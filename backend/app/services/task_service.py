from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.task import Task
from app.models.image import Image
from app.models.style import Style
from app.models.style_prompt import StylePrompt


def create_task(db: Session, user_id: int, style_id: int, model: str, size: str, reference_image: str = "") -> Task:
    style = db.query(Style).filter(Style.id == style_id).first()
    if not style:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="风格不存在")

    prompts = (
        db.query(StylePrompt)
        .filter(StylePrompt.style_id == style_id)
        .order_by(StylePrompt.sort_order)
        .all()
    )
    if not prompts:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="该风格暂无配置的Prompt")

    task = Task(user_id=user_id, style_id=style_id, model=model, size=size, reference_image=reference_image, status="pending")
    db.add(task)
    db.flush()

    for prompt in prompts:
        image = Image(task_id=task.id, prompt_id=prompt.id, image_url="", status="pending")
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
