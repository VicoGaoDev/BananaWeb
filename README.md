# 🍌 Banana Web — AI 绘图系统

基于提示词的 AI 批量出图系统，支持多参考图上传与自定义生成数量，并可将参考图与生成结果统一存储到腾讯云 COS。

## 技术栈

| 模块 | 技术 |
|------|------|
| 前端 | Vue 3 + TypeScript + Ant Design Vue 4 + Pinia |
| 后端 | Python FastAPI + SQLAlchemy + MySQL |
| 异步任务 | Celery + Redis（可选，开发环境自动降级为线程） |
| 图片存储 | 腾讯云 COS（前端临时凭证直传 + 后端结果图上传） |
| 部署 | 前端 Vercel / 后端 VPS |

## 项目结构

```
Banana_Web/
├── frontend/              # Vue 3 前端
│   ├── src/
│   │   ├── api/           # API 请求层
│   │   ├── stores/        # Pinia 状态管理
│   │   ├── views/         # 页面视图（GenerateView / HistoryView / admin）
│   │   ├── components/    # 通用组件（AppLayout 含登录弹窗）
│   │   └── router/        # 路由配置
│   └── vercel.json        # Vercel 部署配置
├── backend/               # FastAPI 后端
│   ├── app/
│   │   ├── api/           # 路由层
│   │   ├── models/        # ORM 模型
│   │   ├── schemas/       # Pydantic 模型
│   │   ├── services/      # 业务逻辑层
│   │   ├── workers/       # Celery 异步任务
│   │   └── utils/         # 工具函数
└── prd.md                 # 产品需求文档
```

## 快速开始

### 1. 启动后端

```bash
cd backend

# 创建虚拟环境
python -m venv venv
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 复制环境变量（按需修改）
cp .env.example .env

# 填写数据库账号信息（默认连开发环境 MySQL 主机）
# DB_HOST=sh-cynosdbmysql-grp-kmfw4ojg.sql.tencentcdb.com
# DB_PORT=20396
# DB_USER=<user>
# DB_PASSWORD=<password>
# DB_NAME=<database>

# 启动服务（首次启动自动建表 + 创建默认管理员）
uvicorn app.main:app --reload --port 8000
```

启动后：
- API 文档：http://localhost:8000/docs
- 超级管理员：`administrator` / `administrator123`（不显示在用户列表，可重置所有用户密码）
- 默认管理员：`admin` / `admin123`
- 如需启用腾讯云 COS，请使用超级管理员进入后台“COS 配置”页填写 `SecretId`、`SecretKey`、`Bucket`、`Region`

### 2. 启动前端

```bash
cd frontend

# 安装依赖
npm install

# 启动开发服务（自动代理 /api 到 localhost:8000）
npm run dev
```

打开 http://localhost:3000 即可使用（无需登录即可浏览，点击顶部"登录"按钮弹窗登录后可生成图片）。

### 3. （可选）启动 Celery Worker

如需真正的异步队列处理，需安装 Redis 并启动 Worker：

```bash
cd backend
celery -A app.workers.celery_app worker --loglevel=info --concurrency=2
```

> 不启动 Redis/Celery 时，系统自动降级为后台线程处理，开发环境完全可用。

## 部署

### 腾讯云 COS 配置

系统已支持将以下图片统一存储到腾讯云 COS：
- 参考图
- 局部重绘原图与蒙版
- 提示词反推上传图
- 联系二维码
- 模版参考图 / 结果图
- AI 生成结果图

配置方式：
1. 启动系统并使用超级管理员登录后台
2. 进入独立的“COS 配置”页
3. 填写：
   - `Bucket`，例如 `vicoimagetencent-1257893314`
   - `Region`，例如 `ap-guangzhou`
   - `SecretId`
   - `SecretKey`
   - `访问域名` 可选，留空时默认使用 COS 公网域名
4. 点击保存后立即生效，无需重启服务

说明：
- 前端上传文件时会先请求后端获取临时凭证，再直传 COS
- 后端 worker 会把生成结果图上传到 COS，并将最终 URL 写入数据库
- 历史遗留的本地 `/uploads/...` 路径仍兼容读取与下载

### 前端 — Vercel

1. 将代码推送到 GitHub
2. 在 [Vercel](https://vercel.com) 导入项目
3. 设置：
   - **Root Directory**: `frontend`
   - **Framework Preset**: Vite
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
4. 添加环境变量：
   - `VITE_API_BASE_URL` = 你的后端地址（如 `https://api.yourdomain.com`）
5. 修改 `frontend/vercel.json` 中的 `rewrites` 规则，将 `your-backend-domain.com` 替换为实际后端地址

### 后端 — VPS / Railway / Render

后端统一通过 `DATABASE_URL` 连接云端 MySQL：

**方案 A：VPS 部署**
```bash
# 在服务器上
git clone <repo>
cd Banana_Web/backend
pip install -r requirements.txt
# 生产环境需修改 .env 中的 SECRET_KEY
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

配合 Nginx 反向代理 + HTTPS。

**方案 B：Railway**
1. 在 Railway 创建项目，选择 GitHub 仓库
2. Root Directory 设为 `backend`
3. Start Command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. 如需兼容旧的本地上传文件，可添加持久化 Volume 挂载到 `/app/uploads`

如果已全面切换到腾讯云 COS，`/app/uploads` 主要只用于兼容旧数据与失败占位图，核心业务图片将写入 COS。

### MySQL 配置

项目运行时优先读取 `DATABASE_URL`；如果未提供，会自动用 `DB_HOST`、`DB_PORT`、`DB_USER`、`DB_PASSWORD`、`DB_NAME` 拼接 MySQL 连接串。建议按环境分开配置：

- 本地开发：在 `backend/.env` 中填写 `DB_*`
- 正式环境：通过部署平台环境变量或 CI 注入 `DATABASE_URL` 或 `DB_*`，不要把生产库连接串提交进仓库

1. 本地开发在 `backend/.env` 中配置 MySQL：

```env
DB_HOST=sh-cynosdbmysql-grp-kmfw4ojg.sql.tencentcdb.com
DB_PORT=20396
DB_USER=user
DB_PASSWORD=password
DB_NAME=database
DB_CHARSET=utf8mb4
DB_AUTO_CREATE_TABLES=true
DB_RUN_SCHEMA_COMPAT=false
DB_RUN_SEED=false
```

2. 正式环境可继续直接注入完整 `DATABASE_URL`，例如内网 MySQL：

```env
DATABASE_URL=mysql+pymysql://user:password@172.17.0.17:3306/database?charset=utf8mb4
DB_RUN_SCHEMA_COMPAT=false
DB_RUN_SEED=false
```

如果使用当前仓库中的 GitHub Actions + CloudBase 工作流，需要在仓库 Secrets 中配置：

- `TENCENT_CLOUD_SECRET_ID`
- `TENCENT_CLOUD_SECRET_KEY`
- `PROD_DATABASE_URL`

工作流会在部署前生成 `backend/.env`，再执行 `cloudbase deploy`。

3. 安装依赖：

```bash
cd backend
pip install -r requirements.txt
```

4. 启动后端前，请确认目标 MySQL 已可访问，并检查登录、历史记录、管理配置和任务查询是否正常。

说明：
- 项目不再提供 SQLite 回退；缺少 `DATABASE_URL` 时，需要提供完整的 `DB_*` MySQL 配置。
- MySQL 生产环境建议禁用运行时补列与种子逻辑，即 `DB_RUN_SCHEMA_COMPAT=false`、`DB_RUN_SEED=false`。

## API 概览

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| POST | /api/auth/login | 公开 | 登录 |
| POST | /api/auth/change-password | 用户 | 修改密码 |
| GET | /api/auth/me | 用户 | 获取当前用户信息 |
| POST | /api/tasks | 用户 | 创建生成任务（prompt + num_images + reference_images） |
| GET | /api/tasks/:id | 用户 | 查询任务结果 |
| POST | /api/images/:id/regenerate | 用户 | 单张重新生成 |
| GET | /api/images/:id/download | 用户 | 下载图片 |
| POST | /api/upload | 用户 | 上传参考图（最多 6 张） |
| POST | /api/upload/credential | 用户 | 获取腾讯云 COS 临时上传凭证 |
| GET | /api/history | 用户 | 历史记录 |
| GET | /api/admin/cos-config | 超级管理员 | 获取 COS 配置 |
| PUT | /api/admin/cos-config | 超级管理员 | 保存 COS 配置 |
| POST | /api/admin/users | 管理员 | 创建用户 |
| GET | /api/admin/users | 管理员 | 用户列表 |
| PUT | /api/admin/users/:id/status | 管理员 | 禁用/启用 |
| PUT | /api/admin/users/:id/role | 管理员 | 设置角色 |
| PUT | /api/admin/users/:id/reset-password | 超级管理员 | 重置用户密码 |
| GET | /api/admin/stats | 管理员 | 数据统计 |
| GET | /api/admin/history | 管理员 | 全部记录 |

完整文档启动后端后访问 http://localhost:8000/docs 查看。
