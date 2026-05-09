# ⚙️ KYC Video KYC (vKYC) Service

Welcome to the backend repository for the Video KYC (vKYC) microservice.

## 🎯 Repository Purpose
This repository contains the backend logic to handle Video KYC verification. While the `eKYC` service handles fully automated, document-based verification, this `vKYC` service facilitates live video calls between a customer and a KYC verification agent, recording the session for compliance.

## 🛠️ Technology Stack
- **Framework**: Node.js / Python / Java (Backend API)
- **Database Connection**: PostgreSQL/MySQL (for status), S3 (for video storage)
- **Containerization**: Docker
- **CI/CD**: GitHub Actions & Jenkins

### Key Resources Managed:
- **Application Source Code**: WebRTC signaling, API endpoints, and agent-routing logic.
- **Dockerfile**: The container definition to package the microservice for Kubernetes execution.

---

## 🔑 Environment Variables & Secrets

Because this microservice interacts with databases and cloud storage, it requires several environment variables.

### 1. Database Credentials
- `DB_HOST`: The endpoint of the Amazon RDS database.
- `DB_PORT`: The database port (e.g., 5432).
- `DB_USER` & `DB_PASS`: The authentication credentials.
- **How to create**: Created securely in AWS Secrets Manager via the `kyc-infrastructure` repo. 
- **Where to use it**: Injected by the External Secrets Operator in the Kubernetes cluster.

### 2. Video Storage Credentials
- `AWS_S3_BUCKET_NAME`: The bucket where vKYC video recordings are stored.
- **Where to use it**: Configured in the `kyc-gitops` Helm chart values. The application uses IAM Roles for Service Accounts (IRSA) to securely write to S3 without needing an AWS Access Key.

### 3. AWS ECR Deployment Variables
To push the built Docker image to AWS Elastic Container Registry (ECR), the CI/CD pipeline requires:
- `AWS_ROLE_TO_ASSUME`: GitHub Secret containing the IAM Role ARN.
- `ECR_REPOSITORY`: The name of the ECR repository (e.g., `kyc-vkyc-service`).

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
