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

## Passwordless Or Temporary Database Access From Kubernetes

If Terraform creates the databases, AWS does not automatically give your application a temporary password. There are two real-world patterns:

1. **Bootstrap password managed by AWS Secrets Manager**
   - Terraform tells AWS to generate and store the master/admin password.
   - Humans and CI/CD do not know or store the master password.
   - AWS Secrets Manager can rotate the master password on a schedule.

2. **Runtime application access through IAM/OIDC**
   - EKS pods use IAM Roles for Service Accounts, also called IRSA.
   - The pod receives short-lived AWS credentials from STS.
   - The app uses those credentials to authenticate to the database or retrieve a rotated secret.

Recommended target design:

```text
EKS OIDC provider
  -> Kubernetes service account
  -> IAM role for service account
  -> Pod receives temporary AWS credentials
  -> App connects to DB using IAM auth or reads rotated secret from Secrets Manager
```

### PostgreSQL On RDS

For RDS PostgreSQL, use IAM database authentication for application users.

How it works:

```text
Pod assumes IAM role through IRSA
  -> app generates RDS IAM auth token
  -> token is used as the database password
  -> token is valid for 15 minutes
```

Terraform changes needed:

```hcl
resource "aws_db_instance" "postgres" {
  # existing settings
  engine                              = "postgres"
  iam_database_authentication_enabled = true

  # Better than passing var.postgres_password:
  manage_master_user_password = true
}
```

Then create a non-admin database user and grant IAM login inside PostgreSQL:

```sql
CREATE USER kyc_app;
GRANT rds_iam TO kyc_app;
GRANT CONNECT ON DATABASE appdb TO kyc_app;
```

The pod IAM role needs `rds-db:connect`.

Example IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:us-east-1:111122223333:dbuser:db-ABCDEFGHIJKLMNOP/kyc_app"
    }
  ]
}
```

The `db-ABCDEFGHIJKLMNOP` value is the RDS DB resource ID, not the normal DB identifier. Terraform can output it from `aws_db_instance.postgres.resource_id`.

Application behavior:

- Generate a fresh auth token before opening new DB connections.
- Keep connection pool lifetime below token lifetime or reconnect cleanly.
- Use TLS/SSL for the database connection.
- Do not store `PG_PASSWORD` in Kubernetes secrets for IAM-authenticated users.

### DocumentDB

For Amazon DocumentDB, there are two options.

Preferred when your DocumentDB version and driver support it:

```text
DocumentDB IAM authentication
```

Amazon DocumentDB supports IAM database authentication for non-primary users on supported DocumentDB 5.0 instance-based clusters. The primary/admin user still uses password authentication.

Target flow:

```text
Pod assumes IAM role through IRSA
  -> MongoDB driver uses AWS IAM authentication
  -> app connects without storing a MongoDB password
```

Alternative and widely used option:

```text
AWS Secrets Manager rotation
```

Use this when your app or driver cannot use DocumentDB IAM authentication yet.

Flow:

```text
AWS Secrets Manager stores DocumentDB user/password
  -> Secrets Manager rotates password on schedule
  -> pod uses IRSA to read secret
  -> External Secrets Operator can sync it into Kubernetes if needed
```

Terraform target for AWS-managed admin password:

```hcl
resource "aws_docdb_cluster" "docdb" {
  # existing settings
  engine = "docdb"

  # Better than passing var.docdb_password when supported by provider/version:
  manage_master_user_password = true
}
```

If using Secrets Manager for application credentials, the pod IAM role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:111122223333:secret:kyc/dev/docdb/app-*"
    }
  ]
}
```

### EKS IRSA Setup

Each workload should have its own Kubernetes service account and IAM role.

Example service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kyc-app-sa
  namespace: kyc
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/kyc-dev-app-irsa-role
```

Example IAM trust policy for the service account:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111122223333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:kyc:kyc-app-sa"
        }
      }
    }
  ]
}
```

### What Changes In CI/CD Secrets

If you fully move to AWS-managed master passwords and IAM runtime auth:

| Current secret | Future status |
| --- | --- |
| `TF_VAR_POSTGRES_PASSWORD` | Not required for RDS if using `manage_master_user_password = true` |
| `TF_VAR_DOCDB_PASSWORD` | Not required for DocumentDB if using `manage_master_user_password = true` |
| `AWS_ROLE_TO_ASSUME` | Still required for GitHub Actions |
| Jenkins AWS credentials | Still required for Jenkins |

CI/CD still needs AWS permissions to create:

- RDS/DocumentDB resources.
- Secrets Manager managed secrets.
- KMS keys if customer-managed encryption is used.
- IAM roles and policies for IRSA.
- EKS service account annotations if managed by Terraform or Helm.

### Recommended Migration Plan

1. Enable AWS-managed master password for RDS PostgreSQL.
2. Enable RDS IAM database authentication.
3. Add Terraform output for RDS `resource_id`.
4. Create an IRSA role for each Kubernetes service account.
5. Grant `rds-db:connect` to the app DB user.
6. Update the application to generate RDS IAM auth tokens instead of reading `PG_PASSWORD`.
7. For DocumentDB, choose IAM authentication if your cluster and MongoDB driver support it.
8. Otherwise store DocumentDB application credentials in Secrets Manager and rotate them.
9. Use External Secrets Operator only if the app cannot read Secrets Manager directly.
10. Remove `TF_VAR_POSTGRES_PASSWORD` and `TF_VAR_DOCDB_PASSWORD` from GitHub/Jenkins only after Terraform no longer requires those variables.

### Code Implementation In This Repository

The repository now has an opt-in implementation path.

Terraform:

- `kyc-terraform/modules/database/main.tf` supports `manage_master_user_password`.
- `kyc-terraform/modules/database/main.tf` supports `enable_postgres_iam_auth`.
- `kyc-terraform/environments/prod/irsa.tf` creates the EKS OIDC provider, an app IRSA role, and policies for:
  - `rds-db:connect`
  - `secretsmanager:GetSecretValue`
  - `secretsmanager:DescribeSecret`
- `kyc-terraform/environments/prod/outputs.tf` exposes:
  - `rds_resource_id`
  - `rds_master_user_secret_arn`
  - `docdb_master_user_secret_arn`
  - `kyc_app_irsa_role_arn`

Helm/Kubernetes:

- `kyc-k8s/templates/serviceaccount.yaml` creates `kyc-app-sa`.
- `kyc-k8s/templates/*deployment.yaml` sets `serviceAccountName`.
- `PG_PASSWORD` is omitted when `database.postgres.iamAuthEnabled` is `true`.
- `MONGO_URI` from Kubernetes secret is omitted when `database.docdb.mongoUriSecretArn` is set.

Application:

- `kyc-ekyc-service/index.js` and `kyc-vkyc-service/index.js` support `PG_IAM_AUTH_ENABLED=true`.
- When enabled, the services use `@aws-sdk/rds-signer` to generate short-lived PostgreSQL auth tokens.
- If `MONGO_URI_SECRET_ARN` is set, the services use `@aws-sdk/client-secrets-manager` to read the MongoDB URI using the pod IRSA role.

To enable for an environment:

```hcl
manage_master_user_password = true
enable_postgres_iam_auth    = true
k8s_namespace               = "kyc"
k8s_service_account_name    = "kyc-app-sa"
app_db_username             = "kyc_app"
docdb_app_secret_arn        = "arn:aws:secretsmanager:us-east-1:111122223333:secret:kyc/dev/docdb/app-abc123"
```

Then update Helm values manually or with the helper script.

Automated update:

```bash
./kyc-terraform/scripts/update_helm_irsa_values.sh prod true
```

Arguments:

```text
1st argument: environment name, for example dev, qa, prod
2nd argument: postgres IAM auth flag, true or false
```

The script reads:

```bash
terraform -chdir=kyc-terraform/environments/<env> output -raw kyc_app_irsa_role_arn
```

Then updates:

```yaml
serviceAccount.annotations.eks.amazonaws.com/role-arn
database.postgres.iamAuthEnabled
```

Manual equivalent:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/dev-kyc-app-irsa-role

database:
  postgres:
    iamAuthEnabled: true
  docdb:
    mongoUriSecretArn: arn:aws:secretsmanager:us-east-1:111122223333:secret:kyc/dev/docdb/app-abc123
```

Current repository status:

- `kyc-terraform/environments/prod/variables.tf` defaults `manage_master_user_password = true`.
- `kyc-terraform/environments/prod/variables.tf` defaults `enable_postgres_iam_auth = true`.
- Helm environment files can be updated with `kyc-terraform/scripts/update_helm_irsa_values.sh` after Terraform creates the `kyc_app_irsa_role_arn` output.


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

### 1. Verify Terraform Remote State For Dev

You already provided the backend resources:

```text
S3 bucket: my-terraform-trinath
DynamoDB lock table: terraform-locks
```

Verify they exist before running Terraform:

```bash
aws s3api head-bucket \
  --bucket my-terraform-trinath

aws dynamodb describe-table \
  --table-name terraform-locks \
  --region us-east-1
```

If the bucket is new, enable versioning and encryption:

```bash
aws s3api put-bucket-versioning \
  --bucket my-terraform-trinath \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket my-terraform-trinath \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

If the lock table does not exist, create it:

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Your current backend values are:

```text
S3 bucket: my-terraform-trinath
DynamoDB lock table: terraform-locks
```

Recommended backend values for dev if you reuse the same bucket and lock table:

```hcl
terraform {
  backend "s3" {
    # Same bucket can be reused for all environments.
    bucket         = "my-terraform-trinath"

    # Change this key per environment so states do not overwrite each other.
    key            = "dev/terraform.tfstate"

    # Use the region where the bucket and lock table exist.
    region         = "us-east-1"

    # Same lock table can be reused for all environments.
    dynamodb_table = "terraform-locks"

    # Keep enabled.
    encrypt        = true
  }
}
```

QA and prod should use separate backend keys or separate buckets:

| Environment | Bucket | State key | Lock table |
| --- | --- | --- | --- |
| dev | `my-terraform-trinath` | `dev/terraform.tfstate` | `terraform-locks` |
| qa | `my-terraform-trinath` | `qa/terraform.tfstate` | `terraform-locks` |
| prod | `my-terraform-trinath` | `prod/terraform.tfstate` | `terraform-locks` |

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
