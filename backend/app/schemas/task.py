from pydantic import BaseModel, Field
from datetime import datetime


class TaskCreate(BaseModel):
    prompt: str
    num_images: int = Field(default=4, ge=1, le=8)
    size: str = "3:4"
    resolution: str = "4K"
    reference_images: list[str] | None = None


class TaskCreateResponse(BaseModel):
    task_id: int


class ImageOut(BaseModel):
    id: int
    image_url: str
    status: str

    model_config = {"from_attributes": True}


class TaskOut(BaseModel):
    id: int
    prompt: str = ""
    num_images: int = 4
    size: str
    status: str
    created_at: datetime | None = None
    images: list[ImageOut] = []

    model_config = {"from_attributes": True}
