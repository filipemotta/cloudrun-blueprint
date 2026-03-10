# -----------------------------------------------------------------------------
# Parse YAML configuration
# -----------------------------------------------------------------------------
locals {
  raw = yamldecode(file(var.config_file))

  ingress_map = {
    "all"                               = "INGRESS_TRAFFIC_ALL"
    "internal"                          = "INGRESS_TRAFFIC_INTERNAL_ONLY"
    "internal-and-cloud-load-balancing" = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  }

  config = {
    service = local.raw.service

    container = {
      image = local.raw.container.image
      port  = try(local.raw.container.port, 8080)
      resources = {
        cpu    = try(local.raw.container.resources.cpu, "1000m")
        memory = try(local.raw.container.resources.memory, "512Mi")
      }
    }

    scaling = {
      min_instances = try(local.raw.scaling.min_instances, 0)
      max_instances = try(local.raw.scaling.max_instances, 5)
      concurrency   = try(local.raw.scaling.concurrency, 80)
    }

    env_vars = try(local.raw.env_vars, {})
    secrets  = try(local.raw.secrets, [])

    networking = {
      ingress       = try(local.raw.networking.ingress, "internal-and-cloud-load-balancing")
      vpc_connector = try(local.raw.networking.vpc_connector, false)
      cloud_armor   = try(local.raw.networking.cloud_armor, false)
    }

    labels = local.raw.labels
  }
}

# -----------------------------------------------------------------------------
# 1. Per-service Service Account
# -----------------------------------------------------------------------------
resource "google_service_account" "service" {
  account_id   = "${local.config.service.name}-sa"
  display_name = "SA for ${local.config.service.name}"
  project      = local.config.service.project
}

# -----------------------------------------------------------------------------
# 2. Secret Manager IAM (grant SA access to each secret)
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret_iam_member" "access" {
  for_each = { for s in local.config.secrets : s.name => s }

  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.service.email}"
  project   = local.config.service.project
}

# -----------------------------------------------------------------------------
# 3. VPC Connector (conditional)
# -----------------------------------------------------------------------------
resource "google_vpc_access_connector" "this" {
  count = local.config.networking.vpc_connector ? 1 : 0

  name          = "${local.config.service.name}-connector"
  region        = local.config.service.region
  ip_cidr_range = var.vpc_connector_cidr
  network       = var.shared_vpc_network
  project       = local.config.service.project
}

# -----------------------------------------------------------------------------
# 4. Cloud Run v2 Service
# -----------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "this" {
  name     = local.config.service.name
  location = local.config.service.region
  project  = local.config.service.project
  ingress  = local.ingress_map[local.config.networking.ingress]
  labels   = local.config.labels

  template {
    service_account = google_service_account.service.email

    scaling {
      min_instance_count = local.config.scaling.min_instances
      max_instance_count = local.config.scaling.max_instances
    }

    max_instance_request_concurrency = local.config.scaling.concurrency

    containers {
      image = "${local.config.container.image}:${var.image_tag}"

      ports {
        container_port = local.config.container.port
      }

      resources {
        limits = {
          cpu    = local.config.container.resources.cpu
          memory = local.config.container.resources.memory
        }
      }

      # Plain environment variables
      dynamic "env" {
        for_each = local.config.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret Manager references
      dynamic "env" {
        for_each = { for s in local.config.secrets : s.name => s }
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_id
              version = try(env.value.version, "latest")
            }
          }
        }
      }
    }

    dynamic "vpc_access" {
      for_each = local.config.networking.vpc_connector ? [1] : []
      content {
        connector = google_vpc_access_connector.this[0].id
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.access,
  ]
}

# -----------------------------------------------------------------------------
# 4b. Allow unauthenticated access when ingress is "all"
# -----------------------------------------------------------------------------
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = local.config.networking.ingress == "all" ? 1 : 0

  project  = google_cloud_run_v2_service.this.project
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# -----------------------------------------------------------------------------
# 5. Monitoring Alert Policy (conditional)
# -----------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "error_rate" {
  count = var.enable_monitoring ? 1 : 0

  display_name = "${local.config.service.name} - High 5xx Rate"
  project      = local.config.service.project
  combiner     = "OR"

  conditions {
    display_name = "5xx error rate"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${local.config.service.name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
