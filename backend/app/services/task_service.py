import json
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.task import Task
from app.models.image import Image


def create_task(
    db: Session,
    user_id: int,
    prompt: str,
    num_images: int,
    size: str,
    resolution: str = "4K",
    reference_images: list[str] | None = None,
) -> Task:
    if not prompt or not prompt.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="提示词不能为空")
    if num_images < 1 or num_images > 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="生成数量须在 1-8 之间")

    ref_json = json.dumps(reference_images or [])

    task = Task(
        user_id=user_id,
        prompt=prompt.strip(),
        num_images=num_images,
        size=size,
        resolution=resolution,
        reference_images=ref_json,
        status="pending",
    )
    db.add(task)
    db.flush()

    for _ in range(num_images):
        image = Image(task_id=task.id, image_url="", status="pending")
        db.add(image)

    db.commit()
    db.refresh(task)
    return task


def get_task_detail(db: Session, task_id: int, user_id: int | None = None) -> Task:
    query = db.query(Task).filter(Task.id == task_id)
    if user_id is not None:
        query = query.filter(Task.user_id == user_id)
    task = query.first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="任务不存在")
    return task
