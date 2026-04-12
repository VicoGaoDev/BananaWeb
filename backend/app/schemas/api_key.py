from pydantic import BaseModel
from datetime import datetime


class ApiKeyOut(BaseModel):
    id: int
    key: str
    tongyi_key: str = ""
    contact_qr_image: str = ""
    announcement_enabled: bool = False
    announcement_content: str = ""
    announcement_updated_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class ApiKeyUpdate(BaseModel):
    key: str = ""
    tongyi_key: str = ""
    contact_qr_image: str = ""
    announcement_enabled: bool = False
    announcement_content: str = ""


class AnnouncementConfigOut(BaseModel):
    announcement_enabled: bool = False
    announcement_content: str = ""
    announcement_updated_at: datetime | None = None
