#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$TERRAFORM_ROOT")"

ENVIRONMENT="${1:-prod}"
ENABLE_IAM_AUTH="${2:-true}"
TERRAFORM_DIR="$TERRAFORM_ROOT/environments/$ENVIRONMENT"

if [ "$ENVIRONMENT" = "prod" ]; then
  VALUES_FILE="$REPO_ROOT/kyc-k8s/values-prod.yaml"
else
  VALUES_FILE="$REPO_ROOT/kyc-k8s/values-$ENVIRONMENT.yaml"
fi

if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "Terraform environment directory not found: $TERRAFORM_DIR"
  exit 1
fi

if [ ! -f "$VALUES_FILE" ]; then
  echo "Helm values file not found: $VALUES_FILE"
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform command not found"
  exit 1
fi

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python3 or python command not found"
  exit 1
fi

IRSA_ROLE_ARN="$(terraform -chdir="$TERRAFORM_DIR" output -raw kyc_app_irsa_role_arn)"

if [ -z "$IRSA_ROLE_ARN" ]; then
  echo "Terraform output kyc_app_irsa_role_arn is empty"
  exit 1
fi

"$PYTHON_BIN" - "$VALUES_FILE" "$IRSA_ROLE_ARN" "$ENABLE_IAM_AUTH" <<'PY'
import re
import sys
from pathlib import Path

values_path = Path(sys.argv[1])
irsa_role_arn = sys.argv[2]
enable_iam_auth = sys.argv[3].lower()

if enable_iam_auth not in {"true", "false"}:
    raise SystemExit("ENABLE_IAM_AUTH must be true or false")

text = values_path.read_text()

text = re.sub(
    r'(eks\.amazonaws\.com/role-arn:\s*)".*?"',
    rf'\1"{irsa_role_arn}"',
    text,
)

text = re.sub(
    r'(\n\s*postgres:\n\s*iamAuthEnabled:\s*)(true|false)',
    rf'\1{enable_iam_auth}',
    text,
)

values_path.write_text(text)
PY

echo "Updated $VALUES_FILE"
echo "  eks.amazonaws.com/role-arn: $IRSA_ROLE_ARN"
echo "  database.postgres.iamAuthEnabled: $ENABLE_IAM_AUTH"
