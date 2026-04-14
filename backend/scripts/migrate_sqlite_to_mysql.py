#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from sqlalchemy import MetaData, Table, create_engine, func, inspect, select, text
from sqlalchemy.engine import Engine, make_url

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from app.config import settings
from app.database import Base
import app.models  # noqa: F401

TABLE_ORDER = [
    "users",
    "styles",
    "template_tags",
    "api_keys",
    "external_api_configs",
    "style_prompts",
    "templates",
    "external_api_scene_bindings",
    "template_tag_relations",
    "tasks",
    "images",
    "prompt_history",
    "credit_logs",
    "regenerate_logs",
]

FK_CHECKS = [
    (
        "tasks.user_id -> users.id",
        """
        SELECT COUNT(*)
        FROM tasks AS child
        LEFT JOIN users AS parent ON parent.id = child.user_id
        WHERE child.user_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "tasks.style_id -> styles.id",
        """
        SELECT COUNT(*)
        FROM tasks AS child
        LEFT JOIN styles AS parent ON parent.id = child.style_id
        WHERE child.style_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "images.task_id -> tasks.id",
        """
        SELECT COUNT(*)
        FROM images AS child
        LEFT JOIN tasks AS parent ON parent.id = child.task_id
        WHERE child.task_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "style_prompts.style_id -> styles.id",
        """
        SELECT COUNT(*)
        FROM style_prompts AS child
        LEFT JOIN styles AS parent ON parent.id = child.style_id
        WHERE child.style_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "template_tag_relations.template_id -> templates.id",
        """
        SELECT COUNT(*)
        FROM template_tag_relations AS child
        LEFT JOIN templates AS parent ON parent.id = child.template_id
        WHERE parent.id IS NULL
        """,
    ),
    (
        "template_tag_relations.tag_id -> template_tags.id",
        """
        SELECT COUNT(*)
        FROM template_tag_relations AS child
        LEFT JOIN template_tags AS parent ON parent.id = child.tag_id
        WHERE parent.id IS NULL
        """,
    ),
    (
        "credit_logs.user_id -> users.id",
        """
        SELECT COUNT(*)
        FROM credit_logs AS child
        LEFT JOIN users AS parent ON parent.id = child.user_id
        WHERE child.user_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "credit_logs.operator_id -> users.id",
        """
        SELECT COUNT(*)
        FROM credit_logs AS child
        LEFT JOIN users AS parent ON parent.id = child.operator_id
        WHERE child.operator_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "credit_logs.task_id -> tasks.id",
        """
        SELECT COUNT(*)
        FROM credit_logs AS child
        LEFT JOIN tasks AS parent ON parent.id = child.task_id
        WHERE child.task_id IS NOT NULL AND parent.id IS NULL
        """,
        ),
    (
        "regenerate_logs.image_id -> images.id",
        """
        SELECT COUNT(*)
        FROM regenerate_logs AS child
        LEFT JOIN images AS parent ON parent.id = child.image_id
        WHERE child.image_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "prompt_history.user_id -> users.id",
        """
        SELECT COUNT(*)
        FROM prompt_history AS child
        LEFT JOIN users AS parent ON parent.id = child.user_id
        WHERE child.user_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
    (
        "external_api_scene_bindings.api_config_id -> external_api_configs.id",
        """
        SELECT COUNT(*)
        FROM external_api_scene_bindings AS child
        LEFT JOIN external_api_configs AS parent ON parent.id = child.api_config_id
        WHERE child.api_config_id IS NOT NULL AND parent.id IS NULL
        """,
    ),
]


def sqlite_url_from_path(path: str) -> str:
    return f"sqlite:///{Path(path).resolve()}"


def build_engine(database_url: str) -> Engine:
    engine_kwargs = {}
    if database_url.startswith("sqlite"):
        engine_kwargs["connect_args"] = {"check_same_thread": False}
    else:
        engine_kwargs["pool_pre_ping"] = True
    return create_engine(database_url, **engine_kwargs)


def redact_database_url(database_url: str) -> str:
    return make_url(database_url).render_as_string(hide_password=True)


def scalar_count(engine: Engine, table_name: str) -> int:
    metadata = MetaData()
    table = Table(table_name, metadata, autoload_with=engine)
    with engine.connect() as conn:
        return int(conn.execute(select(func.count()).select_from(table)).scalar_one())


def ensure_source_database(sqlite_path: str) -> None:
    if not Path(sqlite_path).exists():
        raise SystemExit(f"SQLite 源库不存在: {sqlite_path}")


def ensure_mysql_target(database_url: str) -> None:
    if not database_url:
        raise SystemExit("请通过 --target-url 或 DATABASE_URL 提供 MySQL 连接串")
    if not database_url.startswith("mysql"):
        raise SystemExit(f"目标库必须是 MySQL，当前为: {redact_database_url(database_url)}")


def ensure_target_is_empty(target_engine: Engine) -> None:
    inspector = inspect(target_engine)
    existing_tables = set(inspector.get_table_names())
    occupied_tables: list[str] = []
    for table_name in TABLE_ORDER:
        if table_name not in existing_tables:
            continue
        if scalar_count(target_engine, table_name) > 0:
            occupied_tables.append(table_name)
    if occupied_tables:
        joined = ", ".join(occupied_tables)
        raise SystemExit(f"MySQL 目标库不是空库，以下表已有数据: {joined}")


def migrate_table(table_name: str, source_engine: Engine, target_engine: Engine) -> int:
    source_metadata = MetaData()
    target_metadata = MetaData()
    source_table = Table(table_name, source_metadata, autoload_with=source_engine)
    target_table = Table(table_name, target_metadata, autoload_with=target_engine)

    with source_engine.connect() as source_conn:
        rows = [dict(row) for row in source_conn.execute(select(source_table)).mappings()]

    if not rows:
        return 0

    with target_engine.begin() as target_conn:
        target_conn.execute(target_table.insert(), rows)

    return len(rows)


def sync_auto_increment(target_engine: Engine, table_name: str) -> None:
    metadata = MetaData()
    table = Table(table_name, metadata, autoload_with=target_engine)
    if "id" not in table.c:
        return

    with target_engine.begin() as conn:
        max_id = int(conn.execute(select(func.max(table.c.id))).scalar() or 0)
        conn.execute(text(f"ALTER TABLE `{table_name}` AUTO_INCREMENT = {max_id + 1}"))


def collect_counts(engine: Engine) -> dict[str, int]:
    return {table_name: scalar_count(engine, table_name) for table_name in TABLE_ORDER}


def validate_counts(source_engine: Engine, target_engine: Engine) -> list[str]:
    source_counts = collect_counts(source_engine)
    target_counts = collect_counts(target_engine)
    problems: list[str] = []

    print("\n[Count Check]")
    for table_name in TABLE_ORDER:
        source_count = source_counts[table_name]
        target_count = target_counts[table_name]
        status = "OK" if source_count == target_count else "MISMATCH"
        print(f"- {table_name}: sqlite={source_count}, mysql={target_count} [{status}]")
        if source_count != target_count:
            problems.append(f"{table_name} 行数不一致: sqlite={source_count}, mysql={target_count}")

    return problems


def validate_foreign_keys(target_engine: Engine) -> list[str]:
    problems: list[str] = []

    print("\n[Foreign Key Check]")
    with target_engine.connect() as conn:
        for label, sql in FK_CHECKS:
            orphan_count = int(conn.execute(text(sql)).scalar_one())
            status = "OK" if orphan_count == 0 else "BROKEN"
            print(f"- {label}: {orphan_count} [{status}]")
            if orphan_count:
                problems.append(f"{label} 存在 {orphan_count} 条孤儿记录")

    return problems


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="将 BananaWeb 的 SQLite 数据迁移到 MySQL")
    parser.add_argument(
        "--sqlite-path",
        default=settings.DB_PATH,
        help="SQLite 源库路径，默认读取 app.config 中的 DB_PATH",
    )
    parser.add_argument(
        "--target-url",
        default=settings.DATABASE_URL or "",
        help="MySQL 目标连接串，优先使用 mysql+pymysql://...",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="只做 MySQL 与 SQLite 的校验，不执行迁移写入",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ensure_source_database(args.sqlite_path)

    source_url = sqlite_url_from_path(args.sqlite_path)
    target_url = args.target_url.strip()
    ensure_mysql_target(target_url)

    print(f"SQLite source: {source_url}")
    print(f"MySQL target: {redact_database_url(target_url)}")

    source_engine = build_engine(source_url)
    target_engine = build_engine(target_url)

    try:
        if not args.validate_only:
            ensure_target_is_empty(target_engine)
            Base.metadata.create_all(bind=target_engine)
            print("\n[Migrate Tables]")
            for table_name in TABLE_ORDER:
                row_count = migrate_table(table_name, source_engine, target_engine)
                print(f"- {table_name}: inserted {row_count} rows")
            for table_name in TABLE_ORDER:
                sync_auto_increment(target_engine, table_name)

        problems = []
        problems.extend(validate_counts(source_engine, target_engine))
        problems.extend(validate_foreign_keys(target_engine))

        if problems:
            print("\n[Validation Failed]")
            for item in problems:
                print(f"- {item}")
            return 1

        print("\n[Validation Passed] SQLite 与 MySQL 数据一致，可继续切换应用配置。")
        return 0
    finally:
        source_engine.dispose()
        target_engine.dispose()


if __name__ == "__main__":
    sys.exit(main())
