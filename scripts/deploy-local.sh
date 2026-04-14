#!/bin/bash
# scripts/deploy-local.sh
# Usage: ./deploy-local.sh [namespace] [release_name]

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
EKS_CLUSTER="${EKS_CLUSTER:-retail-vti-do2508-de000159-quyen-eksdemo}"
NAMESPACE="${1:-simpleauth}"
RELEASE="${2:-simpleauth}"
HELM_CHART_DIR="./infrastructure/helm/simpleauth-chart"

# Optional secrets (should be set in environment or entered manually)
DB_PASSWORD="${DB_PASSWORD:-}"
JWT_SECRET="${JWT_SECRET:-}"

echo "🚀 Deploying $RELEASE to EKS cluster $EKS_CLUSTER in namespace $NAMESPACE"

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"

# Ensure namespace exists
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# Create ECR pull secret if not exists
if ! kubectl -n "$NAMESPACE" get secret ecr-secret >/dev/null 2>&1; then
    echo "🔐 Creating ECR pull secret..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    kubectl -n "$NAMESPACE" create secret docker-registry ecr-secret \
        --docker-server="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region "$AWS_REGION")
fi

# Prompt for secrets if not set
if [ -z "$DB_PASSWORD" ]; then
    read -sp "Enter PostgreSQL password: " DB_PASSWORD
    echo
fi
if [ -z "$JWT_SECRET" ]; then
    read -sp "Enter JWT secret (min 32 chars): " JWT_SECRET
    echo
fi

# Deploy with Helm
cd "$HELM_CHART_DIR"
helm dependency update

helm upgrade --install "$RELEASE" . \
    --namespace "$NAMESPACE" \
    --set postgresql.auth.password="$DB_PASSWORD" \
    --set api.database.password="$DB_PASSWORD" \
    --set api.jwtSecret="$JWT_SECRET" \
    --wait --timeout 5m

echo "✅ Deployment completed. Getting Ingress URL..."
kubectl -n "$NAMESPACE" get ingress --watch