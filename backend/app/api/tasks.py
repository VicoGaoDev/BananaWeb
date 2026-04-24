from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.task import TaskCreate, TaskCreateResponse, TaskOut
from app.services.image_delivery_service import get_optional_cos_config, serialize_task
from app.services.external_api_config_service import (
    get_default_generation_model_key,
    require_scene_config,
    SCENE_INPAINT,
)
from app.services.task_service import (
    create_tasks,
    get_task_detail,
    get_task_details,
    mark_tasks_enqueue_failed,
    mark_tasks_queued,
)

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

    try:
        from app.workers.generation import dispatch_generation_task, get_generation_dispatch_mode
        dispatch_mode = get_generation_dispatch_mode()
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc

    tasks = create_tasks(
        db,
        user_id=user.id,
        model=task_model,
        mode=body.mode,
        prompt=body.prompt,
        num_images=body.num_images,
        size=body.size,
        resolution=resolved_resolution,
        custom_size=body.custom_size,
        reference_images=body.reference_images,
        source_image=body.source_image,
        mask_image=body.mask_image,
    )

    dispatched_task_ids: list[int] = []
    try:
        for task in tasks:
            dispatch_generation_task(task.id)
            dispatched_task_ids.append(task.id)
        if dispatch_mode == "celery":
            mark_tasks_queued(db, dispatched_task_ids)
    except Exception as exc:
        failed_task_ids = [task.id for task in tasks if task.id not in set(dispatched_task_ids)]
        mark_tasks_enqueue_failed(db, failed_task_ids, error_message=str(exc))
        if dispatched_task_ids:
            task_ids = [task.id for task in tasks]
            return TaskCreateResponse(task_id=task_ids[0] if task_ids else None, task_ids=task_ids)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="任务队列暂不可用，请稍后重试",
        ) from exc

    task_ids = [task.id for task in tasks]
    return TaskCreateResponse(task_id=task_ids[0] if task_ids else None, task_ids=task_ids)


@router.get("/{task_id}", response_model=TaskOut)
def get_task(
    task_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = get_task_detail(db, task_id, user.id)
    return serialize_task(task, cos_config=get_optional_cos_config(db))


@router.get("", response_model=list[TaskOut])
def get_tasks(
    task_ids: list[int] = Query(default=[]),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tasks = get_task_details(db, task_ids, user.id)
    cos_config = get_optional_cos_config(db)
    return [serialize_task(task, cos_config=cos_config) for task in tasks]
