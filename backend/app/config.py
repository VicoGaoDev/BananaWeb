from pathlib import Path

from pydantic_settings import BaseSettings
from sqlalchemy.engine import URL

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    DEBUG: bool = False
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    DATABASE_URL: str | None = None
    DB_HOST: str = "sh-cynosdbmysql-grp-kmfw4ojg.sql.tencentcdb.com"
    DB_PORT: int = 20396
    DB_USER: str | None = None
    DB_PASSWORD: str | None = None
    DB_NAME: str | None = None
    DB_CHARSET: str = "utf8mb4"
    DB_AUTO_CREATE_TABLES: bool = True
    DB_RUN_SCHEMA_COMPAT: bool = True
    DB_RUN_SEED: bool = False
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
        database_url = (self.DATABASE_URL or "").strip()
        if database_url:
            if not database_url.startswith("mysql"):
                raise ValueError("DATABASE_URL must start with a MySQL driver prefix.")
            return database_url

        missing_fields = [
            field_name
            for field_name, field_value in {
                "DB_USER": self.DB_USER,
                "DB_PASSWORD": self.DB_PASSWORD,
                "DB_NAME": self.DB_NAME,
            }.items()
            if not (field_value or "").strip()
        ]
        if missing_fields:
            joined = ", ".join(missing_fields)
            raise ValueError(f"Set DATABASE_URL or provide MySQL fields: {joined}.")

        return URL.create(
            drivername="mysql+pymysql",
            username=self.DB_USER,
            password=self.DB_PASSWORD,
            host=self.DB_HOST,
            port=self.DB_PORT,
            database=self.DB_NAME,
            query={"charset": self.DB_CHARSET},
        ).render_as_string(hide_password=False)

    @property
    def should_run_schema_compat(self) -> bool:
        return self.DB_RUN_SCHEMA_COMPAT

    @property
    def should_run_seed(self) -> bool:
        return self.DB_RUN_SEED


settings = Settings()
