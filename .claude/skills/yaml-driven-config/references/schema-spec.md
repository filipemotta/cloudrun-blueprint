# YAML Configuration Schema Specification

## Design Philosophy
The YAML config is the **developer interface** to the platform. It should:
1. Be self-documenting (field names explain purpose)
2. Have safe defaults (omitting optional fields produces a working, secure service)
3. Fail early (validation catches errors before terraform plan)
4. Be flat (max 3 nesting levels)

## Terraform Parsing Pattern

```hcl
locals {
  raw = yamldecode(file(var.config_file))

  # Apply defaults via merge
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
```

## Validation Script Pattern (Python)

```python
#!/usr/bin/env python3
"""Validate service.yaml against platform schema."""
import sys
import yaml

REQUIRED_FIELDS = {
    "service": ["name", "project", "region"],
    "container": ["image"],
    "labels": ["team", "cost_center", "environment"],
}

ALLOWED_REGIONS = ["us-central1", "us-east1", "europe-west1"]
ALLOWED_INGRESS = ["all", "internal", "internal-and-cloud-load-balancing"]
MAX_INSTANCES = 50

def validate(config):
    errors = []

    # Check required sections and fields
    for section, fields in REQUIRED_FIELDS.items():
        if section not in config:
            errors.append(f"Missing required section: {section}")
            continue
        for field in fields:
            if field not in config[section]:
                errors.append(f"Missing required field: {section}.{field}")

    # Validate constraints
    if "service" in config:
        region = config["service"].get("region")
        if region and region not in ALLOWED_REGIONS:
            errors.append(f"Invalid region: {region}. Allowed: {ALLOWED_REGIONS}")

    if "scaling" in config:
        max_inst = config["scaling"].get("max_instances", 5)
        min_inst = config["scaling"].get("min_instances", 0)
        if max_inst > MAX_INSTANCES:
            errors.append(f"max_instances ({max_inst}) exceeds limit ({MAX_INSTANCES})")
        if min_inst < 0:
            errors.append(f"min_instances ({min_inst}) cannot be negative")
        if max_inst < min_inst:
            errors.append(f"max_instances ({max_inst}) < min_instances ({min_inst})")

    if "networking" in config:
        ingress = config["networking"].get("ingress", "internal-and-cloud-load-balancing")
        if ingress not in ALLOWED_INGRESS:
            errors.append(f"Invalid ingress: {ingress}. Allowed: {ALLOWED_INGRESS}")

    return errors

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "service.yaml"
    with open(path) as f:
        config = yaml.safe_load(f)

    errors = validate(config)
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    print("Validation passed.")
```
