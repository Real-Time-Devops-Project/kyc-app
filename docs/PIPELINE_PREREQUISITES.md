# Pipeline Prerequisites & Configuration

To run the **DevSecOps Pipeline** successfully for any project, you must configure the following in Jenkins.

## 1. Environment Variables
Set these in the **Pipeline Configuration** (or Global Properties) to make the `Jenkinsfile` reusable.

| Variable Name | Description | Example Value |
| :--- | :--- | :--- |
| `AWS_REGION` | AWS Region for ECR and EKS | `us-east-1` |
| `ECR_REPO_NAME` | Name of the ECR Repository | `kyc-app` |
| `EKS_CLUSTER_NAME` | Name of the EKS Cluster | `kyc-cluster` |
| `SERVICE_NAME` | Name of the service (used for Helm/Deploy) | `ekyc-service` |
| `SERVICE_DIR` | Path to the source code within the repo | `kyc-app/ekyc-service` |
| `HELM_CHART_DIR` | Path to the Helm chart within the repo | `kyc-app/k8s` |
| `SONAR_PROJECT_KEY` | Unique Key for SonarQube Project | `kyc-app` |
| `APP_PORT` | Port the application runs on (for Smoke Test) | `3001` |
| `NODE_TOOL_NAME` | Name of the NodeJS tool installation in Jenkins | `nodejs-22-6-0` |

## 2. Credentials
Ensure these credentials exist in the **Jenkins Credentials Store**.

| ID | Type | Description |
| :--- | :--- | :--- |
| `aws-account-id` | Secret Text | Your 12-digit AWS Account ID (e.g., `123456789012`). |
| `aws-credentials-id` | AWS Credentials | Access Key and Secret Key for AWS access. |
| `sonar-token` | Secret Text | (Optional) Token for SonarQube if not using the System Configuration. |

## 3. Global Tool Configuration
Ensure these tools are installed and named correctly in **Manage Jenkins > Tools**.

| Tool Type | Name in Jenkins | Description |
| :--- | :--- | :--- |
| **NodeJS** | `nodejs-22-6-0` | (Or match the `NODE_TOOL_NAME` variable) |
| **SonarQube Scanner** | `SonarQube Scanner` | For SAST analysis. |
| **Dependency-Check** | `OWASP-Dependency-Check` | For SCA analysis. |

## 4. System Configuration
*   **SonarQube Server**: Configure under **Manage Jenkins > System > SonarQube servers**. Name it `SonarQube`.
