# 🧾 AI 绘图系统需求说明（整理版）

---

# 一、系统整体模块划分

系统分为 4 大核心模块：

1. 用户认证模块（登录体系）
2. 绘图主功能模块（核心业务）
3. 历史记录模块
4. 后台管理模块（管理员专用）

---

# 二、用户认证模块（登录系统）

## 2.1 功能说明

* 用户通过「用户名 + 密码」登录系统
* 支持用户修改密码

---

## 2.2 权限规则（⚠️重点修改）

* ❌ 普通用户 **不可注册**
* ✅ 仅管理员可以创建账号
* ✅ 管理员可禁用账号（账号封禁）

---

## 2.3 功能列表

### 普通用户

* 登录
* 修改密码

### 管理员

* 创建用户账号
* 禁用 / 启用账号
* 设置管理员权限

---

# 三、绘图主功能模块（核心）

## 3.1 页面结构

用户登录后默认进入该页面，包含：

### 输入区域

* 风格选择（前端展示）
* 参数选择：

  * AI 模型（默认 Banana Pro）
  * 图片尺寸（2K / 4K / 横竖比例）

⚠️ **重要修改：**

* ❌ 前端不提供提示词输入
* ❌ 前端不可见任何 Prompt
* ✅ Prompt 由后端维护

---

## 3.2 风格生成逻辑（核心改动）

* 每个“风格图”对应后端**多条 Prompt**
* 用户选择风格 → 后端批量生成图片
* 前端只展示结果

---

## 3.3 生成流程

1. 用户选择：

   * 风格
   * 参数（尺寸 / 模型）

2. 点击「开始生成」

3. 系统状态：

   * 显示 loading（30–90 秒）

4. 返回结果：

   * 多张生成图片（风格对应）

---

## 3.4 图片操作

每张图片支持：

* 放大查看
* 下载
* 单张重新生成（✅重点）

---

## 3.5 重新生成规则

* 支持针对某一张图片重新生成
* 不影响其他图片
* 使用同一风格配置

---

# 四、历史记录模块

## 4.1 用户侧功能

* 按时间倒序展示历史图片
* 每条记录包含：

  * 缩略图
  * 风格（或简要描述）
  * 生成时间
  * 状态（成功 / 失败）

---

## 4.2 操作能力

* 查看大图
* 下载图片

---

## 4.3 后续扩展（预留）

* 搜索功能（关键词）

---

## 4.4 管理员增强能力

管理员可查看：

* 所有用户的生成记录
* 数据统计：

  * 最近 7 天生成量
  * 最近 30 天生成量

---

# 五、后台管理模块（仅管理员）

## 5.1 用户管理

功能包括：

* 用户列表查看
* 创建用户
* 禁用 / 启用用户
* 设置管理员权限

---

## 5.2 数据监控

* 全站生成数据统计
* 用户使用情况分析

---

# 六、系统使用流程（完整链路）

1. 打开系统 → 进入登录页
2. 输入账号密码登录
3. 登录成功 → 进入绘图页面
4. 选择：

   * 风格
   * 参数
5. 点击生成
6. 等待生成结果
7. 操作图片：

   * 下载
   * 单张重新生成
8. 查看历史记录
9. （管理员）进入后台管理

---

# ⚠️ 七、关键设计原则（非常重要）

## 1️⃣ Prompt 隐藏机制

* Prompt 完全在后端
* 前端不可见、不可编辑

---

## 2️⃣ 风格驱动生成

* 用户选“风格”，而不是写描述
* 风格 → 多 Prompt → 多图结果

---

## 3️⃣ 权限强控制

* 禁止开放注册
* 管理员控制所有账号

---

# ✅ 总结一句话版本

👉 这是一个
**“基于风格模板的 AI 批量出图系统（无 Prompt 暴露 + 强后台控制）”**

---

# 🗄️ 八、数据库表结构设计（MySQL 示例）

## 8.1 用户表（users）

```sql
CREATE TABLE users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('user','admin') DEFAULT 'user',
  status ENUM('active','disabled') DEFAULT 'active',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

---

## 8.2 风格表（styles）

```sql
CREATE TABLE styles (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  cover_image VARCHAR(255),
  description VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 8.3 Prompt 模板表（style_prompts）

```sql
CREATE TABLE style_prompts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  style_id BIGINT NOT NULL,
  prompt TEXT NOT NULL,
  negative_prompt TEXT,
  sort_order INT DEFAULT 0,
  FOREIGN KEY (style_id) REFERENCES styles(id)
);
```

说明：

* 一个 style 对应多条 prompt
* 用于批量生成图片

---

## 8.4 生成任务表（tasks）

```sql
CREATE TABLE tasks (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  style_id BIGINT NOT NULL,
  model VARCHAR(50) DEFAULT 'banana-pro',
  size VARCHAR(20),
  status ENUM('pending','processing','success','failed') DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (style_id) REFERENCES styles(id)
);
```

---

## 8.5 图片结果表（images）

```sql
CREATE TABLE images (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  task_id BIGINT NOT NULL,
  prompt_id BIGINT,
  image_url VARCHAR(255) NOT NULL,
  status ENUM('success','failed') DEFAULT 'success',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (task_id) REFERENCES tasks(id),
  FOREIGN KEY (prompt_id) REFERENCES style_prompts(id)
);
```

说明：

* 一次任务（task）对应多张图片
* 每张图片对应一个 prompt

---

## 8.6 重新生成记录表（regenerate_logs）

```sql
CREATE TABLE regenerate_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  image_id BIGINT NOT NULL,
  new_image_id BIGINT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (image_id) REFERENCES images(id)
);
```

说明：

* 记录单张图片重新生成历史

---

## 8.7 管理员统计视图（可选）

```sql
-- 最近7天生成数量
SELECT COUNT(*) FROM tasks
WHERE created_at >= NOW() - INTERVAL 7 DAY;

-- 最近30天生成数量
SELECT COUNT(*) FROM tasks
WHERE created_at >= NOW() - INTERVAL 30 DAY;
```

---

# 📌 数据关系总结

* users 1:N tasks
* styles 1:N style_prompts
* tasks 1:N images
* images 1:1 style_prompts（逻辑对应）

---

# ✅ 设计核心思路

* 用 style 控制前端展示
* 用 prompt 控制生成逻辑（后端隐藏）
* 用 task 作为一次请求单位
* 用 image 存储最终结果

---

# 🔌 九、接口文档（API 设计）

## 9.1 用户认证

### 登录

POST /api/auth/login

请求：

```json
{
  "username": "string",
  "password": "string"
}
```

返回：

```json
{
  "token": "jwt_token",
  "user": {
    "id": 1,
    "username": "xxx",
    "role": "user"
  }
}
```

---

### 修改密码

POST /api/auth/change-password

---

## 9.2 风格相关

### 获取风格列表

GET /api/styles

返回：

```json
[
  {
    "id": 1,
    "name": "赛博朋克",
    "cover_image": "xxx"
  }
]
```

---

## 9.3 生成任务

### 创建生成任务

POST /api/tasks

请求：

```json
{
  "style_id": 1,
  "model": "banana-pro",
  "size": "1024x1024"
}
```

返回：

```json
{
  "task_id": 1001
}
```

---

### 查询任务结果

GET /api/tasks/{task_id}

返回：

```json
{
  "status": "success",
  "images": [
    {
      "id": 1,
      "url": "xxx"
    }
  ]
}
```

---

### 单张重新生成

POST /api/images/{image_id}/regenerate

---

## 9.4 历史记录

### 获取历史列表

GET /api/history

参数：

* page
* page_size

---

## 9.5 管理员接口

### 创建用户

POST /api/admin/users

### 禁用用户

POST /api/admin/users/{id}/disable

### 获取统计数据

GET /api/admin/stats

返回：

```json
{
  "last_7_days": 100,
  "last_30_days": 500
}
```

---

# 🎨 十、前端页面原型（低保真）

## 10.1 登录页

```
+----------------------+
|      登录系统         |
|----------------------|
| 用户名 [__________]   |
| 密码   [__________]   |
|                      |
|   [ 登录按钮 ]        |
+----------------------+
```

---

## 10.2 主绘图页面

```
+------------------------------------------------+
| 导航栏 | 画图 | 历史 |（管理员）用户管理         |
|------------------------------------------------|
| 风格选择： [风格1] [风格2] [风格3]              |
|                                                |
| 参数：                                         |
| 模型: [banana-pro]                             |
| 尺寸: [1024x1024 ▼]                            |
|                                                |
|        [ 🎨 开始生成 ]                          |
|                                                |
| 生成结果：                                     |
| [图1] [图2] [图3]                              |
|  ↓点击放大                                     |
| [下载] [重新生成]                              |
+------------------------------------------------+
```

---

## 10.3 历史记录页

```
+----------------------------------------------+
| 历史记录                                     |
|----------------------------------------------|
| [图] 时间：2026-03-19 状态：成功              |
| [图] 时间：2026-03-18 状态：成功              |
| [图] 时间：2026-03-17 状态：失败              |
+----------------------------------------------+
```

---

## 10.4 用户管理页（管理员）

```
+----------------------------------------------+
| 用户管理                                     |
|----------------------------------------------|
| 用户名   状态     操作                        |
| user1    正常     [禁用]                      |
| user2    禁用     [启用]                      |
|                                              |
| [新增用户]                                   |
+----------------------------------------------+
```

---

# ✅ 前端结构建议

* 框架：Vue / React
* 状态管理：Pinia / Redux
* 请求：Axios
* UI：Element Plus / Ant Design

---

# 🚀 下一步建议

1. 先做登录 + 鉴权
2. 再打通生成任务链路（最核心）
3. 最后补后台管理
