from pydantic import BaseModel, Field
from datetime import datetime


class TaskCreate(BaseModel):
    mode: str = "generate"
    model: str = ""
    prompt: str
    num_images: int = Field(default=4, ge=1, le=8)
    size: str = "3:4"
    resolution: str = "4K"
    reference_images: list[str] | None = None
    source_image: str = ""
    mask_image: str = ""


class TaskCreateResponse(BaseModel):
    task_id: int


class ImageOut(BaseModel):
    id: int
    image_url: str
    preview_url: str = ""
    status: str

    model_config = {"from_attributes": True}


class TaskOut(BaseModel):
    id: int
    mode: str = "generate"
    model: str = ""
    prompt: str = ""
    num_images: int = 4
    size: str
    resolution: str = ""
    status: str
    created_at: datetime | None = None
    images: list[ImageOut] = []

    model_config = {"from_attributes": True}
