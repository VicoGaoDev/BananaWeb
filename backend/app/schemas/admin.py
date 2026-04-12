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
    credits: int = 0
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class AllocateCreditsRequest(BaseModel):
    amount: int
    description: str = ""


class CreditLogOut(BaseModel):
    id: int
    user_id: int
    username: str = ""
    amount: int
    type: str
    description: str = ""
    operator_name: str = ""
    task_id: int | None = None
    created_at: datetime | None = None


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
