#!/bin/bash
# scripts/deploy-helm.sh
# Usage: ./deploy-helm.sh [--namespace <ns>] [--release <name>] [--set key=value]...

set -e

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
EKS_CLUSTER="${EKS_CLUSTER:-retail-vti-do2508-de000159-quyen-eksdemo}"
NAMESPACE="simpleauth"
RELEASE="simpleauth"
HELM_CHART_DIR="./infrastructure/helm/simpleauth-chart"
EXTRA_SET_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --release)
            RELEASE="$2"
            shift 2
            ;;
        --set)
            EXTRA_SET_ARGS+=("--set" "$2")
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--namespace <ns>] [--release <name>] [--set key=value]..."
            echo "Environment variables:"
            echo "  DB_PASSWORD   - PostgreSQL password"
            echo "  JWT_SECRET    - JWT secret for API"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get secrets from environment or prompt
DB_PASSWORD="${DB_PASSWORD:-}"
JWT_SECRET="${JWT_SECRET:-}"

if [ -z "$DB_PASSWORD" ]; then
    read -sp "Enter PostgreSQL password: " DB_PASSWORD
    echo
fi
if [ -z "$JWT_SECRET" ]; then
    read -sp "Enter JWT secret (min 32 chars): " JWT_SECRET
    echo
fi

echo "🚀 Deploying Helm release '$RELEASE' to namespace '$NAMESPACE' on cluster '$EKS_CLUSTER'"

# Update kubeconfig
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"

# Create namespace if not exists
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# Create ECR secret if not exists
if ! kubectl -n "$NAMESPACE" get secret ecr-secret >/dev/null 2>&1; then
    echo "🔐 Creating ECR pull secret..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    kubectl -n "$NAMESPACE" create secret docker-registry ecr-secret \
        --docker-server="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region "$AWS_REGION")
fi

# Deploy
cd "$HELM_CHART_DIR"
helm dependency update

helm upgrade --install "$RELEASE" . \
    --namespace "$NAMESPACE" \
    --set postgresql.auth.password="$DB_PASSWORD" \
    --set api.database.password="$DB_PASSWORD" \
    --set api.jwtSecret="$JWT_SECRET" \
    "${EXTRA_SET_ARGS[@]}" \
    --wait --timeout 5m

echo "✅ Deployment completed."
echo "📡 Getting Ingress status (may take a minute for ALB)..."
kubectl -n "$NAMESPACE" get ingress -w