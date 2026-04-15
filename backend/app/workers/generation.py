"""
AI image generation worker using configurable external APIs.

Supports multiple reference images (base64) and marks outputs as failed when
generation or persistence fails.
"""

import base64
import json
import logging
import uuid

import httpx
from pathlib import Path

from app.config import settings
from app.database import SessionLocal
from app.models.image import Image
from app.models.regenerate_log import RegenerateLog
from app.models.task import Task
from app.services.cos_service import build_object_key, load_image_bytes, upload_bytes_to_cos
from app.services.external_api_config_service import (
    render_config,
    require_scene_config,
    SCENE_INPAINT,
)

logger = logging.getLogger(__name__)

def _read_file_as_base64(ref_url: str) -> tuple[str, str] | None:
    """Read a local or remote image and return (mime_type, base64_data)."""
    result = load_image_bytes(ref_url)
    if not result:
        return None
    data, mime_type = result
    return mime_type, base64.b64encode(data).decode("utf-8")


def _append_inline_image(parts: list[dict], image_url: str) -> bool:
    ref = _read_file_as_base64(image_url)
    if not ref:
        return False
    mime_type, b64_data = ref
    parts.append({"inlineData": {"mimeType": mime_type, "data": b64_data}})
    return True


def _call_gemini_api(
    prompt: str,
    aspect_ratio: str,
    image_size: str,
    model_key: str = "",
    reference_images: list[str] | None = None,
    mode: str = "generate",
    source_image: str = "",
    mask_image: str = "",
) -> tuple[bytes, str] | None:
    """
    Call Gemini image generation API.
    Returns (image_bytes, mime_type) on success, None on failure.
    """
    db = SessionLocal()

    try:
        scene_key = SCENE_INPAINT if mode == "inpaint" else model_key
        config = require_scene_config(db, scene_key)

        parts: list[dict] = []
        if mode == "inpaint":
            if not _append_inline_image(parts, source_image):
                logger.warning("Inpaint source image not found: %s", source_image)
                return None
            if not _append_inline_image(parts, mask_image):
                logger.warning("Inpaint mask image not found: %s", mask_image)
                return None
            parts.append({
                "text": (
                    "请基于第1张原图进行局部重绘，第2张图是蒙版：白色区域需要重绘，"
                    "黑色区域必须保持原样。严格保留未遮罩区域的主体、构图、光影与细节。"
                    f"重绘要求：{prompt}"
                )
            })
        else:
            for ref_url in (reference_images or []):
                _append_inline_image(parts, ref_url)
            parts.append({"text": prompt})

        generation_config = {"responseModalities": ["IMAGE"]}
        if mode != "inpaint":
            generation_config["imageConfig"] = {
                "aspectRatio": aspect_ratio,
            }
            if image_size:
                generation_config["imageConfig"]["imageSize"] = image_size

        rendered = render_config(
            config,
            {
                "prompt": prompt,
                "aspect_ratio": aspect_ratio,
                "image_size": image_size,
                "contents_parts": parts,
                "generation_config": generation_config,
                "mode": mode,
            },
        )

        auth_value = rendered.headers.get("Authorization", "")
        logger.info(
            "Calling generation API: config=%s, mode=%s, prompt=%s, ratio=%s, size=%s, ref_count=%d, auth_prefix=%s",
            config.name,
            mode,
            prompt[:60],
            aspect_ratio,
            image_size,
            len(reference_images or []),
            (auth_value[:8] + "...") if auth_value else "none",
        )

        with httpx.Client(timeout=settings.AI_TIMEOUT) as client:
            resp = client.post(
                rendered.request_url,
                json=rendered.payload,
                headers=rendered.headers,
            )

            if resp.status_code != 200:
                logger.error(
                    "Generation API HTTP %s: %s", resp.status_code, resp.text[:500]
                )
                return None

            data = resp.json()

        candidates = data.get("candidates", [])
        if not candidates:
            logger.warning("Generation API returned no candidates: %s", str(data)[:300])
            return None

        for part in candidates[0].get("content", {}).get("parts", []):
            inline = part.get("inlineData")
            if inline:
                b64_str = inline["data"]
                mime = inline.get("mimeType", "image/png")
                img_bytes = base64.b64decode(b64_str)
                logger.info(
                    "Generation API success, mime=%s, image size: %d bytes",
                    mime, len(img_bytes),
                )
                return img_bytes, mime

        logger.warning("Generation API response has no inlineData in parts")
        return None

    except httpx.TimeoutException:
        logger.error("Generation API request timed out (%s seconds)", settings.AI_TIMEOUT)
        return None
    except Exception as e:
        logger.error("Generation API error: %s", e, exc_info=True)
        return None
    finally:
        db.close()


MIME_TO_EXT = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/gif": "gif",
}


def _save_image_bytes(db, image_bytes: bytes, mime: str = "image/png") -> str:
    ext = MIME_TO_EXT.get(mime, "png")
    key = build_object_key("generated", f"generated.{ext}", mime)
    return upload_bytes_to_cos(db, data=image_bytes, key=key, content_type=mime)


def _save_preview_image(image_bytes: bytes, mime: str = "image/png") -> str:
    ext = MIME_TO_EXT.get(mime, "png")
    preview_dir = Path(settings.UPLOAD_DIR) / "generated_preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    file_name = f"{uuid.uuid4().hex}.{ext}"
    file_path = preview_dir / file_name
    file_path.write_bytes(image_bytes)
    return f"/uploads/generated_preview/{file_name}"


def _derive_image_format(mime: str) -> str:
    if not mime:
        return ""
    return mime.split("/")[-1].upper()


def _mark_image_storage_fallback(image: Image) -> None:
    """
    Preserve the locally saved preview when remote storage upload fails.

    The preview file contains the full generated bytes, so we can safely expose
    it as the downloadable image_url fallback instead of discarding the result.
    """
    fallback_url = image.preview_url or ""
    image.image_url = fallback_url
    image.status = "success" if fallback_url else "failed"
    if not fallback_url:
        image.image_format = ""
        image.image_size_bytes = 0


def _parse_reference_images(task: Task) -> list[str]:
    """Parse reference_images JSON string from task."""
    if not task.reference_images:
        return []
    try:
        refs = json.loads(task.reference_images)
        return refs if isinstance(refs, list) else []
    except (json.JSONDecodeError, TypeError):
        return []


def _resolve_task_status(images: list[Image]) -> str:
    if any(image.status == "pending" for image in images):
        return "processing"
    if images and all(image.status == "success" for image in images):
        return "success"
    return "failed"


def _process_task(task_id: int):
    db = SessionLocal()
    try:
        task = db.query(Task).filter(Task.id == task_id).first()
        if not task:
            return
        task.status = "processing"
        db.commit()

        images = db.query(Image).filter(Image.task_id == task_id).all()
        ref_urls = _parse_reference_images(task)
        task_mode = (task.mode or "generate").lower()
        all_success = True

        for image in images:
            result = _call_gemini_api(
                prompt=task.prompt,
                aspect_ratio=task.size,
                image_size=task.resolution,
                model_key=task.model or "",
                reference_images=ref_urls,
                mode=task_mode,
                source_image=task.source_image or "",
                mask_image=task.mask_image or "",
            )

            if result:
                img_bytes, mime = result
                image.preview_url = _save_preview_image(img_bytes, mime)
                image.image_url = ""
                image.image_format = _derive_image_format(mime)
                image.image_size_bytes = len(img_bytes)
                image.status = "success"
                db.commit()
                try:
                    image.image_url = _save_image_bytes(db, img_bytes, mime)
                    db.commit()
                except Exception:
                    logger.exception("Failed to persist generated image to storage")
                    _mark_image_storage_fallback(image)
                    all_success = image.status == "success" and all_success
                    db.commit()
            else:
                image.preview_url = ""
                image.image_url = ""
                image.image_format = ""
                image.image_size_bytes = 0
                image.status = "failed"
                all_success = False
                db.commit()

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

        task = db.query(Task).filter(Task.id == image.task_id).first()
        if not task:
            image.status = "failed"
            image.preview_url = ""
            image.image_url = ""
            image.image_format = ""
            image.image_size_bytes = 0
            db.commit()
            return

        task.status = "processing"
        db.commit()

        ref_urls = _parse_reference_images(task)
        task_mode = (task.mode or "generate").lower()

        result = _call_gemini_api(
            prompt=task.prompt,
            aspect_ratio=task.size,
            image_size=task.resolution,
            model_key=task.model or "",
            reference_images=ref_urls,
            mode=task_mode,
            source_image=task.source_image or "",
            mask_image=task.mask_image or "",
        )

        if result:
            img_bytes, mime = result
            image.preview_url = _save_preview_image(img_bytes, mime)
            image.image_url = ""
            image.image_format = _derive_image_format(mime)
            image.image_size_bytes = len(img_bytes)
            image.status = "success"
            db.commit()
            try:
                new_url = _save_image_bytes(db, img_bytes, mime)
                log = (
                    db.query(RegenerateLog)
                    .filter(RegenerateLog.image_id == image_id, RegenerateLog.new_image_url == "")
                    .order_by(RegenerateLog.created_at.desc())
                    .first()
                )
                if log:
                    log.new_image_url = new_url
                image.image_url = new_url
                db.commit()
            except Exception:
                logger.exception("Failed to persist regenerated image to storage")
                _mark_image_storage_fallback(image)
                log = (
                    db.query(RegenerateLog)
                    .filter(RegenerateLog.image_id == image_id, RegenerateLog.new_image_url == "")
                    .order_by(RegenerateLog.created_at.desc())
                    .first()
                )
                if log and image.image_url:
                    log.new_image_url = image.image_url
                db.commit()
        else:
            image.preview_url = ""
            image.image_url = ""
            image.image_format = ""
            image.image_size_bytes = 0
            image.status = "failed"
            db.commit()

        db.refresh(task)
        task.status = _resolve_task_status(list(task.images))
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
