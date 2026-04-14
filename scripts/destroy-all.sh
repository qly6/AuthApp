#!/bin/bash
# scripts/destroy-all.sh
# Usage: ./destroy-all.sh [--force] [--keep-ecr] [--keep-iam]

set -e

# Xác định thư mục gốc của dự án (cha của thư mục scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EKS_CLUSTER="${EKS_CLUSTER:-retail-vti-do2508-de000159-quyen-eksdemo}"
HELM_RELEASE="simpleauth"
NAMESPACE="simpleauth"

FORCE=false
KEEP_ECR=false
KEEP_IAM=false

for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --keep-ecr) KEEP_ECR=true ;;
        --keep-iam) KEEP_IAM=true ;;
        --help|-h)
            echo "Usage: $0 [--force] [--keep-ecr] [--keep-iam]"
            echo "  --force     Skip confirmation prompts"
            echo "  --keep-ecr  Do not delete ECR repositories"
            echo "  --keep-iam  Do not delete IAM role and OIDC provider"
            exit 0
            ;;
    esac
done

echo "⚠️  WARNING: This will delete EKS cluster and related resources."
echo "   Region: $AWS_REGION"
echo "   Cluster: $EKS_CLUSTER"
echo "   Project root: $PROJECT_ROOT"
echo ""

if [ "$FORCE" = false ]; then
    read -p "Are you sure? Type 'yes' to continue: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# 1. Uninstall Helm release
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$HELM_RELEASE"; then
    echo "🗑️  Uninstalling Helm release $HELM_RELEASE..."
    helm uninstall "$HELM_RELEASE" -n "$NAMESPACE"
fi

# 2. Delete namespace
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "🗑️  Deleting namespace $NAMESPACE..."
    kubectl delete namespace "$NAMESPACE" --wait=false
fi

# 3. Uninstall AWS Load Balancer Controller (if installed)
if helm list -n kube-system 2>/dev/null | grep -q "aws-load-balancer-controller"; then
    echo "🗑️  Uninstalling AWS Load Balancer Controller..."
    helm uninstall aws-load-balancer-controller -n kube-system
fi

# 4. Delete EKS cluster
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform/eks"
if [ -d "$TERRAFORM_DIR" ]; then
    echo "🗑️  Destroying EKS with Terraform (remote state S3)..."
    cd "$TERRAFORM_DIR"
    terraform init -reconfigure
    terraform destroy -auto-approve || echo "⚠️  Terraform destroy finished (may have warnings)."
    cd "$PROJECT_ROOT"
else
    if command -v eksctl &> /dev/null; then
        echo "🗑️  Deleting EKS cluster with eksctl..."
        eksctl delete cluster --name "$EKS_CLUSTER" --region "$AWS_REGION" --wait
    else
        echo "❌ Terraform directory not found at: $TERRAFORM_DIR"
        echo "   and eksctl not available. Please delete EKS manually."
    fi
fi

# 5. Delete ECR repositories (optional)
if [ "$KEEP_ECR" = false ]; then
    echo "🗑️  Deleting ECR repositories..."
    for repo in quyen-simpleauth-api quyen-simpleauth-ui postgresql; do
        aws ecr delete-repository --repository-name "$repo" --region "$AWS_REGION" --force 2>/dev/null || echo "   $repo not found."
    done
fi

# 6. Delete IAM role and OIDC provider (optional)
if [ "$KEEP_IAM" = false ]; then
    echo "🗑️  Deleting IAM role and OIDC provider..."
    ROLE_NAME="GitHubActionsEKSRole"
    # Detach policies
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser 2>/dev/null || true
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy 2>/dev/null || true
    aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name EKSDescribe 2>/dev/null || true
    aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true

    OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null || echo "   OIDC provider not found."
fi

echo "✅ Cleanup completed."