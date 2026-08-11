from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.chat import (
    ChatMessageListOut,
    ChatSendMessageRequest,
    ChatSendMessageResponse,
    ChatSessionCreate,
    ChatSessionListOut,
    ChatSessionOut,
    ChatSessionUpdate,
)
from app.services.chat_service import (
    create_session,
    delete_session,
    get_session,
    list_messages,
    list_sessions,
    send_message,
    update_session,
)

router = APIRouter(prefix="/api/chat", tags=["AI对话"])


@router.get("/sessions", response_model=ChatSessionListOut)
def get_chat_sessions(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return list_sessions(db, user.id, page=page, page_size=page_size)


@router.post("/sessions", response_model=ChatSessionOut)
def create_chat_session(
    body: ChatSessionCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return create_session(db, user.id, body)


@router.get("/sessions/{session_id}", response_model=ChatSessionOut)
def get_chat_session(
    session_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_session(db, user.id, session_id)


@router.patch("/sessions/{session_id}", response_model=ChatSessionOut)
def patch_chat_session(
    session_id: str,
    body: ChatSessionUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return update_session(db, user.id, session_id, body)


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_chat_session(
    session_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    delete_session(db, user.id, session_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/sessions/{session_id}/messages", response_model=ChatMessageListOut)
def get_chat_messages(
    session_id: str,
    before_id: int | None = Query(default=None, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return list_messages(db, user.id, session_id, before_id=before_id, page_size=page_size)


@router.post("/sessions/{session_id}/messages", response_model=ChatSendMessageResponse)
def post_chat_message(
    session_id: str,
    body: ChatSendMessageRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return send_message(db, user, session_id, body)
