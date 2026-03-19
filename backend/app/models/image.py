from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from app.database import Base


class Image(Base):
    __tablename__ = "images"

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=False)
    prompt_id = Column(Integer, ForeignKey("style_prompts.id"), nullable=True)
    image_url = Column(String(255), default="")
    status = Column(String(20), default="pending")
    created_at = Column(DateTime, server_default=func.now())

    task = relationship("Task", back_populates="images")
    prompt = relationship("StylePrompt")
