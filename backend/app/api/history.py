from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.history import UserHistoryResponse
from app.services.history_service import get_user_history

router = APIRouter(prefix="/api/history", tags=["历史记录"])


@router.get("", response_model=UserHistoryResponse)
def list_history(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    mode: str | None = Query(None, pattern="^(generate|inpaint)$"),
    model: str | None = Query(None),
    prompt: str | None = Query(None),
    status: str | None = Query(None, pattern="^(pending|processing|success|failed)$"),
    start_date: datetime | None = Query(None),
    end_date: datetime | None = Query(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_user_history(
        db,
        user.id,
        page,
        page_size,
        mode=mode,
        model=model,
        prompt=prompt,
        status=status,
        start_date=start_date,
        end_date=end_date,
    )
