from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func
from app.database import Base


class PromptHistory(Base):
    __tablename__ = "prompt_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    prompt = Column(String(2000), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
