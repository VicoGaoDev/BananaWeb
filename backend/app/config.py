from pathlib import Path

from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    DEBUG: bool = False
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    DATABASE_URL: str | None = None
    DB_PATH: str = str(BASE_DIR / "data" / "banana.db")
    DB_AUTO_CREATE_TABLES: bool = True
    DB_RUN_SCHEMA_COMPAT: bool | None = None
    DB_RUN_SEED: bool | None = None
    UPLOAD_DIR: str = str(BASE_DIR / "uploads")

    REDIS_URL: str = "redis://localhost:6379/0"

    AI_API_URL: str = "https://nanoapi.poloai.top/v1beta/models/gemini-2.5-flash-image-preview:generateContent"
    AI_TIMEOUT: int = 120
    COS_STS_DURATION_SECONDS: int = 1800
    IMAGE_FETCH_TIMEOUT: int = 30
    COS_IMAGE_THUMBNAIL_RULE: str = ""
    COS_IMAGE_STYLE_SEPARATOR: str = "!"
    GENERATED_PREVIEW_TTL_SECONDS: int = 3600
    GENERATED_IMAGE_CACHE_CONTROL: str = "public, max-age=31536000, immutable"

    model_config = {"env_file": ".env", "extra": "ignore"}

    @property
    def database_url(self) -> str:
        return self.DATABASE_URL or f"sqlite:///{self.DB_PATH}"

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")

    @property
    def should_run_schema_compat(self) -> bool:
        if self.DB_RUN_SCHEMA_COMPAT is not None:
            return self.DB_RUN_SCHEMA_COMPAT
        return self.is_sqlite

    @property
    def should_run_seed(self) -> bool:
        if self.DB_RUN_SEED is not None:
            return self.DB_RUN_SEED
        return self.is_sqlite


settings = Settings()
