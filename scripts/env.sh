#!/bin/bash
set -e

# -----------------------------------------
# Load env file inside scripts folder
# -----------------------------------------
ENV_FILE="$(dirname "$0")/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# -----------------------------------------
# Defaults
# -----------------------------------------
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
EKS_CLUSTER="${EKS_CLUSTER:-your-cluster}"

HELM_RELEASE="${HELM_RELEASE:-simpleauth}"
NAMESPACE="${NAMESPACE:-simpleauth}"

# -----------------------------------------
# Required secrets validation
# -----------------------------------------
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${JWT_SECRET:?JWT_SECRET is required}"

# -----------------------------------------
# Derived values
# -----------------------------------------
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# -----------------------------------------
# Paths
# -----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"