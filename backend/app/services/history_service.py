from sqlalchemy.orm import Session
from app.models.task import Task
from app.models.style import Style


def get_user_history(db: Session, user_id: int, page: int = 1, page_size: int = 20):
    query = db.query(Task).filter(Task.user_id == user_id).order_by(Task.created_at.desc())
    total = query.count()
    tasks = query.offset((page - 1) * page_size).limit(page_size).all()

    items = []
    for task in tasks:
        style = db.query(Style).filter(Style.id == task.style_id).first()
        items.append({
            "task_id": task.id,
            "style_name": style.name if style else "未知",
            "model": task.model,
            "size": task.size,
            "status": task.status,
            "created_at": task.created_at,
            "images": [
                {"id": img.id, "image_url": img.image_url, "status": img.status}
                for img in task.images
            ],
        })

    return {"total": total, "items": items}


def get_all_history(db: Session, page: int = 1, page_size: int = 20):
    query = db.query(Task).order_by(Task.created_at.desc())
    total = query.count()
    tasks = query.offset((page - 1) * page_size).limit(page_size).all()

    items = []
    for task in tasks:
        style = db.query(Style).filter(Style.id == task.style_id).first()
        items.append({
            "task_id": task.id,
            "style_name": style.name if style else "未知",
            "model": task.model,
            "size": task.size,
            "status": task.status,
            "created_at": task.created_at,
            "images": [
                {"id": img.id, "image_url": img.image_url, "status": img.status}
                for img in task.images
            ],
        })

    return {"total": total, "items": items}
