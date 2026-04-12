from datetime import datetime
from pydantic import BaseModel, Field


class TemplateTagOut(BaseModel):
    id: int
    name: str

    model_config = {"from_attributes": True}


class TemplateBase(BaseModel):
    prompt: str
    model: str = "banana_pro"
    reference_images: list[str] = []
    size: str = "1:1"
    resolution: str = "2K"
    num_images: int = Field(default=1, ge=1, le=6)
    result_image: str = ""
    tag_names: list[str] = []


class TemplateCreate(TemplateBase):
    pass


class TemplateUpdate(TemplateBase):
    pass


class TemplateListItemOut(BaseModel):
    id: int
    prompt: str
    model: str = ""
    result_image: str
    size: str
    resolution: str
    num_images: int
    tags: list[TemplateTagOut]
    created_at: datetime | None = None


class TemplateDetailOut(BaseModel):
    id: int
    prompt: str
    model: str = ""
    reference_images: list[str] = []
    size: str
    resolution: str
    num_images: int
    result_image: str
    tags: list[TemplateTagOut]
    created_at: datetime | None = None
