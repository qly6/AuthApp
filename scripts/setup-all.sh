#!/bin/bash
# scripts/setup-all.sh (phiên bản 2.0 - đã sửa lỗi triệt để)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-terraform) SKIP_TERRAFORM=true ;;
        --skip-build) SKIP_BUILD=true ;;
        --db-password=*) DB_PASSWORD="${1#*=}" ;;
        --jwt-secret=*) JWT_SECRET="${1#*=}" ;;
        --help|-h) echo "Usage: $0 [--skip-terraform] [--skip-build] ..."; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo "🚀 Starting full setup (v2.0)..."

# ... (các phần Terraform, update kubeconfig, ECR repo giữ nguyên như trước)

# ------------------------------------------------------------------------
# 5. Build and push Docker images (cải tiến: tự động push PostgreSQL image nếu cần)
# ------------------------------------------------------------------------
if [ "$SKIP_BUILD" = false ]; then
    echo "📌 Building and pushing Docker images..."

    # ... (xác định context API, UI như cũ)

    # Push PostgreSQL image lên ECR nếu chưa có
    if ! aws ecr describe-images --repository-name postgresql --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "   PostgreSQL image not found in ECR, pulling from Docker Hub and pushing..."
        docker pull bitnami/postgresql:latest
        docker tag bitnami/postgresql:latest "$ECR_BASE/postgresql:latest"
        docker push "$ECR_BASE/postgresql:latest"
    fi

    # Build và push API, UI (như cũ)
    # ...
fi

# ------------------------------------------------------------------------
# 9. Deploy Helm chart (cải tiến: thêm initContainer cho API và đảm bảo ConfigMap UI)
# ------------------------------------------------------------------------
echo "📌 Deploying Helm chart..."
HELM_CHART_DIR="$PROJECT_ROOT/infrastructure/helm/simpleauth-chart"
cd "$HELM_CHART_DIR"
helm dependency update

# Tạo file values tạm để override initContainer
cat > /tmp/override-values.yaml <<EOF
api:
  image:
    tag: latest
  database:
    password: "$DB_PASSWORD"
  jwtSecret: "$JWT_SECRET"
  # Thêm initContainer chờ PostgreSQL
  initContainers:
    - name: wait-for-postgres
      image: busybox:latest
      command: ['sh', '-c', 'until nc -z simpleauth-postgresql 5432; do echo waiting for postgres; sleep 3; done;']

ui:
  image:
    tag: latest
  apiUrl: "/api"

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
EOF

helm upgrade --install "$HELM_RELEASE" . \
    --namespace "$NAMESPACE" \
    -f /tmp/override-values.yaml \
    --wait --timeout 10m

rm -f /tmp/override-values.yaml

cd "$PROJECT_ROOT"

# Đảm bảo ConfigMap UI đúng (đề phòng trường hợp template bị sai)
kubectl -n "$NAMESPACE" create configmap simpleauth-ui-config \
  --from-literal=env.js="(function(window){ window.__env = window.__env || {}; window.__env.apiUrl = '/api'; })(this);" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Setup completed!"
kubectl -n "$NAMESPACE" get pods
kubectl -n "$NAMESPACE" get ingress