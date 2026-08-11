from __future__ import annotations

import json
import re
import secrets
import string
from datetime import datetime

import httpx
from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import settings
from app.utils.datetime_utils import now_local
from app.models.chat_external_api_config import ChatExternalApiConfig
from app.models.chat_message import ChatMessage
from app.models.chat_session import ChatSession
from app.models.user import User
from app.schemas.chat import (
    ChatMessageListOut,
    ChatMessageOut,
    ChatSendMessageRequest,
    ChatSendMessageResponse,
    ChatSessionCreate,
    ChatSessionListOut,
    ChatSessionOut,
    ChatSessionUpdate,
)
from app.services.chat_external_api_config_service import (
    get_chat_scene_credit_cost,
    list_chat_generation_models,
    resolve_chat_scene_configs,
)
from app.services.external_api_config_service import (
    build_external_request_kwargs,
    build_secret_variables,
    parse_http_statuses_json,
    read_value_by_path,
    render_config,
)
from app.services.user_credit_service import change_user_credit_balance, get_user_credit_balance


CHAT_CREDIT_LOG_DESCRIPTION = "AI对话"
MAX_PROVIDER_RESPONSE_PREVIEW_LENGTH = 2000
DEFAULT_SESSION_PAGE_SIZE = 50
DEFAULT_MESSAGE_PAGE_SIZE = 50
PUBLIC_SESSION_ID_RE = re.compile(r"^[0-9]{12}[a-z0-9]{4}$")
_SESSION_ID_RANDOM_ALPHABET = string.ascii_lowercase + string.digits


def _is_credit_exempt_user(user: User | None) -> bool:
    return bool(user and user.role == "superadmin")


def _extract_text_value(payload: object, field_path: str) -> str:
    raw_value, _parent = read_value_by_path(payload, field_path or "")
    return str(raw_value or "").strip()


def _normalize_public_session_id(session_id: str) -> str:
    cleaned = (session_id or "").strip().lower()
    if not PUBLIC_SESSION_ID_RE.fullmatch(cleaned):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="会话不存在")
    return cleaned


def generate_chat_session_id(now: datetime | None = None) -> str:
    """16 位：yymmddhhmmss + 4 位随机小写字母/数字。"""
    stamp = (now or datetime.now()).strftime("%y%m%d%H%M%S")
    suffix = "".join(secrets.choice(_SESSION_ID_RANDOM_ALPHABET) for _ in range(4))
    return f"{stamp}{suffix}"


def _allocate_session_id(db: Session, *, now: datetime | None = None) -> str:
    for _ in range(12):
        candidate = generate_chat_session_id(now)
        exists = (
            db.query(ChatSession.id)
            .filter(ChatSession.session_id == candidate)
            .first()
        )
        if not exists:
            return candidate
    raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="生成会话 ID 失败，请重试")


def _serialize_session(session: ChatSession) -> ChatSessionOut:
    return ChatSessionOut(
        id=(session.session_id or "").strip(),
        title=session.title or "",
        model=session.model or "",
        last_message_at=session.last_message_at,
        created_at=session.created_at,
        updated_at=session.updated_at,
    )


def _serialize_message(message: ChatMessage, *, public_session_id: str) -> ChatMessageOut:
    return ChatMessageOut(
        id=int(message.id),
        session_id=public_session_id,
        role=message.role or "user",
        content=message.content or "",
        model=message.model or "",
        client_message_id=message.client_message_id,
        credit_cost=int(message.credit_cost or 0),
        status=message.status or "success",
        error_message=message.error_message or "",
        created_at=message.created_at,
    )


def _require_session(db: Session, user_id: int, session_id: str) -> ChatSession:
    public_id = _normalize_public_session_id(session_id)
    session = (
        db.query(ChatSession)
        .filter(
            ChatSession.session_id == public_id,
            ChatSession.user_id == user_id,
            ChatSession.is_deleted.is_(False),
        )
        .first()
    )
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="会话不存在")
    return session


def _ensure_model_available(db: Session, model: str) -> str:
    normalized = (model or "").strip().lower()
    if not normalized:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="请选择对话模型")
    available = {item.model_key for item in list_chat_generation_models(db)}
    if normalized not in available:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="对话模型不可用或未绑定接口")
    return normalized


def list_sessions(
    db: Session,
    user_id: int,
    *,
    page: int = 1,
    page_size: int = DEFAULT_SESSION_PAGE_SIZE,
) -> ChatSessionListOut:
    normalized_page = max(int(page or 1), 1)
    normalized_page_size = min(max(int(page_size or DEFAULT_SESSION_PAGE_SIZE), 1), 100)
    # 多取 1 条判断 has_more，避免每次 COUNT(*)
    rows = (
        db.query(ChatSession)
        .filter(
            ChatSession.user_id == user_id,
            ChatSession.is_deleted.is_(False),
        )
        .order_by(
            func.coalesce(ChatSession.last_message_at, ChatSession.updated_at, ChatSession.created_at).desc(),
            ChatSession.id.desc(),
        )
        .offset((normalized_page - 1) * normalized_page_size)
        .limit(normalized_page_size + 1)
        .all()
    )
    has_more = len(rows) > normalized_page_size
    page_rows = rows[:normalized_page_size]
    # total 仅作兼容字段：无更多时为精确值，有更多时为下界估计
    total = (normalized_page - 1) * normalized_page_size + len(page_rows) + (1 if has_more else 0)
    return ChatSessionListOut(
        items=[_serialize_session(item) for item in page_rows],
        total=total,
        page=normalized_page,
        page_size=normalized_page_size,
        has_more=has_more,
    )


def get_session(db: Session, user_id: int, session_id: str) -> ChatSessionOut:
    return _serialize_session(_require_session(db, user_id, session_id))


def create_session(db: Session, user_id: int, body: ChatSessionCreate) -> ChatSessionOut:
    model = _ensure_model_available(db, body.model)
    now = datetime.now()
    last_error: Exception | None = None
    # 并发下以 DB 唯一索引为最终兜底；撞号后换新 ID 重试
    for _ in range(12):
        session = ChatSession(
            session_id=_allocate_session_id(db, now=now),
            user_id=user_id,
            title=body.title or "",
            model=model,
        )
        try:
            db.add(session)
            db.commit()
            db.refresh(session)
            return _serialize_session(session)
        except IntegrityError as exc:
            db.rollback()
            last_error = exc
            continue
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="生成会话 ID 失败，请重试",
    ) from last_error


def update_session(db: Session, user_id: int, session_id: str, body: ChatSessionUpdate) -> ChatSessionOut:
    session = _require_session(db, user_id, session_id)
    if body.title is not None:
        session.title = body.title
    if body.model is not None:
        session.model = _ensure_model_available(db, body.model)
    db.add(session)
    db.commit()
    db.refresh(session)
    return _serialize_session(session)


def delete_session(db: Session, user_id: int, session_id: str) -> None:
    session = _require_session(db, user_id, session_id)
    session.is_deleted = True
    db.add(session)
    db.commit()


def list_messages(
    db: Session,
    user_id: int,
    session_id: str,
    *,
    before_id: int | None = None,
    page_size: int = DEFAULT_MESSAGE_PAGE_SIZE,
) -> ChatMessageListOut:
    session = _require_session(db, user_id, session_id)
    public_session_id = (session.session_id or "").strip()
    normalized_page_size = min(max(int(page_size or DEFAULT_MESSAGE_PAGE_SIZE), 1), 100)
    query = db.query(ChatMessage).filter(ChatMessage.session_id == session.id)
    if before_id is not None:
        query = query.filter(ChatMessage.id < int(before_id))
    rows = (
        query.order_by(ChatMessage.id.desc())
        .limit(normalized_page_size + 1)
        .all()
    )
    has_more = len(rows) > normalized_page_size
    page_rows = rows[:normalized_page_size]
    page_rows.reverse()
    return ChatMessageListOut(
        items=[_serialize_message(item, public_session_id=public_session_id) for item in page_rows],
        has_more=has_more,
        next_before_id=page_rows[0].id if has_more and page_rows else None,
    )


def _build_context_messages(
    db: Session,
    session_id: int,
    *,
    system_prompt: str,
    context_message_limit: int,
    current_user_content: str,
) -> list[dict[str, str]]:
    limit = max(2, int(context_message_limit or 10))
    history_rows = (
        db.query(ChatMessage)
        .filter(
            ChatMessage.session_id == session_id,
            ChatMessage.role.in_(["user", "assistant"]),
            ChatMessage.status == "success",
        )
        .order_by(ChatMessage.id.desc())
        .limit(limit)
        .all()
    )
    history_rows.reverse()
    messages: list[dict[str, str]] = []
    if (system_prompt or "").strip():
        messages.append({"role": "system", "content": system_prompt.strip()})
    for item in history_rows:
        content = (item.content or "").strip()
        if not content:
            continue
        messages.append({"role": item.role, "content": content})
    if not messages or messages[-1].get("content") != current_user_content:
        messages.append({"role": "user", "content": current_user_content})
    return messages


def _call_chat_provider(
    db: Session,
    config: ChatExternalApiConfig,
    *,
    messages: list[dict[str, str]],
    system_prompt: str,
    user_message: str,
) -> tuple[str, str]:
    variables = {
        **build_secret_variables(db),
        "messages": messages,
        "system_prompt": system_prompt or "",
        "user_message": user_message,
    }
    rendered = render_config(config, variables)
    request_kwargs = build_external_request_kwargs(rendered)
    with httpx.Client(timeout=settings.AI_TIMEOUT, trust_env=False) as client:
        response = client.post(rendered.request_url, **request_kwargs)
    preview = (response.text or "")[:MAX_PROVIDER_RESPONSE_PREVIEW_LENGTH]
    success_statuses = parse_http_statuses_json(config.submit_success_statuses_json) or [200, 201, 202]
    try:
        payload = response.json()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"对话接口返回非 JSON：{preview or str(exc)}",
        ) from exc

    if response.status_code not in success_statuses:
        error_text = _extract_text_value(payload, config.result_error_field) if config.result_error_field else ""
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=error_text or f"对话接口调用失败（HTTP {response.status_code}）",
        )

    text = _extract_text_value(payload, config.result_text_field)
    if not text:
        error_text = _extract_text_value(payload, config.result_error_field) if config.result_error_field else ""
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=error_text or "对话接口未返回有效文本",
        )
    return text, preview or json.dumps(payload, ensure_ascii=False)[:MAX_PROVIDER_RESPONSE_PREVIEW_LENGTH]


def _get_reply_assistant(db: Session, session_id: int, user_message_id: int) -> ChatMessage | None:
    return (
        db.query(ChatMessage)
        .filter(
            ChatMessage.session_id == session_id,
            ChatMessage.role == "assistant",
            ChatMessage.reply_to_message_id == user_message_id,
        )
        .first()
    )


def send_message(
    db: Session,
    user: User,
    session_id: str,
    body: ChatSendMessageRequest,
) -> ChatSendMessageResponse:
    session = _require_session(db, user.id, session_id)
    public_session_id = (session.session_id or "").strip()
    existing_user = (
        db.query(ChatMessage)
        .filter(
            ChatMessage.session_id == session.id,
            ChatMessage.client_message_id == body.client_message_id,
            ChatMessage.role == "user",
        )
        .first()
    )
    if existing_user:
        assistant = _get_reply_assistant(db, session.id, existing_user.id)
        if assistant:
            if (assistant.status or "") == "pending":
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="该消息仍在处理中，请稍后重试")
            return ChatSendMessageResponse(
                user_message=_serialize_message(existing_user, public_session_id=public_session_id),
                assistant_message=_serialize_message(assistant, public_session_id=public_session_id),
                credit_cost=int(assistant.credit_cost or 0),
                balance=get_user_credit_balance(db, user.id),
                session=_serialize_session(session),
            )
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="该消息仍在处理中，请稍后重试")

    model = _ensure_model_available(db, body.model or session.model)
    primary_config, backup_config, binding = resolve_chat_scene_configs(db, model)
    credit_cost = get_chat_scene_credit_cost(db, model)
    current_balance = get_user_credit_balance(db, user.id)
    if not _is_credit_exempt_user(user) and current_balance < credit_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"积分不足，需要 {credit_cost} 积分，当前余额 {current_balance}",
        )

    now = now_local()
    user_message = ChatMessage(
        session_id=session.id,
        role="user",
        content=body.content,
        model=model,
        client_message_id=body.client_message_id,
        credit_cost=0,
        status="success",
    )
    assistant_message = ChatMessage(
        session_id=session.id,
        role="assistant",
        reply_to_message_id=None,
        content="",
        model=model,
        credit_cost=0,
        status="pending",
        error_message="",
        provider_response_preview="",
    )
    try:
        db.add(user_message)
        db.flush()
        assistant_message.reply_to_message_id = user_message.id
        db.add(assistant_message)
        if not (session.title or "").strip():
            session.title = body.content[:30]
        session.model = model
        session.last_message_at = now
        db.add(session)
        db.commit()
    except Exception as exc:
        db.rollback()
        # 并发下可能撞唯一约束，按幂等返回
        existing_user = (
            db.query(ChatMessage)
            .filter(
                ChatMessage.session_id == session.id,
                ChatMessage.client_message_id == body.client_message_id,
                ChatMessage.role == "user",
            )
            .first()
        )
        if existing_user:
            assistant = _get_reply_assistant(db, session.id, existing_user.id)
            if assistant:
                if (assistant.status or "") == "pending":
                    raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="该消息仍在处理中，请稍后重试")
                return ChatSendMessageResponse(
                    user_message=_serialize_message(existing_user, public_session_id=public_session_id),
                    assistant_message=_serialize_message(assistant, public_session_id=public_session_id),
                    credit_cost=int(assistant.credit_cost or 0),
                    balance=get_user_credit_balance(db, user.id),
                    session=_serialize_session(session),
                )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="消息提交冲突，请重试") from exc
    db.refresh(user_message)
    db.refresh(assistant_message)
    db.refresh(session)

    context_messages = _build_context_messages(
        db,
        session.id,
        system_prompt=binding.system_prompt or "",
        context_message_limit=int(binding.context_message_limit or 10),
        current_user_content=body.content,
    )
    return _finish_provider_round(
        db,
        user=user,
        session=session,
        user_message=user_message,
        assistant_message=assistant_message,
        model=model,
        binding=binding,
        primary_config=primary_config,
        backup_config=backup_config,
        credit_cost=credit_cost,
        context_messages=context_messages,
        user_content=body.content,
    )


def _finish_provider_round(
    db: Session,
    *,
    user: User,
    session: ChatSession,
    user_message: ChatMessage,
    assistant_message: ChatMessage,
    model: str,
    binding,
    primary_config: ChatExternalApiConfig,
    backup_config: ChatExternalApiConfig | None,
    credit_cost: int,
    context_messages: list[dict[str, str]],
    user_content: str,
) -> ChatSendMessageResponse:
    reply_text = ""
    preview = ""
    used_fallback = False
    provider_config_id = int(primary_config.id)
    last_error = "对话服务异常，请稍后重试"
    candidates = [primary_config] + ([backup_config] if backup_config else [])
    for index, config in enumerate(candidates):
        try:
            reply_text, preview = _call_chat_provider(
                db,
                config,
                messages=context_messages,
                system_prompt=binding.system_prompt or "",
                user_message=user_content,
            )
            provider_config_id = int(config.id)
            used_fallback = index > 0
            last_error = ""
            break
        except HTTPException as exc:
            last_error = str(exc.detail)
        except httpx.TimeoutException:
            last_error = "对话请求超时，请稍后重试"
        except Exception:
            last_error = "对话服务异常，请稍后重试"

    if not reply_text:
        assistant_message.content = last_error
        assistant_message.status = "failed"
        assistant_message.error_message = last_error
        assistant_message.provider_api_config_id = provider_config_id
        assistant_message.used_fallback_api = used_fallback
        assistant_message.provider_response_preview = preview
        db.add(assistant_message)
        session.last_message_at = now_local()
        db.add(session)
        db.commit()
        db.refresh(assistant_message)
        db.refresh(session)
        public_session_id = (session.session_id or "").strip()
        return ChatSendMessageResponse(
            user_message=_serialize_message(user_message, public_session_id=public_session_id),
            assistant_message=_serialize_message(assistant_message, public_session_id=public_session_id),
            credit_cost=0,
            balance=get_user_credit_balance(db, user.id),
            session=_serialize_session(session),
        )

    assistant_message.content = reply_text
    assistant_message.model = model
    assistant_message.credit_cost = credit_cost if not _is_credit_exempt_user(user) else 0
    assistant_message.status = "success"
    assistant_message.error_message = ""
    assistant_message.provider_api_config_id = provider_config_id
    assistant_message.used_fallback_api = used_fallback
    assistant_message.provider_response_preview = preview
    db.add(assistant_message)
    session.last_message_at = now_local()
    db.add(session)
    if not _is_credit_exempt_user(user) and credit_cost > 0:
        change_user_credit_balance(
            db,
            user.id,
            delta=-credit_cost,
            log_type="consume",
            description=f"{CHAT_CREDIT_LOG_DESCRIPTION}·{binding.scene_label or model}",
        )
    db.commit()
    db.refresh(assistant_message)
    db.refresh(session)

    public_session_id = (session.session_id or "").strip()
    return ChatSendMessageResponse(
        user_message=_serialize_message(user_message, public_session_id=public_session_id),
        assistant_message=_serialize_message(assistant_message, public_session_id=public_session_id),
        credit_cost=int(assistant_message.credit_cost or 0),
        balance=get_user_credit_balance(db, user.id),
        session=_serialize_session(session),
    )
