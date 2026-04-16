#!/bin/bash
set -e

# -----------------------------------------
# Resolve project root (VERY IMPORTANT)
# -----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Starting full infrastructure setup..."
echo "📁 Project root: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# -----------------------------------------
# Run scripts with absolute path
# -----------------------------------------
# ./scripts/01-terraform.sh
# ./scripts/02-kubeconfig.sh
# ./scripts/03-ecr.sh
# ./scripts/04-build-push.sh
./scripts/05-lbc.sh
./scripts/06-helm-deploy.sh
./scripts/07-post-deploy.sh

echo "✅ Setup completed successfully"