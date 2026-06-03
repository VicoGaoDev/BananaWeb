from __future__ import annotations

import logging

from app.database import SessionLocal
from app.services.daily_report_service import send_previous_day_report
from app.services.wecom_notify_service import is_wecom_notify_enabled
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.workers.reporting.send_daily_wecom_report")
def send_daily_wecom_report() -> bool:
    if not is_wecom_notify_enabled():
        logger.info("WeCom notify disabled, skip daily report")
        return False

    db = SessionLocal()
    try:
        result = send_previous_day_report(db)
        return result.sent
    except Exception:
        logger.exception("Failed to send daily WeCom report")
        return False
    finally:
        db.close()
