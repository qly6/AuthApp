#!/bin/bash
# scripts/clean-all.sh
# Usage: ./clean-all.sh [--delete-eks] [--delete-ecr]

set -e

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-296725355870}"
EKS_CLUSTER="${EKS_CLUSTER:-retail-vti-do2508-de000159-quyen-eksdemo}"
NAMESPACE="simpleauth"
RELEASE="simpleauth"

DELETE_EKS=false
DELETE_ECR=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --delete-eks) DELETE_EKS=true ;;
        --delete-ecr) DELETE_ECR=true ;;
        --help|-h)
            echo "Usage: $0 [--delete-eks] [--delete-ecr]"
            echo "  --delete-eks   Also delete EKS cluster (DANGEROUS)"
            echo "  --delete-ecr   Delete ECR repositories and images"
            exit 0
            ;;
    esac
done

echo "🧹 Starting cleanup..."

# 1. Uninstall Helm release
if helm list -n "$NAMESPACE" | grep -q "$RELEASE"; then
    echo "🗑️  Uninstalling Helm release $RELEASE..."
    helm uninstall "$RELEASE" -n "$NAMESPACE"
fi

# 2. Delete namespace (and all resources inside)
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "🗑️  Deleting namespace $NAMESPACE..."
    kubectl delete namespace "$NAMESPACE" --wait=false
fi

# 3. Delete PVCs (if any leftover)
kubectl delete pvc --all -n "$NAMESPACE" --ignore-not-found=true 2>/dev/null || true

# 4. Delete ECR repositories and images (if requested)
if [ "$DELETE_ECR" = true ]; then
    echo "⚠️  Deleting ECR repositories..."
    for repo in quyen-simpleauth-api quyen-simpleauth-ui postgresql; do
        if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
            echo "   Deleting $repo..."
            aws ecr delete-repository --repository-name "$repo" --region "$AWS_REGION" --force
        fi
    done
fi

# 5. Delete EKS cluster (if requested - DANGEROUS)
if [ "$DELETE_EKS" = true ]; then
    echo "☢️  Deleting EKS cluster $EKS_CLUSTER (this may take 10-15 minutes)..."
    eksctl delete cluster --name "$EKS_CLUSTER" --region "$AWS_REGION"
fi

echo "✅ Cleanup completed."