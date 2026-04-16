#!/bin/bash
# -----------------------------------------
# Auto-detect + build + push Docker images to ECR
# -----------------------------------------

set -e
source ./scripts/env.sh

echo "📌 Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
docker login --username AWS --password-stdin "$ECR_BASE"

# -----------------------------------------
# Sanitize names for AWS ECR compliance
# -----------------------------------------
sanitize() {
  echo "$1" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9._-]/-/g' | \
    sed 's/-\+/-/g' | \
    sed 's/^-//;s/-$//'
}

# -----------------------------------------
# Ensure ECR repository exists
# -----------------------------------------
ensure_repo() {
  local repo=$1

  aws ecr describe-repositories \
    --repository-names "$repo" \
    --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository \
    --repository-name "$repo" \
    --region "$AWS_REGION" >/dev/null
}

# -----------------------------------------
# Build & push image
# -----------------------------------------
build_and_push() {
  local repo=$1
  local context=$2

  echo "📌 Building $repo from $context"

  ensure_repo "$repo"

  docker build -t "$ECR_BASE/$repo:latest" "$context"
  docker push "$ECR_BASE/$repo:latest"
}

# -----------------------------------------
# Auto-detect backend services
# -----------------------------------------
echo "📌 Scanning backend services..."

find "$PROJECT_ROOT/backend" -maxdepth 2 -type f -name "Dockerfile" | while read -r dockerfile; do
  context_dir=$(dirname "$dockerfile")
  service_name=$(basename "$context_dir")

  safe_name=$(sanitize "$service_name")

  repo_name="quyen-simpleauth-$safe_name-api"

  build_and_push "$repo_name" "$context_dir"
done

# -----------------------------------------
# Auto-detect frontend services
# -----------------------------------------
echo "📌 Scanning frontend services..."

find "$PROJECT_ROOT/frontend" -maxdepth 2 -type f -name "Dockerfile" | while read -r dockerfile; do
  context_dir=$(dirname "$dockerfile")
  service_name=$(basename "$context_dir")

  safe_name=$(sanitize "$service_name")

  repo_name="quyen-simpleauth-$safe_name-ui"

  build_and_push "$repo_name" "$context_dir"
done

# -----------------------------------------
# Optional PostgreSQL base image
# -----------------------------------------
echo "📌 PostgreSQL image..."

ensure_repo "postgresql"

if ! aws ecr describe-images \
  --repository-name postgresql \
  --region "$AWS_REGION" \
  --image-ids imageTag=latest >/dev/null 2>&1; then

  docker pull bitnami/postgresql:latest
  docker tag bitnami/postgresql:latest "$ECR_BASE/postgresql:latest"
  docker push "$ECR_BASE/postgresql:latest"
fi

echo "✅ All images built and pushed successfully"