-- ============================================================================
-- FAVORITES MODULE - 5 STORED PROCEDURES
-- ============================================================================

-- SP 1: Favorite User
CREATE OR REPLACE FUNCTION activity.sp_social_favorite_user(
    p_favoriting_user_id UUID,
    p_favorited_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_exists BOOLEAN;
    v_already_favorited BOOLEAN;
    v_any_block_exists BOOLEAN;
BEGIN
    -- Validation 1: Cannot favorite yourself
    IF p_favoriting_user_id = p_favorited_user_id THEN
        RAISE EXCEPTION 'SELF_FAVORITE_ERROR: Cannot favorite yourself';
    END IF;

    -- Validation 2: Check favorited user exists
    SELECT EXISTS(SELECT 1 FROM activity.users WHERE user_id = p_favorited_user_id)
    INTO v_user_exists;

    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'USER_NOT_FOUND: User does not exist';
    END IF;

    -- Validation 3: Check not already favorited
    SELECT EXISTS(
        SELECT 1 FROM activity.user_favorites
        WHERE favoriting_user_id = p_favoriting_user_id
        AND favorited_user_id = p_favorited_user_id
    ) INTO v_already_favorited;

    IF v_already_favorited THEN
        RAISE EXCEPTION 'ALREADY_FAVORITED: User is already favorited';
    END IF;

    -- Validation 4: Check for blocks (either direction)
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks
        WHERE (blocker_user_id = p_favoriting_user_id AND blocked_user_id = p_favorited_user_id)
        OR (blocker_user_id = p_favorited_user_id AND blocked_user_id = p_favoriting_user_id)
    ) INTO v_any_block_exists;

    IF v_any_block_exists THEN
        RAISE EXCEPTION 'BLOCKED_USER: Cannot favorite blocked user';
    END IF;

    -- Insert favorite
    INSERT INTO activity.user_favorites (
        favoriting_user_id, favorited_user_id, created_at
    ) VALUES (
        p_favoriting_user_id, p_favorited_user_id, NOW()
    );

    -- Return success response
    RETURN jsonb_build_object(
        'favoriting_user_id', p_favoriting_user_id,
        'favorited_user_id', p_favorited_user_id,
        'favorited_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 2: Unfavorite User
CREATE OR REPLACE FUNCTION activity.sp_social_unfavorite_user(
    p_favoriting_user_id UUID,
    p_favorited_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM activity.user_favorites
    WHERE favoriting_user_id = p_favoriting_user_id
    AND favorited_user_id = p_favorited_user_id;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    IF v_deleted_count = 0 THEN
        RAISE EXCEPTION 'FAVORITE_NOT_FOUND: Favorite not found';
    END IF;

    RETURN jsonb_build_object(
        'favoriting_user_id', p_favoriting_user_id,
        'unfavorited_user_id', p_favorited_user_id,
        'unfavorited_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 3: Get My Favorites
CREATE OR REPLACE FUNCTION activity.sp_social_get_my_favorites(
    p_user_id UUID,
    p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_favorites JSONB;
    v_total_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM activity.user_favorites
    WHERE favoriting_user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(favorite_data), '[]'::jsonb)
    INTO v_favorites
    FROM (
        SELECT jsonb_build_object(
            'user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'is_verified', u.is_verified,
            'favorited_at', f.created_at
        ) AS favorite_data
        FROM activity.user_favorites f
        JOIN activity.users u ON u.user_id = f.favorited_user_id
        WHERE f.favoriting_user_id = p_user_id
        ORDER BY f.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) favorites;

    RETURN jsonb_build_object(
        'favorites', v_favorites,
        'total_count', v_total_count,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 4: Get Who Favorited Me (Premium Feature)
CREATE OR REPLACE FUNCTION activity.sp_social_get_who_favorited_me(
    p_user_id UUID,
    p_subscription_level TEXT,
    p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_favorited_by JSONB;
    v_total_count INT;
BEGIN
    -- Premium check
    IF p_subscription_level NOT IN ('premium', 'club') THEN
        RAISE EXCEPTION 'PREMIUM_REQUIRED: This feature requires Premium or Club subscription';
    END IF;

    SELECT COUNT(*)
    INTO v_total_count
    FROM activity.user_favorites
    WHERE favorited_user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(favoriter_data), '[]'::jsonb)
    INTO v_favorited_by
    FROM (
        SELECT jsonb_build_object(
            'user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'is_verified', u.is_verified,
            'favorited_at', f.created_at
        ) AS favoriter_data
        FROM activity.user_favorites f
        JOIN activity.users u ON u.user_id = f.favoriting_user_id
        WHERE f.favorited_user_id = p_user_id
        ORDER BY f.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) favoriters;

    RETURN jsonb_build_object(
        'favorited_by', v_favorited_by,
        'total_count', v_total_count,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 5: Check Favorite Status
CREATE OR REPLACE FUNCTION activity.sp_social_check_favorite_status(
    p_favoriting_user_id UUID,
    p_favorited_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_favorite RECORD;
BEGIN
    SELECT * INTO v_favorite
    FROM activity.user_favorites
    WHERE favoriting_user_id = p_favoriting_user_id
    AND favorited_user_id = p_favorited_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('is_favorited', FALSE);
    END IF;

    RETURN jsonb_build_object(
        'is_favorited', TRUE,
        'favorited_at', v_favorite.created_at
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
