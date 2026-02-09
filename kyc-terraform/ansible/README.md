# KYC - Ansible Configuration

This repository contains Ansible playbooks and roles for configuration management.

## Purpose

- Server hardening.
- Application configuration (if not containerized or for dependencies).
- Deployment automation (if applicable).
- Bastion host configuration.

## Usage

1.  Navigate to `playbooks`.
2.  Run playbook:
    ```bash
    ansible-playbook -i inventory host_setup.yml
    ```
