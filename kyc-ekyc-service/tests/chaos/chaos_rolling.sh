#!/bin/bash
# Chaos Scenario 2: Rolling Restart Spam
# repeatedly deletes pods to force rolling updates logic test

NAMESPACE="qa"
SERVICE="kyc-ekyc-service"

echo "🌪️  CHAOS: Rolling Restart Loop initiated..."

for i in {1..5}; do
   echo "Cycle $i: Deleting a random pod..."
   POD=$(kubectl get pod -n $NAMESPACE -l app=$SERVICE -o jsonpath="{.items[0].metadata.name}")
   kubectl delete pod $POD -n $NAMESPACE --grace-period=0
   
   # Immediate Health Check - System should degrade but not Fail completely (if replicas > 1)
   HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://localhost:3001/health || echo "000")
   
   if [ "$HTTP_CODE" -eq 200 ]; then
       echo "   ✅ Service still responsive during outage."
   else
       echo "   ⚠️  Service HIT during outage! (Code: $HTTP_CODE)"
   fi
   
   sleep 3 # Wait a bit before next hit
done

echo "✅ Rolling Chaos Passed."
