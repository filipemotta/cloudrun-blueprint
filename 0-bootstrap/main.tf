terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }

  # Bootstrap uses local state — no remote backend here
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

# -----------------------------------------------------------------------------
# 1. GCS State Bucket (for all other Terraform layers)
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region
  project  = var.project_id

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# 2. Artifact Registry (container images)
# -----------------------------------------------------------------------------
resource "google_artifact_registry_repository" "cloud_run_images" {
  location      = var.region
  repository_id = "cloud-run-images"
  format        = "DOCKER"
  description   = "Container images for Cloud Run services"
  project       = var.project_id
}

# -----------------------------------------------------------------------------
# 3. Terraform Deployer Service Account
# -----------------------------------------------------------------------------
resource "google_service_account" "deployer" {
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployer for Cloud Run services"
  project      = var.project_id
}

locals {
  deployer_roles = [
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountAdmin",
    "roles/secretmanager.admin",
    "roles/vpcaccess.admin",
    "roles/monitoring.editor",
    "roles/storage.admin",
  ]
}

resource "google_project_iam_member" "deployer_roles" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# -----------------------------------------------------------------------------
# 3b. Image Pusher Service Account (least-privilege for Docker build + push)
# -----------------------------------------------------------------------------
resource "google_service_account" "image_pusher" {
  account_id   = "image-pusher"
  display_name = "Image Pusher for CI/CD Docker builds"
  project      = var.project_id
}

resource "google_project_iam_member" "image_pusher_ar" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.image_pusher.email}"
}

# -----------------------------------------------------------------------------
# 4. Workload Identity Federation (GitHub Actions OIDC)
# -----------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "WIF pool for GitHub Actions OIDC authentication"
  project                   = var.project_id
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  project                            = var.project_id

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

resource "google_service_account_iam_member" "wif_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

resource "google_service_account_iam_member" "wif_image_pusher" {
  service_account_id = google_service_account.image_pusher.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}
