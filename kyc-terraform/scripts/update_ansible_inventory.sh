#!/bin/bash
set -e

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ROOT_DIR/kyc-terraform/environments/prod"
ANSIBLE_DIR="$ROOT_DIR/kyc-ansible"
INVENTORY_TEMPLATE="$ANSIBLE_DIR/inventory.template"
INVENTORY_FILE="$ANSIBLE_DIR/inventory"

echo "------------------------------------------------"
echo "Updating Ansible Inventory from Terraform Outputs"
echo "------------------------------------------------"

# 1. Check if Terraform has been initialized and applied
if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
    echo "Error: Terraform directory not found or not initialized at $TERRAFORM_DIR"
    echo "Please run 'terraform init' and 'terraform apply' first."
    exit 1
fi

# 2. Extract Outputs from Terraform
echo "Reading Terraform outputs..."
pushd "$TERRAFORM_DIR" > /dev/null

# Check if state file exists
if [ ! -f "terraform.tfstate" ]; then
     echo "Warning: terraform.tfstate not found. Using empty values."
     JENKINS_IP=""
     BASTION_IP=""
else
    JENKINS_IP=$(terraform output -raw jenkins_ip 2>/dev/null || echo "")
    BASTION_IP=$(terraform output -raw bastion_ip 2>/dev/null || echo "")
fi
popd > /dev/null

if [ -z "$JENKINS_IP" ]; then
    echo "Warning: Jenkins IP not found in Terraform outputs."
    JENKINS_IP="PLACEHOLDER_JENKINS_IP"
fi

if [ -z "$BASTION_IP" ]; then
    echo "Warning: Bastion IP not found in Terraform outputs."
    BASTION_IP="PLACEHOLDER_BASTION_IP"
fi

echo "  Jenkins IP: $JENKINS_IP"
echo "  Bastion IP: $BASTION_IP"

# 3. Export variables for envsubst
export JENKINS_IP
export BASTION_IP

# 4. Generate Inventory File
if command -v envsubst >/dev/null 2>&1; then
    echo "Generating inventory using envsubst..."
    envsubst < "$INVENTORY_TEMPLATE" > "$INVENTORY_FILE"
else
    echo "envsubst not found, falling back to sed..."
    sed -e "s/\${JENKINS_IP}/$JENKINS_IP/g" \
        -e "s/\${BASTION_IP}/$BASTION_IP/g" \
        "$INVENTORY_TEMPLATE" > "$INVENTORY_FILE"
fi

echo "Success! Inventory file updated at: $INVENTORY_FILE"
cat "$INVENTORY_FILE"
echo "------------------------------------------------"
