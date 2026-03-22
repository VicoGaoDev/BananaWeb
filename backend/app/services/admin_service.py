from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from app.models.user import User
from app.models.task import Task
from app.utils.security import hash_password


def _get_first_admin_id(db: Session) -> int | None:
    first = db.query(User).filter(User.role == "admin").order_by(User.created_at.asc()).first()
    return first.id if first else None


def create_user(db: Session, username: str, password: str, role: str = "user") -> User:
    if username == "administrator":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="该用户名为系统保留，不可使用")
    exists = db.query(User).filter(User.username == username).first()
    if exists:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="用户名已存在")
    if len(password) < 6:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="密码至少6位")
    if role not in ("user", "admin"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="角色必须是 user 或 admin")

    user = User(username=username, password_hash=hash_password(password), role=role)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def list_users(db: Session) -> list[User]:
    return (
        db.query(User)
        .filter(User.role != "superadmin")
        .order_by(User.created_at.desc())
        .all()
    )


def update_user_status(db: Session, user_id: int, new_status: str) -> User:
    if new_status not in ("active", "disabled"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="状态必须是 active 或 disabled")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="用户不存在")
    if user.role == "superadmin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无法修改超级管理员")
    if user.id == _get_first_admin_id(db) and new_status == "disabled":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="初始管理员不允许被禁用")

    user.status = new_status
    db.commit()
    db.refresh(user)
    return user


def update_user_role(db: Session, user_id: int, new_role: str) -> User:
    if new_role not in ("user", "admin"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="角色必须是 user 或 admin")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="用户不存在")
    if user.role == "superadmin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无法修改超级管理员")
    if user.id == _get_first_admin_id(db) and new_role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="初始管理员不允许被降级")

    user.role = new_role
    db.commit()
    db.refresh(user)
    return user


def reset_user_password(db: Session, user_id: int, new_password: str) -> User:
    if len(new_password) < 6:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="新密码至少6位")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="用户不存在")
    if user.role == "superadmin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无法重置超级管理员密码")

    user.password_hash = hash_password(new_password)
    db.commit()
    db.refresh(user)
    return user


def get_stats(db: Session) -> dict:
    now = datetime.now(timezone.utc)
    last_7 = db.query(func.count(Task.id)).filter(Task.created_at >= now - timedelta(days=7)).scalar()
    last_30 = db.query(func.count(Task.id)).filter(Task.created_at >= now - timedelta(days=30)).scalar()
    total_users = db.query(func.count(User.id)).filter(User.role != "superadmin").scalar()
    active_users = db.query(func.count(User.id)).filter(User.status == "active", User.role != "superadmin").scalar()

    return {
        "last_7_days": last_7 or 0,
        "last_30_days": last_30 or 0,
        "total_users": total_users or 0,
        "active_users": active_users or 0,
    }
