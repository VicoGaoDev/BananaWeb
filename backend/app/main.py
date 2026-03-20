from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import inspect, text
from app.database import engine, Base
from app.config import settings
import app.models  # noqa: F401 — ensure all models are registered

app = FastAPI(title="Banana Web - AI 绘图系统", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    Path(settings.DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
    Base.metadata.create_all(bind=engine)
    _ensure_schema_compat()
    _seed_default_data()


def _ensure_schema_compat():
    inspector = inspect(engine)
    user_columns = {col["name"] for col in inspector.get_columns("users")}

    with engine.begin() as conn:
        if "avatar_url" not in user_columns:
            conn.execute(text("ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500) DEFAULT ''"))


def _seed_default_data():
    """Create default admin and sample styles on first run."""
    from app.database import SessionLocal
    from app.models.user import User
    from app.models.style import Style
    from app.models.style_prompt import StylePrompt
    from app.utils.security import hash_password

    db = SessionLocal()
    try:
        if not db.query(User).first():
            db.add(User(username="admin", password_hash=hash_password("admin123"), role="admin"))
            db.commit()

        if not db.query(Style).first():
            styles_data = [
                {
                    "name": "赛博朋克",
                    "description": "未来科技感的霓虹城市风格",
                    "cover_image": "",
                    "prompts": [
                        {"prompt": "cyberpunk city skyline, neon lights, rain, futuristic buildings, 8k ultra detailed", "negative_prompt": "blurry, low quality"},
                        {"prompt": "cyberpunk street scene, holographic signs, flying cars, dramatic lighting", "negative_prompt": "blurry, low quality"},
                        {"prompt": "cyberpunk character portrait, neon glow, tech implants, cinematic", "negative_prompt": "blurry, low quality, deformed"},
                    ],
                },
                {
                    "name": "水墨山水",
                    "description": "中国传统水墨画风格",
                    "cover_image": "",
                    "prompts": [
                        {"prompt": "traditional chinese ink wash painting, mountains and rivers, misty landscape, elegant brushstrokes", "negative_prompt": "modern, colorful, cartoon"},
                        {"prompt": "chinese ink painting style, bamboo forest, waterfall, peaceful atmosphere", "negative_prompt": "modern, cartoon"},
                        {"prompt": "ink wash painting, lone fisherman on lake, mountains in background, minimalist", "negative_prompt": "modern, colorful"},
                    ],
                },
                {
                    "name": "油画风景",
                    "description": "印象派风格的油画",
                    "cover_image": "",
                    "prompts": [
                        {"prompt": "impressionist oil painting landscape, golden wheat field, blue sky, thick brushstrokes, vivid colors", "negative_prompt": "photo, realistic, digital"},
                        {"prompt": "oil painting style, sunset over ocean, dramatic clouds, impasto technique", "negative_prompt": "photo, digital art"},
                        {"prompt": "oil painting, autumn forest path, fallen leaves, warm light filtering through trees", "negative_prompt": "photo, digital"},
                    ],
                },
                {
                    "name": "动漫插画",
                    "description": "日系动漫风格插画",
                    "cover_image": "",
                    "prompts": [
                        {"prompt": "anime style illustration, cherry blossom tree, school rooftop, blue sky, studio ghibli inspired", "negative_prompt": "realistic, photo, 3d"},
                        {"prompt": "anime landscape, fantasy castle in clouds, floating islands, magical atmosphere, vibrant colors", "negative_prompt": "realistic, photo"},
                        {"prompt": "anime style, cozy room interior, rain outside window, warm lighting, detailed", "negative_prompt": "realistic, 3d render"},
                    ],
                },
            ]

            for s_data in styles_data:
                style = Style(name=s_data["name"], description=s_data["description"], cover_image=s_data["cover_image"])
                db.add(style)
                db.flush()
                for i, p_data in enumerate(s_data["prompts"]):
                    db.add(StylePrompt(
                        style_id=style.id,
                        prompt=p_data["prompt"],
                        negative_prompt=p_data["negative_prompt"],
                        sort_order=i,
                    ))
            db.commit()
    finally:
        db.close()


upload_path = Path(settings.UPLOAD_DIR)
upload_path.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(upload_path)), name="uploads")

from app.api import auth, styles, tasks, images, history, admin, upload, api_key  # noqa: E402
app.include_router(auth.router)
app.include_router(styles.router)
app.include_router(tasks.router)
app.include_router(images.router)
app.include_router(history.router)
app.include_router(admin.router)
app.include_router(upload.router)
app.include_router(api_key.router)
