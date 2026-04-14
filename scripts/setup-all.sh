#!/bin/bash
# scripts/setup-all.sh
# Version: 2.2 - No wait/timeout

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EKS_CLUSTER="${EKS_CLUSTER:-retail-vti-do2508-de000159-quyen-eksdemo}"
HELM_RELEASE="simpleauth"
NAMESPACE="simpleauth"
ECR_BASE="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

SKIP_TERRAFORM=false
SKIP_BUILD=false
DB_PASSWORD="StrongDBPassword123"
JWT_SECRET="your-strong-secret-at-least-32-characters-long"

# ------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-terraform) SKIP_TERRAFORM=true ;;
        --skip-build) SKIP_BUILD=true ;;
        --db-password=*) DB_PASSWORD="${1#*=}" ;;
        --jwt-secret=*) JWT_SECRET="${1#*=}" ;;
        --help|-h)
            echo "Usage: $0 [--skip-terraform] [--skip-build] [--db-password=PASS] [--jwt-secret=SECRET]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo "🚀 Starting full setup (v2.2 no-wait)..."

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
    export GITHUB_REPO="${GITHUB_REPO:-qly6/AuthApp}"
    export EKS_CLUSTER
    "$SCRIPT_DIR/setup-gh-oidc.sh"
fi

# ------------------------------------------------------------------------
# 4. Create ECR repositories (including postgresql)
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

    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_BASE"

    # ----- PostgreSQL image -----
    echo "   Checking PostgreSQL image in ECR..."
    if ! aws ecr describe-images --repository-name postgresql --region "$AWS_REGION" --image-ids imageTag=latest >/dev/null 2>&1; then
        echo "   PostgreSQL image not found. Pulling from Docker Hub and pushing to ECR..."
        docker pull bitnami/postgresql:latest
        docker tag bitnami/postgresql:latest "$ECR_BASE/postgresql:latest"
        docker push "$ECR_BASE/postgresql:latest"
        echo "   ✅ PostgreSQL image pushed."
    else
        echo "   ✅ PostgreSQL image already exists in ECR."
    fi

    # ----- API image -----
    if [ -f "$PROJECT_ROOT/backend/SimpleAuthApi/Dockerfile" ]; then
        API_CONTEXT="$PROJECT_ROOT/backend/SimpleAuthApi"
    elif [ -f "$PROJECT_ROOT/backend/SimpleAuthApi/SimpleAuthApi/Dockerfile" ]; then
        API_CONTEXT="$PROJECT_ROOT/backend/SimpleAuthApi/SimpleAuthApi"
    else
        echo "❌ Cannot find API Dockerfile"
        exit 1
    fi
    echo "   Building API image from $API_CONTEXT..."
    docker build -t "$ECR_BASE/quyen-simpleauth-api:latest" "$API_CONTEXT"
    docker push "$ECR_BASE/quyen-simpleauth-api:latest"

    # ----- UI image -----
    if [ -f "$PROJECT_ROOT/frontend/SimpleAuthUi/Dockerfile" ]; then
        UI_CONTEXT="$PROJECT_ROOT/frontend/SimpleAuthUi"
    elif [ -f "$PROJECT_ROOT/frontend/SimpleAuthUi/SimpleAuthUi/Dockerfile" ]; then
        UI_CONTEXT="$PROJECT_ROOT/frontend/SimpleAuthUi/SimpleAuthUi"
    else
        echo "❌ Cannot find UI Dockerfile"
        exit 1
    fi
    echo "   Building UI image from $UI_CONTEXT..."
    docker build -t "$ECR_BASE/quyen-simpleauth-ui:latest" "$UI_CONTEXT"
    docker push "$ECR_BASE/quyen-simpleauth-ui:latest"

    echo "✅ All images pushed to ECR."
fi

# ------------------------------------------------------------------------
# 6. Install AWS Load Balancer Controller (Pod Identity)
# ------------------------------------------------------------------------
echo "📌 Setting up AWS Load Balancer Controller..."

LBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy_${EKS_CLUSTER}"
LBC_ROLE_NAME="AmazonEKS_LBC_Role_${EKS_CLUSTER}"
LBC_SA_NAME="aws-load-balancer-controller"
LBC_NAMESPACE="kube-system"

aws eks create-addon --cluster-name "$EKS_CLUSTER" --addon-name eks-pod-identity-agent 2>/dev/null || echo "   Add-on exists."

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${LBC_POLICY_NAME}"
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    curl -so /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
    aws iam create-policy --policy-name "$LBC_POLICY_NAME" --policy-document file:///tmp/iam_policy.json
    rm -f /tmp/iam_policy.json
fi

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LBC_ROLE_NAME}"
if ! aws iam get-role --role-name "$LBC_ROLE_NAME" >/dev/null 2>&1; then
    cat > /tmp/trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": { "Service": "pods.eks.amazonaws.com" },
            "Action": [ "sts:AssumeRole", "sts:TagSession" ]
        }
    ]
}
EOF
    aws iam create-role --role-name "$LBC_ROLE_NAME" --assume-role-policy-document file:///tmp/trust-policy.json
    rm -f /tmp/trust-policy.json
fi
aws iam attach-role-policy --role-name "$LBC_ROLE_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null || echo "   Policy attached."

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

echo "✅ LBC installed (no wait)."

# ------------------------------------------------------------------------
# 7. Create namespace and ECR secret
# ------------------------------------------------------------------------
echo "📌 Creating namespace and ECR secret..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" delete secret ecr-secret --ignore-not-found
kubectl -n "$NAMESPACE" create secret docker-registry ecr-secret \
    --docker-server="$ECR_BASE" --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region "$AWS_REGION")

# ------------------------------------------------------------------------
# 8. Deploy Helm chart (no wait/timeout)
# ------------------------------------------------------------------------
echo "📌 Deploying Helm chart..."
HELM_CHART_DIR="$PROJECT_ROOT/infrastructure/helm/simpleauth-chart"
cd "$HELM_CHART_DIR"
helm dependency update

cat > /tmp/override-values.yaml <<EOF
api:
  image:
    tag: latest
  database:
    password: "$DB_PASSWORD"
  jwtSecret: "$JWT_SECRET"
  imagePullSecrets:
    - name: ecr-secret

ui:
  image:
    tag: latest
  apiUrl: "/api"
  imagePullSecrets:
    - name: ecr-secret

postgresql:
  auth:
    password: "$DB_PASSWORD"
  primary:
    persistence:
      enabled: false
  image:
    registry: $ECR_BASE
    repository: postgresql
    tag: latest
  imagePullSecrets:
    - name: ecr-secret

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
EOF

helm upgrade --install "$HELM_RELEASE" . --namespace "$NAMESPACE" -f /tmp/override-values.yaml
rm -f /tmp/override-values.yaml

cd "$PROJECT_ROOT"

# ------------------------------------------------------------------------
# 9. Post-deployment fixes (run in background, no wait)
# ------------------------------------------------------------------------
echo "📌 Applying post-deployment fixes..."
(
  sleep 10
  kubectl -n "$NAMESPACE" create configmap simpleauth-ui-config \
    --from-literal=env.js="(function(window){ window.__env = window.__env || {}; window.__env.apiUrl = '/api'; })(this);" \
    --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null

  kubectl -n "$NAMESPACE" patch deployment simpleauth-ui -p '{"spec":{"template":{"spec":{"containers":[{"name":"ui","command":["nginx","-g","daemon off;"]}]}}}}' 2>/dev/null || true

  kubectl -n "$NAMESPACE" rollout restart deployment/simpleauth-ui 2>/dev/null
  kubectl -n "$NAMESPACE" rollout restart deployment/simpleauth-api 2>/dev/null
) &

echo "✅ Setup script completed (resources are deploying in background)."
echo "🌐 Monitor with: kubectl -n $NAMESPACE get pods -w"
echo "🌐 Ingress will be available at: (check with: kubectl -n $NAMESPACE get ingress)"