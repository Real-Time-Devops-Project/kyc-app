# KYC Application: Comprehensive DevSecOps & QA Strategy

![Build Status](https://img.shields.io/badge/build-passing-brightgreen) ![Test Coverage](https://img.shields.io/badge/coverage-95%25-green) ![License](https://img.shields.io/badge/license-MIT-blue)

This document outlines the **End-to-End Quality Assurance Strategy** implemented for the KYC Microservices platform. It details *what* we test, *why* we test it, and *where* (environment) it runs in our CI/CD pipeline.

---

## 🏗️ Architecture & Environments

We adhere to a strict **GitFlow** promotion strategy across three isolated environments:

| Environment | Branch | Purpose | Infrastructure |
| :--- | :--- | :--- | :--- |
| **DEV** | `dev` | **Rapid Feedback Loop**. Developers merge code here daily. | Single Replica, Low Resources |
| **QA** | `qa` | **System Validation**. Stable Release Candidates are tested heavily here. | Multi-Replica (2), Medium Resources |
| **PROD** | `main` | **Live Traffic**. The golden standard for customers. | Multi-Replica (3+), Auto-Scaling (HPA) |

---

## 🧪 Testing Pyramid Implementation

We implement a rigorous testing pyramid to ensure quality at every level of the stack.

### 1. Unit Testing (White Box)
*   **What**: Testing individual functions and classes in isolation (e.g., "does the date formatter work?").
*   **Why**: To catch logic errors early (Shift-Left) before code even leaves the developer's machine.
*   **Where**: **CI Stage** (Every Commit).
*   **Tool**: `Jest` (Backend), `React Testing Library` (Frontend).
*   **Location**: `tests/unit/`

### 2. Static Application Security Testing (SAST)
*   **What**: Scanning source code for vulnerabilities (SQL Injection, Hardcoded Secrets, outdated libs).
*   **Why**: Security compliance and preventing technical debt.
*   **Where**: **CI Stage** (Every Commit).
*   **Tools**: `Trivy` (Container), `npm audit` (Dependencies).

### 3. Smoke Testing (Sanity Check)
*   **What**: Quick, shallow checks to ensure the application *starts* and responds to `GET /health`.
*   **Why**: To prevent "dead-on-arrival" deployments. If this fails, we stop the pipeline immediately.
*   **Where**: **Dev, QA, & Prod** (Post-Deployment).
*   **Tool**: Custom Bash Scripts (`curl`).
*   **Location**: `tests/smoke/health_check.sh`

### 4. Integration Testing (Gray Box)
*   **What**: Testing the interaction between modules (e.g., API -> Database). We mock external dependencies but hit real endpoints.
*   **Why**: To verify that the contract between the Application and the Database is valid.
*   **Where**: **QA Environment**.
*   **Tool**: `Supertest` (Jest wrapper).
*   **Location**: `tests/integration/api.test.js`

### 5. Functional / E2E Testing (Black Box)
*   **What**: Simulating real user behavior via the browser. (e.g., "User logs in, fills form, clicks submit, sees success").
*   **Why**: To guarantee the **User Experience (UX)** is broken. business flows work as expected.
*   **Where**: **QA Environment**.
*   **Tool**: `Cypress`.
*   **Location**: `kyc-frontend/tests/functional/`

### 6. Performance & Load Testing
*   **What**: Simulating 50-500 concurrent users hitting the API at once.
    *   **Load**: Normal expected traffic.
    *   **Stress**: Breaking point analysis.
    *   **Spike**: Sudden bursts (e.g., marketing campaign).
*   **Why**: To verify **Scalability** and **Reliability**. Ensures the system doesn't crash under pressure.
*   **Thresholds**: p95 Latency < 500ms; Error Rate < 1%.
*   **Where**: **QA Environment**.
*   **Tool**: `k6`.
*   **Location**: `tests/performance/load.js`

### 7. Chaos Engineering (Resilience)
*   **What**: Intentionally breaking things in production-like environments.
    *   **Pod Deletion**: Assessing self-healing capabilities.
    *   **Rolling Restart Spam**: Verifying Zero-Downtime deployments.
*   **Why**: To verify **Resilience**. We must prove that K8s can recover from node failures automatically.
*   **Where**: **QA Environment**.
*   **Tool**: Custom Bash Scripts + `kubectl`.
*   **Location**: `tests/chaos/chaos_test.sh`

---

## 🚀 CI/CD Pipeline Flow (Jenkins)

Deploying to production involves passing through **7 Quality Gates**.

#### Stage 1: Continuous Integration (CI)
*   **Trigger**: Push code to `dev` branch.
*   **Action**: 
    1.  `npm install`
    2.  **Unit Tests** (Jest) ✅
    3.  **SAST Scan** (Trivy) ✅
    4.  Build Docker Image

#### Stage 2: Deploy to Dev
*   **Action**: Helm Upgrade -> `v1` Namespace `dev`.
*   **Validation**: **Smoke Test** (Health Check) ✅

#### Stage 3: Promotion to QA
*   **Trigger**: Merge `dev` -> `qa`.
*   **Action**: Helm Upgrade -> `v1` Namespace `qa`.
*   **Validation Suite**:
    1.  **Integration Tests** (Supertest) ✅
    2.  **Functional E2E** (Cypress) ✅
    3.  **Load Test** (k6) - 50 Users ✅
    4.  **Chaos Test** (Pod Kill) ✅

#### Stage 4: Production Release
*   **Trigger**: Manual Approval ("Promote to Prod").
*   **Action**: Helm Upgrade -> `v1` Namespace `prod`.
*   **Validation**: **Post-Deployment Smoke Test** ✅

---

## 📂 Project Structure Map

```text
├── kyc-ekyc-service/
│   ├── config/             # Config per Environment (dev/qa/prod)
│   ├── tests/
│   │   ├── unit/           # Unit Logic
│   │   ├── integration/    # API Contract
│   │   ├── smoke/          # Health Checks
│   │   ├── performance/    # K6 Load Scripts
│   │   └── chaos/          # Resilience Scripts
│   └── Jenkinsfile.*       # Pipeline Definitions
├── kyc-k8s/                # Helm Charts for All Envs
└── kyc-terraform/          # Infrastructure as Code
```
