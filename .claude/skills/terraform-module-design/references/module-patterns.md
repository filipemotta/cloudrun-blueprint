# Terraform Module Patterns for Cloud Run Blueprint

## Pattern: YAML-Parsed Configuration Module

```hcl
# Parse external config
locals {
  config = yamldecode(file(var.config_file))
}

# Use parsed values throughout
resource "google_cloud_run_v2_service" "this" {
  name     = local.config.service.name
  location = local.config.service.region
  # ...
}
```

## Pattern: Conditional Resource with Dynamic Blocks

```hcl
# VPC connector only when requested
resource "google_vpc_access_connector" "this" {
  count = try(local.config.networking.vpc_connector, false) ? 1 : 0

  name          = "${local.config.service.name}-connector"
  region        = local.config.service.region
  ip_cidr_range = var.vpc_connector_cidr
  network       = var.shared_vpc_network
}

# Dynamic secrets in container
dynamic "env" {
  for_each = try(local.config.secrets, [])
  content {
    name = env.value.name
    value_source {
      secret_key_ref {
        secret  = env.value.secret_id
        version = try(env.value.version, "latest")
      }
    }
  }
}
```

## Pattern: Precondition Guardrails (Terraform 1.5+)

```hcl
resource "null_resource" "guardrails" {
  lifecycle {
    precondition {
      condition     = local.config.scaling.max_instances <= 50
      error_message = "GUARDRAIL VIOLATION: max_instances=${local.config.scaling.max_instances} exceeds limit of 50."
    }
    precondition {
      condition     = contains(["us-central1", "us-east1", "europe-west1"], local.config.service.region)
      error_message = "GUARDRAIL VIOLATION: region '${local.config.service.region}' not in allowed list."
    }
  }
}
```

## Pattern: Per-Service Service Account

```hcl
resource "google_service_account" "service" {
  account_id   = "${local.config.service.name}-sa"
  display_name = "SA for ${local.config.service.name}"
  project      = local.config.service.project
}

# Grant access to specific secrets only
resource "google_secret_manager_secret_iam_member" "access" {
  for_each = { for s in try(local.config.secrets, []) : s.name => s }

  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.service.email}"
}
```

## Pattern: Monitoring Alert with Conditional Creation

```hcl
resource "google_monitoring_alert_policy" "error_rate" {
  count = var.enable_monitoring ? 1 : 0

  display_name = "${local.config.service.name} - High 5xx Rate"
  combiner     = "OR"

  conditions {
    display_name = "5xx error rate"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${local.config.service.name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
    }
  }
}
```
