from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.history import HistoryResponse
from app.services.history_service import delete_user_history_task, get_user_history

router = APIRouter(prefix="/api/history", tags=["历史记录"])


@router.get("", response_model=HistoryResponse)
def list_history(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_user_history(db, user.id, page, page_size)


@router.delete("/{task_id}")
def delete_history(
    task_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ok = delete_user_history_task(db, user.id, task_id)
    if not ok:
        raise HTTPException(status_code=404, detail="任务不存在")
    return {"message": "删除成功"}
