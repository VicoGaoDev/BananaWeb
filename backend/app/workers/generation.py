"""
AI image generation tasks.

Provides both Celery async tasks and synchronous fallbacks
for when Redis/Celery is not available.
"""

import time
import uuid
import httpx
from pathlib import Path
from app.config import settings
from app.database import SessionLocal
from app.models.task import Task
from app.models.image import Image
from app.models.style_prompt import StylePrompt
from app.models.regenerate_log import RegenerateLog

try:
    from app.workers.celery_app import celery_app
    CELERY_AVAILABLE = True
except Exception:
    CELERY_AVAILABLE = False
    celery_app = None


def _call_ai_api(prompt: str, negative_prompt: str, model: str, size: str) -> bytes | None:
    """Call external AI API to generate an image. Returns image bytes or None."""
    if not settings.AI_API_BASE_URL or not settings.AI_API_KEY:
        return _generate_placeholder(prompt)

    try:
        with httpx.Client(timeout=120) as client:
            resp = client.post(
                f"{settings.AI_API_BASE_URL}/generate",
                json={
                    "prompt": prompt,
                    "negative_prompt": negative_prompt,
                    "model": model,
                    "size": size,
                },
                headers={"Authorization": f"Bearer {settings.AI_API_KEY}"},
            )
            resp.raise_for_status()
            return resp.content
    except Exception:
        return None


def _generate_placeholder(prompt: str) -> bytes:
    """Generate a placeholder SVG image for development/testing."""
    short = prompt[:30].replace('"', "'")
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512">
  <rect width="512" height="512" fill="#1a1a2e"/>
  <rect x="20" y="20" width="472" height="472" rx="16" fill="none" stroke="#e94560" stroke-width="2"/>
  <text x="256" y="240" text-anchor="middle" fill="#e94560" font-size="20" font-family="sans-serif">AI Generated</text>
  <text x="256" y="280" text-anchor="middle" fill="#888" font-size="14" font-family="sans-serif">{short}</text>
</svg>"""
    return svg.encode("utf-8")


def _save_image_bytes(image_bytes: bytes, ext: str = "svg") -> str:
    upload_dir = Path(settings.UPLOAD_DIR)
    upload_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid.uuid4().hex}.{ext}"
    (upload_dir / filename).write_bytes(image_bytes)
    return f"/uploads/{filename}"


def _process_task(task_id: int):
    db = SessionLocal()
    try:
        task = db.query(Task).filter(Task.id == task_id).first()
        if not task:
            return
        task.status = "processing"
        db.commit()

        images = db.query(Image).filter(Image.task_id == task_id).all()
        all_success = True

        for image in images:
            prompt = db.query(StylePrompt).filter(StylePrompt.id == image.prompt_id).first()
            if not prompt:
                image.status = "failed"
                all_success = False
                continue

            time.sleep(1)  # Simulate processing time

            result = _call_ai_api(prompt.prompt, prompt.negative_prompt, task.model, task.size)
            if result:
                ext = "svg" if result[:5] == b"<svg " else "png"
                image.image_url = _save_image_bytes(result, ext)
                image.status = "success"
            else:
                image.status = "failed"
                all_success = False

        task.status = "success" if all_success else "failed"
        db.commit()
    finally:
        db.close()


def _process_single_image(image_id: int):
    db = SessionLocal()
    try:
        image = db.query(Image).filter(Image.id == image_id).first()
        if not image:
            return

        prompt = db.query(StylePrompt).filter(StylePrompt.id == image.prompt_id).first()
        task = db.query(Task).filter(Task.id == image.task_id).first()
        if not prompt or not task:
            image.status = "failed"
            db.commit()
            return

        time.sleep(1)

        result = _call_ai_api(prompt.prompt, prompt.negative_prompt, task.model, task.size)
        if result:
            ext = "svg" if result[:5] == b"<svg " else "png"
            new_url = _save_image_bytes(result, ext)
            # Update regenerate log
            log = (
                db.query(RegenerateLog)
                .filter(RegenerateLog.image_id == image_id, RegenerateLog.new_image_url == "")
                .order_by(RegenerateLog.created_at.desc())
                .first()
            )
            if log:
                log.new_image_url = new_url
            image.image_url = new_url
            image.status = "success"
        else:
            image.status = "failed"

        db.commit()
    finally:
        db.close()


# --- Celery tasks ---

if CELERY_AVAILABLE and celery_app:
    @celery_app.task(bind=True, max_retries=2)
    def generate_images_task(self, task_id: int):
        _process_task(task_id)

    @celery_app.task(bind=True, max_retries=2)
    def regenerate_single_image_task(self, image_id: int):
        _process_single_image(image_id)
else:
    def generate_images_task():
        raise RuntimeError("Celery not available")

    def regenerate_single_image_task():
        raise RuntimeError("Celery not available")


# --- Sync fallbacks (for dev without Redis) ---

def generate_images_sync(task_id: int):
    import threading
    threading.Thread(target=_process_task, args=(task_id,), daemon=True).start()


def regenerate_single_sync(image_id: int):
    import threading
    threading.Thread(target=_process_single_image, args=(image_id,), daemon=True).start()
