import json
from datetime import datetime
from typing import Optional

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session, selectinload
from app.models.task import Task
from app.models.image import Image
from app.models.regenerate_log import RegenerateLog
from app.models.credit_log import CreditLog
from app.models.user import User
from app.services.image_delivery_service import (
    get_optional_cos_config,
    serialize_asset_urls,
    serialize_image,
)


def _parse_refs(raw: str | None) -> list[str]:
    if not raw:
        return []
    try:
        refs = json.loads(raw)
        return refs if isinstance(refs, list) else []
    except (json.JSONDecodeError, TypeError):
        return []


def _resolve_history_card_status(task_status: str | None, image_status: str | None) -> str:
    if image_status == "pending" and task_status in {"pending", "processing", "failed"}:
        return task_status
    return image_status or task_status or "pending"


def _serialize_history_images(
    images: list[Image],
    *,
    cos_config,
    include_deleted: bool = False,
) -> list[dict]:
    result: list[dict] = []
    for img in sorted(images, key=lambda item: item.id, reverse=True):
        if not include_deleted and img.is_deleted:
            continue
        result.append(serialize_image(img, cos_config=cos_config))
    return result


def get_user_history(
    db: Session,
    user_id: int,
    page: int = 1,
    page_size: int = 20,
    mode: str | None = None,
    model: str | None = None,
    prompt: str | None = None,
    status: str | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
):
    cos_config = get_optional_cos_config(db)
    query = (
        db.query(Image)
        .join(Task, Image.task_id == Task.id)
        .options(selectinload(Image.task).selectinload(Task.images))
        .filter(Task.user_id == user_id)
        .filter(Image.is_deleted.is_(False))
    )
    if mode:
        query = query.filter(Task.mode == mode)
    if model:
        query = query.filter(Task.model == model)
    if prompt:
        keyword = prompt.strip()
        if keyword:
            query = query.filter(Task.prompt.ilike(f"%{keyword}%"))
    if status:
        if status == "processing":
            query = query.filter(Image.status == "pending", Task.status == "processing")
        elif status == "pending":
            query = query.filter(Image.status == "pending", Task.status == "pending")
        elif status == "failed":
            query = query.filter(or_(Image.status == "failed", and_(Image.status == "pending", Task.status == "failed")))
        else:
            query = query.filter(Image.status == status)
    if start_date:
        query = query.filter(Task.created_at >= start_date)
    if end_date:
        query = query.filter(Task.created_at <= end_date)
    query = query.order_by(Task.created_at.desc(), Image.id.desc())
    total = query.count()
    images = query.offset((page - 1) * page_size).limit(page_size).all()

    items = []
    for image in images:
        task = image.task
        image_payload = serialize_image(image, cos_config=cos_config)
        source_asset = serialize_asset_urls(task.source_image or "", cos_config=cos_config)
        reference_assets = [serialize_asset_urls(ref, cos_config=cos_config) for ref in _parse_refs(task.reference_images)]
        visible_images = _serialize_history_images(task.images, cos_config=cos_config)
        items.append({
            "task_id": task.id,
            "image_id": image.id,
            "image_url": image_payload["image_url"],
            "preview_url": image_payload["preview_url"],
            "thumb_url": image_payload["thumb_url"],
            "status": _resolve_history_card_status(task.status, image.status),
            "image_format": image_payload["image_format"],
            "image_size_bytes": image_payload["image_size_bytes"],
            "is_soft_deleted": False,
            "model": task.model or "",
            "mode": task.mode or "generate",
            "prompt": task.prompt or "",
            "reference_images": [asset["image_url"] for asset in reference_assets],
            "reference_image_thumbs": [asset["thumb_url"] for asset in reference_assets],
            "source_image": source_asset["image_url"],
            "source_image_thumb": source_asset["thumb_url"],
            "num_images": task.num_images,
            "size": task.size,
            "resolution": task.resolution or "",
            "credit_cost": int(task.credit_cost or 0),
            "created_at": task.created_at,
            "error_message": task.error_message or "",
            "images": visible_images,
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
    model: Optional[str] = None,
    mode: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
):
    cos_config = get_optional_cos_config(db)
    base_query = (
        db.query(Task)
        .join(User, User.id == Task.user_id)
        .filter(User.role != "superadmin", User.is_whitelisted.is_(False))
    )

    if status:
        base_query = base_query.filter(Task.status == status)
    if user_id:
        base_query = base_query.filter(Task.user_id == user_id)
    if model:
        base_query = base_query.filter(Task.model == model)
    if mode:
        base_query = base_query.filter(Task.mode == mode)
    if start_date:
        base_query = base_query.filter(Task.created_at >= start_date)
    if end_date:
        base_query = base_query.filter(Task.created_at <= end_date)

    total = base_query.count()
    total_credit_cost = base_query.with_entities(func.coalesce(func.sum(Task.credit_cost), 0)).scalar() or 0
    tasks = (
        base_query
        .order_by(Task.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    user_cache: dict[int, dict[str, str]] = {}
    items = []
    for task in tasks:
        if task.user_id not in user_cache:
            u = db.query(User).filter(User.id == task.user_id).first()
            user_cache[task.user_id] = {
                "username": u.username if u else "未知",
                "avatar_url": (u.avatar_url or "") if u else "",
            }

        soft_deleted_count = sum(1 for img in task.images if img.is_deleted)

        items.append({
            "task_id": task.id,
            "username": user_cache[task.user_id]["username"],
            "avatar_url": user_cache[task.user_id]["avatar_url"],
            "model": task.model or "",
            "mode": task.mode or "generate",
            "prompt": task.prompt or "",
            "reference_images": _parse_refs(task.reference_images),
            "num_images": task.num_images,
            "size": task.size,
            "resolution": task.resolution or "",
            "credit_cost": int(task.credit_cost or 0),
            "status": task.status,
            "error_message": task.error_message or "",
            "is_soft_deleted": soft_deleted_count > 0,
            "soft_deleted_count": soft_deleted_count,
            "created_at": task.created_at,
            "images": _serialize_history_images(
                task.images,
                cos_config=cos_config,
                include_deleted=True,
            ),
        })

    return {"total": total, "total_credit_cost": total_credit_cost, "items": items}
