# 🧾 AI 绘图系统 — 产品需求文档

> 基于风格模板的 AI 批量出图系统（无 Prompt 暴露 + 强后台控制）
> 最后更新：2026-03-20

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
│   │   │   ├── styles.ts     # 风格列表
│   │   │   ├── tasks.ts      # 创建/查询生成任务
│   │   │   ├── images.ts     # 图片下载、重新生成
│   │   │   ├── upload.ts     # 参考图上传
│   │   │   ├── admin.ts      # 管理员接口（用户/统计/API Key）
│   │   │   └── client.ts     # Axios 实例 + JWT 拦截器
│   │   ├── stores/auth.ts    # Pinia 认证状态
│   │   ├── views/            # 页面
│   │   │   ├── LoginView.vue
│   │   │   ├── GenerateView.vue
│   │   │   ├── HistoryView.vue
│   │   │   └── admin/
│   │   │       ├── UserManageView.vue
│   │   │       ├── StyleManageView.vue
│   │   │       ├── DashboardView.vue
│   │   │       └── ApiKeyView.vue
│   │   ├── components/
│   │   │   ├── StyleSelector.vue    # 风格选择抽屉
│   │   │   ├── ImageCard.vue        # 图片结果卡片
│   │   │   └── layout/AppLayout.vue # 顶部导航布局
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

1. **用户认证模块** — 登录 / 修改密码 / JWT 鉴权
2. **绘图主功能模块** — 风格选择 / 参考图上传 / AI 生图
3. **历史记录模块** — 生成结果浏览与管理
4. **后台管理模块** — 用户管理 / 风格管理 / 数据统计 / API Key 管理
5. **AI 生图引擎** — 对接 Gemini API，base64 图片交互

---

# 三、用户认证模块

## 3.1 功能说明

- 用户通过「用户名 + 密码」登录系统，获取 JWT Token
- Token 有效期 24 小时（可配置）
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

左右分栏布局：

| 左侧面板（280px） | 右侧面板 |
|---|---|
| 参考图上传区（点击上传本地图片） | 2×2 图片结果网格 |
| 分辨率选择（1K / 2K / 4K，默认 4K） | 空态提示 / 生成结果 |
| 比例选择（1:1 / 2:3 / 3:2 / 3:4 / 4:3 / 9:16 / 16:9） | |
| 风格图选项按钮（点击弹出风格选择抽屉） | |
| 开始生成按钮 | |

## 4.2 核心设计原则

- ❌ 前端不提供 Prompt 输入
- ❌ 前端不可见任何 Prompt
- ✅ Prompt 由后端维护，通过风格关联
- ✅ 支持上传本地参考图（base64 传递给 AI API）

## 4.3 风格生成逻辑

- 每个"风格"对应后端**多条 Prompt**
- 用户选择风格 → 后端批量调用 AI API 生成图片
- 前端只展示结果

## 4.4 生成流程

1. 用户操作：
   - （可选）上传参考图
   - 选择分辨率（1K / 2K / 4K）
   - 选择比例（3:4 等）
   - 点击"风格图选项"选择风格
   - 点击"开始生成"

2. 系统处理：
   - 创建生成任务（Task）
   - 后台线程逐张调用 Gemini API
   - 前端轮询任务状态（每 2 秒）
   - 实时更新图片结果

3. 返回结果：
   - 多张生成图片（风格对应的 Prompt 数量）
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
            "data": "<参考图 base64>"
          }
        },
        {
          "text": "<后端 Prompt>"
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

## 6.2 风格管理

- 风格列表（CRUD）
- 每个风格管理多条 Prompt（含负面 Prompt、排序）

## 6.3 数据统计

- 最近 7 / 30 天生成量
- 总用户数 / 活跃用户数
- 最近生成任务列表

## 6.4 API Key 管理

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
  style_id INTEGER NOT NULL,
  model VARCHAR(50) DEFAULT 'banana-pro',
  size VARCHAR(20) DEFAULT '3:4',          -- 比例（传给 API 的 aspectRatio）
  resolution VARCHAR(10) DEFAULT '4K',     -- 分辨率（传给 API 的 imageSize）
  reference_image VARCHAR(500) DEFAULT '', -- 参考图路径
  status VARCHAR(20) DEFAULT 'pending',    -- pending | processing | success | failed
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (style_id) REFERENCES styles(id)
);
```

## 7.5 图片结果表（images）

```sql
CREATE TABLE images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL,
  prompt_id INTEGER,
  image_url VARCHAR(255) DEFAULT '',
  status VARCHAR(20) DEFAULT 'pending',   -- pending | success | failed
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (task_id) REFERENCES tasks(id),
  FOREIGN KEY (prompt_id) REFERENCES style_prompts(id)
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
styles 1:N style_prompts
tasks 1:N images
images N:1 style_prompts
api_keys（全局唯一，只存一条记录）
```

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

## 8.2 风格接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| GET | /api/styles | 用户 | 获取风格列表（含关联 Prompt） |

## 8.3 生成任务接口

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
  "style_id": 1,
  "model": "banana-pro",
  "size": "3:4",
  "resolution": "4K",
  "reference_image": "/uploads/ref/xxx.jpg"
}
```

响应：
```json
{ "task_id": 1 }
```

## 8.4 图片接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| POST | /api/images/:id/regenerate | 用户 | 单张重新生成 |
| GET | /api/images/:id/download | 用户 | 下载图片 |

## 8.5 文件上传接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| POST | /api/upload | 用户 | 上传参考图（JPG/PNG/WEBP/GIF，≤10MB） |

响应：
```json
{ "url": "/uploads/ref/abc123.jpg" }
```

## 8.6 历史记录接口

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| GET | /api/history | 用户 | 当前用户历史（分页） |

## 8.7 管理员接口

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

## 9.1 登录页

双栏布局：左侧蓝色品牌区 + 右侧登录表单。

## 9.2 主绘图页

左右分栏：
- 左侧：参考图上传卡片（点击上传）、分辨率/比例选择、风格选择按钮、生成按钮
- 右侧：2×2 图片网格（支持预览、下载、重新生成）

## 9.3 历史记录页

卡片列表：每条任务显示风格名、时间、状态、图片缩略图，支持分页。

## 9.4 管理后台（导航栏下拉菜单）

- **用户管理**：表格展示，支持新增/禁用/设角色
- **风格管理**：CRUD 风格及其 Prompt
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

1. **Prompt 隐藏**：Prompt 完全在后端维护，前端不可见、不可编辑
2. **风格驱动生成**：用户选"风格"而非写描述，风格 → 多 Prompt → 多图结果
3. **权限强控制**：禁止开放注册，管理员控制所有账号
4. **API Key 动态化**：Key 存数据库，管理员随时可更换，无需重启服务
5. **失败兜底**：生图失败显示统一错误图片，不生成占位 SVG
6. **参考图支持**：用户上传参考图，以 base64 传递给 AI 接口辅助生成
