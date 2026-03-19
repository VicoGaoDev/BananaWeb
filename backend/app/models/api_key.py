from sqlalchemy import Column, Integer, String, DateTime, func
from app.database import Base


class ApiKey(Base):
    __tablename__ = "api_keys"

    id = Column(Integer, primary_key=True, autoincrement=True)
    key = Column(String(255), nullable=False, default="")
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
