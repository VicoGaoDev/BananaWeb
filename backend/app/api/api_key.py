from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import require_admin
from app.models.user import User
from app.models.api_key import ApiKey
from app.schemas.api_key import ApiKeyOut, ApiKeyUpdate

router = APIRouter(prefix="/api/admin/api-key", tags=["API Key 管理"])


@router.get("", response_model=ApiKeyOut | None)
def get_api_key(
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(ApiKey).first()


@router.put("", response_model=ApiKeyOut)
def set_api_key(
    body: ApiKeyUpdate,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    record = db.query(ApiKey).first()
    if record:
        record.key = body.key
    else:
        record = ApiKey(key=body.key)
        db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.delete("")
def delete_api_key(
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    record = db.query(ApiKey).first()
    if record:
        db.delete(record)
        db.commit()
    return {"detail": "已删除"}
