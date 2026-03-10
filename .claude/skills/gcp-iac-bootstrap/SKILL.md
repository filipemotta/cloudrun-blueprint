---
name: gcp-iac-bootstrap
description: Bootstraps GCP projects for Terraform-managed infrastructure including state buckets, Artifact Registry, IAM service accounts, and Workload Identity Federation. Use when user says "bootstrap project", "setup GCP", "create state bucket", "configure WIF", or "workload identity federation".
---

# GCP IaC Bootstrap

## Instructions

### Step 1: Gather Project Information
Ask the user for:
1. GCP Project ID
2. GCP Region (default: us-central1)
3. GitHub organization/user and repository name (for WIF)
4. GitHub branch for production deploys (default: main)

### Step 2: Create API Enablement Script
Generate `0-bootstrap/01-enable-apis.sh` that enables required APIs:
```bash
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

for api in "${APIS[@]}"; do
  echo "Enabling $api..."
  gcloud services enable "$api" --project="$PROJECT_ID"
done
```

### Step 3: Create Bootstrap Terraform (0-bootstrap/main.tf)
Must include these resources in this order:

1. **GCS State Bucket**
   - Name: `${project_id}-tfstate`
   - Versioning enabled
   - Retention policy (optional but recommended)
   - Force destroy = false (safety)

2. **Artifact Registry Repository**
   - Format: DOCKER
   - Name: `cloud-run-images`
   - Region-scoped

3. **Terraform Deployer Service Account**
   - Roles (least-privilege):
     - roles/run.admin
     - roles/iam.serviceAccountUser
     - roles/secretmanager.admin
     - roles/vpcaccess.admin
     - roles/monitoring.editor
     - roles/artifactregistry.writer
     - roles/storage.admin (for state bucket only)
     - roles/iam.workloadIdentityUser

4. **Workload Identity Federation**
   - Pool: `github-pool`
   - Provider: `github-provider`
   - OIDC issuer: `https://token.actions.githubusercontent.com`
   - Attribute mapping:
     - google.subject = assertion.sub
     - attribute.actor = assertion.actor
     - attribute.repository = assertion.repository
   - Attribute condition: restrict to specific repo
   - SA binding with principalSet for repo + branch

### Step 4: Generate Outputs
The bootstrap must output everything GitHub Actions needs:
```hcl
output "workload_identity_provider" { ... }
output "service_account_email" { ... }
output "state_bucket" { ... }
output "artifact_registry_repo" { ... }
```

### Step 5: Create SETUP-GUIDE.sh
Generate a documented walkthrough script with numbered steps that a platform engineer can follow sequentially.

## Critical Rules
- NEVER create service account keys - WIF replaces them
- Attribute condition MUST restrict to the specific repository
- State bucket MUST have versioning enabled
- Bootstrap itself uses local state (no remote backend for bootstrapping)

## Troubleshooting

### WIF authentication fails in GitHub Actions
1. Verify attribute condition matches exactly: `assertion.repository == 'org/repo'`
2. Check SA has roles/iam.workloadIdentityUser
3. Verify principalSet format includes correct pool path
4. Ensure sts.googleapis.com and iamcredentials.googleapis.com APIs are enabled

### "Permission denied" on terraform apply
1. Verify deployer SA has all required roles
2. Check role bindings are at project level, not resource level
3. Ensure APIs are enabled before creating resources
