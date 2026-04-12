from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import require_admin
from app.models.user import User
from app.models.api_key import ApiKey
from app.schemas.api_key import AnnouncementConfigOut, ApiKeyOut, ApiKeyUpdate

router = APIRouter(prefix="/api/admin/api-key", tags=["API Key 管理"])
public_router = APIRouter(prefix="/api/config", tags=["公开配置"])


@public_router.get("/contact")
def get_contact_config(db: Session = Depends(get_db)):
    record = db.query(ApiKey).first()
    return {"contact_qr_image": record.contact_qr_image if record else ""}


@public_router.get("/announcement", response_model=AnnouncementConfigOut)
def get_announcement_config(db: Session = Depends(get_db)):
    record = db.query(ApiKey).first()
    if not record:
        return AnnouncementConfigOut()
    return AnnouncementConfigOut(
        announcement_enabled=bool(record.announcement_enabled),
        announcement_content=record.announcement_content or "",
        announcement_updated_at=record.announcement_updated_at,
    )


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
    normalized_announcement_content = body.announcement_content.strip()
    if record:
        announcement_changed = (
            bool(record.announcement_enabled) != bool(body.announcement_enabled)
            or (record.announcement_content or "") != normalized_announcement_content
        )
        record.key = body.key
        record.tongyi_key = body.tongyi_key
        record.contact_qr_image = body.contact_qr_image
        record.announcement_enabled = 1 if body.announcement_enabled else 0
        record.announcement_content = normalized_announcement_content
        if announcement_changed:
            record.announcement_updated_at = datetime.utcnow()
    else:
        record = ApiKey(
            key=body.key,
            tongyi_key=body.tongyi_key,
            contact_qr_image=body.contact_qr_image,
            announcement_enabled=1 if body.announcement_enabled else 0,
            announcement_content=normalized_announcement_content,
            announcement_updated_at=datetime.utcnow() if (body.announcement_enabled or normalized_announcement_content) else None,
        )
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
