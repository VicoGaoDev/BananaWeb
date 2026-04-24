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
    ExternalApiSceneBindingCreate,
    ExternalApiSceneBindingMetaUpdate,
    ExternalApiConfigUpdate,
    ExternalApiSceneBindingOut,
    ExternalApiSceneBindingStatusUpdate,
    ExternalApiSceneBindingUpdate,
    GenerationModelOptionOut,
    RenderedExternalApiConfig,
    TaskSceneConfigOut,
)

SCENE_BANANA = "banana"
SCENE_BANANA2 = "banana2"
SCENE_BANANA_PRO = "banana_pro"
SCENE_BANANA_PRO_PLUS = "banana_pro_plus"
SCENE_BANANA_EDIT = "banana_edit"
SCENE_BANANA2_EDIT = "banana2_edit"
SCENE_BANANA_PRO_EDIT = "banana_pro_edit"
SCENE_BANANA_PRO_PLUS_EDIT = "banana_pro_plus_edit"
SCENE_PROMPT_REVERSE = "prompt_reverse"
SCENE_INPAINT = "inpaint"
SCENE_TYPE_GENERATE = "generate"
SCENE_TYPE_IMAGE_EDIT = "image_edit"
SCENE_TYPE_PROMPT_REVERSE = "prompt_reverse"
SCENE_TYPE_INPAINT = "inpaint"
DEFAULT_GENERATION_SCENE = SCENE_BANANA_PRO
PLACEHOLDER_RE = re.compile(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}")
DEFAULT_SCENE_DEFINITIONS = [
    {"scene_key": SCENE_BANANA, "scene_type": SCENE_TYPE_GENERATE, "scene_label": "Banana", "scene_description": "推荐模型", "sort_order": 10, "hide_aspect_ratio": False, "hide_resolution": True, "hide_custom_size": True},
    {"scene_key": SCENE_BANANA2, "scene_type": SCENE_TYPE_GENERATE, "scene_label": "Banana 2", "scene_description": "尝鲜版", "sort_order": 20, "hide_aspect_ratio": False, "hide_resolution": False, "hide_custom_size": True},
    {"scene_key": SCENE_BANANA_PRO, "scene_type": SCENE_TYPE_GENERATE, "scene_label": "Banana Pro", "scene_description": "增强版", "sort_order": 30, "hide_aspect_ratio": False, "hide_resolution": False, "hide_custom_size": True},
    {"scene_key": SCENE_BANANA_PRO_PLUS, "scene_type": SCENE_TYPE_GENERATE, "scene_label": "Banana Pro+", "scene_description": "增强稳定版", "sort_order": 40, "hide_aspect_ratio": False, "hide_resolution": False, "hide_custom_size": True},
    {"scene_key": SCENE_BANANA_EDIT, "scene_type": SCENE_TYPE_IMAGE_EDIT, "scene_label": "Banana", "scene_description": "推荐模型", "sort_order": 110, "hide_aspect_ratio": False, "hide_resolution": True, "hide_custom_size": True},
    {"scene_key": SCENE_BANANA2_EDIT, "scene_type": SCENE_TYPE_IMAGE_EDIT, "scene_label": "Banana 2", "scene_description": "尝鲜版", "sort_order": 120, "hide_aspect_ratio": False, "hide_resolution": False, "hide_custom_size": True},
    {"scene_key": SCENE_BANANA_PRO_EDIT, "scene_type": SCENE_TYPE_IMAGE_EDIT, "scene_label": "Banana Pro", "scene_description": "增强版", "sort_order": 130, "hide_aspect_ratio": False, "hide_resolution": False, "hide_custom_size": True},
    {"scene_key": SCENE_BANANA_PRO_PLUS_EDIT, "scene_type": SCENE_TYPE_IMAGE_EDIT, "scene_label": "Banana Pro+", "scene_description": "增强稳定版", "sort_order": 140, "hide_aspect_ratio": False, "hide_resolution": False, "hide_custom_size": True},
    {"scene_key": SCENE_PROMPT_REVERSE, "scene_type": SCENE_TYPE_PROMPT_REVERSE, "scene_label": "提示词反推", "scene_description": "图片反推提示词", "sort_order": 50, "hide_aspect_ratio": True, "hide_resolution": True, "hide_custom_size": True},
    {"scene_key": SCENE_INPAINT, "scene_type": SCENE_TYPE_INPAINT, "scene_label": "局部重绘", "scene_description": "图编辑/局部重绘", "sort_order": 60, "hide_aspect_ratio": True, "hide_resolution": True, "hide_custom_size": True},
]
SCENE_DEFAULT_CREDIT_COSTS = {
    SCENE_BANANA: 4,
    SCENE_BANANA2: 4,
    SCENE_BANANA_PRO: 4,
    SCENE_BANANA_PRO_PLUS: 4,
    SCENE_BANANA_EDIT: 4,
    SCENE_BANANA2_EDIT: 4,
    SCENE_BANANA_PRO_EDIT: 4,
    SCENE_BANANA_PRO_PLUS_EDIT: 4,
    SCENE_PROMPT_REVERSE: 1,
    SCENE_INPAINT: 4,
}
IMAGE_EDIT_SCENE_SOURCE_MAP = {
    SCENE_BANANA_EDIT: SCENE_BANANA,
    SCENE_BANANA2_EDIT: SCENE_BANANA2,
    SCENE_BANANA_PRO_EDIT: SCENE_BANANA_PRO,
    SCENE_BANANA_PRO_PLUS_EDIT: SCENE_BANANA_PRO_PLUS,
}
DEFAULT_SCENE_MAP = {item["scene_key"]: item for item in DEFAULT_SCENE_DEFINITIONS}
NON_EDITABLE_SCENE_KEYS = {SCENE_PROMPT_REVERSE, SCENE_INPAINT}
DEFAULT_ASPECT_RATIO_OPTIONS = [
    {"label": "■  1:1", "value": "1:1"},
    {"label": "▮  2:3", "value": "2:3"},
    {"label": "▬  3:2", "value": "3:2"},
    {"label": "▮  3:4", "value": "3:4"},
    {"label": "▬  4:3", "value": "4:3"},
    {"label": "▮  9:16", "value": "9:16"},
    {"label": "▬  16:9", "value": "16:9"},
]
DEFAULT_IMAGE_SIZE_OPTIONS = [
    {"label": "1K", "value": "1K"},
    {"label": "2K", "value": "2K"},
    {"label": "4K", "value": "4K"},
]
DEFAULT_CUSTOM_SIZE_OPTIONS = [
    {"label": "1024 x 1024", "value": "1024x1024"},
    {"label": "1152 x 896", "value": "1152x896"},
    {"label": "896 x 1152", "value": "896x1152"},
    {"label": "1280 x 720", "value": "1280x720"},
]


def is_builtin_scene(scene_key: str) -> bool:
    return scene_key in NON_EDITABLE_SCENE_KEYS


def _get_default_scene_options(scene_type: str) -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    if scene_type in {SCENE_TYPE_GENERATE, SCENE_TYPE_IMAGE_EDIT}:
        return DEFAULT_ASPECT_RATIO_OPTIONS, DEFAULT_IMAGE_SIZE_OPTIONS, DEFAULT_CUSTOM_SIZE_OPTIONS
    return [], [], []


def _normalize_scene_options(raw: str | None, fallback: list[dict[str, str]]) -> list[dict[str, str]]:
    candidate = (raw or "").strip()
    if not candidate:
        return [item.copy() for item in fallback]
    try:
        parsed = json.loads(candidate)
    except json.JSONDecodeError:
        return [item.copy() for item in fallback]

    if not isinstance(parsed, list):
        return [item.copy() for item in fallback]

    normalized: list[dict[str, str]] = []
    for item in parsed:
        if not isinstance(item, dict):
            continue
        label = str(item.get("label", "") or "").strip()
        value = str(item.get("value", "") or "").strip()
        if not label or not value:
            continue
        normalized.append({"label": label, "value": value})
    return normalized or [item.copy() for item in fallback]


def _dump_scene_options(items: list[dict[str, str]]) -> str:
    return json.dumps(items, ensure_ascii=False, indent=2)


def _get_scene_option_json(
    scene_type: str,
    aspect_ratio_options_json: str | None,
    image_size_options_json: str | None,
    custom_size_options_json: str | None,
) -> tuple[str, str, str]:
    default_aspect_ratio_options, default_image_size_options, default_custom_size_options = _get_default_scene_options(scene_type)
    return (
        _dump_scene_options(_normalize_scene_options(aspect_ratio_options_json, default_aspect_ratio_options)),
        _dump_scene_options(_normalize_scene_options(image_size_options_json, default_image_size_options)),
        _dump_scene_options(_normalize_scene_options(custom_size_options_json, default_custom_size_options)),
    )


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


def _default_generation_response() -> str:
    return _dump_json({
        "candidates": [
            {
                "content": {
                    "parts": [
                        {
                            "inlineData": {
                                "mimeType": "image/png",
                                "data": "<base64>",
                            }
                        }
                    ]
                }
            }
        ]
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


def get_default_credit_cost(scene_key: str, scene_type: str | None = None) -> int:
    if scene_key in SCENE_DEFAULT_CREDIT_COSTS:
        return SCENE_DEFAULT_CREDIT_COSTS[scene_key]
    if scene_type == SCENE_TYPE_PROMPT_REVERSE:
        return SCENE_DEFAULT_CREDIT_COSTS[SCENE_PROMPT_REVERSE]
    if scene_type == SCENE_TYPE_INPAINT:
        return SCENE_DEFAULT_CREDIT_COSTS[SCENE_INPAINT]
    return SCENE_DEFAULT_CREDIT_COSTS[SCENE_BANANA_PRO]


def _resolve_scene_copy(binding: ExternalApiSceneBinding) -> tuple[str, str]:
    display_name = (binding.display_name or "").strip()
    subtitle = (binding.subtitle or "").strip()
    return (
        display_name or (binding.scene_label or "").strip(),
        subtitle or (binding.scene_description or "").strip(),
    )


def _serialize_scene_binding(
    binding: ExternalApiSceneBinding,
    config: ExternalApiConfig | None,
) -> ExternalApiSceneBindingOut:
    scene_label, scene_description = _resolve_scene_copy(binding)
    aspect_ratio_options_json, image_size_options_json, custom_size_options_json = _get_scene_option_json(
        binding.scene_type,
        binding.aspect_ratio_options_json,
        binding.image_size_options_json,
        binding.custom_size_options_json,
    )
    return ExternalApiSceneBindingOut(
        scene_key=binding.scene_key,
        scene_type=binding.scene_type,
        scene_label=scene_label,
        scene_description=scene_description,
        display_name=(binding.display_name or "").strip(),
        subtitle=(binding.subtitle or "").strip(),
        sort_order=binding.sort_order,
        hide_aspect_ratio=bool(binding.hide_aspect_ratio),
        hide_resolution=binding.hide_resolution,
        hide_custom_size=bool(binding.hide_custom_size),
        status=(binding.status or "enabled").strip().lower(),
        is_builtin=is_builtin_scene(binding.scene_key),
        api_config_id=config.id if config else None,
        api_config_name=config.name if config else "",
        api_group_name=config.group_name if config else "",
        api_status=config.status if config else None,
        credit_cost=binding.credit_cost,
        aspect_ratio_options_json=aspect_ratio_options_json,
        image_size_options_json=image_size_options_json,
        custom_size_options_json=custom_size_options_json,
    )


def list_configs(db: Session) -> list[ExternalApiConfigOut]:
    rows = (
        db.query(ExternalApiConfig)
        .order_by(ExternalApiConfig.group_name.asc(), ExternalApiConfig.created_at.desc(), ExternalApiConfig.id.desc())
        .all()
    )
    return [_serialize_config(row) for row in rows]


def list_generation_models(db: Session) -> list[GenerationModelOptionOut]:
    _ensure_scene_bindings(db)
    scene_bindings = (
        db.query(ExternalApiSceneBinding)
        .filter(
            ExternalApiSceneBinding.scene_type == SCENE_TYPE_GENERATE,
            ExternalApiSceneBinding.status == "enabled",
        )
        .order_by(ExternalApiSceneBinding.sort_order.asc(), ExternalApiSceneBinding.id.asc())
        .all()
    )
    items: list[GenerationModelOptionOut] = []
    for binding in scene_bindings:
        model_label, model_description = _resolve_scene_copy(binding)
        items.append(GenerationModelOptionOut(
            model_key=binding.scene_key,
            model_label=model_label,
            model_description=model_description,
            display_name=(binding.display_name or "").strip(),
            subtitle=(binding.subtitle or "").strip(),
            sort_order=binding.sort_order,
            hide_aspect_ratio=bool(binding.hide_aspect_ratio),
            hide_resolution=binding.hide_resolution,
            hide_custom_size=bool(binding.hide_custom_size),
            credit_cost=binding.credit_cost,
            aspect_ratio_options=json.loads(binding.aspect_ratio_options_json or "[]"),
            image_size_options=json.loads(binding.image_size_options_json or "[]"),
            custom_size_options=json.loads(binding.custom_size_options_json or "[]"),
        ))
    return items


def get_default_generation_model_key(db: Session) -> str:
    models = list_generation_models(db)
    return models[0].model_key if models else DEFAULT_GENERATION_SCENE


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
    _ensure_scene_bindings(db)
    bindings = (
        db.query(ExternalApiSceneBinding)
        .order_by(ExternalApiSceneBinding.sort_order.asc(), ExternalApiSceneBinding.id.asc())
        .all()
    )
    configs = {row.id: row for row in db.query(ExternalApiConfig).all()}
    return [
        _serialize_scene_binding(binding, configs.get(binding.api_config_id) if binding.api_config_id else None)
        for binding in bindings
    ]


def list_public_task_scene_configs(db: Session) -> list[TaskSceneConfigOut]:
    return [
        TaskSceneConfigOut(
            scene_key=item.scene_key,
            scene_type=item.scene_type,
            scene_label=item.scene_label,
            scene_description=item.scene_description,
            display_name=item.display_name,
            subtitle=item.subtitle,
            sort_order=item.sort_order,
            hide_aspect_ratio=item.hide_aspect_ratio,
            hide_resolution=item.hide_resolution,
            hide_custom_size=item.hide_custom_size,
            credit_cost=item.credit_cost,
            aspect_ratio_options=json.loads(item.aspect_ratio_options_json or "[]"),
            image_size_options=json.loads(item.image_size_options_json or "[]"),
            custom_size_options=json.loads(item.custom_size_options_json or "[]"),
        )
        for item in list_scene_bindings(db)
        if item.status == "enabled"
    ]


def create_scene_binding(
    db: Session,
    body: ExternalApiSceneBindingCreate,
) -> ExternalApiSceneBindingOut:
    _ensure_scene_bindings(db)
    if db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == body.scene_key).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="场景标识已存在")
    if body.scene_type not in {SCENE_TYPE_GENERATE, SCENE_TYPE_IMAGE_EDIT}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="目前仅支持新增文生图或图编辑场景")
    if not body.scene_label.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="场景名称不能为空")

    if body.api_config_id is not None:
        config = get_config_or_404(db, body.api_config_id)
        if config.status != "enabled":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只能绑定启用状态的接口")

    binding = ExternalApiSceneBinding(
        scene_key=body.scene_key,
        scene_type=body.scene_type,
        scene_label=body.scene_label,
        scene_description=body.scene_description,
        sort_order=body.sort_order,
        hide_aspect_ratio=body.hide_aspect_ratio,
        hide_resolution=body.hide_resolution,
        hide_custom_size=body.hide_custom_size,
        status=body.status,
        api_config_id=body.api_config_id,
        display_name=body.display_name,
        subtitle=body.subtitle,
        credit_cost=body.credit_cost,
        aspect_ratio_options_json=body.aspect_ratio_options_json,
        image_size_options_json=body.image_size_options_json,
        custom_size_options_json=body.custom_size_options_json,
    )
    db.add(binding)
    db.commit()
    config = get_config_or_404(db, body.api_config_id) if body.api_config_id else None
    return _serialize_scene_binding(binding, config)


def _require_custom_scene_binding(db: Session, scene_key: str) -> ExternalApiSceneBinding:
    _ensure_scene_bindings(db)
    binding = db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == scene_key).first()
    if not binding:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="调用场景不存在")
    if is_builtin_scene(scene_key):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="内置场景不支持此操作")
    return binding


def set_scene_binding(
    db: Session,
    scene_key: str,
    body: ExternalApiSceneBindingUpdate,
) -> ExternalApiSceneBindingOut:
    _ensure_scene_bindings(db)
    binding = db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == scene_key).first()
    if not binding:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="调用场景不存在")

    if body.api_config_id is not None:
        config = get_config_or_404(db, body.api_config_id)
        if config.status != "enabled":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="只能绑定启用状态的接口")

    binding.api_config_id = body.api_config_id
    binding.display_name = body.display_name
    binding.subtitle = body.subtitle
    binding.credit_cost = body.credit_cost
    db.commit()
    config = get_config_or_404(db, body.api_config_id) if body.api_config_id else None
    return _serialize_scene_binding(binding, config)


def update_scene_binding_meta(
    db: Session,
    scene_key: str,
    body: ExternalApiSceneBindingMetaUpdate,
) -> ExternalApiSceneBindingOut:
    binding = _require_custom_scene_binding(db, scene_key)
    if not body.scene_label.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="场景名称不能为空")
    binding.scene_label = body.scene_label
    binding.scene_description = body.scene_description
    binding.sort_order = body.sort_order
    binding.hide_aspect_ratio = body.hide_aspect_ratio
    binding.hide_resolution = body.hide_resolution
    binding.hide_custom_size = body.hide_custom_size
    binding.aspect_ratio_options_json = body.aspect_ratio_options_json
    binding.image_size_options_json = body.image_size_options_json
    binding.custom_size_options_json = body.custom_size_options_json
    db.commit()
    config = get_config_or_404(db, binding.api_config_id) if binding.api_config_id else None
    return _serialize_scene_binding(binding, config)


def set_scene_binding_status(
    db: Session,
    scene_key: str,
    body: ExternalApiSceneBindingStatusUpdate,
) -> ExternalApiSceneBindingOut:
    binding = _require_custom_scene_binding(db, scene_key)
    binding.status = body.status
    db.commit()
    config = get_config_or_404(db, binding.api_config_id) if binding.api_config_id else None
    return _serialize_scene_binding(binding, config)


def delete_scene_binding(db: Session, scene_key: str) -> None:
    binding = _require_custom_scene_binding(db, scene_key)
    db.delete(binding)
    db.commit()


def get_scene_credit_cost(db: Session, scene_key: str) -> int:
    _ensure_scene_bindings(db)
    binding = db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == scene_key).first()
    if not binding:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="不支持的调用场景")
    if binding.status != "enabled":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"场景 {scene_key} 已被停用")
    return binding.credit_cost


def require_scene_config(db: Session, scene_key: str) -> ExternalApiConfig:
    _ensure_scene_bindings(db)
    binding = db.query(ExternalApiSceneBinding).filter(ExternalApiSceneBinding.scene_key == scene_key).first()
    if not binding:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="不支持的调用场景")
    if binding.status != "enabled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"场景 {scene_key} 已被停用，请联系超级管理员调整",
        )
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


def build_secret_variables(db: Session) -> dict[str, str]:
    record = db.query(ApiKey).first()
    generation_key = (record.key or "").strip() if record else ""
    prompt_reverse_key = (record.tongyi_key or "").strip() if record else ""
    return {
        "api_key": generation_key,
        "bearer_token": prompt_reverse_key or generation_key,
    }


def _build_test_variables(db: Session) -> dict[str, Any]:
    one_pixel_png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+XGJ0AAAAASUVORK5CYII="
    return {
        "prompt": "连接测试",
        "aspect_ratio": "1:1",
        "image_size": "2K",
        "custom_size": "1024x1024",
        "contents_parts": [{"text": "连接测试"}],
        "generation_config": {"responseModalities": ["TEXT"]},
        "mode": "generate",
        "image_data_url": f"data:image/png;base64,{one_pixel_png}",
        "prompt_reverse_text": "请返回测试提示词",
        **build_secret_variables(db),
    }


def test_external_api_config(db: Session, body: ExternalApiConfigCreate) -> ExternalApiConfigTestResult:
    config = ExternalApiConfig(**body.model_dump())
    rendered = render_config(config, _build_test_variables(db))

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


def _pick_default_config_for_definition(db: Session, definition: dict[str, Any]) -> ExternalApiConfig | None:
    if definition["scene_type"] == SCENE_TYPE_GENERATE:
        return _pick_generation_config_for_scene(db, definition["scene_key"])
    if definition["scene_type"] == SCENE_TYPE_IMAGE_EDIT:
        source_scene_key = IMAGE_EDIT_SCENE_SOURCE_MAP.get(definition["scene_key"], SCENE_BANANA_PRO)
        return _pick_generation_config_for_scene(db, source_scene_key)
    if definition["scene_type"] == SCENE_TYPE_PROMPT_REVERSE:
        return _pick_prompt_reverse_config(db)
    if definition["scene_type"] == SCENE_TYPE_INPAINT:
        return _pick_inpaint_config(db)
    return None


def _ensure_scene_bindings(db: Session) -> None:
    bindings = db.query(ExternalApiSceneBinding).all()
    existing_map = {row.scene_key: row for row in bindings}
    if bindings:
        updated = False
        for binding in bindings:
            default_definition = DEFAULT_SCENE_MAP.get(binding.scene_key)
            default_cost = get_default_credit_cost(binding.scene_key, binding.scene_type)
            aspect_ratio_options_json, image_size_options_json, custom_size_options_json = _get_scene_option_json(
                binding.scene_type or SCENE_TYPE_GENERATE,
                binding.aspect_ratio_options_json,
                binding.image_size_options_json,
                binding.custom_size_options_json,
            )
            if binding.credit_cost is None:
                binding.credit_cost = default_cost
                updated = True
            if (binding.status or "").strip().lower() not in {"enabled", "disabled"}:
                binding.status = "enabled"
                updated = True
            if (binding.aspect_ratio_options_json or "") != aspect_ratio_options_json:
                binding.aspect_ratio_options_json = aspect_ratio_options_json
                updated = True
            if (binding.image_size_options_json or "") != image_size_options_json:
                binding.image_size_options_json = image_size_options_json
                updated = True
            if (binding.custom_size_options_json or "") != custom_size_options_json:
                binding.custom_size_options_json = custom_size_options_json
                updated = True
            if default_definition:
                if not (binding.scene_type or "").strip():
                    binding.scene_type = default_definition["scene_type"]
                    updated = True
                if is_builtin_scene(binding.scene_key):
                    if binding.scene_type != default_definition["scene_type"]:
                        binding.scene_type = default_definition["scene_type"]
                        updated = True
                    if (binding.scene_label or "").strip() != default_definition["scene_label"]:
                        binding.scene_label = default_definition["scene_label"]
                        updated = True
                    if (binding.scene_description or "").strip() != default_definition["scene_description"]:
                        binding.scene_description = default_definition["scene_description"]
                        updated = True
                    if int(binding.sort_order or 0) != int(default_definition["sort_order"]):
                        binding.sort_order = default_definition["sort_order"]
                        updated = True
                    if bool(binding.hide_aspect_ratio) != bool(default_definition["hide_aspect_ratio"]):
                        binding.hide_aspect_ratio = default_definition["hide_aspect_ratio"]
                        updated = True
                    if bool(binding.hide_resolution) != bool(default_definition["hide_resolution"]):
                        binding.hide_resolution = default_definition["hide_resolution"]
                        updated = True
                    if bool(binding.hide_custom_size) != bool(default_definition["hide_custom_size"]):
                        binding.hide_custom_size = default_definition["hide_custom_size"]
                        updated = True
                else:
                    if not (binding.scene_label or "").strip():
                        binding.scene_label = default_definition["scene_label"]
                        updated = True
                    if not (binding.scene_description or "").strip():
                        binding.scene_description = default_definition["scene_description"]
                        updated = True
                    if int(binding.sort_order or 0) <= 0:
                        binding.sort_order = default_definition["sort_order"]
                        updated = True
                    if binding.hide_aspect_ratio is None:
                        binding.hide_aspect_ratio = default_definition["hide_aspect_ratio"]
                        updated = True
                    if binding.hide_resolution is None:
                        binding.hide_resolution = default_definition["hide_resolution"]
                        updated = True
                    if binding.hide_custom_size is None:
                        binding.hide_custom_size = default_definition["hide_custom_size"]
                        updated = True
            else:
                if not (binding.scene_type or "").strip():
                    binding.scene_type = SCENE_TYPE_GENERATE
                    updated = True
                if not (binding.scene_label or "").strip():
                    binding.scene_label = binding.scene_key
                    updated = True
                if binding.hide_aspect_ratio is None:
                    binding.hide_aspect_ratio = False
                    updated = True
                if binding.hide_resolution is None:
                    binding.hide_resolution = False
                    updated = True
                if binding.hide_custom_size is None:
                    binding.hide_custom_size = True
                    updated = True
        for definition in DEFAULT_SCENE_DEFINITIONS:
            if definition["scene_key"] in existing_map:
                continue
            config = _pick_default_config_for_definition(db, definition)
            db.add(ExternalApiSceneBinding(
                scene_key=definition["scene_key"],
                scene_type=definition["scene_type"],
                scene_label=definition["scene_label"],
                scene_description=definition["scene_description"],
                sort_order=definition["sort_order"],
                hide_aspect_ratio=definition["hide_aspect_ratio"],
                hide_resolution=definition["hide_resolution"],
                hide_custom_size=definition["hide_custom_size"],
                api_config_id=config.id if config else None,
                credit_cost=get_default_credit_cost(definition["scene_key"], definition["scene_type"]),
                aspect_ratio_options_json=_get_scene_option_json(definition["scene_type"], None, None, None)[0],
                image_size_options_json=_get_scene_option_json(definition["scene_type"], None, None, None)[1],
                custom_size_options_json=_get_scene_option_json(definition["scene_type"], None, None, None)[2],
            ))
            updated = True
        if updated:
            db.commit()
        return

    for definition in DEFAULT_SCENE_DEFINITIONS:
        config = _pick_default_config_for_definition(db, definition)
        db.add(ExternalApiSceneBinding(
            scene_key=definition["scene_key"],
            scene_type=definition["scene_type"],
            scene_label=definition["scene_label"],
            scene_description=definition["scene_description"],
            sort_order=definition["sort_order"],
            hide_aspect_ratio=definition["hide_aspect_ratio"],
            hide_resolution=definition["hide_resolution"],
            hide_custom_size=definition["hide_custom_size"],
            api_config_id=config.id if config else None,
            credit_cost=get_default_credit_cost(definition["scene_key"], definition["scene_type"]),
            aspect_ratio_options_json=_get_scene_option_json(definition["scene_type"], None, None, None)[0],
            image_size_options_json=_get_scene_option_json(definition["scene_type"], None, None, None)[1],
            custom_size_options_json=_get_scene_option_json(definition["scene_type"], None, None, None)[2],
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
                response_json=_default_generation_response(),
                result_base64_field="candidates.0.content.parts.0.inlineData.data",
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
