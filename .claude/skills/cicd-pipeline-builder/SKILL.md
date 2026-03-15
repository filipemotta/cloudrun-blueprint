---
name: cicd-pipeline-builder
description: Creates GitHub Actions CI/CD pipelines for Cloud Run deployments. For PLATFORM repos, builds the reusable workflow with Docker build, Terraform generation, and deploy. For DEVELOPER repos, creates a simple 5-line workflow calling the reusable one. Use when user says "create pipeline", "github actions", "CI/CD workflow", "deploy workflow", or "setup deployment automation".
---

# CI/CD Pipeline Builder

## Important Context
There are TWO types of workflows in this architecture:

1. **Platform reusable workflow** (deploy-service.yml in cloudrun-blueprint repo)
   - Called by ALL developer repos
   - Handles: Docker build, push, TF generation, terraform apply, health check
   - Uses WIF/OIDC authentication

2. **Developer workflow** (deploy.yml in each service repo)
   - ~5 lines calling the platform reusable workflow
   - Passes service_yaml path as input
   - Developer never writes Terraform or Docker push logic

## Instructions

### For DEVELOPER REPOS (most common)

Generate `.github/workflows/deploy.yml`:
```yaml
name: Deploy
on:
  push:
    branches: [main]
permissions:
  contents: read
  id-token: write
jobs:
  deploy:
    uses: filipemotta/cloudrun-blueprint/.github/workflows/deploy-service.yml@main
    with:
      service_yaml: service.yaml
```

That's it. The developer is done. The platform handles everything else.

### For PLATFORM REPO (reusable workflow)

Generate `.github/workflows/deploy-service.yml` with:

```yaml
name: Deploy Cloud Run Service (Reusable)
on:
  workflow_call:
    inputs:
      service_yaml:
        description: "Path to service.yaml in the caller repo"
        required: false
        type: string
        default: "service.yaml"
```

**Job 1: build-and-push**
Steps:
1. `actions/checkout@v4`
2. Parse service.yaml with Python to extract project_id, region, service_name, image
3. `google-github-actions/auth@v2` with WIF (token_format: access_token)
4. Configure Docker for Artifact Registry
5. Set image tag from GITHUB_SHA
6. Docker build
7. Docker push

**Job 2: deploy** (needs: build-and-push)
Steps:
1. `actions/checkout@v4`
2. `google-github-actions/auth@v2` with WIF
3. Configure git for private module download
4. `hashicorp/setup-terraform@v3`
5. Generate Terraform files in `_deploy/` directory:
   - Copy service.yaml
   - Generate main.tf (calls cloudrun-blueprint module via git source)
   - Generate backend.tf (GCS backend with service-specific prefix)
   - Generate providers.tf
6. `terraform init` in _deploy/
7. `terraform apply -auto-approve` with image_tag variable
8. Capture service URL from terraform output
9. Health check with retries

### WIF Authentication Block
CRITICAL: `permissions.id-token: write` is REQUIRED.
```yaml
- id: auth
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: <WIF_PROVIDER>
    service_account: <SA_EMAIL>
    token_format: access_token
```

## Common Issues

### "Unable to generate OIDC token"
Cause: Missing `permissions.id-token: write` in workflow.

### "Repository not found" during terraform init
Cause: Private module repo not accessible. Fix: Add git config step with github.token.

### "credential is not authorized"
Cause: WIF SA binding missing for the caller repo. Fix: Add IAM binding for the new repo.
