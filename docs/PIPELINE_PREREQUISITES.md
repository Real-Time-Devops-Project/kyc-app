# Pipeline Prerequisites & Configuration

To successfully run the **DevSecOps Pipeline** for the KYC App, you must configure the following in your Jenkins environment.

---

## 1. Which Jenkinsfile to Use?

*   **Primary Pipeline:** `kyc-app/Jenkinsfile`
    *   **Use Case:** This is the main pipeline for the project. It handles the full build, scan, and deploy process for all services (`frontend`, `ekyc-service`, `vkyc-service`).
    *   **Location:** Root of the `kyc-app` folder.
*   **Template Pipeline:** `jenkins/Jenkinsfile.app`
    *   **Use Case:** A reusable/parameterized example for single services. Use this if you want to create separate jobs for each microservice.

---

## 2. Infrastructure Requirements (Jenkins VM)

Since this pipeline runs **SCA (Dependency-Check)**, **SAST (SonarQube)**, and **Docker Builds**, the Jenkins agent requires significant resources.

| Resource | Minimum | Recommended | Why? |
| :--- | :--- | :--- | :--- |
| **Instance Type** | `t3.large` (2 vCPU, 8GB RAM) | **`t3.xlarge` (4 vCPU, 16GB RAM)** | OWASP Dependency-Check and SonarQube Scanner are memory-intensive. |
| **Disk Space** | 30 GB | **50 GB+** | Docker images and build artifacts consume space quickly. |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS | Standard compatibility. |

### Required CI Tools on the Controller/Agent
These tools must be installed **on the server hosting Jenkins** (or the agent node):
1.  **Docker:** `sudo apt install docker.io && sudo usermod -aG docker jenkins` (Critical: Jenkins user must run docker).
2.  **AWS CLI v2:** For ECR login and EKS updates.
3.  **Kubectl:** To deploy manifests to EKS.
4.  **Trivy:** `sudo apt install trivy` (For container scanning).
5.  **Node.js (LTS):** If pipeline does not use the NodeJS plugin tool, install globally: `sudo apt install nodejs npm`.

---

## 3. Jenkins Plugins & Configuration

Install these plugins via **Manage Jenkins > Plugins**.

| Plugin Name | Purpose |
| :--- | :--- |
| **Pipeline: Workflow** | Core pipeline functionality. |
| **Git** | To checkout the repository. |
| **Docker Pipeline** | Allows `docker.build()` and `withRegistry()` commands. |
| **OWASP Dependency-Check** | Analyzes dependencies for CVEs. |
| **SonarQube Scanner** | Integrates with SonarQube Server. |
| **NodeJS** | Manages Node versions (Highly Recommended). |
| **HTML Publisher** | Publishes reports (Zap, Trivy) to the build dashboard. |
| **CloudBees AWS Credentials** | Securely injects AWS keys. |

### Global Tool Configuration (Manage Jenkins > Tools)
1.  **NodeJS:** Name it `nodejs-22-6-0`.
2.  **SonarQube Scanner:** Name it `SonarQubeScanner` (Install automatically).
3.  **Dependency-Check:** Name it `Dependency-Check` (Install automatically from Version 9.0+).

---

## 4. Required Accounts & Credentials

You need to connect Jenkins to external services. Add these IDs in **Manage Jenkins > Credentials**.

| ID | Kind | Value Description |
| :--- | :--- | :--- |
| **`aws-credentials-id`** | **AWS Credentials** | Your AWS **Access Key ID** and **Secret Access Key**. User needs `AmazonEC2ContainerRegistryFullAccess` and `AmazonEKSClusterPolicy`. |
| **`sonar-token`** | **Secret Text** | User Token generated in SonarQube (User > My Account > Security > Generate Token). |
| **`aws-account-id`** | **Secret Text** | Your 12-digit AWS Account ID (e.g., `123456789012`). |

---

## 5. How to Create the Jenkins Job (Main Branch)

Follow these steps to set up the pipeline for the `main` branch:

1.  **New Item:** Go to Jenkins Dashboard > **New Item**.
2.  **Name:** Enter `kyc-app-pipeline`.
3.  **Type:** Select **Multibranch Pipeline** (Best Practice) or **Pipeline**.
    *   *Why Multibranch?* It automatically detects `Jenkinsfile` in all branches.
4.  **Configuration (If "Pipeline"):**
    *   **Definition:** Pipeline script from SCM.
    *   **SCM:** Git.
    *   **Repository URL:** `https://github.com/Start-Smart-2024/kyc-app.git` (Use your actual repo URL).
    *   **Branch Specifier:** `*/main`.
    *   **Script Path:** `kyc-app/Jenkinsfile` (**Crucial**: Point to the correct file).
5.  **Save & Run:** Click **Build Now**.

---

## 6. Environment Variables (Required)

Confirm these values in your `Jenkinsfile` environment block or Global Config:

*   `AWS_REGION`: e.g., `us-east-1`
*   `REGISTRY`: Your ECR URI (e.g., `123456789.dkr.ecr.us-east-1.amazonaws.com`)
*   `SONAR_TOKEN`: (Injected via credentials)

---

## 7. Terraform Pipeline Configuration (Infrastructure as Code)

In addition to the application pipeline, this project uses Jenkins to manage AWS infrastructure.

### Which Pipeline to Use?

*   **Provisioning Infrastructure:** `jenkins/Jenkinsfile.terraform`
    *   **Purpose:** Runs `terraform plan` and `terraform apply`.
    *   **Features:** Includes `tfsec` scanning for security misconfigurations.
    *   **Branch:** Runs `apply` ONLY on `main` branch (after manual approval in Jenkins).
*   **Destroying Infrastructure:** `jenkins/Jenkinsfile.destroy`
    *   **Purpose:** TEARS DOWN the entire environment (`terraform destroy`).
    *   **Safety:** Includes a manual approval step ("Are you sure?").

### Terraform Specific Prerequisites

1.  **Jenkins Plugins:**
    *   **Terraform Plugin:** To manage Terraform installations.
    *   **AnsiColor:** (Optional) To make Terraform output readable.

2.  **Tools Configuration:**
    *   **Terraform:** Install Terraform (v1.5+) in **Manage Jenkins > Tools**. Name it `Terraform`.
    *   **tfsec:** Install `tfsec` on the agent:
        ```bash
        curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
        ```

3.  **Environment Variables:**
    *   `TF_VAR_region`: The AWS region (matches `AWS_REGION`).

4.  **Job Setup (Provisioning):**
    *   **Name:** `kyc-infrastructure-provision`
    *   **Script Path:** `jenkins/Jenkinsfile.terraform`
    *   **Webhook:** Configure GitHub hook to trigger on commits to `terraform-project/`.

5.  **Job Setup (Destroy):**
    *   **Name:** `kyc-infrastructure-destroy`
    *   **Script Path:** `jenkins/Jenkinsfile.destroy`
    *   **Trigger:** **DO NOT** set a webhook. Run this manually only.
