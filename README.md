# Harness Scaffolding Generator

一键生成 **Next.js + FastAPI** 全栈项目脚手架，内置图分析（graph-tool）、图可视化（Cytoscape.js）和 LLM 集成（LangChain）。

## 前置依赖

- [Node.js](https://nodejs.org) 18+ & [pnpm](https://pnpm.io) 8+
- [Python](https://python.org) 3.12+
- [Docker](https://docker.com)（Docker 部署必需，含 nginx 反向代理）
- [graph-tool](https://graph-tool.skewed.de/)（Docker 中通过 miniforge3 + conda 自动安装）

## 快速开始

```bash
# 1. 生成脚手架（可自定义项目名，影响容器名和网络名）
./init.sh my_project

# 2. ⭐ 编辑你的项目设计文档（最重要的一步！）
#    打开 docs/design.md，按模板提示填写你的需求

# 3. 本地开发（前后端分别启动）
make install        # 安装所有依赖
make dev            # 同时启动前后端
# → 后端 http://localhost:8000/docs
# → 前端 http://localhost:3000

# 4. Docker 部署（含 nginx 反向代理）
make docker-up      # 构建并启动所有服务 (backend + frontend + nginx)
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
├── docker-compose.yml      全栈编排 (backend + frontend + nginx)
├── nginx/
│   └── nginx.conf          反向代理配置 (:80 → frontend/backend)
├── docs/
│   ├── design.md               ⭐ 你的项目设计文档（先填这个！）
│   ├── dev_rules.md            AI 编码工具必读的开发规范（lint / test / 提交检查）
│   └── tech_preferences.md     技术选型偏好（AI 必读）
├── backend/                FastAPI + Pydantic + loguru + graph-tool + LangChain
│   ├── Dockerfile          miniforge3 镜像, conda graph-tool, healthcheck
│   ├── app/main.py         入口 & 路由挂载
│   ├── app/core/config.py  配置（自动读取 .env）
│   ├── app/core/logging.py loguru 日志配置（按天轮转，保留 30 天）
│   ├── app/api/routes/     API 端点（health + items + graph + llm）
│   ├── app/schemas/        请求/响应模型
│   ├── app/models/         数据模型
│   ├── app/services/       业务逻辑（graph_analysis + llm_registry）
│   ├── app/prompts/        AI Prompt 模板
│   └── tests/              pytest 测试
└── frontend/               Next.js 14 + TypeScript + Tailwind + shadcn/ui
    ├── Dockerfile          Node 22 多阶段构建 (standalone)
    ├── src/app/            页面（Dashboard、Login、Register、Settings）
    ├── src/components/     组件（Sidebar 布局 + GraphViewer 图可视化）
    └── src/lib/api.ts      封装的 API 客户端
```

## Docker 架构

```
              ┌────────────┐
        ┌────▶│  Frontend   │
┌──────┐│     │  Next.js    │
│Nginx ││     │  :3000      │
│ :80  ││     └────────────┘
└──────┘│     ┌────────────┐
        └────▶│  Backend    │
              │  FastAPI    │
              │  :8000      │
              └────────────┘
```

- **Nginx** 统一入口 (:80)，`/api/` 转发到 Backend，其余转发到 Frontend
- **Frontend** 多阶段构建，生产模式 standalone 输出，非 root 用户运行
- **Backend** miniforge3 + conda graph-tool，loguru 日志，内置 HEALTHCHECK
- 所有服务通过自定义 Docker network 通信，仅 nginx 暴露端口

## 核心特性

### 后端图分析 (graph-tool)

通过 `POST /api/v1/graph/analyze` 提交节点和边，返回 PageRank、Betweenness 等指标。Docker 中通过 miniforge3 镜像 + conda 自动安装 graph-tool。

### LLM 集成 (LangChain)

通过 API 动态注册/管理大模型 Provider，无需写死环境变量：

- `POST /api/v1/llm/providers` — 注册 Provider（name, api_key, api_base, model）
- `GET /api/v1/llm/providers` — 列出已注册 Provider（隐藏 api_key）
- `DELETE /api/v1/llm/providers/{name}` — 删除 Provider
- `POST /api/v1/llm/chat` — 使用指定 Provider 对话

Provider 配置持久化在 `data/llm_providers.json`，Docker volume 保证数据持久。

依赖：langchain, langchain-openai, langchain-community, langgraph, langsmith, openai, tiktoken

### 前端图可视化 (Cytoscape.js)

内置 `<GraphViewer>` 组件，支持 5 种自动布局（fcose / dagre / cola / grid / circle），用户可一键切换排布方式。

### 前端 Markdown 渲染

内置 react-markdown + remark-gfm + rehype-highlight，用于展示 LLM 返回的 Markdown 格式内容。

### 日志 (loguru)

开发模式输出到 stderr，同时写入 `logs/` 目录按天轮转、保留 30 天。

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

工作流：填写 design.md → AI 读上下文 → 拆任务 → 逐个实现 → 跑测试

## 技术偏好

详见 `docs/tech_preferences.md`，核心约定：

| 场景 | 必须使用 |
|------|---------|
| 图表 | ECharts |
| 图/网络可视化 | Cytoscape.js + 布局扩展 |
| 后端图分析 | graph-tool (conda) |
| 大模型框架 | LangChain + LangGraph |
| 日志 | loguru |
| UI 组件 | shadcn/ui |
| 状态管理 | zustand + @tanstack/react-query |
