-- ============================================================================
-- PROFILE VIEWS MODULE - 3 STORED PROCEDURES
-- ============================================================================

-- SP 1: Record Profile View
CREATE OR REPLACE FUNCTION activity.sp_social_record_profile_view(
    p_viewer_user_id UUID,
    p_viewed_user_id UUID,
    p_ghost_mode BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_exists BOOLEAN;
    v_any_block_exists BOOLEAN;
    v_view_id UUID;
BEGIN
    -- Validation 1: Cannot view your own profile
    IF p_viewer_user_id = p_viewed_user_id THEN
        RAISE EXCEPTION 'SELF_VIEW_ERROR: Cannot record self-profile view';
    END IF;

    -- Validation 2: Check viewed user exists
    SELECT EXISTS(SELECT 1 FROM activity.users WHERE user_id = p_viewed_user_id)
    INTO v_user_exists;

    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'USER_NOT_FOUND: User does not exist';
    END IF;

    -- Validation 3: Check for blocks (either direction)
    SELECT EXISTS(
        SELECT 1 FROM activity.user_blocks
        WHERE (blocker_user_id = p_viewer_user_id AND blocked_user_id = p_viewed_user_id)
        OR (blocker_user_id = p_viewed_user_id AND blocked_user_id = p_viewer_user_id)
    ) INTO v_any_block_exists;

    IF v_any_block_exists THEN
        RAISE EXCEPTION 'BLOCKED_USER: Cannot view blocked user profile';
    END IF;

    -- Ghost Mode: Return without recording
    IF p_ghost_mode = TRUE THEN
        RETURN jsonb_build_object(
            'view_recorded', FALSE,
            'ghost_mode', TRUE,
            'viewed_user_id', p_viewed_user_id
        );
    END IF;

    -- Normal Mode: Record the view
    v_view_id := gen_random_uuid();

    INSERT INTO activity.profile_views (
        view_id, viewer_user_id, viewed_user_id, viewed_at
    ) VALUES (
        v_view_id, p_viewer_user_id, p_viewed_user_id, NOW()
    );

    RETURN jsonb_build_object(
        'view_recorded', TRUE,
        'view_id', v_view_id,
        'viewer_user_id', p_viewer_user_id,
        'viewed_user_id', p_viewed_user_id,
        'viewed_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 2: Get Who Viewed My Profile (Premium Feature)
CREATE OR REPLACE FUNCTION activity.sp_social_get_who_viewed_my_profile(
    p_user_id UUID,
    p_subscription_level TEXT,
    p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_viewers JSONB;
    v_total_viewers INT;
    v_total_views INT;
BEGIN
    -- Premium check
    IF p_subscription_level NOT IN ('premium', 'club') THEN
        RAISE EXCEPTION 'PREMIUM_REQUIRED: This feature requires Premium or Club subscription';
    END IF;

    -- Get total views count
    SELECT COUNT(*)
    INTO v_total_views
    FROM activity.profile_views
    WHERE viewed_user_id = p_user_id;

    -- Get unique viewers count
    SELECT COUNT(DISTINCT viewer_user_id)
    INTO v_total_viewers
    FROM activity.profile_views
    WHERE viewed_user_id = p_user_id;

    -- Get viewers with aggregated data
    SELECT COALESCE(jsonb_agg(viewer_data), '[]'::jsonb)
    INTO v_viewers
    FROM (
        SELECT jsonb_build_object(
            'viewer_user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'is_verified', u.is_verified,
            'last_viewed_at', MAX(pv.viewed_at),
            'view_count', COUNT(pv.view_id)
        ) AS viewer_data
        FROM activity.profile_views pv
        JOIN activity.users u ON u.user_id = pv.viewer_user_id
        WHERE pv.viewed_user_id = p_user_id
        GROUP BY u.user_id, u.username, u.first_name, u.last_name,
                 u.main_photo_url, u.is_verified
        ORDER BY MAX(pv.viewed_at) DESC
        LIMIT p_limit
        OFFSET p_offset
    ) viewers;

    RETURN jsonb_build_object(
        'viewers', v_viewers,
        'total_viewers', v_total_viewers,
        'total_views', v_total_views,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- SP 3: Get Profile View Count
CREATE OR REPLACE FUNCTION activity.sp_social_get_profile_view_count(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_views INT;
    v_unique_viewers INT;
BEGIN
    -- Get total views
    SELECT COUNT(*)
    INTO v_total_views
    FROM activity.profile_views
    WHERE viewed_user_id = p_user_id;

    -- Get unique viewers
    SELECT COUNT(DISTINCT viewer_user_id)
    INTO v_unique_viewers
    FROM activity.profile_views
    WHERE viewed_user_id = p_user_id;

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'total_views', v_total_views,
        'unique_viewers', v_unique_viewers
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
