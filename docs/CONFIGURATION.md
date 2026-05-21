# Configuration Guide

## Overview

9Router is configured through environment variables, JSON files, and the web dashboard. This guide covers all configuration options.

## Quick Start

1. Copy environment template:
   ```bash
   cp .env.example .env.local    # Development
   cp .env.example .env.prod     # Production
   ```

2. Update critical values:
   ```bash
   # .env.prod
   OLLAMA_ENDPOINT=http://10.15.17.190:11434
   INITIAL_PASSWORD=YourSecurePassword123!
   JWT_SECRET=your-secure-jwt-secret-key
   DATABASE_URL=postgresql://9router:password@postgres:5432/9router
   ```

3. Start services:
   ```bash
   docker-compose up -d
   ```

## Environment Variables

### Server Configuration
```bash
# Port
PORT=20128                                      # Default: 20128
HOSTNAME=0.0.0.0                              # Bind address
NEXT_PUBLIC_BASE_URL=http://localhost:20128   # Base URL for redirects

# Environment
NODE_ENV=production                             # production or development
LOG_LEVEL=info                                  # debug, info, warn, error
```

### Database & Cache
```bash
# PostgreSQL
DATABASE_URL=postgresql://user:pass@host:5432/9router
DB_CONNECTION_TIMEOUT=5000
DB_POOL_SIZE=20

# Redis
REDIS_URL=redis://localhost:6379
REDIS_DB=0
REDIS_KEY_PREFIX=9router:
```

### Ollama Configuration
```bash
# Local LLM
OLLAMA_ENDPOINT=http://10.15.17.190:11434
OLLAMA_ENABLED=true
OLLAMA_MODELS=gemma,qwen,deepseek,mistral,llama
OLLAMA_TIMEOUT_MS=10000
OLLAMA_HEALTH_CHECK_INTERVAL=60000
ENABLE_OLLAMA_ROUTING=true
```

### Provider Credentials
```bash
# Free Providers (no credentials needed)
PROVIDERS_FREE_KIRO_ENABLED=true
PROVIDERS_FREE_OPENCODE_ENABLED=true
PROVIDERS_FREE_VERTEX_ENABLED=false

# Cheap Providers
GLM_API_KEY=sk-...
MINIMAX_API_KEY=...

# Premium Providers
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GITHUB_COPILOT_TOKEN=...
CODEX_API_KEY=...

# Custom Endpoints
CUSTOM_PROVIDER_1_ENDPOINT=http://api.example.com
CUSTOM_PROVIDER_1_API_KEY=...
```

### Features
```bash
# Token Optimization
ENABLE_RTK_TOKEN_SAVER=true        # 20-40% token savings
ENABLE_CAVEMAN_MODE=false          # 65% token savings (terse)

# Multi-Tenancy
ENABLE_MULTI_TENANT=true           # Workspace isolation
WORKSPACE_ISOLATION_STRICT=true    # Strict SQL filtering

# Request Logging
ENABLE_REQUEST_LOGS=true
DB_REQUEST_LOG_ENABLED=true
DB_REQUEST_LOG_RETENTION_DAYS=30

# API Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=1000       # Per IP per window
```

### Authentication
```bash
# JWT
JWT_SECRET=your-secret-key-change-this
JWT_EXPIRATION=7d
JWT_ALGORITHM=HS256

# Initial Admin
INITIAL_PASSWORD=admin123
INITIAL_EMAIL=admin@example.com

# OAuth (future)
GITHUB_OAUTH_ID=
GITHUB_OAUTH_SECRET=
```

### Monitoring
```bash
# Health Checks
ENABLE_HEALTH_CHECK=true
HEALTH_CHECK_INTERVAL=30000        # ms

# Logging
LOG_FORMAT=json                      # json or text
SENTRY_DSN=                         # Error tracking
DATADOG_ENABLED=false              # Datadog APM
```

## Configuration Files

### combos.json (Fallback Chains)

```json
{
  "combos": [
    {
      "id": "local-first",
      "name": "Local First",
      "tiers": [
        {
          "tier": 1,
          "provider": "ollama",
          "models": ["ollama/gemma", "ollama/qwen"],
          "priority": 1
        },
        {
          "tier": 2,
          "provider": "kiro",
          "models": ["kr/claude-opus-4.7"],
          "priority": 2
        }
      ]
    }
  ]
}
```

**Fields:**
- `id`: Unique combo identifier
- `name`: Display name
- `tiers`: Fallback chain (ordered by priority)
- `tier.provider`: Provider ID
- `tier.priority`: Fallback order (1=first)

### Provider Configuration Files

#### ollama-local.json
```json
{
  "provider": "ollama",
  "endpoint": "http://10.15.17.190:11434",
  "models": ["gemma", "qwen", "deepseek", "mistral", "llama"],
  "authRequired": false,
  "timeoutMs": 10000
}
```

#### free-providers.json
```json
{
  "provider": "free-tier",
  "providers": [
    {
      "id": "kiro",
      "endpoint": "https://api.kiro.ai/v1",
      "authRequired": true,
      "authType": "oauth"
    }
  ]
}
```

#### cheap-providers.json
```json
{
  "provider": "cheap-tier",
  "providers": [
    {
      "id": "glm",
      "costPer1k": 0.0006,
      "authRequired": true,
      "authType": "api-key"
    }
  ]
}
```

#### subscription-providers.json
```json
{
  "provider": "subscription-tier",
  "providers": [
    {
      "id": "openai",
      "endpoint": "https://api.openai.com/v1",
      "costPer1k": 0.03,
      "authRequired": true
    }
  ]
}
```

## Dashboard Configuration

### Adding a Provider

1. **Dashboard → Settings → Providers**
2. **Add Provider** button
3. **Select provider** from list
4. **Enter credentials** (API key or OAuth)
5. **Test connection**
6. **Save**

Provider config saved to PostgreSQL `provider_configs` table.

### Creating Custom Combos

1. **Dashboard → Settings → Combos**
2. **Create Combo**
3. **Name**: e.g., "My Custom Chain"
4. **Add tiers**: Select providers in order
5. **Set priorities**
6. **Save**

Combo saved to `custom_combos` table, available to workspace.

### Workspace Settings

1. **Dashboard → Workspace → Settings**
2. **Default Combo**: Select fallback chain
3. **Features**:
   - RTK Token Saver (on/off)
   - Request Logging (on/off)
   - Caveman Mode (on/off)
4. **Provider Isolation**: Local-only, cloud-only, or mixed
5. **Save**

## Advanced Configuration

### Custom Endpoints

Add arbitrary LLM provider:

```bash
# Environment variable
CUSTOM_PROVIDERS='[
  {
    "id": "internal-api",
    "endpoint": "http://internal-llm.company.local:8000",
    "type": "openai-compatible",
    "apiKey": "sk-internal-..."
  }
]'
```

Then use in combos:
```json
{
  "tier": 3,
  "provider": "internal-api",
  "models": ["internal/gpt"]
}
```

### Model Mapping

Override automatic model detection:

```json
// config/providers/model-mapping.json
{
  "mappings": {
    "gemma": {
      "cloud_equivalent": "kr/claude-sonnet-4.5",
      "context_window": 8192
    },
    "qwen": {
      "cloud_equivalent": "glm/glm-5.1",
      "context_window": 128000
    }
  }
}
```

### Request Transformations

Modify requests before sending:

```json
// config/transformations.json
{
  "transformations": [
    {
      "trigger": "model contains 'ollama'",
      "action": "set_max_tokens",
      "value": 2048
    },
    {
      "trigger": "provider is 'openai'",
      "action": "set_temperature",
      "value": 0.7
    }
  ]
}
```

### Rate Limiting Per Workspace

```bash
# Override global limits in workspace config
POST /api/workspaces/ws-001/settings
{
  "rate_limit": {
    "requests_per_minute": 100,
    "tokens_per_hour": 100000,
    "daily_cost_limit": 50
  }
}
```

## Environment Presets

### Development
```bash
# .env.local
NODE_ENV=development
LOG_LEVEL=debug
PORT=20128
DATABASE_URL=postgresql://9router:password123@localhost:5432/9router
JWT_SECRET=dev-secret-key
INITIAL_PASSWORD=admin123
ENABLE_RTK_TOKEN_SAVER=true
```

### Staging
```bash
# .env.staging
NODE_ENV=production
LOG_LEVEL=info
PORT=20128
DATABASE_URL=postgresql://9router:${SECURE_DB_PASSWORD}@postgres:5432/9router
JWT_SECRET=${SECURE_JWT_SECRET}
ENABLE_REQUEST_LOGS=true
DB_REQUEST_LOG_RETENTION_DAYS=7
```

### Production
```bash
# .env.prod
NODE_ENV=production
LOG_LEVEL=warn
PORT=20128
DATABASE_URL=postgresql://9router:${VAULT_DB_PASSWORD}@postgres.internal:5432/9router
JWT_SECRET=${VAULT_JWT_SECRET}
ENABLE_REQUEST_LOGS=true
DB_REQUEST_LOG_RETENTION_DAYS=90
RATE_LIMIT_MAX_REQUESTS=5000
SENTRY_DSN=${SENTRY_PROD_DSN}
```

## Validation

### Validate Configuration

```bash
# 9Router will validate on startup and report errors

# Common errors:
# - Invalid DATABASE_URL → PostgreSQL won't connect
# - Missing OLLAMA_ENDPOINT → Ollama routing disabled
# - Invalid JWT_SECRET → Auth fails
# - Port already in use → Server won't start
```

Check logs:
```bash
docker-compose logs 9router | grep -i error
```

## Secrets Management

### Development (Simple)
Store secrets in `.env.local` (not in version control).

### Staging/Production (Secure)
Use environment variable injection at deploy time:

```bash
# Docker run
docker run -e DATABASE_URL=$DB_URL -e JWT_SECRET=$JWT_SECRET ...

# Docker Compose
docker-compose --env-file secrets.env up -d

# Kubernetes
kubectl create secret generic 9router-secrets --from-literal=JWT_SECRET=...
```

### Vault Integration (Future)
```bash
# Load secrets from HashiCorp Vault
VAULT_ENABLED=true
VAULT_ADDR=https://vault.company.local
VAULT_TOKEN=${VAULT_TOKEN}
VAULT_SECRET_PATH=secret/9router/production
```

## Common Configurations

### All Local (Privacy)
```bash
ENABLE_OLLAMA_ROUTING=true
OLLAMA_ENABLED=true
# Don't configure cloud providers
```

### All Cloud (No Local)
```bash
OLLAMA_ENABLED=false
PROVIDERS_FREE_KIRO_ENABLED=true
PROVIDERS_FREE_OPENCODE_ENABLED=true
# Kiro acts as primary
```

### Hybrid (Local + Cloud)
```bash
ENABLE_OLLAMA_ROUTING=true
OLLAMA_ENABLED=true
PROVIDERS_FREE_KIRO_ENABLED=true
# Use local-first combo: Ollama → Kiro fallback
```

### Budget-Conscious
```bash
ENABLE_OLLAMA_ROUTING=true
OLLAMA_ENABLED=true
PROVIDERS_FREE_KIRO_ENABLED=true
GLM_API_KEY=${GLM_KEY}  # Cheap fallback
# Skip paid providers
```

### Enterprise
```bash
ENABLE_MULTI_TENANT=true
ENABLE_REQUEST_LOGS=true
OPENAI_API_KEY=${OPENAI_KEY}
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
SENTRY_DSN=${SENTRY_DSN}
# Full logging, multiple premium providers
```

## Troubleshooting Configuration

### Provider Not Working

```bash
# 1. Check if enabled in .env
grep PROVIDER_NAME .env.prod

# 2. Check if credentials configured in dashboard
# Dashboard → Providers → Check list

# 3. Test connectivity
curl -H "Authorization: Bearer ${API_KEY}" \
  http://localhost:20128/v1/models | grep provider_name

# 4. Check logs
docker-compose logs 9router | grep -i provider_name
```

### Model Not Available

```bash
# 1. Check if model in config
grep model_name config/providers/*.json

# 2. Check if provider has model
curl http://${PROVIDER_ENDPOINT}/v1/models

# 3. Check if workspace has provider enabled
curl -H "Authorization: Bearer ${API_KEY}" \
  http://localhost:20128/v1/models
```

### Performance Issues

```bash
# Check resource limits
OLLAMA_TIMEOUT_MS → Increase if timeouts
RATE_LIMIT_MAX_REQUESTS → Reduce if server overloaded
REDIS_KEY_PREFIX → Verify cache is working

# Monitor
docker stats 9router-app
docker-compose logs -f 9router
```

## References

- [Environment variables](../.env.example)
- [Provider configs](../config/providers/)
- [Database schema](../sql/schema.sql)
- [Combos](../config/combos.json)
