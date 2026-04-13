from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func

from app.database import Base


class ExternalApiSceneBinding(Base):
    __tablename__ = "external_api_scene_bindings"

    id = Column(Integer, primary_key=True, autoincrement=True)
    scene_key = Column(String(50), nullable=False, unique=True)
    api_config_id = Column(Integer, ForeignKey("external_api_configs.id"), nullable=True)
    credit_cost = Column(Integer, nullable=False, default=0, server_default="0")
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
