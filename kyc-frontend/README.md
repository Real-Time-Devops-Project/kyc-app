# 💻 KYC Frontend Application

Welcome to the frontend application repository for the KYC (Know Your Customer) platform.

## 🎯 Repository Purpose
This repository contains the user-facing web application where customers interact with the KYC platform to upload their identification documents and verify their identity. It is decoupled from the backend logic and communicates with our backend microservices via REST APIs.

## 🛠️ Technology Stack
- **Framework**: React / Next.js (or equivalent modern JS framework)
- **Containerization**: Docker
- **CI/CD**: GitHub Actions & Jenkins

### Key Resources Managed:
- **Application Source Code**: All HTML, CSS, and JavaScript components.
- **Dockerfile**: The container definition to package the frontend application into a lightweight, production-ready Nginx image.

---

## 🔑 Environment Variables & Secrets

The frontend application requires specific environment variables during build time and runtime to connect to the correct backend services.

### 1. `NEXT_PUBLIC_API_URL` (or `REACT_APP_API_URL`)
- **What it is**: The public endpoint of the backend API gateway or the specific eKYC/vKYC services.
- **Where to use it**: Configured in `.env` files locally, or injected into the container at runtime.
- **How to create**: If running in Kubernetes, this value is passed via the Helm chart's `values-<env>.yaml` file located in the `kyc-gitops` repository.

### 2. AWS ECR Deployment Variables
To push the built Docker image to AWS Elastic Container Registry (ECR), the CI/CD pipeline requires:
- `AWS_ROLE_TO_ASSUME`: GitHub Secret containing the IAM Role ARN.
- `AWS_REGION`: Environment variable in the pipeline (e.g., `us-east-1`).
- `ECR_REPOSITORY`: The name of the ECR repository (e.g., `kyc-frontend`).

---

## 🚀 CI/CD Pipeline & Workflow

This repository uses a standard Continuous Integration pipeline:

1. **Build & Test (PR)**: 
   - When a PR is opened, the code is linted and tested.
2. **Docker Build & Push (Merge)**:
   - When code is merged to `main`, the `docker-build.yml` workflow triggers.
   - It builds the Docker container.
   - It pushes the container image to AWS ECR with a unique tag (usually the Git SHA).
3. **Deployment Handoff**:
   - Once the image is pushed, a developer must update the `image.tag` value in the `kyc-gitops` repository to deploy the new version to Kubernetes via ArgoCD.
