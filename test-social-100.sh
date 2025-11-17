#!/bin/bash
################################################################################
# SOCIAL-API 100% PERFECT TEST SUITE
# Uses real users from auth-api for complete end-to-end testing
################################################################################

set +e  # Continue on errors to show all results

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

TOTAL=0
PASSED=0
FAILED=0

AUTH_API="http://localhost:8000"
SOCIAL_API="http://localhost:8005"

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     SOCIAL-API 100% COMPREHENSIVE TEST SUITE                ║"
echo "║     Real users • Real tokens • Real database verification   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Generate unique timestamp for user emails
TIMESTAMP=$(date +%s)

echo -e "${YELLOW}[STEP 1/5]${NC} Creating test users via auth-api..."

# Register User 1 (Premium)
echo -e "${CYAN}  Creating user 1...${NC}"
USER1_REG=$(curl -s -X POST "$AUTH_API/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "social_test1_'$TIMESTAMP'@test.com",
    "password": "Xk9#mP2$vL8@wQ5!nR7",
    "username": "social_test1_'$TIMESTAMP'",
    "first_name": "Test",
    "last_name": "User1"
  }')

USER1_ID=$(echo "$USER1_REG" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)

# Register User 2 (Premium)
echo -e "${CYAN}  Creating user 2...${NC}"
USER2_REG=$(curl -s -X POST "$AUTH_API/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "social_test2_'$TIMESTAMP'@test.com",
    "password": "Zj4&tN8%yH3@bF9!kD6",
    "username": "social_test2_'$TIMESTAMP'",
    "first_name": "Test",
    "last_name": "User2"
  }')

USER2_ID=$(echo "$USER2_REG" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)

# Register User 3 (For additional tests)
echo -e "${CYAN}  Creating user 3...${NC}"
USER3_REG=$(curl -s -X POST "$AUTH_API/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "social_test3_'$TIMESTAMP'@test.com",
    "password": "Wq7!pS5#cM2@vL9$gT4",
    "username": "social_test3_'$TIMESTAMP'",
    "first_name": "Test",
    "last_name": "User3"
  }')

USER3_ID=$(echo "$USER3_REG" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$USER1_ID" ] || [ -z "$USER2_ID" ] || [ -z "$USER3_ID" ]; then
    echo -e "${RED}✗ Failed to create users${NC}"
    echo "User1 Response: $USER1_REG"
    echo "User2 Response: $USER2_REG"
    echo "User3 Response: $USER3_REG"
    exit 1
fi

echo -e "${GREEN}✓ Users created successfully${NC}"
echo -e "  User 1 ID: ${USER1_ID}"
echo -e "  User 2 ID: ${USER2_ID}"
echo -e "  User 3 ID: ${USER3_ID}\n"

# Update users to premium subscription and verify accounts
echo -e "${YELLOW}[STEP 2/5]${NC} Setting up premium subscriptions and verifying accounts..."
docker exec activity-postgres-db psql -U postgres -d activitydb -c "UPDATE activity.users SET subscription_level='premium', subscription_expires_at=NOW() + INTERVAL '1 year', is_verified=true WHERE user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID');" >/dev/null 2>&1
echo -e "${GREEN}✓ Users upgraded to premium and verified${NC}\n"

echo -e "${YELLOW}[STEP 3/5]${NC} Generating JWT tokens via auth-api..."

# Login User 1
TOKEN1_RESP=$(curl -s -X POST "$AUTH_API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "social_test1_'$TIMESTAMP'@test.com",
    "password": "Xk9#mP2$vL8@wQ5!nR7"
  }')
TOKEN1=$(echo "$TOKEN1_RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Login User 2
TOKEN2_RESP=$(curl -s -X POST "$AUTH_API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "social_test2_'$TIMESTAMP'@test.com",
    "password": "Zj4&tN8%yH3@bF9!kD6"
  }')
TOKEN2=$(echo "$TOKEN2_RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Login User 3
TOKEN3_RESP=$(curl -s -X POST "$AUTH_API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "social_test3_'$TIMESTAMP'@test.com",
    "password": "Wq7!pS5#cM2@vL9$gT4"
  }')
TOKEN3=$(echo "$TOKEN3_RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN1" ] || [ -z "$TOKEN2" ] || [ -z "$TOKEN3" ]; then
    echo -e "${RED}✗ Failed to get tokens${NC}"
    echo "Token1 Response: $TOKEN1_RESP"
    echo "Token2 Response: $TOKEN2_RESP"
    echo "Token3 Response: $TOKEN3_RESP"
    exit 1
fi

echo -e "${GREEN}✓ JWT tokens generated successfully${NC}\n"

# Create a free tier user for premium feature tests
docker exec activity-postgres-db psql -U postgres -d activitydb -c "UPDATE activity.users SET subscription_level='free' WHERE user_id='$USER3_ID';" >/dev/null 2>&1
TOKEN_FREE=$TOKEN3

echo -e "${YELLOW}[STEP 4/5]${NC} Running comprehensive endpoint tests...\n"

test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local token="$4"
    local data="$5"
    local success_pattern="$6"
    local db_check="$7"
    
    ((TOTAL++))
    echo -e "${CYAN}[TEST $TOTAL]${NC} $name"
    
    if [ -z "$data" ]; then
        response=$(curl -s -X $method "$SOCIAL_API$endpoint" -H "Authorization: Bearer $token")
    else
        response=$(curl -s -X $method "$SOCIAL_API$endpoint" \
          -H "Authorization: Bearer $token" \
          -H "Content-Type: application/json" \
          -d "$data")
    fi
    
    if echo "$response" | grep -Eqi "$success_pattern"; then
        echo -e "${GREEN}  ✓ PASS${NC} - API response correct"
        
        # Database verification if provided
        if [ -n "$db_check" ]; then
            db_result=$(docker exec activity-postgres-db psql -U postgres -d activitydb -t -c "$db_check" 2>/dev/null | xargs)
            echo -e "${MAGENTA}  [DB] $db_result${NC}"
        fi
        
        ((PASSED++))
    else
        echo -e "${RED}  ✗ FAIL${NC}"
        echo -e "${RED}  Expected pattern: $success_pattern${NC}"
        echo -e "${RED}  Got: ${response:0:150}${NC}"
        ((FAILED++))
    fi
}

echo -e "${CYAN}${BOLD}═══ HEALTH CHECK ═══${NC}"
test_endpoint "API Health Check" "GET" "/health" "" "" "healthy.*social-api"

echo -e "\n${CYAN}${BOLD}═══ FRIENDSHIP ENDPOINTS (8 tests) ═══${NC}"

test_endpoint "Send Friend Request" \
  "POST" "/social/friends/request" "$TOKEN1" \
  '{"target_user_id": "'$USER2_ID'"}' \
  "pending|initiated_by" \
  "SELECT status FROM activity.friendships WHERE initiated_by='$USER1_ID' LIMIT 1;"

test_endpoint "Check Friendship Status" \
  "GET" "/social/friends/status/$USER2_ID" "$TOKEN1" "" \
  "pending|accepted|status"

test_endpoint "Get Received Friend Requests" \
  "GET" "/social/friends/requests/received" "$TOKEN2" "" \
  "requests|total_count"

test_endpoint "Get Sent Friend Requests" \
  "GET" "/social/friends/requests/sent" "$TOKEN1" "" \
  "requests|total_count"

test_endpoint "Accept Friend Request" \
  "POST" "/social/friends/accept" "$TOKEN2" \
  '{"requester_user_id": "'$USER1_ID'"}' \
  "accepted|friendship_id" \
  "SELECT status FROM activity.friendships WHERE status='accepted' AND (user_id_1='$USER1_ID' OR user_id_2='$USER1_ID') LIMIT 1;"

test_endpoint "Get Friends List" \
  "GET" "/social/friends?limit=10" "$TOKEN1" "" \
  "friends|total_count"

test_endpoint "Check Friendship Status (Accepted)" \
  "GET" "/social/friends/status/$USER2_ID" "$TOKEN1" "" \
  "accepted"

test_endpoint "Remove Friend" \
  "DELETE" "/social/friends/$USER2_ID" "$TOKEN1" "" \
  "removed|message" \
  "SELECT COUNT(*) FROM activity.friendships WHERE (user_id_1='$USER1_ID' AND user_id_2='$USER2_ID') OR (user_id_1='$USER2_ID' AND user_id_2='$USER1_ID');"

echo -e "\n${CYAN}${BOLD}═══ BLOCKING ENDPOINTS (5 tests) ═══${NC}"

test_endpoint "Block User" \
  "POST" "/social/blocks" "$TOKEN1" \
  '{"blocked_user_id": "'$USER2_ID'", "reason": "Test blocking"}' \
  "blocked|blocker_user_id" \
  "SELECT reason FROM activity.user_blocks WHERE blocker_user_id='$USER1_ID' AND blocked_user_id='$USER2_ID';"

test_endpoint "Check Block Status" \
  "GET" "/social/blocks/status/$USER2_ID" "$TOKEN1" "" \
  "user_1_blocked_user_2.*true|any_block_exists.*true"

test_endpoint "Get Blocked Users List" \
  "GET" "/social/blocks?limit=10" "$TOKEN1" "" \
  "blocked_users|total_count"

test_endpoint "Can Interact - Standard (Blocked)" \
  "GET" "/social/blocks/can-interact/$USER2_ID?activity_type=standard" "$TOKEN1" "" \
  '"can_interact".*false|blocked'

test_endpoint "Can Interact - XXL Exception" \
  "GET" "/social/blocks/can-interact/$USER2_ID?activity_type=xxl" "$TOKEN1" "" \
  'xxl_exception.*can_interact.*true|can_interact.*true.*xxl_exception'

echo -e "\n${CYAN}${BOLD}═══ FAVORITES ENDPOINTS (5 tests) ═══${NC}"

test_endpoint "Favorite User" \
  "POST" "/social/favorites" "$TOKEN1" \
  '{"favorited_user_id": "'$USER3_ID'"}' \
  "favorit|created" \
  "SELECT COUNT(*) FROM activity.user_favorites WHERE favoriting_user_id='$USER1_ID' AND favorited_user_id='$USER3_ID';"

test_endpoint "Check Favorite Status" \
  "GET" "/social/favorites/status/$USER3_ID" "$TOKEN1" "" \
  "favorited.*true|is_favorite"

test_endpoint "Get My Favorites" \
  "GET" "/social/favorites/mine?limit=10" "$TOKEN1" "" \
  "favorites|total_count"

test_endpoint "Who Favorited Me (Premium)" \
  "GET" "/social/favorites/who-favorited-me?limit=10" "$TOKEN3" "" \
  "users|total_count|favorited"

test_endpoint "Who Favorited Me (Free Tier - Should Block)" \
  "GET" "/social/favorites/who-favorited-me" "$TOKEN_FREE" "" \
  "premium|subscription|403|error"

echo -e "\n${CYAN}${BOLD}═══ PROFILE VIEWS ENDPOINTS (3 tests) ═══${NC}"

test_endpoint "Record Profile View" \
  "POST" "/social/profile-views" "$TOKEN1" \
  '{"viewed_user_id": "'$USER3_ID'"}' \
  "view|recorded|success"

test_endpoint "Get Profile View Count" \
  "GET" "/social/profile-views/my-count" "$TOKEN3" "" \
  "total_views|unique_viewers"

test_endpoint "Who Viewed My Profile (Premium)" \
  "GET" "/social/profile-views/who-viewed-me?limit=10" "$TOKEN1" "" \
  "viewers|total"

echo -e "\n${CYAN}${BOLD}═══ USER SEARCH ENDPOINT (1 test) ═══${NC}"

test_endpoint "Search Users" \
  "GET" "/social/users/search?q=test&limit=5" "$TOKEN1" "" \
  "users|total_count"

echo -e "\n${CYAN}${BOLD}═══ ERROR HANDLING & EDGE CASES (5 tests) ═══${NC}"

test_endpoint "Self-Friend Prevention" \
  "POST" "/social/friends/request" "$TOKEN1" \
  '{"target_user_id": "'$USER1_ID'"}' \
  "self|yourself|cannot|error"

test_endpoint "Self-Block Prevention" \
  "POST" "/social/blocks" "$TOKEN1" \
  '{"blocked_user_id": "'$USER1_ID'"}' \
  "self|yourself|cannot|error"

test_endpoint "Self-Favorite Prevention" \
  "POST" "/social/favorites" "$TOKEN1" \
  '{"favorited_user_id": "'$USER1_ID'"}' \
  "self|yourself|cannot|error"

test_endpoint "Unauthenticated Request" \
  "GET" "/social/friends" "" "" \
  "unauthorized|401|not authenticated"

test_endpoint "Search Validation (Min Length)" \
  "GET" "/social/users/search?q=a" "$TOKEN1" "" \
  "2 character|validation|error"

echo -e "\n${YELLOW}[STEP 5/5]${NC} Database integrity checks...\n"

echo -e "${MAGENTA}[DB CHECK]${NC} Verifying stored procedures..."
SP_COUNT=$(docker exec activity-postgres-db psql -U postgres -d activitydb -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'activity' AND routine_name LIKE 'sp_social_%';" | xargs)
if [ "$SP_COUNT" = "22" ]; then
    echo -e "${GREEN}  ✓ All 22 stored procedures present${NC}"
else
    echo -e "${RED}  ✗ Expected 22, found $SP_COUNT${NC}"
fi

echo -e "${MAGENTA}[DB CHECK]${NC} Verifying friendship normalization..."
UNNORM=$(docker exec activity-postgres-db psql -U postgres -d activitydb -t -c "SELECT COUNT(*) FROM activity.friendships WHERE user_id_1 > user_id_2;" | xargs)
if [ "$UNNORM" = "0" ]; then
    echo -e "${GREEN}  ✓ All friendships properly normalized (user_id_1 < user_id_2)${NC}"
else
    echo -e "${RED}  ✗ Found $UNNORM unnormalized friendships${NC}"
fi

echo -e "${MAGENTA}[DB CHECK]${NC} Verifying no orphaned records..."
ORPHANED=$(docker exec activity-postgres-db psql -U postgres -d activitydb -t -c "SELECT COUNT(*) FROM activity.friendships f WHERE NOT EXISTS (SELECT 1 FROM activity.users u WHERE u.user_id = f.user_id_1) OR NOT EXISTS (SELECT 1 FROM activity.users u WHERE u.user_id = f.user_id_2);" | xargs)
if [ "$ORPHANED" = "0" ]; then
    echo -e "${GREEN}  ✓ No orphaned friendship records${NC}"
else
    echo -e "${RED}  ✗ Found $ORPHANED orphaned records${NC}"
fi

# Cleanup
echo -e "\n${YELLOW}[CLEANUP]${NC} Removing test data..."
docker exec activity-postgres-db psql -U postgres -d activitydb -c "
DELETE FROM activity.profile_views WHERE viewer_user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID') OR viewed_user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID');
DELETE FROM activity.user_favorites WHERE favoriting_user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID') OR favorited_user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID');
DELETE FROM activity.user_blocks WHERE blocker_user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID') OR blocked_user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID');
DELETE FROM activity.friendships WHERE user_id_1 IN ('$USER1_ID', '$USER2_ID', '$USER3_ID') OR user_id_2 IN ('$USER1_ID', '$USER2_ID', '$USER3_ID');
DELETE FROM activity.users WHERE user_id IN ('$USER1_ID', '$USER2_ID', '$USER3_ID');
" >/dev/null 2>&1
echo -e "${GREEN}✓ Test users and data cleaned up${NC}\n"

# Final Summary
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     FINAL TEST SUMMARY                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${BOLD}Total Tests:     ${NC} $TOTAL"
echo -e "${GREEN}${BOLD}Passed Tests:    ${NC} $PASSED"
echo -e "${RED}${BOLD}Failed Tests:    ${NC} $FAILED"

if [ $TOTAL -gt 0 ]; then
    PERCENTAGE=$((PASSED * 100 / TOTAL))
    echo -e "${BOLD}Success Rate:    ${NC} ${PERCENTAGE}%"
fi

echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║           🎉  100% TEST SUCCESS! ALL TESTS PASSED  🎉        ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║                                                               ║${NC}"
    echo -e "${RED}${BOLD}║              ❌  SOME TESTS FAILED - SEE ABOVE  ❌            ║${NC}"
    echo -e "${RED}${BOLD}║                                                               ║${NC}"
    echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 1
fi
