# 🚀 Atlantis & DevSecOps Architecture

This directory contains the necessary Terraform configuration to deploy the official **Atlantis** server natively on AWS ECS Fargate, providing a fully automated "Terraform in Pull Requests" workflow.

Atlantis is an application that listens for Terraform webhook events from GitHub, GitLab, or Bitbucket. It runs `terraform plan` and `terraform apply` remotely and comments the output directly back onto your Pull Requests.

---

## 🌟 Key Features
- **PR Comments as Commands:** Developers interact with Terraform directly via GitHub comments (e.g., typing `atlantis plan` or `atlantis apply` in the PR).
- **State Locking:** Atlantis locks the Terraform state and the directory being modified until the PR is merged or closed, preventing concurrent modifications and state corruption.
- **VCS Integration:** Natively integrates with GitHub branch protection rules. You can configure Atlantis to only allow `apply` after the PR is approved by a manager.
- **Serverless Architecture:** Deployed on AWS ECS Fargate, meaning there are no EC2 instances to patch or manage.

## 🏆 Why It's Better (Advantages over GitHub Actions)
While serverless GitHub Actions workflows (like our `atlantis-terraform-plan.yml`) are great for simple use-cases, a dedicated Atlantis server offers significant enterprise advantages:

1. **No Context Switching:** Reviewers can see the exact Terraform output in the PR comment thread without clicking away to a GitHub Actions log console.
2. **True State Locking:** GitHub Actions concurrency groups only prevent parallel pipeline execution. Atlantis locks the actual workspace, ensuring that if PR #1 is modifying the `database` module, PR #2 cannot run a plan on the `database` module until PR #1 is merged.
3. **Auditability:** Every command and output is permanently preserved in the GitHub PR comment history, providing a perfect audit trail for compliance.
4. **Security Isolation:** Atlantis runs inside your secure AWS VPC. It does not require you to expose AWS credentials or OIDC roles to GitHub Actions runners.

## 💰 Extra Cost Estimation
Running a dedicated Atlantis server on AWS incurs 24/7 runtime costs. Because this deployment uses **serverless AWS ECS Fargate** and an **Application Load Balancer (ALB)**, here is an estimated monthly cost breakdown (us-east-1):

- **Application Load Balancer (ALB):** ~$16 - $20 / month
- **ECS Fargate Compute (0.25 vCPU, 0.5 GB Memory):** ~$8 - $10 / month
- **Total Estimated Cost:** **$25 - $30 / month**

*Note: You can further reduce compute costs by running Atlantis on Fargate Spot instances or scaling the ECS task to 0 during off-hours using AWS Auto Scaling schedules.*

---

## 🏗️ Atlantis Server Deployment
The `main.tf` file utilizes the official `terraform-aws-modules/atlantis/aws` module. Once deployed, this creates:
1. An Application Load Balancer (ALB) accessible at `atlantis.kyc-app.internal`.
2. An ECS Fargate cluster running the Atlantis container.
3. The necessary IAM roles allowing Atlantis to plan and apply infrastructure directly against your AWS environment.

### How to Deploy
1. **Generate your GitHub Credentials:**
   - **`github_token`**: Go to your GitHub Settings -> Developer Settings -> Personal Access Tokens (Classic). Generate a new token with `repo` scope.
   - **`github_webhook_secret`**: This is just a random string used to secure the webhook payload. You can generate one in your terminal by running `openssl rand -hex 24`.

2. **Export your credentials:**
   ```bash
   export TF_VAR_github_token="<your-generated-personal-access-token>"
   export TF_VAR_github_webhook_secret="<your-generated-random-webhook-secret>"
   ```
2. Run standard Terraform commands from this directory:
   ```bash
   terraform init
   terraform apply
   ```
3. Update your GitHub Repository Webhooks to point to `https://atlantis.kyc-app.internal/events`.

---

## 🔒 DevSecOps Pipeline Integration

If you choose to use the "Serverless Atlantis" GitHub Actions workflow (`.github/workflows/atlantis-terraform-plan.yml`) instead of the dedicated server, it has been upgraded to run several industry-standard security and compliance tools **before** generating the Terraform plan.

### Integrated Tools:
- **Checkov**: Statically analyzes the Terraform HCL code for misconfigurations.
- **Cloud Custodian**: Validates that all YAML auto-remediation policies are syntax-error free.
- **Prowler**: Scans the live AWS environment for identity and access management vulnerabilities.
- **Steampipe**: Runs SQL queries against live AWS APIs to verify compliance.
- **CloudQuery**: Integrates open-source cloud asset inventory management.

### 🚦 The Full DevSecOps Pipeline Flow (In-Depth Architecture)

This section provides a deep dive into the exact execution sequence of our Pull Request CI/CD pipeline. We utilize a "Shift-Left" security model, meaning all validation, compliance checks, and drift detection occur *before* code ever reaches the `main` branch.

#### Phase 1: Pre-Flight & Authentication
1. **Event Trigger Trigger:** A developer opens a Pull Request or pushes new commits. GitHub Actions intercepts the webhook and triggers `.github/workflows/atlantis-terraform-plan.yml`.
2. **OIDC Authentication (`aws-actions/configure-aws-credentials`):** The GitHub Actions runner requests a short-lived JSON Web Token (JWT) from GitHub's OIDC provider. This token is exchanged with AWS IAM (Identity and Access Management) for temporary, least-privilege AWS credentials. No hardcoded `AWS_ACCESS_KEY_ID` secrets are stored or exposed.
3. **Environment Setup:** The runner installs the exact Terraform binary version (`1.5.7`) and configures the environment variables (`TF_IN_AUTOMATION=true`).

#### Phase 2: Static & Dynamic Security Analysis (The Toolchain)
Before Terraform even attempts to connect to the AWS state, the pipeline runs a gauntlet of DevSecOps tools. If configured as "blocking", a failure here instantly halts the pipeline via an `exit 1` code.

1. **Checkov (Static Application Security Testing):**
   - **How it works:** It parses the raw HCL (HashiCorp Configuration Language) files locally.
   - **What it checks:** It looks for known bad patterns based on CIS benchmarks.
   - **Sample Scenario:** A developer writes code to deploy a new RDS Postgres database but forgets to add `storage_encrypted = true`. Checkov flags this, outputs the exact line number, and stops the pipeline.
2. **Cloud Custodian (Policy Validation):**
   - **How it works:** It uses the `c7n` CLI to syntax-check your auto-remediation YAML policies.
   - **Sample Scenario:** A developer makes a typo in `sg-block-public-ssh.yml`. The validation fails, preventing a broken Lambda function from being deployed to AWS.
3. **Prowler (Cloud Security Posture Management):**
   - **How it works:** Prowler authenticates to your live AWS account and runs hundreds of API checks against CIS, NIST, and GDPR frameworks.
   - **Sample Scenario:** Prowler queries the AWS IAM API, discovers an active Root user without MFA enabled, and generates a critical alert in the pipeline log.
4. **Steampipe (Continuous Compliance via SQL):**
   - **How it works:** Steampipe translates AWS APIs into a PostgreSQL database, allowing us to run rapid compliance queries.
   - **Sample Scenario:** The pipeline executes `select * from aws_vpc where is_default = true;`. If it returns a result, it means a default VPC exists (which violates our strict enterprise networking policies), and the pipeline is flagged.
5. **CloudQuery (Asset Inventory):**
   - **How it works:** Connects to AWS to extract the current configuration state of every single resource (EC2, S3, IAM) into a structured schema for advanced offline querying.

#### Phase 3: Terraform Initialization & State Locking
1. **`terraform init`:** The runner executes our `tf-init.sh` script. This downloads the necessary provider plugins (AWS, Random, TLS) and securely connects to our S3 Backend (`kyc-app-terraform-state-prod`).
2. **State Locking:** Terraform connects to the DynamoDB lock table (`kyc-app-terraform-locks`). If another pipeline is currently running an `apply`, Terraform cannot acquire the lock, preventing catastrophic state corruption.

#### Phase 4: Execution Plan & Drift Detection
1. **`terraform plan`:** Terraform reads your `.tf` files, queries the AWS API to see what actually exists in reality, and calculates the exact "diff" required to make reality match your code. The output is saved securely to a binary `tfplan` file.
2. **How Drift is Handled:** "Drift" is when the AWS environment has been manually altered outside of Terraform.
   - **Detection:** If an engineer manually deleted a critical S3 bucket via the AWS Console, the `terraform plan` will detect this drift. The plan output will show `+ create` for that S3 bucket, as Terraform realizes reality is broken and plans to fix it by restoring the bucket.
   - **Visibility:** The manager reviewing the PR will see exactly what manual drift occurred and exactly how the pipeline plans to revert it.

#### Phase 5: Manager Summary & Pipeline Stoppage
1. **JSON Parsing (`human_summary.py`):** Raw Terraform output is difficult for non-technical managers to read. The pipeline converts the binary `tfplan` to JSON, and our Python parser extracts only the relevant data (Action, Resource Name, AWS Region).
2. **PR Comment Injection:** The pipeline uses `actions/github-script` to post the parsed Python summary as a beautiful Markdown table directly into the GitHub PR comment thread.
3. **The Stoppage Mechanism:** Throughout this entire process, GitHub Actions is monitoring the exit codes of every step. 
   - A success code (`0`) allows the pipeline to proceed to the next step.
   - An error code (`1` or `2` in some tools) triggers the GitHub Actions `if: failure()` block.
   - This block runs an explicit `exit 1`, which turns the GitHub PR status check from yellow (Pending) to red (❌ Failed). GitHub branch protection rules then physically block the "Merge" button, ensuring bad code can never reach the `main` branch.

### ⏱️ How to Enable "Full" Blocking Scans
By default, tools like **Prowler** and **CloudQuery** take 15+ minutes to run a complete environment scan. To prevent blocking developer PR velocity, the GitHub Actions workflow currently runs them as targeted/fast scans, and uses `continue-on-error: true`.

**If you want strict, full security scans that BLOCK the PR from merging:**
1. Open `.github/workflows/atlantis-terraform-plan.yml`.
2. Remove `continue-on-error: true` from the respective DevSecOps steps.
3. For Prowler, remove the `--services iam --quiet` flags to run the full CIS framework scan.
4. For CloudQuery, replace the `--version` command with `cloudquery sync <config.yml>` to trigger a full database synchronization of your assets.

---

## 🔄 Developer Workflow
Once Atlantis is deployed and webhooks are configured:
1. A developer opens a Pull Request with Terraform changes.
2. Atlantis automatically runs `terraform plan` and posts the output as a comment.
3. The PR is reviewed. If changes are needed, the developer pushes new commits, and Atlantis automatically posts a new plan.
4. Once the PR is approved, a developer comments `atlantis apply`.
5. Atlantis runs `terraform apply`, streams the output to the PR, and if successful, the PR can be safely merged.
