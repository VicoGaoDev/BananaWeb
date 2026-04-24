from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from app.database import Base


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    model = Column(String(50), default="")
    mode = Column(String(20), default="generate")
    prompt = Column(Text, default="")
    num_images = Column(Integer, default=4)
    size = Column(String(20), default="3:4")
    resolution = Column(String(10), default="4K")
    custom_size = Column(String(50), default="")
    reference_image = Column(String(500), default="")
    reference_images = Column(Text, default="")
    source_image = Column(String(500), default="")
    mask_image = Column(String(500), default="")
    credit_cost = Column(Integer, nullable=False, default=0, server_default="0")
    status = Column(String(20), default="pending")
    error_message = Column(Text, default="")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", backref="tasks")
    images = relationship("Image", back_populates="task", lazy="selectin")
