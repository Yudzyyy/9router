# Ollama Integration Guide

## Overview

9Router integrates with local Ollama at `10.15.17.190:11434` as the **primary LLM provider**. This guide explains how routing works, health checks, and troubleshooting.

## Ollama Configuration

### Endpoint
```
http://10.15.17.190:11434
```

### Available Models
```
- gemma       (lightweight, fast)
- qwen        (balanced quality/speed)
- deepseek    (specialized tasks)
- mistral     (open source, high quality)
- llama       (flagship model)
```

### Environment Variables
```bash
# In .env.prod or .env.local
OLLAMA_ENDPOINT=http://10.15.17.190:11434
OLLAMA_ENABLED=true
OLLAMA_MODELS=gemma,qwen,deepseek,mistral,llama
OLLAMA_TIMEOUT_MS=10000              # Request timeout
ENABLE_OLLAMA_ROUTING=true           # Enable local-first routing
```

## Routing Logic

### Smart Model Routing
9Router routes requests based on model availability:

```
User Request: "Use model X"
                 │
                 ↓
        Is "X" available on Ollama?
                 │
        ┌────────┴────────┐
        │                 │
       YES               NO
        │                 │
        ↓                 ↓
    Use Ollama    Check cloud providers
   (fast, free)   (Kiro → GLM → etc)
        │                 │
        └────────┬────────┘
                 ↓
          Return result
```

### Combo-Based Routing
Each combo defines a fallback chain:

**`local-first` (default)**
```
1. Ollama (gemma, qwen, deepseek, mistral, llama)
   ↓ if unavailable
2. Kiro (Claude, GLM, MiniMax free)
   ↓ if unavailable
3. GLM (cheap backup)
```

**`local-only` (privacy)**
```
1. Ollama ONLY (fails if unavailable)
```

**`always-on` (reliability)**
```
1. Ollama
2. OpenAI (GPT-5.5)
3. Anthropic (Claude)
4. GLM
5. Kiro
```

## Health Checks

### Automatic Ollama Health Monitoring
9Router performs automatic health checks every 60 seconds:

```bash
GET http://10.15.17.190:11434/api/tags
```

**Response (healthy)**
```json
{
  "models": [
    { "name": "gemma:latest", ... },
    { "name": "qwen:latest", ... },
    ...
  ]
}
```

**Health Check Interval**: 60 seconds  
**Timeout**: 10 seconds  
**Failure Threshold**: 3 consecutive failures before marking down

### Checking Ollama Status
```bash
# From host machine
curl http://10.15.17.190:11434/api/tags

# From 9router container
docker-compose exec 9router curl http://10.15.17.190:11434/api/tags

# From dashboard
Dashboard → Providers → Ollama (shows status + latency + available models)
```

## API Usage

### Request Models by Source

**Use specific Ollama model**
```bash
curl -X POST http://localhost:20128/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ollama/qwen",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

**Let router choose (smart routing)**
```bash
# Request without "ollama/" prefix
# Router checks availability:
# 1. If qwen exists on Ollama → use Ollama
# 2. Else try cloud providers
curl -X POST http://localhost:20128/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### List Available Models
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:20128/v1/models

# Response includes:
# - Ollama models: "ollama/gemma", "ollama/qwen", etc
# - Cloud models: "kr/claude-opus-4.7", "glm/glm-5.1", etc
# - Model capabilities: context window, cost, latency estimates
```

## Workspace-Specific Configuration

### Per-Workspace Combo Selection
Each workspace can have different routing preferences:

```
Organization: My Company
├── Workspace 1: "Privacy First"
│   └── Combo: "local-only" (Ollama only, no cloud)
│
├── Workspace 2: "Cost Optimized"
│   └── Combo: "local-first" (Ollama → Kiro → GLM)
│
└── Workspace 3: "Always Available"
    └── Combo: "always-on" (5-tier fallback)
```

### Dashboard Configuration
```
1. Dashboard → Settings → Workspace
2. Select "Ollama Routing"
3. Choose combo: local-first, local-only, cloud-backup, etc
4. Apply and restart 9router
```

## Request Logging

### Routing Path Tracking
Every request logs which providers were tried:

```sql
SELECT 
  model,
  provider_used,
  routing_path,
  latency_ms,
  status_code
FROM request_logs
WHERE workspace_id = 'abc-123'
ORDER BY created_at DESC;

-- Example routing_path:
-- "ollama/qwen → (200ms, OK)"
-- "ollama/unknown → failed → kr/claude → (1200ms, OK)"
-- "ollama → down → glm → (2100ms, OK)"
```

## Performance Optimization

### Model Caching
Available models from Ollama cached in Redis:

```
Ollama models cache TTL: 5 minutes
Cloud models cache TTL: 24 hours
```

When cache expires, 9router refreshes model list.

### Request Optimization
```bash
# RTK Token Saver (enabled by default)
ENABLE_RTK_TOKEN_SAVER=true
# Saves 20-40% tokens on tool outputs

# Caveman Mode (optional)
ENABLE_CAVEMAN_MODE=false
# Saves 65% output tokens (terse responses)
```

## Troubleshooting

### Ollama Not Reachable

**Problem**: Can't connect to 10.15.17.190:11434

**Diagnosis**
```bash
# Test from host machine
ping 10.15.17.190
curl http://10.15.17.190:11434/api/tags

# Test from container
docker-compose exec 9router ping 10.15.17.190
docker-compose exec 9router curl http://10.15.17.190:11434/api/tags

# Check 9router logs
docker-compose logs 9router | grep -i ollama
```

**Solutions**
1. Verify Ollama is running: `ollama serve`
2. Check firewall allows 10.15.17.190:11434
3. Verify network connectivity (VPN, same subnet)
4. Restart Ollama service
5. Check Ollama logs: `ollama logs`

### Slow Ollama Response

**Problem**: Ollama requests taking >5 seconds

**Diagnosis**
```bash
# Check Ollama latency
time curl http://10.15.17.190:11434/api/tags

# Monitor server resources
# CPU, memory, disk I/O on Ollama host
# Check for other processes using GPU

# Check 9router logs
docker-compose logs 9router | grep latency_ms
```

**Solutions**
1. Check Ollama host CPU/memory/GPU usage
2. Reduce loaded models (unload unused)
3. Check network latency: `ping -t 10.15.17.190`
4. Reduce OLLAMA_TIMEOUT_MS if timeouts frequent
5. Consider moving Ollama to local machine (lower latency)

### Model Not Found

**Problem**: Request for "ollama/gemma" returns 404

**Diagnosis**
```bash
# List available Ollama models
curl http://10.15.17.190:11434/api/tags

# Check model name exactly
# (Ollama may use "gemma:latest", "gemma:7b", etc)

# Check model config in 9router
cat config/providers/ollama-local.json | grep -i gemma
```

**Solutions**
1. Pull missing model: `ollama pull gemma`
2. Use correct model name (check API response)
3. Verify model is loaded: `ollama list`
4. Update `OLLAMA_MODELS` environment variable

### Fallback Chain Not Working

**Problem**: When Ollama is down, requests fail instead of falling back to cloud

**Diagnosis**
```bash
# Manually disable Ollama
docker-compose exec 9router curl http://10.15.17.190:11434/api/tags

# Make request and check routing
curl -X POST http://localhost:20128/v1/chat/completions \
  -H "Authorization: Bearer TOKEN" \
  -d '{"model": "qwen", ...}'

# Check logs
docker-compose logs 9router | grep -i fallback
docker-compose logs 9router | grep -i routing_path
```

**Solutions**
1. Verify combo configuration includes fallback (check combos.json)
2. Restart 9router: `docker-compose restart 9router`
3. Check cloud provider credentials are configured
4. Ensure cloud provider isn't also failing
5. Review health check status in dashboard

## Model Mapping

### Ollama ↔ Cloud Equivalents
When routing to cloud fallback, 9router maps models:

```
ollama/gemma     → Closest cloud equivalent
ollama/qwen      → GLM-5 or OpenCode equivalent
ollama/mistral   → GPT-4 or Claude equivalent
ollama/llama     → Claude Opus equivalent
```

Configure mapping in `config/providers/model-mapping.json` (if needed).

## Monitoring & Analytics

### Dashboard Analytics
```
Dashboard → Analytics
├── Requests by Provider (Ollama vs cloud split)
├── Average Latency (Ollama vs cloud)
├── Cost Analysis (local $0 vs cloud cost)
├── Model Usage Distribution
└── Fallback Chain Activation Rate
```

### Query Request Logs
```sql
-- Ollama usage percentage
SELECT 
  provider_used,
  COUNT(*) as requests,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM request_logs), 2) as percentage
FROM request_logs
GROUP BY provider_used
ORDER BY requests DESC;

-- Ollama latency
SELECT 
  model,
  AVG(latency_ms) as avg_latency,
  MIN(latency_ms) as min_latency,
  MAX(latency_ms) as max_latency,
  COUNT(*) as requests
FROM request_logs
WHERE provider_used = 'ollama'
GROUP BY model;
```

## Advanced Configuration

### Custom Ollama Endpoint
```bash
# If Ollama is at different address
OLLAMA_ENDPOINT=http://ollama.company.local:11434
# or
OLLAMA_ENDPOINT=http://192.168.1.100:11434
```

### Model Blacklist/Whitelist
```bash
# Only use specific models from Ollama
OLLAMA_MODELS=gemma,qwen

# Block problematic models
OLLAMA_MODELS_BLACKLIST=deepseek
```

### Custom Health Check
```bash
# Override default health check interval
OLLAMA_HEALTH_CHECK_INTERVAL=30000  # 30 seconds

# Override timeout
OLLAMA_TIMEOUT_MS=5000  # 5 second timeout
```

## References

- [Ollama Documentation](https://ollama.ai/docs)
- [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Available Ollama Models](https://ollama.ai/library)

## Support

For Ollama-specific issues:
- [Ollama GitHub Issues](https://github.com/ollama/ollama/issues)
- [Ollama Discord Community](https://discord.gg/ollama)

For 9Router + Ollama integration issues:
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- [9Router GitHub Issues](https://github.com/decolua/9router/issues)
