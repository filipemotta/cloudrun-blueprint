# Cloud Run Self-Service Blueprint - Platform Engineering Project

## Project Goal
Build a Terraform-based self-service platform that enables developers to deploy containerized services to GCP Cloud Run with embedded guardrails, monitoring, and GitOps automation.

## Architecture (Three-Tier)
1. **0-bootstrap/** - GCP project setup (platform team only): state bucket, Artifact Registry, IAM, Workload Identity Federation
2. **modules/cloudrun-blueprint/** - Reusable Terraform module: Cloud Run v2 + service accounts + secrets + VPC + monitoring
3. **examples/** - Developer-facing service templates: service.yaml + main.tf + CI/CD pipeline

## Core Design Decisions
- **service.yaml** is the single source of truth for each service configuration
- **Workload Identity Federation (OIDC)** for GitHub Actions auth - NEVER static service account keys
- **Terraform preconditions** for guardrails (not just documentation)
- **Cloud Run v2 API** (google_cloud_run_v2_service), not v1
- **Per-service service accounts** - never share SAs between services
- **GCS backend** with versioning for Terraform state

## Guardrail Rules (Hard Enforcement)
- max_instances <= 50
- Allowed regions: us-central1, us-east1, europe-west1
- Required labels: team, cost_center, environment
- Valid ingress: "all", "internal", "internal-and-cloud-load-balancing"
- min_instances >= 0
- max_instances >= min_instances

## Tech Stack
- Terraform >= 1.5 (for preconditions in check blocks)
- Google provider (google, google-beta)
- GCP: Cloud Run v2, IAM, Secret Manager, VPC Access, Artifact Registry, Cloud Monitoring
- GitHub Actions for CI/CD
- YAML (yamldecode) for service configuration

## Conventions
- Naming: kebab-case for all resources
- All Terraform files: main.tf, variables.tf, outputs.tf, validations.tf
- Module source: relative paths (../modules/cloudrun-blueprint)
- State bucket naming: ${project_id}-tfstate
- Artifact Registry repo: cloud-run-images

## Security Principles
- Least-privilege IAM roles per service account
- WIF attribute conditions scoped to specific repo + branch
- Secrets via Secret Manager, never in env vars or code
- No public ingress by default (internal-and-cloud-load-balancing)

## What NOT to Do
- Do not use google_cloud_run_service (v1) - always use v2
- Do not hardcode project IDs - use variables
- Do not create resources outside of Terraform (except initial gcloud API enablement)
- Do not use count for conditional resources - use for_each or dynamic blocks
- Do not skip validation blocks in the module
