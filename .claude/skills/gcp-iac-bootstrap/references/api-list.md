# Required GCP APIs

| API | Service | Why Required |
|-----|---------|--------------|
| run.googleapis.com | Cloud Run | Core compute platform |
| iam.googleapis.com | IAM | Service accounts and role bindings |
| secretmanager.googleapis.com | Secret Manager | Application secrets |
| cloudresourcemanager.googleapis.com | Resource Manager | Project-level operations |
| vpcaccess.googleapis.com | VPC Access | Serverless VPC connectors |
| artifactregistry.googleapis.com | Artifact Registry | Container image storage |
| monitoring.googleapis.com | Cloud Monitoring | Alert policies and metrics |
| cloudbuild.googleapis.com | Cloud Build | Container builds (optional) |
| sts.googleapis.com | Security Token Service | WIF token exchange |
| iamcredentials.googleapis.com | IAM Credentials | WIF SA impersonation |

## Enablement Order
APIs should be enabled BEFORE any Terraform resources are created.
The bootstrap script (01-enable-apis.sh) must run first.

## Verification
```bash
gcloud services list --enabled --project=PROJECT_ID --filter="name:(run OR iam OR secretmanager OR cloudresourcemanager OR vpcaccess OR artifactregistry OR monitoring OR cloudbuild OR sts OR iamcredentials)"
```
