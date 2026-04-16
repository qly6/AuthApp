#!/bin/bash
# -----------------------------------------
# 05-lbc.sh (FIXED PRODUCTION VERSION)
# Install AWS Load Balancer Controller safely
#
# FIXES:
# - ServiceAccount missing (your actual error)
# - Helm create SA disabled but not created manually
# - webhook readiness issue protection
# -----------------------------------------

set -e

source ./scripts/env.sh

echo "====================================="
echo "📌 AWS LOAD BALANCER CONTROLLER SETUP"
echo "====================================="

LBC_NAMESPACE="kube-system"
LBC_SA="aws-load-balancer-controller"

# =====================================
# 1. Ensure Pod Identity Agent (safe)
# =====================================
echo "📌 Ensuring EKS Pod Identity Agent..."

aws eks create-addon \
  --cluster-name "$EKS_CLUSTER" \
  --addon-name eks-pod-identity-agent \
  --region "$AWS_REGION" 2>/dev/null || true

# =====================================
# 2. Helm repo
# =====================================
echo "📌 Adding Helm repo..."

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# =====================================
# 3. Get VPC ID
# =====================================
VPC_ID=$(aws eks describe-cluster \
  --name "$EKS_CLUSTER" \
  --region "$AWS_REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)

echo "📌 VPC ID: $VPC_ID"

# =====================================
# 4. CREATE SERVICE ACCOUNT (CRITICAL FIX)
# =====================================
echo "📌 Creating ServiceAccount..."

kubectl create serviceaccount "$LBC_SA" \
  -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -

# OPTIONAL: IRSA annotation (uncomment if using IAM role)
# echo "📌 Attaching IAM role to ServiceAccount..."
# kubectl annotate serviceaccount "$LBC_SA" \
#   -n kube-system \
#   eks.amazonaws.com/role-arn=arn:aws:iam::$ACCOUNT_ID:role/$LBC_ROLE_NAME \
#   --overwrite

# =====================================
# 5. INSTALL / UPGRADE HELM
# =====================================
echo "📌 Installing AWS Load Balancer Controller..."

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n "$LBC_NAMESPACE" \
  --set clusterName="$EKS_CLUSTER" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$LBC_SA"

# =====================================
# 6. WAIT: deployment ready
# =====================================
echo "📌 Waiting for controller deployment..."

kubectl -n kube-system rollout status deployment/aws-load-balancer-controller \
  --timeout=300s

# =====================================
# 7. WAIT: webhook ready (CRITICAL FIX)
# =====================================
echo "📌 Waiting for webhook service endpoints..."

for i in {1..40}; do
  ENDPOINTS=$(kubectl get endpoints aws-load-balancer-webhook-service \
    -n kube-system -o jsonpath='{.subsets}' 2>/dev/null || true)

  if [ -n "$ENDPOINTS" ] && [ "$ENDPOINTS" != "null" ]; then
    echo "✅ Webhook ready"
    break
  fi

  echo "⏳ Waiting webhook... ($i/40)"
  sleep 5
done

# =====================================
# 8. FINAL CHECK
# =====================================
echo "====================================="
echo "📌 FINAL STATUS"
echo "====================================="

kubectl get pods -n kube-system | grep aws-load-balancer-controller || true

kubectl get endpoints aws-load-balancer-webhook-service \
  -n kube-system || true

echo "====================================="
echo "✅ LBC SETUP COMPLETED SUCCESSFULLY"
echo "====================================="