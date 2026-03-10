#!/bin/bash
set -euo pipefail

# =============================================================================
# init-service.sh — Scaffold a new Cloud Run service directory
# Usage: ./scripts/init-service.sh <service-name> <team> <cost-center> <environment>
# =============================================================================

SERVICE_NAME="${1:?Usage: $0 SERVICE_NAME TEAM COST_CENTER ENVIRONMENT}"
TEAM="${2:?Missing TEAM}"
COST_CENTER="${3:?Missing COST_CENTER}"
ENVIRONMENT="${4:?Missing ENVIRONMENT}"

PROJECT_ID="${PROJECT_ID:-freestar}"
REGION="${REGION:-us-central1}"

SERVICE_DIR="examples/${SERVICE_NAME}"

if [ -d "$SERVICE_DIR" ]; then
  echo "ERROR: Directory $SERVICE_DIR already exists." >&2
  exit 1
fi

echo "Scaffolding service: $SERVICE_NAME"
mkdir -p "${SERVICE_DIR}/.github/workflows"

# --- service.yaml ---
cat > "${SERVICE_DIR}/service.yaml" <<EOF
service:
  name: ${SERVICE_NAME}
  project: ${PROJECT_ID}
  region: ${REGION}

container:
  image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/cloud-run-images/${SERVICE_NAME}
  port: 8080
  resources:
    cpu: "1000m"
    memory: "512Mi"

scaling:
  min_instances: 0
  max_instances: 5
  concurrency: 80

env_vars:
  LOG_LEVEL: "info"

networking:
  ingress: "internal-and-cloud-load-balancing"
  vpc_connector: false
  cloud_armor: false

labels:
  team: ${TEAM}
  cost_center: ${COST_CENTER}
  environment: ${ENVIRONMENT}
EOF

# --- main.tf ---
cat > "${SERVICE_DIR}/main.tf" <<'EOF'
module "service" {
  source      = "../../modules/cloudrun-blueprint"
  config_file = "${path.module}/service.yaml"
  image_tag   = var.image_tag
}

variable "image_tag" {
  type        = string
  description = "Container image tag to deploy"
  default     = "latest"
}

output "service_url" {
  value = module.service.service_url
}

output "service_account_email" {
  value = module.service.service_account_email
}

output "revision" {
  value = module.service.revision
}
EOF

# --- backend.tf ---
cat > "${SERVICE_DIR}/backend.tf" <<EOF
# Uncomment after bootstrap creates the state bucket
# terraform {
#   backend "gcs" {
#     bucket = "${PROJECT_ID}-tfstate"
#     prefix = "services/${SERVICE_NAME}"
#   }
# }
EOF

# --- providers.tf ---
cat > "${SERVICE_DIR}/providers.tf" <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = "${PROJECT_ID}"
  region  = "${REGION}"
}
EOF

# --- deploy.yml ---
cat > "${SERVICE_DIR}/.github/workflows/deploy.yml" <<'EOF'
name: Deploy Cloud Run Service

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write
  pull-requests: write

env:
  PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
  REGION: ${{ vars.GCP_REGION }}
  WIF_PROVIDER: ${{ vars.WIF_PROVIDER }}
  SA_EMAIL: ${{ vars.SA_EMAIL }}

jobs:
  plan:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ env.WIF_PROVIDER }}
          service_account: ${{ env.SA_EMAIL }}

      - name: Validate YAML config
        run: python3 -c "import yaml; yaml.safe_load(open('service.yaml'))"

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5.0"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan -no-color

  deploy:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ env.WIF_PROVIDER }}
          service_account: ${{ env.SA_EMAIL }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5.0"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply -auto-approve

      - name: Get Service URL
        id: url
        run: echo "url=$(terraform output -raw service_url)" >> $GITHUB_OUTPUT

      - name: Health Check
        run: |
          for i in 1 2 3 4 5; do
            if curl -sf "${{ steps.url.outputs.url }}/health"; then
              echo "Health check passed"
              exit 0
            fi
            echo "Attempt $i failed, retrying in 10s..."
            sleep 10
          done
          echo "Health check failed after 5 attempts"
          exit 1
EOF

echo ""
echo "Service scaffolded at: $SERVICE_DIR"
echo "Files created:"
find "$SERVICE_DIR" -type f | sort | sed "s|^|  |"
echo ""
echo "Next steps:"
echo "  1. Update container image in service.yaml"
echo "  2. Add environment variables and secrets as needed"
echo "  3. Uncomment backend.tf after state bucket exists"
echo "  4. Set GitHub repo variables: GCP_PROJECT_ID, GCP_REGION, WIF_PROVIDER, SA_EMAIL"
