#!/bin/bash
set -euo pipefail

PROJECT_ID="${1:?Usage: $0 PROJECT_ID}"

APIS=(
  run.googleapis.com
  iam.googleapis.com
  secretmanager.googleapis.com
  cloudresourcemanager.googleapis.com
  vpcaccess.googleapis.com
  artifactregistry.googleapis.com
  monitoring.googleapis.com
  cloudbuild.googleapis.com
  sts.googleapis.com
  iamcredentials.googleapis.com
)

echo "Enabling APIs for project: $PROJECT_ID"
for api in "${APIS[@]}"; do
  echo "  Enabling $api..."
  gcloud services enable "$api" --project="$PROJECT_ID"
done

echo "All APIs enabled successfully."
