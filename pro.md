# Banana Web 补充说明

> 基于当前已完成实现整理的增量说明文档
> 更新时间：2026-04-12

---

## 1. 本次补充

当前已额外补充以下能力：

- 外部接口配置与场景绑定拆层
- 创意模版固定单张，不展示生图数量
- 模版详情移除底部关闭按钮
- 普通管理员只能分配积分，用户权限调整仅超级管理员可操作
- 新增系统公告配置与前端全局公告弹窗

---

## 2. 系统公告配置与弹窗

### 2.1 功能目标

后台可配置系统公告内容。

前台在以下时机触发公告检查：

- 用户登录成功后
- 用户注册成功后
- 用户刷新网站后

当公告开启且有内容时，前端弹出系统公告对话框。

### 2.2 后台配置方式

系统公告复用现有单例配置表 `api_keys`，不新增独立设置表。

新增字段：

- `announcement_enabled`
- `announcement_content`
- `announcement_updated_at`

后台配置页支持：

- 开启/关闭公告
- 编辑公告内容
- 保存公告配置

### 2.3 前台弹窗规则

公告弹窗挂在全局壳层，作为全站唯一入口。

弹出条件：

- `announcement_enabled = true`
- `announcement_content` 非空
- 当前用户今天尚未选择“不再弹出”

弹窗内容包括：

- 公告正文
- `今日不再弹出` 复选框
- `知道了` 按钮

### 2.4 今日不再弹出

前端使用 `localStorage` 保存抑制状态，记录：

- 当天日期
- 公告版本

其中公告版本使用：

- `announcement_updated_at`

这样可以保证：

- 同一天内用户勾选后不会重复弹出
- 如果管理员当天修改了公告内容，版本变化后仍会重新弹出

### 2.5 不触发的场景

以下场景不会反复弹出系统公告：

- 前端站内普通路由切换
- 公告关闭但未发生刷新或重新登录/注册

也就是说，“刷新网站”只指整页加载，不包括 SPA 内部导航。

---

## 3. 接口补充

### 3.1 管理端配置接口

沿用：

- `GET /api/admin/api-key`
- `PUT /api/admin/api-key`
- `DELETE /api/admin/api-key`

其中管理端配置对象新增：

- `announcement_enabled`
- `announcement_content`
- `announcement_updated_at`

### 3.2 公告公开接口

新增：

- `GET /api/config/announcement`

返回字段：

- `announcement_enabled`
- `announcement_content`
- `announcement_updated_at`

---

## 4. 前端落点

后台配置页：

- `frontend/src/views/admin/ApiKeyView.vue`

前台全局弹窗与触发逻辑：

- `frontend/src/components/layout/AppLayout.vue`

前端接口与类型：

- `frontend/src/api/admin.ts`
- `frontend/src/api/auth.ts`
- `frontend/src/types/index.ts`

---

## 5. 后端落点

- `backend/app/models/api_key.py`
- `backend/app/schemas/api_key.py`
- `backend/app/api/api_key.py`
- `backend/app/main.py`

---

## 6. 已完成验证

已完成以下验证：

- 后端编译通过：`python3 -m compileall app`
- 前端构建通过：`npm run build`
- 运行态验证通过：
  - 公告可保存
  - 公告公开接口可读取
  - 修改公告后 `announcement_updated_at` 会变化
  - 满足“今日不再弹出”与“公告更新后重新弹出”的版本判断需求

---

## 7. 当前一致性说明

当前 `prd.md` 已同步主需求说明，`pro.md` 作为增量补充文档，重点记录最近几轮实现落地结果，便于后续继续迭代时快速回顾。
