# Harness Scaffolding Generator

一键生成 **Next.js + FastAPI + PostgreSQL** 全栈项目脚手架。

## 前置依赖

- [Node.js](https://nodejs.org) 18+ & [pnpm](https://pnpm.io) 8+
- [Python](https://python.org) 3.12+
- [Docker](https://docker.com)（Docker 部署必需，含 nginx 反向代理）

## 快速开始

```bash
# 1. 生成脚手架（可自定义项目名，影响容器名和网络名）
./init.sh my_project

# 2. ⭐ 编辑你的项目设计文档（最重要的一步！）
#    打开 docs/design.md，按模板提示填写你的需求
#    参考 docs/example_app_design.md 了解怎么写

# 3. 本地开发（前后端分别启动）
make install        # 安装所有依赖
make dev            # 同时启动前后端
# → 后端 http://localhost:8000/docs
# → 前端 http://localhost:3000

# 4. Docker 部署（含 nginx 反向代理）
make docker-up      # 构建并启动所有服务 (db + backend + frontend + nginx)
# → http://localhost (通过 nginx :80 统一访问)
make docker-logs    # 查看容器日志
make docker-ps      # 查看容器状态和健康检查
make docker-down    # 停止所有服务
```

清除所有生成文件：`./clean.sh`

## 生成内容

```
├── AGENTS.md               AI 开发指导 & 技术约定 & Agent 使用策略
├── Makefile                make help 查看所有命令
├── feature_list.json       功能清单
├── progress.md             进度看板
├── docker-compose.yml      全栈编排 (db + backend + frontend + nginx)
├── nginx/
│   └── nginx.conf          反向代理配置 (:80 → frontend/backend)
├── docs/
│   ├── design.md               ⭐ 你的项目设计文档（先填这个！）
│   ├── example_app_design.md   示例：完整的应用设计（参考用）
│   └── tech_preferences.md     技术选型偏好（AI 必读）
├── backend/                FastAPI + SQLAlchemy + Pydantic
│   ├── Dockerfile          Python 3.12, healthcheck
│   ├── app/main.py         入口 & 路由挂载
│   ├── app/core/config.py  配置（自动读取 .env）
│   ├── app/api/routes/     API 端点（含 health + items CRUD 示例）
│   ├── app/schemas/        请求/响应模型
│   ├── app/models/         数据库模型
│   ├── app/services/       业务逻辑
│   ├── app/prompts/        AI Prompt 模板
│   └── tests/              pytest 测试
└── frontend/               Next.js 14 + TypeScript + Tailwind + shadcn/ui
    ├── Dockerfile          Node 22 多阶段构建 (standalone)
    ├── src/app/            页面（Dashboard、Login、Register、Settings）
    ├── src/components/     组件（含 Sidebar 布局）
    └── src/lib/api.ts      封装的 API 客户端
```

## Docker 架构

```
                    ┌────────────┐     ┌────────────┐
              ┌────▶│  Frontend   │     │  Database   │
┌──────────┐  │     │  Next.js    │     │  PostgreSQL │
│  Nginx    │──┤     │  :3000      │     │  :5432      │
│  :80      │  │     └────────────┘     └─────▲──────┘
└──────────┘  │     ┌────────────┐           │
              └────▶│  Backend    │───────────┘
                    │  FastAPI    │
                    │  :8000      │
                    └────────────┘
```

- **Nginx** 统一入口 (:80)，`/api/` 转发到 Backend，其余转发到 Frontend
- **Frontend** 多阶段构建，生产模式 standalone 输出，非 root 用户运行
- **Backend** Python 3.12，内置 HEALTHCHECK，腾讯镜像源加速
- 所有服务通过自定义 Docker network 通信，仅 nginx 暴露端口
- `container_name` 和 `network` 名称自动使用项目名前缀

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
