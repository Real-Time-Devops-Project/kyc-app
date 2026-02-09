#!/bin/bash
set -e

# Configuration
NAMESPACE="qa"
SERVICE_NAME="kyc-ekyc-service"
PORT=3001
LOCAL_PORT=3001

echo "==============================================="
echo "💀 CHAOS TEST: Simulating Pod Failure for $SERVICE_NAME"
echo "==============================================="

# 1. Start: Verify Deployment is Healthy initially
echo "🔍 Checking initial state..."
kubectl rollout status deployment/$SERVICE_NAME -n $NAMESPACE --timeout=30s

# 2. Identify a victim pod
VICTIM_POD=$(kubectl get pod -n $NAMESPACE -l app=$SERVICE_NAME --field-selector=status.phase=Running -o jsonpath="{.items[0].metadata.name}")

if [ -z "$VICTIM_POD" ]; then
  echo "❌ Error: No running pods found for $SERVICE_NAME in namespace $NAMESPACE"
  exit 1
fi

echo "🎯 Target Victim Pod: $VICTIM_POD"

# 3. Execute Chaos: Delete the Pod
echo "🔥 DELETE ACTION: Terminating $VICTIM_POD..."
kubectl delete pod $VICTIM_POD -n $NAMESPACE --grace-period=0 --force

# 4. Wait for Recovery (Self-Healing)
echo "⏳ Waiting for Kubernetes to auto-heal..."
sleep 5 # Allow K8s to register the deletion

# Wait for all pods to be ready again
if kubectl wait --for=condition=ready pod -l app=$SERVICE_NAME -n $NAMESPACE --timeout=60s; then
    echo "✅ Recovery Successful: Pods are running."
else
    echo "❌ Recovery Failed: Pods did not come back up in time."
    exit 1
fi

# 5. Validation: Verify Application Health
echo "❤️ Verifying Service Application Health..."
NEW_POD=$(kubectl get pod -n $NAMESPACE -l app=$SERVICE_NAME --field-selector=status.phase=Running -o jsonpath="{.items[0].metadata.name}")

# Use port-forward to access the internal health endpoint
# Running in background
kubectl port-forward pod/$NEW_POD $LOCAL_PORT:$PORT -n $NAMESPACE > /dev/null 2>&1 &
PF_PID=$!

# Wait for tunnel
sleep 5

# Curl Endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$LOCAL_PORT/health)

# Cleanup
kill $PF_PID

if [ "$HTTP_CODE" -eq 200 ]; then
   echo "✅ CHAOS TEST PASSED: Service is Healthy (200 OK) after failure."
   exit 0
else
   echo "❌ CHAOS TEST FAILED: Service returned $HTTP_CODE after failure."
   exit 1
fi
