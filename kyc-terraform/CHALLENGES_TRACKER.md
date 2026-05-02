# KYC Terraform — Challenges & Resolution Tracker

## 1. Terraform Code Quality

### Critical Bugs (Code Would Not Run)
- [x] Duplicate `variable` blocks in `main.tf` + `variables.tf` across 4 modules — Terraform crashes
- [x] Duplicate `output` blocks in `main.tf` + `outputs.tf` across 3 modules — Terraform crashes
- [x] Broken reference `aws_subnet.transit_public` → should be `aws_subnet.transit_untrusted`
- [x] `cluster_name` tfvars value ignored — hardcoded interpolation used instead
- [x] EKS subnet tags don't match actual cluster name — service discovery fails

### Security Vulnerabilities
- [x] NACLs allowed all traffic from `0.0.0.0/0` → restricted to `10.0.0.0/8`
- [x] EKS API publicly accessible → set private endpoint only
- [x] EKS cluster SG had no ingress → added port 443 from node SG
- [x] `skip_final_snapshot = true` on prod databases → set to `false` with snapshot identifiers
- [x] RDS storage unencrypted → `storage_encrypted = true`
- [x] No DB backup retention → `backup_retention_period = 7`
- [x] No IMDSv2 on EC2 → `http_tokens = "required"`
- [x] IRSA policy used wildcard `"*"` for Secrets Manager → auto-resolved from module output
- [x] WAF scope `REGIONAL` on CloudFront (must be `CLOUDFRONT`) → fixed
- [x] S3 artifacts bucket no encryption/access controls → added SSE + public access block

### Best Practices
- [x] No EKS version pinned → added `version = "1.29"`
- [x] Node group config hardcoded → fully parameterized
- [x] No EKS control plane logging → enabled all 5 log types
- [x] Provider versions too loose `>= 5.0` → tightened to `~> 5.0`
- [x] PostgreSQL 14 approaching EOL → upgraded to 16
- [x] No VPC Flow Logs → added for all 3 VPCs
- [x] CloudFront deprecated `forwarded_values` → replaced with `cache_policy_id`
- [x] No SPA error responses on CloudFront → added 403/404 → index.html
- [x] WAF only 1 rule → added SQLi, KnownBadInputs, IP Reputation, Rate Limiting
- [x] Hardcoded AMI ID → replaced with `data.aws_ami` lookup
- [x] Jenkins playbook Java 11 + deprecated `apt_key` → Java 17 + keyrings
- [x] No `.terraform-version` file → added (1.5.7)
- [x] README listed non-existent resources → updated

---

## 2. Automation Challenges

- [x] Manual `backend.tf` edits when switching branches → `tf-init.sh` auto-detects branch
- [x] Manual `docdb_app_secret_arn` copy-paste → auto-resolved from `module.database` output
- [x] Unnecessary `TF_VAR_POSTGRES_PASSWORD` / `TF_VAR_DOCDB_PASSWORD` secrets → removed from workflows

---

## 3. GitHub Actions ↔ AWS Authentication

- [x] OIDC provider missing in AWS → created `token.actions.githubusercontent.com` provider
- [x] `sts:AssumeRoleWithWebIdentity` denied → fix IAM role trust policy (repo name, condition types)
- [x] AWS warning: wildcard `*` in `sub` too broad → use explicit branch list in trust policy

### Trust Policy (Correct Version)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:<YOUR_ORG>/kyc-app:ref:refs/heads/main",
            "repo:<YOUR_ORG>/kyc-app:ref:refs/heads/qa",
            "repo:<YOUR_ORG>/kyc-app:ref:refs/heads/dev",
            "repo:<YOUR_ORG>/kyc-app:pull_request"
          ]
        }
      }
    }
  ]
}
```

---

## 4. AWS Prerequisites Checklist

- [x] S3 Bucket: `my-terraform-trinath` (versioned, encrypted, public access blocked)
- [x] DynamoDB Table: `terraform-locks` (partition key: `LockID`, type: String)
- [ ] EC2 Key Pair: `my-key-pair` (.pem saved securely)
- [x] OIDC Provider: `token.actions.githubusercontent.com`
- [x] IAM Role: trust policy with correct repo name + branch list
- [x] IAM Role: `AdministratorAccess` policy attached (scope down later)

## 5. GitHub Prerequisites Checklist

- [x] Secret: `AWS_ROLE_TO_ASSUME` = IAM role ARN
- [ ] Environment: `prod` with required reviewers
- [ ] Environment: `prod-destroy` with required reviewers

---

## 6. Pipeline Errors Encountered During Deployment

### 6.1 OIDC Provider Not Found
- **Error:** `Could not assume role with OIDC: No OpenIDConnect provider found in your account for https://token.actions.githubusercontent.com`
- **Cause:** OIDC Identity Provider was not created in AWS account
- **Fix:** Created OIDC provider in IAM with URL `https://token.actions.githubusercontent.com` and audience `sts.amazonaws.com`
- **Status:** ✅ Resolved

### 6.2 Role Assumption Denied
- **Error:** `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`
- **Cause:** IAM role trust policy had wrong repo name or wrong condition type
- **Fix:** Updated trust policy — used `StringEquals` for `aud`, `StringLike` for `sub` with exact branch patterns
- **AWS Warning:** Wildcard `*` in `sub` is too broad — replaced with explicit branch list (main, qa, dev, pull_request)
- **Status:** ✅ Resolved

### 6.3 Terraform Format Check Failed (Round 1)
- **Error:** `terraform fmt -check -recursive` flagged `backend.tf` and `networking/main.tf`
- **Cause:** Extra alignment padding in `backend.tf` attributes and inconsistent tag alignment in `networking/main.tf` subnet tags
- **Fix:** Reformatted both files to match `terraform fmt` canonical style
- **Status:** ✅ Resolved

### 6.4 Terraform Format Check Failed (Round 2)
- **Error:** `terraform fmt -check -recursive` still flagged `networking/main.tf`
- **Cause:** 1 space off — `Name` tag in `app_private` subnet needed 1 more space to align `=` with the longest key (`kubernetes.io/cluster/${var.cluster_name}`)
- **Fix:** Downloaded Terraform 1.5.7 locally, ran `terraform fmt` to auto-fix, verified with `terraform fmt -check`
- **Lesson:** Always run `terraform fmt` locally before pushing — manual alignment guesswork causes subtle failures
- **Status:** ✅ Resolved

---

## 7. Deployment Verification

- [ ] `terraform fmt -check` passes
- [ ] `terraform validate` passes
- [ ] Checkov IaC scan passes (or acceptable findings only)
- [ ] PR triggers `terraform plan` and posts summary on PR
- [ ] Merge to main triggers plan → waits for `prod` approval → applies
- [ ] State file created at `prod/terraform.tfstate` in S3
- [ ] All 3 VPCs created successfully
- [ ] EKS cluster reachable (private endpoint)
- [ ] RDS and DocumentDB created with encryption + backups
- [ ] Jenkins and Bastion instances running with IMDSv2
