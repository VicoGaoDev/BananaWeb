from pydantic import BaseModel
from datetime import datetime


class TaskCreate(BaseModel):
    style_id: int
    model: str = "banana-pro"
    size: str = "3:4"
    resolution: str = "4K"
    reference_image: str = ""


class TaskCreateResponse(BaseModel):
    task_id: int


class ImageOut(BaseModel):
    id: int
    image_url: str
    status: str

    model_config = {"from_attributes": True}


class TaskOut(BaseModel):
    id: int
    style_id: int
    model: str
    size: str
    status: str
    created_at: datetime | None = None
    images: list[ImageOut] = []

    model_config = {"from_attributes": True}
