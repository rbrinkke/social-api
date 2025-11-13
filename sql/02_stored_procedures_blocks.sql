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
