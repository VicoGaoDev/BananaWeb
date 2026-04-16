from calendar import monthrange
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from app.models.user import User
from app.models.task import Task
from app.models.credit_log import CreditLog
from app.utils.security import hash_password

LOCAL_TZ = ZoneInfo("Asia/Shanghai")


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


def _to_local_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=LOCAL_TZ)
    return value.astimezone(LOCAL_TZ)


def _to_db_datetime(value: datetime) -> datetime:
    return _to_local_datetime(value).replace(tzinfo=None)


def _start_of_day(value: datetime) -> datetime:
    value = _to_local_datetime(value)
    return value.replace(hour=0, minute=0, second=0, microsecond=0)


def _end_of_day(value: datetime) -> datetime:
    value = _to_local_datetime(value)
    return value.replace(hour=23, minute=59, second=59, microsecond=999999)


def _start_of_week(value: datetime) -> datetime:
    value = _start_of_day(value)
    return value - timedelta(days=value.weekday())


def _end_of_week(value: datetime) -> datetime:
    return _start_of_week(value) + timedelta(days=6, hours=23, minutes=59, seconds=59, microseconds=999999)


def _start_of_month(value: datetime) -> datetime:
    value = _to_local_datetime(value)
    return value.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def _shift_months(value: datetime, months: int) -> datetime:
    value = _to_local_datetime(value)
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    day = min(value.day, monthrange(year, month)[1])
    return value.replace(year=year, month=month, day=day)


def _end_of_month(value: datetime) -> datetime:
    month_start = _start_of_month(value)
    next_month = _shift_months(month_start, 1)
    return next_month - timedelta(microseconds=1)


def _format_range_label(start: datetime, end: datetime) -> str:
    return f"{start.strftime('%Y-%m-%d')} ~ {end.strftime('%Y-%m-%d')}"


def _align_range(
    granularity: str,
    start_date: datetime | None,
    end_date: datetime | None,
) -> tuple[datetime, datetime]:
    now = datetime.now(LOCAL_TZ)
    if start_date is None or end_date is None:
        if granularity == "day":
            end = _end_of_day(now)
            start = _start_of_day(now - timedelta(days=6))
        elif granularity == "week":
            end = _end_of_week(now)
            start = _start_of_week(now) - timedelta(weeks=7)
        else:
            end = _end_of_month(now)
            start = _start_of_month(_shift_months(now, -5))
        return start, end

    if granularity == "day":
        start = _start_of_day(start_date)
        end = _end_of_day(end_date)
    elif granularity == "week":
        start = _start_of_week(start_date)
        end = _end_of_week(end_date)
    else:
        start = _start_of_month(start_date)
        end = _end_of_month(end_date)

    if end < start:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="结束时间不能早于开始时间")
    return start, end


def _iter_bucket_starts(start: datetime, end: datetime, granularity: str) -> list[datetime]:
    buckets: list[datetime] = []
    cursor = start
    while cursor <= end:
        buckets.append(cursor)
        if granularity == "day":
            cursor += timedelta(days=1)
        elif granularity == "week":
            cursor += timedelta(weeks=1)
        else:
            cursor = _start_of_month(_shift_months(cursor, 1))
    return buckets


def _previous_range(start: datetime, end: datetime, granularity: str) -> tuple[datetime, datetime]:
    bucket_count = len(_iter_bucket_starts(start, end, granularity))
    if granularity == "day":
        previous_start = start - timedelta(days=bucket_count)
    elif granularity == "week":
        previous_start = start - timedelta(weeks=bucket_count)
    else:
        previous_start = _start_of_month(_shift_months(start, -bucket_count))
    previous_end = start - timedelta(microseconds=1)
    return previous_start, previous_end


def _bucket_start(value: datetime, granularity: str) -> datetime:
    if granularity == "day":
        return _start_of_day(value)
    if granularity == "week":
        return _start_of_week(value)
    return _start_of_month(value)


def _bucket_end(value: datetime, granularity: str) -> datetime:
    if granularity == "day":
        return _end_of_day(value)
    if granularity == "week":
        return _end_of_week(value)
    return _end_of_month(value)


def _bucket_label(value: datetime, granularity: str) -> str:
    if granularity == "day":
        return value.strftime("%m-%d")
    if granularity == "week":
        week_end = value + timedelta(days=6)
        return f"{value.strftime('%m-%d')} ~ {week_end.strftime('%m-%d')}"
    return value.strftime("%Y-%m")


def _metric_payload(current: int, previous: int) -> dict:
    delta = current - previous
    delta_pct = None if previous == 0 else round(delta / previous * 100, 1)
    return {
        "current": current,
        "previous": previous,
        "delta": delta,
        "delta_pct": delta_pct,
    }


def _task_query(
    db: Session,
    *,
    start_date: datetime,
    end_date: datetime,
    status_filter: str | None = None,
    user_id: int | None = None,
    model: str | None = None,
    mode: str | None = None,
):
    query = db.query(Task).filter(
        Task.created_at >= _to_db_datetime(start_date),
        Task.created_at <= _to_db_datetime(end_date),
    )
    if status_filter:
        query = query.filter(Task.status == status_filter)
    if user_id:
        query = query.filter(Task.user_id == user_id)
    if model:
        query = query.filter(Task.model == model)
    if mode:
        query = query.filter(Task.mode == mode)
    return query


def _user_query(
    db: Session,
    *,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    user_id: int | None = None,
):
    query = db.query(User).filter(User.role != "superadmin")
    if start_date is not None:
        query = query.filter(User.created_at >= _to_db_datetime(start_date))
    if end_date is not None:
        query = query.filter(User.created_at <= _to_db_datetime(end_date))
    if user_id:
        query = query.filter(User.id == user_id)
    return query


def _task_summary_metrics(tasks: list[Task], user_roles: dict[int, str]) -> dict[str, int]:
    return {
        "tasks_created": len(tasks),
        "success_tasks": sum(1 for task in tasks if task.status == "success"),
        "failed_tasks": sum(1 for task in tasks if task.status == "failed"),
        "credits_consumed": sum(int(task.credit_cost or 0) for task in tasks),
        "active_users": len({
            task.user_id
            for task in tasks
            if user_roles.get(task.user_id, "user") != "superadmin"
        }),
    }


def _build_timeseries_points(
    bucket_starts: list[datetime],
    *,
    granularity: str,
    tasks: list[Task],
    users: list[User],
    user_roles: dict[int, str],
) -> list[dict]:
    bucket_map = {
        bucket: {
            "label": _bucket_label(bucket, granularity),
            "bucket_start": bucket,
            "bucket_end": _bucket_end(bucket, granularity),
            "tasks_created": 0,
            "success_tasks": 0,
            "failed_tasks": 0,
            "credits_consumed": 0,
            "new_users": 0,
            "active_users": 0,
            "_active_user_ids": set(),
        }
        for bucket in bucket_starts
    }

    for task in tasks:
        bucket = _bucket_start(_to_local_datetime(task.created_at), granularity)
        if bucket not in bucket_map:
            continue
        item = bucket_map[bucket]
        item["tasks_created"] += 1
        item["credits_consumed"] += int(task.credit_cost or 0)
        if task.status == "success":
            item["success_tasks"] += 1
        if task.status == "failed":
            item["failed_tasks"] += 1
        if user_roles.get(task.user_id, "user") != "superadmin":
            item["_active_user_ids"].add(task.user_id)

    for user in users:
        bucket = _bucket_start(_to_local_datetime(user.created_at), granularity)
        if bucket in bucket_map:
            bucket_map[bucket]["new_users"] += 1

    result: list[dict] = []
    for bucket in bucket_starts:
        item = bucket_map[bucket]
        item["active_users"] = len(item.pop("_active_user_ids"))
        result.append(item)
    return result


def get_analytics_summary(
    db: Session,
    *,
    granularity: str = "day",
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    user_id: int | None = None,
    model: str | None = None,
    mode: str | None = None,
    status_filter: str | None = None,
) -> dict:
    current_start, current_end = _align_range(granularity, start_date, end_date)
    previous_start, previous_end = _previous_range(current_start, current_end, granularity)

    current_tasks = _task_query(
        db,
        start_date=current_start,
        end_date=current_end,
        status_filter=status_filter,
        user_id=user_id,
        model=model,
        mode=mode,
    ).all()
    previous_tasks = _task_query(
        db,
        start_date=previous_start,
        end_date=previous_end,
        status_filter=status_filter,
        user_id=user_id,
        model=model,
        mode=mode,
    ).all()

    relevant_user_ids = {task.user_id for task in current_tasks + previous_tasks}
    users_by_id = {
        user.id: user
        for user in db.query(User).filter(User.id.in_(relevant_user_ids)).all()
    } if relevant_user_ids else {}
    user_roles = {user_id_key: user.role for user_id_key, user in users_by_id.items()}

    current_metrics = _task_summary_metrics(current_tasks, user_roles)
    previous_metrics = _task_summary_metrics(previous_tasks, user_roles)
    current_new_users = _user_query(db, start_date=current_start, end_date=current_end, user_id=user_id).count()
    previous_new_users = _user_query(db, start_date=previous_start, end_date=previous_end, user_id=user_id).count()
    total_users = _user_query(db).count()

    return {
        "granularity": granularity,
        "current_range_label": _format_range_label(current_start, current_end),
        "previous_range_label": _format_range_label(previous_start, previous_end),
        "total_users": total_users,
        "tasks_created": _metric_payload(current_metrics["tasks_created"], previous_metrics["tasks_created"]),
        "success_tasks": _metric_payload(current_metrics["success_tasks"], previous_metrics["success_tasks"]),
        "failed_tasks": _metric_payload(current_metrics["failed_tasks"], previous_metrics["failed_tasks"]),
        "credits_consumed": _metric_payload(current_metrics["credits_consumed"], previous_metrics["credits_consumed"]),
        "new_users": _metric_payload(current_new_users, previous_new_users),
        "active_users": _metric_payload(current_metrics["active_users"], previous_metrics["active_users"]),
    }


def get_analytics_timeseries(
    db: Session,
    *,
    granularity: str = "day",
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    user_id: int | None = None,
    model: str | None = None,
    mode: str | None = None,
    status_filter: str | None = None,
) -> dict:
    current_start, current_end = _align_range(granularity, start_date, end_date)
    previous_start, previous_end = _previous_range(current_start, current_end, granularity)
    current_bucket_starts = _iter_bucket_starts(current_start, current_end, granularity)
    previous_bucket_starts = _iter_bucket_starts(previous_start, previous_end, granularity)

    current_tasks = _task_query(
        db,
        start_date=current_start,
        end_date=current_end,
        status_filter=status_filter,
        user_id=user_id,
        model=model,
        mode=mode,
    ).all()
    previous_tasks = _task_query(
        db,
        start_date=previous_start,
        end_date=previous_end,
        status_filter=status_filter,
        user_id=user_id,
        model=model,
        mode=mode,
    ).all()
    current_users = _user_query(db, start_date=current_start, end_date=current_end, user_id=user_id).all()
    previous_users = _user_query(db, start_date=previous_start, end_date=previous_end, user_id=user_id).all()

    relevant_user_ids = {
        task.user_id for task in current_tasks + previous_tasks
    }
    users_by_id = {
        user.id: user
        for user in db.query(User).filter(User.id.in_(relevant_user_ids)).all()
    } if relevant_user_ids else {}
    user_roles = {user_id_key: user.role for user_id_key, user in users_by_id.items()}

    return {
        "granularity": granularity,
        "current_range_label": _format_range_label(current_start, current_end),
        "previous_range_label": _format_range_label(previous_start, previous_end),
        "current": _build_timeseries_points(
            current_bucket_starts,
            granularity=granularity,
            tasks=current_tasks,
            users=current_users,
            user_roles=user_roles,
        ),
        "previous": _build_timeseries_points(
            previous_bucket_starts,
            granularity=granularity,
            tasks=previous_tasks,
            users=previous_users,
            user_roles=user_roles,
        ),
    }


def _sorted_breakdown(items: dict[str, dict[str, int]], limit: int | None = None) -> list[dict]:
    rows = [
        {"name": name, "count": payload["count"], "credit_cost": payload["credit_cost"]}
        for name, payload in items.items()
    ]
    rows.sort(key=lambda item: (item["count"], item["credit_cost"], item["name"]), reverse=True)
    if limit is not None:
        return rows[:limit]
    return rows


def get_analytics_breakdown(
    db: Session,
    *,
    granularity: str = "day",
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    user_id: int | None = None,
    model: str | None = None,
    mode: str | None = None,
    status_filter: str | None = None,
) -> dict:
    current_start, current_end = _align_range(granularity, start_date, end_date)
    tasks = _task_query(
        db,
        start_date=current_start,
        end_date=current_end,
        status_filter=status_filter,
        user_id=user_id,
        model=model,
        mode=mode,
    ).all()

    relevant_user_ids = {task.user_id for task in tasks}
    users_by_id = {
        user.id: user
        for user in db.query(User).filter(User.id.in_(relevant_user_ids)).all()
    } if relevant_user_ids else {}

    status_breakdown: dict[str, dict[str, int]] = defaultdict(lambda: {"count": 0, "credit_cost": 0})
    mode_breakdown: dict[str, dict[str, int]] = defaultdict(lambda: {"count": 0, "credit_cost": 0})
    model_breakdown: dict[str, dict[str, int]] = defaultdict(lambda: {"count": 0, "credit_cost": 0})
    user_task_breakdown: dict[str, dict[str, int]] = defaultdict(lambda: {"count": 0, "credit_cost": 0})

    for task in tasks:
        task_cost = int(task.credit_cost or 0)
        status_key = task.status or "unknown"
        mode_key = task.mode or "generate"
        model_key = task.model or "未设置"

        status_breakdown[status_key]["count"] += 1
        status_breakdown[status_key]["credit_cost"] += task_cost

        mode_breakdown[mode_key]["count"] += 1
        mode_breakdown[mode_key]["credit_cost"] += task_cost

        model_breakdown[model_key]["count"] += 1
        model_breakdown[model_key]["credit_cost"] += task_cost

        user = users_by_id.get(task.user_id)
        if user and user.role != "superadmin":
            user_task_breakdown[user.username]["count"] += 1
            user_task_breakdown[user.username]["credit_cost"] += task_cost

    user_breakdown_rows = _sorted_breakdown(user_task_breakdown)
    top_users_by_tasks = user_breakdown_rows[:8]
    top_users_by_credit = sorted(
        user_breakdown_rows,
        key=lambda item: (item["credit_cost"], item["count"], item["name"]),
        reverse=True,
    )

    return {
        "range_label": _format_range_label(current_start, current_end),
        "status_breakdown": _sorted_breakdown(status_breakdown),
        "mode_breakdown": _sorted_breakdown(mode_breakdown),
        "model_breakdown": _sorted_breakdown(model_breakdown, limit=8),
        "top_users_by_tasks": top_users_by_tasks,
        "top_users_by_credit": top_users_by_credit[:8],
    }
