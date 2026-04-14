from datetime import datetime

from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.image import Image
from app.models.regenerate_log import RegenerateLog


def get_image(db: Session, image_id: int) -> Image:
    image = db.query(Image).filter(Image.id == image_id, Image.is_deleted.is_(False)).first()
    if not image:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="图片不存在")
    return image


def request_regenerate(db: Session, image_id: int, user_id: int) -> Image:
    image = db.query(Image).filter(Image.id == image_id, Image.is_deleted.is_(False)).first()
    if not image:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="图片不存在")

    if image.task.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权操作此图片")

    log = RegenerateLog(image_id=image.id, old_image_url=image.image_url)
    db.add(log)

    image.task.status = "processing"
    image.status = "pending"
    image.image_url = ""
    image.preview_url = ""
    db.commit()
    db.refresh(image)
    return image


def delete_image_for_user(db: Session, image_id: int, user_id: int) -> bool:
    image = db.query(Image).filter(Image.id == image_id).first()
    if not image:
        return False
    if image.task.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权操作此图片")
    if image.is_deleted:
        return True

    db.query(RegenerateLog).filter(RegenerateLog.image_id == image.id).delete(synchronize_session=False)
    image.is_deleted = True
    image.deleted_at = datetime.utcnow()
    db.commit()
    return True
