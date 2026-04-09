# 🧾 AI 绘图系统 — 产品需求文档

> 基于提示词的 AI 批量出图系统，支持多参考图上传与自定义生成数量
> 最后更新：2026-04-09

---

# 一、技术架构

## 1.1 技术栈

| 层 | 技术 |
|---|---|
| 前端 | Vue 3 + TypeScript + Ant Design Vue 4 + Pinia |
| 后端 | Python FastAPI + SQLAlchemy 2.0 + SQLite（WAL 模式） |
| AI 接口 | Gemini API（Nano Banana Pro），base64 图片交互 |
| 异步任务 | Celery + Redis（可选，无 Redis 自动降级为后台线程） |
| 部署 | 前端 Vercel / 后端 VPS 或 Railway |

## 1.2 项目结构

```
Banana_Web/
├── frontend/                 # Vue 3 前端
│   ├── src/
│   │   ├── api/              # Axios API 请求层
│   │   │   ├── auth.ts       # 登录、修改密码
│   │   │   ├── tasks.ts      # 创建/查询生成任务
│   │   │   ├── images.ts     # 图片下载、重新生成
│   │   │   ├── upload.ts     # 参考图上传
│   │   │   ├── admin.ts      # 管理员接口（用户/统计/API Key）
│   │   │   └── client.ts     # Axios 实例 + JWT 拦截器
│   │   ├── stores/auth.ts    # Pinia 认证状态
│   │   ├── views/            # 页面
│   │   │   ├── GenerateView.vue
│   │   │   ├── HistoryView.vue
│   │   │   └── admin/
│   │   │       ├── UserManageView.vue
│   │   │       ├── DashboardView.vue
│   │   │       └── ApiKeyView.vue
│   │   ├── components/
│   │   │   ├── ImageCard.vue        # 图片结果卡片
│   │   │   └── layout/AppLayout.vue # 顶部导航布局（含登录弹窗）
│   │   ├── router/index.ts
│   │   ├── types/index.ts
│   │   └── composables/usePolling.ts
│   └── vercel.json
├── backend/
│   ├── app/
│   │   ├── api/              # FastAPI 路由
│   │   │   ├── auth.py
│   │   │   ├── styles.py
│   │   │   ├── tasks.py
│   │   │   ├── images.py
│   │   │   ├── history.py
│   │   │   ├── upload.py
│   │   │   ├── admin.py
│   │   │   ├── api_key.py
│   │   │   └── deps.py       # 鉴权依赖（get_current_user / require_admin）
│   │   ├── models/           # SQLAlchemy ORM
│   │   │   ├── user.py
│   │   │   ├── style.py
│   │   │   ├── style_prompt.py
│   │   │   ├── task.py
│   │   │   ├── image.py
│   │   │   ├── regenerate_log.py
│   │   │   └── api_key.py
│   │   ├── schemas/          # Pydantic 请求/响应模型
│   │   ├── services/         # 业务逻辑
│   │   ├── workers/          # 生图任务（Gemini API 调用）
│   │   │   ├── generation.py
│   │   │   └── celery_app.py
│   │   ├── static/error.svg  # 兜底错误图片
│   │   ├── utils/security.py # 密码哈希 + JWT
│   │   ├── config.py
│   │   ├── database.py
│   │   └── main.py
│   ├── data/                 # SQLite 数据库（自动创建）
│   ├── uploads/              # 上传文件 + 生成图片
│   └── requirements.txt
└── prd.md
```

---

# 二、系统模块划分

系统分为 5 大模块：

1. **用户认证模块** — 弹窗登录 / 修改密码 / JWT 鉴权
2. **绘图主功能模块** — 提示词输入 / 多参考图上传 / 生成数量选择 / AI 生图
3. **历史记录模块** — 生成结果浏览与管理
4. **后台管理模块** — 用户管理 / 数据统计 / API Key 管理
5. **AI 生图引擎** — 对接 Gemini API，base64 图片交互

---

# 三、用户认证模块

## 3.1 功能说明

- 无单独登录页，用户在主页顶部点击"登录"按钮弹出登录 Dialog
- 用户通过「用户名 + 密码」登录系统，获取 JWT Token
- Token 有效期 24 小时（可配置）
- 未登录用户可浏览主页，但生成图片需先登录
- 支持用户修改密码

## 3.2 权限规则

- ❌ 普通用户**不可注册**
- ✅ 仅管理员可以创建账号
- ✅ 管理员可禁用/启用账号
- ✅ 管理员可设置其他用户为管理员

## 3.3 功能列表

| 角色 | 功能 |
|---|---|
| 普通用户 | 登录、修改密码 |
| 管理员 | 创建用户、禁用/启用账号、设置管理员权限 |

## 3.4 默认数据

系统首次启动自动创建默认管理员：`admin` / `admin123`

---

# 四、绘图主功能模块（核心）

## 4.1 页面布局

上下分区布局：

| 上方左侧面板 | 上方右侧面板 |
|---|---|
| 参考图上传区（最多 6 张，3 列网格展示） | 绘图设置面板 |
| 支持逐张上传、逐张删除 | 提示词输入框（最多 2000 字） |
| | 生成数量选择（1-8 张） |
| | 图片尺寸选择（1:1 / 2:3 / 3:2 / 3:4 / 4:3 / 9:16 / 16:9） |
| | 生成质量选择（1K / 2K / 4K，默认 4K） |
| | 开始生成按钮 |

| 下方全宽面板 |
|---|
| 生成结果区域（3 列网格排列） |

## 4.2 核心设计原则

- ✅ 前端提供提示词输入框，用户自行描述想要生成的内容
- ✅ 支持上传最多 6 张本地参考图（base64 传递给 AI API）
- ✅ 用户可选择生成数量（1-8 张）
- ✅ 生成结果以 3 列网格排列展示

## 4.3 生成流程

1. 用户操作：
   - （可选）上传参考图（最多 6 张）
   - 输入提示词
   - 选择生成数量（1-8 张）
   - 选择比例（3:4 等）
   - 选择分辨率（1K / 2K / 4K）
   - 点击"开始生成"

2. 系统处理：
   - 创建生成任务（Task）
   - 后台线程逐张调用 Gemini API
   - 前端轮询任务状态（每 2 秒）
   - 实时更新图片结果

3. 返回结果：
   - 按用户指定数量生成图片（1-8 张）
   - 结果以 3 列网格排列
   - 每张图片可独立操作

## 4.5 图片操作

每张图片支持：

- 放大预览
- 下载
- 单张重新生成（不影响其他图片）

## 4.6 AI 生图引擎

### 接口对接

- **API 地址**：`https://nanoapi.poloai.top/v1beta/models/gemini-3-pro-image-preview:generateContent`
- **API Key**：从数据库 `api_keys` 表动态读取（管理员在后台配置）
- **超时时间**：120 秒（可配置）

### 请求格式

```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": "<参考图1 base64>"
          }
        },
        {
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": "<参考图2 base64（可选，最多6张）>"
          }
        },
        {
          "text": "<用户输入的提示词>"
        }
      ]
    }
  ],
  "generationConfig": {
    "responseModalities": ["IMAGE"],
    "imageConfig": {
      "aspectRatio": "3:4",
      "imageSize": "4K"
    }
  }
}
```

> 参考图为可选项，最多 6 张。每张参考图作为一个 `inlineData` part 传入。

### 响应格式

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "inlineData": {
              "mimeType": "image/jpeg",
              "data": "<生成图片 base64>"
            }
          }
        ]
      }
    }
  ]
}
```

### 失败处理

- API 调用失败或超时 → 图片状态设为 `failed`，显示兜底错误图片（`error.svg`）
- 不重新生成 SVG 占位图，使用统一的静态错误提示图

---

# 五、历史记录模块

## 5.1 用户侧功能

- 按时间倒序展示历史生成任务
- 每条记录包含：缩略图、风格名称、生成时间、状态
- 分页加载（每页 20 条）

## 5.2 操作能力

- 查看大图
- 下载图片

## 5.3 管理员增强

- 查看所有用户的生成记录
- 数据统计：最近 7 天 / 30 天生成量、总用户数、活跃用户数

---

# 六、后台管理模块（仅管理员）

## 6.1 用户管理

- 用户列表（ID、用户名、角色、状态、创建时间）
- 创建用户
- 禁用 / 启用用户
- 设置管理员权限

## 6.2 数据统计

- 最近 7 / 30 天生成量
- 总用户数 / 活跃用户数
- 最近生成任务列表

## 6.3 API Key 管理

- 全局唯一 API Key（用于调用 Gemini 生图接口）
- 支持查看（带掩码）、编辑、删除
- Key 存储在数据库中，后端动态读取

---

# 七、数据库表结构（SQLite）

## 7.1 用户表（users）

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(10) DEFAULT 'user',        -- 'user' | 'admin'
  status VARCHAR(10) DEFAULT 'active',    -- 'active' | 'disabled'
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## 7.2 风格表（styles）

```sql
CREATE TABLE styles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(100) NOT NULL,
  cover_image VARCHAR(255),
  description VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## 7.3 Prompt 模板表（style_prompts）

```sql
CREATE TABLE style_prompts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  style_id INTEGER NOT NULL,
  prompt TEXT NOT NULL,
  negative_prompt TEXT,
  sort_order INTEGER DEFAULT 0,
  FOREIGN KEY (style_id) REFERENCES styles(id)
);
```

## 7.4 生成任务表（tasks）

```sql
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  prompt TEXT NOT NULL DEFAULT '',         -- 用户输入的提示词
  num_images INTEGER DEFAULT 4,           -- 生成数量（1-8）
  size VARCHAR(20) DEFAULT '3:4',          -- 比例（传给 API 的 aspectRatio）
  resolution VARCHAR(10) DEFAULT '4K',     -- 分辨率（传给 API 的 imageSize）
  reference_images TEXT DEFAULT '',        -- 参考图路径列表（JSON 数组）
  status VARCHAR(20) DEFAULT 'pending',    -- pending | processing | success | failed
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

## 7.5 图片结果表（images）

```sql
CREATE TABLE images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL,
  image_url VARCHAR(255) DEFAULT '',
  status VARCHAR(20) DEFAULT 'pending',   -- pending | success | failed
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (task_id) REFERENCES tasks(id)
);
```

## 7.6 重新生成记录表（regenerate_logs）

```sql
CREATE TABLE regenerate_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  image_id INTEGER NOT NULL,
  old_image_url VARCHAR(255) DEFAULT '',
  new_image_url VARCHAR(255) DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (image_id) REFERENCES images(id)
);
```

## 7.7 API Key 表（api_keys）

```sql
CREATE TABLE api_keys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key VARCHAR(255) NOT NULL DEFAULT '',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## 7.8 数据关系

```
users 1:N tasks
tasks 1:N images
api_keys（全局唯一，只存一条记录）
```

> 注：styles 和 style_prompts 表保留在数据库中供后端兼容，但前端不再使用风格功能。

---

# 八、API 接口文档

## 8.1 认证接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| POST | /api/auth/login | 公开 | 登录，返回 JWT |
| POST | /api/auth/change-password | 用户 | 修改密码 |
| GET | /api/auth/me | 用户 | 获取当前用户信息 |

### 登录

```
POST /api/auth/login
```

请求：
```json
{ "username": "admin", "password": "admin123" }
```

响应：
```json
{
  "token": "eyJhbGciOi...",
  "user": { "id": 1, "username": "admin", "role": "admin" }
}
```

## 8.2 生成任务接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| POST | /api/tasks | 用户 | 创建生成任务 |
| GET | /api/tasks/:id | 用户 | 查询任务结果（含图片列表） |

### 创建任务

```
POST /api/tasks
```

请求：
```json
{
  "prompt": "一只在花园中奔跑的金毛犬",
  "num_images": 4,
  "size": "3:4",
  "resolution": "4K",
  "reference_images": ["/uploads/ref/xxx.jpg", "/uploads/ref/yyy.jpg"]
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| prompt | string | 是 | 用户输入的提示词 |
| num_images | int | 是 | 生成数量（1-8） |
| size | string | 是 | 比例（如 3:4） |
| resolution | string | 是 | 分辨率（1K / 2K / 4K） |
| reference_images | string[] | 否 | 参考图路径列表（最多 6 张） |

响应：
```json
{ "task_id": 1 }
```

## 8.3 图片接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| POST | /api/images/:id/regenerate | 用户 | 单张重新生成 |
| GET | /api/images/:id/download | 用户 | 下载图片 |

## 8.4 文件上传接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| POST | /api/upload | 用户 | 上传参考图（JPG/PNG/WEBP/GIF，≤10MB） |

响应：
```json
{ "url": "/uploads/ref/abc123.jpg" }
```

## 8.5 历史记录接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| GET | /api/history | 用户 | 当前用户历史（分页） |

## 8.6 管理员接口

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | /api/admin/users | 创建用户 |
| GET | /api/admin/users | 用户列表 |
| PUT | /api/admin/users/:id/status | 禁用/启用用户 |
| PUT | /api/admin/users/:id/role | 设置角色 |
| GET | /api/admin/stats | 数据统计 |
| GET | /api/admin/history | 全部生成记录 |
| GET | /api/admin/api-key | 获取 API Key |
| PUT | /api/admin/api-key | 设置 API Key |
| DELETE | /api/admin/api-key | 删除 API Key |

---

# 九、前端页面说明

## 9.1 登录

无单独登录页。主页顶部导航栏右侧：
- 未登录时显示"登录"按钮，点击弹出登录 Dialog（Modal）
- 已登录时显示用户头像和下拉菜单（修改密码、上传头像、退出登录）

## 9.2 主绘图页

上下分区布局：
- 上方左侧：参考图上传区（最多 6 张，3 列网格，逐张上传/删除）
- 上方右侧：绘图设置面板（提示词输入框、生成数量 1-8、尺寸选择、质量选择、生成按钮）
- 下方全宽：生成结果区域（3 列网格排列，支持预览、下载、重新生成）

## 9.3 历史记录页

卡片列表：每条任务显示时间、状态、图片缩略图，支持分页。

## 9.4 管理后台（导航栏下拉菜单）

- **用户管理**：表格展示，支持新增/禁用/设角色
- **数据统计**：7天/30天生成量、用户统计
- **API Key**：全局 Key 管理（查看/编辑/删除）

---

# 十、部署方案

## 10.1 前端 — Vercel

1. GitHub 仓库关联 Vercel
2. Root Directory: `frontend`
3. 环境变量: `VITE_API_BASE_URL` = 后端地址
4. 更新 `vercel.json` 中的 rewrites 代理地址

## 10.2 后端 — Railway（推荐）

1. 创建 Railway 项目，选择 GitHub 仓库
2. Root Directory: `backend`
3. Build: `pip install -r requirements.txt`
4. Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
5. 挂载 Volume：`/app/data`（数据库）+ `/app/uploads`（图片文件）
6. 环境变量：`SECRET_KEY`、`DB_PATH=/app/data/banana.db`、`UPLOAD_DIR=/app/uploads`

## 10.3 后端 — VPS

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env  # 修改 SECRET_KEY
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

配合 Nginx 反向代理 + Let's Encrypt HTTPS。

---

# 十一、配置项

| 配置项 | 默认值 | 说明 |
|---|---|---|
| `SECRET_KEY` | `change-me-in-production` | JWT 签名密钥 |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` | Token 有效期（分钟） |
| `DB_PATH` | `backend/data/banana.db` | SQLite 数据库路径 |
| `UPLOAD_DIR` | `backend/uploads` | 上传文件存储路径 |
| `AI_API_URL` | `https://nanoapi.poloai.top/...` | Gemini 生图接口地址 |
| `AI_TIMEOUT` | `120` | AI 接口超时时间（秒） |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis 地址（可选） |

> API Key 不在配置文件中，由管理员在后台界面配置，存储在数据库中。

---

# 十二、关键设计原则

1. **提示词驱动**：用户直接输入提示词描述想要生成的内容
2. **多参考图支持**：支持上传最多 6 张参考图，以 base64 传递给 AI 接口辅助生成
3. **灵活生成数量**：用户可选择 1-8 张生成数量
4. **无独立登录页**：登录通过主页顶部弹窗完成，未登录可浏览、生成需登录
5. **权限强控制**：禁止开放注册，管理员控制所有账号
6. **API Key 动态化**：Key 存数据库，管理员随时可更换，无需重启服务
7. **失败兜底**：生图失败显示统一错误图片，不生成占位 SVG
8. **三列结果展示**：生成结果以 3 列网格排列，清晰直观
