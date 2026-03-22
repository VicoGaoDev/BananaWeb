from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import require_admin, require_superadmin
from app.models.user import User
from app.schemas.admin import (
    CreateUserRequest, UserOut, UpdateStatusRequest, UpdateRoleRequest,
    ResetPasswordRequest, StatsOut,
)
from app.schemas.history import HistoryResponse
from app.services.admin_service import (
    create_user, list_users, update_user_status, update_user_role,
    reset_user_password, get_stats,
)
from app.services.history_service import get_all_history

router = APIRouter(prefix="/api/admin", tags=["管理员"])


@router.post("/users", response_model=UserOut)
def admin_create_user(
    body: CreateUserRequest,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return create_user(db, body.username, body.password, body.role)


@router.get("/users", response_model=list[UserOut])
def admin_list_users(
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return list_users(db)


@router.put("/users/{user_id}/status", response_model=UserOut)
def admin_update_status(
    user_id: int,
    body: UpdateStatusRequest,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return update_user_status(db, user_id, body.status)


@router.put("/users/{user_id}/role", response_model=UserOut)
def admin_update_role(
    user_id: int,
    body: UpdateRoleRequest,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return update_user_role(db, user_id, body.role)


@router.put("/users/{user_id}/reset-password", response_model=UserOut)
def admin_reset_password(
    user_id: int,
    body: ResetPasswordRequest,
    _user: User = Depends(require_superadmin),
    db: Session = Depends(get_db),
):
    return reset_user_password(db, user_id, body.new_password)


@router.get("/stats", response_model=StatsOut)
def admin_stats(
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_stats(db)


@router.get("/history", response_model=HistoryResponse)
def admin_history(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None),
    user_id: Optional[int] = Query(None),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_all_history(
        db, page, page_size,
        status=status, user_id=user_id,
        start_date=start_date, end_date=end_date,
    )
