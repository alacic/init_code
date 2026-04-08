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
- **Stack**: Next.js (frontend) + FastAPI (backend)
- **Monorepo**: `frontend/` and `backend/` at repo root

## Architecture
```
nginx/      → Nginx reverse proxy (port 80 → frontend/backend)
frontend/   → Next.js 14+ App Router, TypeScript, Tailwind, shadcn/ui
backend/    → FastAPI, Pydantic v2, graph-tool (graph analysis), loguru (logging)
docs/       → Design docs, ADRs, API specs
```

## Conventions
- Backend: snake_case for files/functions, PascalCase for classes/models
- Frontend: kebab-case for files, PascalCase for components
- API routes: RESTful, versioned under `/api/v1/`
- All new features need tests before merge

## Tech Preferences (IMPORTANT)
**Before adding ANY dependency, read `docs/tech_preferences.md`**
**Every code change MUST pass `make lint` — see `docs/dev_rules.md`**

Key constraints:
- Charts → **ECharts** (not Recharts, Chart.js, Nivo)
- Graph/Network visualization → **Cytoscape.js** with layout extensions (not D3-force, vis.js, react-flow)
- Backend graph analysis → **graph-tool** (not NetworkX, igraph)
- UI components → **shadcn/ui** only (not Ant Design, MUI, Chakra)
- State management → **zustand** (client) + **@tanstack/react-query** (server)
- Logging → **loguru** (not stdlib logging)
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

<!-- 描述核心实体和字段 -->

```
实体名:
  - id: str (PK)
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

<!-- 如果有额外服务（数据库、Redis、消息队列、外部 API），在这里补充 -->

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

# dev_rules.md — 开发规范约束（给 AI 编码工具的硬性规则）
cat > docs/dev_rules.md << 'RULES_EOF'
# 开发规范 — AI 编码工具必须遵守

> 本文档是给 AI 编码工具（Cursor / Claude Code / Codex 等）的 **硬性约束**。
> 每次编写或修改代码后 **必须** 执行以下检查。

## 代码质量检查（每次修改后必做）

```bash
# 后端 — 修改 Python 文件后
make lint-backend       # ruff 检查，必须 0 error
make format             # 自动格式化

# 前端 — 修改 TS/TSX 文件后
make lint-frontend      # ESLint 检查，必须 0 error

# 一键全量检查
make lint               # 同时 lint 前后端
```

## 测试（功能变更后必做）

```bash
# 后端
make test-backend       # pytest，新增 API 必须有对应测试

# 全量
make test               # 前后端一起跑
```

## 提交前检查清单

| 检查项 | 命令 | 要求 |
|--------|------|------|
| Python lint | `make lint-backend` | 0 error, 0 warning |
| TS/JS lint | `make lint-frontend` | 0 error |
| 格式化 | `make format` | 已执行 |
| 后端测试 | `make test-backend` | 全部通过 |
| 类型安全 | 前端 `pnpm build` 无 TS error | 编译通过 |

## 日志规范

- **后端一律使用 `loguru`**，禁止 `import logging` 或 `print()` 调试
- 使用方式：`from loguru import logger`，然后 `logger.info(...)`
- 敏感信息（密码、token、密钥）**禁止**出现在日志中

## 依赖管理

- 新增前端依赖：先查看 `docs/tech_preferences.md`，同类库已有指定的不要引入新的
- 新增后端依赖：加入 `backend/requirements.txt` 并说明用途
- **禁止** 引入与 tech_preferences.md 冲突的库

```
RULES_EOF
success "docs/dev_rules.md"

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

**必须使用**: [Cytoscape.js](https://js.cytoscape.org/) + 布局扩展

```bash
pnpm add cytoscape react-cytoscapejs cytoscape-cola cytoscape-dagre cytoscape-fcose
pnpm add -D @types/cytoscape
```

- 所有关系图、网络图、拓扑图统一用 Cytoscape.js
- 默认启用自动布局（fcose / dagre / cola / grid / circle），展示时必须包含排布功能
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
| 数据校验 | `Pydantic v2` |
| 配置 | `pydantic-settings` |
| 日志 | `loguru` (不用 stdlib logging) |
| 图分析 | `graph-tool` (不用 NetworkX、igraph) |
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
loguru>=0.7.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
httpx>=0.27.0
python-dotenv>=1.0.1
pytest>=8.2.0
pytest-asyncio>=0.23.0
ruff>=0.5.0
# graph-tool: installed via conda in Dockerfile
langchain>=0.3.0
langchain-openai>=0.2.0
langchain-community>=0.3.0
langchain-core>=0.3.0
langgraph>=0.2.0
langsmith>=0.1.0
openai>=1.50.0
tiktoken>=0.7.0
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

cat > backend/app/core/logging.py << 'PYEOF'
import sys

from loguru import logger

from app.core.config import settings

logger.remove()

if settings.debug:
    logger.add(sys.stderr, level="DEBUG", format="{time:HH:mm:ss} | {level:<7} | {message}")
else:
    logger.add(sys.stderr, level="INFO", format="{time:YYYY-MM-DD HH:mm:ss} | {level:<7} | {name}:{function}:{line} | {message}")

logger.add(
    "logs/{time:YYYY-MM-DD}.log",
    rotation="00:00",
    retention="30 days",
    level="INFO",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level:<7} | {name}:{function}:{line} | {message}",
)
PYEOF
success "core/logging.py (loguru)"

cat > backend/app/main.py << 'PYEOF'
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger

from app.core.config import settings
import app.core.logging  # noqa: F401 — init loguru
from app.api.routes import graph, health, items, llm


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting {} ...", settings.app_name)
    yield
    logger.info("Shutting down {} ...", settings.app_name)


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
app.include_router(graph.router, prefix="/api/v1", tags=["graph"])
app.include_router(llm.router, prefix="/api/v1", tags=["llm"])
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
"""Item CRUD routes.

Endpoints:
    GET    /items           — list all items
    POST   /items           — create item (ItemCreate → ItemResponse)
    GET    /items/{item_id} — get single item (404 if missing)

Schema: app.schemas.item (ItemCreate, ItemResponse)
"""
from fastapi import APIRouter

router = APIRouter()
PYEOF
success "api/routes/items.py"

cat > backend/app/api/routes/graph.py << 'PYEOF'
"""Graph analysis routes.

Endpoints:
    POST /graph/analyze — accept {nodes, edges}, return pagerank & betweenness metrics

Request body:
    nodes: list[{id: str, label: str}]
    edges: list[{source: str, target: str}]

Uses: app.services.graph_analysis (graph-tool backend)
"""
from fastapi import APIRouter

router = APIRouter()
PYEOF
success "api/routes/graph.py"

cat > backend/app/api/routes/llm.py << 'PYEOF'
"""LLM Provider management routes.

Endpoints:
    POST   /llm/providers       — register or update a provider
    GET    /llm/providers       — list all providers (api_key hidden)
    DELETE /llm/providers/{name} — remove a provider
    POST   /llm/chat            — chat using a registered provider
"""
from fastapi import APIRouter

router = APIRouter()
PYEOF
success "api/routes/llm.py"

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

# Models placeholder
cat > backend/app/models/base.py << 'PYEOF'
from pydantic import BaseModel


class TimestampMixin(BaseModel):
    created_at: str | None = None
    updated_at: str | None = None
PYEOF
success "models/base.py"

# Services
cat > backend/app/services/__init__.py << 'EOF'
EOF

cat > backend/app/services/graph_analysis.py << 'PYEOF'
"""Graph analysis service using graph-tool.

Graceful fallback: if graph-tool is not installed, return basic stats only.

Public API:
    build_graph(nodes, edges) -> gt.Graph | None
    analyze_graph(nodes, edges) -> dict
        Returns: {num_nodes, num_edges, metrics: [{id, pagerank, betweenness}]}
"""
PYEOF
success "services/graph_analysis.py"

cat > backend/app/services/llm_registry.py << 'PYEOF'
"""LLM Provider Registry — runtime registration of LLM providers.

Storage: data/llm_providers.json (persisted via Docker volume)
Supported provider_type: "openai_compatible" (via langchain_openai.ChatOpenAI)

Public API:
    register_provider(name, api_key, api_base, model, provider_type, extra) -> dict
    remove_provider(name) -> bool
    list_providers() -> list[dict]       (api_key redacted)
    get_provider(name) -> dict | None
    build_chat_model(name) -> BaseChatModel
"""
PYEOF
success "services/llm_registry.py"

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
(cd frontend && pnpm add lucide-react cytoscape react-cytoscapejs cytoscape-cola cytoscape-dagre cytoscape-fcose)
(cd frontend && pnpm add react-markdown remark-gfm rehype-highlight)
(cd frontend && pnpm add -D @types/cytoscape)

# Create directory structure
mkdir -p frontend/src/app/\(dashboard\) \
         frontend/src/app/\(auth\)/login \
         frontend/src/app/\(auth\)/register \
         frontend/src/app/settings \
         frontend/src/components/ui \
         frontend/src/components/layout \
         frontend/src/lib

# Graph visualization component (Cytoscape.js with layout)
mkdir -p frontend/src/components/graph

cat > frontend/src/components/graph/graph-viewer.tsx << 'TSEOF'
/**
 * GraphViewer — Cytoscape.js graph visualization component.
 *
 * Props:
 *   elements: cytoscape.ElementDefinition[]   — nodes & edges data
 *   layout:   "fcose" | "dagre" | "cola" | "grid" | "circle"
 *   style:    cytoscape.Stylesheet[]          — custom node/edge styling
 *   className: string
 *
 * Features:
 *   - Layout switcher toolbar (fcose, dagre, cola, grid, circle)
 *   - Fit-to-view button
 *   - Default indigo color scheme for nodes, light edges with arrows
 *
 * Dependencies: cytoscape, cytoscape-cola, cytoscape-dagre, cytoscape-fcose
 */
export {};
TSEOF
success "components/graph/graph-viewer.tsx"

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
/**
 * Typed API client wrapping fetch.
 *
 * Base URL from NEXT_PUBLIC_API_URL (default http://localhost:8000).
 *
 * Exports:
 *   api.get<T>(path)          — GET request
 *   api.post<T>(path, body)   — POST with JSON body
 *   api.put<T>(path, body)    — PUT with JSON body
 *   api.delete<T>(path)       — DELETE request
 *
 * Auto JSON serialization, error extraction from {detail} response.
 */
export {};
TSEOF
success "lib/api.ts"

# Shared layout component
cat > frontend/src/components/layout/sidebar.tsx << 'TSEOF'
/**
 * Sidebar navigation component.
 *
 * "use client" — uses usePathname for active route highlighting.
 *
 * Nav items: Dashboard (/), Settings (/settings), Login (/login)
 * Icons: lucide-react (LayoutDashboard, Settings, LogIn)
 * Width: w-60, border-r, bg-muted/40
 * App name from NEXT_PUBLIC_APP_NAME env var.
 */
export {};
TSEOF
success "components/layout/sidebar.tsx"

# Root layout with sidebar
cat > frontend/src/app/layout.tsx << 'TSEOF'
/**
 * Root layout — Inter font, globals.css, flex row: Sidebar + main content.
 *
 * Structure: <html> → <body> → flex h-screen → <Sidebar /> + <main>{children}</main>
 * Metadata title from NEXT_PUBLIC_APP_NAME.
 */
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}
TSEOF
success "app/layout.tsx"

# Dashboard page
cat > frontend/src/app/page.tsx << 'TSEOF'
/**
 * Dashboard page — 3-column stats cards grid.
 * Cards: Total Items, API Health, Uptime.
 */
export default function DashboardPage() {
  return <div>Dashboard</div>;
}
TSEOF
success "app/page.tsx (dashboard)"

# Settings page
cat > frontend/src/app/settings/page.tsx << 'TSEOF'
/** Settings page — project configuration panel. */
export default function SettingsPage() {
  return <div>Settings</div>;
}
TSEOF
success "app/settings/page.tsx"

# Login page
cat > frontend/src/app/\(auth\)/login/page.tsx << 'TSEOF'
/** Login page — email + password form, centered layout. */
export default function LoginPage() {
  return <div>Login</div>;
}
TSEOF
success "app/(auth)/login/page.tsx"

# Register page
cat > frontend/src/app/\(auth\)/register/page.tsx << 'TSEOF'
/** Register page — name + email + password form, centered layout. */
export default function RegisterPage() {
  return <div>Register</div>;
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
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: __PROJECT_NAME__-backend
    restart: unless-stopped
    environment:
      - ENVIRONMENT=production
      - SECRET_KEY=${SECRET_KEY:-change-me-in-production}
      - CORS_ORIGINS=["http://localhost","http://localhost:80"]
    volumes:
      - backend-data:/app/data
      - backend-logs:/app/logs
    networks:
      - __PROJECT_NAME__-network
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
  backend-data:
    driver: local
  backend-logs:
    driver: local
DOCKER_EOF
sed -i '' "s/__PROJECT_NAME__/${PROJECT_NAME}/g" docker-compose.yml
success "docker-compose.yml"

cat > backend/Dockerfile << 'DOCK_EOF'
FROM condaforge/miniforge3:latest

WORKDIR /app

RUN conda install -y -c conda-forge graph-tool && \
    conda clean -afy

RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple/

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p data logs

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

# Logs
logs/

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

docker-up: ## Start all services (backend + frontend + nginx)
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
echo "  ├── Makefile               ← make help 查看所有命令"
echo "  ├── docker-compose.yml     ← Full-stack Docker (backend + frontend + nginx)"
echo "  ├── .gitignore"
echo "  ├── nginx/"
echo "  │   └── nginx.conf         ← Reverse proxy config (:80 → frontend/backend)"
echo "  ├── docs/"
echo "  │   ├── design.md              ← ⭐ 先填写你的项目设计"
echo "  │   ├── dev_rules.md           ← AI 编码工具必读的开发规范"
echo "  │   └── tech_preferences.md    ← 技术选型偏好"
echo "  ├── backend/"
echo "  │   ├── Dockerfile         ← Python 3.12, healthcheck"
echo "  │   ├── requirements.txt   ← + loguru, graph-tool (系统依赖)"
echo "  │   ├── app/"
echo "  │   │   ├── main.py         ← FastAPI entrypoint"
echo "  │   │   ├── core/config.py  ← Pydantic settings"
echo "  │   │   ├── core/logging.py ← loguru 日志配置"
echo "  │   │   ├── api/routes/     ← API endpoints (health, items, graph)"
echo "  │   │   ├── models/         ← Data models"
echo "  │   │   ├── schemas/        ← Pydantic schemas"
echo "  │   │   ├── services/       ← Business logic (含 graph_analysis)"
echo "  │   │   └── prompts/        ← AI prompt templates"
echo "  │   └── tests/"
echo "  └── frontend/"
echo "      ├── Dockerfile         ← Node 22 multi-stage build (standalone)"
echo "      ├── src/"
echo "      │   ├── app/            ← Next.js pages"
echo "      │   ├── components/     ← React components (含 graph-viewer)"
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
