# Presentation: AWS Enterprise Architecture

## Slide 1: Title
**Secure & Scalable Hub-and-Spoke Architecture on AWS**
*Integrating Terraform, Ansible, and Jenkins*

---

## Slide 2: The Challenge
*   Need for a secure, isolated network environment.
*   Requirement to host microservices (EKS) and multiple database types.
*   Demand for automated deployment and configuration.

---

## Slide 3: The Solution - High Level
*   **Hub-and-Spoke Topology**: Centralized control via Transit Gateway.
*   **Separation of Concerns**: Dedicated VPCs for Transit, Apps, and Management.
*   **Automation First**: Everything defined as code.

---

## Slide 4: Network Deep Dive
*   **Transit VPC**: The "Front Door". Handles all traffic filtering.
*   **App VPC**: The "Safe House". Private subnets only.
*   **Mgmt VPC**: The "Control Room". CI/CD and Admin tools.

---

## Slide 5: The Tech Stack
*   **Infrastructure**: AWS (EKS, RDS, Transit Gateway)
*   **IaC**: Terraform
*   **Config**: Ansible
*   **CI/CD**: Jenkins

---

## Slide 6: Security & Compliance
*   Encrypted at Rest & In Transit.
*   Least Privilege IAM Roles.
*   Network Segmentation via Security Groups & NACLs.

---

## Slide 7: Conclusion
This architecture provides a robust foundation for enterprise growth, balancing security with agility.
