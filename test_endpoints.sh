#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================="
echo "Testing Slack Endpoints"
echo "=================================="

# Test 1: Try to access without authentication (should fail)
echo -e "\n${YELLOW}Test 1: GET /api/admin/slack/unmatched (no auth - should fail with 401)${NC}"
response=$(curl -s -w "\n%{http_code}" -X GET http://localhost:3000/api/admin/slack/unmatched -H "Content-Type: application/json")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ Correctly returned 401 Unauthorized${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Expected 401, got $http_code${NC}"
    echo "Response: $body"
fi

# Test 2: Try to access POST endpoint without authentication
echo -e "\n${YELLOW}Test 2: POST /api/admin/slack/upload (no auth - should fail with 401)${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST http://localhost:3000/api/admin/slack/upload -H "Content-Type: multipart/form-data")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ Correctly returned 401 Unauthorized${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Expected 401, got $http_code${NC}"
    echo "Response: $body"
fi

echo -e "\n${YELLOW}=================================="
echo "To test with authentication, you need to:"
echo "1. Login to get a JWT token"
echo "2. Use that token in the Authorization header"
echo "==================================${NC}"
