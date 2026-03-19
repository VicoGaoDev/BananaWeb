from pydantic import BaseModel
from datetime import datetime


class ApiKeyOut(BaseModel):
    id: int
    key: str
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class ApiKeyUpdate(BaseModel):
    key: str
