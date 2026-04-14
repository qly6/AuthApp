#!/bin/bash
# scripts/install-lbc-pod-identity.sh
# Usage: ./install-lbc-pod-identity.sh [CLUSTER_NAME] [REGION] [VPC_ID]

set -e

# ------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------
CLUSTER_NAME="${1:-retail-vti-do2508-de000159-quyen-eksdemo}"
AWS_REGION="${2:-ap-southeast-1}"
VPC_ID="${3:-vpc-02b36ba9d7cc9a720}"  # Nếu không truyền, script sẽ tự lấy từ cluster

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

LBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy_${CLUSTER_NAME}"
LBC_ROLE_NAME="AmazonEKS_LBC_Role_${CLUSTER_NAME}"
LBC_SA_NAME="aws-load-balancer-controller"
LBC_NAMESPACE="kube-system"

echo "=========================================="
echo "Installing AWS Load Balancer Controller"
echo "Cluster: $CLUSTER_NAME"
echo "Region : $AWS_REGION"
echo "VPC ID : $VPC_ID"
echo "Account: $ACCOUNT_ID"
echo "=========================================="

# ------------------------------------------------------------------------
# 1. Tạo IAM Policy (nếu chưa có)
# ------------------------------------------------------------------------
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${LBC_POLICY_NAME}"
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    echo "📌 Creating IAM policy: $LBC_POLICY_NAME"
    curl -so /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
    aws iam create-policy \
        --policy-name "$LBC_POLICY_NAME" \
        --policy-document file:///tmp/iam_policy.json
    rm -f /tmp/iam_policy.json
else
    echo "✅ IAM policy already exists."
fi

# ------------------------------------------------------------------------
# 2. Tạo IAM Role với trust policy cho EKS Pod Identity
# ------------------------------------------------------------------------
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LBC_ROLE_NAME}"
if ! aws iam get-role --role-name "$LBC_ROLE_NAME" >/dev/null 2>&1; then
    echo "📌 Creating IAM role: $LBC_ROLE_NAME"

    # Trust policy cho Pod Identity
    cat > /tmp/trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF

    aws iam create-role \
        --role-name "$LBC_ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json

    rm -f /tmp/trust-policy.json
else
    echo "✅ IAM role already exists."
fi

# ------------------------------------------------------------------------
# 3. Gắn policy vào role
# ------------------------------------------------------------------------
echo "📌 Attaching policy to role..."
aws iam attach-role-policy \
    --role-name "$LBC_ROLE_NAME" \
    --policy-arn "$POLICY_ARN" 2>/dev/null || echo "   Policy already attached."

# ------------------------------------------------------------------------
# 4. Tạo EKS Pod Identity Association
# ------------------------------------------------------------------------
echo "📌 Creating Pod Identity Association..."
# Kiểm tra association đã tồn tại chưa
ASSOCIATION_ID=$(aws eks list-pod-identity-associations \
    --cluster-name "$CLUSTER_NAME" \
    --namespace "$LBC_NAMESPACE" \
    --service-account "$LBC_SA_NAME" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null)

if [ "$ASSOCIATION_ID" == "None" ] || [ -z "$ASSOCIATION_ID" ]; then
    aws eks create-pod-identity-association \
        --cluster-name "$CLUSTER_NAME" \
        --namespace "$LBC_NAMESPACE" \
        --service-account "$LBC_SA_NAME" \
        --role-arn "$ROLE_ARN" \
        --region "$AWS_REGION"
    echo "✅ Association created."
else
    echo "✅ Association already exists (ID: $ASSOCIATION_ID)."
fi

# ------------------------------------------------------------------------
# 5. Lấy VPC ID nếu chưa có
# ------------------------------------------------------------------------
if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "vpc-unknown" ]; then
    VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text)
    echo "📌 VPC ID retrieved: $VPC_ID"
fi

# ------------------------------------------------------------------------
# 6. Cài đặt Helm chart
# ------------------------------------------------------------------------
echo "📌 Installing AWS Load Balancer Controller with Helm..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# Đảm bảo namespace kube-system tồn tại
kubectl create namespace "$LBC_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n "$LBC_NAMESPACE" \
    --set clusterName="$CLUSTER_NAME" \
    --set region="$AWS_REGION" \
    --set vpcId="$VPC_ID" \
    --set serviceAccount.create=true \
    --set serviceAccount.name="$LBC_SA_NAME" \
    --wait --timeout 5m

echo "=========================================="
echo "✅ AWS Load Balancer Controller installed!"
echo "=========================================="