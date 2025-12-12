# 📘 Comprehensive DevSecOps Standards & Implementation Guide

This document outlines the **10 Golden Rules of DevSecOps** and provides a **Tailored Implementation Checklist** specific to your current AWS + Terraform + Jenkins + Kubernetes environment.

---

## 🏛️ Part 1: The 10 Golden Rules of DevSecOps

### 1. DevSecOps Process Foundations
*   **Pipeline as Control Plane**: Treat CI/CD as the primary security control. Any missing gate or skipped scan is a vulnerability.
*   **Definition as Code**: All pipeline definitions (`Jenkinsfile`, workflows) must be in version control, peer-reviewed, and protected.

### 2. Pipeline Design & Release Flow
*   **Graduated Rigor**:
    *   *Dev*: Auto-deploy.
    *   *Staging*: One senior approval.
    *   *Production*: Two approvals (different teams) + 15 min cancellation window.
*   **Early Integration**: Run SAST, SCA, and Secret Scanning on every Pull Request (PR) and block merges on high/critical findings.

### 3. Security Scanning & Policy-as-Code
*   **Fast Feedback**: Run fast SAST (Semgrep) on changed files in PRs. Run full scans on Main/Master nightly.
*   **Policy Enforcement**: Use tools like Checks/Kyverno to enforce rules pre-deployment (IaC) and post-deployment (Cloud posture). Auto-remediate low risks.

### 4. Secrets Management "Like a Ninja"
*   **Zero Visibility**: Never store secrets in git, Docker images, or logs. No `.env` files in repo.
*   **Central Broker**: Use AWS Secrets Manager or HashiCorp Vault. Enforce encryption in transit/rest and RBAC logging.

### 5. Secret Hygiene & Incident Handling
*   **Short-Lived**: Prefer dynamic credentials (15-60 min TTL) over static keys.
*   **Leak Response**: Run automated scanners (TruffleHog, GitLeaks) at pre-commit and CI. If a leak occurs: Revoke -> Rotate -> Scan Blast Radius immediately.

### 6. Secret Alternatives & "Keyless" Patterns
*   **Identity Federation**: Use OIDC (e.g., GitHub Actions to AWS) or IAM Roles for Service Accounts (IRSA) in EKS.
*   **No Shared Accounts**: Give each workload its own identity with least privilege.

### 7. Feature Flags as Security-Critical
*   **Security Primitives**: Flags are access controls. Compromise of a flag = privilege escalation.
*   **Evaluation Hygiene**: Evaluate server-side. Protect flag APIs. Separate "kill switches" from "experimental" flags.

### 8. Hardening Feature Flag Platforms
*   **Strict RBAC**: Require approval for changing sensitive flags.
*   **Audit Logging**: Integrate flag changes with SIEM. Monitor for anomalies (spikes in access denied).

### 9. Observability & Anomaly Detection
*   **Baseline Normals**: Know your "normal" deployment times and actors. Alert on deviations (e.g., 3 AM production deploy).
*   **KPI Tracking**: Measure MTTD, MTTR, Secret Rotation Frequency, and Pipeline Failure Rate due to security.

### 10. Maturity Path
*   **Crawl**: Audit pipelines/secrets.
*   **Walk**: Add approval gates & scanning.
*   **Run**: Implement OIDC & Policy-as-Code.
*   **Fly**: Self-healing controls & Chaos Engineering.

---

## � Part 2: Detailed Operational Protocols

### 1. DevSecOps Lifecycle and Pipeline
**Design the pipeline as a layered security gate**: Code → SAST/SCA/Secret Scan → Build → Container Scan → IaC Scan → DAST on Staging → Manual Risk Review → Production Approval. Each stage must be able to independently block the build.

*   **Pipeline as IaC**: Store all pipeline configurations (YAML, Jenkinsfiles) in Git.
*   **Governance**: Require at least two reviewers for any workflow change. Protect main/release branches.
*   **Audit**: Log and audit workflow changes exactly like different infrastructure changes (Terraform).

### 2. Approvals, Rollout, and Rollback
**Use environment-specific rigor**:
*   *Dev*: Auto-deploy.
*   *Staging*: One senior approval.
*   *Production*: Two approvals from different teams + wait timer.

*   **Rollback**: Establish clear rollback procedures (blue/green or canary) with automated trigger on error/latency thresholds.
*   **Baselines**: Define "normal" deploy patterns (time window, source IPs). Alert on anomalies (e.g., 3 AM deploys, unusual regions, pipelines skipping security stages).

### 3. Vulnerability Management & Scanning Process
**Standard Intake**: Run SAST, SCA, IaC, and Container scans for every service.
**SLAs**:
*   *Critical*: 7 days
*   *High*: 14 days
*   *Medium*: 30 days
*   *Metric*: Track MTTR (Mean Time To Remediate) per team.

**Scanning as a Service**:
*   Formalize the process: Request -> Scope -> Stage -> Execute -> Review -> Validate.
*   Metrics: Track coverage and turnaround time.

### 4. Secrets: From "Ninja" Hygiene to Rotation
**Avoid Legacy Patterns**: Treat any of these as incident conditions:
*   Static long-lived keys.
*   `.env` files in Git.
*   Secrets in CI logs, Dockerfiles, or Terraform state.

**Modern Management**:
*   **Centralize**: Use Vault or AWS Secrets Manager.
*   **Enforce**: Encryption, RBAC, and Audit Logs.
*   **KPIs**: Track Average Secret Age, Rotation Success Rate, and Time to Emergency Rotation.

### 5. Keyless / Identity-Based Access
**Workload Identity**: Prefer OIDC (CI to Cloud) or SPIFFE/SPIRE over stored keys.
*   **Ephemeral**: Credentials should be minted per run and auto-expire within minutes.
*   **Least Privilege**: Minimize shared service accounts. Every pipeline and microservice gets its own identity with full attribution.

### 6. Feature Flags as a Security Surface
**Classification**: Tag flags as Release, Experiment, Ops, Permission, or Kill-Switch.
*   **Governance**: Treat "Permission" and "Kill-Switch" flags as security controls (stricter than A/B toggles).
*   **Implementation**: Server-side evaluation only. Authenticated APIs only. Encrypt storage.
*   **Monitoring**: Log all evaluations and changes. Alert on abuse (e.g., repeated toggling of premium features).

### 7. Detection, Response, and Governance
**SIEM Integration**: Feed pipeline logs, secret access logs, and flag audits into SIEM.
**Detection Rules**:
*   Skipped scan stages.
*   Suspicious `curl`/`wget` in CI.
*   Unusual secret access.
*   Anomalous flag calls.

**Incident Playbooks**:
*   *Scenarios*: "Pipeline Poisoned", "Secret Leaked", "Flag Abused".
*   *Actions*: Automated first response (Disable flag, Rotate key, Lock workflow) -> Forensics -> Post-Incident.
*   *KPIs*: MTTD, MTTR, Repeat Rate.

---

## �🛠️ Part 3: Tailored Implementation Checklist
*Specific steps for your project structure: `terraform`, `jenkins`, `kyc-app`*

### 🔹 Phase 1: Pipeline Hardening (Rules 1, 2, 3)
**Target File**: `jenkins/Jenkinsfile.app`

- [ ] **Add Semgrep for SAST**:
    *   *Why*: Fast, customizable static analysis.
    *   *Action*: Add a stage *before* "Build & Unit Test":
        ```groovy
        stage('SAST (Semgrep)') {
            steps { sh 'semgrep scan --config=p/javascript --error --json -o semgrep.json' }
        }
        ```
- [ ] **Add Secret Scanning**:
    *   *Why*: Prevent leaks before build.
    *   *Action*: Add `TruffleHog` stage early in pipeline:
        ```groovy
        stage('Secret Scan') {
            steps { sh 'trufflehog filesystem . --fail' }
        }
        ```
- [ ] **Enforce Blocking Gates**:
    *   *Current State*: `waitForQualityGate` allows abort, but Trivy scans don't explicitly break build on HIGH (only CRITICAL exit code 1).
    *   *Action*: Ensure `trufflehog` and `semgrep` failures strictly fail the build (`exit 1`).

### 🔹 Phase 2: OIDC & Keyless Infrastructure (Rules 4, 6)
**Target Files**: `terraform-project/modules/eks/*.tf`

- [ ] **Enable OIDC Provider**:
    *   *Missing*: `aws_iam_openid_connect_provider` in `eks/main.tf`.
    *   *Action*: Add this resource to allow Kubernetes Service Accounts to assume AWS IAM Roles.
- [ ] **Implement IRSA (IAM Roles for Service Accounts)**:
    *   *Why*: Remove `aws-credentials-id` usage in Jenkins and hardcoded pod secrets.
    *   *Action*: Create IAM roles with a trust policy for `federated: oidc-provider`.
- [ ] **Update Jenkins Agent**:
    *   *Action*: Instead of `withCredentials` (Line 158), attach an **IAM Instance Profile** to the Jenkins EC2 agent with `eks:DescribeCluster` permissions.

### 🔹 Phase 3: Secrets Migration (Rules 4, 5)
**Target**: `kyc-app/k8s/` and AWS console

- [ ] **Create Secrets in AWS Secrets Manager**:
    *   Move DB passwords, API keys from K8s Secrets/Jenkins Creds to AWS Secrets Manager.
- [ ] **Install External Secrets Operator (ESO)**:
    *   Deploy ESO to your EKS cluster via Helm.
    *   Create `SecretStore` and `ExternalSecret` manifests to sync AWS secrets to K8s secrets automatically.
    *   *Benefit*: Automatic rotation support without redeploying apps.

### 🔹 Phase 4: Feature Flags (Rules 7, 8)
**Target**: `kyc-app/frontend/src`

- [ ] **Integrate LaunchDarkly/Split**:
    *   Add SDK to React frontend.
    *   Create a flag for `vkyc-module`.
- [ ] **Secure the Configuration**:
    *   Ensure the SDK key is injected via build-time env vars (from Secrets Manager), not hardcoded in `package.json`.

### 🔹 Phase 5: Policy as Code (Rule 3)
**Target**: `jenkins/Jenkinsfile` (IaC Pipeline)

- [ ] **Add Checkov**:
    *   *Action*: Scan Terraform modules for misconfigurations.
        ```groovy
        stage('IaC Security (Checkov)') {
             sh 'checkov -d ./terraform-project --check CKV_AWS_...'
        }
        ```

---

## 🚀 Execution Roadmap

| Week | Focus | Key Deliverable |
|:---|:---|:---|
| **1** | Pipeline Gates | Jenkinsfile updated with Semgrep & TruffleHog. |
| **2** | Keyless Access | OIDC Provider enabled in EKS Terraform. |
| **3** | Secrets Ops | External Secrets Operator running in Prod. |
| **4** | Feature Flags | vKYC feature wrapped in a flag. |

This guide bridges the gap between high-level theory and your specific codebase.
