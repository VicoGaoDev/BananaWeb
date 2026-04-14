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
    if settings.is_sqlite:
        Path(settings.DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
    if settings.DB_AUTO_CREATE_TABLES:
        Base.metadata.create_all(bind=engine)
    _ensure_image_required_columns()
    _ensure_template_required_columns()
    if settings.should_run_schema_compat:
        _ensure_schema_compat()
    _initialize_template_sort_orders()
    if settings.should_run_seed:
        _seed_default_data()


def _ensure_schema_compat():
    inspector = inspect(engine)

    user_columns = {col["name"] for col in inspector.get_columns("users")}
    with engine.begin() as conn:
        if "avatar_url" not in user_columns:
            conn.execute(text("ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500) DEFAULT ''"))

    task_columns = {col["name"] for col in inspector.get_columns("tasks")}
    with engine.begin() as conn:
        if "model" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN model VARCHAR(50) DEFAULT ''"))
        if "resolution" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN resolution VARCHAR(10) DEFAULT '4K'"))
        if "prompt" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN prompt TEXT DEFAULT ''"))
        if "num_images" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN num_images INTEGER DEFAULT 4"))
        if "reference_images" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN reference_images TEXT DEFAULT ''"))
        if "mode" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN mode VARCHAR(20) DEFAULT 'generate'"))
        if "source_image" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN source_image VARCHAR(500) DEFAULT ''"))
        if "mask_image" not in task_columns:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN mask_image VARCHAR(500) DEFAULT ''"))

    image_columns = {col["name"] for col in inspector.get_columns("images")}
    with engine.begin() as conn:
        if "is_deleted" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN is_deleted BOOLEAN DEFAULT 0"))
        if "deleted_at" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN deleted_at DATETIME"))
        if "preview_url" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN preview_url VARCHAR(500) DEFAULT ''"))
        if "image_format" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN image_format VARCHAR(20) DEFAULT ''"))
        if "image_size_bytes" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN image_size_bytes INTEGER DEFAULT 0"))

    api_key_tables = set(inspector.get_table_names())
    if "api_keys" in api_key_tables:
        api_key_columns = {col["name"] for col in inspector.get_columns("api_keys")}
        with engine.begin() as conn:
            if "tongyi_key" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN tongyi_key VARCHAR(255) DEFAULT ''"))
            if "contact_qr_image" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN contact_qr_image VARCHAR(500) DEFAULT ''"))
            if "cos_secret_id" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN cos_secret_id VARCHAR(255) DEFAULT ''"))
            if "cos_secret_key" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN cos_secret_key VARCHAR(255) DEFAULT ''"))
            if "cos_bucket" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN cos_bucket VARCHAR(255) DEFAULT ''"))
            if "cos_region" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN cos_region VARCHAR(100) DEFAULT ''"))
            if "cos_public_base_url" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN cos_public_base_url VARCHAR(500) DEFAULT ''"))
            if "announcement_enabled" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN announcement_enabled INTEGER DEFAULT 0"))
            if "announcement_content" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN announcement_content VARCHAR(5000) DEFAULT ''"))
            if "announcement_updated_at" not in api_key_columns:
                conn.execute(text("ALTER TABLE api_keys ADD COLUMN announcement_updated_at DATETIME"))

    if "external_api_configs" in api_key_tables:
        external_api_columns = {col["name"] for col in inspector.get_columns("external_api_configs")}
        with engine.begin() as conn:
            if "group_name" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN group_name VARCHAR(100) DEFAULT '默认'"))
            if "model_key" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN model_key VARCHAR(50) DEFAULT ''"))
            if "model_label" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN model_label VARCHAR(100) DEFAULT ''"))
            if "model_description" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN model_description VARCHAR(255) DEFAULT ''"))
            if "sort_order" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN sort_order INTEGER DEFAULT 0"))
            if "hide_resolution" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN hide_resolution BOOLEAN DEFAULT 0"))
            if "supports_inpaint" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN supports_inpaint BOOLEAN DEFAULT 0"))
            if "is_active_inpaint" not in external_api_columns:
                conn.execute(text("ALTER TABLE external_api_configs ADD COLUMN is_active_inpaint BOOLEAN DEFAULT 0"))

    if "external_api_scene_bindings" in api_key_tables:
        scene_binding_columns = {col["name"] for col in inspector.get_columns("external_api_scene_bindings")}
        credit_cost_added = False
        with engine.begin() as conn:
            if "api_config_id" not in scene_binding_columns:
                conn.execute(text("ALTER TABLE external_api_scene_bindings ADD COLUMN api_config_id INTEGER"))
            if "credit_cost" not in scene_binding_columns:
                conn.execute(text("ALTER TABLE external_api_scene_bindings ADD COLUMN credit_cost INTEGER DEFAULT 0"))
                credit_cost_added = True

    from app.services.external_api_config_service import get_default_credit_cost

    if "external_api_scene_bindings" in api_key_tables:
        with engine.begin() as conn:
            for scene_key in ["banana", "banana2", "banana_pro", "banana_pro_plus", "prompt_reverse", "inpaint"]:
                conn.execute(
                    text(
                        """
                        UPDATE external_api_scene_bindings
                        SET credit_cost = :credit_cost
                        WHERE scene_key = :scene_key
                          AND credit_cost IS NULL
                        """
                    ),
                    {"scene_key": scene_key, "credit_cost": get_default_credit_cost(scene_key)},
                )
                if credit_cost_added:
                    conn.execute(
                        text(
                            """
                            UPDATE external_api_scene_bindings
                            SET credit_cost = :credit_cost
                            WHERE scene_key = :scene_key
                              AND credit_cost = 0
                            """
                        ),
                        {"scene_key": scene_key, "credit_cost": get_default_credit_cost(scene_key)},
                    )


def _ensure_template_required_columns():
    inspector = inspect(engine)
    if "templates" not in inspector.get_table_names():
        return

    template_columns = {col["name"] for col in inspector.get_columns("templates")}
    with engine.begin() as conn:
        if "model" not in template_columns:
            conn.execute(text("ALTER TABLE templates ADD COLUMN model VARCHAR(50) DEFAULT 'banana_pro'"))
        if "sort_order" not in template_columns:
            conn.execute(text("ALTER TABLE templates ADD COLUMN sort_order INTEGER DEFAULT 0"))


def _ensure_image_required_columns():
    inspector = inspect(engine)
    if "images" not in inspector.get_table_names():
        return

    image_columns = {col["name"] for col in inspector.get_columns("images")}
    with engine.begin() as conn:
        if "is_deleted" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN is_deleted BOOLEAN DEFAULT 0"))
        if "deleted_at" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN deleted_at DATETIME"))
        if "preview_url" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN preview_url VARCHAR(500) DEFAULT ''"))
        if "image_format" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN image_format VARCHAR(20) DEFAULT ''"))
        if "image_size_bytes" not in image_columns:
            conn.execute(text("ALTER TABLE images ADD COLUMN image_size_bytes INTEGER DEFAULT 0"))


def _initialize_template_sort_orders():
    from app.database import SessionLocal
    from app.models.template import Template

    _ensure_template_required_columns()

    db = SessionLocal()
    try:
        templates = (
            db.query(Template)
            .order_by(Template.created_at.asc(), Template.id.asc())
            .all()
        )
        if not templates:
            return

        has_initialized_sort = any((template.sort_order or 0) > 0 for template in templates)
        if has_initialized_sort:
            return

        for index, template in enumerate(templates, start=1):
            template.sort_order = index

        db.commit()
    finally:
        db.close()


def _seed_default_data():
    """Create default admin, superadmin, and sample styles on first run."""
    from app.database import SessionLocal
    from app.services.external_api_config_service import seed_legacy_configs
    from app.models.user import User
    from app.models.style import Style
    from app.models.style_prompt import StylePrompt
    from app.utils.security import hash_password

    db = SessionLocal()
    try:
        if not db.query(User).filter(User.role == "superadmin").first():
            db.add(User(
                username="administrator",
                password_hash=hash_password("administrator123"),
                role="superadmin",
            ))
            db.commit()

        if not db.query(User).filter(User.role.in_(["admin", "user"])).first():
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

        seed_legacy_configs(
            db,
            ai_api_url=settings.AI_API_URL,
            prompt_reverse_url="https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation",
        )
    finally:
        db.close()


upload_path = Path(settings.UPLOAD_DIR)
upload_path.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(upload_path)), name="uploads")

from app.api import auth, styles, tasks, images, history, admin, upload, api_key, templates, prompt_reverse, external_api_config  # noqa: E402
app.include_router(auth.router)
app.include_router(styles.router)
app.include_router(templates.router)
app.include_router(tasks.router)
app.include_router(images.router)
app.include_router(history.router)
app.include_router(admin.router)
app.include_router(upload.router)
app.include_router(api_key.router)
app.include_router(api_key.cos_router)
app.include_router(api_key.public_router)
app.include_router(prompt_reverse.router)
app.include_router(external_api_config.router)
app.include_router(external_api_config.scene_router)
app.include_router(external_api_config.public_router)
