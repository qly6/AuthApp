#!/bin/bash
# scripts/build-push.sh
# Usage: ./build-push.sh [api|ui|all] [tag]

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-296725355870}"
ECR_BASE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

API_REPO="quyen-simpleauth-api"
UI_REPO="quyen-simpleauth-ui"

API_CONTEXT="./backend/SimpleAuthApi"
UI_CONTEXT="./frontend/SimpleAuthUi"

# Determine tag
TAG="${2:-latest}"
if [ "$TAG" = "git" ]; then
    TAG=$(git rev-parse --short HEAD)
fi

# Determine target
TARGET="${1:-all}"

echo "🏗️  Building and pushing images with tag: $TAG"

# Login to ECR first
./scripts/ecr-login.sh

build_and_push() {
    local context=$1
    local repo=$2
    local image_tag=$3
    local name=$4

    echo "📦 Building $name image..."
    docker build -t "$ECR_BASE/$repo:$image_tag" "$context"

    echo "⬆️  Pushing $name image to ECR..."
    docker push "$ECR_BASE/$repo:$image_tag"

    # Also tag as latest if not already
    if [ "$image_tag" != "latest" ]; then
        docker tag "$ECR_BASE/$repo:$image_tag" "$ECR_BASE/$repo:latest"
        docker push "$ECR_BASE/$repo:latest"
    fi
    echo "✅ $name image pushed successfully."
}

case "$TARGET" in
    api)
        build_and_push "$API_CONTEXT" "$API_REPO" "$TAG" "API"
        ;;
    ui)
        build_and_push "$UI_CONTEXT" "$UI_REPO" "$TAG" "UI"
        ;;
    all)
        build_and_push "$API_CONTEXT" "$API_REPO" "$TAG" "API"
        build_and_push "$UI_CONTEXT" "$UI_REPO" "$TAG" "UI"
        ;;
    *)
        echo "❌ Unknown target: $TARGET. Use 'api', 'ui', or 'all'."
        exit 1
        ;;
esac

echo "🎉 All builds completed."