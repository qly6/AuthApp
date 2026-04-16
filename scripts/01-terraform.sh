#!/bin/bash
# -----------------------------------------
# Provision EKS via Terraform
# -----------------------------------------

set -e
source ./scripts/env.sh

TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform/eks"

echo "📌 Running Terraform apply..."

cd "$TERRAFORM_DIR"
terraform init -reconfigure
terraform apply -auto-approve

cd "$PROJECT_ROOT"