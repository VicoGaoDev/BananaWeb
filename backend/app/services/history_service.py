import json
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session
from app.models.task import Task
from app.models.user import User
from app.models.image import Image
from app.models.regenerate_log import RegenerateLog
from app.models.credit_log import CreditLog


def _parse_refs(raw: str | None) -> list[str]:
    if not raw:
        return []
    try:
        refs = json.loads(raw)
        return refs if isinstance(refs, list) else []
    except (json.JSONDecodeError, TypeError):
        return []


def get_user_history(db: Session, user_id: int, page: int = 1, page_size: int = 20):
    query = db.query(Task).filter(Task.user_id == user_id).order_by(Task.created_at.desc())
    total = query.count()
    tasks = query.offset((page - 1) * page_size).limit(page_size).all()

    items = []
    for task in tasks:
        items.append({
            "task_id": task.id,
            "model": task.model or "",
            "prompt": task.prompt or "",
            "reference_images": _parse_refs(task.reference_images),
            "num_images": task.num_images,
            "size": task.size,
            "resolution": task.resolution or "",
            "status": task.status,
            "created_at": task.created_at,
            "images": [
                {"id": img.id, "image_url": img.image_url, "status": img.status}
                for img in task.images
            ],
        })

    return {"total": total, "items": items}


def delete_user_history_task(db: Session, user_id: int, task_id: int):
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == user_id).first()
    if not task:
        return False

    image_ids = [img.id for img in task.images]
    if image_ids:
        db.query(RegenerateLog).filter(RegenerateLog.image_id.in_(image_ids)).delete(synchronize_session=False)
        for image in list(task.images):
            db.delete(image)

    db.query(CreditLog).filter(CreditLog.task_id == task_id).update(
        {"task_id": None},
        synchronize_session=False,
    )
    db.delete(task)
    db.commit()
    return True


def get_all_history(
    db: Session,
    page: int = 1,
    page_size: int = 20,
    status: Optional[str] = None,
    user_id: Optional[int] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
):
    query = db.query(Task).order_by(Task.created_at.desc())

    if status:
        query = query.filter(Task.status == status)
    if user_id:
        query = query.filter(Task.user_id == user_id)
    if start_date:
        query = query.filter(Task.created_at >= start_date)
    if end_date:
        query = query.filter(Task.created_at <= end_date)

    total = query.count()
    tasks = query.offset((page - 1) * page_size).limit(page_size).all()

    user_cache: dict[int, dict[str, str]] = {}
    items = []
    for task in tasks:
        if task.user_id not in user_cache:
            u = db.query(User).filter(User.id == task.user_id).first()
            user_cache[task.user_id] = {
                "username": u.username if u else "未知",
                "avatar_url": (u.avatar_url or "") if u else "",
            }

        items.append({
            "task_id": task.id,
            "username": user_cache[task.user_id]["username"],
            "avatar_url": user_cache[task.user_id]["avatar_url"],
            "model": task.model or "",
            "prompt": task.prompt or "",
            "reference_images": _parse_refs(task.reference_images),
            "num_images": task.num_images,
            "size": task.size,
            "resolution": task.resolution or "",
            "status": task.status,
            "created_at": task.created_at,
            "images": [
                {"id": img.id, "image_url": img.image_url, "status": img.status}
                for img in task.images
            ],
        })

    return {"total": total, "items": items}
