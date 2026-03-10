---
name: cicd-pipeline-builder
description: Creates GitHub Actions CI/CD pipelines for Terraform deployments using Workload Identity Federation with OIDC authentication. Use when user says "create pipeline", "github actions", "CI/CD workflow", "deploy workflow", or "setup deployment automation".
---

# CI/CD Pipeline Builder

## Instructions

### Step 1: Determine Pipeline Scope
Ask the user:
1. Is this for a single service or a reusable template?
2. Which Terraform workspace/directory does it target?
3. Should it run health checks post-deploy?

### Step 2: Create the Workflow File
Generate `.github/workflows/deploy.yml` with two jobs:

**Job 1: plan** (runs on pull_request)
```yaml
name: Deploy Cloud Run Service
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write    # REQUIRED for WIF/OIDC
  pull-requests: write

env:
  PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
  REGION: ${{ vars.GCP_REGION }}
  WIF_PROVIDER: ${{ vars.WIF_PROVIDER }}
  SA_EMAIL: ${{ vars.SA_EMAIL }}
```

Steps for plan job:
1. `actions/checkout@v4`
2. `google-github-actions/auth@v2` with WIF (workload_identity_provider + service_account)
3. Validate YAML config: `python -c "import yaml; yaml.safe_load(open('service.yaml'))"`
4. `hashicorp/setup-terraform@v3`
5. `terraform init`
6. `terraform validate`
7. `terraform plan -out=tfplan`
8. Post plan output as PR comment (optional)

**Job 2: deploy** (runs on push to main, needs: plan)
```yaml
deploy:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  needs: plan  # only if both triggered
```

Steps for deploy job:
1. Same checkout + auth as plan
2. `terraform init`
3. `terraform apply -auto-approve`
4. Capture service URL from terraform output
5. Health check: `curl -sf $SERVICE_URL/health || exit 1` (with retries)

### Step 3: WIF Authentication Block
This is the critical part - NO static keys:
```yaml
- id: auth
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ env.WIF_PROVIDER }}
    service_account: ${{ env.SA_EMAIL }}
    token_format: access_token
```

CRITICAL: The `permissions.id-token: write` is REQUIRED. Without it, OIDC token generation fails silently.

### Step 4: Configure Repository Variables
Guide the user to set these GitHub repo variables (NOT secrets):
- `GCP_PROJECT_ID`
- `GCP_REGION`
- `WIF_PROVIDER` (full path: projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL/providers/PROVIDER)
- `SA_EMAIL`

### Step 5: Add Safety Checks
- Plan job must succeed before deploy
- Deploy only on main branch push
- YAML validation before terraform commands
- Health check with retry loop after deploy
- Optional: require manual approval for production

## Pipeline Patterns

### Docker Build + Deploy
If the service needs image building:
```yaml
- name: Build and push
  run: |
    gcloud auth configure-docker ${REGION}-docker.pkg.dev
    docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/cloud-run-images/${SERVICE_NAME}:${GITHUB_SHA} .
    docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/cloud-run-images/${SERVICE_NAME}:${GITHUB_SHA}
```

### Multi-Environment
For dev/staging/prod separation:
```yaml
strategy:
  matrix:
    environment: [dev, staging, prod]
```

## Common Issues

### "Unable to generate OIDC token"
Cause: Missing `permissions.id-token: write` in workflow.
Fix: Add the permission block at job or workflow level.

### "Error: credential is not authorized"
Cause: WIF attribute condition doesn't match the repo/branch.
Fix: Verify the attribute_condition in the WIF provider matches `assertion.repository == 'org/repo'`.

### Plan succeeds but apply fails
Cause: Deployer SA missing required IAM role.
Fix: Check bootstrap outputs for complete role list.
