import json
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session
from app.models.task import Task
from app.models.user import User


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
            "prompt": task.prompt or "",
            "reference_images": _parse_refs(task.reference_images),
            "size": task.size,
            "status": task.status,
            "created_at": task.created_at,
            "images": [
                {"id": img.id, "image_url": img.image_url, "status": img.status}
                for img in task.images
            ],
        })

    return {"total": total, "items": items}


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
            "prompt": task.prompt or "",
            "reference_images": _parse_refs(task.reference_images),
            "size": task.size,
            "status": task.status,
            "created_at": task.created_at,
            "images": [
                {"id": img.id, "image_url": img.image_url, "status": img.status}
                for img in task.images
            ],
        })

    return {"total": total, "items": items}
