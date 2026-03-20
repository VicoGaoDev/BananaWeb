from pathlib import Path
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    DEBUG: bool = False
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    DB_PATH: str = str(BASE_DIR / "data" / "banana.db")
    UPLOAD_DIR: str = str(BASE_DIR / "uploads")

    REDIS_URL: str = "redis://localhost:6379/0"

    AI_API_URL: str = "https://nanoapi.poloai.top/v1beta/models/gemini-3-pro-image-preview:generateContent"
    AI_TIMEOUT: int = 120

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
