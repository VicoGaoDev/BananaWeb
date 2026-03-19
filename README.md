# 🍌 Banana Web — AI 绘图系统

基于风格模板的 AI 批量出图系统，无 Prompt 暴露，强后台控制。

## 技术栈

| 模块 | 技术 |
|------|------|
| 前端 | Vue 3 + TypeScript + Ant Design Vue 4 + Pinia |
| 后端 | Python FastAPI + SQLAlchemy + SQLite |
| 异步任务 | Celery + Redis（可选，开发环境自动降级为线程） |
| 部署 | 前端 Vercel / 后端 VPS |

## 项目结构

```
Banana_Web/
├── frontend/          # Vue 3 前端
│   ├── src/
│   │   ├── api/       # API 请求层
│   │   ├── stores/    # Pinia 状态管理
│   │   ├── views/     # 页面视图
│   │   ├── components/# 通用组件
│   │   └── router/    # 路由配置
│   └── vercel.json    # Vercel 部署配置
├── backend/           # FastAPI 后端
│   ├── app/
│   │   ├── api/       # 路由层
│   │   ├── models/    # ORM 模型
│   │   ├── schemas/   # Pydantic 模型
│   │   ├── services/  # 业务逻辑层
│   │   ├── workers/   # Celery 异步任务
│   │   └── utils/     # 工具函数
│   └── data/          # SQLite 数据库（自动创建）
└── prd.md             # 产品需求文档
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

# 启动服务（首次启动自动建表 + 创建默认管理员）
uvicorn app.main:app --reload --port 8000
```

启动后：
- API 文档：http://localhost:8000/docs
- 默认管理员：`admin` / `admin123`

### 2. 启动前端

```bash
cd frontend

# 安装依赖
npm install

# 启动开发服务（自动代理 /api 到 localhost:8000）
npm run dev
```

打开 http://localhost:3000 即可使用。

### 3. （可选）启动 Celery Worker

如需真正的异步队列处理，需安装 Redis 并启动 Worker：

```bash
cd backend
celery -A app.workers.celery_app worker --loglevel=info --concurrency=2
```

> 不启动 Redis/Celery 时，系统自动降级为后台线程处理，开发环境完全可用。

## 部署

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

后端使用 SQLite，需要持久化文件系统，推荐：

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
4. 添加持久化 Volume 挂载到 `/app/data` 和 `/app/uploads`

## API 概览

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| POST | /api/auth/login | 公开 | 登录 |
| POST | /api/auth/change-password | 用户 | 修改密码 |
| GET | /api/auth/me | 用户 | 获取当前用户信息 |
| GET | /api/styles | 用户 | 风格列表 |
| POST | /api/tasks | 用户 | 创建生成任务 |
| GET | /api/tasks/:id | 用户 | 查询任务结果 |
| POST | /api/images/:id/regenerate | 用户 | 单张重新生成 |
| GET | /api/images/:id/download | 用户 | 下载图片 |
| GET | /api/history | 用户 | 历史记录 |
| POST | /api/admin/users | 管理员 | 创建用户 |
| GET | /api/admin/users | 管理员 | 用户列表 |
| PUT | /api/admin/users/:id/status | 管理员 | 禁用/启用 |
| PUT | /api/admin/users/:id/role | 管理员 | 设置角色 |
| GET | /api/admin/stats | 管理员 | 数据统计 |
| GET | /api/admin/history | 管理员 | 全部记录 |

完整文档启动后端后访问 http://localhost:8000/docs 查看。
