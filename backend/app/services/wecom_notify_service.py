from __future__ import annotations

import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


def is_wecom_notify_enabled() -> bool:
    return bool(settings.WECOM_NOTIFY_ENABLED and (settings.WECOM_WEBHOOK_URL or "").strip())


def send_wecom_markdown(content: str) -> bool:
    webhook_url = (settings.WECOM_WEBHOOK_URL or "").strip()
    if not settings.WECOM_NOTIFY_ENABLED or not webhook_url:
        return False

    try:
        response = httpx.post(
            webhook_url,
            json={"msgtype": "markdown", "markdown": {"content": content}},
            timeout=max(int(settings.WECOM_NOTIFY_TIMEOUT_SECONDS or 0), 1),
        )
        response.raise_for_status()
        payload = response.json()
        if int(payload.get("errcode") or 0) != 0:
            logger.warning("WeCom notify failed: %s", payload)
            return False
        return True
    except Exception:
        logger.exception("Failed to send WeCom markdown message")
        return False
