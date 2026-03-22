from pydantic import BaseModel
from datetime import datetime


class CreateUserRequest(BaseModel):
    username: str
    password: str
    role: str = "user"


class UserOut(BaseModel):
    id: int
    username: str
    avatar_url: str = ""
    role: str
    status: str
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class UpdateStatusRequest(BaseModel):
    status: str  # "active" | "disabled"


class UpdateRoleRequest(BaseModel):
    role: str  # "user" | "admin"


class ResetPasswordRequest(BaseModel):
    new_password: str


class StatsOut(BaseModel):
    last_7_days: int
    last_30_days: int
    total_users: int
    active_users: int
