# ⚙️ KYC Electronic KYC (eKYC) Service

Welcome to the backend repository for the Electronic KYC (eKYC) microservice.

## 🎯 Repository Purpose
This repository contains the business logic for the fully automated Electronic KYC workflow. It is responsible for parsing digitally submitted documents, extracting PII, interacting with 3rd-party identity verification APIs, and persisting the verification status to the database.

## 🛠️ Technology Stack
- **Framework**: Node.js / Python / Java (Backend API)
- **Database Connection**: PostgreSQL/MySQL
- **Containerization**: Docker
- **CI/CD**: GitHub Actions & Jenkins

### Key Resources Managed:
- **Application Source Code**: RESTful API endpoints and business logic.
- **Dockerfile**: The container definition to package the microservice for Kubernetes execution.

---

## 🔑 Environment Variables & Secrets

Because this microservice interacts with secure databases and external APIs, it requires several environment variables.

### 1. Database Credentials
- `DB_HOST`: The endpoint of the Amazon RDS database.
- `DB_PORT`: The database port (e.g., 5432).
- `DB_USER` & `DB_PASS`: The authentication credentials.
- **How to create**: These are created securely in AWS Secrets Manager by the `kyc-infrastructure` Terraform code. 
- **Where to use it**: In Kubernetes, the External Secrets Operator fetches these from AWS and injects them as environment variables into the Pod. Do not store these locally.

### 2. AWS ECR Deployment Variables
To push the built Docker image to AWS Elastic Container Registry (ECR), the CI/CD pipeline requires:
- `AWS_ROLE_TO_ASSUME`: GitHub Secret containing the IAM Role ARN.
- `ECR_REPOSITORY`: The name of the ECR repository (e.g., `kyc-ekyc-service`).

---

## 🚀 CI/CD Pipeline & Workflow

This repository uses a standard Continuous Integration pipeline:

1. **Build & Test (PR)**: 
   - When a PR is opened, the code runs unit tests and static analysis.
2. **Docker Build & Push (Merge)**:
   - When code is merged to `main`, the `docker-build.yml` workflow triggers.
   - It builds the Docker container.
   - It pushes the container image to AWS ECR with a unique tag (usually the Git SHA).
3. **Deployment Handoff**:
   - Once the image is pushed, a developer must update the `image.tag` value in the `kyc-gitops` repository to deploy the new version to Kubernetes via ArgoCD.
