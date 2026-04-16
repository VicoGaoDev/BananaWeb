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
    task_id: int | None = None
    task_ids: list[int] = Field(default_factory=list)


class ImageOut(BaseModel):
    id: int
    image_url: str
    preview_url: str = ""
    thumb_url: str = ""
    status: str
    error_message: str = ""
    image_format: str = ""
    image_size_bytes: int = 0

    model_config = {"from_attributes": True}


class TaskOut(BaseModel):
    id: int
    mode: str = "generate"
    model: str = ""
    prompt: str = ""
    num_images: int = 4
    size: str
    resolution: str = ""
    credit_cost: int = 0
    status: str
    error_message: str = ""
    created_at: datetime | None = None
    images: list[ImageOut] = []

    model_config = {"from_attributes": True}
