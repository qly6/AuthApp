#!/bin/bash
# -----------------------------------------
# Create required ECR repositories
# -----------------------------------------

set -e
source ./scripts/env.sh

echo "📌 Ensuring ECR repositories exist..."

for repo in quyen-simpleauth-api quyen-simpleauth-ui postgresql; do
  aws ecr describe-repositories \
    --repository-names "$repo" \
    --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository \
    --repository-name "$repo" \
    --region "$AWS_REGION"
done

echo "✅ ECR ready"