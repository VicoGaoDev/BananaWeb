import json
import re
from typing import Any

import httpx
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.api_key import ApiKey
from app.models.external_api_config import ExternalApiConfig
from app.models.external_api_scene_binding import ExternalApiSceneBinding
from app.schemas.external_api_config import (
    ExternalApiConfigCreate,
    ExternalApiConfigOut,
    ExternalApiConfigTestResult,
    ExternalApiConfigUpdate,
    ExternalApiSceneBindingOut,
    ExternalApiSceneBindingUpdate,
    GenerationModelOptionOut,
    RenderedExternalApiConfig,
    TaskSceneConfigOut,
)

SCENE_BANANA = "banana"
SCENE_BANANA2 = "banana2"
SCENE_BANANA_PRO = "banana_pro"
SCENE_BANANA_PRO_PLUS = "banana_pro_plus"
SCENE_PROMPT_REVERSE = "prompt_reverse"
SCENE_INPAINT = "inpaint"
DEFAULT_GENERATION_SCENE = SCENE_BANANA_PRO
PLACEHOLDER_RE = re.compile(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}")
SCENE_DEFINITIONS = [
    {"scene_key": SCENE_BANANA, "scene_label": "Banana", "scene_description": "推荐模型", "sort_order": 10, "hide_resolution": True},
    {"scene_key": SCENE_BANANA2, "scene_label": "Banana 2", "scene_description": "尝鲜版", "sort_order": 20, "hide_resolution": False},
    {"scene_key": SCENE_BANANA_PRO, "scene_label": "Banana Pro", "scene_description": "增强版", "sort_order": 30, "hide_resolution": False},
    {"scene_key": SCENE_BANANA_PRO_PLUS, "scene_label": "Banana Pro+", "scene_description": "增强稳定版", "sort_order": 40, "hide_resolution": False},
    {"scene_key": SCENE_PROMPT_REVERSE, "scene_label": "提示词反推", "scene_description": "图片反推提示词", "sort_order": 50, "hide_resolution": False},
    {"scene_key": SCENE_INPAINT, "scene_label": "局部重绘", "scene_description": "图编辑/局部重绘", "sort_order": 60, "hide_resolution": False},
]
SCENE_DEFAULT_CREDIT_COSTS = {
    SCENE_BANANA: 4,
    SCENE_BANANA2: 4,
    SCENE_BANANA_PRO: 4,
    SCENE_BANANA_PRO_PLUS: 4,
    SCENE_PROMPT_REVERSE: 1,
    SCENE_INPAINT: 4,
}
GENERATION_SCENE_KEYS = {SCENE_BANANA, SCENE_BANANA2, SCENE_BANANA_PRO, SCENE_BANANA_PRO_PLUS}
SCENE_DEF_MAP = {item["scene_key"]: item for item in SCENE_DEFINITIONS}


def _load_json(raw: str, field_name: str) -> Any:
    try:
        return json.loads(raw or "{}")
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name} 不是合法 JSON: {exc.msg}",
        ) from exc


def _dump_json(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2)


def _default_generation_headers(api_key: str) -> str:
    return _dump_json({
        "Content-Type": "application/json",
        "Authorization": api_key,
    })


def _default_generation_payload() -> str:
    return _dump_json({
        "contents": [
            {
                "role": "user",
                "parts": "{{contents_parts}}",
            }
        ],
        "generationConfig": "{{generation_config}}",
    })


def _default_prompt_reverse_headers(api_key: str) -> str:
    return _dump_json({
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    })


def _default_prompt_reverse_payload() -> str:
    return _dump_json({
        "model": "qwen-vl-plus",
        "input": {
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"image": "{{image_data_url}}"},
                        {"text": "{{prompt_reverse_text}}"},
                    ],
                }
            ],
        },
        "parameters": {
            "temperature": 0.1,
            "max_tokens": 1024,
        },
    })


def _normalize_headers(data: Any) -> dict[str, str]:
    if not isinstance(data, dict):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Header JSON 必须是对象")
    return {str(key): "" if value is None else str(value) for key, value in data.items()}


def _render_string(template: str, variables: dict[str, Any]) -> Any:
    exact_match = PLACEHOLDER_RE.fullmatch(template)
    if exact_match:
        return variables.get(exact_match.group(1), "")

    def replace(match: re.Match[str]) -> str:
        name = match.group(1)
        value = variables.get(name, "")
        if isinstance(value, (dict, list)):
            return json.dumps(value, ensure_ascii=False)
        if value is None:
            return ""
        return str(value)

    return PLACEHOLDER_RE.sub(replace, template)


def _render_json_template(template: Any, variables: dict[str, Any]) -> Any:
    if isinstance(template, dict):
        return {key: _render_json_template(value, variables) for key, value in template.items()}
    if isinstance(template, list):
        return [_render_json_template(item, variables) for item in template]
    if isinstance(template, str):
        return _render_string(template, variables)
    return template


def _serialize_config(config: ExternalApiConfig) -> ExternalApiConfigOut:
    return ExternalApiConfigOut.model_validate(config)


def get_default_credit_cost(scene_key: str) -> int:
    return SCENE_DEFAULT_CREDIT_COSTS.get(scene_key, 0)


def _serialize_scene_binding(
    definition: dict[str, Any],
    binding: ExternalApiSceneBinding | None,
    config: ExternalApiConfig | None,
) -> ExternalApiSceneBindingOut:
    return ExternalApiSceneBindingOut(
        scene_key=definition["scene_key"],
        scene_label=definition["scene_label"],
        scene_description=definition["scene_description"],
        sort_order=definition["sort_order"],
        hide_resolution=definition["hide_resolution"],
        api_config_id=config.id if config else None,
        api_config_name=config.name if config else "",
        api_group_name=config.group_name if config else "",
        api_status=config.status if config else None,
        credit_cost=binding.credit_cost if binding else get_default_credit_cost(definition["scene_key"]),
    )


def list_configs(db: Session) -> list[ExternalApiConfigOut]:
    rows = (
        db.query(ExternalApiConfig)
        .order_by(ExternalApiConfig.group_name.asc(), ExternalApiConfig.created_at.desc(), ExternalApiConfig.id.desc())
        .all()
    )
    return [_serialize_config(row) for row in rows]


def list_generation_models(db: Session) -> list[GenerationModelOptionOut]:
    scene_bindings = {row.scene_key: row for row in db.query(ExternalApiSceneBinding).all()}
    return [
        GenerationModelOptionOut(
            model_key=item["scene_key"],
            model_label=item["scene_label"],
            model_description=item["scene_description"],
            sort_order=item["sort_order"],
            hide_resolution=item["hide_resolution"],
            credit_cost=scene_bindings.get(item["scene_key"]).credit_cost
            if scene_bindings.get(item["scene_key"])
            else get_default_credit_cost(item["scene_key"]),
        )
        for item in SCENE_DEFINITIONS
        if item["scene_key"] in GENERATION_SCENE_KEYS
    ]


def get_default_generation_model_key(db: Session) -> str:
    return DEFAULT_GENERATION_SCENE


def get_config_or_404(db: Session, config_id: int) -> ExternalApiConfig:
    config = db.query(ExternalApiConfig).filter(ExternalApiConfig.id == config_id).first()
    if not config:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="接口配置不存在")
    return config


def _ensure_name_unique(db: Session, name: str, exclude_id: int | None = None) -> None:
    query = db.query(ExternalApiConfig).filter(ExternalApiConfig.name == name)
    if exclude_id is not None:
        query = query.filter(ExternalApiConfig.id != exclude_id)
    if query.first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="配置名称已存在")


def create_config(db: Session, body: ExternalApiConfigCreate) -> ExternalApiConfigOut:
    _ensure_name_unique(db, body.name)
    config = ExternalApiConfig(**body.model_dump())
    db.add(config)
    db.commit()
    db.refresh(config)
    return _serialize_config(config)


def update_config(db: Session, config_id: int, body: ExternalApiConfigUpdate) -> ExternalApiConfigOut:
    config = get_config_or_404(db, config_id)
    _ensure_name_unique(db, body.name, exclude_id=config_id)
    for key, value in body.model_dump().items():
        setattr(config, key, value)
    db.commit()
    db.refresh(config)
    return _serialize_config(config)


def set_config_status(db: Session, config_id: int, status_value: str) -> ExternalApiConfigOut:
    config = get_config_or_404(db, config_id)
    config.status = status_value
    db.commit()
    db.refresh(config)
    return _serialize_config(config)


def list_scene_bindings(db: Session) -> list[ExternalApiSceneBindingOut]:
    bindings = {row.scene_key: row for row in db.query(ExternalApiSceneBinding).all()}
    configs = {row.id: row for row in db.query(ExternalApiConfig).all()}
    items: list[ExternalApiSceneBindingOut] = []
    for definition in SCENE_DEFINITIONS:
        binding = bindings.get(definition["scene_key"])
        config = configs.get(binding.api_config_id) if binding and binding.api_config_id else None
        items.append(_serialize_scene_binding(definition, binding, config))
    return items


def list_public_task_scene_configs(db: Session) -> list[TaskSceneConfigOut]:
    return [
        TaskSceneConfigOut(
            scene_key=item.scene_key,
            scene_label=item.scene_label,
            scene_description=item.scene_description,
            sort_order=item.sort_order,
            hide_resolution=item.hide_resolution,
            credit_cost=item.credit_cost,
        )
        for item in list_scene_bindings(db)
    ]


def set_scene_binding(
    db: Session,
    scene_key: str,
    body: ExternalApiSceneBindingUpdate,
) -> ExternalApiSceneBindingOut:
    if scene_key not in SCENE_DEF_MAP:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="不支持的调用场景")

    if body.api_config_id is not None:
        config = get_config_or_404(db, body.api_config_id)
        if config.status != "enabled":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只能绑定启用状态的接口")

    binding = db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == scene_key).first()
    if not binding:
        binding = ExternalApiSceneBinding(
            scene_key=scene_key,
            api_config_id=body.api_config_id,
            credit_cost=body.credit_cost,
        )
        db.add(binding)
    else:
        binding.api_config_id = body.api_config_id
        binding.credit_cost = body.credit_cost
    db.commit()
    return next(item for item in list_scene_bindings(db) if item.scene_key == scene_key)


def get_scene_credit_cost(db: Session, scene_key: str) -> int:
    if scene_key not in SCENE_DEF_MAP:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="不支持的调用场景")
    binding = db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == scene_key).first()
    if binding:
        return binding.credit_cost
    return get_default_credit_cost(scene_key)


def require_scene_config(db: Session, scene_key: str) -> ExternalApiConfig:
    if scene_key not in SCENE_DEF_MAP:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="不支持的调用场景")
    binding = db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == scene_key).first()
    if not binding or not binding.api_config_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"场景 {scene_key} 尚未绑定接口，请联系超级管理员在后台设置后再使用",
        )
    config = get_config_or_404(db, binding.api_config_id)
    if config.status != "enabled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"场景 {scene_key} 当前绑定的接口已停用，请联系超级管理员调整绑定",
        )
    return config


def render_config(config: ExternalApiConfig, variables: dict[str, Any]) -> RenderedExternalApiConfig:
    headers_template = _load_json(config.headers_json, "Header JSON")
    payload_template = _load_json(config.payload_json, "请求 JSON")

    rendered_headers = _render_json_template(headers_template, variables)
    rendered_payload = _render_json_template(payload_template, variables)

    return RenderedExternalApiConfig(
        request_url=config.request_url.strip(),
        headers=_normalize_headers(rendered_headers),
        payload=rendered_payload,
    )


def _build_test_variables() -> dict[str, Any]:
    one_pixel_png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+XGJ0AAAAASUVORK5CYII="
    return {
        "prompt": "连接测试",
        "aspect_ratio": "1:1",
        "image_size": "2K",
        "contents_parts": [{"text": "连接测试"}],
        "generation_config": {"responseModalities": ["TEXT"]},
        "mode": "generate",
        "image_data_url": f"data:image/png;base64,{one_pixel_png}",
        "prompt_reverse_text": "请返回测试提示词",
        "api_key": "test-api-key",
        "bearer_token": "test-api-key",
    }


def test_external_api_config(body: ExternalApiConfigCreate) -> ExternalApiConfigTestResult:
    config = ExternalApiConfig(**body.model_dump())
    rendered = render_config(config, _build_test_variables())

    try:
        with httpx.Client(timeout=20) as client:
            response = client.post(
                rendered.request_url,
                json=rendered.payload,
                headers=rendered.headers,
            )
        preview = response.text[:1200]
        return ExternalApiConfigTestResult(
            success=200 <= response.status_code < 300,
            request_url=rendered.request_url,
            status_code=response.status_code,
            response_preview=preview or "(空响应)",
        )
    except httpx.TimeoutException:
        return ExternalApiConfigTestResult(
            success=False,
            request_url=rendered.request_url,
            response_preview="请求超时，请检查接口地址、网络或服务端响应时间",
        )
    except Exception as exc:
        return ExternalApiConfigTestResult(
            success=False,
            request_url=rendered.request_url,
            response_preview=f"请求发送失败：{exc}",
        )


def _pick_generation_config_for_scene(db: Session, scene_key: str) -> ExternalApiConfig | None:
    candidates = db.query(ExternalApiConfig).filter(ExternalApiConfig.status == "enabled").order_by(ExternalApiConfig.id.asc()).all()
    for item in candidates:
        if item.model_key == scene_key and item.is_active_generation:
            return item
    for item in candidates:
        if item.model_key == scene_key:
            return item
    for item in candidates:
        if item.is_active_generation:
            return item
    return candidates[0] if candidates else None


def _pick_prompt_reverse_config(db: Session) -> ExternalApiConfig | None:
    candidates = db.query(ExternalApiConfig).filter(ExternalApiConfig.status == "enabled").order_by(ExternalApiConfig.id.asc()).all()
    for item in candidates:
        if item.is_active_prompt_reverse:
            return item
    return candidates[-1] if candidates else None


def _pick_inpaint_config(db: Session) -> ExternalApiConfig | None:
    candidates = db.query(ExternalApiConfig).filter(ExternalApiConfig.status == "enabled").order_by(ExternalApiConfig.id.asc()).all()
    for item in candidates:
        if item.is_active_inpaint:
            return item
    preferred = _pick_generation_config_for_scene(db, SCENE_BANANA_PRO)
    return preferred or (candidates[0] if candidates else None)


def _ensure_scene_bindings(db: Session) -> None:
    if db.query(ExternalApiSceneBinding).first():
        bindings = db.query(ExternalApiSceneBinding).all()
        updated = False
        for binding in bindings:
            default_cost = get_default_credit_cost(binding.scene_key)
            if binding.credit_cost is None:
                binding.credit_cost = default_cost
                updated = True
        if updated:
            db.commit()
        return

    for scene_key in [SCENE_BANANA, SCENE_BANANA2, SCENE_BANANA_PRO, SCENE_BANANA_PRO_PLUS]:
        config = _pick_generation_config_for_scene(db, scene_key)
        db.add(ExternalApiSceneBinding(
            scene_key=scene_key,
            api_config_id=config.id if config else None,
            credit_cost=get_default_credit_cost(scene_key),
        ))

    prompt_reverse_config = _pick_prompt_reverse_config(db)
    db.add(ExternalApiSceneBinding(
        scene_key=SCENE_PROMPT_REVERSE,
        api_config_id=prompt_reverse_config.id if prompt_reverse_config else None,
        credit_cost=get_default_credit_cost(SCENE_PROMPT_REVERSE),
    ))

    inpaint_config = _pick_inpaint_config(db)
    db.add(ExternalApiSceneBinding(
        scene_key=SCENE_INPAINT,
        api_config_id=inpaint_config.id if inpaint_config else None,
        credit_cost=get_default_credit_cost(SCENE_INPAINT),
    ))
    db.commit()


def seed_legacy_configs(db: Session, ai_api_url: str, prompt_reverse_url: str) -> None:
    api_key = db.query(ApiKey).first()
    generation_key = (api_key.key or "").strip() if api_key else ""
    prompt_reverse_key = (api_key.tongyi_key or "").strip() if api_key else ""

    if not db.query(ExternalApiConfig).first():
        created = False
        if generation_key:
            db.add(ExternalApiConfig(
                name="默认生图接口",
                description="从旧版 API Key 配置自动迁移而来",
                group_name="默认",
                request_url=ai_api_url,
                headers_json=_default_generation_headers(generation_key),
                payload_json=_default_generation_payload(),
                status="enabled",
            ))
            created = True
        if prompt_reverse_key:
            db.add(ExternalApiConfig(
                name="默认反推接口",
                description="从旧版通义配置自动迁移而来",
                group_name="默认",
                request_url=prompt_reverse_url,
                headers_json=_default_prompt_reverse_headers(prompt_reverse_key),
                payload_json=_default_prompt_reverse_payload(),
                status="enabled",
            ))
            created = True
        if created:
            db.commit()

    _ensure_scene_bindings(db)
