# 空库一键初始化（MySQL）

在**无任何表**的数据库中执行以下脚本，创建与 `backend/app/models` 一致的结构，并插入默认管理员账号。

- 库 / 连接字符集请使用 `utf8mb4`（例如连接串加 `?charset=utf8mb4`）。
- `external_api_scene_bindings` 中三个 `TEXT` 字段在 MySQL 中不设默认值（`TEXT`/`BLOB` 在多数配置下不能带 `DEFAULT`），由应用层写入；与 ORM 的 Python 侧默认值 `[]` 行为一致。
- 若已由应用 `DB_AUTO_CREATE_TABLES` 建表，请勿重复执行建表；仅需按需插入 `users` 或改用 `DB_RUN_SEED`。
- 首次登录后请立即修改默认密码。

## 默认账号

| 用户名 | 初始密码 | 角色 |
|--------|----------|------|
| `administrator` | `administrator123` | `superadmin`（超级管理员） |
| `admin` | `admin123` | `admin`（管理员） |

## SQL

```sql
SET NAMES utf8mb4;

CREATE TABLE api_keys (
  id INT NOT NULL AUTO_INCREMENT,
  `key` VARCHAR(255) NOT NULL,
  tongyi_key VARCHAR(255) NOT NULL,
  contact_qr_image VARCHAR(500) NOT NULL,
  cos_secret_id VARCHAR(255) NOT NULL,
  cos_secret_key VARCHAR(255) NOT NULL,
  cos_bucket VARCHAR(255) NOT NULL,
  cos_region VARCHAR(100) NOT NULL,
  cos_public_base_url VARCHAR(500) NOT NULL,
  announcement_enabled INT NOT NULL,
  announcement_content VARCHAR(5000) NOT NULL,
  announcement_updated_at DATETIME NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE external_api_configs (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255) NOT NULL,
  group_name VARCHAR(100) NOT NULL,
  model_key VARCHAR(50) NOT NULL,
  model_label VARCHAR(100) NOT NULL,
  model_description VARCHAR(255) NOT NULL,
  sort_order INT NOT NULL,
  hide_resolution TINYINT(1) NOT NULL,
  request_url VARCHAR(500) NOT NULL,
  headers_json TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  response_json TEXT NOT NULL,
  result_base64_field VARCHAR(255) NOT NULL,
  supports_generation TINYINT(1) NOT NULL,
  supports_inpaint TINYINT(1) NOT NULL,
  supports_prompt_reverse TINYINT(1) NOT NULL,
  is_active_generation TINYINT(1) NOT NULL,
  is_active_inpaint TINYINT(1) NOT NULL,
  is_active_prompt_reverse TINYINT(1) NOT NULL,
  status VARCHAR(20) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_external_api_configs_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE template_tags (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE templates (
  id INT NOT NULL AUTO_INCREMENT,
  prompt TEXT NOT NULL,
  model VARCHAR(50) DEFAULT NULL,
  reference_images TEXT,
  size VARCHAR(20) DEFAULT NULL,
  resolution VARCHAR(10) DEFAULT NULL,
  custom_size VARCHAR(50) DEFAULT NULL,
  num_images INT DEFAULT NULL,
  result_image VARCHAR(255) DEFAULT NULL,
  sort_order INT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE users (
  id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  email VARCHAR(255) DEFAULT NULL,
  email_verified TINYINT(1) NOT NULL DEFAULT 0,
  password_hash VARCHAR(255) NOT NULL,
  avatar_url VARCHAR(500) DEFAULT NULL,
  `role` VARCHAR(20) DEFAULT NULL,
  status VARCHAR(10) DEFAULT NULL,
  is_whitelisted TINYINT(1) NOT NULL DEFAULT 0,
  credits INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE external_api_scene_bindings (
  id INT NOT NULL AUTO_INCREMENT,
  scene_key VARCHAR(50) NOT NULL,
  scene_type VARCHAR(30) NOT NULL DEFAULT 'generate',
  scene_label VARCHAR(100) NOT NULL DEFAULT '',
  scene_description VARCHAR(255) NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  hide_aspect_ratio TINYINT(1) NOT NULL DEFAULT 0,
  hide_resolution TINYINT(1) NOT NULL DEFAULT 0,
  hide_custom_size TINYINT(1) NOT NULL DEFAULT 1,
  status VARCHAR(20) NOT NULL DEFAULT 'enabled',
  api_config_id INT DEFAULT NULL,
  display_name VARCHAR(100) NOT NULL DEFAULT '',
  subtitle VARCHAR(255) NOT NULL DEFAULT '',
  credit_cost INT NOT NULL DEFAULT 0,
  aspect_ratio_options_json TEXT NOT NULL,
  image_size_options_json TEXT NOT NULL,
  custom_size_options_json TEXT NOT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_external_api_scene_bindings_scene_key (scene_key),
  CONSTRAINT fk_scene_api_config FOREIGN KEY (api_config_id) REFERENCES external_api_configs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE prompt_history (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  prompt VARCHAR(2000) NOT NULL,
  mode VARCHAR(20) NOT NULL DEFAULT 'generate',
  source_image VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_prompt_history_user_id (user_id),
  CONSTRAINT fk_prompt_history_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tasks (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  model VARCHAR(50) DEFAULT NULL,
  mode VARCHAR(20) DEFAULT NULL,
  prompt TEXT,
  num_images INT DEFAULT NULL,
  size VARCHAR(20) DEFAULT NULL,
  resolution VARCHAR(10) DEFAULT NULL,
  custom_size VARCHAR(50) DEFAULT NULL,
  reference_image VARCHAR(500) DEFAULT NULL,
  reference_images TEXT,
  source_image VARCHAR(500) DEFAULT NULL,
  mask_image VARCHAR(500) DEFAULT NULL,
  credit_cost INT NOT NULL DEFAULT 0,
  status VARCHAR(20) DEFAULT NULL,
  error_message TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_tasks_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE template_tag_relations (
  template_id INT NOT NULL,
  tag_id INT NOT NULL,
  PRIMARY KEY (template_id, tag_id),
  CONSTRAINT fk_ttr_template FOREIGN KEY (template_id) REFERENCES templates (id),
  CONSTRAINT fk_ttr_tag FOREIGN KEY (tag_id) REFERENCES template_tags (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE credit_logs (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  amount INT NOT NULL,
  type VARCHAR(20) NOT NULL,
  description VARCHAR(500) DEFAULT NULL,
  operator_id INT DEFAULT NULL,
  task_id INT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_credit_logs_user_id (user_id),
  CONSTRAINT fk_credit_logs_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_credit_logs_operator FOREIGN KEY (operator_id) REFERENCES users (id),
  CONSTRAINT fk_credit_logs_task FOREIGN KEY (task_id) REFERENCES tasks (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE images (
  id INT NOT NULL AUTO_INCREMENT,
  task_id INT NOT NULL,
  image_url VARCHAR(255) DEFAULT NULL,
  preview_url VARCHAR(500) DEFAULT NULL,
  image_format VARCHAR(20) DEFAULT NULL,
  image_size_bytes INT DEFAULT NULL,
  status VARCHAR(20) DEFAULT NULL,
  error_message VARCHAR(2000) DEFAULT NULL,
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_images_task FOREIGN KEY (task_id) REFERENCES tasks (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE regenerate_logs (
  id INT NOT NULL AUTO_INCREMENT,
  image_id INT NOT NULL,
  old_image_url VARCHAR(255) DEFAULT NULL,
  new_image_url VARCHAR(255) DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_regenerate_logs_image FOREIGN KEY (image_id) REFERENCES images (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE UNIQUE INDEX ix_users_email ON users (email);
CREATE INDEX ix_users_username ON users (username);
CREATE UNIQUE INDEX ix_template_tags_name ON template_tags (name);

INSERT INTO users (
  username, email, email_verified, password_hash, avatar_url,
  `role`, status, is_whitelisted, credits, created_at, updated_at
) VALUES
('administrator', NULL, 0, '$2b$12$CR1qnIGjLbi46hgFXXrxQOoPge5g0aWWuLga1fWGDC5GOBiIFY0vK', '', 'superadmin', 'active', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('admin', NULL, 0, '$2b$12$gGceM8aYPCpT9Kz0GJQvje0cvIS5y6HEFrXTGyeu4AzNbD7ANX..C', '', 'admin', 'active', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
```
