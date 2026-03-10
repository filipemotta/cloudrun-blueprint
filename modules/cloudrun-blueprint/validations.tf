# -----------------------------------------------------------------------------
# Guardrail enforcement via Terraform preconditions
# All checks run at plan time and block deployment on violation
# -----------------------------------------------------------------------------
resource "null_resource" "guardrails" {
  lifecycle {
    precondition {
      condition     = local.config.scaling.max_instances <= 50
      error_message = "GUARDRAIL VIOLATION: max_instances=${local.config.scaling.max_instances} exceeds limit of 50."
    }

    precondition {
      condition     = contains(["us-central1", "us-east1", "europe-west1"], local.config.service.region)
      error_message = "GUARDRAIL VIOLATION: region '${local.config.service.region}' is not allowed. Must be one of: us-central1, us-east1, europe-west1."
    }

    precondition {
      condition = alltrue([
        contains(keys(local.config.labels), "team"),
        contains(keys(local.config.labels), "cost_center"),
        contains(keys(local.config.labels), "environment"),
      ])
      error_message = "GUARDRAIL VIOLATION: Missing required labels. All services must have: team, cost_center, environment."
    }

    precondition {
      condition     = contains(["all", "internal", "internal-and-cloud-load-balancing"], local.config.networking.ingress)
      error_message = "GUARDRAIL VIOLATION: ingress '${local.config.networking.ingress}' is invalid. Must be: all, internal, or internal-and-cloud-load-balancing."
    }

    precondition {
      condition     = local.config.scaling.min_instances >= 0
      error_message = "GUARDRAIL VIOLATION: min_instances=${local.config.scaling.min_instances} cannot be negative."
    }

    precondition {
      condition     = local.config.scaling.max_instances >= local.config.scaling.min_instances
      error_message = "GUARDRAIL VIOLATION: max_instances=${local.config.scaling.max_instances} must be >= min_instances=${local.config.scaling.min_instances}."
    }
  }
}
