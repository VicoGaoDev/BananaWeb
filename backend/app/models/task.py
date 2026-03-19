from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from app.database import Base


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    style_id = Column(Integer, ForeignKey("styles.id"), nullable=False)
    model = Column(String(50), default="banana-pro")
    size = Column(String(20), default="1024x1024")
    reference_image = Column(String(500), default="")
    status = Column(String(20), default="pending")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", backref="tasks")
    style = relationship("Style", backref="tasks")
    images = relationship("Image", back_populates="task", lazy="selectin")
