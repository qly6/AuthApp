#!/bin/bash
# -----------------------------------------
# Configure kubectl for EKS
# -----------------------------------------

set -e
source ./scripts/env.sh

echo "📌 Updating kubeconfig for cluster: $EKS_CLUSTER"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER"