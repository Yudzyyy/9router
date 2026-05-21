# 9Router LLM Deployment with Ollama Integration

**Deployment Status**: Phase 1 ✅ Initialized

## Quick Start

```bash
# 1. Clone 9Router repository
git clone https://github.com/decolua/9router.git .

# 2. Copy configuration
cp .env.example .env.local

# 3. Start Docker Compose stack
docker-compose up -d

# 4. Access dashboard
# http://localhost:20128/dashboard
# Default password: admin123
```

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    CLI Tools / Clients                        │
│  (Claude Code, Cursor, Cline, Copilot, etc.)                │
└────────────────────────┬─────────────────────────────────────┘
                         │ http://localhost:20128/v1
                         ↓
┌──────────────────────────────────────────────────────────────┐
│                    9Router (Next.js)                          │
│  • RTK Token Saver (20-40% compression)                       │
│  • Multi-Tenant Support (workspace isolation)                 │
│  • Intelligent Routing (model availability based)             │
│  • Format Translation (OpenAI ↔ Claude ↔ Gemini)            │
└────────┬───────────────┬─────────────┬───────────────────────┘
         │               │             │
         ↓               ↓             ↓
    ┌─────────┐   ┌──────────┐   ┌─────────┐
    │ Ollama  │   │PostgreSQL│   │  Redis  │
    │10.15... │   │(5432)    │   │(6379)   │
    │(Local)  │   │(Users)   │   │(Cache)  │
    └─────────┘   └──────────┘   └─────────┘
         │
    Free + Cloud
    Tier Routing
         │
    ┌────────────────────────────────────────────┐
    │  Cloud Providers (Free → Cheap → Paid)      │
    │  Kiro, OpenCode, GLM, MiniMax, OpenAI, etc │
    └────────────────────────────────────────────┘
```

## Directory Structure

```
d:\9router/
├── config/
│   ├── providers/
│   │   ├── ollama-local.json         # Local Ollama config
│   │   ├── free-providers.json       # Kiro, OpenCode, Vertex
│   │   ├── cheap-providers.json      # GLM, MiniMax
│   │   └── subscription-providers.json # OpenAI, Claude, etc
│   └── combos.json                   # Fallback chain configurations
├── docker/
│   ├── Dockerfile                    # Build 9Router image
│   └── docker-compose.yml            # Multi-service orchestration
├── sql/
│   ├── init.sql                      # PostgreSQL initialization
│   └── schema.sql                    # Database schema (tables, indexes)
├── scripts/
│   ├── deploy.ps1                    # Windows deployment script
│   ├── logs.ps1                      # View container logs
│   ├── stop.ps1                      # Stop containers
│   └── reset.ps1                     # Full reset
├── docs/
│   ├── CONFIGURATION.md              # How to configure providers
│   ├── MULTI_TENANCY.md              # Workspace/organization setup
│   ├── OLLAMA_INTEGRATION.md          # Ollama connectivity guide
│   ├── PROVIDERS.md                  # Provider-specific setup
│   └── TROUBLESHOOTING.md            # Common issues & solutions
├── logs/
│   └── (request logs, application logs)
├── .env.local                        # Development environment
├── .env.prod                         # Production environment template
├── docker-compose.yml                # Main orchestration file
├── .dockerignore                     # Docker build exclusions
└── README.md                         # This file
```

## Deployment Stages

### Phase 1: ✅ Project Setup (COMPLETE)
- [x] Directory structure created
- [x] Docker Compose configuration ready
- [x] Provider configurations defined
- [x] Database schema created
- [x] Environment files templated
- [x] Documentation framework initialized

### Phase 2: Multi-Tenancy Architecture
- [ ] Database schema deployment
- [ ] User authentication layer
- [ ] Workspace routing logic
- [ ] Organizational context in API

### Phase 3: Provider & Configuration Management
- [ ] Ollama health checks
- [ ] Provider credential management
- [ ] Model discovery from Ollama + cloud
- [ ] Fallback chain implementation

### Phase 4: Docker Compose & Networking
- [ ] Build and test 9Router image
- [ ] Verify PostgreSQL connectivity
- [ ] Configure Ollama routing
- [ ] Test multi-service networking

### Phase 5: Configuration Management
- [ ] Provider setup documentation
- [ ] Multi-tenancy guide
- [ ] Ollama integration guide
- [ ] Troubleshooting documentation

### Phase 6: Deployment & Startup Scripts
- [ ] PowerShell deployment scripts
- [ ] Health check automation
- [ ] First-run initialization
- [ ] Team onboarding docs

### Phase 7: Monitoring & Verification
- [ ] Logging configuration
- [ ] Analytics dashboard
- [ ] Health monitoring
- [ ] Integration testing

## Key Components

### 🖥️ 9Router (LLM Gateway)
- **Port**: 20128
- **API**: OpenAI-compatible (`/v1/chat/completions`, `/v1/models`)
- **Dashboard**: http://localhost:20128/dashboard
- **Tech**: Node.js 20, Next.js 16, React 19

### 🐘 PostgreSQL (User Data)
- **Port**: 5432
- **Database**: 9router
- **User**: 9router
- **Persistence**: `postgres_data` volume
- **Features**: Multi-tenancy, workspace isolation, request logging

### 🚀 Redis (Cache & Sessions)
- **Port**: 6379
- **Use**: Session management, model cache, feature flags
- **Persistence**: `redis_data` volume

### 🦙 Ollama (Local LLM)
- **Host**: 10.15.17.190
- **Port**: 11434
- **Models**: gemma, qwen, deepseek, mistral, llama
- **Status**: External (not in docker-compose)

## Provider Tiers

### Tier 1: Local (Priority 1) - FREE ⚡
```
Ollama at 10.15.17.190:11434
├── gemma (fast, lightweight)
├── qwen (fast, good quality)
├── deepseek (specialized)
├── mistral (open source, high quality)
└── llama (flagship)
```
**Cost**: $0/month | **Latency**: <100ms | **Privacy**: 100% local

### Tier 2: Free Cloud (Priority 2) - FREE 💰
```
Kiro AI (unlimited)
├── Claude Opus 4.7
├── GLM-5
└── MiniMax M2.5

OpenCode Free (no auth)
└── Auto-fetch all available

Vertex AI ($300 credits)
└── Gemini Pro + GLM-5 + DeepSeek
```
**Cost**: $0/month | **Latency**: 1-3s | **Quality**: High

### Tier 3: Cheap Providers (Priority 3) - 💵
```
GLM ($0.6/1M tokens)
├── GLM-5.1
└── GLM-4.7

MiniMax ($0.2/1M tokens)
└── MiniMax M2.7
```
**Cost**: $5-10/month | **Latency**: 2-5s | **Quality**: Very Good

### Tier 4: Premium (Priority 4) - 💳
```
OpenAI ($0.03/1K tokens)
├── GPT-5.5
└── GPT-4 Turbo

Anthropic ($0.03/1K tokens)
├── Claude Opus 4.6
└── Claude Sonnet 4.5

GitHub Copilot (subscription)
└── Claude via Copilot
```
**Cost**: $20-200/month | **Latency**: 1-3s | **Quality**: Best

## Default Combos (Fallback Chains)

### `local-first` (Default)
```
1. Ollama (free, fast, local)
2. Kiro (free cloud)
3. GLM (cheap)
```
**Best For**: General use, cost optimization, privacy-conscious

### `local-only`
```
1. Ollama (no fallback)
```
**Best For**: Sensitive data, air-gapped, strict privacy requirements

### `free-forever`
```
1. Kiro (free unlimited)
2. OpenCode Free
3. Vertex AI
```
**Best For**: Zero cost, unlimited usage

### `cloud-backup`
```
1. Ollama
2. GLM (cheap)
3. Kiro (free)
```
**Best For**: Balanced local + cloud with cost control

### `always-on`
```
1. Ollama
2. OpenAI (GPT-5.5)
3. Anthropic (Claude)
4. GLM
5. Kiro
```
**Best For**: 24/7 availability, zero downtime, premium quality

## Getting Started

### 1. Prerequisites
- Docker Desktop with Docker Compose
- Network access to Ollama at 10.15.17.190:11434
- PostgreSQL will be managed by Docker Compose
- Redis will be managed by Docker Compose

### 2. Clone 9Router and Configure
```bash
# Clone official repository
git clone https://github.com/decolua/9router.git d:\9router-src
cd d:\9router-src

# Copy to deployment folder
# (Or customize existing d:\9router setup)
```

### 3. Start the Stack
```bash
cd d:\9router

# Using PowerShell
.\scripts\deploy.ps1

# Or manually
docker-compose up -d
```

### 4. Verify Deployment
```bash
# Check services
docker-compose ps

# Verify Ollama connectivity
curl http://10.15.17.190:11434/api/tags

# Check 9Router health
curl http://localhost:20128/health

# View logs
docker-compose logs -f 9router
```

### 5. Access Dashboard
```
URL: http://localhost:20128/dashboard
Initial Password: admin123 (from .env.local)
Change password on first login
```

### 6. Add Your Team
```
1. Dashboard → Settings → Users
2. Invite team members by email
3. Each user creates/joins workspace
4. Configure workspace-specific providers
```

## First-Run Setup

1. **Initialize default organization**
   - Created automatically: "Default Organization"
   - Default workspace: "Default Workspace"

2. **Create admin user** (via dashboard or CLI)
   - Email: admin@example.com
   - Password: Change INITIAL_PASSWORD in .env

3. **Add providers** (via dashboard)
   - Kiro: OAuth required (free)
   - OpenAI: API key required
   - GLM: API key required
   - Ollama: Auto-detected (no config needed)

4. **Create custom combos** (via dashboard)
   - Combine providers for your use case
   - Set as default for workspace
   - Each user can override

5. **Connect your CLI tool**
   - Endpoint: http://machine-ip:20128/v1
   - API Key: Copy from dashboard
   - Model: Select from available (ollama/*, kr/*, etc)

## Environment Variables

See `.env.prod` for full list. Key variables:

```bash
# Server
PORT=20128
NODE_ENV=production
NEXT_PUBLIC_BASE_URL=http://your-machine-ip:20128

# Database
DATABASE_URL=postgresql://9router:password@postgres:5432/9router
REDIS_URL=redis://redis:6379

# Ollama
OLLAMA_ENDPOINT=http://10.15.17.190:11434
ENABLE_OLLAMA_ROUTING=true

# Providers
PROVIDERS_FREE_KIRO_ENABLED=true
GLM_API_KEY=your-key-here

# Features
ENABLE_REQUEST_LOGS=true
ENABLE_RTK_TOKEN_SAVER=true
ENABLE_MULTI_TENANT=true
```

## Troubleshooting

### Can't reach Ollama
```bash
# Test connectivity from deployment machine
curl http://10.15.17.190:11434/api/tags

# From docker container
docker-compose exec 9router curl http://10.15.17.190:11434/api/tags

# Check network
docker network inspect 9router_network
```

### PostgreSQL connection failed
```bash
# Check logs
docker-compose logs postgres

# Verify container is running
docker-compose ps postgres

# Test connection
docker-compose exec postgres psql -U 9router -d 9router -c "SELECT 1"
```

### Dashboard not accessible
```bash
# Check 9router logs
docker-compose logs 9router

# Verify port binding
netstat -ano | findstr :20128

# Test locally
curl http://localhost:20128/health
```

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more issues.

## Next Steps

1. **Phase 2**: Deploy database schema and test connectivity
2. **Phase 3**: Configure providers and test routing
3. **Phase 4**: Build and test Docker images
4. **Phase 5**: Complete documentation
5. **Phase 6**: Create deployment automation
6. **Phase 7**: Setup monitoring and analytics

## References

- [9Router GitHub](https://github.com/decolua/9router)
- [9Router Documentation](https://9router.com/)
- [Ollama Documentation](https://ollama.ai/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/docs/)

## Support

- **Issues**: Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **GitHub**: https://github.com/decolua/9router/issues
- **Documentation**: See docs/ folder

---

**Last Updated**: May 5, 2026  
**Status**: Phase 1 ✅ Complete, Phase 2 in progress
