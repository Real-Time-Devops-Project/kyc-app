# 🛡️ DevSecOps Strategy & Implementation

This document outlines the security practices, tools, and strategies implemented across the project to ensure a secure, compliant, and resilient infrastructure.

---

## 🚀 1. Comprehensive Pipeline Flow

We have implemented a **12-Stage DevSecOps Pipeline** following industry best practices to ensure code quality, security, and reliability.

### Pipeline Stages
1.  **Checkout**: Retrieve source code from SCM.
2.  **Build & Unit Test**: Compile code and run unit tests (`npm test`).
3.  **Code Coverage**: Measure test coverage (`Jest` / `JaCoCo`).
4.  **SCA (Software Composition Analysis)**: Scan dependencies for CVEs (`OWASP Dependency-Check`).
5.  **SAST (Static Application Security Testing)**: Analyze source code for bugs and vulnerabilities (`SonarQube`).
6.  **Quality Gate**: Enforce quality standards (Block pipeline if SonarQube Quality Gate fails).
7.  **Dockerfile Scan**: Lint Dockerfile for best practices (`Hadolint`).
8.  **Build Image**: Build the Docker container image.
9.  **Scan Image**: Scan the container image for OS vulnerabilities (`Trivy`).
10. **Smoke Deploy**: Deploy a temporary container to verify startup.
11. **Smoke Test**: Execute a quick health check (`curl /health`).
12. **Push**: Push the verified image to the registry (`ECR`).
13. **Deploy & DAST**: Deploy to EKS and run Dynamic Analysis (`OWASP ZAP`).

---

## 🛠️ 2. Toolchain Mapping & Setup Guide

This section explains the **Open Source** alternatives we use to match the capabilities of an Enterprise toolchain.

| Domain | Enterprise Tool | Our Open Source Choice | Why? |
| :--- | :--- | :--- | :--- |
| **SAST** | Checkmarx | **SonarQube** | Industry standard for code quality & security. Supports 25+ languages. |
| **SCA** | Black Duck / Snyk | **OWASP Dependency-Check** | Dedicated tool for finding vulnerabilities in project dependencies (NVD). |
| **Container** | Twistlock | **Trivy** | Lightweight, comprehensive scanner for OS packages and app dependencies in images. |
| **DAST** | Acunetix | **OWASP ZAP** | The world's most popular free DAST scanner. Scriptable and Docker-friendly. |
| **Secrets** | HashiCorp Vault | **AWS Secrets Manager** | Native AWS integration, serverless, and easy to use with EKS. |

### 1.1. SonarQube (SAST)
**Goal**: Find bugs, vulnerabilities, and code smells in source code.

*   **Jenkins Plugin**: `SonarQube Scanner`
*   **Configuration**:
    1.  Go to **Manage Jenkins > System > SonarQube servers**.
    2.  Add a server named `SonarQube`.
    3.  **Secret**: Create a "Secret text" credential containing the SonarQube User Token.
*   **Pipeline Usage**:
    ```groovy
    withSonarQubeEnv('SonarQube') {
        sh 'sonar-scanner ...'
    }
    ```

### 1.2. OWASP Dependency-Check (SCA)
**Goal**: Check if your libraries (e.g., `package.json`, `pom.xml`) have known CVEs.

*   **Jenkins Plugin**: `OWASP Dependency-Check`
*   **Configuration**:
    1.  Go to **Manage Jenkins > Tools**.
    2.  Add a Dependency-Check installation named `OWASP-Dependency-Check`.
    3.  Select "Install automatically".
*   **Pipeline Usage**:
    ```groovy
    dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'OWASP-Dependency-Check'
    ```

### 1.3. Trivy (Container Security)
**Goal**: Scan the Docker image for OS-level vulnerabilities (e.g., old `glibc`, `openssl`).

*   **Installation**: Install `trivy` binary on the Jenkins agent.
*   **Pipeline Usage**:
    ```groovy
    sh "trivy image --severity HIGH,CRITICAL my-image:tag"
    ```

### 1.4. OWASP ZAP (DAST)
**Goal**: Attack the running application to find runtime issues (XSS, SQLi, Headers).

*   **Installation**: Use the Docker image `owasp/zap2docker-stable`.
*   **Pipeline Usage**:
    ```groovy
    docker run -t owasp/zap2docker-stable zap-baseline.py -t http://target-url
    ```

---

## 🔐 2. Secret Management Strategy

---

## 🔐 2. Secret Management Strategy

### 2.1. Recommendation: Which is Best?
**Winner: AWS Secrets Manager + External Secrets Operator (ESO)**

| Feature | Kubernetes Secrets (Current) | AWS Secrets Manager (Recommended) |
| :--- | :--- | :--- |
| **Security** | Base64 encoded (not encrypted at rest by default unless configured) | Encrypted with KMS keys |
| **Rotation** | Manual process | Automatic rotation (e.g., every 30 days) |
| **Audit** | Hard to track who accessed what | Full CloudTrail audit logs |
| **Management** | Stored in Git (risky) or applied manually | Centralized AWS Console/CLI |

**Verdict**: We currently use **Kubernetes Secrets** for simplicity, but for a production DevSecOps implementation, you should migrate to **AWS Secrets Manager**.

### 2.2. How to Add & Use Secrets (Current Method: K8s Secrets)
Since we are currently using Kubernetes Secrets, here is the procedure:

**Step 1: Create the Secret**
You do not store the actual secret in Git. You create a local file or run a command.
```bash
# Create a secret named 'db-secrets' with a username and password
kubectl create secret generic db-secrets \
  --from-literal=pg-user=admin \
  --from-literal=pg-password=MySuperSecurePassword!
```

**Step 2: Use it in Deployment**
In your `deployment.yaml`, map the secret key to an environment variable.
```yaml
env:
  - name: PG_USER
    valueFrom:
      secretKeyRef:
        name: db-secrets      # Name of the secret created above
        key: pg-user          # Key inside the secret
```

### 2.3. How to Add & Use Secrets (Best Practice: AWS Secrets Manager)
To adopt the best practice, you would install the **External Secrets Operator** in your cluster.

**Step 1: Add Secret in AWS**
```bash
aws secretsmanager create-secret \
    --name production/kyc-app/db \
    --secret-string '{"username":"admin","password":"MySuperSecurePassword!"}'
```

**Step 2: Sync to K8s (ExternalSecret CRD)**
Create a manifest that tells K8s to fetch the secret from AWS.
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secrets-sync
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-store
    kind: SecretStore
  target:
    name: db-secrets # Creates this K8s secret automatically!
  data:
  - secretKey: pg-user
    remoteRef:
      key: production/kyc-app/db
      property: username
```

**Step 3: Use in Deployment**
Same as above! The application doesn't know the difference. It still reads from the K8s secret `db-secrets`, but now that secret is automatically managed and rotated by AWS.

---

## ☸️ 3. Kubernetes Hardening

Our Kubernetes manifests follow security best practices to minimize the attack surface.

### 3.1. Security Context
We enforce strict security contexts in our Deployments:
```yaml
securityContext:
  runAsNonRoot: true        # Prevents running as root user
  runAsUser: 1000           # Enforces a specific non-privileged UID
  allowPrivilegeEscalation: false # Prevents gaining more privileges
  capabilities:
    drop: ["ALL"]           # Drops all Linux capabilities
```

### 3.2. Resource Quotas
All containers have defined `requests` and `limits` to prevent "Noisy Neighbor" issues and Denial of Service (DoS) from resource exhaustion.

### 3.3. Network Policies (Recommended)
*   **Current**: VPC Security Groups restrict traffic.
*   **Future**: Implement Calico/Cilium Network Policies to isolate microservices within the cluster (Zero Trust).

---

## 📈 4. Scalability & Availability

### 4.1. Horizontal Pod Autoscaling (HPA)
We use HPA to automatically scale pods based on CPU utilization.
*   **Config**: `kyc-app/k8s/hpa.yaml`
*   **Trigger**: Scales up when CPU > 70%.
*   **Range**: Min 2 replicas, Max 10 replicas.

### 4.2. Probes
*   **Liveness Probe**: Restarts the pod if the application crashes or deadlocks.
*   **Readiness Probe**: Removes the pod from the Service load balancer until it is ready to accept traffic.

---

## 📝 5. Audit & Compliance

*   **Logs**: All application logs are sent to `stdout/stderr` and collected by CloudWatch Container Insights (if enabled on EKS).
*   **IaC State**: Terraform state is stored in an encrypted S3 bucket with DynamoDB locking for audit trails of infrastructure changes.
