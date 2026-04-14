#!/bin/bash
# scripts/ecr-login.sh
# Usage: ./ecr-login.sh [aws_profile]

set -e

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-296725355870}"
PROFILE="${1:-default}"

echo "🔐 Logging into Amazon ECR in region $AWS_REGION..."

if [ "$PROFILE" != "default" ]; then
    aws ecr get-login-password --region "$AWS_REGION" --profile "$PROFILE" | \
        docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
else
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
fi

echo "✅ ECR login successful."