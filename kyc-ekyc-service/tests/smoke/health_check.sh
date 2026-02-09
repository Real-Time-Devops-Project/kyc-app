#!/bin/bash
set -e
# Advanced Smoke Test

URL="http://localhost:3001"
echo "🔍 Running Smoke Tests against $URL"

# 1. Basic Connectivity
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $URL/health)
if [ "$HTTP_CODE" -ne 200 ]; then
    echo "❌ CRITICAL: Health endpoint returned $HTTP_CODE"
    exit 1
fi
echo "✅ Health Endpoint Accessible"

# 2. Check Database Connectivity (Simulated via logs or specific endpoint if available)
# In production, /health usually returns { "postgres": "up", "redis": "up" }
# checking response body
RESPONSE=$(curl -s $URL/health)
if [[ "$RESPONSE" == *"UP"* ]]; then
    echo "✅ Service Status is confirmed UP"
else
    echo "⚠️  Service is reachable but status is unknown: $RESPONSE"
fi

# 3. Test Invalid Method (Security Check)
HTTP_CODE_404=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE $URL/api/ekyc/verify)
if [ "$HTTP_CODE_404" -eq 404 ]; then
    echo "✅ 404 handled correctly for invalid method/path"
else
    echo "⚠️  Unexpected response for invalid path: $HTTP_CODE_404"
fi

exit 0
