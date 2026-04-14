#!/bin/bash
# scripts/setup-gh-oidc.sh
# Usage: GITHUB_REPO="qly6/AuthApp" EKS_CLUSTER="..." ./setup-gh-oidc.sh

set -e

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="GitHubActionsEKSRole"
EKS_CLUSTER="${EKS_CLUSTER:-retail-vti-do2508-de000159-quyen-eksdemo}"

if [ -z "$GITHUB_REPO" ]; then
    echo "❌ Please set GITHUB_REPO environment variable."
    echo "Example: GITHUB_REPO=\"qly6/AuthApp\" EKS_CLUSTER=\"...\" $0"
    exit 1
fi

echo "🔧 Account ID: $ACCOUNT_ID"
echo "🔧 GitHub Repo: $GITHUB_REPO"
echo "🔧 Role Name: $ROLE_NAME"
echo "🔧 EKS Cluster: $EKS_CLUSTER"

# 1. Tạo OIDC provider (nếu chưa có)
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
    echo "📌 Creating OIDC provider for GitHub Actions..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo "✅ OIDC provider created."
else
    echo "✅ OIDC provider already exists."
fi

# 2. Tạo trust policy
TRUST_POLICY_FILE="./trust-policy.json"
cat > "$TRUST_POLICY_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# 3. Tạo IAM role (nếu chưa tồn tại)
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "📌 Creating IAM role '$ROLE_NAME'..."
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "file://$TRUST_POLICY_FILE" \
        --no-cli-pager
    echo "✅ Role created."
else
    echo "✅ Role '$ROLE_NAME' already exists."
fi

# 4. Gắn managed policies
echo "📌 Attaching managed policies..."
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser 2>/dev/null || echo "   Policy AmazonEC2ContainerRegistryPowerUser already attached."
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy 2>/dev/null || echo "   Policy AmazonEKSClusterPolicy already attached."

# 5. Tạo inline policy cho quyền describe cluster
INLINE_POLICY_FILE="./eks-policy.json"
cat > "$INLINE_POLICY_FILE" <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name EKSDescribe \
    --policy-document "file://$INLINE_POLICY_FILE"

# Dọn dẹp file tạm
rm -f "$TRUST_POLICY_FILE" "$INLINE_POLICY_FILE"

# 6. Thêm role vào aws-auth của EKS (để có quyền truy cập Kubernetes)
echo "📌 Adding role to EKS aws-auth ConfigMap..."
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Kiểm tra xem eksctl có sẵn không
if command -v eksctl &> /dev/null; then
    echo "   Using eksctl..."
    eksctl create iamidentitymapping \
        --cluster "$EKS_CLUSTER" \
        --region "$AWS_REGION" \
        --arn "$ROLE_ARN" \
        --group system:masters \
        --username github-actions 2>/dev/null || echo "   Mapping may already exist."
else
    echo "   eksctl not found, using kubectl..."
    # Cập nhật kubeconfig
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"
    # Thêm vào aws-auth ConfigMap
    kubectl patch configmap aws-auth -n kube-system --type merge -p "
data:
  mapRoles: |
    - groups:
      - system:masters
      rolearn: $ROLE_ARN
      username: github-actions
" 2>/dev/null || echo "   Mapping may already exist or need manual merge."
fi

echo ""
echo "=========================================="
echo "✅ Setup completed successfully!"
echo "Role ARN: $ROLE_ARN"
echo "EKS cluster access: enabled"
echo "=========================================="