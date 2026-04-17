from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import require_admin, require_superadmin
from app.models.user import User
from app.schemas.admin import (
    CreateUserRequest, UserOut, UpdateStatusRequest, UpdateRoleRequest,
    UpdateWhitelistRequest, ResetPasswordRequest, StatsOut, AllocateCreditsRequest, CreditLogOut,
    AnalyticsSummaryOut, AnalyticsTimeseriesOut, AnalyticsBreakdownOut,
)
from app.schemas.history import HistoryResponse
from app.services.admin_service import (
    create_user, list_users, update_user_status, update_user_role,
    update_user_whitelist, reset_user_password, get_stats, allocate_credits, get_credit_logs,
    get_analytics_summary, get_analytics_timeseries, get_analytics_breakdown,
)
from app.services.history_service import get_all_history

router = APIRouter(prefix="/api/admin", tags=["管理员"])


@router.post("/users", response_model=UserOut)
def admin_create_user(
    body: CreateUserRequest,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return create_user(db, body.username, body.password, body.role, operator=_user)


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
    _user: User = Depends(require_superadmin),
    db: Session = Depends(get_db),
):
    return update_user_status(db, user_id, body.status)


@router.put("/users/{user_id}/role", response_model=UserOut)
def admin_update_role(
    user_id: int,
    body: UpdateRoleRequest,
    _user: User = Depends(require_superadmin),
    db: Session = Depends(get_db),
):
    return update_user_role(db, user_id, body.role)


@router.put("/users/{user_id}/whitelist", response_model=UserOut)
def admin_update_whitelist(
    user_id: int,
    body: UpdateWhitelistRequest,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return update_user_whitelist(db, user_id, body.is_whitelisted)


@router.put("/users/{user_id}/reset-password", response_model=UserOut)
def admin_reset_password(
    user_id: int,
    body: ResetPasswordRequest,
    _user: User = Depends(require_superadmin),
    db: Session = Depends(get_db),
):
    return reset_user_password(db, user_id, body.new_password)


@router.post("/users/{user_id}/credits", response_model=UserOut)
def admin_allocate_credits(
    user_id: int,
    body: AllocateCreditsRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return allocate_credits(db, user_id, body.amount, body.description, admin.id)


@router.get("/credit-logs", response_model=dict)
def admin_credit_logs(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: Optional[int] = Query(None),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_credit_logs(db, user_id=user_id, page=page, page_size=page_size,
                           start_date=start_date, end_date=end_date)


@router.get("/stats", response_model=StatsOut)
def admin_stats(
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_stats(db)


@router.get("/analytics/summary", response_model=AnalyticsSummaryOut)
def admin_analytics_summary(
    granularity: str = Query("day", pattern="^(day|week|month)$"),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    user_id: Optional[int] = Query(None),
    model: Optional[str] = Query(None),
    mode: Optional[str] = Query(None, pattern="^(generate|inpaint)$"),
    status: Optional[str] = Query(None),
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_analytics_summary(
        db,
        granularity=granularity,
        start_date=start_date,
        end_date=end_date,
        user_id=user_id,
        model=model,
        mode=mode,
        status_filter=status,
    )


@router.get("/analytics/timeseries", response_model=AnalyticsTimeseriesOut)
def admin_analytics_timeseries(
    granularity: str = Query("day", pattern="^(day|week|month)$"),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    user_id: Optional[int] = Query(None),
    model: Optional[str] = Query(None),
    mode: Optional[str] = Query(None, pattern="^(generate|inpaint)$"),
    status: Optional[str] = Query(None),
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_analytics_timeseries(
        db,
        granularity=granularity,
        start_date=start_date,
        end_date=end_date,
        user_id=user_id,
        model=model,
        mode=mode,
        status_filter=status,
    )


@router.get("/analytics/breakdown", response_model=AnalyticsBreakdownOut)
def admin_analytics_breakdown(
    granularity: str = Query("day", pattern="^(day|week|month)$"),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    user_id: Optional[int] = Query(None),
    model: Optional[str] = Query(None),
    mode: Optional[str] = Query(None, pattern="^(generate|inpaint)$"),
    status: Optional[str] = Query(None),
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_analytics_breakdown(
        db,
        granularity=granularity,
        start_date=start_date,
        end_date=end_date,
        user_id=user_id,
        model=model,
        mode=mode,
        status_filter=status,
    )


@router.get("/history", response_model=HistoryResponse)
def admin_history(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None),
    user_id: Optional[int] = Query(None),
    model: Optional[str] = Query(None),
    mode: Optional[str] = Query(None, pattern="^(generate|inpaint)$"),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_all_history(
        db, page, page_size,
        status=status, user_id=user_id,
        model=model, mode=mode,
        start_date=start_date, end_date=end_date,
    )
