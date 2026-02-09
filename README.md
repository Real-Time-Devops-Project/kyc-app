# KYC Application Organization

Welcome to the KYC Application organization repository structure.
This project has been restructured to simulate a GitHub Organization where each component resides in its own repository.

## Repositories (Folders)

Here is the breakdown of the repositories:

- **[kyc-frontend](./kyc-frontend)**: The React-based frontend application.
- **[kyc-ekyc-service](./kyc-ekyc-service)**: The Node.js eKYC (Electronic Know Your Customer) microservice.
- **[kyc-vkyc-service](./kyc-vkyc-service)**: The Node.js vKYC (Video Know Your Customer) microservice.
- **[kyc-terraform](./kyc-terraform)**: Infrastructure as Code (Terraform) and Configuration Management (Ansible).

- **[kyc-docs](./kyc-docs)**: Project documentation and architectural diagrams.
- **[kyc-scripts](./kyc-scripts)**: Helper scripts for automation and testing.

## Getting Started

Each repository contains its own `README.md` with specific instructions on how to build, run, and deploy that component.
Please refer to the individual folders for more details.

## Global Prerequisites

- Jenkins (for CI/CD pipelines)
- AWS Account (for deployment)
- Docker & Kubernetes (Local or Cloud)
- Terraform & Ansible
