from sqlalchemy import Column, Integer, String, DateTime, func
from sqlalchemy.orm import relationship
from app.database import Base


class Style(Base):
    __tablename__ = "styles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    cover_image = Column(String(255), default="")
    description = Column(String(255), default="")
    created_at = Column(DateTime, server_default=func.now())

    prompts = relationship("StylePrompt", back_populates="style", lazy="selectin")
