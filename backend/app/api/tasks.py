from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.task import TaskCreate, TaskCreateResponse, TaskOut
from app.services.external_api_config_service import (
    get_default_generation_model_key,
    require_scene_config,
    SCENE_INPAINT,
)
from app.services.task_service import create_task, get_task_detail

router = APIRouter(prefix="/api/tasks", tags=["生成任务"])


@router.post("", response_model=TaskCreateResponse)
def create(
    body: TaskCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if body.mode == "inpaint":
        require_scene_config(db, SCENE_INPAINT)
        task_model = SCENE_INPAINT
        resolved_resolution = body.resolution
    else:
        task_model = body.model.strip() or get_default_generation_model_key(db)
        require_scene_config(db, task_model)
        resolved_resolution = "" if task_model == "banana" else body.resolution

    task = create_task(
        db,
        user_id=user.id,
        model=task_model,
        mode=body.mode,
        prompt=body.prompt,
        num_images=body.num_images,
        size=body.size,
        resolution=resolved_resolution,
        reference_images=body.reference_images,
        source_image=body.source_image,
        mask_image=body.mask_image,
    )

    try:
        from app.workers.generation import generate_images_task
        generate_images_task.delay(task.id)
    except Exception:
        from app.workers.generation import generate_images_sync
        generate_images_sync(task.id)

    return TaskCreateResponse(task_id=task.id)


@router.get("/{task_id}", response_model=TaskOut)
def get_task(
    task_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = get_task_detail(db, task_id, user.id)
    return task
