# Docker Deployment Guide

## Docker Compose Stack Overview

The `docker-compose.yml` orchestrates three main services:

```
┌─────────────────────────────────────────────┐
│         Docker Compose Network               │
├─────────────────────────────────────────────┤
│                                               │
│  ┌──────────────┐  ┌────────────┐  ┌──────┐ │
│  │  9router     │  │ PostgreSQL │  │ Redis│ │
│  │  :20128      │  │   :5432    │  │:6379 │ │
│  └──────────────┘  └────────────┘  └──────┘ │
│                                               │
│  Network: 9router_network (bridge)           │
└─────────────────────────────────────────────┘
         │
         └──> External: Ollama @ 10.15.17.190:11434
```

## Service Details

### 9Router Application
- **Image**: Built from `docker/Dockerfile`
- **Port**: 20128 (accessible on host)
- **Depends**: PostgreSQL, Redis (health check before start)
- **Volumes**: 
  - `./config` → `/app/config` (provider configs, hot-reload)
  - `./logs` → `/app/logs` (request/application logs)
- **Environment**: Injected from `.env.prod`
- **Health Check**: `curl http://localhost:20128/health`

### PostgreSQL
- **Image**: `postgres:15-alpine`
- **Port**: 5432
- **Volume**: `postgres_data` (persistent storage)
- **Init Scripts**:
  - `/docker-entrypoint-initdb.d/01-init.sql` (extensions)
  - `/docker-entrypoint-initdb.d/02-schema.sql` (tables, indexes)
- **Health Check**: `pg_isready` command
- **Credentials**: Read from environment (POSTGRES_PASSWORD)

### Redis
- **Image**: `redis:7-alpine`
- **Port**: 6379
- **Volume**: `redis_data` (persistent storage)
- **Append Only File (AOF)**: Enabled for durability
- **Health Check**: `redis-cli PING`

## Starting the Stack

### Option 1: Using Docker Desktop UI
1. Open Docker Desktop
2. Go to Containers
3. Navigate to `d:\9router` directory
4. Click "Compose Up"

### Option 2: Command Line
```bash
cd d:\9router

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### Option 3: PowerShell Script
```powershell
.\scripts\deploy.ps1
```

## Health Checks

### Check Service Status
```bash
# View all services
docker-compose ps

# Expected output:
# NAME           STATUS        PORTS
# 9router-app    running       0.0.0.0:20128->20128/tcp
# 9router-postgres running     0.0.0.0:5432->5432/tcp
# 9router-redis  running       0.0.0.0:6379->6379/tcp
```

### Test 9Router Health
```bash
curl http://localhost:20128/health

# Expected response:
# {
#   "status": "ok",
#   "services": {
#     "database": "connected",
#     "redis": "connected",
#     "ollama": "connected"
#   }
# }
```

### Test Database
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U 9router -d 9router

# Check tables
\dt

# Count users
SELECT COUNT(*) FROM users;

# Exit
\q
```

### Test Redis
```bash
# Connect to Redis
docker-compose exec redis redis-cli

# Test PING
PING

# Check keys
KEYS *

# Exit
exit
```

### Test Ollama Connectivity
```bash
# From host machine
curl http://10.15.17.190:11434/api/tags

# From 9router container
docker-compose exec 9router curl http://10.15.17.190:11434/api/tags
```

## Troubleshooting

### Service Won't Start

**PostgreSQL failing to start**
```bash
# Check logs
docker-compose logs postgres

# Common issues:
# - Port 5432 already in use → Change port mapping
# - Volume permission issue → Run docker-compose as admin
# - Previous failed init → Remove volume: docker volume rm 9router_postgres_data

# Full reset
docker-compose down -v
docker-compose up -d
```

**Redis failing to start**
```bash
# Check logs
docker-compose logs redis

# Check port
netstat -ano | findstr :6379

# If port in use, kill the process or change port in docker-compose.yml
```

**9Router not starting**
```bash
# Check logs
docker-compose logs 9router

# Wait for dependencies (may take 30s)
docker-compose logs -f 9router

# Check if database is ready
docker-compose exec postgres pg_isready -U 9router -d 9router
```

### Network Issues

**Can't reach Ollama from container**
```bash
# Test from host
ping 10.15.17.190

# Test from container
docker-compose exec 9router ping 10.15.17.190

# If fails, Ollama may be on different network
# Add to docker-compose.yml:
# extra_hosts:
#   - "ollama.local:10.15.17.190"
# Then use http://ollama.local:11434
```

### Viewing Logs

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs 9router
docker-compose logs postgres
docker-compose logs redis

# Follow logs (real-time)
docker-compose logs -f

# Last 50 lines
docker-compose logs --tail=50

# Timestamp included
docker-compose logs -t
```

## Updating Configuration

### Updating .env Variables
```bash
# Edit .env.prod
nano .env.prod

# Restart 9router to apply changes
docker-compose restart 9router

# Or full restart
docker-compose down
docker-compose up -d
```

### Updating Provider Configs
```bash
# Edit config files
nano config/providers/ollama-local.json

# Changes apply automatically (hot-reload) or restart:
docker-compose restart 9router
```

### Updating Database Schema
```bash
# Edit sql/schema.sql
nano sql/schema.sql

# Connect to database and run new migrations
docker-compose exec postgres psql -U 9router -d 9router -f /path/to/migration.sql

# Or use application migration system (if implemented)
```

## Data Persistence

### Backup

**PostgreSQL Backup**
```bash
# Dump database
docker-compose exec postgres pg_dump -U 9router 9router > backup.sql

# Compressed backup
docker-compose exec postgres pg_dump -U 9router 9router | gzip > backup.sql.gz
```

**Redis Backup**
```bash
# Copy RDB file
docker cp 9router-redis:/data/dump.rdb ./redis-backup.rdb
```

**Complete Backup**
```bash
# Stop services
docker-compose down

# Copy volumes
docker run --rm -v 9router_postgres_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres_backup.tar.gz -C /data .

# Restart services
docker-compose up -d
```

### Restore

**PostgreSQL Restore**
```bash
# Create empty database
docker-compose exec postgres createdb -U 9router 9router

# Restore from backup
docker-compose exec -T postgres psql -U 9router 9router < backup.sql
```

**Wipe and Reset (Development Only)**
```bash
# Remove all data
docker-compose down -v

# Restart (will reinitialize)
docker-compose up -d
```

## Development vs Production

### Development (.env.local)
```bash
NODE_ENV=development
LOG_LEVEL=debug
DATABASE_URL=postgresql://9router:password123@localhost:5432/9router
INITIAL_PASSWORD=admin123
JWT_SECRET=dev-secret-key
```
- Quick restart for testing
- Verbose logging
- Local Ollama access
- Basic security

### Production (.env.prod)
```bash
NODE_ENV=production
LOG_LEVEL=info
DATABASE_URL=postgresql://9router:${SECURE_PASSWORD}@postgres:5432/9router
INITIAL_PASSWORD=${SECURE_PASSWORD}
JWT_SECRET=${SECURE_JWT_SECRET}
```
- Optimized performance
- Error reporting
- Secure credentials (injected via environment)
- Full security features
- Automatic restarts
- Health checks enabled

## Scaling

### Single Node (Current)
- One 9router container
- One PostgreSQL container
- One Redis container
- Handles ~100-200 requests/second

### Multi-Node (Future)
```yaml
# Multiple 9router instances
9router-1:
  # ...
9router-2:
  # ...

# Load balancer (NGINX, HAProxy, or cloud LB)
nginx:
  ports:
    - "20128:20128"
  upstream 9router_pool:
    server 9router-1:20128
    server 9router-2:20128
```

## Monitoring

### CPU & Memory Usage
```bash
# Docker stats (real-time)
docker stats 9router-app 9router-postgres 9router-redis

# Or
docker-compose stats
```

### Database Connections
```bash
docker-compose exec postgres psql -U 9router -d 9router \
  -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"
```

### Redis Memory Usage
```bash
docker-compose exec redis redis-cli INFO memory
```

## Advanced Configuration

### Custom Networks
```yaml
networks:
  9router_network:
    driver: bridge
    driver_opts:
      com.docker.network.driver.mtu: 1500
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Resource Limits
```yaml
services:
  9router:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

### Logging Configuration
```yaml
services:
  9router:
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "3"
```

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [Redis Docker Image](https://hub.docker.com/_/redis)
- [9Router Repository](https://github.com/decolua/9router)
