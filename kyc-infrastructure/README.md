# 🏗️ KYC Infrastructure Repository

Welcome to the foundational infrastructure repository for the KYC Application. This repository manages the provisioning of all core AWS resources using Terraform and is controlled via a GitOps "Serverless Atlantis" workflow.

## 🎯 Repository Purpose
This repository is solely responsible for creating, modifying, and destroying the underlying AWS cloud architecture that powers the KYC application. No application code lives here. Instead, this repo creates the VPCs, EKS Clusters, RDS databases, WAFs, and necessary IAM roles.

## 🛠️ Technology Stack
- **IaC Tool**: Terraform (`v1.5.7`)
- **Cloud Provider**: Amazon Web Services (AWS)
- **CI/CD**: GitHub Actions (Atlantis Workflow) & Jenkins

### Key Resources Provisioned:
1. **Networking (`modules/networking`)**: VPC, Public/Private Subnets, NAT Gateways, Route Tables, and strict NACLs.
2. **Compute (`modules/eks`)**: Elastic Kubernetes Service (EKS) cluster, Fargate profiles, and Managed Node Groups for running our microservices.
3. **Database (`modules/database`)**: Amazon RDS (PostgreSQL/MySQL) with encryption at rest and automated backups.
4. **Security (`modules/security`)**: AWS WAF (Web Application Firewall) attached to load balancers to prevent SQLi and XSS attacks.

---

## 🔑 Environment Variables & Secrets

To securely deploy infrastructure, this repository relies on the following environment variables. **Do not hardcode these in files.**

### 1. `AWS_ROLE_TO_ASSUME`
- **What it is**: The ARN of the IAM Role that GitHub Actions uses to authenticate to AWS via OIDC.
- **Where to use it**: Configured as a GitHub Repository Secret (`secrets.AWS_ROLE_TO_ASSUME`).
- **How to create**: Provisioned via the `prod/irsa.tf` file or created manually in AWS IAM with a trust policy allowing `token.actions.githubusercontent.com`.

### 2. `TF_VAR_github_token`
- **What it is**: A Personal Access Token (PAT) used by the Atlantis Fargate server to post comments on your Pull Requests.
- **Where to use it**: Injected as an environment variable in Jenkins or exported locally before running `terraform apply` in the `environments/atlantis` directory.
- **How to create**: Go to GitHub -> Developer Settings -> Personal Access Tokens -> Generate new token (classic) with `repo` scope.

### 3. `TF_VAR_github_webhook_secret`
- **What it is**: A random string used to secure the webhook payloads between GitHub and the Atlantis server.
- **Where to use it**: Exported locally or stored in CI/CD variables.
- **How to create**: Run `openssl rand -hex 24` in your terminal.

---

## 🚀 CI/CD Pipeline & Workflow

This repository strictly enforces **Infrastructure as Code (IaC)**. Direct manual changes in the AWS Console are prohibited.

1. **Pull Request Validation**: 
   - When a PR is opened, the `atlantis-terraform-plan.yml` workflow runs.
   - It performs static analysis using `Checkov`.
   - It runs `terraform plan` and automatically posts the planned infrastructure diff as a comment on the PR.
2. **Self-Serve Apply**:
   - Once a manager approves the PR, they add the `self-serve-apply` label to the PR.
   - This triggers the `atlantis-terraform-apply.yml` workflow, which executes `terraform apply` and merges the code.

Alternatively, a `Jenkinsfile` is provided in the root of this repo if your organization prefers Jenkins over GitHub Actions.
