# Terraform CI/CD Credentials Runbook

This runbook explains the credentials, variables, and environment setup required to run the Terraform deployment and destroy pipelines from GitHub Actions and Jenkins.

The current pipelines use this security flow:

```text
Define desired state in IaC
  -> terraform fmt/init/validate
  -> Checkov scan

Deploy to the cloud
  -> terraform plan
  -> approval
  -> terraform apply

Detect runtime issues
  -> Prowler

Query, understand, and correlate data
  -> CloudQuery
  -> Steampipe

Remediate or enforce policy
  -> Cloud Custodian dry-run by default
  -> real remediation only after explicit approval
```

## Current Pipeline Files

| Pipeline | File | Current Terraform root |
| --- | --- | --- |
| GitHub deploy | `.github/workflows/terraform-deploy.yml` | `kyc-terraform/environments/prod` |
| GitHub destroy | `.github/workflows/terraform-destroy.yml` | `kyc-terraform/environments/prod` |
| Jenkins deploy | `kyc-terraform/Jenkinsfile` | `kyc-terraform/environments/prod` |
| Jenkins destroy | `kyc-terraform/Jenkinsfile.destroy` | `kyc-terraform/environments/prod` |

Dev and QA should follow the same credential pattern. When separate Terraform roots are added, use:

```text
kyc-terraform/environments/dev
kyc-terraform/environments/qa
kyc-terraform/environments/prod
```

## Required Terraform Variables

These variables are defined by Terraform and must be available during plan/apply/destroy.

| Terraform variable | Required | Secret | Current source |
| --- | --- | --- | --- |
| `region` | Yes | No | GitHub `AWS_REGION`, Jenkins `AWS_REGION` parameter mapped to `TF_VAR_region` |
| `environment` | Yes | No | `terraform.tfvars` |
| `vpc_cidrs` | Yes | No | `terraform.tfvars` |
| `availability_zones` | Yes | No | `terraform.tfvars` |
| `cluster_name` | Yes | No | `terraform.tfvars` |
| `db_name` | Yes | No | Terraform default or `terraform.tfvars` |
| `db_username` | Yes | No | Terraform default or `terraform.tfvars` |
| `postgres_password` | Yes | Yes | `TF_VAR_postgres_password` |
| `docdb_password` | Yes | Yes | `TF_VAR_docdb_password` |

Do not commit database passwords to `terraform.tfvars`.

## Environment Naming Standard

Use environment-specific secrets so dev, QA, and prod can have different AWS roles and database passwords.

### GitHub Actions

Recommended GitHub environments:

| Environment | Purpose | Required reviewer |
| --- | --- | --- |
| `dev` | Dev deployment approval | Dev lead or manager |
| `qa` | QA deployment approval | QA lead or manager |
| `prod` | Production deployment approval | Production approver |
| `dev-destroy` | Dev destroy approval | Dev lead or manager |
| `qa-destroy` | QA destroy approval | QA lead or manager |
| `prod-destroy` | Production destroy approval | Production approver |

Recommended environment secrets:

| Environment | Secret name | Example value |
| --- | --- | --- |
| `dev` | `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::111122223333:role/kyc-github-actions-dev-terraform-role` |
| `dev` | `TF_VAR_POSTGRES_PASSWORD` | `dev-postgres-password-value` |
| `dev` | `TF_VAR_DOCDB_PASSWORD` | `dev-docdb-password-value` |
| `qa` | `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::111122223333:role/kyc-github-actions-qa-terraform-role` |
| `qa` | `TF_VAR_POSTGRES_PASSWORD` | `qa-postgres-password-value` |
| `qa` | `TF_VAR_DOCDB_PASSWORD` | `qa-docdb-password-value` |
| `prod` | `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::111122223333:role/kyc-github-actions-prod-terraform-role` |
| `prod` | `TF_VAR_POSTGRES_PASSWORD` | `prod-postgres-password-value` |
| `prod` | `TF_VAR_DOCDB_PASSWORD` | `prod-docdb-password-value` |

For destroy environments, duplicate the same secrets into `dev-destroy`, `qa-destroy`, and `prod-destroy`, or use repository-level secrets if your governance allows the same secret source for deploy and destroy.

### Jenkins

Current Jenkinsfiles use these credential IDs:

| Jenkins credential ID | Type | Used as |
| --- | --- | --- |
| `aws-credentials-id` | AWS Credentials | AWS access key and secret key for Terraform, Prowler, CloudQuery, Steampipe, Custodian |
| `tf-var-postgres-password` | Secret text | `TF_VAR_postgres_password` |
| `tf-var-docdb-password` | Secret text | `TF_VAR_docdb_password` |

Recommended environment-specific Jenkins IDs for real-world use:

| Environment | AWS credential ID | Postgres secret ID | DocDB secret ID |
| --- | --- | --- | --- |
| dev | `aws-credentials-dev` | `tf-var-dev-postgres-password` | `tf-var-dev-docdb-password` |
| qa | `aws-credentials-qa` | `tf-var-qa-postgres-password` | `tf-var-qa-docdb-password` |
| prod | `aws-credentials-prod` | `tf-var-prod-postgres-password` | `tf-var-prod-docdb-password` |

The current Jenkinsfiles still reference the generic IDs. If you want one Jenkinsfile to support dev/qa/prod, add an `ENVIRONMENT` parameter and map credential IDs based on that parameter.

## Dev Environment Setup First

Use these steps for dev. QA and prod follow the same pattern with the names from the tables above.

### 1. Create Terraform Remote State For Dev

Create an S3 bucket and DynamoDB table for Terraform state locking.

Example AWS CLI:

```bash
aws s3api create-bucket \
  --bucket kyc-app-terraform-state-dev \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket kyc-app-terraform-state-dev \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket kyc-app-terraform-state-dev \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

aws dynamodb create-table \
  --table-name terraform-state-lock-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Recommended backend values for dev:

```hcl
terraform {
  backend "s3" {
    bucket         = "kyc-app-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-dev"
    encrypt        = true
  }
}
```

QA and prod should use separate backend keys or separate buckets:

| Environment | Bucket example | State key | Lock table example |
| --- | --- | --- | --- |
| dev | `kyc-app-terraform-state-dev` | `dev/terraform.tfstate` | `terraform-state-lock-dev` |
| qa | `kyc-app-terraform-state-qa` | `qa/terraform.tfstate` | `terraform-state-lock-qa` |
| prod | `kyc-app-terraform-state-prod` | `prod/terraform.tfstate` | `terraform-state-lock-prod` |

## GitHub Actions Credential Setup

GitHub Actions should use AWS OIDC instead of long-lived AWS access keys.

### 1. Create GitHub OIDC Provider In AWS

Create the provider once per AWS account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

If the provider already exists, reuse it.

### 2. Create Dev IAM Trust Policy

Replace:

- `111122223333` with your AWS account ID.
- `Real-Time-Devops-Project/kyc-app` with your GitHub org/repo if different.

Example `github-actions-dev-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:Real-Time-Devops-Project/kyc-app:ref:refs/heads/dev",
            "repo:Real-Time-Devops-Project/kyc-app:pull_request",
            "repo:Real-Time-Devops-Project/kyc-app:environment:dev",
            "repo:Real-Time-Devops-Project/kyc-app:environment:dev-destroy"
          ]
        }
      }
    }
  ]
}
```

Create the role:

```bash
aws iam create-role \
  --role-name kyc-github-actions-dev-terraform-role \
  --assume-role-policy-document file://github-actions-dev-trust-policy.json
```

### 3. Attach Dev IAM Permissions

For first implementation, attach broad managed policies only if this is a temporary non-production dev account. For real production, replace them with least-privilege policies scoped to the resources Terraform manages.

Temporary dev example:

```bash
aws iam attach-role-policy \
  --role-name kyc-github-actions-dev-terraform-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Minimum real-world permission groups must cover:

- S3 and DynamoDB access for Terraform state.
- VPC, EC2, IAM, EKS, RDS, DocumentDB, ElastiCache, CloudFront, S3, WAF, CloudWatch resources managed by Terraform.
- Read/list permissions for Prowler, CloudQuery, and Steampipe.
- Mutating permissions for Cloud Custodian only if remediation is enabled.

### 4. Store Dev Secrets In GitHub

Go to:

```text
GitHub repository -> Settings -> Environments -> New environment -> dev
```

Add required reviewers for approval.

Add these environment secrets:

| Secret | Dev value |
| --- | --- |
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::111122223333:role/kyc-github-actions-dev-terraform-role` |
| `TF_VAR_POSTGRES_PASSWORD` | Dev PostgreSQL password |
| `TF_VAR_DOCDB_PASSWORD` | Dev DocumentDB password |

Create another environment:

```text
dev-destroy
```

Add required reviewers and the same three secrets if destroy runs against dev.

### 5. GitHub Variables

The current workflow uses `workflow_dispatch` input `aws_region`, defaulting to `us-east-1`. If you want environment variables instead, create:

| Environment | Variable name | Example value |
| --- | --- | --- |
| dev | `AWS_REGION` | `us-east-1` |
| qa | `AWS_REGION` | `us-east-1` |
| prod | `AWS_REGION` | `us-east-1` |

Current workflow value:

```yaml
AWS_REGION: ${{ inputs.aws_region || 'us-east-1' }}
```

## Jenkins Credential Setup

Jenkins currently uses AWS access keys through the AWS Credentials plugin.

### 1. Required Jenkins Plugins

Install these plugins:

- Pipeline
- Git
- Credentials Binding
- AWS Credentials
- Workspace Cleanup

The Jenkins agent must also have these CLIs installed:

- `terraform`
- `checkov`
- `tfsec` optional
- `prowler` optional
- `cloudquery` optional
- `steampipe` optional
- `custodian` optional
- `ansible`

### 2. Create Dev AWS IAM User Or Role For Jenkins

If Jenkins runs outside AWS, create an IAM user for dev automation. Prefer assuming a role if your Jenkins is hosted in AWS.

Temporary dev IAM user example:

```bash
aws iam create-user --user-name kyc-jenkins-dev-terraform-user

aws iam attach-user-policy \
  --user-name kyc-jenkins-dev-terraform-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws iam create-access-key \
  --user-name kyc-jenkins-dev-terraform-user
```

Store the returned access key and secret access key in Jenkins. Do not commit them.

### 3. Store Dev AWS Credential In Jenkins

Go to:

```text
Jenkins -> Manage Jenkins -> Credentials -> System -> Global credentials -> Add Credentials
```

Create:

```text
Kind: AWS Credentials
ID: aws-credentials-dev
Access Key ID: <dev access key>
Secret Access Key: <dev secret key>
Description: Dev AWS credentials for Terraform CI/CD
```

For the current Jenkinsfile without environment-specific credential mapping, create the generic ID:

```text
ID: aws-credentials-id
```

### 4. Store Dev Terraform Secrets In Jenkins

Create secret text credentials:

```text
Kind: Secret text
ID: tf-var-dev-postgres-password
Secret: <dev PostgreSQL password>
Description: Dev TF_VAR_postgres_password
```

```text
Kind: Secret text
ID: tf-var-dev-docdb-password
Secret: <dev DocumentDB password>
Description: Dev TF_VAR_docdb_password
```

For the current Jenkinsfile without environment-specific credential mapping, create the generic IDs:

```text
ID: tf-var-postgres-password
ID: tf-var-docdb-password
```

## Environment Variable Matrix

### GitHub Actions

| Environment | Environment secret/variable | Required value |
| --- | --- | --- |
| dev | `AWS_ROLE_TO_ASSUME` | Dev Terraform role ARN |
| dev | `TF_VAR_POSTGRES_PASSWORD` | Dev PostgreSQL password |
| dev | `TF_VAR_DOCDB_PASSWORD` | Dev DocumentDB password |
| dev | `AWS_REGION` or dispatch input `aws_region` | Dev AWS region |
| qa | `AWS_ROLE_TO_ASSUME` | QA Terraform role ARN |
| qa | `TF_VAR_POSTGRES_PASSWORD` | QA PostgreSQL password |
| qa | `TF_VAR_DOCDB_PASSWORD` | QA DocumentDB password |
| qa | `AWS_REGION` or dispatch input `aws_region` | QA AWS region |
| prod | `AWS_ROLE_TO_ASSUME` | Prod Terraform role ARN |
| prod | `TF_VAR_POSTGRES_PASSWORD` | Prod PostgreSQL password |
| prod | `TF_VAR_DOCDB_PASSWORD` | Prod DocumentDB password |
| prod | `AWS_REGION` or dispatch input `aws_region` | Prod AWS region |

### Jenkins

| Environment | Jenkins parameter/credential | Required value |
| --- | --- | --- |
| dev | `AWS_REGION` parameter | Dev AWS region |
| dev | `aws-credentials-dev` | Dev AWS access key/secret or assumed-role credential |
| dev | `tf-var-dev-postgres-password` | Dev PostgreSQL password |
| dev | `tf-var-dev-docdb-password` | Dev DocumentDB password |
| qa | `AWS_REGION` parameter | QA AWS region |
| qa | `aws-credentials-qa` | QA AWS access key/secret or assumed-role credential |
| qa | `tf-var-qa-postgres-password` | QA PostgreSQL password |
| qa | `tf-var-qa-docdb-password` | QA DocumentDB password |
| prod | `AWS_REGION` parameter | Prod AWS region |
| prod | `aws-credentials-prod` | Prod AWS access key/secret or assumed-role credential |
| prod | `tf-var-prod-postgres-password` | Prod PostgreSQL password |
| prod | `tf-var-prod-docdb-password` | Prod DocumentDB password |

## Branch And Approval Setup

Recommended branch flow:

```text
feature branch
  -> PR to dev
  -> Terraform CI plan and readable tf-summarize output
  -> manager approval
  -> merge to dev
  -> dev deployment approval
  -> apply to dev

dev
  -> PR to main
  -> Terraform CI plan and readable tf-summarize output
  -> manager approval
  -> merge to main
  -> prod deployment approval
  -> apply to prod
```

For GitHub:

1. Protect `main`.
2. Protect `dev`.
3. Require pull request before merge.
4. Require at least one approval.
5. Require Terraform CI status checks to pass.
6. Add required reviewers to `dev`, `qa`, `prod`, and destroy environments.

## Notes From Current Code Audit

- GitHub deploy and destroy workflows currently point to `kyc-terraform/environments/prod`.
- Jenkins deploy and destroy pipelines currently point to `kyc-terraform/environments/prod`.
- Current Jenkins credential IDs are generic: `aws-credentials-id`, `tf-var-postgres-password`, and `tf-var-docdb-password`.
- Current GitHub secret names are generic inside the selected GitHub environment: `AWS_ROLE_TO_ASSUME`, `TF_VAR_POSTGRES_PASSWORD`, and `TF_VAR_DOCDB_PASSWORD`.
- `AWS_REGION` is a GitHub workflow input for deploy and a Jenkins parameter for deploy/destroy.
- The destroy GitHub workflow currently has `AWS_REGION: us-east-1`; make it a workflow input if destroy must support multiple regions.

