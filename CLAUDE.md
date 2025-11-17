# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FastAPI microservice for social features including friendships, blocking, favorites, profile views, and user search. Part of the Activity platform's microservices architecture.

**Key Stats:**
- 21 REST API endpoints across 5 feature domains
- 22 PostgreSQL stored procedures
- JWT-based authentication
- Redis rate limiting
- Connection pooling (psycopg3)
- Deployed on port 8005

## Architecture Pattern

This API follows a **stored procedure-first architecture**:

```
API Routes → Service Layer → PostgreSQL Stored Procedures → Database
```

**Critical Rule:** ALL database operations MUST go through stored procedures in the `activity` schema. Never write raw SQL queries or use ORMs for business logic.

### Data Flow Example
```python
# Route (app/routes/friendships.py)
→ POST /social/friends/request
  ↓
# Service (app/services/friendship_service.py)
→ FriendshipService.send_friend_request()
  ↓
# Database (sql/01_stored_procedures_friendships.sql)
→ activity.sp_social_send_friend_request()
  ↓
# Returns JSONB directly to client
```

## Development Commands

### Docker Operations (Recommended)
```bash
# IMPORTANT: Always rebuild after code changes
docker compose build --no-cache
docker compose up -d

# View logs
docker compose logs -f social-api

# Restart after changes
docker compose restart social-api

# Check health
curl http://localhost:8005/health

# Stop services
docker compose down
```

### Local Development
```bash
# Install dependencies
pip install -r requirements.txt

# Run server (requires .env file)
uvicorn app.main:app --reload --port 8005

# Run single test
pytest tests/test_friendships.py::test_send_friend_request_success -v

# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=html
```

### Database Operations
```bash
# Deploy stored procedures manually
docker compose exec activity-postgres-db psql -U postgres -d activitydb -f /sql/01_stored_procedures_friendships.sql

# Verify stored procedures exist (should show 22)
docker compose exec activity-postgres-db psql -U postgres -d activitydb -c "\df activity.sp_social_*"

# Test database connection
docker compose exec activity-postgres-db psql -U postgres -d activitydb -c "SELECT 1;"

# Check connection pool status
docker compose exec social-api python -c "from app.utils.database import pool; print(pool.get_stats())"
```

## Central Infrastructure

This API uses **shared external resources**:

**Database:** `activity-postgres-db` container
- Host: `activity-postgres-db:5432`
- Database: `activitydb`
- Schema: `activity`
- User: `postgres`
- Pool: 5-20 connections (configured in docker-compose.yml)

**Redis:** `auth-redis` container
- Host: `auth-redis:6379`
- Database: 0
- Used for: Rate limiting via slowapi

**Network:** `activity-network` (external)
- Must exist before starting this service
- Shared with auth-api, moderation-api, community-api, participation-api

**Port Mapping:**
- auth-api: 8000
- moderation-api: 8002
- community-api: 8003
- participation-api: 8004
- **social-api: 8005** ← This service

## Service Layer Pattern

All services follow this exact pattern:

```python
class ServiceName:
    def method_name(self, param1: str, param2: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_name(%s, %s)",
                    (param1, param2)
                )
                result = cursor.fetchone()[0]
                conn.commit()  # For write operations
                return result
```

**Key Points:**
1. Context manager handles connection pooling automatically
2. Stored procedures return JSONB - we return it directly
3. `conn.commit()` required for INSERT/UPDATE/DELETE operations
4. No manual error handling - let stored procedures raise exceptions
5. Never use `execute_values()` or `executemany()` - stored procedures handle batching

## Error Handling Strategy

**Stored Procedures First:**
All business logic errors are raised in stored procedures with format:
```sql
RAISE EXCEPTION 'ERROR_CODE: Description';
```

**API Layer:**
Routes catch exceptions and use `create_error_response(e, status_code)`:
```python
try:
    result = service.method()
    return result
except Exception as e:
    if "PREMIUM_REQUIRED" in str(e):
        return create_error_response(e, 403)
    return create_error_response(e, 400)
```

**Common Error Codes from Stored Procedures:**
- `SELF_FRIEND_ERROR` - Cannot friend yourself
- `USER_NOT_FOUND` - Target user doesn't exist
- `FRIENDSHIP_EXISTS` - Already friends/pending
- `BLOCKED_BY_USER` - You're blocked by target
- `PREMIUM_REQUIRED` - Feature requires premium subscription
- `ALREADY_BLOCKED` - User already blocked

## JWT Authentication

All endpoints (except `/health`) require JWT bearer token:

```python
from app.core.security import get_current_user

@router.get("/endpoint")
async def endpoint(current_user: Dict = Depends(get_current_user)):
    user_id = current_user["user_id"]           # UUID
    email = current_user["email"]               # string
    subscription = current_user["subscription_level"]  # free/premium/club
    ghost_mode = current_user["ghost_mode"]     # boolean
```

**JWT Claims Required:**
- `sub`: user_id (UUID)
- `email`: user email
- `subscription_level`: free/premium/club (default: free)
- `ghost_mode`: boolean (default: false)

**Testing Authentication:**
See `tests/conftest.py` for mock authentication in tests.

## Rate Limiting

Applied via `slowapi` with Redis backend:

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/endpoint")
@limiter.limit("20/minute")  # 20 requests per minute per IP
async def endpoint():
    pass
```

**Rate Limit Guidelines:**
- Write operations: 10-30/minute
- Read operations: 60-100/minute
- Status checks: 100/minute
- Profile views: 100/minute (high frequency expected)

## Feature-Specific Patterns

### Friendships (8 endpoints)
**Bidirectional storage:** Friendships stored with `user_id_1 < user_id_2` constraint.
```python
# Always normalize user IDs in stored procedures:
IF p_user_id_1 < p_user_id_2 THEN
    v_user_id_1 := p_user_id_1;
    v_user_id_2 := p_user_id_2;
ELSE
    v_user_id_1 := p_user_id_2;
    v_user_id_2 := p_user_id_1;
END IF;
```

### Blocking (5 endpoints)
**XXL Exception:** Blocking does NOT apply to XXL activities:
```python
# Endpoint: GET /social/blocks/can-interact/{target_user_id}?activity_type=xxl
# Returns: {"can_interact": true, "reason": "xxl_exception"}
```

### Favorites (5 endpoints)
**Premium Features:**
- `GET /social/favorites/who-favorited-me` requires premium/club subscription
- Returns 403 if user is free tier
- Stored procedure checks: `IF p_subscription_level NOT IN ('premium', 'club') THEN RAISE EXCEPTION 'PREMIUM_REQUIRED'`

### Profile Views (3 endpoints)
**Ghost Mode:**
- Profile views respect `ghost_mode` from JWT
- When `ghost_mode=true`, view is tracked in memory but NOT stored in database
- Stored procedure returns success but doesn't INSERT
- Premium feature: `GET /social/profile-views/who-viewed-me`

### User Search (1 endpoint)
**Search Requirements:**
- Minimum 2 characters: `q: str = Query(..., min_length=2, max_length=100)`
- Returns max 50 results per page
- Excludes blocked users automatically
- Uses PostgreSQL full-text search in stored procedure

## Database Schema Assumptions

The stored procedures expect these tables in the `activity` schema:

**friendships:**
- user_id_1 (UUID) - Always smaller UUID
- user_id_2 (UUID) - Always larger UUID
- status (TEXT) - 'pending' or 'accepted'
- initiated_by (UUID) - Who sent the request
- created_at, accepted_at, updated_at (TIMESTAMP)

**user_blocks:**
- blocker_user_id (UUID)
- blocked_user_id (UUID)
- created_at (TIMESTAMP)
- reason (TEXT, nullable)

**user_favorites:**
- favoriting_user_id (UUID)
- favorited_user_id (UUID)
- created_at (TIMESTAMP)

**profile_views:**
- viewer_user_id (UUID)
- viewed_user_id (UUID)
- created_at (TIMESTAMP)

**users:**
- user_id (UUID)
- username, first_name, last_name
- main_photo_url
- is_verified
- subscription_level
- ghost_mode

## Common Issues & Solutions

### Issue: Database connection fails
```bash
# Check if external network exists
docker network ls | grep activity-network

# Create if missing
docker network create activity-network

# Verify database is running
docker ps | grep activity-postgres-db
```

### Issue: Code changes not reflected
```bash
# Docker caches old images - ALWAYS rebuild
docker compose build --no-cache
docker compose restart social-api
```

### Issue: Stored procedures not found
```bash
# Deploy manually (in order)
for file in sql/*.sql; do
    docker compose exec activity-postgres-db psql -U postgres -d activitydb -f /$file
done

# Verify deployment
docker compose exec activity-postgres-db psql -U postgres -d activitydb -c "\df activity.sp_social_*"
```

### Issue: Rate limiting not working
```bash
# Check Redis connection
docker compose exec auth-redis redis-cli ping
# Should return: PONG

# Check Redis in use
docker compose exec auth-redis redis-cli KEYS "*"
```

### Issue: JWT authentication fails
- Verify `JWT_SECRET_KEY` matches auth-api
- Check token expiration (auth-api controls token lifetime)
- Validate token structure at jwt.io
- Ensure Authorization header format: `Bearer <token>`

## File Organization

```
app/
├── core/
│   ├── logging_config.py     # Structlog JSON logging setup
│   ├── security.py            # JWT validation & user extraction
│   └── exceptions.py          # Custom exception classes
├── middleware/
│   └── correlation.py         # Request correlation IDs
├── routes/                    # FastAPI route handlers
│   ├── health.py              # Health check endpoint
│   ├── friendships.py         # 8 friendship endpoints
│   ├── blocks.py              # 5 blocking endpoints
│   ├── favorites.py           # 5 favorite endpoints
│   ├── profile_views.py       # 3 profile view endpoints
│   └── user_search.py         # 1 search endpoint
├── services/                  # Business logic → stored procedures
│   ├── friendship_service.py
│   ├── block_service.py
│   ├── favorite_service.py
│   ├── profile_view_service.py
│   └── user_search_service.py
├── models/
│   ├── requests.py            # Pydantic request schemas
│   └── responses.py           # Pydantic response schemas
├── utils/
│   ├── database.py            # Connection pool management
│   ├── auth.py                # Auth helper functions
│   └── errors.py              # Error response formatter
├── config.py                  # Pydantic settings
└── main.py                    # FastAPI application

sql/
├── 01_stored_procedures_friendships.sql   # 8 procedures
├── 02_stored_procedures_blocks.sql        # 5 procedures
├── 03_stored_procedures_favorites.sql     # 5 procedures
├── 04_stored_procedures_profile_views.sql # 3 procedures
└── 05_stored_procedures_user_search.sql   # 1 procedure

tests/
├── conftest.py                # Pytest fixtures & auth mocking
└── test_friendships.py        # Example tests
```

## API Documentation

When service is running:
- **Swagger UI:** http://localhost:8005/docs
- **ReDoc:** http://localhost:8005/redoc

Both provide interactive API testing with authentication support.

## Logging

Uses `structlog` with environment-aware formatting:

**Development:** Console output with colors
```python
logger.info("event_name", user_id=user_id, extra="data")
```

**Production:** JSON output for log aggregation
```json
{"event": "event_name", "user_id": "...", "extra": "data", "timestamp": "..."}
```

**Log levels:** INFO (default), DEBUG, WARNING, ERROR
Configured via `LOG_LEVEL` environment variable.

## Environment Variables

Required variables (no defaults):
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET_KEY` - Must match auth-api secret

Variables with defaults:
- `DATABASE_POOL_MIN_SIZE=5`
- `DATABASE_POOL_MAX_SIZE=20`
- `JWT_ALGORITHM=HS256`
- `REDIS_URL=redis://auth-redis:6379/0`
- `API_HOST=0.0.0.0`
- `API_PORT=8000`
- `ENVIRONMENT=development`
- `CORS_ORIGINS=["http://localhost:3000"]`
- `LOG_LEVEL=INFO`

See `.env.example` for reference configuration.

## Testing Strategy

**Mock authentication** in all tests via `conftest.py`:
```python
app.dependency_overrides[get_current_user] = override_get_current_user
```

**Test database operations:**
- Use dedicated test database or transactions
- Stored procedures should have unit tests in PostgreSQL
- API tests focus on route behavior and error handling

**Run specific test:**
```bash
pytest tests/test_friendships.py::test_send_friend_request_success -v -s
```

## Adding New Features

1. **Create stored procedure** in appropriate `sql/*.sql` file
2. **Add service method** following the connection pool pattern
3. **Create route handler** with proper rate limiting
4. **Define Pydantic models** for request/response
5. **Update main.py** to include new router
6. **Write tests** with mocked authentication
7. **Deploy stored procedure** to database
8. **Restart service** with rebuild

Example workflow:
```bash
# 1. Edit sql/06_new_feature.sql
# 2. Edit app/services/new_service.py
# 3. Edit app/routes/new_route.py
# 4. Edit app/main.py to include router

# 5. Deploy changes
docker compose build --no-cache
docker compose down
docker compose up -d

# 6. Verify
curl http://localhost:8005/docs
```

## Performance Considerations

**Connection Pooling:**
- Min 5 connections, max 20 connections
- 30-second timeout for acquiring connection
- Connections automatically returned to pool via context manager

**Query Optimization:**
- All queries in stored procedures should use indexes
- Use `LIMIT` and `OFFSET` for pagination
- Avoid N+1 queries - stored procedures return complete objects

**Rate Limiting:**
- Redis-backed prevents distributed system abuse
- Per-IP limiting may need adjustment for proxies
- Consider per-user limiting for authenticated endpoints

**Caching Strategy:**
- No application-level caching (stateless)
- Consider Redis caching for expensive queries
- Profile view counts are aggregated in stored procedures
