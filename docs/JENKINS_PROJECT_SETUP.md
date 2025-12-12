# Jenkins Project Setup Guide (Windows Environment)

This guide provides step-by-step instructions to set up the three required projects on your **Windows Jenkins Server**.

---

## ⚙️ Part 1: Global Configuration (Prerequisites)

Before creating the projects, ensure your Jenkins server is configured correctly.

### 1. Install Required Plugins
Go to **Manage Jenkins > Plugins > Available Plugins** and install:
*   **Pipeline**: Basic pipeline functionality.
*   **Git**: For checking out source code.
*   **NodeJS**: For the Application pipeline.
*   **SonarQube Scanner**: For SAST analysis.
*   **OWASP Dependency-Check**: For SCA analysis.
*   **Docker Pipeline**: To build and push images.
*   **Amazon EC2 / AWS Credentials**: For AWS integration.
*   **JUnit**: For test result reporting.
*   **HTML Publisher**: For publishing coverage and security reports.

### 2. Configure Tools
Go to **Manage Jenkins > Tools**:
*   **NodeJS**: Add a new installation.
    *   **Name**: `nodejs-22-6-0` (Must match `Jenkinsfile.app`).
    *   **Install automatically**: Checked.
*   **SonarQube Scanner**: Add a new installation.
    *   **Name**: `SonarQube Scanner`.
    *   **Install automatically**: Checked.
*   **Dependency-Check**: Add a new installation.
    *   **Name**: `OWASP-Dependency-Check`.
    *   **Install automatically**: Checked.

### 3. Configure Credentials
Go to **Manage Jenkins > Credentials > System > Global credentials**:
*   **AWS Credentials (for App/Infra)**:
    *   **Kind**: AWS Credentials (or Username with password if plugin missing).
    *   **ID**: `aws-credentials-id`
    *   **Access Key / Secret Key**: Enter your AWS keys.
*   **AWS Account ID**:
    *   **Kind**: Secret text.
    *   **ID**: `aws-account-id`
    *   **Secret**: Your 12-digit AWS Account ID.
*   **Golden Image Credentials**:
    *   **Kind**: Secret text (or Username/Password depending on pipeline usage).
    *   **ID**: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (The Golden Image pipeline specifically asks for these IDs).

---

## 🛠️ Part 2: Project Setup Instructions

### Project 1: Golden Image Pipeline
*   **Purpose**: Creates the Golden AMI for Jenkins Agents.
*   **Type**: Pipeline

**Steps:**
1.  **New Item**: Click "New Item", enter name **`Golden-Image-Build`**, select **Pipeline**, click OK.
2.  **General**: Check "Do not allow concurrent builds".
3.  **Pipeline**:
    *   **Definition**: Pipeline script from SCM.
    *   **SCM**: Git.
    *   **Repository URL**: Path to your repo (e.g., `file:///C:/Users/ThrinathaReddy/PycharmProjects/terraform` or your GitHub URL).
    *   **Script Path**: `Creating-Golden-Image-For-Jenkins/goldimage/jenkinsfile`
4.  **Agent Requirement**: This pipeline uses `agent { label 'packer' }`. You must have a node/agent with the label `packer` configured, OR change the Jenkinsfile to `agent any` if running on the master.
5.  **Save**.

### Project 2: Infrastructure Pipeline
*   **Purpose**: Deploys AWS Infrastructure (VPC, EKS, RDS) using Terraform.
*   **Type**: Pipeline

**Steps:**
1.  **New Item**: Enter name **`Infrastructure-Deploy`**, select **Pipeline**, click OK.
2.  **Pipeline**:
    *   **Definition**: Pipeline script from SCM.
    *   **SCM**: Git.
    *   **Repository URL**: Your repo URL.
    *   **Script Path**: `jenkins/Jenkinsfile.terraform`
3.  **Save**.

### Project 3: Application Pipeline (DevSecOps)
*   **Purpose**: Builds, Tests, Scans, and Deploys the `kyc-app`.
*   **Type**: Pipeline

**Steps:**
1.  **New Item**: Enter name **`KYC-App-Deploy`**, select **Pipeline**, click OK.
2.  **This project is parameterized**: Check this box.
3.  **Add Parameters** (String Parameter) as defined in `docs/PIPELINE_PREREQUISITES.md`:
    *   `SERVICE_NAME`: Default `ekyc-service`
    *   `AWS_REGION`: Default `us-east-1`
    *   `ECR_REPO_NAME`: Default `kyc-app`
    *   `EKS_CLUSTER_NAME`: Default `kyc-cluster`
    *   (Add others as needed: `APP_PORT`, `SONAR_PROJECT_KEY`, etc.)
4.  **Pipeline**:
    *   **Definition**: Pipeline script from SCM.
    *   **SCM**: Git.
    *   **Repository URL**: Your repo URL.
    *   **Script Path**: `jenkins/Jenkinsfile.app`
5.  **Save**.

### Project 4: Infrastructure Destroy Pipeline
*   **Purpose**: ⚠️ Destroys the entire AWS Infrastructure. Use with caution.
*   **Type**: Pipeline

**Steps:**
1.  **New Item**: Enter name **`Infrastructure-Destroy`**, select **Pipeline**, click OK.
2.  **Pipeline**:
    *   **Definition**: Pipeline script from SCM.
    *   **SCM**: Git.
    *   **Repository URL**: Your repo URL.
    *   **Script Path**: `jenkins/Jenkinsfile.destroy`
3.  **Save**.

---

## 🚀 How to Run
1.  **Golden Image**: Run this **first** (or once) to generate the AMI.
2.  **Infrastructure**: Run this **second** to provision the EKS cluster and Network.
3.  **Application**: Run this **last** (and frequently) to deploy the code.
4.  **Destroy**: Run this **ONLY** when you want to tear down everything.
