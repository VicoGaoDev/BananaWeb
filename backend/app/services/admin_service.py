from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from app.models.user import User
from app.models.task import Task
from app.models.credit_log import CreditLog
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


def allocate_credits(db: Session, user_id: int, amount: int, description: str, operator_id: int) -> User:
    if amount == 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="积分数量不能为 0")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="用户不存在")
    if user.credits + amount < 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="扣减后积分不能为负数")

    user.credits += amount
    log = CreditLog(
        user_id=user_id,
        amount=amount,
        type="allocate",
        description=description or ("管理员充值" if amount > 0 else "管理员扣减"),
        operator_id=operator_id,
    )
    db.add(log)
    db.commit()
    db.refresh(user)
    return user


def get_credit_logs(
    db: Session,
    user_id: int | None = None,
    page: int = 1,
    page_size: int = 20,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
) -> dict:
    query = db.query(CreditLog)
    if user_id is not None:
        query = query.filter(CreditLog.user_id == user_id)
    if start_date is not None:
        query = query.filter(CreditLog.created_at >= start_date)
    if end_date is not None:
        query = query.filter(CreditLog.created_at <= end_date)
    total = query.count()
    logs = query.order_by(CreditLog.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()

    items = []
    for log in logs:
        user = db.query(User).filter(User.id == log.user_id).first()
        operator = db.query(User).filter(User.id == log.operator_id).first() if log.operator_id else None
        items.append({
            "id": log.id,
            "user_id": log.user_id,
            "username": user.username if user else "",
            "amount": log.amount,
            "type": log.type,
            "description": log.description,
            "operator_name": operator.username if operator else "",
            "task_id": log.task_id,
            "created_at": log.created_at,
        })
    return {"total": total, "items": items}


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
