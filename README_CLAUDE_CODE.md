# SOCIAL API - AI AGENT BUILD INSTRUCTIONS
**Complete Implementation Guide for Claude Code**

---

## 📋 DOCUMENT OVERVIEW

Deze instructies zijn specifiek ontworpen voor **Claude Code** (AI coding agent) om de Social API volledig te bouwen zonder menselijke tussenkomst.

### Bestanden in deze set:

1. **CLAUDE_CODE_INSTRUCTIONS_PART1.md** (Database + Core Setup)
   - Phase 0: Repository structuur
   - Phase 1: Database layer (22 stored procedures)
   - Phase 2: Core application (config, logging, security)
   - Phase 3: Pydantic models (request/response schemas)
   - Phase 4: Service layer (business logic)

2. **CLAUDE_CODE_INSTRUCTIONS_PART2.md** (API + Deployment)
   - Phase 5: API routes (21 endpoints)
   - Phase 6: Main application setup
   - Phase 7: Docker & Docker Compose
   - Phase 8: Testing framework
   - Phase 9: Documentation & deployment

---

## 🎯 VOOR CLAUDE CODE

**Start hier**: Begin met PART 1, werk sequentieel door alle phases.

**Belangrijke principes**:
- Volg de volgorde EXACT (Phase 0 → 1 → 2 → ... → 9)
- Elke ✓ Checkpoint is een verificatiemoment
- Bij fouten: check de checkpoint, herstel, ga verder
- NOOIT direct SQL queries in Python - alleen via stored procedures
- Alle endpoints vereisen JWT authentication (behalve /health)

**Verificatie na elke phase**:
```bash
# Example: After Phase 1
SELECT COUNT(*) FROM information_schema.routines 
WHERE routine_schema = 'activity' 
AND routine_name LIKE 'sp_social_%';
-- Expected: 22
```

---

## 🏗️ ARCHITECTUUR OVERZICHT

```
┌─────────────────────────────────────────────────────┐
│                  FastAPI (Social API)                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │  Routes  │  │ Services │  │  Models  │          │
│  │ (21 EPs) │→ │(Bus.Logic)│  │(Pydantic)│          │
│  └──────────┘  └─────┬────┘  └──────────┘          │
│                      │                               │
│                      ↓                               │
│            ┌──────────────────┐                     │
│            │ Stored Procedures │                     │
│            │   (22 functies)   │                     │
│            └────────┬──────────┘                     │
└─────────────────────┼──────────────────────────────┘
                      ↓
         ┌────────────────────────┐
         │   PostgreSQL Database   │
         │   (activity schema)     │
         └────────────────────────┘
```

**Data flow**:
1. Client → JWT Auth → API Route
2. API Route → Service Layer
3. Service → Stored Procedure (PostgreSQL)
4. PostgreSQL → JSONB Response → Service
5. Service → API Route → Client

---

## 📊 DELIVERABLES

Na voltooiing heb je:

### Database Layer (22 SPs)
- ✅ 8 Friendships SPs
- ✅ 5 Blocking SPs
- ✅ 5 Favorites SPs
- ✅ 3 Profile Views SPs
- ✅ 1 User Search SP

### API Layer (21 Endpoints)
- ✅ 8 Friendships endpoints
- ✅ 5 Blocking endpoints
- ✅ 5 Favorites endpoints
- ✅ 3 Profile Views endpoints
- ✅ 1 User Search endpoint

### Infrastructure
- ✅ Docker + Docker Compose
- ✅ PostgreSQL 15
- ✅ Redis (rate limiting)
- ✅ Health checks
- ✅ Structured logging
- ✅ CORS configuratie

### Security
- ✅ JWT authentication (alle endpoints)
- ✅ Rate limiting (per endpoint)
- ✅ Premium feature checks
- ✅ Ghost Mode support
- ✅ XXL activity exception

---

## 🚀 QUICK START (voor Claude Code)

```bash
# Step 1: Clone repository
git clone <repo-url>
cd social-api

# Step 2: Execute PART 1 instructions
# - Create directory structure (Phase 0)
# - Create all SQL files (Phase 1)
# - Create core Python files (Phase 2-4)

# Step 3: Execute PART 2 instructions
# - Create API routes (Phase 5)
# - Create main.py (Phase 6)
# - Create Docker files (Phase 7)
# - Create tests (Phase 8)

# Step 4: Deploy
docker-compose up -d

# Step 5: Verify
curl http://localhost:8000/health
curl http://localhost:8000/docs
```

---

## 🔍 KRITIEKE BUSINESS RULES

**Voor AI Agent - Let op deze regels**:

1. **Asymmetrische Blocking**
   - User A kan User B blokkeren zonder dat B het weet
   - User B kan onafhankelijk User A blokkeren
   - Check beide richtingen in queries

2. **XXL Exception**
   - Voor `activity_type = 'xxl'`: blocking werkt NIET
   - sp_social_check_can_interact moet dit respecteren

3. **Ghost Mode (Premium)**
   - Als `ghost_mode = TRUE`: GEEN record in profile_views
   - sp_social_record_profile_view checkt dit EERST

4. **Premium Features**
   - sp_social_get_who_favorited_me: vereist premium/club
   - sp_social_get_who_viewed_my_profile: vereist premium/club
   - Return HTTP 403 als niet premium

5. **User ID Ordering**
   - Friendships table: user_id_1 < user_id_2 ALTIJD
   - Stored procedures moeten IDs sorteren voor queries

---

## 📁 FILE STRUCTURE REFERENCE

```
social-api/
├── sql/
│   ├── 01_stored_procedures_friendships.sql   (8 SPs)
│   ├── 02_stored_procedures_blocks.sql        (5 SPs)
│   ├── 03_stored_procedures_favorites.sql     (5 SPs)
│   ├── 04_stored_procedures_profile_views.sql (3 SPs)
│   └── 05_stored_procedures_user_search.sql   (1 SP)
│
├── app/
│   ├── main.py                  # FastAPI app + routers
│   ├── config.py                # Settings (pydantic-settings)
│   ├── dependencies.py          # Shared dependencies
│   │
│   ├── core/
│   │   ├── logging_config.py    # Structured logging
│   │   ├── exceptions.py        # Custom exceptions
│   │   └── security.py          # JWT validation
│   │
│   ├── middleware/
│   │   └── correlation.py       # Correlation ID middleware
│   │
│   ├── routes/
│   │   ├── health.py            # Health check
│   │   ├── friendships.py       # 8 endpoints
│   │   ├── blocks.py            # 5 endpoints
│   │   ├── favorites.py         # 5 endpoints
│   │   ├── profile_views.py     # 3 endpoints
│   │   └── user_search.py       # 1 endpoint
│   │
│   ├── services/
│   │   ├── friendship_service.py
│   │   ├── block_service.py
│   │   ├── favorite_service.py
│   │   ├── profile_view_service.py
│   │   └── user_search_service.py
│   │
│   ├── models/
│   │   ├── requests.py          # Pydantic request models
│   │   └── responses.py         # Pydantic response models
│   │
│   └── utils/
│       ├── database.py          # Connection pool
│       └── errors.py            # Error parsing
│
├── tests/
│   ├── conftest.py              # Test fixtures
│   └── test_friendships.py      # Example tests
│
├── .env.example                 # Environment template
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Multi-stage build
├── docker-compose.yml           # Full stack
└── README.md                    # Project documentation
```

---

## ✅ VERIFICATION COMMANDS

Na elke phase, run deze commands:

### Phase 1 (Database)
```sql
SELECT routine_name, routine_schema
FROM information_schema.routines 
WHERE routine_schema = 'activity' 
AND routine_name LIKE 'sp_social_%'
ORDER BY routine_name;
```
**Expected**: 22 rows

### Phase 2-4 (Core + Services)
```bash
python -m py_compile app/**/*.py
# No output = success
```

### Phase 5-6 (API)
```bash
curl http://localhost:8000/health
# Expected: {"status":"healthy",...}

curl http://localhost:8000/docs
# Expected: Swagger UI HTML
```

### Phase 7 (Docker)
```bash
docker-compose ps
# Expected: 3 services running (social-api, postgres, redis)

docker-compose logs social-api | grep "Application startup complete"
# Expected: startup message
```

### Phase 8 (Tests)
```bash
pytest tests/ -v
# Expected: All tests pass (or xfail for DB-dependent tests)
```

---

## 🐛 COMMON ISSUES & FIXES

### Issue: Stored procedure not found
```bash
# Fix: Deploy SQL manually
psql -U postgres -d activitydb -f sql/01_stored_procedures_friendships.sql
```

### Issue: JWT validation fails
```python
# Fix: Check JWT_SECRET_KEY in .env matches Auth API
echo $JWT_SECRET_KEY
```

### Issue: Database connection timeout
```bash
# Fix: Check connection pool settings
# DATABASE_POOL_MAX_SIZE=20
# DATABASE_POOL_MIN_SIZE=5
```

### Issue: Rate limiting not working
```bash
# Fix: Verify Redis connection
redis-cli -h localhost ping
# Expected: PONG
```

---

## 📞 SUPPORT RESOURCES

**Reference Documents**:
- `SOCIAL_API_SPECIFICATIONS.md` - Complete API specs
- `sqlschema.sql` - Database schema
- `auth-api-specifications` - JWT token structure
- `fastapi-requirements` - FastAPI best practices

**External Documentation**:
- FastAPI: https://fastapi.tiangolo.com
- Pydantic: https://docs.pydantic.dev
- psycopg3: https://www.psycopg.org/psycopg3/docs/
- PostgreSQL: https://www.postgresql.org/docs/15/

---

## 🎓 FOR AI AGENTS: KEY LEARNINGS

**Pattern Recognition**:
1. Every API endpoint → Service method → Stored procedure
2. Every stored procedure returns JSONB
3. Every route needs `@limiter.limit("X/minute")`
4. Every route needs `Depends(get_current_user)`
5. Every service method commits transactions

**Error Handling Pattern**:
```python
try:
    service = SomeService()
    result = service.some_method(params)
    return result
except Exception as e:
    return create_error_response(e, 400)
```

**Service Method Pattern**:
```python
def some_method(self, param1: str, param2: str) -> Dict:
    with get_db_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT activity.sp_name(%s, %s)",
                (param1, param2)
            )
            result = cursor.fetchone()[0]
            conn.commit()
            return result
```

**Stored Procedure Pattern**:
```sql
CREATE OR REPLACE FUNCTION activity.sp_name(
    p_param1 UUID,
    p_param2 TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validation
    -- Business logic
    -- Return JSONB
    RETURN jsonb_build_object(...);
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
```

---

## ✨ SUCCESS CRITERIA

De Social API is compleet wanneer:

- [ ] Alle 22 stored procedures gedeployed en werkend
- [ ] Alle 21 API endpoints reageren correct
- [ ] JWT authenticatie werkt op alle protected endpoints
- [ ] Rate limiting actief op alle endpoints
- [ ] Premium features checken subscription_level
- [ ] Ghost Mode voorkomt profile_view records
- [ ] XXL exception voorkomt blocking checks
- [ ] Docker Compose start volledig systeem
- [ ] Health check returnt 200
- [ ] Swagger docs tonen alle endpoints
- [ ] Database connection pool stabiel
- [ ] Logging output structured (JSON in prod)
- [ ] Tests draaien zonder errors

**Final Test**:
```bash
# Send friend request
curl -X POST http://localhost:8000/social/friends/request \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"target_user_id":"<uuid>"}'
# Expected: 201 Created

# Get friends list
curl http://localhost:8000/social/friends \
  -H "Authorization: Bearer <token>"
# Expected: 200 OK with friends array
```

---

**READY TO BUILD!** 🚀

Start met **CLAUDE_CODE_INSTRUCTIONS_PART1.md** en werk sequentieel door alle phases.
