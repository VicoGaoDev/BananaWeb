from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.services.image_service import request_regenerate, get_image
from app.config import settings

router = APIRouter(prefix="/api/images", tags=["图片"])


@router.post("/{image_id}/regenerate")
def regenerate(
    image_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    image = request_regenerate(db, image_id, user.id)

    try:
        from app.workers.generation import regenerate_single_image_task
        regenerate_single_image_task.delay(image.id)
    except Exception:
        from app.workers.generation import regenerate_single_sync
        regenerate_single_sync(image.id)

    return {"message": "已提交重新生成", "image_id": image.id}


@router.get("/{image_id}/download")
def download_image(
    image_id: int,
    _user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    image = get_image(db, image_id)
    if not image.image_url:
        raise HTTPException(status_code=404, detail="图片尚未生成")

    url_path = image.image_url.lstrip("/")
    file_path = Path(settings.UPLOAD_DIR).parent / url_path
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="图片文件不存在")

    return FileResponse(str(file_path), filename=file_path.name, media_type="image/png")
