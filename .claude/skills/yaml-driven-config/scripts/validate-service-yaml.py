#!/usr/bin/env python3
"""Validate service.yaml against the Cloud Run Blueprint platform schema."""
import sys
import yaml

ALLOWED_REGIONS = ["us-central1", "us-east1", "europe-west1"]
ALLOWED_INGRESS = ["all", "internal", "internal-and-cloud-load-balancing"]
MAX_INSTANCES = 50


def validate(config):
    errors = []

    # Required top-level sections
    for section in ["service", "container", "labels"]:
        if section not in config:
            errors.append(f"Missing required section: '{section}'")

    # service fields
    if "service" in config:
        svc = config["service"]
        for field in ["name", "project", "region"]:
            if field not in svc:
                errors.append(f"Missing required field: service.{field}")
        if "region" in svc and svc["region"] not in ALLOWED_REGIONS:
            errors.append(
                f"Invalid region: '{svc['region']}'. Allowed: {ALLOWED_REGIONS}"
            )
        if "name" in svc:
            name = svc["name"]
            if name != name.lower() or " " in name or "_" in name:
                errors.append(
                    f"service.name must be kebab-case: '{name}'"
                )

    # container fields
    if "container" in config:
        if "image" not in config["container"]:
            errors.append("Missing required field: container.image")

    # scaling constraints
    if "scaling" in config:
        sc = config["scaling"]
        max_inst = sc.get("max_instances", 5)
        min_inst = sc.get("min_instances", 0)
        if max_inst > MAX_INSTANCES:
            errors.append(
                f"max_instances ({max_inst}) exceeds limit ({MAX_INSTANCES})"
            )
        if min_inst < 0:
            errors.append(f"min_instances ({min_inst}) cannot be negative")
        if max_inst < min_inst:
            errors.append(
                f"max_instances ({max_inst}) must be >= min_instances ({min_inst})"
            )

    # networking constraints
    if "networking" in config:
        ingress = config["networking"].get(
            "ingress", "internal-and-cloud-load-balancing"
        )
        if ingress not in ALLOWED_INGRESS:
            errors.append(
                f"Invalid ingress: '{ingress}'. Allowed: {ALLOWED_INGRESS}"
            )

    # required labels
    if "labels" in config:
        for label in ["team", "cost_center", "environment"]:
            if label not in config["labels"]:
                errors.append(f"Missing required label: '{label}'")
            elif not config["labels"][label]:
                errors.append(f"Label '{label}' cannot be empty")

    return errors


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "service.yaml"
    try:
        with open(path) as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"ERROR: File not found: {path}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"ERROR: Invalid YAML: {e}", file=sys.stderr)
        sys.exit(1)

    errors = validate(config)
    if errors:
        print(f"Validation FAILED ({len(errors)} error(s)):", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Validation PASSED: {path}")
