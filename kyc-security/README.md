# 🛡️ KYC Security Repository

Welcome to the centralized Security Operations repository for the KYC Application. This repository is dedicated to continuous compliance, auto-remediation, and Security Orchestration, Automation, and Response (SOAR).

## 🎯 Repository Purpose
This repository manages our active defense layer. It contains policies that automatically fix misconfigured AWS resources (like encrypting S3 buckets) and microservices that automatically format security alerts into structured Jira tickets.

## 🛠️ Technology Stack
- **Policy Engine**: Cloud Custodian (`c7n`)
- **Serverless Compute**: AWS Lambda (Python 3.12)
- **CI/CD**: GitHub Actions & Jenkins

### Key Resources Managed:
1. **Cloud Custodian (`kyc-custodian/`)**: 
   - YAML-based rules that map to AWS CloudTrail events.
   - Example: If a user creates an S3 bucket without encryption, Cloud Custodian triggers an AWS Lambda to automatically encrypt it within seconds.
2. **AWS SOAR (`aws-soar/`)**:
   - A Python-based AWS Lambda microservice.
   - It intercepts raw security JSON alerts from Microsoft Defender, Sentinel, or PagerDuty.
   - It automatically enriches the data (generating deep-links to hunting queries) and formats it into clean Atlassian Document Format (ADF) for Jira incidents.

---

## 🔑 Environment Variables & Secrets

### 1. `TENANT_ID` (For AWS SOAR)
- **What it is**: Your Microsoft 365 / Azure Tenant ID used to generate the correct Microsoft Defender incident URLs in the Jira tickets.
- **Where to use it**: Configured as an Environment Variable in the AWS Lambda function (`kyc-soar-formatter`).
- **How to create**: Retrieve this from your Azure Active Directory properties and inject it during the Terraform deployment of the SOAR module.

### 2. `AWS_ROLE_TO_ASSUME`
- **What it is**: The OIDC AWS IAM Role ARN used by GitHub Actions to deploy the Lambda functions and Custodian policies.
- **Where to use it**: GitHub Secrets (`secrets.AWS_ROLE_TO_ASSUME`).

---

## 🚀 CI/CD Pipeline & Workflow

1. **Policy Validation**: 
   - Every PR runs a syntax check using `custodian validate` to ensure no malformed YAML policies are pushed.
2. **Deployment**:
   - Upon merging to `main`, the `custodian-deploy.yml` action translates the YAML into AWS Lambda functions and CloudWatch Event Rules.
   - The `soar-deploy.yml` action zips the Python source code and updates the `kyc-soar-formatter` Lambda.
3. **Jenkins**: A `Jenkinsfile` is provided in the root directory mirroring this exact deployment logic.
