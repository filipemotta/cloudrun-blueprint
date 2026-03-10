---
name: cloudrun-platform-module
description: Builds the core Cloud Run v2 platform module with YAML-driven config, per-service IAM, secrets integration, VPC connectors, monitoring alerts, and Terraform precondition guardrails. Use when user says "build cloudrun module", "platform module", "cloud run terraform", or "create the main module".
---

# Cloud Run Platform Module Builder

## Instructions

### Step 1: Define the service.yaml Contract
The YAML schema is the developer interface. Design it with these sections:

```yaml
service:
  name: string          # kebab-case, required
  project: string       # GCP project ID
  region: string        # Must be in allowed list

container:
  image: string         # Artifact Registry path
  port: number          # Default: 8080
  resources:
    cpu: string         # e.g., "1000m"
    memory: string      # e.g., "512Mi"

scaling:
  min_instances: number # >= 0
  max_instances: number # <= 50
  concurrency: number   # Default: 80

env_vars:               # Optional map
  KEY: value

secrets:                # Optional list
  - name: string
    secret_id: string
    version: string     # Default: "latest"

networking:
  ingress: string       # "all" | "internal" | "internal-and-cloud-load-balancing"
  vpc_connector: bool
  cloud_armor: bool

labels:                 # Required keys: team, cost_center, environment
  team: string
  cost_center: string
  environment: string
```

### Step 2: Build modules/cloudrun-blueprint/variables.tf
Minimal inputs - the YAML file carries the configuration:
- `config_file` (string) - Path to service.yaml
- `image_tag` (string) - Container image tag, default "latest"
- `shared_vpc_network` (string, optional) - VPC for connector
- `vpc_connector_cidr` (string, optional) - CIDR for connector
- `enable_monitoring` (bool) - Default true

### Step 3: Build modules/cloudrun-blueprint/main.tf

Parse YAML first:
```hcl
locals {
  config = yamldecode(file(var.config_file))
}
```

Then create resources in this order:

1. **google_service_account** - Per-service SA (never shared)
2. **google_secret_manager_secret_iam_member** - Grant SA access to secrets (dynamic block, iterate over config secrets)
3. **google_vpc_access_connector** - Conditional on networking.vpc_connector
4. **google_cloud_run_v2_service** - The main resource:
   - template.containers[0] with image, ports, resources, env, secrets
   - template.scaling with min/max
   - template.service_account
   - template.vpc_access (conditional)
   - ingress from config
   - labels from config
5. **google_monitoring_alert_policy** - Conditional on enable_monitoring
   - Alert on 5xx error rate threshold

CRITICAL: Use `google_cloud_run_v2_service`, NOT `google_cloud_run_service`.

### Step 4: Build modules/cloudrun-blueprint/validations.tf
Create null_resource with lifecycle.precondition for EACH guardrail:
- max_instances <= 50
- region in allowed list
- required labels present (team, cost_center, environment)
- valid ingress type
- min_instances >= 0
- max_instances >= min_instances

Every error_message MUST show the actual value received.

### Step 5: Build modules/cloudrun-blueprint/outputs.tf
Export:
- service_url
- service_name
- service_account_email
- revision
- vpc_connector_id (if created)

### Quality Checklist
- [ ] YAML schema supports all Cloud Run v2 features needed
- [ ] Dynamic blocks for optional secrets and env_vars
- [ ] Conditional resources use count = var.enabled ? 1 : 0 pattern
- [ ] All 6 guardrails enforced as preconditions
- [ ] Monitoring alert uses correct metric filter
- [ ] Service account has minimum necessary permissions

## Common Issues

### "Invalid template" errors
Cause: YAML indentation or missing required fields.
Fix: Validate YAML structure in locals before resource creation.

### Secrets not accessible at runtime
Cause: Secret Manager IAM binding missing or wrong SA.
Fix: Ensure google_secret_manager_secret_iam_member uses the per-service SA, not the deployer SA.

### VPC connector conflicts
Cause: CIDR range overlaps with existing network.
Fix: Use a /28 CIDR range that doesn't conflict. Document recommended ranges.
