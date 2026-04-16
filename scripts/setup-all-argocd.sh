#!/bin/bash
# scripts/setup-all-argocd.sh
# Version: 3.0 - Dùng Argo CD thay cho helm install trực tiếp

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EKS_CLUSTER="${EKS_CLUSTER:-retail-vti-do2508-de000159-quyen-eksdemo}"
NAMESPACE="simpleauth"
ECR_BASE="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Thông tin Git (Argo CD sẽ đọc Helm chart từ đây)
GITHUB_REPO="${GITHUB_REPO:-qly6/AuthApp}"
GIT_BRANCH="${GIT_BRANCH:-main}"
HELM_CHART_PATH="infrastructure/helm/simpleauth-chart"

# Secrets
DB_PASSWORD="${DB_PASSWORD:-StrongDBPassword123}"
JWT_SECRET="${JWT_SECRET:-your-strong-secret-at-least-32-characters-long}"

# Cờ skip
SKIP_TERRAFORM="${SKIP_TERRAFORM:-false}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_ARGOCD="${SKIP_ARGOCD:-false}"

# ------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-terraform) SKIP_TERRAFORM=true ;;
        --skip-build) SKIP_BUILD=true ;;
        --skip-argocd) SKIP_ARGOCD=true ;;
        --db-password=*) DB_PASSWORD="${1#*=}" ;;
        --jwt-secret=*) JWT_SECRET="${1#*=}" ;;
        --help|-h)
            echo "Usage: $0 [--skip-terraform] [--skip-build] [--skip-argocd] [--db-password=PASS] [--jwt-secret=SECRET]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo "🚀 Starting full setup with Argo CD (v3.0)..."

# ------------------------------------------------------------------------
# 1. Terraform apply EKS
# ------------------------------------------------------------------------
if [ "$SKIP_TERRAFORM" = false ]; then
    TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform/eks"
    if [ -d "$TERRAFORM_DIR" ]; then
        echo "📌 Applying Terraform for EKS..."
        cd "$TERRAFORM_DIR"
        terraform init -reconfigure
        terraform apply -auto-approve
        cd "$PROJECT_ROOT"
    else
        echo "❌ Terraform directory not found at: $TERRAFORM_DIR"
        exit 1
    fi
fi

# ------------------------------------------------------------------------
# 2. Update kubeconfig
# ------------------------------------------------------------------------
echo "📌 Updating kubeconfig..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"

# ------------------------------------------------------------------------
# 3. Setup GitHub Actions OIDC (optional)
# ------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/setup-gh-oidc.sh" ]; then
    echo "📌 Setting up GitHub Actions OIDC role..."
    export GITHUB_REPO EKS_CLUSTER
    "$SCRIPT_DIR/setup-gh-oidc.sh"
fi

# ------------------------------------------------------------------------
# 4. Create ECR repositories
# ------------------------------------------------------------------------
echo "📌 Creating ECR repositories..."
for repo in quyen-simpleauth-api quyen-simpleauth-ui postgresql; do
    aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1 || \
        aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION"
done

# ------------------------------------------------------------------------
# 5. Build and push Docker images
# ------------------------------------------------------------------------
if [ "$SKIP_BUILD" = false ]; then
    echo "📌 Preparing container images..."

    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_BASE"

    # PostgreSQL
    if ! aws ecr describe-images --repository-name postgresql --region "$AWS_REGION" --image-ids imageTag=latest >/dev/null 2>&1; then
        docker pull bitnami/postgresql:latest
        docker tag bitnami/postgresql:latest "$ECR_BASE/postgresql:latest"
        docker push "$ECR_BASE/postgresql:latest"
    fi

    # API
    if [ -f "$PROJECT_ROOT/backend/SimpleAuthApi/Dockerfile" ]; then
        API_CONTEXT="$PROJECT_ROOT/backend/SimpleAuthApi"
    elif [ -f "$PROJECT_ROOT/backend/SimpleAuthApi/SimpleAuthApi/Dockerfile" ]; then
        API_CONTEXT="$PROJECT_ROOT/backend/SimpleAuthApi/SimpleAuthApi"
    else
        echo "❌ Cannot find API Dockerfile"
        exit 1
    fi
    docker build -t "$ECR_BASE/quyen-simpleauth-api:latest" "$API_CONTEXT"
    docker push "$ECR_BASE/quyen-simpleauth-api:latest"

    # UI
    if [ -f "$PROJECT_ROOT/frontend/SimpleAuthUi/Dockerfile" ]; then
        UI_CONTEXT="$PROJECT_ROOT/frontend/SimpleAuthUi"
    elif [ -f "$PROJECT_ROOT/frontend/SimpleAuthUi/SimpleAuthUi/Dockerfile" ]; then
        UI_CONTEXT="$PROJECT_ROOT/frontend/SimpleAuthUi/SimpleAuthUi"
    else
        echo "❌ Cannot find UI Dockerfile"
        exit 1
    fi
    docker build -t "$ECR_BASE/quyen-simpleauth-ui:latest" "$UI_CONTEXT"
    docker push "$ECR_BASE/quyen-simpleauth-ui:latest"

    echo "✅ All images pushed to ECR."
fi

# ------------------------------------------------------------------------
# 6. Install AWS Load Balancer Controller (Pod Identity)
# ------------------------------------------------------------------------
echo "📌 Setting up AWS Load Balancer Controller..."
# ... (giữ nguyên phần LBC từ script cũ, đã được kiểm tra)
LBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy_${EKS_CLUSTER}"
LBC_ROLE_NAME="AmazonEKS_LBC_Role_${EKS_CLUSTER}"
LBC_SA_NAME="aws-load-balancer-controller"
LBC_NAMESPACE="kube-system"

aws eks create-addon --cluster-name "$EKS_CLUSTER" --addon-name eks-pod-identity-agent 2>/dev/null || true

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${LBC_POLICY_NAME}"
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    curl -so /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
    aws iam create-policy --policy-name "$LBC_POLICY_NAME" --policy-document file:///tmp/iam_policy.json
fi

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LBC_ROLE_NAME}"
if ! aws iam get-role --role-name "$LBC_ROLE_NAME" >/dev/null 2>&1; then
    cat > /tmp/trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "pods.eks.amazonaws.com" },
        "Action": [ "sts:AssumeRole", "sts:TagSession" ]
    }]
}
EOF
    aws iam create-role --role-name "$LBC_ROLE_NAME" --assume-role-policy-document file:///tmp/trust-policy.json
fi
aws iam attach-role-policy --role-name "$LBC_ROLE_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null || true

helm uninstall aws-load-balancer-controller -n "$LBC_NAMESPACE" 2>/dev/null || true
kubectl -n "$LBC_NAMESPACE" delete sa "$LBC_SA_NAME" --ignore-not-found
kubectl -n "$LBC_NAMESPACE" create sa "$LBC_SA_NAME"
kubectl -n "$LBC_NAMESPACE" label sa "$LBC_SA_NAME" app.kubernetes.io/component=controller app.kubernetes.io/name=aws-load-balancer-controller

ASSOCIATION_ID=$(aws eks list-pod-identity-associations --cluster-name "$EKS_CLUSTER" --namespace "$LBC_NAMESPACE" --service-account "$LBC_SA_NAME" --query "associations[0].associationId" --output text 2>/dev/null)
if [ "$ASSOCIATION_ID" == "None" ] || [ -z "$ASSOCIATION_ID" ]; then
    aws eks create-pod-identity-association --cluster-name "$EKS_CLUSTER" --namespace "$LBC_NAMESPACE" --service-account "$LBC_SA_NAME" --role-arn "$ROLE_ARN" --region "$AWS_REGION"
fi

VPC_ID=$(aws eks describe-cluster --name "$EKS_CLUSTER" --query "cluster.resourcesVpcConfig.vpcId" --output text)
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n "$LBC_NAMESPACE" \
    --set clusterName="$EKS_CLUSTER" --set region="$AWS_REGION" --set vpcId="$VPC_ID" \
    --set serviceAccount.create=false --set serviceAccount.name="$LBC_SA_NAME"

echo "✅ LBC installed."

# ------------------------------------------------------------------------
# 7. Create namespace & Pod Identity for application (no ECR secret)
# ------------------------------------------------------------------------
echo "📌 Creating namespace and setting up Pod Identity for app..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Tạo IAM role cho phép pull ảnh từ ECR (Policy: AmazonEC2ContainerRegistryReadOnly)
APP_ROLE_NAME="AppECRPullRole_${EKS_CLUSTER}"
APP_POLICY_ARN="arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
if ! aws iam get-role --role-name "$APP_ROLE_NAME" >/dev/null 2>&1; then
    cat > /tmp/app-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "pods.eks.amazonaws.com" },
        "Action": [ "sts:AssumeRole", "sts:TagSession" ]
    }]
}
EOF
    aws iam create-role --role-name "$APP_ROLE_NAME" --assume-role-policy-document file:///tmp/app-trust-policy.json
    aws iam attach-role-policy --role-name "$APP_ROLE_NAME" --policy-arn "$APP_POLICY_ARN"
fi

APP_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${APP_ROLE_NAME}"
APP_SA_NAME="default"  # hoặc tạo service account riêng
# Tạo pod identity association cho service account default trong namespace simpleauth
ASSOC_ID=$(aws eks list-pod-identity-associations --cluster-name "$EKS_CLUSTER" --namespace "$NAMESPACE" --service-account "$APP_SA_NAME" --query "associations[0].associationId" --output text 2>/dev/null)
if [ "$ASSOC_ID" == "None" ] || [ -z "$ASSOC_ID" ]; then
    aws eks create-pod-identity-association --cluster-name "$EKS_CLUSTER" --namespace "$NAMESPACE" --service-account "$APP_SA_NAME" --role-arn "$APP_ROLE_ARN" --region "$AWS_REGION"
fi

echo "✅ Pod Identity configured for namespace $NAMESPACE (no docker secret needed)."

# ------------------------------------------------------------------------
# 8. Install Argo CD (if not present)
# ------------------------------------------------------------------------
if [ "$SKIP_ARGOCD" = false ]; then
    echo "📌 Installing Argo CD..."
    if ! kubectl get ns argocd >/dev/null 2>&1; then
        kubectl create namespace argocd
    fi
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    # Chờ Argo CD server ready
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=5m || true
    echo "✅ Argo CD installed."
fi

# ------------------------------------------------------------------------
# 9. Create Argo CD Application from template
# ------------------------------------------------------------------------
echo "📌 Creating Argo CD Application..."
# Tạo thư mục chứa template nếu chưa có
ARGOCD_TEMPLATE_DIR="$PROJECT_ROOT/infrastructure/argocd"
mkdir -p "$ARGOCD_TEMPLATE_DIR"

# File template YAML (sẽ được thay thế biến)
cat > "$ARGOCD_TEMPLATE_DIR/simpleauth-application.yaml.tmpl" <<'TMPL'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: simpleauth
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/__GITHUB_REPO__
    targetRevision: __GIT_BRANCH__
    path: __HELM_CHART_PATH__
    helm:
      values: |
        api:
          image:
            repository: __ECR_BASE__/quyen-simpleauth-api
            tag: latest
          database:
            host: simpleauth-postgresql
            port: 5432
            user: postgres
            password: __DB_PASSWORD__
            name: simpleauth
          jwtSecret: __JWT_SECRET__
          imagePullSecrets: []
        ui:
          image:
            repository: __ECR_BASE__/quyen-simpleauth-ui
            tag: latest
          apiUrl: /api
          imagePullSecrets: []
        postgresql:
          enabled: true
          auth:
            password: __DB_PASSWORD__
          primary:
            persistence:
              enabled: false   # change to true for production
          image:
            registry: __ECR_BASE__
            repository: postgresql
            tag: latest
          imagePullSecrets: []
        ingress:
          enabled: true
          className: alb
          annotations:
            alb.ingress.kubernetes.io/scheme: internet-facing
            alb.ingress.kubernetes.io/target-type: ip
            alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
            alb.ingress.kubernetes.io/healthcheck-path: /index.html
          hosts:
            - host: ""
              paths:
                - path: /
                  pathType: Prefix
                  serviceName: simpleauth-ui
                  servicePort: 80
                - path: /api
                  pathType: Prefix
                  serviceName: simpleauth-api
                  servicePort: 80
  destination:
    server: https://kubernetes.default.svc
    namespace: __NAMESPACE__
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
TMPL

# Thay thế biến
APPLICATION_YAML="$ARGOCD_TEMPLATE_DIR/simpleauth-application.yaml"
cp "$ARGOCD_TEMPLATE_DIR/simpleauth-application.yaml.tmpl" "$APPLICATION_YAML"

sed -i "s|__GITHUB_REPO__|${GITHUB_REPO}|g" "$APPLICATION_YAML"
sed -i "s|__GIT_BRANCH__|${GIT_BRANCH}|g" "$APPLICATION_YAML"
sed -i "s|__HELM_CHART_PATH__|${HELM_CHART_PATH}|g" "$APPLICATION_YAML"
sed -i "s|__ECR_BASE__|${ECR_BASE}|g" "$APPLICATION_YAML"
sed -i "s|__DB_PASSWORD__|${DB_PASSWORD}|g" "$APPLICATION_YAML"
sed -i "s|__JWT_SECRET__|${JWT_SECRET}|g" "$APPLICATION_YAML"
sed -i "s|__NAMESPACE__|${NAMESPACE}|g" "$APPLICATION_YAML"

kubectl apply -f "$APPLICATION_YAML"

echo "✅ Argo CD Application created. It will sync automatically."

# ------------------------------------------------------------------------
# 10. (Optional) Wait for Argo CD sync (no wait by default)
# ------------------------------------------------------------------------
echo "📌 Setup complete. Monitor with:"
echo "   kubectl -n argocd get app simpleauth -w"
echo "   kubectl -n $NAMESPACE get pods -w"
echo "🌐 Ingress will be ready after ALB provisioning."