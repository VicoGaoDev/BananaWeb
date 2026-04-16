import json
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, field_validator


StatusType = Literal["enabled", "disabled"]
SceneKeyType = Literal["banana", "banana2", "banana_pro", "banana_pro_plus", "prompt_reverse", "inpaint"]


def _validate_json_text(value: str, field_name: str, *, expect_object: bool) -> str:
    raw = (value or "").strip() or ("{}" if expect_object else "{}")
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"{field_name} 必须是合法 JSON: {exc.msg}") from exc

    if expect_object and not isinstance(parsed, dict):
        raise ValueError(f"{field_name} 必须是 JSON 对象")
    return json.dumps(parsed, ensure_ascii=False, indent=2)


class ExternalApiConfigBase(BaseModel):
    name: str
    description: str = ""
    group_name: str = "默认"
    request_url: str
    headers_json: str
    payload_json: str
    status: StatusType = "enabled"

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("名称不能为空")
        return cleaned

    @field_validator("request_url")
    @classmethod
    def validate_request_url(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("请求地址不能为空")
        return cleaned

    @field_validator("description")
    @classmethod
    def validate_description(cls, value: str) -> str:
        return value.strip()

    @field_validator("group_name")
    @classmethod
    def validate_group_name(cls, value: str) -> str:
        return value.strip()

    @field_validator("headers_json")
    @classmethod
    def validate_headers_json(cls, value: str) -> str:
        return _validate_json_text(value, "Header JSON", expect_object=True)

    @field_validator("payload_json")
    @classmethod
    def validate_payload_json(cls, value: str) -> str:
        return _validate_json_text(value, "请求 JSON", expect_object=False)

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        cleaned = value.strip().lower()
        if cleaned not in {"enabled", "disabled"}:
            raise ValueError("状态只能是 enabled 或 disabled")
        return cleaned


class ExternalApiConfigCreate(ExternalApiConfigBase):
    pass


class ExternalApiConfigUpdate(ExternalApiConfigBase):
    pass


class ExternalApiConfigStatusUpdate(BaseModel):
    status: StatusType

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        return value.strip().lower()


class ExternalApiConfigOut(BaseModel):
    id: int
    name: str
    description: str
    group_name: str
    request_url: str
    headers_json: str
    payload_json: str
    status: StatusType
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class RenderedExternalApiConfig(BaseModel):
    request_url: str
    headers: dict[str, str]
    payload: Any


class GenerationModelOptionOut(BaseModel):
    model_key: str
    model_label: str
    model_description: str
    display_name: str
    subtitle: str
    sort_order: int
    hide_resolution: bool
    credit_cost: int


class ExternalApiSceneBindingUpdate(BaseModel):
    api_config_id: int | None = None
    display_name: str = ""
    subtitle: str = ""
    credit_cost: int

    @field_validator("display_name", "subtitle")
    @classmethod
    def validate_scene_text(cls, value: str) -> str:
        return value.strip()

    @field_validator("credit_cost")
    @classmethod
    def validate_credit_cost(cls, value: int) -> int:
        if value < 0:
            raise ValueError("积分消耗不能小于 0")
        return value


class ExternalApiSceneBindingOut(BaseModel):
    scene_key: SceneKeyType
    scene_label: str
    scene_description: str
    display_name: str
    subtitle: str
    sort_order: int
    hide_resolution: bool
    api_config_id: int | None = None
    api_config_name: str = ""
    api_group_name: str = ""
    api_status: StatusType | None = None
    credit_cost: int


class TaskSceneConfigOut(BaseModel):
    scene_key: SceneKeyType
    scene_label: str
    scene_description: str
    display_name: str
    subtitle: str
    sort_order: int
    hide_resolution: bool
    credit_cost: int


class ExternalApiConfigTestResult(BaseModel):
    success: bool
    request_url: str
    status_code: int | None = None
    response_preview: str
