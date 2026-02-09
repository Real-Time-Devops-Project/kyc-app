#!/bin/bash
set -e
URL="http://localhost:3002"

echo "Running vKYC Smoke Tests..."
if curl -s -f "$URL/health" > /dev/null; then
    echo "✅ Health Check Passed"
else
    echo "❌ Health Check Failed"
    exit 1
fi

# Additional Check: Redis Connectivity Indirect Check
# If /health returns DB status, parse it here
# RESPONSE=$(curl -s $URL/health)
# if [[ $RESPONSE == *"redis"* ]]; then ... fi

exit 0
