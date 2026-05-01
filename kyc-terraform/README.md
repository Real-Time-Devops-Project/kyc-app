# KYC - Infrastructure as Code (Terraform)

This repository contains the Terraform configuration files for provisioning the AWS infrastructure required to run the KYC application.

## Infrastructure Components

- VPC (Virtual Private Cloud)
- Subnets (Public/Private)
- NAT Gateway
- EKS (Elastic Kubernetes Service) Cluster
- IAM Roles and Policies
- Security Groups
- RDS (for PostgreSQL)
- ElasticCache (Redis)
- ECR Repositories

## Usage

1.  Install Terraform (v1.5+).
2.  Navigate to the relevant environment folder (e.g., `environments/dev`).
3.  Initialize Terraform:
    ```bash
    terraform init
    ```
4.  Plan the infrastructure:
    ```bash
    terraform plan
    ```
5.  Applying Changes (Use Caution):
    ```bash
    terraform apply
    ```

## Structure

- `modules/`: Reusable Terraform modules (vpc, eks, etc.).
- `environments/`: Environment-specific configurations (dev, prod).

## CI/CD State Reconciliation

The Jenkins and GitHub Actions pipelines now follow the three-state cloud loop:

- **Intended state:** Terraform format, init, validate, and Checkov IaC scans.
- **Actual state:** Terraform refresh-only drift detection, plan, apply, or destroy.
- **Observed state:** Optional Prowler, CloudQuery, Steampipe, and Cloud Custodian audit outputs.

### Jenkins credentials

Create these Jenkins credentials before running `kyc-terraform/Jenkinsfile` or `kyc-terraform/Jenkinsfile.destroy`:

- `aws-credentials-id`: AWS access key credentials for the AWS Credentials Jenkins plugin.
- `tf-var-postgres-password`: Secret text value for `TF_VAR_postgres_password`.
- `tf-var-docdb-password`: Secret text value for `TF_VAR_docdb_password`.

### GitHub Actions secrets

Create these repository or environment secrets:

- `AWS_ROLE_TO_ASSUME`: IAM role ARN trusted by GitHub OIDC.
- `TF_VAR_POSTGRES_PASSWORD`: PostgreSQL master password.
- `TF_VAR_DOCDB_PASSWORD`: DocumentDB master password.

Use the `prod` GitHub environment for deployment approval and `prod-destroy` for destroy approval.

For full GitHub Actions and Jenkins credential setup across dev, QA, and prod, see `kyc-docs/TERRAFORM_CICD_CREDENTIALS_RUNBOOK.md`.
