# KYC - Infrastructure as Code (Terraform)

This repository contains the Terraform configuration files for provisioning the AWS infrastructure required to run the KYC application.

## Infrastructure Components

- VPC (Virtual Private Cloud)
- Subnets (Public/Private)
- NAT Gateway
- EKS (Elastic Kubernetes Service) Cluster
- IAM Roles and Policies
- Security Groups
- RDS (for PostgreSQL)
- ElasticCache (Redis)
- ECR Repositories

## Usage

1.  Install Terraform (v1.5+).
2.  Navigate to the relevant environment folder (e.g., `environments/dev`).
3.  Initialize Terraform:
    ```bash
    terraform init
    ```
4.  Plan the infrastructure:
    ```bash
    terraform plan
    ```
5.  Applying Changes (Use Caution):
    ```bash
    terraform apply
    ```

## Structure

- `modules/`: Reusable Terraform modules (vpc, eks, etc.).
- `environments/`: Environment-specific configurations (dev, prod).
