# Guardrail Rules Reference

## Enforcement Method
All guardrails are Terraform preconditions on `null_resource`, evaluated at plan time.
They BLOCK deployment - not just warn.

## Rules

### 1. Max Instances Limit
- **Rule**: max_instances <= 50
- **Why**: Prevent runaway costs and resource exhaustion
- **Error**: "max_instances cannot exceed 50. Got: {value}"

### 2. Region Whitelist
- **Rule**: region in ["us-central1", "us-east1", "europe-west1"]
- **Why**: Data residency, latency SLAs, cost optimization
- **Error**: "Region '{value}' is not allowed. Must be one of: us-central1, us-east1, europe-west1"

### 3. Required Labels
- **Rule**: labels must contain keys: team, cost_center, environment
- **Why**: Cost allocation, ownership tracking, environment separation
- **Error**: "Missing required label: '{key}'. All services must have: team, cost_center, environment"

### 4. Valid Ingress Type
- **Rule**: ingress in ["all", "internal", "internal-and-cloud-load-balancing"]
- **Why**: Prevent misconfigured network access
- **Error**: "Invalid ingress type: '{value}'. Must be: all, internal, or internal-and-cloud-load-balancing"

### 5. Min Instances Non-Negative
- **Rule**: min_instances >= 0
- **Why**: Terraform validation (Cloud Run doesn't accept negative)
- **Error**: "min_instances cannot be negative. Got: {value}"

### 6. Scaling Consistency
- **Rule**: max_instances >= min_instances
- **Why**: Prevent impossible scaling configurations
- **Error**: "max_instances ({max}) must be >= min_instances ({min})"

## Adding New Guardrails
1. Add the precondition to `validations.tf`
2. Document the rule in this file
3. Update the service.yaml schema reference
4. Add a test case in CI
