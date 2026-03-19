from sqlalchemy import Column, Integer, String, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class StylePrompt(Base):
    __tablename__ = "style_prompts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    style_id = Column(Integer, ForeignKey("styles.id"), nullable=False)
    prompt = Column(Text, nullable=False)
    negative_prompt = Column(Text, default="")
    sort_order = Column(Integer, default=0)

    style = relationship("Style", back_populates="prompts")
