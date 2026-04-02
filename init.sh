#!/bin/bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-harness_project}"

# ─── Colors & Helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[  OK]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $1"; exit 1; }
step()    { echo -e "\n${BOLD}━━━ $1 ━━━${NC}"; }

# ─── Pre-flight Checks ───────────────────────────────────────────────────────
step "Pre-flight Checks"

command -v node  >/dev/null 2>&1 || fail "node is not installed"
command -v pnpm  >/dev/null 2>&1 || fail "pnpm is not installed (npm i -g pnpm)"
command -v python3 >/dev/null 2>&1 || fail "python3 is not installed"

info "node   $(node -v)"
info "pnpm   $(pnpm -v)"
info "python $(python3 --version | awk '{print $2}')"

if [ -d "frontend" ] || [ -d "backend" ]; then
  warn "frontend/ or backend/ already exists — run clean.sh first"
  read -rp "Continue anyway? (y/N): " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

success "All checks passed"

# ─── Harness Meta Files ──────────────────────────────────────────────────────
step "Harness Meta Files"

cat > AGENTS.md << 'AGENTS_EOF'
# AGENTS.md — AI Agent Guidance

## Project Overview
- **Name**: __PROJECT_NAME__
- **Stack**: Next.js (frontend) + FastAPI (backend) + PostgreSQL
- **Monorepo**: `frontend/` and `backend/` at repo root

## Architecture
```
nginx/      → Nginx reverse proxy (port 80 → frontend/backend)
frontend/   → Next.js 14+ App Router, TypeScript, Tailwind, shadcn/ui
backend/    → FastAPI, SQLAlchemy, Pydantic v2, Alembic migrations
docs/       → Design docs, ADRs, API specs
```

## Conventions
- Backend: snake_case for files/functions, PascalCase for classes/models
- Frontend: kebab-case for files, PascalCase for components
- API routes: RESTful, versioned under `/api/v1/`
- All new features need tests before merge

## Tech Preferences (IMPORTANT)
**Before adding ANY dependency, read `docs/tech_preferences.md`**

Key constraints:
- Charts → **ECharts** (not Recharts, Chart.js, Nivo)
- Graph/Network visualization → **Cytoscape.js** (not D3-force, vis.js, react-flow)
- UI components → **shadcn/ui** only (not Ant Design, MUI, Chakra)
- State management → **zustand** (client) + **@tanstack/react-query** (server)
- Always prefer mature, well-maintained libraries (see full list in docs/tech_preferences.md)

## Key Commands
| Task             | Command                              |
|------------------|--------------------------------------|
| Backend dev      | `cd backend && uvicorn app.main:app --reload` |
| Frontend dev     | `cd frontend && pnpm dev`            |
| Run all (Docker) | `docker compose up --build`          |
| Access (Docker)  | `http://localhost` (nginx :80)       |
| Backend tests    | `cd backend && pytest`               |
| Frontend tests   | `cd frontend && pnpm test`           |
| Lint all         | `make lint`                          |
| Format all       | `make format`                        |

## Agent 使用策略（重要）

### 何时用主 Agent（直接对话）

适合需要 **全局上下文** 的任务：

- 需求分析、架构设计讨论
- 跨前后端的功能实现（需要同时改 backend + frontend）
- Code review、Bug 分析
- 修改 design.md、AGENTS.md 等项目级文件
- 涉及 ≤ 3 个文件的小改动

### 何时用 Subagent（子任务委派）

适合 **独立、边界清晰** 的任务，避免撑大主 Agent 的上下文：

| 场景 | 为什么用 Subagent |
|------|-------------------|
| 单独实现一个后端 API endpoint | 只需 backend 上下文，不需要前端 |
| 单独实现一个前端页面 | 只需 frontend 上下文，不需要后端 |
| 写测试用例 | 只需被测代码的上下文 |
| 修复 lint/build 错误 | 范围小，独立完成 |
| 数据库 migration 文件生成 | 只需 models 上下文 |
| 文档更新（README、注释） | 不影响代码逻辑 |
| 并行开发多个独立功能 | 各 subagent 互不干扰 |

### 上下文管理原则

1. **单一职责**: 每个 Agent/Subagent 只处理一个功能域
2. **上下文预加载**: 告诉 Agent 先读哪些文件，不要让它自己猜
   - 后端任务: "先读 AGENTS.md、docs/design.md 的第 X 节、backend/app/main.py"
   - 前端任务: "先读 AGENTS.md、docs/tech_preferences.md、frontend/src/lib/api.ts"
3. **及时收尾**: 完成一个功能后，让 Agent 更新 progress.md，然后开新会话
4. **避免超长会话**: 如果一个会话超过 20 轮对话，考虑总结当前进展后开新会话
5. **Subagent 结果校验**: 主 Agent 应检查 Subagent 的产出（运行 lint + test）

### Prompt 模板

**主 Agent — 分析需求**:
```
读取 AGENTS.md 和 docs/design.md，帮我分析 F-001 功能的实现方案。
不要写代码，只输出任务拆解和技术方案。
```

**Subagent — 后端实现**:
```
读取 AGENTS.md 和 docs/design.md 第 4-5 节。
在 backend/ 中实现 /api/v1/users 的 CRUD。
遵循 docs/tech_preferences.md 的后端选型。
完成后运行 pytest 确认通过。
```

**Subagent — 前端实现**:
```
读取 AGENTS.md 和 docs/tech_preferences.md。
在 frontend/src/app/users/ 中实现用户列表页面。
使用 shadcn/ui 组件，调用 lib/api.ts 获取数据。
```

**主 Agent — 验收集成**:
```
运行 make lint && make test，检查所有代码是否通过。
更新 progress.md 标记已完成的任务。
```
AGENTS_EOF
sed -i '' "s/__PROJECT_NAME__/${PROJECT_NAME}/g" AGENTS.md
success "AGENTS.md"

cat > feature_list.json << 'FEATURES_EOF'
{
  "project": "harness_project",
  "version": "0.1.0",
  "features": [
    {
      "id": "F-001",
      "name": "User Authentication",
      "status": "planned",
      "priority": "high",
      "description": "JWT-based auth with login/register/logout",
      "frontend_pages": ["/login", "/register"],
      "backend_endpoints": ["/api/v1/auth/login", "/api/v1/auth/register"]
    },
    {
      "id": "F-002",
      "name": "Dashboard",
      "status": "planned",
      "priority": "high",
      "description": "Main dashboard with overview metrics",
      "frontend_pages": ["/dashboard"],
      "backend_endpoints": ["/api/v1/dashboard/stats"]
    }
  ]
}
FEATURES_EOF
success "feature_list.json"

cat > progress.md << 'PROGRESS_EOF'
# Project Progress

## Sprint 1 — Foundation
- [ ] Project scaffolding (init.sh)
- [ ] Backend: FastAPI boilerplate + health check
- [ ] Frontend: Next.js + shadcn/ui setup
- [ ] Docker Compose: full-stack local dev
- [ ] CI/CD: GitHub Actions pipeline

## Sprint 2 — Core Features
- [ ] F-001: User Authentication
- [ ] F-002: Dashboard
- [ ] Database migrations (Alembic)
- [ ] API documentation (auto-generated)

## Changelog
| Date | Change | Author |
|------|--------|--------|
| —    | Initial scaffolding | init.sh |
PROGRESS_EOF
success "progress.md"

# ─── Docs ─────────────────────────────────────────────────────────────────────
step "Documentation"

mkdir -p docs

# design.md — 用户需要填写的项目设计模板
cat > docs/design.md << 'DESIGN_EOF'
# 项目设计文档

<!-- ============================================================
  这是你的项目设计文档模板。请按提示填写每个章节。
  填完后，让 AI 工具读取本文件即可开始开发：
    Cursor:     "请阅读 @docs/design.md 并按计划开始实现"
    Claude Code: "读取 docs/design.md，按开发计划开始工作"
  参考示例：docs/example_app_design.md
============================================================ -->

## 1. 项目名称 & 简介

**名称**: <!-- 填写你的项目名称 -->

**一句话描述**: <!-- 这个项目是什么？解决什么问题？ -->

**目标用户**: <!-- 谁会用这个产品？ -->

## 2. 核心功能

<!-- 列出 3-5 个核心功能，每个功能用一行描述 -->

| ID | 功能名称 | 描述 | 优先级 |
|----|---------|------|--------|
| F-001 | <!-- 功能名 --> | <!-- 简要描述 --> | P0 |
| F-002 | <!-- 功能名 --> | <!-- 简要描述 --> | P0 |
| F-003 | <!-- 功能名 --> | <!-- 简要描述 --> | P1 |

## 3. 页面规划

<!-- 列出前端需要的页面和路由 -->

```
/                → <!-- 首页/Dashboard 做什么？ -->
/login           → 登录
/register        → 注册
/???             → <!-- 你的核心页面 -->
/settings        → 设置
```

## 4. 数据模型

<!-- 描述核心实体和字段，AI 工具会据此生成 SQLAlchemy models -->

```
实体名:
  - id: UUID (PK)
  - 字段名: 类型
  - 字段名: 类型
  - created_at: datetime
  - updated_at: datetime
```

## 5. API 设计

<!-- 列出后端需要的 API 端点 -->

```
GET    /api/v1/???        → 描述
POST   /api/v1/???        → 描述
PUT    /api/v1/???/:id    → 描述
DELETE /api/v1/???/:id    → 描述
```

## 6. 架构图

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

<!-- 如果有额外服务（Redis、消息队列、外部 API），在这里补充 -->

## 7. 开发计划

### Phase 1 — MVP
- [ ] <!-- 任务 1 -->
- [ ] <!-- 任务 2 -->
- [ ] <!-- 任务 3 -->

### Phase 2 — 完善
- [ ] <!-- 任务 4 -->
- [ ] <!-- 任务 5 -->

## 8. 备注 & 开放问题

- [ ] <!-- 还没确定的事项 -->
- [ ] <!-- 需要调研的技术点 -->
DESIGN_EOF
success "docs/design.md"

# example_app_design.md — 完整示例
cat > docs/example_app_design.md << 'EXAMPLE_EOF'
# Example App Design — Task Management System

> 这是一份示例应用设计文档，展示如何将需求结构化地描述给 AI 编码工具。
> 你可以复制此文件并修改为你自己的项目需求。

## 1. 产品概述

**名称**: TaskFlow — 智能任务管理系统

**目标用户**: 小团队（2-10 人），需要轻量级的任务追踪和协作工具

**核心价值**: 比 Jira 简单，比 TODO 列表强大，带 AI 辅助的任务拆分和优先级建议

## 2. 功能需求

### 2.1 用户系统 (F-001)

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 注册 | 邮箱 + 密码，发送验证邮件 | P0 |
| 登录 | JWT 认证，7 天有效期 | P0 |
| 个人资料 | 头像、昵称、时区设置 | P1 |
| 团队邀请 | 通过邮件邀请成员加入团队 | P1 |

**后端 API**:
```
POST   /api/v1/auth/register     — 注册
POST   /api/v1/auth/login        — 登录，返回 JWT
GET    /api/v1/auth/me           — 获取当前用户信息
PUT    /api/v1/auth/me           — 更新个人资料
POST   /api/v1/teams/invite      — 邀请成员
```

**数据模型**:
```
User:
  - id: UUID (PK)
  - email: string (unique)
  - hashed_password: string
  - name: string
  - avatar_url: string?
  - timezone: string (default: "Asia/Shanghai")
  - created_at: datetime
  - updated_at: datetime

Team:
  - id: UUID (PK)
  - name: string
  - owner_id: FK → User
  - created_at: datetime

TeamMember:
  - team_id: FK → Team
  - user_id: FK → User
  - role: enum(owner, admin, member)
  - joined_at: datetime
```

### 2.2 任务管理 (F-002)

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 创建任务 | 标题、描述、标签、截止日期、负责人 | P0 |
| 任务看板 | Kanban 视图：待办 → 进行中 → 已完成 | P0 |
| 任务列表 | 表格视图，支持排序和筛选 | P0 |
| 拖拽排序 | 看板内拖拽改变状态和优先级 | P1 |
| 子任务 | 任务可拆分为多个子任务 | P1 |
| 评论 | 任务下的评论和讨论 | P2 |

**后端 API**:
```
GET    /api/v1/tasks             — 任务列表（支持 ?status=&assignee=&tag=）
POST   /api/v1/tasks             — 创建任务
GET    /api/v1/tasks/:id         — 任务详情
PUT    /api/v1/tasks/:id         — 更新任务
DELETE /api/v1/tasks/:id         — 删除任务
PATCH  /api/v1/tasks/:id/status  — 更改任务状态
POST   /api/v1/tasks/:id/comments — 添加评论
```

**数据模型**:
```
Task:
  - id: UUID (PK)
  - title: string
  - description: text?
  - status: enum(todo, in_progress, done, archived)
  - priority: enum(low, medium, high, urgent)
  - assignee_id: FK → User?
  - creator_id: FK → User
  - team_id: FK → Team
  - parent_task_id: FK → Task? (自引用，用于子任务)
  - due_date: date?
  - tags: string[] (PostgreSQL array)
  - position: int (用于排序)
  - created_at: datetime
  - updated_at: datetime

Comment:
  - id: UUID (PK)
  - task_id: FK → Task
  - author_id: FK → User
  - content: text
  - created_at: datetime
```

### 2.3 Dashboard (F-003)

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 统计卡片 | 总任务数、进行中、已完成、逾期 | P0 |
| 最近活动 | 最近 10 条任务变更记录 | P1 |
| 个人看板 | 只显示分配给自己的任务 | P1 |

### 2.4 AI 辅助 (F-004)

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 任务拆分 | 输入一句话需求，AI 拆分为多个子任务 | P1 |
| 优先级建议 | 基于截止日期和依赖关系建议优先级 | P2 |
| 周报生成 | 基于本周完成的任务自动生成周报 | P2 |

## 3. 前端页面规划

```
/                     → Dashboard（统计卡片 + 最近活动）
/login                → 登录页
/register             → 注册页
/tasks                → 任务看板（Kanban 默认视图）
/tasks?view=list      → 任务列表视图
/tasks/:id            → 任务详情（侧边抽屉或独立页面）
/settings             → 个人设置
/settings/team        → 团队管理
```

## 4. 技术方案

### 后端
- **框架**: FastAPI + Pydantic v2
- **数据库**: PostgreSQL 16 + SQLAlchemy 2.0 (async)
- **迁移**: Alembic
- **认证**: JWT (python-jose)
- **AI**: OpenAI API / 本地 LLM via LiteLLM

### 前端
- **框架**: Next.js 14 (App Router)
- **UI**: Tailwind CSS + shadcn/ui
- **状态**: React Query (TanStack Query) + Zustand
- **拖拽**: @dnd-kit/core
- **图标**: Lucide React

## 5. 开发计划

### Phase 1 — MVP (2 周)
- [ ] 用户注册/登录 (F-001 核心)
- [ ] 任务 CRUD (F-002 核心)
- [ ] 任务看板视图
- [ ] Dashboard 统计
- [ ] Docker Compose 本地运行

### Phase 2 — 协作 (2 周)
- [ ] 团队功能
- [ ] 任务评论
- [ ] 拖拽排序
- [ ] 列表视图 + 筛选

### Phase 3 — AI (1 周)
- [ ] AI 任务拆分
- [ ] 优先级建议
- [ ] 周报生成

## 6. 如何让 AI 工具使用本文档

**Cursor**:
```
请阅读 @docs/example_app_design.md，按照 Phase 1 的计划，
帮我实现用户注册/登录功能。
```

**Claude Code**:
```
请读取 docs/example_app_design.md，然后按 Phase 1 计划开始开发。
从 F-001 用户系统开始，先实现后端 API，再对接前端页面。
```
EXAMPLE_EOF
success "docs/example_app_design.md"

# tech_preferences.md — 技术选型偏好
cat > docs/tech_preferences.md << 'TECH_EOF'
# Tech Preferences — 技术选型偏好

> AI 编码工具和开发者在做技术选型时 **必须** 参考本文档。
> 任何新增依赖都应优先使用下列指定库，避免引入同类竞品。

## 前端

### 图表 (Charts)

**必须使用**: [ECharts](https://echarts.apache.org/)

```bash
pnpm add echarts echarts-for-react
```

- 所有统计图表统一用 ECharts，React 中用 `echarts-for-react` wrapper
- 不要使用 Chart.js、Recharts、Nivo、Victory 等

### 图/网络可视化 (Graph / Network)

**必须使用**: [Cytoscape.js](https://js.cytoscape.org/)

```bash
pnpm add cytoscape react-cytoscapejs && pnpm add -D @types/cytoscape
```

- 所有关系图、网络图、拓扑图统一用 Cytoscape.js
- 不要使用 D3-force、vis.js、Sigma.js、react-flow 等

### UI 组件库

**必须使用**: [shadcn/ui](https://ui.shadcn.com/) + Tailwind CSS

- 不要额外引入 Ant Design、Material UI、Chakra UI
- 按需安装: `npx shadcn@latest add <component>`

### 常用库偏好

| 场景 | 首选库 | 备注 |
|------|--------|------|
| HTTP 请求 | 内置 `fetch` + `lib/api.ts` | 无需 axios |
| 服务端状态 | `@tanstack/react-query` | 缓存、重试、乐观更新 |
| 客户端状态 | `zustand` | 轻量级 |
| 表单 | `react-hook-form` + `zod` | shadcn/ui form 已集成 |
| 日期 | `date-fns` | 不用 moment.js / dayjs |
| 拖拽 | `@dnd-kit/core` | 看板、排序 |
| 动画 | `framer-motion` | 页面过渡 |
| 图标 | `lucide-react` | shadcn/ui 默认 |
| 数据表格 | `@tanstack/react-table` | 配合 shadcn DataTable |

## 后端

| 场景 | 首选库 |
|------|--------|
| Web 框架 | `FastAPI` |
| ORM | `SQLAlchemy 2.0` (async) + `asyncpg` |
| 数据校验 | `Pydantic v2` |
| 配置 | `pydantic-settings` |
| 迁移 | `Alembic` |
| 认证 | `python-jose` + `passlib` |
| HTTP 客户端 | `httpx` |
| AI / LLM | `litellm` |
| 测试 | `pytest` + `pytest-asyncio` |
| Lint | `ruff` |

## 开发工具链

| 用途 | 工具 | 命令 |
|------|------|------|
| Python lint + format | `ruff` | `make lint-backend` / `make format` |
| JS/TS format | `prettier` | `make format` |
| JS/TS lint | `ESLint` (Next.js 内置) | `pnpm lint` |
| 构建命令 | `Makefile` | `make help` |

## 通用原则

1. **成熟度优先**: GitHub stars > 5k，npm 周下载 > 50k
2. **维护活跃**: 最近 6 个月有更新
3. **类型安全**: 优先选有 TypeScript 类型定义的库
4. **避免重复**: 同一场景只引入一个库
5. **引入新库前**: 先在本文档中记录并说明理由
TECH_EOF
success "docs/tech_preferences.md"

# ─── Backend (FastAPI) ────────────────────────────────────────────────────────
step "Backend — FastAPI"

mkdir -p backend/app/api/routes backend/app/models backend/app/schemas \
         backend/app/services backend/app/prompts backend/app/core \
         backend/tests

# requirements.txt
cat > backend/requirements.txt << 'REQ_EOF'
fastapi>=0.111.0
uvicorn[standard]>=0.30.0
pydantic>=2.7.0
pydantic-settings>=2.3.0
sqlalchemy>=2.0.30
alembic>=1.13.0
asyncpg>=0.29.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
httpx>=0.27.0
python-dotenv>=1.0.1
pytest>=8.2.0
pytest-asyncio>=0.23.0
ruff>=0.5.0
REQ_EOF
success "requirements.txt"

# .env.example
cat > backend/.env.example << 'ENV_EOF'
# App
APP_NAME=harness_project
APP_ENV=development
DEBUG=true

# Server
BACKEND_PORT=8000
BACKEND_HOST=0.0.0.0

# Database
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/harness_db

# Auth
SECRET_KEY=change-me-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS (local dev: :3000 direct, Docker: via nginx :80)
CORS_ORIGINS=["http://localhost:3000","http://localhost","http://localhost:80"]
ENV_EOF
cp backend/.env.example backend/.env
success ".env"

# core/config.py
cat > backend/app/core/__init__.py << 'EOF'
EOF

cat > backend/app/core/config.py << 'PYEOF'
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "harness_project"
    app_env: str = "development"
    debug: bool = True

    backend_host: str = "0.0.0.0"
    backend_port: int = 8000

    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/harness_db"

    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 30

    cors_origins: list[str] = ["http://localhost:3000"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
PYEOF
success "core/config.py"

# app/main.py
cat > backend/app/__init__.py << 'EOF'
EOF

cat > backend/app/main.py << 'PYEOF'
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.api.routes import health, items


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    yield
    # shutdown


app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, tags=["health"])
app.include_router(items.router, prefix="/api/v1", tags=["items"])
PYEOF
success "app/main.py"

# API routes
cat > backend/app/api/__init__.py << 'EOF'
EOF

cat > backend/app/api/routes/__init__.py << 'EOF'
EOF

cat > backend/app/api/routes/health.py << 'PYEOF'
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check():
    return {"status": "healthy"}
PYEOF
success "api/routes/health.py"

cat > backend/app/api/routes/items.py << 'PYEOF'
from fastapi import APIRouter, HTTPException

from app.schemas.item import ItemCreate, ItemResponse

router = APIRouter()

_fake_db: list[dict] = []


@router.get("/items", response_model=list[ItemResponse])
async def list_items():
    return _fake_db


@router.post("/items", response_model=ItemResponse, status_code=201)
async def create_item(payload: ItemCreate):
    item = {"id": len(_fake_db) + 1, **payload.model_dump()}
    _fake_db.append(item)
    return item


@router.get("/items/{item_id}", response_model=ItemResponse)
async def get_item(item_id: int):
    for item in _fake_db:
        if item["id"] == item_id:
            return item
    raise HTTPException(status_code=404, detail="Item not found")
PYEOF
success "api/routes/items.py"

# Schemas
mkdir -p backend/app/schemas
cat > backend/app/schemas/__init__.py << 'EOF'
EOF

cat > backend/app/schemas/item.py << 'PYEOF'
from pydantic import BaseModel


class ItemCreate(BaseModel):
    name: str
    description: str = ""


class ItemResponse(ItemCreate):
    id: int
PYEOF
success "schemas/item.py"

# Models placeholder
cat > backend/app/models/__init__.py << 'EOF'
EOF

cat > backend/app/models/base.py << 'PYEOF'
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
PYEOF
success "models/base.py"

# Services placeholder
cat > backend/app/services/__init__.py << 'EOF'
EOF

# Prompts placeholder
cat > backend/app/prompts/__init__.py << 'EOF'
EOF

cat > backend/app/prompts/system.py << 'PYEOF'
SYSTEM_PROMPT = """You are a helpful AI assistant for the harness project.
Respond concisely and accurately.
"""
PYEOF
success "prompts/system.py"

# Tests
cat > backend/tests/__init__.py << 'EOF'
EOF

cat > backend/tests/conftest.py << 'PYEOF'
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
PYEOF

cat > backend/tests/test_health.py << 'PYEOF'
import pytest


@pytest.mark.asyncio
async def test_health(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "healthy"
PYEOF
success "tests/"

cat > backend/pytest.ini << 'PYEOF'
[pytest]
asyncio_mode = auto
testpaths = tests
PYEOF

# pyproject.toml with ruff config
cat > backend/pyproject.toml << 'PYEOF'
[project]
name = "harness-backend"
version = "0.1.0"
requires-python = ">=3.11"

[tool.ruff]
target-version = "py311"
line-length = 100

[tool.ruff.lint]
select = [
  "E",    # pycodestyle errors
  "W",    # pycodestyle warnings
  "F",    # pyflakes
  "I",    # isort
  "N",    # pep8-naming
  "UP",   # pyupgrade
  "B",    # flake8-bugbear
  "S",    # flake8-bandit (security)
  "A",    # flake8-builtins
  "T20",  # flake8-print
  "RUF",  # ruff-specific rules
]
ignore = ["S101"]  # allow assert in tests

[tool.ruff.lint.isort]
known-first-party = ["app"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
PYEOF
success "pyproject.toml (ruff)"

# ─── Frontend (Next.js + shadcn/ui) ──────────────────────────────────────────
step "Frontend — Next.js + shadcn/ui"

info "Creating Next.js app (this may take a minute)..."
pnpm dlx create-next-app@latest ./frontend \
  --typescript --tailwind --eslint --app --src-dir \
  --import-alias "@/*" --yes

info "Installing shadcn/ui..."
npx --yes shadcn@latest init -y --defaults --cwd ./frontend

# Additional frontend dependencies
info "Installing extra dependencies..."
(cd frontend && pnpm add lucide-react)

# Create directory structure
mkdir -p frontend/src/app/\(dashboard\) \
         frontend/src/app/\(auth\)/login \
         frontend/src/app/\(auth\)/register \
         frontend/src/app/settings \
         frontend/src/components/ui \
         frontend/src/components/layout \
         frontend/src/lib

# .env.local
cat > frontend/.env.local << 'ENV_EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_APP_NAME=Harness Project
ENV_EOF

cat > frontend/.env.example << 'ENV_EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_APP_NAME=Harness Project
ENV_EOF
success ".env.local"

# API client utility
cat > frontend/src/lib/api.ts << 'TSEOF'
const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

type RequestOptions = Omit<RequestInit, "body"> & {
  body?: unknown;
};

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { body, headers, ...rest } = options;

  const res = await fetch(`${API_BASE}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
    ...rest,
  });

  if (!res.ok) {
    const error = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(error.detail ?? "API request failed");
  }

  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) => request<T>(path, { method: "POST", body }),
  put: <T>(path: string, body: unknown) => request<T>(path, { method: "PUT", body }),
  delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};
TSEOF
success "lib/api.ts"

# Shared layout component
cat > frontend/src/components/layout/sidebar.tsx << 'TSEOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, Settings, LogIn } from "lucide-react";

const navItems = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/settings", label: "Settings", icon: Settings },
  { href: "/login", label: "Login", icon: LogIn },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-screen w-60 flex-col border-r bg-muted/40 p-4">
      <h1 className="mb-8 text-lg font-bold tracking-tight">
        {process.env.NEXT_PUBLIC_APP_NAME ?? "Harness"}
      </h1>
      <nav className="flex flex-1 flex-col gap-1">
        {navItems.map(({ href, label, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            className={`flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors hover:bg-accent ${
              pathname === href ? "bg-accent font-medium" : "text-muted-foreground"
            }`}
          >
            <Icon className="h-4 w-4" />
            {label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
TSEOF
success "components/layout/sidebar.tsx"

# Root layout with sidebar
cat > frontend/src/app/layout.tsx << 'TSEOF'
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Sidebar } from "@/components/layout/sidebar";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: process.env.NEXT_PUBLIC_APP_NAME ?? "Harness Project",
  description: "AI-powered harness project",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <div className="flex h-screen">
          <Sidebar />
          <main className="flex-1 overflow-auto p-8">{children}</main>
        </div>
      </body>
    </html>
  );
}
TSEOF
success "app/layout.tsx"

# Dashboard page
cat > frontend/src/app/page.tsx << 'TSEOF'
export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
        <p className="text-muted-foreground">Welcome to your harness project.</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {[
          { title: "Total Items", value: "0", desc: "Managed items" },
          { title: "API Health", value: "●", desc: "Backend status" },
          { title: "Uptime", value: "—", desc: "Since last deploy" },
        ].map((card) => (
          <div
            key={card.title}
            className="rounded-lg border bg-card p-6 text-card-foreground shadow-sm"
          >
            <p className="text-sm font-medium text-muted-foreground">{card.title}</p>
            <p className="mt-2 text-2xl font-bold">{card.value}</p>
            <p className="text-xs text-muted-foreground">{card.desc}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
TSEOF
success "app/page.tsx (dashboard)"

# Settings page
cat > frontend/src/app/settings/page.tsx << 'TSEOF'
export default function SettingsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Settings</h2>
        <p className="text-muted-foreground">Manage your project configuration.</p>
      </div>
      <div className="rounded-lg border p-6">
        <p className="text-sm text-muted-foreground">Settings panel coming soon.</p>
      </div>
    </div>
  );
}
TSEOF
success "app/settings/page.tsx"

# Login page
cat > frontend/src/app/\(auth\)/login/page.tsx << 'TSEOF'
export default function LoginPage() {
  return (
    <div className="flex min-h-[80vh] items-center justify-center">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center">
          <h2 className="text-2xl font-bold">Sign In</h2>
          <p className="text-sm text-muted-foreground">Enter your credentials to continue</p>
        </div>
        <form className="space-y-4">
          <div>
            <label htmlFor="email" className="text-sm font-medium">Email</label>
            <input
              id="email"
              type="email"
              placeholder="you@example.com"
              className="mt-1 block w-full rounded-md border px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label htmlFor="password" className="text-sm font-medium">Password</label>
            <input
              id="password"
              type="password"
              className="mt-1 block w-full rounded-md border px-3 py-2 text-sm"
            />
          </div>
          <button
            type="submit"
            className="w-full rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
          >
            Sign In
          </button>
        </form>
      </div>
    </div>
  );
}
TSEOF
success "app/(auth)/login/page.tsx"

# Register page
cat > frontend/src/app/\(auth\)/register/page.tsx << 'TSEOF'
export default function RegisterPage() {
  return (
    <div className="flex min-h-[80vh] items-center justify-center">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center">
          <h2 className="text-2xl font-bold">Create Account</h2>
          <p className="text-sm text-muted-foreground">Get started with your account</p>
        </div>
        <form className="space-y-4">
          <div>
            <label htmlFor="name" className="text-sm font-medium">Name</label>
            <input
              id="name"
              type="text"
              placeholder="Your name"
              className="mt-1 block w-full rounded-md border px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label htmlFor="email" className="text-sm font-medium">Email</label>
            <input
              id="email"
              type="email"
              placeholder="you@example.com"
              className="mt-1 block w-full rounded-md border px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label htmlFor="password" className="text-sm font-medium">Password</label>
            <input
              id="password"
              type="password"
              className="mt-1 block w-full rounded-md border px-3 py-2 text-sm"
            />
          </div>
          <button
            type="submit"
            className="w-full rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
          >
            Create Account
          </button>
        </form>
      </div>
    </div>
  );
}
TSEOF
success "app/(auth)/register/page.tsx"

# Enable standalone output for Docker multi-stage build
info "Configuring Next.js standalone output..."
if [ -f frontend/next.config.ts ]; then
  NEXT_CONFIG="frontend/next.config.ts"
elif [ -f frontend/next.config.mjs ]; then
  NEXT_CONFIG="frontend/next.config.mjs"
else
  NEXT_CONFIG="frontend/next.config.js"
fi

cat > "$NEXT_CONFIG" << 'NEXTCFG_EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
};

export default nextConfig;
NEXTCFG_EOF
success "next.config (standalone output)"

# Prettier config
cat > frontend/.prettierrc << 'PRETTIER_EOF'
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100,
  "plugins": ["prettier-plugin-tailwindcss"]
}
PRETTIER_EOF

(cd frontend && pnpm add -D prettier prettier-plugin-tailwindcss)
success "prettier config"

# ─── Docker ───────────────────────────────────────────────────────────────────
step "Docker"

cat > docker-compose.yml << 'DOCKER_EOF'
services:
  db:
    image: postgres:16-alpine
    container_name: __PROJECT_NAME__-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: harness_db
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - __PROJECT_NAME__-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: __PROJECT_NAME__-backend
    restart: unless-stopped
    environment:
      - ENVIRONMENT=production
      - SECRET_KEY=${SECRET_KEY:-change-me-in-production}
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/harness_db
      - CORS_ORIGINS=["http://localhost","http://localhost:80"]
    volumes:
      - backend-data:/app/data
    networks:
      - __PROJECT_NAME__-network
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: __PROJECT_NAME__-frontend
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - __PROJECT_NAME__-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

  nginx:
    image: nginx:alpine
    container_name: __PROJECT_NAME__-nginx
    restart: unless-stopped
    ports:
      - "${PORT:-80}:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - __PROJECT_NAME__-network
    depends_on:
      frontend:
        condition: service_healthy
      backend:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s

networks:
  __PROJECT_NAME__-network:
    driver: bridge

volumes:
  pgdata:
    driver: local
  backend-data:
    driver: local
DOCKER_EOF
sed -i '' "s/__PROJECT_NAME__/${PROJECT_NAME}/g" docker-compose.yml
success "docker-compose.yml"

cat > backend/Dockerfile << 'DOCK_EOF'
FROM python:3.12-slim

WORKDIR /app

RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple/

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p data

ENV PYTHONUNBUFFERED=1
ENV ENVIRONMENT=production

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCK_EOF
success "backend/Dockerfile"

cat > frontend/Dockerfile << 'DOCK_EOF'
# ===== Build Stage =====
FROM node:22-alpine AS build

RUN apk add --no-cache libc6-compat

RUN corepack enable && corepack prepare pnpm@9 --activate

RUN pnpm config set registry https://mirrors.cloud.tencent.com/npm/

WORKDIR /app

COPY package.json pnpm-lock.yaml* ./

RUN pnpm install --no-frozen-lockfile

COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_PUBLIC_API_URL=

RUN pnpm run build

# ===== Production Stage =====
FROM node:22-alpine AS runner

RUN apk add --no-cache libc6-compat

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=build /app/public ./public

RUN mkdir .next
RUN chown nextjs:nodejs .next

COPY --from=build --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=build --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/ || exit 1

CMD ["node", "server.js"]
DOCK_EOF
success "frontend/Dockerfile"

# ─── Nginx ────────────────────────────────────────────────────────────────────
step "Nginx — Reverse Proxy"

mkdir -p nginx

cat > nginx/nginx.conf << 'NGINX_EOF'
upstream frontend {
    server frontend:3000;
}

upstream backend {
    server backend:8000;
}

server {
    listen 80;
    server_name _;

    client_max_body_size 100M;

    # Backend API — proxy to FastAPI
    location /api/ {
        proxy_pass http://backend/api/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Backend health endpoint
    location = /health {
        proxy_pass http://backend/health;
    }

    # Frontend — everything else
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX_EOF
success "nginx/nginx.conf"

# ─── .gitignore ───────────────────────────────────────────────────────────────
step "Git"

cat > .gitignore << 'GIT_EOF'
# Python
__pycache__/
*.pyc
*.pyo
.venv/
backend/.env

# Node
node_modules/
.next/
frontend/.env.local

# Docker
pgdata/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
GIT_EOF
success ".gitignore"

# ─── Makefile ─────────────────────────────────────────────────────────────────
step "Makefile"

cat > Makefile << 'MAKE_EOF'
.PHONY: dev dev-backend dev-frontend docker-up docker-down docker-clean docker-logs docker-ps lint lint-backend lint-frontend format test clean

# ─── Development (local) ─────────────────────────────────────────────────────

dev: ## Start backend + frontend in parallel
	@make -j2 dev-backend dev-frontend

dev-backend: ## Start FastAPI dev server
	cd backend && uvicorn app.main:app --reload --port 8000

dev-frontend: ## Start Next.js dev server
	cd frontend && pnpm dev

# ─── Docker (production-like with nginx) ─────────────────────────────────────

docker-up: ## Start all services (db + backend + frontend + nginx)
	docker compose up --build -d

docker-down: ## Stop all Docker services
	docker compose down

docker-clean: ## Stop and remove volumes
	docker compose down -v

docker-logs: ## Tail logs for all containers
	docker compose logs -f

docker-ps: ## Show running containers and health
	docker compose ps

# ─── Lint & Format ────────────────────────────────────────────────────────────

lint: lint-backend lint-frontend ## Lint all code

lint-backend: ## Lint Python with ruff
	cd backend && ruff check .

lint-frontend: ## Lint frontend with ESLint
	cd frontend && pnpm lint

format: ## Format all code
	cd backend && ruff format . && ruff check --fix .
	cd frontend && pnpm exec prettier --write "src/**/*.{ts,tsx,css}"

# ─── Test ─────────────────────────────────────────────────────────────────────

test: ## Run all tests
	cd backend && pytest -v
	cd frontend && pnpm test 2>/dev/null || echo "(frontend tests not configured)"

test-backend: ## Run backend tests
	cd backend && pytest -v

# ─── Utilities ────────────────────────────────────────────────────────────────

install: ## Install all dependencies
	cd backend && pip install -r requirements.txt
	cd frontend && pnpm install

clean: ## Remove generated files (use clean.sh)
	./clean.sh

tree: ## Show project structure
	@tree -I 'node_modules|.next|__pycache__|.venv|.git' --dirsfirst -L 3

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
MAKE_EOF
success "Makefile"

# ─── Summary ──────────────────────────────────────────────────────────────────
step "Done! Project Structure"
echo ""
echo "  $PROJECT_NAME/"
echo "  ├── AGENTS.md              ← AI agent guidance"
echo "  ├── feature_list.json      ← Feature tracking"
echo "  ├── progress.md            ← Sprint progress"
echo "  ├── Makefile               ← make help 查看所有命令"
echo "  ├── docker-compose.yml     ← Full-stack Docker (db + backend + frontend + nginx)"
echo "  ├── .gitignore"
echo "  ├── nginx/"
echo "  │   └── nginx.conf         ← Reverse proxy config (:80 → frontend/backend)"
echo "  ├── docs/"
echo "  │   ├── design.md              ← ⭐ 先填写你的项目设计"
echo "  │   ├── example_app_design.md  ← 参考示例"
echo "  │   └── tech_preferences.md    ← 技术选型偏好"
echo "  ├── backend/"
echo "  │   ├── Dockerfile         ← Python 3.12 multi-stage, healthcheck"
echo "  │   ├── requirements.txt"
echo "  │   ├── pyproject.toml     ← ruff lint 配置"
echo "  │   ├── .env"
echo "  │   ├── pytest.ini"
echo "  │   ├── app/"
echo "  │   │   ├── main.py         ← FastAPI entrypoint"
echo "  │   │   ├── core/config.py  ← Pydantic settings"
echo "  │   │   ├── api/routes/     ← API endpoints"
echo "  │   │   ├── models/         ← SQLAlchemy models"
echo "  │   │   ├── schemas/        ← Pydantic schemas"
echo "  │   │   ├── services/       ← Business logic"
echo "  │   │   └── prompts/        ← AI prompt templates"
echo "  │   └── tests/"
echo "  └── frontend/"
echo "      ├── Dockerfile         ← Node 22 multi-stage build (standalone)"
echo "      ├── src/"
echo "      │   ├── app/            ← Next.js pages"
echo "      │   ├── components/     ← React components"
echo "      │   └── lib/api.ts      ← API client"
echo "      └── .env.local"
echo ""
echo -e "${GREEN}${BOLD}Quick Start:${NC}"
echo "  1. 编辑 docs/design.md 填写你的项目需求"
echo "  2. make install          安装所有依赖 (本地开发)"
echo "  3. make dev              同时启动前后端 (本地开发)"
echo "  4. make docker-up        Docker 启动全部服务 (含 nginx)"
echo "  5. 访问 http://localhost  通过 nginx 代理访问"
echo "  6. make help             查看所有可用命令"
echo ""
