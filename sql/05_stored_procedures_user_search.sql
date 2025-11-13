-- ============================================================================
-- USER SEARCH MODULE - 1 STORED PROCEDURE
-- ============================================================================

-- SP 1: Search Users
CREATE OR REPLACE FUNCTION activity.sp_social_search_users(
    p_searcher_user_id UUID,
    p_search_query TEXT,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_users JSONB;
    v_total_count INT;
    v_search_pattern TEXT;
BEGIN
    -- Validation: Query must be at least 2 characters
    IF LENGTH(TRIM(p_search_query)) < 2 THEN
        RAISE EXCEPTION 'INVALID_QUERY: Search query must be at least 2 characters';
    END IF;

    v_search_pattern := '%' || LOWER(TRIM(p_search_query)) || '%';

    -- Get total count of matching users
    SELECT COUNT(*)
    INTO v_total_count
    FROM activity.users u
    WHERE (
        LOWER(u.username) LIKE v_search_pattern
        OR LOWER(u.first_name) LIKE v_search_pattern
        OR LOWER(u.last_name) LIKE v_search_pattern
        OR LOWER(CONCAT(u.first_name, ' ', u.last_name)) LIKE v_search_pattern
    )
    AND u.user_id != p_searcher_user_id
    AND NOT EXISTS (
        SELECT 1 FROM activity.user_blocks
        WHERE (blocker_user_id = p_searcher_user_id AND blocked_user_id = u.user_id)
        OR (blocker_user_id = u.user_id AND blocked_user_id = p_searcher_user_id)
    );

    -- Get matching users with details
    SELECT COALESCE(jsonb_agg(user_data), '[]'::jsonb)
    INTO v_users
    FROM (
        SELECT jsonb_build_object(
            'user_id', u.user_id,
            'username', u.username,
            'first_name', u.first_name,
            'last_name', u.last_name,
            'main_photo_url', u.main_photo_url,
            'is_verified', u.is_verified,
            'activities_created_count', COALESCE(u.activities_created_count, 0),
            'activities_attended_count', COALESCE(u.activities_attended_count, 0)
        ) AS user_data
        FROM activity.users u
        WHERE (
            LOWER(u.username) LIKE v_search_pattern
            OR LOWER(u.first_name) LIKE v_search_pattern
            OR LOWER(u.last_name) LIKE v_search_pattern
            OR LOWER(CONCAT(u.first_name, ' ', u.last_name)) LIKE v_search_pattern
        )
        AND u.user_id != p_searcher_user_id
        AND NOT EXISTS (
            SELECT 1 FROM activity.user_blocks
            WHERE (blocker_user_id = p_searcher_user_id AND blocked_user_id = u.user_id)
            OR (blocker_user_id = u.user_id AND blocked_user_id = p_searcher_user_id)
        )
        ORDER BY
            u.is_verified DESC,
            CASE
                WHEN LOWER(u.username) = LOWER(TRIM(p_search_query)) THEN 1
                WHEN LOWER(u.first_name) = LOWER(TRIM(p_search_query)) THEN 2
                WHEN LOWER(u.last_name) = LOWER(TRIM(p_search_query)) THEN 3
                ELSE 4
            END,
            u.username ASC
        LIMIT p_limit
        OFFSET p_offset
    ) users;

    RETURN jsonb_build_object(
        'users', v_users,
        'total_count', v_total_count,
        'search_query', p_search_query,
        'limit', p_limit,
        'offset', p_offset
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
