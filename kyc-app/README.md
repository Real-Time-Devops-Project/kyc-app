# KYC Sample Application

This project is a microservices-based KYC (Know Your Customer) application consisting of a React frontend and two Node.js backend services (eKYC and vKYC). It is designed to be deployed on AWS EKS using the accompanying Terraform infrastructure.

## Architecture

- **Frontend**: React.js (Vite)
- **eKYC Service**: Node.js (Express) - Handles electronic KYC verification.
- **vKYC Service**: Node.js (Express) - Handles video KYC sessions.
- **Databases**:
  - **PostgreSQL**: Stores KYC status.
  - **MongoDB (DocumentDB)**: Stores detailed KYC data.
  - **Redis (ElastiCache)**: Caches sessions and status.

## Prerequisites

- Node.js (v18+)
- Docker
- Kubernetes Cluster (EKS)
- kubectl configured

## Build and Run Locally

### 1. Install Dependencies

```bash
cd kyc-app/frontend && npm install
cd ../ekyc-service && npm install
cd ../vkyc-service && npm install
```

### 2. Run Tests

Unit tests are available for the backend services using Jest.

```bash
# eKYC Service
cd kyc-app/ekyc-service
npm test

# vKYC Service
cd kyc-app/vkyc-service
npm test
```

### 3. Build Docker Images

```bash
cd kyc-app
docker build -t kyc-frontend:latest ./frontend
docker build -t ekyc-service:latest ./ekyc-service
docker build -t vkyc-service:latest ./vkyc-service
```

## CI/CD Pipeline

A `Jenkinsfile` is provided in the `kyc-app` directory. It defines the following stages:

1.  **Checkout**: Pulls the code.
2.  **Install Dependencies**: Installs npm packages for all services.
3.  **Static Application Security Testing (SAST)**: Scans code using **SonarQube**.
4.  **Dependency Vulnerability Scan**: Checks dependencies using **OWASP Dependency-Check**.
5.  **Run Tests**: Executes unit tests.
6.  **Build Docker Images**: Builds the container images.
7.  **Container Image Scan**: Scans images using **Trivy**.
8.  **Push to Registry**: Pushes images to ECR (requires configuration).
9.  **Deploy to EKS**: Applies Kubernetes manifests.
10. **Dynamic Application Security Testing (DAST)**: Scans running application using **OWASP ZAP**.

### Jenkins Configuration Requirements

To use this pipeline, ensure your Jenkins environment has:

- **Plugins**:
    - SonarQube Scanner
    - OWASP Dependency-Check
    - HTML Publisher (for ZAP reports)
- **Tools**:
    - `SonarQubeScanner` configured in Global Tool Configuration.
    - `Dependency-Check` configured in Global Tool Configuration.
    - `Trivy` installed on the agent.
    - `Docker` installed and configured.
    - `Kubectl` installed and configured.
- **Credentials**:
    - `sonar-token`: Secret text for SonarQube authentication.
    - AWS Credentials configured on the agent (or via plugin).
- **Environment Variables**:
    - Update `REGISTRY` and `AWS_REGION` in the `Jenkinsfile`.

## Deployment

See [walkthrough.md](../walkthrough.md) for detailed manual deployment steps.
