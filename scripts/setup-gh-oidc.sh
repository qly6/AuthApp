#!/bin/bash
# scripts/setup-gh-oidc.sh
# Sử dụng: GITHUB_REPO="qly6/AuthApp" ./setup-gh-oidc.sh

set -e

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="GitHubActionsEKSRole"

if [ -z "$GITHUB_REPO" ]; then
    echo "❌ Vui lòng đặt biến môi trường GITHUB_REPO."
    echo "Ví dụ: GITHUB_REPO=\"qly6/AuthApp\" $0"
    exit 1
fi

echo "🔧 Account ID: $ACCOUNT_ID"
echo "🔧 GitHub Repo: $GITHUB_REPO"
echo "🔧 Role Name: $ROLE_NAME"

# 1. Tạo OIDC provider (nếu chưa có)
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
    echo "📌 Đang tạo OIDC provider cho GitHub Actions..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo "✅ Đã tạo OIDC provider."
else
    echo "✅ OIDC provider đã tồn tại."
fi

# 2. Tạo file trust policy (lưu ở thư mục hiện tại)
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
    echo "📌 Đang tạo IAM role '$ROLE_NAME'..."
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "file://$TRUST_POLICY_FILE" \
        --no-cli-pager
    echo "✅ Đã tạo role."
else
    echo "✅ Role '$ROLE_NAME' đã tồn tại."
fi

# 4. Gắn managed policies (bỏ qua lỗi nếu đã gắn)
echo "📌 Đang gắn managed policies..."
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser 2>/dev/null || echo "   Policy AmazonEC2ContainerRegistryPowerUser đã được gắn."
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy 2>/dev/null || echo "   Policy AmazonEKSClusterPolicy đã được gắn."

# 5. Tạo inline policy (quyền describe cluster)
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

echo ""
echo "=========================================="
echo "✅ Hoàn tất cài đặt!"
echo "Role ARN: arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "=========================================="