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
