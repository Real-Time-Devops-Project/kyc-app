#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tf-init.sh – Branch-aware Terraform backend initializer
#
# Detects the current git branch and maps it to the correct S3 backend key
# so you never have to manually edit backend.tf when switching branches.
#
# Usage (from kyc-terraform/environments/prod):
#   bash ../../scripts/tf-init.sh
#
# Or from the repo root:
#   bash kyc-terraform/scripts/tf-init.sh
#
# Branch → Key mapping:
#   main  → prod/terraform.tfstate
#   qa    → qa/terraform.tfstate
#   dev   → dev/terraform.tfstate
#   *     → <branch>/terraform.tfstate   (any other branch)
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Detect current git branch ─────────────────────────────────────────────
# CI systems often set standard env vars instead of a real git HEAD.
if [ -n "${GITHUB_REF_NAME:-}" ]; then
  BRANCH="$GITHUB_REF_NAME"
elif [ -n "${BRANCH_NAME:-}" ]; then
  # Jenkins sets BRANCH_NAME
  BRANCH="$BRANCH_NAME"
else
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
fi

echo "Detected branch: $BRANCH"

# ── Map branch to backend key ─────────────────────────────────────────────
case "$BRANCH" in
  main)
    TF_BACKEND_KEY="prod/terraform.tfstate"
    ;;
  qa)
    TF_BACKEND_KEY="qa/terraform.tfstate"
    ;;
  dev)
    TF_BACKEND_KEY="dev/terraform.tfstate"
    ;;
  *)
    TF_BACKEND_KEY="${BRANCH}/terraform.tfstate"
    ;;
esac

echo "Using backend key: $TF_BACKEND_KEY"

# ── Resolve the Terraform working directory ───────────────────────────────
# If we're already inside environments/prod, use current dir.
# Otherwise, navigate to the expected Terraform root module.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../environments/prod"

if [ -f "backend.tf" ]; then
  # Already in the Terraform root module directory.
  TF_DIR="."
elif [ -f "${TF_DIR}/backend.tf" ]; then
  TF_DIR="${TF_DIR}"
else
  echo "ERROR: Cannot find backend.tf. Run this script from the Terraform"
  echo "       root module or from the repo root."
  exit 1
fi

# ── Run terraform init with the computed backend key ──────────────────────
echo "Running: terraform -chdir=${TF_DIR} init -input=false -backend-config=\"key=${TF_BACKEND_KEY}\" $*"
terraform -chdir="${TF_DIR}" init -input=false -backend-config="key=${TF_BACKEND_KEY}" "$@"
