import json
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.task import Task
from app.models.image import Image
from app.models.user import User
from app.models.credit_log import CreditLog
from app.models.prompt_history import PromptHistory
from app.services.external_api_config_service import SCENE_INPAINT, get_scene_credit_cost


def _is_credit_exempt_user(user: User | None) -> bool:
    return bool(user and user.role == "superadmin")


def create_task(
    db: Session,
    user_id: int,
    model: str,
    mode: str,
    prompt: str,
    num_images: int,
    size: str,
    resolution: str = "4K",
    reference_images: list[str] | None = None,
    source_image: str = "",
    mask_image: str = "",
) -> Task:
    mode = (mode or "generate").strip().lower()
    if mode not in {"generate", "inpaint"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="不支持的生成模式")
    if not prompt or not prompt.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="提示词不能为空")
    if num_images < 1 or num_images > 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="生成数量须在 1-8 之间")
    if mode == "inpaint":
        if not source_image.strip():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="请先上传原图")
        if not mask_image.strip():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="请先涂抹需要重绘的区域")
        num_images = 1

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户不存在",
        )
    scene_key = SCENE_INPAINT if mode == "inpaint" else model.strip()
    unit_cost = get_scene_credit_cost(db, scene_key)
    cost = unit_cost if mode == "inpaint" else num_images * unit_cost
    if not _is_credit_exempt_user(user) and user.credits < cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"积分不足，需要 {cost} 积分，当前余额 {user.credits if user else 0}",
        )

    ref_json = json.dumps(reference_images or [])

    task = Task(
        user_id=user_id,
        model=model.strip(),
        mode=mode,
        prompt=prompt.strip(),
        num_images=num_images,
        size=size,
        resolution=resolution,
        reference_images=ref_json,
        source_image=source_image.strip(),
        mask_image=mask_image.strip(),
        status="pending",
        error_message="",
    )
    db.add(task)
    db.flush()

    for _ in range(num_images):
        image = Image(task_id=task.id, image_url="", status="pending", error_message="")
        db.add(image)

    if not _is_credit_exempt_user(user):
        user.credits -= cost
        credit_log = CreditLog(
            user_id=user_id,
            amount=-cost,
            type="consume",
            description="局部重绘 1 张图片" if mode == "inpaint" else f"生成 {num_images} 张图片",
            task_id=task.id,
        )
        db.add(credit_log)

    db.add(PromptHistory(user_id=user_id, prompt=prompt.strip()))

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
