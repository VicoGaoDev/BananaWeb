from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.task import TaskCreate, TaskCreateResponse, TaskOut
from app.services.task_service import create_task, get_task_detail

router = APIRouter(prefix="/api/tasks", tags=["生成任务"])


@router.post("", response_model=TaskCreateResponse)
def create(
    body: TaskCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = create_task(db, user.id, body.style_id, body.model, body.size, body.resolution, body.reference_image)

    # Trigger async generation (Celery)
    try:
        from app.workers.generation import generate_images_task
        generate_images_task.delay(task.id)
    except Exception:
        # If Celery/Redis not available, run sync simulation
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
