# GitHub Actions WIF Authentication Pattern

## Two Workflow Types

### 1. Developer Repo Workflow (deploy.yml)
Developers create this simple file. No Terraform, no Docker logic.

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

### 2. Platform Reusable Workflow (deploy-service.yml)
Lives in the platform repo. Handles everything automatically.

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

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tag }}
      project_id: ${{ steps.config.outputs.project_id }}
      region: ${{ steps.config.outputs.region }}
      service_name: ${{ steps.config.outputs.service_name }}
      image: ${{ steps.config.outputs.image }}
    steps:
      - uses: actions/checkout@v4

      - name: Parse service.yaml
        id: config
        run: |
          pip install pyyaml -q
          python3 - <<'PYEOF'
          import yaml, os
          with open("${{ inputs.service_yaml }}") as f:
              c = yaml.safe_load(f)
          with open(os.environ["GITHUB_OUTPUT"], "a") as out:
              out.write(f"project_id={c['service']['project']}\n")
              out.write(f"region={c['service']['region']}\n")
              out.write(f"service_name={c['service']['name']}\n")
              out.write(f"image={c['container']['image']}\n")
          PYEOF

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: <WIF_PROVIDER>
          service_account: terraform-deployer@<PROJECT_ID>.iam.gserviceaccount.com
          token_format: access_token

      - name: Configure Docker
        run: echo '${{ steps.auth.outputs.access_token }}' | docker login -u oauth2accesstoken --password-stdin https://${{ steps.config.outputs.region }}-docker.pkg.dev

      - name: Set image tag
        id: meta
        run: echo "tag=${GITHUB_SHA::8}" >> $GITHUB_OUTPUT

      - name: Build and push
        run: |
          docker build -t ${{ steps.config.outputs.image }}:${{ steps.meta.outputs.tag }} .
          docker push ${{ steps.config.outputs.image }}:${{ steps.meta.outputs.tag }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: <WIF_PROVIDER>
          service_account: terraform-deployer@<PROJECT_ID>.iam.gserviceaccount.com

      - name: Configure git for private modules
        run: git config --global url."https://x-access-token:${{ github.token }}@github.com/".insteadOf "https://github.com/"

      - uses: hashicorp/setup-terraform@v3

      - name: Generate Terraform files
        run: |
          mkdir -p _deploy
          cp ${{ inputs.service_yaml }} _deploy/service.yaml
          # Generate main.tf, backend.tf, providers.tf dynamically
          # See deploy-service.yml in platform repo for full implementation

      - name: Terraform Init & Apply
        working-directory: _deploy
        run: |
          terraform init
          terraform apply -auto-approve -var="image_tag=${{ needs.build-and-push.outputs.image_tag }}"

      - name: Health Check
        run: |
          URL=$(cd _deploy && terraform output -raw service_url)
          for i in 1 2 3 4 5; do
            curl -sf "$URL/health" && exit 0
            sleep 10
          done
```

## Required GitHub Repository Variables
Set via Settings > Secrets and variables > Actions > Variables:
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_REGION`: e.g., us-central1
- `WIF_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider`
- `SA_EMAIL`: `deployer@PROJECT_ID.iam.gserviceaccount.com`

## WIF SA Binding for New Repos
Each new developer repo needs a WIF binding:
```bash
gcloud iam service-accounts add-iam-policy-binding terraform-deployer@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUM/locations/global/workloadIdentityPools/github-pool/attribute.repository/ORG/REPO"
```

## Security Notes
- WIF tokens are short-lived (1 hour default) - no key rotation needed
- Developers never see or handle GCP credentials
- The reusable workflow generates and discards Terraform files per run
