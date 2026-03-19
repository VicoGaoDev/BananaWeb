from celery import Celery
from app.config import settings

celery_app = Celery(
    "banana_worker",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    worker_concurrency=2,
    task_acks_late=True,
)

celery_app.autodiscover_tasks(["app.workers"])
