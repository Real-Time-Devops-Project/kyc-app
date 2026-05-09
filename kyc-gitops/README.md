# ☸️ KYC GitOps Repository

Welcome to the GitOps deployment repository for the KYC Application. This repository represents the "Desired State" of our Kubernetes clusters.

## 🎯 Repository Purpose
This repository stores all Kubernetes deployment manifests (packaged as Helm charts) and the ArgoCD Application configuration. Our Kubernetes cluster runs ArgoCD, which continuously monitors this repository. If the configuration here changes, ArgoCD automatically pulls those changes and applies them to the live EKS cluster.

## 🛠️ Technology Stack
- **Continuous Deployment**: ArgoCD
- **Package Manager**: Helm (`v3`)
- **Container Orchestration**: Kubernetes (AWS EKS)
- **CI/CD**: GitHub Actions & Jenkins (for manifest validation)

### Key Resources Managed:
1. **Helm Charts (`kyc-k8s/`)**: 
   - Contains the core `Deployment`, `Service`, `Ingress`, and `ConfigMap` templates for our microservices (Frontend, eKYC backend, vKYC backend).
   - Utilizes separate `values-<env>.yaml` files (e.g., `values-prod.yaml`) to manage environment-specific configurations.
2. **ArgoCD Apps (`kyc-argocd/`)**:
   - Contains the `Application.yaml` custom resource definitions that tell ArgoCD where to find the Helm charts and which EKS namespace to deploy them into.

---

## 🔑 Environment Variables & Secrets

Because this is a pure GitOps declarative repository, **there are very few environment variables required here**. Secrets (like database passwords) should NEVER be committed to this repository.

### 1. External Secrets Operator (ESO)
- **What it is**: To securely handle secrets in Kubernetes, we use the External Secrets Operator.
- **How it works**: You create secrets in AWS Secrets Manager. The Helm charts in this repository define `ExternalSecret` custom resources, which tell Kubernetes to dynamically fetch the secrets from AWS and mount them into the Pods.

---

## 🚀 CI/CD Pipeline & Workflow

This repository uses a **"Pull-based" GitOps workflow**:

1. **Manifest Validation (Push/PR)**: 
   - When a developer opens a PR to update a Helm chart (e.g., bumping an image tag from `v1.2` to `v1.3`), GitHub Actions runs `helm lint` to ensure the syntax is valid.
2. **ArgoCD Sync (Merge)**:
   - Once the PR is merged to `main`, no active deployment script runs in GitHub Actions.
   - Instead, the ArgoCD controller running inside AWS EKS detects the new commit.
   - ArgoCD "Pulls" the new Helm chart and gracefully updates the live pods to the new version.
