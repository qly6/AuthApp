#!/bin/bash
set -e
source ./scripts/env.sh

cd "$PROJECT_ROOT/infrastructure/helm/simpleauth-chart"
helm dependency update

cat > /tmp/values.yaml <<EOF
api:
  image:
    tag: latest
  database:
    password: "$DB_PASSWORD"
  jwtSecret: "$JWT_SECRET"

ui:
  image:
    tag: latest

postgresql:
  auth:
    password: "$DB_PASSWORD"

ingress:
  enabled: true
  className: alb
EOF

helm upgrade --install "$HELM_RELEASE" . \
  --namespace "$NAMESPACE" \
  --create-namespace \
  -f /tmp/values.yaml

rm -f /tmp/values.yaml