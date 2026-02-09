# Branching & CI/CD Strategy

This document outlines the branching and CI/CD strategy for the KYC application, implementing strict environment promotion logic via separate pipelines.

## 1. Branching Model

We follow a GitFlow-inspired model mapping branches directly to environments:

| Branch | Environment | Purpose | Jenkinsfile |
| :--- | :--- | :--- | :--- |
| `dev` | **Development** | Active development, feature integration. | `Jenkinsfile.dev` |
| `qa` | **QA / Staging** | Stable release candidates, load testing. | `Jenkinsfile.qa` |
| `main` | **Production** | Live, production-ready code. | `Jenkinsfile.prod` |

## 2. Pipeline Configuration

Each repository (`kyc-ekyc-service`, `kyc-vkyc-service`, `kyc-frontend`) contains three distinct Jenkinsfiles.

### How to Configure Jenkins
You must create **Multibranch Pipelines** or separate **Pipeline Jobs** for each branch, pointing them to the correct script path:

*   **Job Name**: `kyc-ekyc-dev` -> **Script Path**: `Jenkinsfile.dev` (Trigger: Push to `dev`)
*   **Job Name**: `kyc-ekyc-qa` -> **Script Path**: `Jenkinsfile.qa` (Trigger: Push to `qa`)
*   **Job Name**: `kyc-ekyc-prod` -> **Script Path**: `Jenkinsfile.prod` (Trigger: Push to `main`)

## 3. Deployment Workflow

### Step 1: Development (`Jenkinsfile.dev`)
1.  **Trigger**: Developer pushes code to `dev` branch.
2.  **Test**: Runs Unit Tests (`npm test`).
3.  **Build**: Creates Docker Image `dev-<build-id>`.
4.  **Deploy**: Deploys to K8s Namespace `dev`.
5.  **Verify**: Runs Smoke Tests (`health_check.sh`).

### Step 2: Quality Assurance (`Jenkinsfile.qa`)
1.  **Trigger**: Merge `dev` into `qa`.
2.  **Deploy**: Deploys to K8s Namespace `qa`.
3.  **Test Suite**:
    *   **Integration Tests**: Checks API contracts.
    *   **Load Tests**: 500 concurrent users via `k6`.
    *   **Chaos Tests**: Simulates pod failure.

### Step 3: Production (`Jenkinsfile.prod`)
1.  **Trigger**: Merge `qa` into `main`.
2.  **Artifact Promotion**: Retags the tested QA image as `prod-<id>`.
3.  **Gate**: Pauses for **Manual Approval** ("Promote to Prod?").
4.  **Deploy**: Deploys to K8s Namespace `prod`.
5.  **Test**: Final sanity check.

## 4. Helm Details
All deployments use the unified Helm chart in `kyc-k8s`.
*   **Dev Vars**: `kyc-k8s/values-dev.yaml`
*   **QA Vars**: `kyc-k8s/values-qa.yaml`
*   **Prod Vars**: `kyc-k8s/values-prod.yaml`
