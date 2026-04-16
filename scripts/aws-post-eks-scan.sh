#!/bin/bash
set -e

REGION="${AWS_REGION:-ap-southeast-1}"

echo "🧹 ==================================="
echo "   REAL OIDC ORPHAN DETECTOR"
echo "==================================="

# lấy tất cả cluster hiện tại
CLUSTERS=$(aws eks list-clusters --region "$REGION" --output text)

echo ""
echo "🧠 ACTIVE CLUSTERS:"
echo "$CLUSTERS"

echo ""
echo "🧠 SCANNING OIDC PROVIDERS..."

PROVIDERS=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[].Arn" \
  --output text)

for arn in $PROVIDERS; do

  ISSUER=$(aws iam get-open-id-connect-provider \
    --open-id-connect-provider-arn "$arn" \
    --query "Url" \
    --output text)

  # extract OIDC ID
  OIDC_ID=$(echo "$ISSUER" | awk -F/ '{print $NF}')

  MATCH=0

  for c in $CLUSTERS; do
    CLUSTER_OIDC=$(aws eks describe-cluster \
      --name "$c" \
      --region "$REGION" \
      --query "cluster.identity.oidc.issuer" \
      --output text | awk -F/ '{print $NF}')

    if [ "$OIDC_ID" = "$CLUSTER_OIDC" ]; then
      MATCH=1
      break
    fi
  done

  if [ "$MATCH" -eq 0 ]; then
    echo ""
    echo "💀 ORPHAN OIDC FOUND:"
    echo "ARN   : $arn"
    echo "ISSUER: $ISSUER"
    echo "👉 SAFE TO DELETE:"
    echo "aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $arn"
  fi

done

echo ""
echo "==================================="
echo "✅ DONE - ONLY ORPHANS SHOWN"
echo "==================================="