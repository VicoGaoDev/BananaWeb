from pydantic import BaseModel
from datetime import datetime


class HistoryImageOut(BaseModel):
    id: int
    image_url: str
    status: str

    model_config = {"from_attributes": True}


class HistoryItem(BaseModel):
    task_id: int
    username: str = ""
    avatar_url: str = ""
    model: str = ""
    prompt: str = ""
    reference_images: list[str] = []
    num_images: int = 1
    size: str
    resolution: str = ""
    status: str
    created_at: datetime | None = None
    images: list[HistoryImageOut] = []


class HistoryResponse(BaseModel):
    total: int
    items: list[HistoryItem]
