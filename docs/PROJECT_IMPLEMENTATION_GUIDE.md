# 📘 Comprehensive Project Implementation Guide

This document provides a step-by-step guide to setting up, configuring, and deploying the entire infrastructure and application stack. It covers every process from zero to a running application.

---

## 🛠️ Prerequisites

Before starting, ensure you have the following tools installed and configured:
1.  **AWS CLI**: Configured with `aws configure` (Access Key, Secret Key, Region).
2.  **Terraform** (v1.5+): For infrastructure provisioning.
3.  **Ansible**: For server configuration.
4.  **Git**: For version control.
5.  **Kubectl**: For interacting with the EKS cluster.

---

## 🏗️ Phase 1: Infrastructure Provisioning (Terraform)

We use Terraform to create the VPCs, EKS Cluster, RDS, and other AWS resources.

### 1.1. Setup Remote Backend (Manual Step)
Terraform needs an S3 bucket to store its state file (`terraform.tfstate`) securely.
1.  Go to the **AWS Console > S3**.
2.  Create a bucket named `my-company-terraform-state-prod` (or a unique name).
3.  Go to **AWS Console > DynamoDB**.
4.  Create a table named `terraform-state-lock` with Partition key `LockID` (String).
5.  **Update Code**: Open `terraform-project/environments/prod/providers.tf` and update the `bucket` and `dynamodb_table` fields with your names.

### 1.2. Provision Infrastructure
Run the following commands to create the infrastructure:

```bash
cd terraform-project/environments/prod

# Initialize Terraform (downloads providers and configures backend)
terraform init

# Create a Plan (preview changes)
terraform plan -out=tfplan

# Apply the Plan (create resources)
terraform apply tfplan
```
*Type `yes` if prompted (or use auto-approve).*

### 1.3. Capture Outputs
After `terraform apply` completes, note the outputs printed in the terminal. You will need:
*   `jenkins_ip`: Public IP of the Jenkins Server.
*   `bastion_ip`: Public IP of the Bastion Host.
*   `eks_cluster_name`: Name of the EKS cluster.
*   `rds_endpoint`: Database endpoint.

---

## ⚙️ Phase 2: Configuration Management (Ansible)

We use Ansible to install software (Jenkins, Java, Docker, Kubectl) on the EC2 instances created by Terraform.

### 2.1. Update Inventory
1.  Open `ansible/inventory`.
2.  Replace the placeholder IPs with the actual IPs from the Terraform output.
    ```ini
    [jenkins_servers]
    <ACTUAL_JENKINS_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem

    [bastion_servers]
    <ACTUAL_BASTION_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
    ```

### 2.2. Run Playbooks
Execute the playbooks to configure the servers:

```bash
cd ansible

# Configure Jenkins Server
ansible-playbook -i inventory playbook-jenkins.yml

# Harden Bastion Host
ansible-playbook -i inventory playbook-bastion.yml
```

---

## 🤖 Phase 3: Jenkins Configuration

Now that Jenkins is installed, we need to configure it to run our pipelines.

### 3.1. Initial Setup
1.  Open your browser and go to `http://<JENKINS_IP>:8080`.
2.  **Unlock Jenkins**:
    *   SSH into the Jenkins server: `ssh -i key.pem ubuntu@<JENKINS_IP>`
    *   Get the password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
    *   Paste it into the browser.
3.  **Install Plugins**: Select "Install suggested plugins".
4.  **Create Admin User**: Set up your username and password.

### 3.2. Install Required Plugins
Go to **Manage Jenkins > Plugins > Available Plugins** and install:
*   **AWS Credentials**
*   **Pipeline: AWS Steps**
*   **Docker Pipeline**
*   **Terraform** (if using a Terraform plugin, though we often use `sh 'terraform'` directly).

### 3.3. Configure Credentials (CRITICAL STEP)
Jenkins needs permission to talk to AWS and GitHub.

#### A. AWS Credentials
1.  Go to **Manage Jenkins > Credentials > System > Global credentials (unrestricted)**.
2.  Click **Add Credentials**.
3.  **Kind**: `AWS Credentials` (or `Secret text` for separate keys, but AWS Credentials plugin is best).
4.  **ID**: `aws-credentials-id` (**Must match `Jenkinsfile`**).
5.  **Description**: AWS Access for Terraform and EKS.
6.  **Access Key ID**: Your AWS Access Key.
7.  **Secret Access Key**: Your AWS Secret Key.
8.  Click **Create**.

#### B. GitHub Credentials (for SCM)
1.  Click **Add Credentials**.
2.  **Kind**: `Username with password`.
3.  **ID**: `git-credentials` (optional, but good practice).
4.  **Username**: Your GitHub username.
5.  **Password**: Your GitHub **Personal Access Token** (Classic).
    *   *To generate*: GitHub > Settings > Developer settings > Personal access tokens > Tokens (classic) > Generate new token (select `repo` scope).

### 3.4. Create Pipelines

#### Pipeline 1: Infrastructure (Terraform)
1.  **New Item** > Name: `Infrastructure-Deploy` > **Pipeline**.
2.  **Definition**: `Pipeline script from SCM`.
3.  **SCM**: `Git`.
4.  **Repository URL**: `https://github.com/your-user/your-repo.git`.
5.  **Credentials**: Select your GitHub credentials.
6.  **Script Path**: `jenkins/Jenkinsfile.terraform`.
7.  Click **Save**.

#### Pipeline 2: Application (KYC App)
1.  **New Item** > Name: `KYC-App-Deploy` > **Pipeline**.
2.  **Definition**: `Pipeline script from SCM`.
3.  **SCM**: `Git`.
4.  **Repository URL**: `https://github.com/your-user/your-repo.git`.
5.  **Credentials**: Select your GitHub credentials.
6.  **Script Path**: `jenkins/Jenkinsfile.app`.
7.  Click **Save**.

---

## 📦 Phase 4: Application Deployment

### 4.1. Build and Push (CI)
1.  Go to the **KYC-App-Deploy** pipeline in Jenkins.
2.  Click **Build Now**.
3.  **What happens**:
    *   Jenkins checks out the code.
    *   Builds Docker images for Frontend, eKYC, and vKYC services.
    *   Pushes images to AWS ECR (Elastic Container Registry).

### 4.2. Deploy to EKS (CD)
1.  The same pipeline continues to the "Deploy" stage.
2.  It uses `kubectl` and `helm` (configured in the Jenkinsfile) to deploy the app to your EKS cluster.
3.  It updates the Kubernetes `Deployment` to use the new image tag.

---

## ✅ Phase 5: Verification

### 5.1. Verify Infrastructure
Check that all AWS resources are healthy in the AWS Console (VPC, TGW, EKS, RDS).

### 5.2. Verify Application
1.  **Get Load Balancer URL**:
    ```bash
    kubectl get svc kyc-frontend
    ```
2.  **Access in Browser**: Open the External IP/DNS.
3.  **Test Flows**:
    *   Run through the eKYC form submission.
    *   Test the vKYC video call simulation.

---

## 🔐 Phase 6: Deep Dive - Secrets & Database Access

This section details exactly how the application connects to the database and how you manage credentials.

### 6.1. Where do Credentials come from?
*   **RDS (Postgres)**: Defined in `terraform-project/environments/prod/variables.tf` (or `terraform.tfvars`). Look for `db_username` and `db_password`.
*   **DocumentDB (Mongo)**: Similar to RDS, check your Terraform variables.
*   **Endpoints**: These are **Outputs** from your Terraform run (`rds_endpoint`, `docdb_endpoint`, `redis_endpoint`).

### 6.2. Configuring Kubernetes Secrets
The application does **not** have hardcoded passwords. It reads them from a Kubernetes Secret named `db-secrets`.

1.  **Open the Secrets File**:
    Navigate to `kyc-app/k8s/secrets.yaml`.

2.  **Update Values**:
    You must Base64 encode your values or just put them in `stringData` (easier).
    *   `pg-user`: Your Postgres username (e.g., `adminuser`).
    *   `pg-password`: Your Postgres password.
    *   `mongo-uri`: The full connection string for DocumentDB.
        *   Format: `mongodb://<USER>:<PASSWORD>@<DOCDB_ENDPOINT>:27017/kyc?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false`

    **Example `secrets.yaml`**:
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: db-secrets
    type: Opaque
    stringData:
      pg-user: "adminuser"
      pg-password: "SuperSecretPassword123!"
      mongo-uri: "mongodb://admin:pass@docdb-cluster.cluster-xyz.us-east-1.docdb.amazonaws.com:27017/kyc?tls=true..."
    ```

3.  **Apply the Secret**:
    ```bash
    kubectl apply -f kyc-app/k8s/secrets.yaml
    ```

### 6.3. Connecting App to Endpoints
The application deployments (`ekyc-deployment.yaml`, `vkyc-deployment.yaml`) need to know **where** the databases are.

1.  **Open Deployment Files**:
    *   `kyc-app/k8s/ekyc-deployment.yaml`
    *   `kyc-app/k8s/vkyc-deployment.yaml`

2.  **Update Environment Variables**:
    Look for the `env` section. You need to replace the placeholder service names with the **Actual AWS Endpoints** you got from Terraform outputs.

    *   **Postgres**:
        ```yaml
        - name: PG_HOST
          value: "terraform-2023...us-east-1.rds.amazonaws.com" # <-- REPLACE THIS
        ```
    *   **Redis**:
        ```yaml
        - name: REDIS_URL
          value: "redis://clustercfg.my-redis.xyz.use1.cache.amazonaws.com:6379" # <-- REPLACE THIS
        ```

3.  **Re-apply Deployments**:
    ```bash
    kubectl apply -f kyc-app/k8s/ekyc-deployment.yaml
    kubectl apply -f kyc-app/k8s/vkyc-deployment.yaml
    ```

### 6.4. How Access Works (The Flow)
1.  **Pod Starts**: Kubernetes starts the `ekyc-service` pod.
2.  **Env Injection**: Kubernetes reads `db-secrets` and injects `PG_USER` and `PG_PASSWORD` as environment variables into the container.
3.  **App Startup**: The Node.js app reads `process.env.PG_USER`, `process.env.PG_HOST`, etc.
4.  **Connection**: The app uses these values to open a connection to the RDS instance in the Private Subnet.
For a production-grade setup, we use a "Golden Image" for Jenkins itself.
1.  Navigate to `Creating-Golden-Image-For-Jenkins/`.
2.  Follow the `README.md` there to run the Packer pipeline.
3.  This creates an AMI with Jenkins pre-installed.
4.  Update your Terraform code to use this AMI ID for the Jenkins instance instead of a generic Ubuntu AMI.
