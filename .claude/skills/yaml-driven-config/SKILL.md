---
name: yaml-driven-config
description: Designs YAML-based configuration schemas for platform abstractions, creating developer-friendly interfaces that hide infrastructure complexity. Use when user says "design config schema", "service.yaml", "yaml interface", "developer config", or "configuration contract".
---

# YAML-Driven Configuration Design

## Instructions

### Step 1: Identify the Abstraction Level
Ask the user:
1. What should developers control? (scaling, resources, env vars)
2. What should the platform hide? (IAM, networking details, monitoring setup)
3. What must be enforced? (regions, limits, required labels)

Principle: **Developers describe WHAT they want, the platform decides HOW.**

### Step 2: Design the Schema Sections
Organize the YAML into logical groups:

```yaml
# Section 1: Identity (required, immutable after creation)
service:
  name: string
  project: string
  region: string

# Section 2: Runtime (developer controls)
container:
  image: string
  port: number
  resources:
    cpu: string
    memory: string

# Section 3: Behavior (developer controls with guardrails)
scaling:
  min_instances: number
  max_instances: number
  concurrency: number

# Section 4: Configuration (developer controls)
env_vars:
  KEY: value
secrets:
  - name: string
    secret_id: string
    version: string

# Section 5: Platform-managed (limited developer control)
networking:
  ingress: enum
  vpc_connector: bool

# Section 6: Governance (required by platform)
labels:
  team: string
  cost_center: string
  environment: string
```

### Step 3: Define Defaults and Constraints
For each field, document:
- **Type**: string, number, bool, enum, map, list
- **Required**: yes/no
- **Default**: value if omitted
- **Constraint**: validation rule
- **Mutable**: can it change after creation?

Example table:
| Field | Type | Required | Default | Constraint |
|-------|------|----------|---------|------------|
| service.name | string | yes | - | kebab-case, max 63 chars |
| container.port | number | no | 8080 | 1-65535 |
| scaling.max_instances | number | no | 5 | 1-50 |
| labels.team | string | yes | - | non-empty |

### Step 4: Create Example Configurations
Generate 3 example service.yaml files:

1. **Minimal** - Only required fields, all defaults
2. **Standard** - Common production setup with env vars and scaling
3. **Full** - All features including secrets, VPC, monitoring

### Step 5: Implement Parsing in Terraform
```hcl
locals {
  raw    = yamldecode(file(var.config_file))
  config = {
    service = local.raw.service
    container = merge({
      port = 8080
      resources = { cpu = "1000m", memory = "512Mi" }
    }, local.raw.container)
    scaling = merge({
      min_instances = 0
      max_instances = 5
      concurrency   = 80
    }, try(local.raw.scaling, {}))
    # ... merge defaults for each section
  }
}
```

Use `merge()` and `try()` to apply defaults safely.

### Step 6: Generate Validation Script
Create `scripts/validate-service-yaml.py`:
- Parse YAML
- Check required fields
- Validate types and constraints
- Return clear error messages with line numbers
- Exit 0 on success, 1 on failure (for CI integration)

## Design Principles

### Keep It Flat
Bad: deeply nested configs that are hard to remember.
Good: max 3 levels of nesting.

### Make Safe Things Easy
Default values should be the safest option:
- min_instances: 0 (cost-effective for dev)
- ingress: "internal-and-cloud-load-balancing" (not public)
- max_instances: 5 (prevents runaway scaling)

### Make Dangerous Things Visible
If a developer sets `ingress: "all"`, the platform should log a warning.
If `max_instances: 50`, force explicit justification in labels.

## Common Issues

### YAML parsing fails silently
Cause: Terraform yamldecode gives cryptic errors.
Fix: Pre-validate YAML in CI before terraform runs.

### Missing optional sections cause errors
Cause: Accessing undefined YAML keys.
Fix: Always wrap optional access with `try(local.raw.section, {})`.
