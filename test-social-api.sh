#!/bin/bash

################################################################################
# SOCIAL API COMPREHENSIVE TEST SUITE
# Tests all 23 endpoints with complete database verification
################################################################################

# Don't exit on error - we want to continue testing even if some tests fail
set +e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# API Configuration
API_URL="http://localhost:8005"
DB_CONTAINER="activity-postgres-db"
DB_NAME="activitydb"
DB_USER="postgres"

# Test user IDs (will be created)
TEST_USER_1=""
TEST_USER_2=""
TEST_USER_3=""
TEST_USER_1_TOKEN=""
TEST_USER_2_TOKEN=""
TEST_USER_3_TOKEN=""
TEST_USER_FREE_TOKEN=""
TEST_USER_GHOST_TOKEN=""

################################################################################
# HELPER FUNCTIONS
################################################################################

print_header() {
    echo -e "\n${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}\n"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TOTAL_TESTS++))
}

print_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASSED_TESTS++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAILED_TESTS++))
}

print_info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

print_db_verify() {
    echo -e "${MAGENTA}[DB VERIFY]${NC} $1"
}

# Execute database query and show result
db_query() {
    local query="$1"
    echo -e "${CYAN}SQL:${NC} $query"
    docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "$query"
}

# Execute database query silently and return result
db_query_silent() {
    local query="$1"
    docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "$query" | xargs
}

# Make API call and show response
api_call() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local data="$4"

    echo -e "${CYAN}API:${NC} $method $endpoint"

    if [ -z "$data" ]; then
        response=$(curl -s -X $method "$API_URL$endpoint" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json")
    else
        response=$(curl -s -X $method "$API_URL$endpoint" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi

    echo -e "${GREEN}Response:${NC} $response"
    echo "$response"
}

# Generate JWT token for test user
generate_token() {
    local user_id="$1"
    local email="$2"
    local subscription="${3:-premium}"
    local ghost_mode="${4:-false}"

    docker exec auth-api python -c "
from jose import jwt
from datetime import datetime, timedelta

SECRET_KEY = 'dev-secret-key-change-in-production'
ALGORITHM = 'HS256'

payload = {
    'sub': '$user_id',
    'email': '$email',
    'subscription_level': '$subscription',
    'ghost_mode': $ghost_mode,
    'exp': datetime.utcnow() + timedelta(hours=24)
}

token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
print(token)
" 2>/dev/null
}

################################################################################
# SETUP
################################################################################

print_header "SOCIAL API COMPREHENSIVE TEST SUITE"

print_info "Checking API health..."
health_response=$(curl -s "$API_URL/health")
if echo "$health_response" | grep -q "healthy"; then
    print_success "API is healthy"
    echo "$health_response"
else
    print_fail "API is not responding correctly"
    exit 1
fi

print_header "TEST USER SETUP"

print_info "Creating test users in database..."

# Create test user 1 (premium)
TEST_USER_1=$(docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
INSERT INTO activity.users (username, email, first_name, last_name, subscription_level, ghost_mode)
VALUES ('test_user_1_$(date +%s)', 'test1@socialapi.test', 'Test', 'User One', 'premium', false)
RETURNING user_id;
" | xargs)

# Create test user 2 (premium)
TEST_USER_2=$(docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
INSERT INTO activity.users (username, email, first_name, last_name, subscription_level, ghost_mode)
VALUES ('test_user_2_$(date +%s)', 'test2@socialapi.test', 'Test', 'User Two', 'premium', false)
RETURNING user_id;
" | xargs)

# Create test user 3 (premium)
TEST_USER_3=$(docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
INSERT INTO activity.users (username, email, first_name, last_name, subscription_level, ghost_mode)
VALUES ('test_user_3_$(date +%s)', 'test3@socialapi.test', 'Test', 'User Three', 'premium', false)
RETURNING user_id;
" | xargs)

# Create free tier user
TEST_USER_FREE=$(docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
INSERT INTO activity.users (username, email, first_name, last_name, subscription_level, ghost_mode)
VALUES ('test_user_free_$(date +%s)', 'testfree@socialapi.test', 'Free', 'User', 'free', false)
RETURNING user_id;
" | xargs)

# Create ghost mode user
TEST_USER_GHOST=$(docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
INSERT INTO activity.users (username, email, first_name, last_name, subscription_level, ghost_mode)
VALUES ('test_user_ghost_$(date +%s)', 'testghost@socialapi.test', 'Ghost', 'User', 'premium', true)
RETURNING user_id;
" | xargs)

print_success "Created test users"
echo "User 1 (Premium): $TEST_USER_1"
echo "User 2 (Premium): $TEST_USER_2"
echo "User 3 (Premium): $TEST_USER_3"
echo "User Free: $TEST_USER_FREE"
echo "User Ghost: $TEST_USER_GHOST"

print_info "Generating JWT tokens..."
TEST_USER_1_TOKEN=$(generate_token "$TEST_USER_1" "test1@socialapi.test" "premium" "false")
TEST_USER_2_TOKEN=$(generate_token "$TEST_USER_2" "test2@socialapi.test" "premium" "false")
TEST_USER_3_TOKEN=$(generate_token "$TEST_USER_3" "test3@socialapi.test" "premium" "false")
TEST_USER_FREE_TOKEN=$(generate_token "$TEST_USER_FREE" "testfree@socialapi.test" "free" "false")
TEST_USER_GHOST_TOKEN=$(generate_token "$TEST_USER_GHOST" "testghost@socialapi.test" "premium" "true")

print_success "JWT tokens generated"

################################################################################
# FRIENDSHIP TESTS
################################################################################

print_header "FRIENDSHIP WORKFLOW TESTS (8 endpoints)"

# Test 1: Send friend request
print_test "Send friend request from User1 to User2"
response=$(api_call "POST" "/social/friends/request" "$TEST_USER_1_TOKEN" "{\"target_user_id\": \"$TEST_USER_2\"}")
if echo "$response" | grep -q "pending"; then
    print_success "Friend request sent successfully"

    print_db_verify "Checking friendship in database..."
    db_query "SELECT user_id_1, user_id_2, status, initiated_by FROM activity.friendships WHERE (user_id_1='$TEST_USER_1' AND user_id_2='$TEST_USER_2') OR (user_id_1='$TEST_USER_2' AND user_id_2='$TEST_USER_1');"
else
    print_fail "Failed to send friend request"
fi

# Test 2: Check friendship status
print_test "Check friendship status between User1 and User2"
response=$(api_call "GET" "/social/friends/status/$TEST_USER_2" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "pending"; then
    print_success "Friendship status shows 'pending'"
else
    print_fail "Friendship status incorrect"
fi

# Test 3: Get pending friend requests (received by User2)
print_test "Get pending friend requests for User2"
response=$(api_call "GET" "/social/friends/requests/received" "$TEST_USER_2_TOKEN")
if echo "$response" | grep -q "$TEST_USER_1"; then
    print_success "User2 sees friend request from User1"
else
    print_fail "User2 doesn't see friend request"
fi

# Test 4: Get sent friend requests (sent by User1)
print_test "Get sent friend requests for User1"
response=$(api_call "GET" "/social/friends/requests/sent" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "$TEST_USER_2"; then
    print_success "User1 sees sent friend request to User2"
else
    print_fail "User1 doesn't see sent request"
fi

# Test 5: Accept friend request
print_test "User2 accepts friend request from User1"
response=$(api_call "POST" "/social/friends/accept" "$TEST_USER_2_TOKEN" "{\"requester_user_id\": \"$TEST_USER_1\"}")
if echo "$response" | grep -q "accepted"; then
    print_success "Friend request accepted"

    print_db_verify "Verifying accepted friendship in database..."
    db_query "SELECT user_id_1, user_id_2, status, accepted_at IS NOT NULL as has_accepted_at FROM activity.friendships WHERE (user_id_1='$TEST_USER_1' AND user_id_2='$TEST_USER_2') OR (user_id_1='$TEST_USER_2' AND user_id_2='$TEST_USER_1');"
else
    print_fail "Failed to accept friend request"
fi

# Test 6: Get friends list for User1
print_test "Get friends list for User1"
response=$(api_call "GET" "/social/friends?limit=10" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "$TEST_USER_2"; then
    print_success "User1 sees User2 in friends list"
    friend_count=$(echo "$response" | grep -o '"total_count":[0-9]*' | cut -d':' -f2)
    print_info "User1 has $friend_count friend(s)"
else
    print_fail "User1 doesn't see User2 in friends list"
fi

# Test 7: Try to send duplicate friend request (error case)
print_test "Try to send duplicate friend request (should fail)"
response=$(api_call "POST" "/social/friends/request" "$TEST_USER_1_TOKEN" "{\"target_user_id\": \"$TEST_USER_2\"}")
if echo "$response" | grep -qi "exists\|error\|already"; then
    print_success "Duplicate friend request correctly rejected"
else
    print_fail "Duplicate friend request not properly handled"
fi

# Test 8: User1 sends friend request to User3
print_test "Send friend request from User1 to User3"
response=$(api_call "POST" "/social/friends/request" "$TEST_USER_1_TOKEN" "{\"target_user_id\": \"$TEST_USER_3\"}")
if echo "$response" | grep -q "pending"; then
    print_success "Friend request to User3 sent"
fi

# Test 9: Decline friend request
print_test "User3 declines friend request from User1"
response=$(api_call "POST" "/social/friends/decline" "$TEST_USER_3_TOKEN" "{\"requester_user_id\": \"$TEST_USER_1\"}")
if echo "$response" | grep -qi "declined\|message"; then
    print_success "Friend request declined"

    print_db_verify "Verifying friendship removed from database..."
    count=$(db_query_silent "SELECT COUNT(*) FROM activity.friendships WHERE (user_id_1='$TEST_USER_1' AND user_id_2='$TEST_USER_3') OR (user_id_1='$TEST_USER_3' AND user_id_2='$TEST_USER_1');")
    if [ "$count" = "0" ]; then
        print_success "Friendship correctly removed from database"
    else
        print_fail "Friendship still exists in database after decline"
    fi
else
    print_fail "Failed to decline friend request"
fi

# Test 10: Remove friend
print_test "User1 removes User2 as friend"
response=$(api_call "DELETE" "/social/friends/$TEST_USER_2" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -qi "removed\|message"; then
    print_success "Friend removed successfully"

    print_db_verify "Verifying friendship removed from database..."
    count=$(db_query_silent "SELECT COUNT(*) FROM activity.friendships WHERE (user_id_1='$TEST_USER_1' AND user_id_2='$TEST_USER_2') OR (user_id_1='$TEST_USER_2' AND user_id_2='$TEST_USER_1');")
    if [ "$count" = "0" ]; then
        print_success "Friendship correctly removed from database"
    else
        print_fail "Friendship still exists in database"
    fi
else
    print_fail "Failed to remove friend"
fi

################################################################################
# BLOCKING TESTS
################################################################################

print_header "BLOCKING WORKFLOW TESTS (5 endpoints)"

# Test 11: Block user
print_test "User1 blocks User2"
response=$(api_call "POST" "/social/blocks" "$TEST_USER_1_TOKEN" "{\"blocked_user_id\": \"$TEST_USER_2\", \"reason\": \"Test blocking\"}")
if echo "$response" | grep -q "blocked"; then
    print_success "User2 blocked successfully"

    print_db_verify "Verifying block in database..."
    db_query "SELECT blocker_user_id, blocked_user_id, reason, created_at FROM activity.user_blocks WHERE blocker_user_id='$TEST_USER_1' AND blocked_user_id='$TEST_USER_2';"
else
    print_fail "Failed to block user"
fi

# Test 12: Check block status
print_test "Check block status between User1 and User2"
response=$(api_call "GET" "/social/blocks/status/$TEST_USER_2" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "true"; then
    print_success "Block status shows correctly"
else
    print_fail "Block status incorrect"
fi

# Test 13: Get blocked users list
print_test "Get blocked users list for User1"
response=$(api_call "GET" "/social/blocks" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "$TEST_USER_2"; then
    print_success "User1 sees User2 in blocked list"
    block_count=$(echo "$response" | grep -o '"total_count":[0-9]*' | cut -d':' -f2)
    print_info "User1 has blocked $block_count user(s)"
else
    print_fail "User2 not in blocked list"
fi

# Test 14: Check can-interact with standard activity
print_test "Check can-interact for standard activity (should be false)"
response=$(api_call "GET" "/social/blocks/can-interact/$TEST_USER_2?activity_type=standard" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q '"can_interact":false'; then
    print_success "Can-interact correctly returns false for blocked user"
else
    print_fail "Can-interact should be false for blocked user"
fi

# Test 15: Check can-interact with XXL activity (exception)
print_test "Check can-interact for XXL activity (should be true - XXL exception)"
response=$(api_call "GET" "/social/blocks/can-interact/$TEST_USER_2?activity_type=xxl" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q '"can_interact":true' && echo "$response" | grep -q "xxl_exception"; then
    print_success "XXL blocking exception works correctly"
else
    print_fail "XXL blocking exception not working"
fi

# Test 16: Try to send friend request when blocked (error case)
print_test "Try to send friend request when blocked (should fail)"
response=$(api_call "POST" "/social/friends/request" "$TEST_USER_2_TOKEN" "{\"target_user_id\": \"$TEST_USER_1\"}")
if echo "$response" | grep -qi "blocked\|error\|cannot"; then
    print_success "Friend request correctly blocked"
else
    print_fail "Friend request should be blocked"
fi

# Test 17: Unblock user
print_test "User1 unblocks User2"
response=$(api_call "DELETE" "/social/blocks/$TEST_USER_2" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -qi "unblocked\|message"; then
    print_success "User2 unblocked successfully"

    print_db_verify "Verifying block removed from database..."
    count=$(db_query_silent "SELECT COUNT(*) FROM activity.user_blocks WHERE blocker_user_id='$TEST_USER_1' AND blocked_user_id='$TEST_USER_2';")
    if [ "$count" = "0" ]; then
        print_success "Block correctly removed from database"
    else
        print_fail "Block still exists in database"
    fi
else
    print_fail "Failed to unblock user"
fi

################################################################################
# FAVORITES TESTS
################################################################################

print_header "FAVORITES WORKFLOW TESTS (5 endpoints)"

# Test 18: Favorite user
print_test "User1 favorites User2"
response=$(api_call "POST" "/social/favorites" "$TEST_USER_1_TOKEN" "{\"favorited_user_id\": \"$TEST_USER_2\"}")
if echo "$response" | grep -q "favorited\|favoriting"; then
    print_success "User2 favorited successfully"

    print_db_verify "Verifying favorite in database..."
    db_query "SELECT favoriting_user_id, favorited_user_id, created_at FROM activity.user_favorites WHERE favoriting_user_id='$TEST_USER_1' AND favorited_user_id='$TEST_USER_2';"
else
    print_fail "Failed to favorite user"
fi

# Test 19: Check favorite status
print_test "Check favorite status"
response=$(api_call "GET" "/social/favorites/status/$TEST_USER_2" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "true\|favorited"; then
    print_success "Favorite status shows correctly"
else
    print_fail "Favorite status incorrect"
fi

# Test 20: Get my favorites list
print_test "Get User1's favorites list"
response=$(api_call "GET" "/social/favorites/mine" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "$TEST_USER_2"; then
    print_success "User1 sees User2 in favorites list"
    fav_count=$(echo "$response" | grep -o '"total_count":[0-9]*' | cut -d':' -f2)
    print_info "User1 has $fav_count favorite(s)"
else
    print_fail "User2 not in favorites list"
fi

# Test 21: Who favorited me (premium feature)
print_test "User2 checks who favorited them (premium feature)"
response=$(api_call "GET" "/social/favorites/who-favorited-me" "$TEST_USER_2_TOKEN")
if echo "$response" | grep -q "$TEST_USER_1"; then
    print_success "Premium feature: User2 can see User1 favorited them"
else
    print_fail "User2 should see User1 in who-favorited-me"
fi

# Test 22: Who favorited me with free tier (should fail)
print_test "Free tier user tries to access who-favorited-me (should fail)"
response=$(api_call "GET" "/social/favorites/who-favorited-me" "$TEST_USER_FREE_TOKEN")
if echo "$response" | grep -qi "premium\|subscription\|error\|403"; then
    print_success "Premium feature correctly restricted for free tier"
else
    print_fail "Free tier should not access who-favorited-me"
fi

# Test 23: Unfavorite user
print_test "User1 unfavorites User2"
response=$(api_call "DELETE" "/social/favorites/$TEST_USER_2" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -qi "unfavorited\|removed\|message"; then
    print_success "User2 unfavorited successfully"

    print_db_verify "Verifying favorite removed from database..."
    count=$(db_query_silent "SELECT COUNT(*) FROM activity.user_favorites WHERE favoriting_user_id='$TEST_USER_1' AND favorited_user_id='$TEST_USER_2';")
    if [ "$count" = "0" ]; then
        print_success "Favorite correctly removed from database"
    else
        print_fail "Favorite still exists in database"
    fi
else
    print_fail "Failed to unfavorite user"
fi

################################################################################
# PROFILE VIEWS TESTS
################################################################################

print_header "PROFILE VIEWS WORKFLOW TESTS (3 endpoints)"

# Test 24: Record profile view
print_test "User1 views User2's profile"
response=$(api_call "POST" "/social/profile-views" "$TEST_USER_1_TOKEN" "{\"viewed_user_id\": \"$TEST_USER_2\"}")
if echo "$response" | grep -qi "recorded\|success\|view"; then
    print_success "Profile view recorded"

    print_db_verify "Verifying profile view in database..."
    db_query "SELECT viewer_user_id, viewed_user_id, created_at FROM activity.profile_views WHERE viewer_user_id='$TEST_USER_1' AND viewed_user_id='$TEST_USER_2' ORDER BY created_at DESC LIMIT 1;"
else
    print_fail "Failed to record profile view"
fi

# Test 25: Get profile view count
print_test "User2 checks their profile view count"
response=$(api_call "GET" "/social/profile-views/my-count" "$TEST_USER_2_TOKEN")
if echo "$response" | grep -q "total_views"; then
    print_success "Profile view count retrieved"
    total_views=$(echo "$response" | grep -o '"total_views":[0-9]*' | cut -d':' -f2)
    print_info "User2 has $total_views total profile view(s)"
else
    print_fail "Failed to get profile view count"
fi

# Test 26: Who viewed my profile (premium feature)
print_test "User2 checks who viewed their profile (premium feature)"
response=$(api_call "GET" "/social/profile-views/who-viewed-me" "$TEST_USER_2_TOKEN")
if echo "$response" | grep -q "$TEST_USER_1"; then
    print_success "Premium feature: User2 can see User1 viewed them"
else
    print_fail "User2 should see User1 viewed them"
fi

# Test 27: Ghost mode profile view
print_test "Ghost mode user views User2's profile (should not be stored)"
initial_count=$(db_query_silent "SELECT COUNT(*) FROM activity.profile_views WHERE viewer_user_id='$TEST_USER_GHOST' AND viewed_user_id='$TEST_USER_2';")
response=$(api_call "POST" "/social/profile-views" "$TEST_USER_GHOST_TOKEN" "{\"viewed_user_id\": \"$TEST_USER_2\"}")
sleep 1
final_count=$(db_query_silent "SELECT COUNT(*) FROM activity.profile_views WHERE viewer_user_id='$TEST_USER_GHOST' AND viewed_user_id='$TEST_USER_2';")

if [ "$initial_count" = "$final_count" ]; then
    print_success "Ghost mode: Profile view NOT stored in database (as expected)"
else
    print_fail "Ghost mode: Profile view was stored (should not be)"
fi

################################################################################
# USER SEARCH TESTS
################################################################################

print_header "USER SEARCH TESTS (1 endpoint)"

# Test 28: Search users by username
print_test "Search for users with 'test' in username"
response=$(api_call "GET" "/social/users/search?q=test&limit=5" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -q "users"; then
    print_success "User search executed successfully"
    result_count=$(echo "$response" | grep -o '"total_count":[0-9]*' | cut -d':' -f2)
    print_info "Found $result_count user(s) matching 'test'"
else
    print_fail "User search failed"
fi

# Test 29: Search with minimum length requirement (error case)
print_test "Try to search with 1 character (should fail - min 2 required)"
response=$(api_call "GET" "/social/users/search?q=a" "$TEST_USER_1_TOKEN")
if echo "$response" | grep -qi "error\|2 character\|validation"; then
    print_success "Minimum search length validation works"
else
    print_fail "Should enforce minimum 2 character search"
fi

################################################################################
# ERROR CASES & EDGE CASES
################################################################################

print_header "ERROR CASES & EDGE CASES"

# Test 30: Try to friend yourself (error case)
print_test "Try to send friend request to yourself (should fail)"
response=$(api_call "POST" "/social/friends/request" "$TEST_USER_1_TOKEN" "{\"target_user_id\": \"$TEST_USER_1\"}")
if echo "$response" | grep -qi "self\|yourself\|error\|cannot"; then
    print_success "Self-friending correctly prevented"
else
    print_fail "Should not allow friending yourself"
fi

# Test 31: Try to block yourself (error case)
print_test "Try to block yourself (should fail)"
response=$(api_call "POST" "/social/blocks" "$TEST_USER_1_TOKEN" "{\"blocked_user_id\": \"$TEST_USER_1\"}")
if echo "$response" | grep -qi "self\|yourself\|error\|cannot"; then
    print_success "Self-blocking correctly prevented"
else
    print_fail "Should not allow blocking yourself"
fi

# Test 32: Try to favorite yourself (error case)
print_test "Try to favorite yourself (should fail)"
response=$(api_call "POST" "/social/favorites" "$TEST_USER_1_TOKEN" "{\"favorited_user_id\": \"$TEST_USER_1\"}")
if echo "$response" | grep -qi "self\|yourself\|error\|cannot"; then
    print_success "Self-favoriting correctly prevented"
else
    print_fail "Should not allow favoriting yourself"
fi

# Test 33: Try to access endpoint without authentication (error case)
print_test "Try to access endpoint without JWT token (should fail)"
response=$(curl -s -X GET "$API_URL/social/friends")
if echo "$response" | grep -qi "unauthorized\|401\|authentication\|not authenticated"; then
    print_success "Authentication correctly required"
else
    print_fail "Should require authentication"
fi

################################################################################
# DATABASE INTEGRITY CHECKS
################################################################################

print_header "DATABASE INTEGRITY VERIFICATION"

print_db_verify "Checking all stored procedures exist..."
sp_count=$(db_query_silent "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'activity' AND routine_name LIKE 'sp_social_%';")
if [ "$sp_count" = "22" ]; then
    print_success "All 22 stored procedures present"
else
    print_fail "Expected 22 stored procedures, found $sp_count"
fi

print_db_verify "Checking friendship bidirectional constraint..."
db_query "SELECT user_id_1 < user_id_2 as is_normalized, user_id_1, user_id_2 FROM activity.friendships LIMIT 5;"

print_db_verify "Checking for orphaned records..."
orphaned=$(db_query_silent "SELECT COUNT(*) FROM activity.friendships f WHERE NOT EXISTS (SELECT 1 FROM activity.users u WHERE u.user_id = f.user_id_1) OR NOT EXISTS (SELECT 1 FROM activity.users u WHERE u.user_id = f.user_id_2);")
if [ "$orphaned" = "0" ]; then
    print_success "No orphaned friendship records"
else
    print_fail "Found $orphaned orphaned friendship record(s)"
fi

################################################################################
# CLEANUP
################################################################################

print_header "CLEANUP"

print_info "Cleaning up test data..."

# Delete all test user data
db_query "DELETE FROM activity.profile_views WHERE viewer_user_id IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST') OR viewed_user_id IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST');" >/dev/null 2>&1
db_query "DELETE FROM activity.user_favorites WHERE favoriting_user_id IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST') OR favorited_user_id IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST');" >/dev/null 2>&1
db_query "DELETE FROM activity.user_blocks WHERE blocker_user_id IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST') OR blocked_user_id IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST');" >/dev/null 2>&1
db_query "DELETE FROM activity.friendships WHERE user_id_1 IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST') OR user_id_2 IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST');" >/dev/null 2>&1
db_query "DELETE FROM activity.users WHERE user_id IN ('$TEST_USER_1', '$TEST_USER_2', '$TEST_USER_3', '$TEST_USER_FREE', '$TEST_USER_GHOST');" >/dev/null 2>&1

print_success "Test data cleaned up"

################################################################################
# FINAL SUMMARY
################################################################################

print_header "TEST SUMMARY"

echo -e "${BOLD}Total Tests:${NC} $TOTAL_TESTS"
echo -e "${GREEN}${BOLD}Passed:${NC} $PASSED_TESTS"
echo -e "${RED}${BOLD}Failed:${NC} $FAILED_TESTS"

PASS_PERCENTAGE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "${BOLD}Success Rate:${NC} ${PASS_PERCENTAGE}%"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}🎉 ALL TESTS PASSED! 🎉${NC}\n"
    exit 0
else
    echo -e "\n${RED}${BOLD}❌ SOME TESTS FAILED ❌${NC}\n"
    exit 1
fi
