from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.auth import LoginRequest, LoginResponse, UserBrief, ChangePasswordRequest
from app.services.auth_service import authenticate_user, change_password

router = APIRouter(prefix="/api/auth", tags=["认证"])


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    token, user = authenticate_user(db, body.username, body.password)
    return LoginResponse(
        token=token,
        user=UserBrief(id=user.id, username=user.username, role=user.role),
    )


@router.post("/change-password")
def change_pwd(
    body: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    change_password(db, user, body.old_password, body.new_password)
    return {"message": "密码修改成功"}


@router.get("/me", response_model=UserBrief)
def get_me(user: User = Depends(get_current_user)):
    return UserBrief(id=user.id, username=user.username, role=user.role)
