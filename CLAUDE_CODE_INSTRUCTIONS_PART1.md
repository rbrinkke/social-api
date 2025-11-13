# SOCIAL API - CLAUDE CODE WORK INSTRUCTIONS (PART 1)
**AI Agent Implementation Guide for Claude Code**

---

## MISSION BRIEFING

You are Claude Code building a production FastAPI microservice. This document contains EXACT step-by-step instructions optimized for AI execution.

**Repository**: `social-api/` (already exists on GitHub)  
**Goal**: Build complete Social API with 21 endpoints, 22 stored procedures  
**Reference docs**: SOCIAL_API_SPECIFICATIONS.md, sqlschema.sql, auth-api-specifications

---

## IMPLEMENTATION SEQUENCE

```
PHASE 0: Repository Setup (directories)
PHASE 1: Database Layer (22 stored procedures)
PHASE 2: Core Application (config, logging, security)
PHASE 3: Pydantic Models (request/response schemas)
PHASE 4: Service Layer (business logic)
PHASE 5: API Routes (endpoints) → See PART 2
PHASE 6: Main Application (FastAPI app) → See PART 2
PHASE 7: Docker & Testing → See PART 2
```

---

## PHASE 0: REPOSITORY STRUCTURE

Create exact directory structure:

```bash
mkdir -p app/{core,middleware,routes,services,models,utils}
mkdir -p tests sql
touch app/{__init__,main,config,dependencies}.py
touch app/core/{__init__,logging_config,exceptions,security}.py
touch app/middleware/{__init__,correlation}.py
touch app/routes/{__init__,health,friendships,blocks,favorites,profile_views,user_search}.py
touch app/services/{__init__,friendship_service,block_service,favorite_service,profile_view_service,user_search_service}.py
touch app/models/{__init__,requests,responses}.py
touch app/utils/{__init__,auth,database,errors}.py
touch tests/{__init__,conftest}.py
touch sql/{01_stored_procedures_friendships,02_stored_procedures_blocks,03_stored_procedures_favorites,04_stored_procedures_profile_views,05_stored_procedures_user_search}.sql
```

**✓ Checkpoint**: Run `tree app sql tests` - structure must match exactly

---

## PHASE 1: DATABASE STORED PROCEDURES

### File: `sql/01_stored_procedures_friendships.sql`

```sql
-- ============================================================================
-- FRIENDSHIPS MODULE - 8 STORED PROCEDURES
-- ============================================================================

-- SP 1: Send Friend Request
CREATE OR REPLACE FUNCTION activity.sp_social_send_friend_request(
    p_requester_user_id UUID,
    p_target_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id_1 UUID;
    v_user_id_2 UUID;
    v_target_exists BOOLEAN;
    v_friendship_exists BOOLEAN;
    v_existing_status TEXT;
    v_is_blocked BOOLEAN;
    v_has_blocked BOOLEAN;
BEGIN
    -- Validation 1: Cannot friend yourself
    IF p_requester_user_id = p_target_user_id THEN
        RAISE EXCEPTION 'SELF_FRIEND_ERROR: Cannot send friend request to yourself';
    END IF;
    
    -- Validation 2: Check target user exists
    SELECT EXISTS(SELECT 1 FROM activity.users WHERE user_id = p_target_user_id)
    INTO v_target_exists;
    
    IF NOT v_target_exists THEN
        RAISE EXCEPTION 'USER_NOT_FOUND: Target user does not exist';
    END IF;
    
    -- Validation 3: Check for existing friendship
    IF p_requester_user_id < p_target_user_id THEN
        v_user_id_1 := p_requester_user_id;
        v_user_id_2 := p_target_user_id;
    ELSE
        v_user_id_1 := p_target_user_id;
        v_user_id_2 := p_requester_user_id;
    END IF;
    
    SELECT EXISTS(
        SELECT 1 FROM activity.friendships 
        WHERE user_id_1 = v_user_id_1 AND user_id_2 = v_user_id_2
    ), status
    INTO v_friendship_exists, v_existing_status
    FROM activity.friendships
    WHERE user_id_1 = v_user_id_1 AND user_id_2 = v_user_id_2;
    
    IF v_friendship_exists THEN
        RAISE EXCEPTION 'FRIENDSHIP_EXISTS: Friendship already exists with status: %', v_existing_status;
    END IF;
    
    -- Validation 4: Check if requester is blocked by target
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks 
        WHERE blocker_user_id = p_target_user_id 
        AND blocked_user_id = p_requester_user_id
    ) INTO v_is_blocked;
    
    IF v_is_blocked THEN
        RAISE EXCEPTION 'BLOCKED_BY_USER: You cannot send friend request to this user';
    END IF;
    
    -- Validation 5: Check if requester has blocked target
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks 
        WHERE blocker_user_id = p_requester_user_id 
        AND blocked_user_id = p_target_user_id
    ) INTO v_has_blocked;
    
    IF v_has_blocked THEN
        RAISE EXCEPTION 'USER_BLOCKED: Cannot send friend request to blocked user';
    END IF;
    
    -- Insert friendship
    INSERT INTO activity.friendships (
        user_id_1, user_id_2, status, initiated_by, created_at
    ) VALUES (
        v_user_id_1, v_user_id_2, 'pending', p_requester_user_id, NOW()
    );
    
    -- Return success response
    RETURN jsonb_build_object(
        'friendship_id', v_user_id_1::TEXT || ':' || v_user_id_2::TEXT,
        'requester_user_id', p_requester_user_id,
        'target_user_id', p_target_user_id,
        'status', 'pending',
        'initiated_by', p_requester_user_id,
        'created_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 2: Accept Friend Request
CREATE OR REPLACE FUNCTION activity.sp_social_accept_friend_request(
    p_accepting_user_id UUID,
    p_requester_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id_1 UUID;
    v_user_id_2 UUID;
    v_friendship RECORD;
BEGIN
    IF p_accepting_user_id < p_requester_user_id THEN
        v_user_id_1 := p_accepting_user_id;
        v_user_id_2 := p_requester_user_id;
    ELSE
        v_user_id_1 := p_requester_user_id;
        v_user_id_2 := p_accepting_user_id;
    END IF;
    
    SELECT * INTO v_friendship
    FROM activity.friendships
    WHERE user_id_1 = v_user_id_1 
    AND user_id_2 = v_user_id_2
    AND status = 'pending'
    AND initiated_by = p_requester_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'FRIENDSHIP_NOT_FOUND: No pending friend request found';
    END IF;
    
    IF p_accepting_user_id = p_requester_user_id THEN
        RAISE EXCEPTION 'INVALID_ACCEPTOR: You cannot accept your own friend request';
    END IF;
    
    UPDATE activity.friendships
    SET status = 'accepted',
        accepted_at = NOW(),
        updated_at = NOW()
    WHERE user_id_1 = v_user_id_1 
    AND user_id_2 = v_user_id_2;
    
    RETURN jsonb_build_object(
        'friendship_id', v_user_id_1::TEXT || ':' || v_user_id_2::TEXT,
        'user_id_1', v_user_id_1,
        'user_id_2', v_user_id_2,
        'status', 'accepted',
        'initiated_by', v_friendship.initiated_by,
        'accepted_at', NOW(),
        'created_at', v_friendship.created_at
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 3: Decline Friend Request
CREATE OR REPLACE FUNCTION activity.sp_social_decline_friend_request(
    p_declining_user_id UUID,
    p_requester_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id_1 UUID;
    v_user_id_2 UUID;
    v_deleted_count INT;
BEGIN
    IF p_declining_user_id < p_requester_user_id THEN
        v_user_id_1 := p_declining_user_id;
        v_user_id_2 := p_requester_user_id;
    ELSE
        v_user_id_1 := p_requester_user_id;
        v_user_id_2 := p_declining_user_id;
    END IF;
    
    IF p_declining_user_id = p_requester_user_id THEN
        RAISE EXCEPTION 'INVALID_DECLINER: You cannot decline your own friend request';
    END IF;
    
    DELETE FROM activity.friendships
    WHERE user_id_1 = v_user_id_1 
    AND user_id_2 = v_user_id_2
    AND status = 'pending'
    AND initiated_by = p_requester_user_id;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    IF v_deleted_count = 0 THEN
        RAISE EXCEPTION 'FRIENDSHIP_NOT_FOUND: No pending friend request found';
    END IF;
    
    RETURN jsonb_build_object(
        'message', 'Friend request declined',
        'requester_user_id', p_requester_user_id,
        'declined_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 4: Remove Friend
CREATE OR REPLACE FUNCTION activity.sp_social_remove_friend(
    p_user_id UUID,
    p_friend_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id_1 UUID;
    v_user_id_2 UUID;
    v_deleted_count INT;
BEGIN
    IF p_user_id < p_friend_user_id THEN
        v_user_id_1 := p_user_id;
        v_user_id_2 := p_friend_user_id;
    ELSE
        v_user_id_1 := p_friend_user_id;
        v_user_id_2 := p_user_id;
    END IF;
    
    DELETE FROM activity.friendships
    WHERE user_id_1 = v_user_id_1 
    AND user_id_2 = v_user_id_2;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    IF v_deleted_count = 0 THEN
        RAISE EXCEPTION 'FRIENDSHIP_NOT_FOUND: No friendship found with this user';
    END IF;
    
    RETURN jsonb_build_object(
        'message', 'Friendship removed',
        'removed_user_id', p_friend_user_id,
        'removed_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 5: Get Friends List
CREATE OR REPLACE FUNCTION activity.sp_social_get_friends_list(
    p_user_id UUID,
    p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_friends JSONB;
    v_total_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM activity.friendships f
    WHERE (f.user_id_1 = p_user_id OR f.user_id_2 = p_user_id)
    AND f.status = 'accepted';
    
    SELECT COALESCE(jsonb_agg(friend_data), '[]'::jsonb)
    INTO v_friends
    FROM (
        SELECT jsonb_build_object(
            'user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'is_verified', u.is_verified,
            'friendship_since', f.accepted_at
        ) AS friend_data
        FROM activity.friendships f
        JOIN activity.users u ON (
            CASE 
                WHEN f.user_id_1 = p_user_id THEN u.user_id = f.user_id_2
                ELSE u.user_id = f.user_id_1
            END
        )
        WHERE (f.user_id_1 = p_user_id OR f.user_id_2 = p_user_id)
        AND f.status = 'accepted'
        ORDER BY f.accepted_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) friends;
    
    RETURN jsonb_build_object(
        'friends', v_friends,
        'total_count', v_total_count,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 6: Get Pending Friend Requests (Received)
CREATE OR REPLACE FUNCTION activity.sp_social_get_pending_friend_requests(
    p_user_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_requests JSONB;
    v_total_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM activity.friendships f
    WHERE (f.user_id_1 = p_user_id OR f.user_id_2 = p_user_id)
    AND f.status = 'pending'
    AND f.initiated_by != p_user_id;
    
    SELECT COALESCE(jsonb_agg(request_data), '[]'::jsonb)
    INTO v_requests
    FROM (
        SELECT jsonb_build_object(
            'requester_user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'is_verified', u.is_verified,
            'requested_at', f.created_at
        ) AS request_data
        FROM activity.friendships f
        JOIN activity.users u ON u.user_id = f.initiated_by
        WHERE (f.user_id_1 = p_user_id OR f.user_id_2 = p_user_id)
        AND f.status = 'pending'
        AND f.initiated_by != p_user_id
        ORDER BY f.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) requests;
    
    RETURN jsonb_build_object(
        'requests', v_requests,
        'total_count', v_total_count,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 7: Get Sent Friend Requests
CREATE OR REPLACE FUNCTION activity.sp_social_get_sent_friend_requests(
    p_user_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_requests JSONB;
    v_total_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM activity.friendships f
    WHERE f.status = 'pending'
    AND f.initiated_by = p_user_id;
    
    SELECT COALESCE(jsonb_agg(request_data), '[]'::jsonb)
    INTO v_requests
    FROM (
        SELECT jsonb_build_object(
            'target_user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'is_verified', u.is_verified,
            'requested_at', f.created_at
        ) AS request_data
        FROM activity.friendships f
        JOIN activity.users u ON (
            CASE 
                WHEN f.user_id_1 = p_user_id THEN u.user_id = f.user_id_2
                ELSE u.user_id = f.user_id_1
            END
        )
        WHERE f.status = 'pending'
        AND f.initiated_by = p_user_id
        ORDER BY f.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) requests;
    
    RETURN jsonb_build_object(
        'requests', v_requests,
        'total_count', v_total_count,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 8: Check Friendship Status
CREATE OR REPLACE FUNCTION activity.sp_social_check_friendship_status(
    p_user_id_1 UUID,
    p_user_id_2 UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id_1 UUID;
    v_user_id_2 UUID;
    v_friendship RECORD;
BEGIN
    IF p_user_id_1 < p_user_id_2 THEN
        v_user_id_1 := p_user_id_1;
        v_user_id_2 := p_user_id_2;
    ELSE
        v_user_id_1 := p_user_id_2;
        v_user_id_2 := p_user_id_1;
    END IF;
    
    SELECT * INTO v_friendship
    FROM activity.friendships
    WHERE user_id_1 = v_user_id_1 
    AND user_id_2 = v_user_id_2;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'none');
    END IF;
    
    RETURN jsonb_build_object(
        'status', v_friendship.status,
        'initiated_by', v_friendship.initiated_by,
        'created_at', v_friendship.created_at,
        'accepted_at', v_friendship.accepted_at
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
```

**✓ Checkpoint**: Deploy to database, verify 8 functions exist:
```sql
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'activity' AND routine_name LIKE '%friend%';
```

---

### File: `sql/02_stored_procedures_blocks.sql`

```sql
-- ============================================================================
-- BLOCKING MODULE - 5 STORED PROCEDURES
-- ============================================================================

-- SP 1: Block User
CREATE OR REPLACE FUNCTION activity.sp_social_block_user(
    p_blocker_user_id UUID,
    p_blocked_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_exists BOOLEAN;
    v_already_blocked BOOLEAN;
    v_friendship_removed BOOLEAN := FALSE;
BEGIN
    IF p_blocker_user_id = p_blocked_user_id THEN
        RAISE EXCEPTION 'SELF_BLOCK_ERROR: Cannot block yourself';
    END IF;
    
    SELECT EXISTS(SELECT 1 FROM activity.users WHERE user_id = p_blocked_user_id)
    INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'USER_NOT_FOUND: User does not exist';
    END IF;
    
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks 
        WHERE blocker_user_id = p_blocker_user_id 
        AND blocked_user_id = p_blocked_user_id
    ) INTO v_already_blocked;
    
    IF v_already_blocked THEN
        RAISE EXCEPTION 'ALREADY_BLOCKED: User is already blocked';
    END IF;
    
    INSERT INTO activity.user_blocks (
        blocker_user_id, blocked_user_id, created_at, reason
    ) VALUES (
        p_blocker_user_id, p_blocked_user_id, NOW(), p_reason
    );
    
    DELETE FROM activity.friendships
    WHERE (user_id_1 = LEAST(p_blocker_user_id, p_blocked_user_id)
       AND user_id_2 = GREATEST(p_blocker_user_id, p_blocked_user_id));
    
    IF FOUND THEN
        v_friendship_removed := TRUE;
    END IF;
    
    RETURN jsonb_build_object(
        'blocker_user_id', p_blocker_user_id,
        'blocked_user_id', p_blocked_user_id,
        'blocked_at', NOW(),
        'friendship_removed', v_friendship_removed
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 2: Unblock User
CREATE OR REPLACE FUNCTION activity.sp_social_unblock_user(
    p_blocker_user_id UUID,
    p_blocked_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM activity.user_blocks
    WHERE blocker_user_id = p_blocker_user_id 
    AND blocked_user_id = p_blocked_user_id;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    IF v_deleted_count = 0 THEN
        RAISE EXCEPTION 'BLOCK_NOT_FOUND: No block found for this user';
    END IF;
    
    RETURN jsonb_build_object(
        'blocker_user_id', p_blocker_user_id,
        'unblocked_user_id', p_blocked_user_id,
        'unblocked_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 3: Get Blocked Users
CREATE OR REPLACE FUNCTION activity.sp_social_get_blocked_users(
    p_blocker_user_id UUID,
    p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_blocked_users JSONB;
    v_total_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM activity.user_blocks
    WHERE blocker_user_id = p_blocker_user_id;
    
    SELECT COALESCE(jsonb_agg(blocked_user_data), '[]'::jsonb)
    INTO v_blocked_users
    FROM (
        SELECT jsonb_build_object(
            'blocked_user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'blocked_at', b.created_at,
            'reason', b.reason
        ) AS blocked_user_data
        FROM activity.user_blocks b
        JOIN activity.users u ON u.user_id = b.blocked_user_id
        WHERE b.blocker_user_id = p_blocker_user_id
        ORDER BY b.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) blocked;
    
    RETURN jsonb_build_object(
        'blocked_users', v_blocked_users,
        'total_count', v_total_count,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 4: Check Block Status
CREATE OR REPLACE FUNCTION activity.sp_social_check_block_status(
    p_user_id_1 UUID,
    p_user_id_2 UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_1_blocked_user_2 BOOLEAN;
    v_user_2_blocked_user_1 BOOLEAN;
    v_any_block_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks 
        WHERE blocker_user_id = p_user_id_1 
        AND blocked_user_id = p_user_id_2
    ) INTO v_user_1_blocked_user_2;
    
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks 
        WHERE blocker_user_id = p_user_id_2 
        AND blocked_user_id = p_user_id_1
    ) INTO v_user_2_blocked_user_1;
    
    v_any_block_exists := v_user_1_blocked_user_2 OR v_user_2_blocked_user_1;
    
    RETURN jsonb_build_object(
        'user_1_blocked_user_2', v_user_1_blocked_user_2,
        'user_2_blocked_user_1', v_user_2_blocked_user_1,
        'any_block_exists', v_any_block_exists
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 5: Check Can Interact
CREATE OR REPLACE FUNCTION activity.sp_social_check_can_interact(
    p_user_id_1 UUID,
    p_user_id_2 UUID,
    p_activity_type TEXT DEFAULT 'standard'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_any_block_exists BOOLEAN;
    v_can_interact BOOLEAN;
    v_reason TEXT;
BEGIN
    -- XXL EXCEPTION: Blocking does NOT apply to XXL activities
    IF p_activity_type = 'xxl' THEN
        RETURN jsonb_build_object(
            'can_interact', TRUE,
            'reason', 'xxl_exception',
            'activity_type', p_activity_type
        );
    END IF;
    
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks 
        WHERE (blocker_user_id = p_user_id_1 AND blocked_user_id = p_user_id_2)
        OR (blocker_user_id = p_user_id_2 AND blocked_user_id = p_user_id_1)
    ) INTO v_any_block_exists;
    
    IF v_any_block_exists THEN
        v_can_interact := FALSE;
        v_reason := 'blocked';
    ELSE
        v_can_interact := TRUE;
        v_reason := 'no_blocks';
    END IF;
    
    RETURN jsonb_build_object(
        'can_interact', v_can_interact,
        'reason', v_reason,
        'activity_type', p_activity_type
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
```

**✓ Checkpoint**: Verify 5 blocking functions exist

---

### Files: `sql/03_stored_procedures_favorites.sql`, `04_profile_views.sql`, `05_user_search.sql`

Due to space constraints, follow the EXACT patterns from SOCIAL_API_SPECIFICATIONS.md for:
- Favorites (5 SPs)
- Profile Views (3 SPs)  
- User Search (1 SP)

**KEY PATTERNS**:
- All use JSONB return type
- All have EXCEPTION WHEN OTHERS THEN RAISE
- Premium checks: `IF p_subscription_level NOT IN ('premium', 'club') THEN RAISE EXCEPTION 'PREMIUM_REQUIRED'`
- Ghost mode: `IF p_ghost_mode THEN RETURN ... (without INSERT)`

---

## PHASE 2: CORE APPLICATION FILES

### File: `requirements.txt`

```txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.0
pydantic-settings==2.1.0
psycopg[binary,pool]==3.1.16
python-jose[cryptography]==3.3.0
python-multipart==0.0.6
redis==5.0.1
slowapi==0.1.9
structlog==24.1.0
pytest==7.4.3
pytest-asyncio==0.21.1
httpx==0.25.2
```

### File: `.env.example`

```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/activitydb
DATABASE_POOL_MIN_SIZE=5
DATABASE_POOL_MAX_SIZE=20
JWT_SECRET_KEY=change-in-production
JWT_ALGORITHM=HS256
REDIS_URL=redis://localhost:6379/0
API_HOST=0.0.0.0
API_PORT=8000
ENVIRONMENT=development
CORS_ORIGINS=["http://localhost:3000"]
LOG_LEVEL=INFO
```

### File: `app/config.py`

```python
from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    PROJECT_NAME: str = "Social API"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    DATABASE_URL: str
    DATABASE_POOL_MIN_SIZE: int = 5
    DATABASE_POOL_MAX_SIZE: int = 20
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    REDIS_URL: str = "redis://localhost:6379/0"
    CORS_ORIGINS: List[str] = ["http://localhost:3000"]
    LOG_LEVEL: str = "INFO"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
```

### File: `app/core/logging_config.py`

```python
import structlog
import logging

def setup_logging(environment: str):
    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
    ]
    
    if environment == "production":
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())
    
    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    logging.basicConfig(format="%(message)s", level=logging.INFO)

def get_logger(name: str):
    return structlog.get_logger(name)
```

### File: `app/core/security.py`

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from app.config import settings
from typing import Dict

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id = payload.get("sub")
        email = payload.get("email")
        
        if not user_id or not email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing required claims"
            )
        
        return {
            "user_id": user_id,
            "email": email,
            "subscription_level": payload.get("subscription_level", "free"),
            "ghost_mode": payload.get("ghost_mode", False)
        }
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}"
        )
```

### File: `app/utils/database.py`

```python
from psycopg_pool import ConnectionPool
from app.config import settings
from contextlib import contextmanager

pool = ConnectionPool(
    conninfo=settings.DATABASE_URL,
    min_size=settings.DATABASE_POOL_MIN_SIZE,
    max_size=settings.DATABASE_POOL_MAX_SIZE,
    timeout=30
)

@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = pool.getconn()
        yield conn
    except Exception as e:
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            pool.putconn(conn)

def close_pool():
    pool.close()
```

---

## PHASE 3: PYDANTIC MODELS

### File: `app/models/requests.py`

```python
from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional

class SendFriendRequestRequest(BaseModel):
    target_user_id: UUID

class AcceptFriendRequestRequest(BaseModel):
    requester_user_id: UUID

class DeclineFriendRequestRequest(BaseModel):
    requester_user_id: UUID

class BlockUserRequest(BaseModel):
    blocked_user_id: UUID
    reason: Optional[str] = Field(None, max_length=500)

class FavoriteUserRequest(BaseModel):
    favorited_user_id: UUID

class RecordProfileViewRequest(BaseModel):
    viewed_user_id: UUID
```

### File: `app/models/responses.py`

```python
from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from typing import List, Optional

class FriendshipResponse(BaseModel):
    friendship_id: str
    requester_user_id: UUID
    target_user_id: UUID
    status: str
    initiated_by: UUID
    created_at: datetime

class FriendProfileResponse(BaseModel):
    user_id: UUID
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool
    friendship_since: datetime

class FriendsListResponse(BaseModel):
    friends: List[FriendProfileResponse]
    total_count: int
    limit: int
    offset: int

# Add all other response models from specifications...
# BlockUserResponse, FavoriteUserResponse, ProfileViewRecordedResponse, etc.
```

---

## PHASE 4: SERVICE LAYER

### File: `app/services/friendship_service.py`

```python
from app.utils.database import get_db_connection
from typing import Dict

class FriendshipService:
    def send_friend_request(self, requester_id: str, target_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_send_friend_request(%s, %s)",
                    (requester_id, target_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result
    
    def accept_friend_request(self, accepting_id: str, requester_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_accept_friend_request(%s, %s)",
                    (accepting_id, requester_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result
    
    # Add remaining 6 methods following exact same pattern...
```

**PATTERN FOR ALL SERVICES**:
1. `with get_db_connection() as conn:`
2. `with conn.cursor() as cursor:`
3. `cursor.execute("SELECT activity.sp_name(%s, ...)", (params,))`
4. `result = cursor.fetchone()[0]`
5. `conn.commit()` (for write operations)
6. `return result`

---

**END OF PART 1**

Continue to **CLAUDE_CODE_INSTRUCTIONS_PART2.md** for:
- API Routes (21 endpoints)
- Main Application Setup
- Docker Configuration
- Testing Strategy
