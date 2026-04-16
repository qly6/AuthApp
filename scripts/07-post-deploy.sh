#!/bin/bash
# -----------------------------------------
# Post deployment fixes
# -----------------------------------------

set -e
source ./scripts/env.sh

echo "📌 Post deployment patching..."

(
  sleep 15

  kubectl -n "$NAMESPACE" create configmap simpleauth-ui-config \
    --from-literal=env.js="window.__env={apiUrl:'/api'}" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl -n "$NAMESPACE" rollout restart deployment/simpleauth-ui || true
  kubectl -n "$NAMESPACE" rollout restart deployment/simpleauth-api || true

) &