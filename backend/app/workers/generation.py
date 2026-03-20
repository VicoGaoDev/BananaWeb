"""
AI image generation via Gemini API (Nano Banana Pro).

Reads API Key dynamically from database. Supports reference image (base64).
Falls back to a static error image on failure.
"""

import base64
import logging
import shutil
import uuid
import httpx
from pathlib import Path

from app.config import settings
from app.database import SessionLocal
from app.models.task import Task
from app.models.image import Image
from app.models.api_key import ApiKey
from app.models.style_prompt import StylePrompt
from app.models.regenerate_log import RegenerateLog

logger = logging.getLogger(__name__)

STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
ERROR_IMAGE_PATH = STATIC_DIR / "error.svg"


def _get_api_key() -> str | None:
    db = SessionLocal()
    try:
        record = db.query(ApiKey).first()
        return record.key if record and record.key else None
    finally:
        db.close()


def _read_file_as_base64(ref_url: str) -> tuple[str, str] | None:
    """Read a local uploaded file and return (mime_type, base64_data)."""
    if not ref_url:
        return None
    relative = ref_url.lstrip("/")
    if relative.startswith("uploads/"):
        relative = relative[len("uploads/"):]
    file_path = Path(settings.UPLOAD_DIR) / relative
    if not file_path.exists():
        return None
    ext = file_path.suffix.lower()
    mime_map = {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp", ".gif": "image/gif",
    }
    mime_type = mime_map.get(ext, "image/jpeg")
    data = file_path.read_bytes()
    return mime_type, base64.b64encode(data).decode("utf-8")


def _call_gemini_api(
    prompt: str,
    aspect_ratio: str,
    image_size: str,
    reference_image: str = "",
) -> bytes | None:
    """
    Call Gemini image generation API.
    Returns decoded image bytes on success, None on failure.
    """
    api_key = _get_api_key()
    if not api_key:
        logger.warning("No API Key configured in database")
        return None

    parts: list[dict] = []

    ref = _read_file_as_base64(reference_image)
    if ref:
        mime_type, b64_data = ref
        parts.append({"inlineData": {"mimeType": mime_type, "data": b64_data}})

    parts.append({"text": prompt})

    payload = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {
                "aspectRatio": aspect_ratio,
                "imageSize": image_size,
            },
        },
    }

    auth_value = api_key.strip()
    logger.info(
        "Calling Gemini API: prompt=%s, ratio=%s, size=%s, has_ref=%s, key_prefix=%s",
        prompt[:60], aspect_ratio, image_size, bool(ref), auth_value[:8] + "..."
    )

    try:
        with httpx.Client(timeout=settings.AI_TIMEOUT) as client:
            resp = client.post(
                settings.AI_API_URL,
                json=payload,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": auth_value,
                },
            )

            if resp.status_code != 200:
                logger.error(
                    "Gemini API HTTP %s: %s", resp.status_code, resp.text[:500]
                )
                return None

            data = resp.json()

        candidates = data.get("candidates", [])
        if not candidates:
            logger.warning("Gemini API returned no candidates: %s", str(data)[:300])
            return None

        for part in candidates[0].get("content", {}).get("parts", []):
            if "inlineData" in part:
                b64_str = part["inlineData"]["data"]
                img_bytes = base64.b64decode(b64_str)
                logger.info("Gemini API success, image size: %d bytes", len(img_bytes))
                return img_bytes

        logger.warning("Gemini API response has no inlineData in parts")
        return None

    except httpx.TimeoutException:
        logger.error("Gemini API request timed out (%ds)", settings.AI_TIMEOUT)
        return None
    except Exception as e:
        logger.error("Gemini API error: %s", e, exc_info=True)
        return None


def _save_image_bytes(image_bytes: bytes, ext: str = "jpg") -> str:
    upload_dir = Path(settings.UPLOAD_DIR)
    upload_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid.uuid4().hex}.{ext}"
    (upload_dir / filename).write_bytes(image_bytes)
    return f"/uploads/{filename}"


def _get_error_image_url() -> str:
    """Copy static error image to uploads and return its URL."""
    upload_dir = Path(settings.UPLOAD_DIR)
    upload_dir.mkdir(parents=True, exist_ok=True)
    dest = upload_dir / "error.svg"
    if not dest.exists():
        shutil.copy2(ERROR_IMAGE_PATH, dest)
    return "/uploads/error.svg"


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
            sp = db.query(StylePrompt).filter(StylePrompt.id == image.prompt_id).first()
            if not sp:
                image.status = "failed"
                image.image_url = _get_error_image_url()
                all_success = False
                continue

            result = _call_gemini_api(
                prompt=sp.prompt,
                aspect_ratio=task.size,
                image_size=task.resolution,
                reference_image=task.reference_image,
            )

            if result:
                image.image_url = _save_image_bytes(result, "jpg")
                image.status = "success"
            else:
                image.image_url = _get_error_image_url()
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

        sp = db.query(StylePrompt).filter(StylePrompt.id == image.prompt_id).first()
        task = db.query(Task).filter(Task.id == image.task_id).first()
        if not sp or not task:
            image.status = "failed"
            image.image_url = _get_error_image_url()
            db.commit()
            return

        result = _call_gemini_api(
            prompt=sp.prompt,
            aspect_ratio=task.size,
            image_size=task.resolution,
            reference_image=task.reference_image,
        )

        if result:
            new_url = _save_image_bytes(result, "jpg")
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
            image.image_url = _get_error_image_url()
            image.status = "failed"

        db.commit()
    finally:
        db.close()


# --- Celery tasks ---

def _redis_reachable() -> bool:
    """Quick check: can we actually connect to the Redis broker?"""
    try:
        import redis
        r = redis.Redis.from_url(
            settings.REDIS_URL, socket_connect_timeout=1, socket_timeout=1
        )
        r.ping()
        return True
    except Exception:
        return False


try:
    from app.workers.celery_app import celery_app
    CELERY_AVAILABLE = _redis_reachable()
    if not CELERY_AVAILABLE:
        logger.info("Redis not reachable — falling back to sync thread mode")
except Exception:
    CELERY_AVAILABLE = False
    celery_app = None

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
