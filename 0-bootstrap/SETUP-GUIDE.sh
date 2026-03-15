#!/bin/bash
# =============================================================================
# Cloud Run Self-Service Blueprint — Bootstrap Setup Guide
# =============================================================================
# Run each step sequentially. This is a guide, not an automated script.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Step 1: Set your variables
# ---------------------------------------------------------------------------
export PROJECT_ID="YOUR_PROJECT_ID"       # <-- CHANGE THIS
export REGION="us-central1"
export GITHUB_ORG="your-org"        # <-- CHANGE THIS
export GITHUB_REPOS='["cloudrun-blueprint", "ad-bidding-api"]'  # <-- ADD YOUR REPOS

# ---------------------------------------------------------------------------
# Step 2: Authenticate with GCP
# ---------------------------------------------------------------------------
echo "Step 2: Authenticating..."
gcloud auth login
gcloud config set project "$PROJECT_ID"

# ---------------------------------------------------------------------------
# Step 3: Enable required APIs
# ---------------------------------------------------------------------------
echo "Step 3: Enabling APIs..."
bash 01-enable-apis.sh "$PROJECT_ID"

# ---------------------------------------------------------------------------
# Step 4: Initialize and apply bootstrap Terraform
# ---------------------------------------------------------------------------
echo "Step 4: Running Terraform bootstrap..."
terraform init
terraform plan \
  -var="project_id=$PROJECT_ID" \
  -var="region=$REGION" \
  -var="github_org=$GITHUB_ORG" \
  -var="github_repos=$GITHUB_REPOS"

echo "Review the plan above. If it looks correct, run:"
echo "  terraform apply \\"
echo "    -var=\"project_id=$PROJECT_ID\" \\"
echo "    -var=\"region=$REGION\" \\"
echo "    -var=\"github_org=$GITHUB_ORG\" \\"
echo "    -var=\"github_repos=$GITHUB_REPOS\""

# ---------------------------------------------------------------------------
# Step 5: Capture outputs for GitHub Actions
# ---------------------------------------------------------------------------
echo ""
echo "Step 5: After apply, set these as GitHub repository variables:"
echo "  GCP_PROJECT_ID   = $PROJECT_ID"
echo "  GCP_REGION       = $REGION"
echo "  WIF_PROVIDER     = \$(terraform output -raw workload_identity_provider)"
echo "  SA_EMAIL         = \$(terraform output -raw service_account_email)"

# ---------------------------------------------------------------------------
# Step 6: Verify
# ---------------------------------------------------------------------------
echo ""
echo "Step 6: Verify the setup:"
echo "  gcloud artifacts repositories list --project=$PROJECT_ID --location=$REGION"
echo "  gcloud iam service-accounts list --project=$PROJECT_ID"
echo "  gcloud iam workload-identity-pools list --project=$PROJECT_ID --location=global"
