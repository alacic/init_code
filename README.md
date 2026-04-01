# Harness Scaffolding Generator

一键生成 **Next.js + FastAPI + PostgreSQL** 全栈项目脚手架。

## 前置依赖

- [Node.js](https://nodejs.org) 18+ & [pnpm](https://pnpm.io) 8+
- [Python](https://python.org) 3.11+
- [Docker](https://docker.com)（可选）

## 快速开始

```bash
# 1. 生成脚手架
./init.sh

# 2. ⭐ 编辑你的项目设计文档（最重要的一步！）
#    打开 docs/design.md，按模板提示填写你的需求
#    参考 docs/example_app_design.md 了解怎么写

# 3. 启动后端
cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload
# → http://localhost:8000/docs

# 4. 启动前端（新终端）
cd frontend && pnpm dev
# → http://localhost:3000

# 或者 Docker 一键启动
docker compose up --build
```

清除所有生成文件：`./clean.sh`

## 生成内容

```
├── AGENTS.md               AI 开发指导 & 技术约定 & Agent 使用策略
├── Makefile                make help 查看所有命令
├── feature_list.json       功能清单
├── progress.md             进度看板
├── docker-compose.yml      全栈编排 (Postgres + Backend + Frontend)
├── docs/
│   ├── design.md               ⭐ 你的项目设计文档（先填这个！）
│   ├── example_app_design.md   示例：完整的应用设计（参考用）
│   └── tech_preferences.md     技术选型偏好（AI 必读）
├── backend/                FastAPI + SQLAlchemy + Pydantic
│   ├── app/main.py         入口 & 路由挂载
│   ├── app/core/config.py  配置（自动读取 .env）
│   ├── app/api/routes/     API 端点（含 health + items CRUD 示例）
│   ├── app/schemas/        请求/响应模型
│   ├── app/models/         数据库模型
│   ├── app/services/       业务逻辑
│   ├── app/prompts/        AI Prompt 模板
│   └── tests/              pytest 测试
└── frontend/               Next.js 14 + TypeScript + Tailwind + shadcn/ui
    ├── src/app/            页面（Dashboard、Login、Register、Settings）
    ├── src/components/     组件（含 Sidebar 布局）
    └── src/lib/api.ts      封装的 API 客户端
```

## 用 AI 工具开发

生成脚手架后，让 AI 工具先读取上下文再开始编码：

**Cursor** — Agent 模式 (`Cmd+L`)：
```
请阅读 @AGENTS.md 和 @docs/design.md，按开发计划帮我实现第一个功能。
```

**Claude Code**：
```
读取 AGENTS.md 和 docs/design.md，按 Phase 1 计划开始开发。
```

**Codex**：
```
Read AGENTS.md and docs/design.md. Implement Phase 1 tasks.
```

工作流：填写 design.md → AI 读上下文 → 拆任务 → 逐个实现 → 跑测试 → 更新 progress.md

## 技术偏好

详见 `docs/tech_preferences.md`，核心约定：

| 场景 | 必须使用 |
|------|---------|
| 图表 | ECharts |
| 图/网络可视化 | Cytoscape.js |
| UI 组件 | shadcn/ui |
| 状态管理 | zustand + @tanstack/react-query |
