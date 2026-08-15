from datetime import datetime

from pydantic import BaseModel, Field, field_validator, model_validator


class ChatSessionCreate(BaseModel):
    title: str = ""
    model: str

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return (value or "").strip()[:100]

    @field_validator("model")
    @classmethod
    def validate_model(cls, value: str) -> str:
        cleaned = (value or "").strip().lower()
        if not cleaned:
            raise ValueError("请选择对话模型")
        return cleaned


class ChatSessionUpdate(BaseModel):
    title: str | None = None
    model: str | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return (value or "").strip()[:100]

    @field_validator("model")
    @classmethod
    def validate_model(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = (value or "").strip().lower()
        if not cleaned:
            raise ValueError("请选择对话模型")
        return cleaned


class ChatSessionOut(BaseModel):
    id: str
    title: str
    model: str
    last_message_at: datetime | None = None
    created_at: datetime
    updated_at: datetime | None = None


class ChatSessionListOut(BaseModel):
    items: list[ChatSessionOut]
    total: int
    page: int
    page_size: int
    has_more: bool


MAX_CHAT_IMAGES = 4


class ChatImagePart(BaseModel):
    url: str = Field(min_length=1, max_length=2000)

    @field_validator("url")
    @classmethod
    def validate_url(cls, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise ValueError("图片地址不能为空")
        if len(cleaned) > 2000:
            raise ValueError("图片地址过长")
        lowered = cleaned.lower()
        if not (lowered.startswith("http://") or lowered.startswith("https://")):
            raise ValueError("图片地址必须是 http/https URL")
        return cleaned


class ChatMessageOut(BaseModel):
    id: int
    session_id: str
    role: str
    content: str
    images: list[ChatImagePart] = Field(default_factory=list)
    model: str
    client_message_id: str | None = None
    credit_cost: int = 0
    status: str
    error_message: str = ""
    created_at: datetime


class ChatMessageListOut(BaseModel):
    items: list[ChatMessageOut]
    has_more: bool
    next_before_id: int | None = None


class ChatSendMessageRequest(BaseModel):
    content: str = Field(default="", max_length=10000)
    images: list[ChatImagePart] = Field(default_factory=list)
    model: str | None = None
    client_message_id: str = Field(min_length=8, max_length=64)

    @field_validator("content")
    @classmethod
    def validate_content(cls, value: str) -> str:
        cleaned = (value or "").strip()
        if len(cleaned) > 10000:
            raise ValueError("消息内容不能超过 10000 字符")
        return cleaned

    @field_validator("images")
    @classmethod
    def validate_images(cls, value: list[ChatImagePart] | None) -> list[ChatImagePart]:
        items = list(value or [])
        if len(items) > MAX_CHAT_IMAGES:
            raise ValueError(f"一次最多上传 {MAX_CHAT_IMAGES} 张图片")
        seen: set[str] = set()
        unique: list[ChatImagePart] = []
        for item in items:
            if item.url in seen:
                continue
            seen.add(item.url)
            unique.append(item)
        return unique

    @model_validator(mode="after")
    def validate_content_or_images(self) -> "ChatSendMessageRequest":
        if not self.content and not self.images:
            raise ValueError("请输入消息或上传图片")
        return self

    @field_validator("model")
    @classmethod
    def validate_model(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = (value or "").strip().lower()
        if not cleaned:
            raise ValueError("请选择对话模型")
        return cleaned

    @field_validator("client_message_id")
    @classmethod
    def validate_client_message_id(cls, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise ValueError("client_message_id 不能为空")
        return cleaned[:64]


class ChatSendMessageResponse(BaseModel):
    user_message: ChatMessageOut
    assistant_message: ChatMessageOut
    credit_cost: int = 0
    balance: int | None = None
    session: ChatSessionOut
