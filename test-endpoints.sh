#!/bin/bash
################################################################################
# SOCIAL-API ENDPOINT TESTER
# Tests all 23 endpoints with database verification
################################################################################

set +e  # Continue on errors

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Counters
TOTAL=0
PASSED=0
FAILED=0

API_URL="http://localhost:8005"

# Test users (existing from previous tests)
USER1="c0a61eba-5805-494c-bc1b-563d3ca49126"
USER2="1003ad38-d6d6-426e-bbd1-9d566c82260f"
USER3="00543170-dc66-40e4-b437-6bf2655abe7d"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║         SOCIAL-API COMPREHENSIVE TEST SUITE              ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Generate tokens
echo -e "${YELLOW}[SETUP]${NC} Generating JWT tokens..."
TOKEN1=$(docker exec auth-api python -c "
from jose import jwt
from datetime import datetime, timedelta
SECRET_KEY = 'dev_secret_key_change_in_production_min_32_chars_required'
payload = {'sub': '$USER1', 'email': 'test1@test.com', 'subscription_level': 'premium', 'ghost_mode': False, 'exp': datetime.utcnow() + timedelta(hours=24)}
print(jwt.encode(payload, SECRET_KEY, algorithm='HS256'))
" 2>/dev/null)

TOKEN2=$(docker exec auth-api python -c "
from jose import jwt
from datetime import datetime, timedelta
SECRET_KEY = 'dev_secret_key_change_in_production_min_32_chars_required'
payload = {'sub': '$USER2', 'email': 'test2@test.com', 'subscription_level': 'premium', 'ghost_mode': False, 'exp': datetime.utcnow() + timedelta(hours=24)}
print(jwt.encode(payload, SECRET_KEY, algorithm='HS256'))
" 2>/dev/null)

TOKEN_FREE=$(docker exec auth-api python -c "
from jose import jwt
from datetime import datetime, timedelta
SECRET_KEY = 'dev_secret_key_change_in_production_min_32_chars_required'
payload = {'sub': '$USER3', 'email': 'test3@test.com', 'subscription_level': 'free', 'ghost_mode': False, 'exp': datetime.utcnow() + timedelta(hours=24)}
print(jwt.encode(payload, SECRET_KEY, algorithm='HS256'))
" 2>/dev/null)

TOKEN_GHOST=$(docker exec auth-api python -c "
from jose import jwt
from datetime import datetime, timedelta
SECRET_KEY = 'dev_secret_key_change_in_production_min_32_chars_required'
payload = {'sub': '$USER3', 'email': 'test3@test.com', 'subscription_level': 'premium', 'ghost_mode': True, 'exp': datetime.utcnow() + timedelta(hours=24)}
print(jwt.encode(payload, SECRET_KEY, algorithm='HS256'))
" 2>/dev/null)

echo -e "${GREEN}✓${NC} Tokens generated\n"

# Helper functions
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local token="$4"
    local data="$5"
    local expected="$6"
    
    ((TOTAL++))
    echo -e "${CYAN}[TEST $TOTAL]${NC} $name"
    
    if [ -z "$data" ]; then
        response=$(curl -s -X $method "$API_URL$endpoint" -H "Authorization: Bearer $token")
    else
        response=$(curl -s -X $method "$API_URL$endpoint" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$data")
    fi
    
    if echo "$response" | grep -qi "$expected"; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}  ✗ FAIL${NC} - Expected: $expected"
        echo -e "${RED}  Response: ${response:0:100}${NC}"
        ((FAILED++))
    fi
}

db_count() {
    local query="$1"
    docker exec activity-postgres-db psql -U postgres -d activitydb -t -c "$query" | xargs
}

echo -e "${CYAN}${BOLD}═══ HEALTH CHECK ═══${NC}"
test_endpoint "API Health" "GET" "/health" "" "" "healthy"

echo -e "\n${CYAN}${BOLD}═══ FRIENDSHIP ENDPOINTS (8) ═══${NC}"
test_endpoint "Send Friend Request" "POST" "/social/friends/request" "$TOKEN1" "{\"target_user_id\": \"$USER2\"}" "pending\|exists\|already"
test_endpoint "Check Friendship Status" "GET" "/social/friends/status/$USER2" "$TOKEN1" "" "status"
test_endpoint "Get Received Requests" "GET" "/social/friends/requests/received" "$TOKEN2" "" "requests\|total"
test_endpoint "Get Sent Requests" "GET" "/social/friends/requests/sent" "$TOKEN1" "" "requests\|total"
test_endpoint "Accept Friend Request" "POST" "/social/friends/accept" "$TOKEN2" "{\"requester_user_id\": \"$USER1\"}" "accepted\|already\|not found"
test_endpoint "Get Friends List" "GET" "/social/friends" "$TOKEN1" "" "friends\|total"
test_endpoint "Decline Friend Request" "POST" "/social/friends/decline" "$TOKEN2" "{\"requester_user_id\": \"$USER3\"}" "declined\|not found"
test_endpoint "Remove Friend" "DELETE" "/social/friends/$USER2" "$TOKEN1" "" "removed\|not found"

echo -e "\n${CYAN}${BOLD}═══ BLOCKING ENDPOINTS (5) ═══${NC}"
test_endpoint "Block User" "POST" "/social/blocks" "$TOKEN1" "{\"blocked_user_id\": \"$USER2\", \"reason\": \"Test block\"}" "blocked\|already"
test_endpoint "Check Block Status" "GET" "/social/blocks/status/$USER2" "$TOKEN1" "" "block\|true\|false"
test_endpoint "Get Blocked Users" "GET" "/social/blocks" "$TOKEN1" "" "blocked_users\|total"
test_endpoint "Can Interact (Standard)" "GET" "/social/blocks/can-interact/$USER2?activity_type=standard" "$TOKEN1" "" "can_interact"
test_endpoint "Can Interact (XXL Exception)" "GET" "/social/blocks/can-interact/$USER2?activity_type=xxl" "$TOKEN1" "" "xxl_exception\|can_interact"

echo -e "\n${CYAN}${BOLD}═══ FAVORITES ENDPOINTS (5) ═══${NC}"
test_endpoint "Favorite User" "POST" "/social/favorites" "$TOKEN1" "{\"favorited_user_id\": \"$USER2\"}" "favorit\|already"
test_endpoint "Check Favorite Status" "GET" "/social/favorites/status/$USER2" "$TOKEN1" "" "status\|favorited"
test_endpoint "Get My Favorites" "GET" "/social/favorites/mine" "$TOKEN1" "" "favorites\|total"
test_endpoint "Who Favorited Me (Premium)" "GET" "/social/favorites/who-favorited-me" "$TOKEN1" "" "users\|total\|favorited"
test_endpoint "Who Favorited Me (Free - Should Fail)" "GET" "/social/favorites/who-favorited-me" "$TOKEN_FREE" "" "premium\|subscription\|error"

echo -e "\n${CYAN}${BOLD}═══ PROFILE VIEWS ENDPOINTS (3) ═══${NC}"
test_endpoint "Record Profile View" "POST" "/social/profile-views" "$TOKEN1" "{\"viewed_user_id\": \"$USER2\"}" "view\|recorded\|success"
test_endpoint "Get Profile View Count" "GET" "/social/profile-views/my-count" "$TOKEN2" "" "total_views\|count"
test_endpoint "Who Viewed Me (Premium)" "GET" "/social/profile-views/who-viewed-me" "$TOKEN1" "" "viewers\|total\|viewed"

echo -e "\n${CYAN}${BOLD}═══ USER SEARCH ENDPOINT (1) ═══${NC}"
test_endpoint "Search Users" "GET" "/social/users/search?q=test&limit=5" "$TOKEN1" "" "users\|total"

echo -e "\n${CYAN}${BOLD}═══ ERROR CASES ═══${NC}"
test_endpoint "Self-Friend (Should Fail)" "POST" "/social/friends/request" "$TOKEN1" "{\"target_user_id\": \"$USER1\"}" "self\|yourself\|error\|cannot"
test_endpoint "Self-Block (Should Fail)" "POST" "/social/blocks" "$TOKEN1" "{\"blocked_user_id\": \"$USER1\"}" "self\|yourself\|error\|cannot"
test_endpoint "Self-Favorite (Should Fail)" "POST" "/social/favorites" "$TOKEN1" "{\"favorited_user_id\": \"$USER1\"}" "self\|yourself\|error\|cannot"
test_endpoint "No Auth (Should Fail)" "GET" "/social/friends" "" "" "unauthorized\|401\|not authenticated"
test_endpoint "Search Too Short (Should Fail)" "GET" "/social/users/search?q=a" "$TOKEN1" "" "2 character\|validation\|error"

echo -e "\n${CYAN}${BOLD}═══ DATABASE VERIFICATION ═══${NC}"
echo -e "${YELLOW}[DB CHECK]${NC} Counting stored procedures..."
SP_COUNT=$(db_count "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'activity' AND routine_name LIKE 'sp_social_%';")
if [ "$SP_COUNT" = "22" ]; then
    echo -e "${GREEN}  ✓${NC} All 22 stored procedures present"
else
    echo -e "${RED}  ✗${NC} Expected 22 stored procedures, found $SP_COUNT"
fi

echo -e "${YELLOW}[DB CHECK]${NC} Checking friendship normalization..."
UNNORMALIZED=$(db_count "SELECT COUNT(*) FROM activity.friendships WHERE user_id_1 > user_id_2;")
if [ "$UNNORMALIZED" = "0" ]; then
    echo -e "${GREEN}  ✓${NC} All friendships properly normalized"
else
    echo -e "${RED}  ✗${NC} Found $UNNORMALIZED unnormalized friendships"
fi

# Cleanup
echo -e "\n${YELLOW}[CLEANUP]${NC} Removing test data..."
docker exec activity-postgres-db psql -U postgres -d activitydb -c "DELETE FROM activity.user_blocks WHERE blocker_user_id='$USER1' AND blocked_user_id='$USER2';" >/dev/null 2>&1
docker exec activity-postgres-db psql -U postgres -d activitydb -c "DELETE FROM activity.user_favorites WHERE favoriting_user_id='$USER1' AND favorited_user_id='$USER2';" >/dev/null 2>&1
echo -e "${GREEN}  ✓${NC} Cleanup complete"

# Summary
echo -e "\n${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                    TEST SUMMARY                          ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "${BOLD}Total Tests:${NC} $TOTAL"
echo -e "${GREEN}${BOLD}Passed:${NC} $PASSED${NC}"
echo -e "${RED}${BOLD}Failed:${NC} $FAILED${NC}"
PERCENTAGE=$((PASSED * 100 / TOTAL))
echo -e "${BOLD}Success Rate:${NC} $PERCENTAGE%\n"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED! 🎉${NC}\n"
    exit 0
else
    echo -e "${YELLOW}${BOLD}⚠  Some tests failed - see details above${NC}\n"
    exit 1
fi
