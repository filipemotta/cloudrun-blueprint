# GitHub Actions WIF Authentication Pattern

## Workflow Template

```yaml
name: Deploy Cloud Run Service

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write      # CRITICAL: Required for OIDC token
  pull-requests: write  # For PR comments

env:
  PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
  REGION: ${{ vars.GCP_REGION }}
  WIF_PROVIDER: ${{ vars.WIF_PROVIDER }}
  SA_EMAIL: ${{ vars.SA_EMAIL }}
  SERVICE_DIR: .        # Directory containing Terraform files

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
        run: python3 -c "import yaml; yaml.safe_load(open('${{ env.SERVICE_DIR }}/service.yaml'))"

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5.0"

      - name: Terraform Init
        working-directory: ${{ env.SERVICE_DIR }}
        run: terraform init

      - name: Terraform Validate
        working-directory: ${{ env.SERVICE_DIR }}
        run: terraform validate

      - name: Terraform Plan
        working-directory: ${{ env.SERVICE_DIR }}
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

      - name: Terraform Init
        working-directory: ${{ env.SERVICE_DIR }}
        run: terraform init

      - name: Terraform Apply
        working-directory: ${{ env.SERVICE_DIR }}
        run: terraform apply -auto-approve

      - name: Get Service URL
        id: url
        working-directory: ${{ env.SERVICE_DIR }}
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
```

## Required GitHub Repository Variables
Set via Settings > Secrets and variables > Actions > Variables:
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_REGION`: e.g., us-central1
- `WIF_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider`
- `SA_EMAIL`: `deployer@PROJECT_ID.iam.gserviceaccount.com`

## Security Notes
- Use vars (not secrets) for non-sensitive config - they're visible in logs which helps debugging
- WIF tokens are short-lived (1 hour default) - no key rotation needed
- Attribute conditions in WIF restrict which repos/branches can authenticate
