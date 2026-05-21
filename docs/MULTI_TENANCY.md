# Multi-Tenancy Architecture

## Overview

9Router supports multi-tenancy through organizational and workspace hierarchies. This allows teams to:

- ✅ Share one 9Router instance across multiple organizations
- ✅ Isolate workspaces per team/project
- ✅ Use different provider configurations per workspace
- ✅ Track usage and costs independently
- ✅ Control access with roles (admin, member, viewer)

## Data Hierarchy

```
Organization (Top Level)
├── Team A
│   ├── User 1 (admin)
│   ├── User 2 (member)
│   └── Workspace: "Production"
│       ├── Provider Config: Ollama + Kiro
│       ├── Custom Combos
│       └── Request Logs
└── Team B
    ├── User 3 (admin)
    └── Workspace: "Development"
        ├── Provider Config: Local-only
        └── Request Logs
```

## Components

### Organizations
- Top-level container for multi-tenancy
- Contains multiple users and workspaces
- Isolated from other organizations
- Database table: `organizations`

Example:
```json
{
  "id": "org-abc-123",
  "name": "My Company",
  "slug": "my-company",
  "description": "Main organization"
}
```

### Users
- Belong to exactly one organization
- Can access multiple workspaces within their org
- Roles: admin, member, viewer
- Database table: `users`

Example:
```json
{
  "id": "user-xyz-789",
  "org_id": "org-abc-123",
  "email": "alice@company.com",
  "full_name": "Alice Smith",
  "is_admin": true
}
```

### Workspaces
- Sub-organization within an organization
- Isolated request logs, usage tracking, provider configs
- Can have multiple workspace members
- Database table: `workspaces`

Example:
```json
{
  "id": "ws-001",
  "org_id": "org-abc-123",
  "name": "Production",
  "slug": "production",
  "default_combo": "local-first"
}
```

### Workspace Members
- Links users to workspaces
- Defines role (admin, member, viewer) per workspace
- Database table: `workspace_members`

## API Integration

### Workspace Selection in API Requests

**Option 1: Header-based (Recommended)**
```bash
curl -X POST http://localhost:20128/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "X-Workspace-ID: ws-001" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ollama/qwen",
    "messages": [...]
  }'
```

**Option 2: API Key bound to workspace (Simpler)**
```bash
# Generate API key in dashboard, it's already bound to workspace
curl -X POST http://localhost:20128/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ollama/qwen",
    "messages": [...]
  }'
# X-Workspace-ID is read from API key metadata
```

### List Models (Workspace-specific)
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:20128/v1/models

# Returns only models available for that API key's workspace
# Including workspace-specific provider configurations
```

## Workspace Configuration

### Workspace Settings

Each workspace has independent configuration:

```json
{
  "workspace_id": "ws-001",
  "name": "Production",
  "default_combo": "local-first",
  "settings": {
    "rtk_token_saver": true,
    "caveman_mode": false,
    "request_logging": true,
    "request_log_retention_days": 30
  },
  "providers": {
    "ollama": {
      "enabled": true,
      "priority": 1
    },
    "kiro": {
      "enabled": true,
      "priority": 2,
      "credentials": "workspace-specific"
    }
  }
}
```

### Workspace-Specific Combos

Create custom fallback chains per workspace:

```
Workspace: "Production"
└── Combo: "always-on"
    1. Ollama (priority 1)
    2. OpenAI GPT-5.5 (priority 2)
    3. Claude Opus (priority 3)
    4. GLM (priority 4)
    5. Kiro (priority 5)

Workspace: "Development"
└── Combo: "local-first"
    1. Ollama (priority 1)
    2. Kiro (priority 2)
    3. GLM (priority 3)
```

## Access Control

### Roles

**Admin**
- Manage workspace (settings, providers, combos)
- Add/remove workspace members
- View all logs and analytics
- Delete workspace

**Member**
- Use providers and models
- Generate API keys (personal)
- View own usage logs
- Cannot modify workspace settings

**Viewer**
- Read-only access
- View analytics and logs
- Cannot generate API keys
- Cannot use API (view-only dashboard)

### Role-Based Access Control (RBAC)

```
POST /workspaces/ws-001/providers
  → Requires: admin role
  → Creates or updates provider config

GET /workspaces/ws-001/analytics
  → Requires: admin or member role
  → Returns workspace-specific data

POST /api-keys
  → Requires: authenticated user
  → Creates personal API key (bound to user's workspace)
```

## Database Schema

### Key Tables

```sql
-- Organizations
CREATE TABLE organizations (
  id UUID PRIMARY KEY,
  name VARCHAR(255),
  slug VARCHAR(255) UNIQUE,
  created_at TIMESTAMP
);

-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY,
  org_id UUID REFERENCES organizations(id),
  email VARCHAR(255),
  is_admin BOOLEAN,
  UNIQUE(org_id, email)
);

-- Workspaces
CREATE TABLE workspaces (
  id UUID PRIMARY KEY,
  org_id UUID REFERENCES organizations(id),
  name VARCHAR(255),
  slug VARCHAR(255),
  default_combo VARCHAR(255),
  UNIQUE(org_id, slug)
);

-- Workspace Members
CREATE TABLE workspace_members (
  id UUID PRIMARY KEY,
  workspace_id UUID REFERENCES workspaces(id),
  user_id UUID REFERENCES users(id),
  role VARCHAR(50), -- admin, member, viewer
  UNIQUE(workspace_id, user_id)
);

-- API Keys (bound to workspace)
CREATE TABLE api_keys (
  id UUID PRIMARY KEY,
  workspace_id UUID REFERENCES workspaces(id),
  key_hash VARCHAR(255),
  created_by UUID REFERENCES users(id)
);

-- Request Logs (workspace-isolated)
CREATE TABLE request_logs (
  id UUID PRIMARY KEY,
  workspace_id UUID REFERENCES workspaces(id),
  api_key_id UUID REFERENCES api_keys(id),
  model VARCHAR(255),
  provider_used VARCHAR(255),
  tokens INT,
  created_at TIMESTAMP
);
```

### Isolation Guarantees

- All queries filtered by `workspace_id`
- No user can access data outside their workspaces
- API keys bound to single workspace
- Request logs never leak across workspaces

## Setup Guide

### 1. Create Organization

```bash
# Via Dashboard → Settings → Organization
# Or via API (admin only)

POST /api/organizations
{
  "name": "Acme Corp",
  "slug": "acme-corp"
}
```

### 2. Create Users

```bash
# Via Dashboard → Settings → Users
# Or invite via email

POST /api/users
{
  "email": "alice@acme.com",
  "full_name": "Alice Smith",
  "is_admin": false
}
```

### 3. Create Workspaces

```bash
# Via Dashboard → Create Workspace
# Or via API

POST /api/workspaces
{
  "name": "Production",
  "slug": "production",
  "default_combo": "local-first"
}
```

### 4. Add Workspace Members

```bash
# Via Dashboard → Workspace → Members
# Or via API

POST /api/workspaces/ws-001/members
{
  "user_id": "user-xyz",
  "role": "member"
}
```

### 5. Configure Providers

```bash
# Via Dashboard → Workspace → Providers
# Or via API

POST /api/workspaces/ws-001/providers
{
  "provider_id": "kiro",
  "credentials": {
    "api_key": "sk-..."
  },
  "enabled": true
}
```

### 6. Generate API Keys

```bash
# Via Dashboard → API Keys → New Key
# Or via API

POST /api/api-keys
{
  "name": "Production API",
  "workspace_id": "ws-001",
  "expires_in_days": 90
}

# Returns: sk-1234567890abcdef... (one-time display)
```

## Usage Examples

### Multiple Teams in One Organization

```
Organization: DevOps Team
├── Workspace: "Staging"
│   ├── Members: Bob (admin), Carol (member)
│   ├── Providers: Ollama + GLM (budget)
│   └── Combo: "cloud-backup"
│
└── Workspace: "Production"
    ├── Members: Bob (admin), Diana (admin)
    ├── Providers: Ollama + OpenAI (premium)
    └── Combo: "always-on"
```

Each workspace is completely isolated:
- Different API keys
- Different provider configs
- Different usage limits
- Separate analytics

### Multi-Organization Setup

```
9Router Instance (Single)
├── Organization: "Company A"
│   └── Workspace: "Default"
│       └── Provider: Local Ollama + Kiro
│
├── Organization: "Company B"
│   ├── Workspace: "Development"
│   └── Workspace: "Production"
│       └── Providers: OpenAI + Anthropic
│
└── Organization: "Startup C"
    └── Workspace: "R&D"
        └── Provider: Vertex AI (free tier)
```

Each organization completely isolated:
- No data sharing
- No cross-organization API calls
- Separate users and admin panels
- Independent usage tracking

## Workspace Isolation Testing

### SQL Queries to Verify Isolation

```sql
-- User can only see their organization's data
SELECT * FROM workspaces WHERE org_id IN (
  SELECT org_id FROM users WHERE id = 'current-user'
);

-- Workspace members cannot see other workspaces' logs
SELECT * FROM request_logs 
WHERE workspace_id IN (
  SELECT workspace_id FROM workspace_members 
  WHERE user_id = 'current-user'
);

-- API key only grants access to bound workspace
SELECT workspace_id FROM api_keys WHERE key_hash = 'hash-of-api-key';
```

## Performance Considerations

### Indexing
- `workspaces(org_id)` for org lookup
- `workspace_members(workspace_id, user_id)` for access control
- `request_logs(workspace_id, created_at)` for log queries
- `api_keys(key_hash)` for authentication

### Query Optimization
- All queries include `WHERE workspace_id = $1` for partition pruning
- Redis caches workspace settings (TTL: 5 min)
- Model list cached per workspace (TTL: 24h)

### Scalability
- Single 9Router handles 100+ workspaces
- PostgreSQL scales to millions of request logs
- Partition logs by date if needed (future enhancement)

## Future Enhancements

1. **Sub-workspaces**: Teams within workspaces
2. **Cost Allocation**: Per-workspace billing
3. **Request Quotas**: Limit requests per workspace
4. **Data Residency**: Choose data location per workspace
5. **SSO Integration**: SAML/OAuth per organization
6. **Audit Logs**: Track all workspace changes

## References

- Database schema: [sql/schema.sql](../sql/schema.sql)
- API routes: 9Router source code
- Dashboard workflows: Web interface

## Support

For multi-tenancy questions:
- See [README.md](../README.md)
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Review database schema in [sql/schema.sql](../sql/schema.sql)
