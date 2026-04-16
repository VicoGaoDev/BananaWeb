from pydantic import BaseModel
from datetime import datetime


class HistoryImageOut(BaseModel):
    id: int
    image_url: str
    preview_url: str = ""
    thumb_url: str = ""
    status: str
    error_message: str = ""
    image_format: str = ""
    image_size_bytes: int = 0
    is_deleted: bool = False

    model_config = {"from_attributes": True}


class HistoryItem(BaseModel):
    task_id: int
    username: str = ""
    avatar_url: str = ""
    model: str = ""
    mode: str = "generate"
    prompt: str = ""
    reference_images: list[str] = []
    num_images: int = 1
    size: str
    resolution: str = ""
    credit_cost: int = 0
    status: str
    is_soft_deleted: bool = False
    soft_deleted_count: int = 0
    created_at: datetime | None = None
    images: list[HistoryImageOut] = []


class HistoryResponse(BaseModel):
    total: int
    total_credit_cost: int = 0
    items: list[HistoryItem]


class UserHistoryCardItem(BaseModel):
    task_id: int
    image_id: int
    image_url: str = ""
    preview_url: str = ""
    thumb_url: str = ""
    status: str
    image_format: str = ""
    image_size_bytes: int = 0
    is_soft_deleted: bool = False
    model: str = ""
    mode: str = "generate"
    prompt: str = ""
    reference_images: list[str] = []
    reference_image_thumbs: list[str] = []
    source_image: str = ""
    source_image_thumb: str = ""
    num_images: int = 1
    size: str
    resolution: str = ""
    credit_cost: int = 0
    created_at: datetime | None = None
    error_message: str = ""
    images: list[HistoryImageOut] = []


class UserHistoryResponse(BaseModel):
    total: int
    items: list[UserHistoryCardItem]
