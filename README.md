# 🚀 Enterprise Hub-and-Spoke Architecture on AWS

Welcome to the **End-to-End Infrastructure Project**. This repository contains the complete Infrastructure as Code (IaC) solution for a secure, scalable, and production-ready enterprise environment.

---

## 🏗️ Architecture Overview

This project implements a **Hub-and-Spoke** network topology using AWS Transit Gateway. It strictly separates concerns into **Transit** (Ingress/Egress), **Application** (Workloads), and **Management** (Tools) VPCs.

### 📊 Connectivity Flow Chart

The following diagram illustrates how traffic flows from the user, through the secure edge, and into your applications.

```mermaid
graph TD
    %% Nodes
    User((👤 User))
    
    subgraph Edge_Layer [🌐 Edge Layer]
        CF[CloudFront CDN]
        WAF[🛡️ AWS WAF]
        S3_Web[🪣 S3 Static Web]
    end

    subgraph AWS_Cloud [☁️ AWS Cloud]
        
        subgraph Transit_VPC [🚦 Transit VPC (Hub)]
            IGW[Internet Gateway]
            subgraph Untrusted_Zone [🚫 Untrusted Zone]
                FW_ENI[🔥 Firewall / Proxy]
            end
            subgraph Trusted_Zone [✅ Trusted Zone]
                TGW_Attach[TGW Attachment]
            end
            TGW[⚡ Transit Gateway]
        end

        subgraph App_VPC [⚙️ Application VPC (Spoke A)]
            EKS[☸️ EKS Cluster]
            RDS[🗄️ RDS Database]
            DocDB[📄 DocumentDB]
            Redis[⚡ Redis Cache]
        end

        subgraph Mgmt_VPC [🛠️ Management VPC (Spoke B)]
            Jenkins[🏗️ Jenkins Server]
            Bastion[🏰 Bastion Host]
            Proxy[🕵️ Proxy Server]
        end
    end

    %% Edges / Flows
    User -->|HTTPS| CF
    CF -->|Inspect| WAF
    WAF -->|Allowed| S3_Web
    
    User -->|SSH/Admin| IGW
    IGW --> Untrusted_Zone
    FW_ENI -->|Filter Traffic| Trusted_Zone
    Trusted_Zone --> TGW
    
    TGW == Peering ==> App_VPC
    TGW == Peering ==> Mgmt_VPC
    
    Jenkins -->|Deploy| EKS
    EKS -->|Read/Write| RDS
    EKS -->|Cache| Redis
    
    style User fill:#f9f,stroke:#333,stroke-width:2px
    style TGW fill:#ff9900,stroke:#333,stroke-width:2px
    style EKS fill:#326ce5,stroke:#333,stroke-width:2px
    style WAF fill:#dd0000,stroke:#333,stroke-width:2px
```

---

## 🔄 Exact Traffic Flow: What Happens?

### 1. 🌍 Web Application Access (The "Happy Path")
1.  **User** visits `https://www.your-app.com`.
2.  Request hits **CloudFront** (Edge Location).
3.  **AWS WAF** inspects the request for SQL injection, XSS, and bad bots.
4.  If safe, CloudFront serves the static content (React/Angular/Vue) from the **S3 Bucket**.

### 2. 🛡️ Secure Administrative Access
1.  **Admin** initiates an SSH connection.
2.  Traffic enters the **Transit VPC** via the Internet Gateway.
3.  Routing rules force traffic into the **Untrusted Subnet**.
4.  A **Firewall Appliance** (or Proxy) inspects the packet.
5.  If allowed, traffic moves to the **Trusted Subnet** and then the **Transit Gateway**.
6.  Transit Gateway routes the connection to the **Bastion Host** in the Management VPC.

### 3. ⚙️ Application Logic & Data
1.  The Web App (Frontend) makes API calls to the Backend running on **EKS**.
2.  Traffic flows through the **Application Load Balancer (ALB)**.
3.  **EKS Worker Nodes** process the request.
4.  Microservices read/write data to **RDS (PostgreSQL)** or **DocumentDB**.
5.  Frequently accessed data is cached in **Redis** for speed.

---

## 📦 Project Structure

| Directory | Description |
| :--- | :--- |
| `📂 terraform-project/modules` | Reusable Terraform modules (Networking, EKS, Security, etc.) |
| `📂 terraform-project/environments/prod` | **Production** environment configuration (The "Root" module) |
| `📂 ansible` | Playbooks to configure Jenkins and harden Bastion servers |
| `📂 jenkins` | CI/CD Pipelines (`Jenkinsfile`) for Infra and App deployment |
| `📂 Creating-Golden-Image-For-Jenkins` | Automated pipeline to build hardened Jenkins Golden AMI |
| `📂 docs` | Detailed Architecture Guide and Presentation slides |

---

## 🚀 How to Deploy

### Prerequisites
*   AWS CLI installed and configured.
*   Terraform v1.5+ installed.
*   Ansible installed.

### Step 1: Provision Infrastructure
```bash
cd terraform-project/environments/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 2: Configure Servers
```bash
cd ansible
# Update inventory file with new IPs from Terraform output
ansible-playbook -i inventory playbook-jenkins.yml
ansible-playbook -i inventory playbook-bastion.yml
```

### Step 3: Deploy Application
*   Push your code to the repository.
*   Jenkins will automatically trigger the `Jenkinsfile.app` pipeline.
*   The app will be deployed to the EKS cluster!

---

## ✨ Key Features
*   **Zero Trust Network**: Strict isolation between Trusted and Untrusted zones.
*   **High Availability**: Multi-AZ deployment for all critical components.
*   **Security First**: WAF, NACLs, Security Groups, and Encryption everywhere.
*   **Automated**: Full CI/CD integration with Jenkins.

---

## 🛡️ Zero Trust Security Implementation

This project implements **Zero Trust Security** principles throughout the infrastructure. Zero Trust is a security framework that eliminates implicit trust and requires continuous verification of every user, device, and application.

### Core Principles
1. **Verify Explicitly** - Always authenticate and authorize based on all available data
2. **Least Privilege Access** - Grant users the minimum permissions necessary
3. **Assume Breach** - Design systems as if they're already compromised

### Documentation
*   📚 **[Zero Trust Security Guide](./docs/ZERO_TRUST_SECURITY.md)** - Complete conceptual overview with diagrams
*   🔧 **[Implementation Examples](./docs/ZERO_TRUST_IMPLEMENTATION_EXAMPLES.md)** - Ready-to-use configuration files
*   🛡️ **[DevSecOps Strategy](./docs/DEVSECOPS_STRATEGY.md)** - Security tools and pipeline integration

### Key Implementations
*   ✅ Network micro-segmentation with Kubernetes Network Policies
*   ✅ IAM roles with least privilege and MFA enforcement
*   ✅ AWS Secrets Manager for centralized secret management
*   ✅ Service mesh (Istio) for mTLS encryption
*   ✅ Continuous monitoring with CloudWatch and GuardDuty
*   ✅ Session Manager for secure, audited access (no SSH keys)

👉 **[Start with Zero Trust Basics](./docs/ZERO_TRUST_SECURITY.md)**

---

## 🌟 Jenkins Golden Image Workflow
We use a "Golden Image" approach for Jenkins High Availability. This ensures that our Jenkins server is immutable, secure, and pre-configured.

*   **Automated Pipeline**: Uses Terraform, Packer, and Ansible to build a hardened AMI.
*   **High Availability**: The AMI is used in an Auto Scaling Group with EFS for shared state.
*   **Self-Healing**: If a Jenkins node fails, a new one launches immediately with all configurations intact.

👉 **[View Full Golden Image Documentation](./Creating-Golden-Image-For-Jenkins/README.MD)**

---

## KYC Application Walkthrough
This document provides instructions on how to build, deploy, and verify the KYC Sample Application on your existing Terraform infrastructure.

### Prerequisites
*   **Docker**: To build the container images.
*   **Kubectl**: Configured to communicate with your EKS cluster.
*   **Terraform**: To provision the infrastructure (if not already done).

### 1. Build Docker Images
Navigate to the kyc-app directory and build the images for each service.

```bash
cd kyc-app
# Build Frontend
docker build -t kyc-frontend:latest ./frontend
# Build eKYC Service
docker build -t ekyc-service:latest ./ekyc-service
# Build vKYC Service
docker build -t vkyc-service:latest ./vkyc-service
```

> [!NOTE]
> In a real production environment, you would tag these images with a registry URL (e.g., ECR) and push them: `docker push <account_id>.dkr.ecr.<region>.amazonaws.com/kyc-frontend:latest`.

### 2. Deploy to Kubernetes
Apply the manifests located in the k8s directory.

```bash
# Apply Secrets (Update values in secrets.yaml first!)
kubectl apply -f kyc-app/k8s/secrets.yaml
# Apply Deployments and Services
kubectl apply -f kyc-app/k8s/ekyc-deployment.yaml
kubectl apply -f kyc-app/k8s/vkyc-deployment.yaml
kubectl apply -f kyc-app/k8s/frontend-deployment.yaml
```

### 3. Verify Deployment
Check the status of the pods and services.

```bash
kubectl get pods
kubectl get services
```
You should see pods for `kyc-frontend`, `ekyc-service`, and `vkyc-service` in Running state.

### 4. Access the Application

#### Step-by-Step Execution Guide
Follow these steps in order to access the application:

1.  **Get the Frontend URL**: Run the following command to get the external IP or DNS name of the frontend service:
    ```bash
    kubectl get svc kyc-frontend
    ```
    Look for the `EXTERNAL-IP` column.
    *   If it shows an IP (e.g., 35.x.x.x), your URL is `http://35.x.x.x`.
    *   If it shows a hostname (e.g., xxx.us-east-1.elb.amazonaws.com), your URL is `http://xxx.us-east-1.elb.amazonaws.com`.

2.  **Open in Browser**: Copy the URL from step 1 and paste it into your web browser. You should see the "Vision KYC" dashboard.

3.  **Verify Backend Services**: The frontend communicates with the backend services internally within the cluster. You do not need to access the backend services directly via a browser URL.
    *   eKYC Service: Internal URL `http://ekyc-service` (configured in frontend env vars).
    *   vKYC Service: Internal URL `http://vkyc-service` (configured in frontend env vars).

    To verify they are running without using the frontend, you can port-forward:
    ```bash
    # Forward eKYC service to localhost:3001
    kubectl port-forward svc/ekyc-service 3001:80
    # Now access http://localhost:3001/health in your browser
    ```

#### Verification Steps
1.  **Home Page**: You should see the "Vision KYC" dashboard with options for eKYC and vKYC.
2.  **eKYC Flow**:
    *   Click "Start eKYC".
    *   Fill in the form (Aadhaar, Name).
    *   Click "Submit".
    *   You should see a success message. This verifies the connection to the eKYC service, Postgres (status update), MongoDB (data storage), and Redis (caching).
3.  **vKYC Flow**:
    *   Click "Start vKYC".
    *   Click "Start Video Call".
    *   The interface should simulate a connection and show a video placeholder.
    *   Click "End Call".
    *   This verifies the vKYC service logic.

#### Troubleshooting
*   **Database Connection Errors**: Check the logs of the pods `kubectl logs <pod_name>`. Ensure the `db-secrets` are correctly populated with the RDS, DocumentDB, and ElastiCache endpoints from your Terraform outputs.
*   **Frontend API Errors**: Ensure the `VITE_EKYC_URL` and `VITE_VKYC_URL` environment variables in `frontend-deployment.yaml` point to the correct internal service DNS (e.g., `http://ekyc-service`).