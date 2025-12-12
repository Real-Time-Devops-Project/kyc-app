# 🎯 Zero Trust Security - Quick Reference Cheat Sheet

A one-page reference guide for Zero Trust concepts and commands.

---

## 📖 Core Principles (Remember: VLA)

```
┌─────────────────────────────────────────┐
│  V - Verify Explicitly                  │
│  L - Least Privilege Access             │
│  A - Assume Breach                      │
└─────────────────────────────────────────┘
```

---

## 🔑 Key Concepts

| Concept | What It Means | Example |
|:--------|:--------------|:--------|
| **Verify Explicitly** | Never trust, always verify | Check user identity + device health + location |
| **Least Privilege** | Minimum permissions needed | Developer can read logs, not delete databases |
| **Assume Breach** | Plan for compromise | Segment network so breach in one service doesn't affect others |
| **Micro-Segmentation** | Divide network into tiny zones | Each microservice in its own security zone |
| **Just-in-Time (JIT)** | Temporary access | 2-hour access to production, then auto-expire |
| **mTLS** | Mutual TLS encryption | Both client and server verify each other's identity |

---

## 🛠️ Quick Commands

### Kubernetes Network Policies

```bash
# Apply network policies
kubectl apply -f network-policies.yaml

# List all policies
kubectl get networkpolicies -n kyc-app

# Describe a specific policy
kubectl describe networkpolicy frontend-policy -n kyc-app

# Test connectivity (should fail if blocked)
kubectl exec -it <pod-name> -n kyc-app -- curl http://database:5432

# Delete all policies (for testing)
kubectl delete networkpolicies --all -n kyc-app
```

---

### AWS Secrets Manager

```bash
# Create a secret
aws secretsmanager create-secret \
  --name prod/app/database \
  --secret-string '{"user":"admin","pass":"secret123"}'

# Retrieve a secret
aws secretsmanager get-secret-value \
  --secret-id prod/app/database \
  --query SecretString \
  --output text

# Update a secret
aws secretsmanager update-secret \
  --secret-id prod/app/database \
  --secret-string '{"user":"admin","pass":"newsecret456"}'

# Enable automatic rotation
aws secretsmanager rotate-secret \
  --secret-id prod/app/database \
  --rotation-lambda-arn arn:aws:lambda:region:account:function:rotator
```

---

### AWS Session Manager (SSH Replacement)

```bash
# Connect to instance (no SSH key needed!)
aws ssm start-session --target i-1234567890abcdef0

# Port forwarding (access RDS locally)
aws ssm start-session \
  --target i-1234567890abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5432"],"localPortNumber":["5432"]}'

# Run a single command
aws ssm send-command \
  --instance-ids i-1234567890abcdef0 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["df -h"]'
```

---

### IAM Policy Testing

```bash
# Simulate IAM policy
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789:role/MyRole \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/*

# Check who you are
aws sts get-caller-identity

# Assume a role (temporary credentials)
aws sts assume-role \
  --role-arn arn:aws:iam::123456789:role/MyRole \
  --role-session-name my-session
```

---

### GuardDuty

```bash
# Enable GuardDuty
aws guardduty create-detector --enable

# List findings
aws guardduty list-findings \
  --detector-id <detector-id>

# Get finding details
aws guardduty get-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id>
```

---

### Istio Service Mesh

```bash
# Install Istio
istioctl install --set profile=default -y

# Enable sidecar injection for namespace
kubectl label namespace kyc-app istio-injection=enabled

# Verify mTLS is working
istioctl authn tls-check <pod-name>.<namespace>

# View service mesh dashboard
istioctl dashboard kiali
```

---

## 📋 Network Policy Templates

### Template 1: Default Deny All

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Template 2: Allow Specific Service

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Template 3: Allow DNS

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

---

## 🔐 IAM Policy Templates

### Template 1: Require MFA

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "BoolIfExists": {
        "aws:MultiFactorAuthPresent": "false"
      }
    }
  }]
}
```

### Template 2: Least Privilege (S3 Read-Only)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:ListBucket"
    ],
    "Resource": [
      "arn:aws:s3:::my-bucket",
      "arn:aws:s3:::my-bucket/*"
    ]
  }]
}
```

### Template 3: Time-Based Access

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "ec2:*",
    "Resource": "*",
    "Condition": {
      "DateGreaterThan": {
        "aws:CurrentTime": "2025-01-01T09:00:00Z"
      },
      "DateLessThan": {
        "aws:CurrentTime": "2025-01-01T17:00:00Z"
      }
    }
  }]
}
```

---

## 🚨 Security Incident Response

### Step 1: Detect
```bash
# Check GuardDuty findings
aws guardduty list-findings --detector-id <id>

# Check CloudTrail for suspicious activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=suspicious-user
```

### Step 2: Isolate
```bash
# Revoke all sessions for a user
aws iam delete-access-key --access-key-id AKIAIOSFODNN7EXAMPLE --user-name BadUser

# Isolate a pod with network policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-compromised-pod
spec:
  podSelector:
    matchLabels:
      app: compromised-app
  policyTypes:
  - Ingress
  - Egress
EOF
```

### Step 3: Investigate
```bash
# Get pod logs
kubectl logs <pod-name> -n kyc-app --previous

# Check CloudTrail events
aws cloudtrail lookup-events \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z
```

### Step 4: Remediate
```bash
# Rotate compromised secrets
aws secretsmanager rotate-secret --secret-id prod/app/database

# Update deployment with new image
kubectl set image deployment/app app=new-image:v2 -n kyc-app

# Restart all pods
kubectl rollout restart deployment/app -n kyc-app
```

---

## 📊 Monitoring & Alerting

### CloudWatch Alarms

```bash
# Create alarm for failed login attempts
aws cloudwatch put-metric-alarm \
  --alarm-name failed-logins \
  --alarm-description "Alert on failed login attempts" \
  --metric-name FailedLoginCount \
  --namespace ZeroTrust/Security \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### Log Queries

```bash
# Query CloudWatch Logs
aws logs filter-log-events \
  --log-group-name /aws/eks/cluster \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000

# Tail logs in real-time
aws logs tail /aws/eks/cluster --follow
```

---

## 🎯 Troubleshooting

### Network Policy Issues

```bash
# Problem: Pod can't connect to service
# Solution: Check if network policy is blocking

# 1. Check if policies exist
kubectl get networkpolicies -n kyc-app

# 2. Describe the policy
kubectl describe networkpolicy <policy-name> -n kyc-app

# 3. Test connectivity
kubectl exec -it <pod> -n kyc-app -- nc -zv <service> <port>

# 4. Temporarily disable (for testing only!)
kubectl delete networkpolicy <policy-name> -n kyc-app
```

### IAM Permission Issues

```bash
# Problem: Access denied error
# Solution: Check IAM permissions

# 1. Check current identity
aws sts get-caller-identity

# 2. Simulate policy
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123:role/MyRole \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::bucket/*

# 3. Check CloudTrail for denied requests
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AccessDenied
```

### Secret Access Issues

```bash
# Problem: Can't access secret from pod
# Solution: Check IRSA and ExternalSecret

# 1. Check if ExternalSecret is synced
kubectl get externalsecret -n kyc-app

# 2. Check if K8s secret was created
kubectl get secret db-secrets -n kyc-app

# 3. Describe ExternalSecret for errors
kubectl describe externalsecret database-credentials -n kyc-app

# 4. Check pod service account
kubectl get pod <pod-name> -n kyc-app -o yaml | grep serviceAccount
```

---

## 📚 Quick Reference Links

| Resource | Link |
|:---------|:-----|
| Full Guide | [ZERO_TRUST_SECURITY.md](./ZERO_TRUST_SECURITY.md) |
| Implementation Examples | [ZERO_TRUST_IMPLEMENTATION_EXAMPLES.md](./ZERO_TRUST_IMPLEMENTATION_EXAMPLES.md) |
| Status Dashboard | [ZERO_TRUST_STATUS.md](./ZERO_TRUST_STATUS.md) |
| DevSecOps Strategy | [DEVSECOPS_STRATEGY.md](./DEVSECOPS_STRATEGY.md) |

---

## 🔢 Common Port Numbers

| Service | Port | Protocol |
|:--------|:-----|:---------|
| HTTP | 80 | TCP |
| HTTPS | 443 | TCP |
| SSH | 22 | TCP |
| PostgreSQL | 5432 | TCP |
| MongoDB | 27017 | TCP |
| Redis | 6379 | TCP |
| MySQL | 3306 | TCP |
| DNS | 53 | UDP |
| Kubernetes API | 6443 | TCP |

---

## ✅ Pre-Deployment Checklist

Before deploying to production:

- [ ] All users have MFA enabled
- [ ] Network policies are applied and tested
- [ ] Secrets are in AWS Secrets Manager (not hardcoded)
- [ ] IAM roles follow least privilege
- [ ] CloudWatch alarms are configured
- [ ] GuardDuty is enabled
- [ ] CloudTrail logging is enabled
- [ ] All data is encrypted (at rest and in transit)
- [ ] Security groups are restrictive (no 0.0.0.0/0 for SSH)
- [ ] Session Manager is configured (no direct SSH)

---

## 🆘 Emergency Contacts

| Issue | Action |
|:------|:-------|
| **Suspected breach** | 1. Isolate affected resources<br/>2. Revoke credentials<br/>3. Check CloudTrail logs |
| **Service down** | 1. Check pod status<br/>2. Review logs<br/>3. Check network policies |
| **Access denied** | 1. Verify IAM permissions<br/>2. Check MFA status<br/>3. Simulate policy |

---

## 💡 Pro Tips

1. **Always test in dev first** - Never apply network policies directly to production
2. **Use labels wisely** - Consistent labeling makes network policies easier
3. **Monitor everything** - You can't protect what you can't see
4. **Automate rotation** - Manual secret rotation always fails eventually
5. **Document exceptions** - If you must break a rule, document why

---

**Print this page and keep it handy!** 📄

---

**Last Updated**: December 12, 2025  
**Version**: 1.0
