# KYC - Infrastructure as Code (Terraform)

This repository contains the Terraform configuration files for provisioning the AWS infrastructure required to run the KYC application.

## Infrastructure Components

- **Networking**: Hub-spoke architecture with Transit VPC, App VPC, and Management VPC connected via Transit Gateway
- **EKS**: Elastic Kubernetes Service cluster with managed node groups (private endpoint)
- **Security**: Security groups, WAFv2 (CloudFront scope), NACLs
- **Database**: RDS PostgreSQL (IAM auth, encrypted, multi-AZ), DocumentDB, ElastiCache Redis
- **Management**: Jenkins server, Bastion host (IMDSv2 enforced)
- **Web**: S3 static hosting with CloudFront distribution
- **Observability**: VPC Flow Logs to CloudWatch, EKS control plane logging

## Usage

1.  Install Terraform (v1.5.7 — pinned in `.terraform-version`).
2.  Navigate to the environment folder: `cd environments/prod`
3.  Initialize Terraform (auto-detects branch for backend key):
    ```bash
    bash ../../scripts/tf-init.sh
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

- `modules/`: Reusable Terraform modules (networking, eks, database, security, management, web).
- `environments/`: Environment-specific configurations (prod).
- `scripts/`: Helper scripts (tf-init.sh, update_ansible_inventory.sh, update_helm_irsa_values.sh).
- `ansible/`: Post-provision configuration playbooks for Jenkins and Bastion.
- `security/`: CloudQuery and Cloud Custodian policy definitions.

## CI/CD State Reconciliation

The Jenkins and GitHub Actions pipelines follow the three-state cloud loop:

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
