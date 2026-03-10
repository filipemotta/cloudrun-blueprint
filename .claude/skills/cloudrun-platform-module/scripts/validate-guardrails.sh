#!/bin/bash
# Quick guardrail pre-check before terraform plan
# Usage: ./validate-guardrails.sh service.yaml
set -euo pipefail

YAML_FILE="${1:?Usage: $0 <service.yaml>}"

if ! command -v yq &> /dev/null; then
  echo "ERROR: yq is required. Install: brew install yq" >&2
  exit 1
fi

ERRORS=0

# Rule 1: max_instances <= 50
MAX=$(yq '.scaling.max_instances // 5' "$YAML_FILE")
if [ "$MAX" -gt 50 ]; then
  echo "FAIL: max_instances=$MAX exceeds limit of 50" >&2
  ERRORS=$((ERRORS + 1))
fi

# Rule 2: Region whitelist
REGION=$(yq '.service.region' "$YAML_FILE")
if [[ ! "$REGION" =~ ^(us-central1|us-east1|europe-west1)$ ]]; then
  echo "FAIL: region '$REGION' not in allowed list" >&2
  ERRORS=$((ERRORS + 1))
fi

# Rule 3: Required labels
for LABEL in team cost_center environment; do
  VAL=$(yq ".labels.$LABEL // \"\"" "$YAML_FILE")
  if [ -z "$VAL" ] || [ "$VAL" = "null" ]; then
    echo "FAIL: missing required label '$LABEL'" >&2
    ERRORS=$((ERRORS + 1))
  fi
done

# Rule 4: Valid ingress
INGRESS=$(yq '.networking.ingress // "internal-and-cloud-load-balancing"' "$YAML_FILE")
if [[ ! "$INGRESS" =~ ^(all|internal|internal-and-cloud-load-balancing)$ ]]; then
  echo "FAIL: invalid ingress '$INGRESS'" >&2
  ERRORS=$((ERRORS + 1))
fi

# Rule 5: min_instances >= 0
MIN=$(yq '.scaling.min_instances // 0' "$YAML_FILE")
if [ "$MIN" -lt 0 ]; then
  echo "FAIL: min_instances=$MIN is negative" >&2
  ERRORS=$((ERRORS + 1))
fi

# Rule 6: max >= min
if [ "$MAX" -lt "$MIN" ]; then
  echo "FAIL: max_instances=$MAX < min_instances=$MIN" >&2
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "Guardrail check FAILED: $ERRORS violation(s)" >&2
  exit 1
fi

echo "Guardrail check PASSED: $YAML_FILE"
