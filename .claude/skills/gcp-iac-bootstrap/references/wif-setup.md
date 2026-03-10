# Workload Identity Federation Setup Reference

## Architecture

```
GitHub Actions Runner
    |
    | (OIDC token with claims: repo, actor, ref, etc.)
    v
Google Security Token Service (STS)
    |
    | (Exchange OIDC token for federated token)
    v
Workload Identity Pool + Provider
    |
    | (Attribute mapping + conditions)
    v
Service Account Impersonation
    |
    | (Short-lived access token)
    v
GCP APIs (Cloud Run, IAM, etc.)
```

## Required Resources

### 1. Workload Identity Pool
```hcl
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Pool for GitHub Actions OIDC authentication"
}
```

### 2. Workload Identity Provider
```hcl
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
```

### 3. Service Account IAM Binding
```hcl
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}
```

## GitHub Actions Usage
```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/PROJECT_NUM/locations/global/workloadIdentityPools/github-pool/providers/github-provider
    service_account: deployer@PROJECT_ID.iam.gserviceaccount.com
```

## Common Pitfalls
1. Using project ID instead of project NUMBER in the provider path
2. Missing `sts.googleapis.com` API enablement
3. Attribute condition using wrong claim name
4. Missing `permissions: id-token: write` in GitHub Actions workflow
5. Binding to principal (single identity) instead of principalSet (group)
