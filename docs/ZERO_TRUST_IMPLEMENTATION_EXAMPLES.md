# 🔧 Zero Trust Implementation Examples for Your Project

This document provides **ready-to-use** configuration files and scripts to implement Zero Trust Security in your Hub-and-Spoke AWS infrastructure.

-

## 📋 Table of Contents

1. [Network Policies for KYC Application](#network-policies-for-kyc-application)
2. [IAM Policies with Least Privilege](#iam-policies-with-least-privilege)
3. [AWS Secrets Manager Integration](#aws-secrets-manager-integration)
4. [Service Mesh (Istio) Configuration](#service-mesh-istio-configuration)
5. [CloudWatch Alarms for Anomaly Detection](#cloudwatch-alarms-for-anomaly-detection)
6. [Session Manager for Bastion Replacement](#session-manager-for-bastion-replacement)

---

## 🔒 Network Policies for KYC Application

### File: `kyc-app/k8s/zero-trust-network-policies.yaml`

```yaml
# ============================================
# Zero Trust Network Policies for KYC App
# ============================================
# This implements micro-segmentation to limit
# lateral movement in case of compromise
# ============================================

---
# 1. DEFAULT DENY ALL
# Block all traffic by default - explicit allow only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: kyc-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# 2. FRONTEND POLICIES
# Allow frontend to communicate with backend services only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kyc-frontend-policy
  namespace: kyc-app
spec:
  podSelector:
    matchLabels:
      app: kyc-frontend
  policyTypes:
  - Ingress
  - Egress
  
  # INGRESS: Allow traffic from Load Balancer
  ingress:
  - from:
    - ipBlock:
        cidr: 0.0.0.0/0  # ALB will handle authentication
    ports:
    - protocol: TCP
      port: 80
  
  # EGRESS: Allow only to backend services and DNS
  egress:
  # DNS resolution
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # eKYC Service
  - to:
    - podSelector:
        matchLabels:
          app: ekyc-service
    ports:
    - protocol: TCP
      port: 3000
  # vKYC Service
  - to:
    - podSelector:
        matchLabels:
          app: vkyc-service
    ports:
    - protocol: TCP
      port: 3001

---
# 3. eKYC SERVICE POLICIES
# Allow eKYC to access database and cache only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ekyc-service-policy
  namespace: kyc-app
spec:
  podSelector:
    matchLabels:
      app: ekyc-service
  policyTypes:
  - Ingress
  - Egress
  
  # INGRESS: Only from frontend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: kyc-frontend
    ports:
    - protocol: TCP
      port: 3000
  
  # EGRESS: Database and cache only
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # PostgreSQL RDS (replace with your DB subnet CIDR)
  - to:
    - ipBlock:
        cidr: 10.0.20.0/24  # Database subnet
    ports:
    - protocol: TCP
      port: 5432
  # MongoDB DocumentDB (replace with your subnet CIDR)
  - to:
    - ipBlock:
        cidr: 10.0.20.0/24
    ports:
    - protocol: TCP
      port: 27017
  # Redis ElastiCache (replace with your subnet CIDR)
  - to:
    - ipBlock:
        cidr: 10.0.20.0/24
    ports:
    - protocol: TCP
      port: 6379

---
# 4. vKYC SERVICE POLICIES
# Similar to eKYC but isolated
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vkyc-service-policy
  namespace: kyc-app
spec:
  podSelector:
    matchLabels:
      app: vkyc-service
  policyTypes:
  - Ingress
  - Egress
  
  # INGRESS: Only from frontend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: kyc-frontend
    ports:
    - protocol: TCP
      port: 3001
  
  # EGRESS: Database only (no cross-service communication)
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # MongoDB only
  - to:
    - ipBlock:
        cidr: 10.0.20.0/24
    ports:
    - protocol: TCP
      port: 27017
```

### Deployment Instructions

```bash
# 1. Update the CIDR blocks with your actual subnet ranges
# Get your database subnet CIDR from Terraform outputs
cd terraform-project/environments/prod
terraform output database_subnet_cidrs

# 2. Apply the network policies
kubectl apply -f kyc-app/k8s/zero-trust-network-policies.yaml

# 3. Verify policies are created
kubectl get networkpolicies -n kyc-app

# 4. Test connectivity (should be blocked)
# Try to access database directly from frontend (should fail)
kubectl exec -it $(kubectl get pod -n kyc-app -l app=kyc-frontend -o jsonpath='{.items[0].metadata.name}') -n kyc-app -- nc -zv <db-host> 5432
# Expected: Connection refused or timeout

# 5. Test legitimate traffic (should work)
# Frontend to eKYC should work
kubectl exec -it $(kubectl get pod -n kyc-app -l app=kyc-frontend -o jsonpath='{.items[0].metadata.name}') -n kyc-app -- curl http://ekyc-service:3000/health
# Expected: 200 OK
```

---

## 🔐 IAM Policies with Least Privilege

### Example 1: Jenkins IAM Role (Least Privilege)

**File**: `terraform-project/modules/iam/jenkins-role.tf`

```hcl
# ============================================
# Zero Trust IAM Role for Jenkins
# ============================================
# Principle: Grant only what's needed, when needed
# ============================================

resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-deployment-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          # Only from Management VPC
          StringEquals = {
            "aws:SourceVpc" = var.management_vpc_id
          }
        }
      }
    ]
  })
}

# Policy 1: EKS Read-Only Access
resource "aws_iam_role_policy" "jenkins_eks_read" {
  name = "jenkins-eks-read-only"
  role = aws_iam_role.jenkins_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
        Condition = {
          # Only during business hours (9 AM - 6 PM UTC)
          DateGreaterThan = {
            "aws:CurrentTime" = "2024-01-01T09:00:00Z"
          }
          DateLessThan = {
            "aws:CurrentTime" = "2024-12-31T18:00:00Z"
          }
        }
      }
    ]
  })
}

# Policy 2: ECR Push Access (Only to specific repositories)
resource "aws_iam_role_policy" "jenkins_ecr_push" {
  name = "jenkins-ecr-push"
  role = aws_iam_role.jenkins_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        # Only to KYC app repositories
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/kyc-frontend",
          "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/ekyc-service",
          "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/vkyc-service"
        ]
      }
    ]
  })
}

# Policy 3: S3 Access (Only to artifact bucket)
resource "aws_iam_role_policy" "jenkins_s3_artifacts" {
  name = "jenkins-s3-artifacts"
  role = aws_iam_role.jenkins_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.jenkins_artifacts.arn}/*"
        ]
        Condition = {
          # Require encryption
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# Deny dangerous actions explicitly
resource "aws_iam_role_policy" "jenkins_deny_dangerous" {
  name = "jenkins-deny-dangerous-actions"
  role = aws_iam_role.jenkins_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = [
          "iam:*",
          "ec2:TerminateInstances",
          "rds:DeleteDBInstance",
          "s3:DeleteBucket"
        ]
        Resource = "*"
      }
    ]
  })
}
```

---

### Example 2: Developer Role with MFA Requirement

```hcl
# Require MFA for all developer actions
resource "aws_iam_role_policy" "developer_require_mfa" {
  name = "require-mfa-for-all-actions"
  role = aws_iam_role.developer_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "DenyAllActionsWithoutMFA"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}
```

---

## 🔑 AWS Secrets Manager Integration

### Step 1: Create Secrets in AWS

```bash
#!/bin/bash
# File: scripts/create-secrets.sh

# Database credentials
aws secretsmanager create-secret \
  --name prod/kyc-app/database \
  --description "KYC App Database Credentials" \
  --kms-key-id alias/kyc-secrets \
  --secret-string '{
    "username": "kyc_admin",
    "password": "REPLACE_WITH_STRONG_PASSWORD",
    "host": "kyc-db.cluster-xxxxx.us-east-1.rds.amazonaws.com",
    "port": "5432",
    "database": "kyc_production"
  }'

# MongoDB credentials
aws secretsmanager create-secret \
  --name prod/kyc-app/mongodb \
  --description "KYC App MongoDB Credentials" \
  --kms-key-id alias/kyc-secrets \
  --secret-string '{
    "username": "kyc_mongo_admin",
    "password": "REPLACE_WITH_STRONG_PASSWORD",
    "host": "kyc-docdb.cluster-xxxxx.us-east-1.docdb.amazonaws.com",
    "port": "27017",
    "database": "kyc_documents"
  }'

# Redis credentials
aws secretsmanager create-secret \
  --name prod/kyc-app/redis \
  --description "KYC App Redis Credentials" \
  --kms-key-id alias/kyc-secrets \
  --secret-string '{
    "host": "kyc-redis.xxxxx.cache.amazonaws.com",
    "port": "6379"
  }'

# API Keys
aws secretsmanager create-secret \
  --name prod/kyc-app/api-keys \
  --description "External API Keys" \
  --kms-key-id alias/kyc-secrets \
  --secret-string '{
    "aadhaar_api_key": "REPLACE_WITH_ACTUAL_KEY",
    "video_service_key": "REPLACE_WITH_ACTUAL_KEY"
  }'

echo "✅ Secrets created successfully!"
echo "⚠️  Remember to replace placeholder passwords with actual values"
```

---

### Step 2: Install External Secrets Operator

```bash
#!/bin/bash
# File: scripts/install-external-secrets.sh

# Add Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Create namespace
kubectl create namespace external-secrets-system

# Create IAM role for External Secrets Operator
# (This should be done via Terraform in production)
eksctl create iamserviceaccount \
  --name external-secrets-sa \
  --namespace external-secrets-system \
  --cluster kyc-eks-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite \
  --approve \
  --override-existing-serviceaccounts

# Install External Secrets Operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-secrets-sa

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s \
  deployment/external-secrets -n external-secrets-system

echo "✅ External Secrets Operator installed!"
```

---

### Step 3: Configure Secret Synchronization

**File**: `kyc-app/k8s/external-secrets.yaml`

```yaml
---
# SecretStore - Connects to AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: kyc-app
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

---
# ExternalSecret - Database Credentials
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: kyc-app
spec:
  refreshInterval: 1h  # Sync every hour
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-secrets  # Creates this K8s secret
    creationPolicy: Owner
  data:
  - secretKey: PG_USER
    remoteRef:
      key: prod/kyc-app/database
      property: username
  - secretKey: PG_PASSWORD
    remoteRef:
      key: prod/kyc-app/database
      property: password
  - secretKey: PG_HOST
    remoteRef:
      key: prod/kyc-app/database
      property: host
  - secretKey: PG_PORT
    remoteRef:
      key: prod/kyc-app/database
      property: port
  - secretKey: PG_DATABASE
    remoteRef:
      key: prod/kyc-app/database
      property: database

---
# ExternalSecret - MongoDB Credentials
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mongodb-credentials
  namespace: kyc-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: mongo-secrets
    creationPolicy: Owner
  data:
  - secretKey: MONGO_USER
    remoteRef:
      key: prod/kyc-app/mongodb
      property: username
  - secretKey: MONGO_PASSWORD
    remoteRef:
      key: prod/kyc-app/mongodb
      property: password
  - secretKey: MONGO_HOST
    remoteRef:
      key: prod/kyc-app/mongodb
      property: host

---
# ExternalSecret - API Keys
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-keys
  namespace: kyc-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: api-secrets
    creationPolicy: Owner
  data:
  - secretKey: AADHAAR_API_KEY
    remoteRef:
      key: prod/kyc-app/api-keys
      property: aadhaar_api_key
  - secretKey: VIDEO_SERVICE_KEY
    remoteRef:
      key: prod/kyc-app/api-keys
      property: video_service_key
```

---

### Step 4: Update Deployments to Use Secrets

```yaml
# File: kyc-app/k8s/ekyc-deployment.yaml (Updated)

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ekyc-service
  namespace: kyc-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ekyc-service
  template:
    metadata:
      labels:
        app: ekyc-service
    spec:
      containers:
      - name: ekyc
        image: <account-id>.dkr.ecr.us-east-1.amazonaws.com/ekyc-service:latest
        ports:
        - containerPort: 3000
        env:
        # Database credentials from AWS Secrets Manager
        - name: PG_USER
          valueFrom:
            secretKeyRef:
              name: db-secrets  # Created by ExternalSecret
              key: PG_USER
        - name: PG_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: PG_PASSWORD
        - name: PG_HOST
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: PG_HOST
        # API Keys
        - name: AADHAAR_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: AADHAAR_API_KEY
```

---

## 🕸️ Service Mesh (Istio) Configuration

### Step 1: Install Istio

```bash
#!/bin/bash
# File: scripts/install-istio.sh

# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with minimal profile
istioctl install --set profile=default -y

# Enable sidecar injection for kyc-app namespace
kubectl label namespace kyc-app istio-injection=enabled

# Verify installation
kubectl get pods -n istio-system

echo "✅ Istio installed successfully!"
```

---

### Step 2: Enable mTLS (Mutual TLS)

**File**: `kyc-app/k8s/istio-mtls.yaml`

```yaml
---
# Enforce strict mTLS for all services
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default-mtls
  namespace: kyc-app
spec:
  mtls:
    mode: STRICT  # All traffic must be encrypted

---
# Authorization Policy - Only allow specific services
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-to-backend
  namespace: kyc-app
spec:
  selector:
    matchLabels:
      app: ekyc-service
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/kyc-app/sa/kyc-frontend"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

---

## 📊 CloudWatch Alarms for Anomaly Detection

**File**: `terraform-project/modules/monitoring/zero-trust-alarms.tf`

```hcl
# ============================================
# Zero Trust Monitoring Alarms
# ============================================

# Alarm 1: Unusual API Call Volume
resource "aws_cloudwatch_metric_alarm" "unusual_api_calls" {
  alarm_name          = "zero-trust-unusual-api-volume"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CallCount"
  namespace           = "AWS/ApiGateway"
  period              = "300"  # 5 minutes
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "Alert when API calls exceed normal threshold"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  
  dimensions = {
    ApiName = "kyc-api"
  }
}

# Alarm 2: Failed Authentication Attempts
resource "aws_cloudwatch_log_metric_filter" "failed_auth" {
  name           = "failed-authentication-attempts"
  log_group_name = "/aws/eks/kyc-cluster/cluster"
  pattern        = "[time, request_id, event_type = AuthenticationFailure, ...]"
  
  metric_transformation {
    name      = "FailedAuthCount"
    namespace = "ZeroTrust/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "failed_auth_alarm" {
  alarm_name          = "zero-trust-failed-auth-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedAuthCount"
  namespace           = "ZeroTrust/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"  # More than 10 failures in 5 minutes
  alarm_description   = "Potential brute force attack detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Alarm 3: Privilege Escalation Attempts
resource "aws_cloudwatch_log_metric_filter" "privilege_escalation" {
  name           = "privilege-escalation-attempts"
  log_group_name = "/aws/eks/kyc-cluster/cluster"
  pattern        = "[time, request_id, event_type = PrivilegeEscalation, ...]"
  
  metric_transformation {
    name      = "PrivilegeEscalationCount"
    namespace = "ZeroTrust/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "privilege_escalation_alarm" {
  alarm_name          = "zero-trust-privilege-escalation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "PrivilegeEscalationCount"
  namespace           = "ZeroTrust/Security"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"  # Any attempt is suspicious
  alarm_description   = "Privilege escalation attempt detected!"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"
}

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security_alerts" {
  name = "zero-trust-security-alerts"
  
  kms_master_key_id = aws_kms_key.sns_encryption.id
}

resource "aws_sns_topic_subscription" "security_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_team_email
}
```

---

## 🖥️ Session Manager for Bastion Replacement

### Why Replace SSH with Session Manager?

| SSH (Traditional) | Session Manager (Zero Trust) |
|:------------------|:-----------------------------|
| ❌ Requires open port 22 | ✅ No inbound ports needed |
| ❌ SSH keys can be stolen | ✅ IAM-based authentication |
| ❌ Limited audit logging | ✅ Full CloudTrail logs |
| ❌ No session recording | ✅ Session recording available |

---

### Implementation

**File**: `terraform-project/modules/compute/bastion-session-manager.tf`

```hcl
# Install SSM Agent on Bastion (via user data)
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  subnet_id     = var.management_public_subnet_id
  
  iam_instance_profile = aws_iam_instance_profile.bastion_ssm.name
  
  user_data = <<-EOF
    #!/bin/bash
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
  
  # No security group rule for SSH needed!
  vpc_security_group_ids = [aws_security_group.bastion_ssm.id]
  
  tags = {
    Name = "bastion-zero-trust"
  }
}

# IAM Role for Session Manager
resource "aws_iam_role" "bastion_ssm" {
  name = "bastion-session-manager-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_ssm" {
  name = "bastion-ssm-profile"
  role = aws_iam_role.bastion_ssm.name
}

# Security Group - No SSH port!
resource "aws_security_group" "bastion_ssm" {
  name        = "bastion-session-manager-sg"
  description = "Security group for Session Manager access"
  vpc_id      = var.management_vpc_id
  
  # Only HTTPS outbound for SSM communication
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for SSM"
  }
  
  tags = {
    Name = "bastion-ssm-sg"
  }
}
```

---

### Usage

```bash
# Connect to bastion without SSH keys or open ports!
aws ssm start-session --target i-1234567890abcdef0

# Port forwarding (e.g., to access RDS)
aws ssm start-session \
  --target i-1234567890abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5432"],"localPortNumber":["5432"]}'

# Now connect to RDS via localhost:5432
psql -h localhost -U kyc_admin -d kyc_production
```

---

## 📝 Summary Checklist

Use this checklist to track your Zero Trust implementation:

- [ ] **Network Policies**
  - [ ] Default deny all traffic
  - [ ] Explicit allow rules for each service
  - [ ] Test connectivity restrictions
  
- [ ] **IAM Least Privilege**
  - [ ] Review all IAM roles
  - [ ] Remove wildcard (*) permissions
  - [ ] Add MFA requirements
  
- [ ] **Secrets Management**
  - [ ] Migrate to AWS Secrets Manager
  - [ ] Install External Secrets Operator
  - [ ] Enable automatic rotation
  
- [ ] **Service Mesh**
  - [ ] Install Istio
  - [ ] Enable mTLS
  - [ ] Configure authorization policies
  
- [ ] **Monitoring**
  - [ ] Create CloudWatch alarms
  - [ ] Enable GuardDuty
  - [ ] Set up SNS notifications
  
- [ ] **Session Management**
  - [ ] Replace SSH with Session Manager
  - [ ] Remove SSH security group rules
  - [ ] Enable session logging

---

**Next Steps**: Start with Network Policies (easiest) and gradually implement other components. Remember: Zero Trust is a journey, not a destination!
