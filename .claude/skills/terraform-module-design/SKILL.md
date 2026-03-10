---
name: terraform-module-design
description: Designs and builds reusable Terraform modules following platform engineering best practices. Use when user says "create module", "new terraform module", "design module", or needs to structure Terraform code with variables, outputs, validations, and documentation.
---

# Terraform Module Design

## Instructions

### Step 1: Define the Module Contract
Before writing any HCL, establish:
- **Inputs (variables.tf)**: What the consumer needs to provide
- **Outputs (outputs.tf)**: What the module exposes back
- **Defaults**: Sensible defaults that reduce consumer burden
- **Validations**: What constraints must be enforced

Ask the user:
1. What GCP resource(s) does this module manage?
2. What should be configurable vs. hardcoded?
3. What guardrails need to be enforced?

### Step 2: Structure the Module Files
Create the standard file layout:
```
modules/<module-name>/
  main.tf          # Core resource definitions
  variables.tf     # Input variables with descriptions, types, defaults
  outputs.tf       # Output values
  validations.tf   # Precondition checks (Terraform 1.5+)
```

### Step 3: Write variables.tf
For each variable:
- Use `type` constraints (string, number, object, map)
- Add `description` that explains purpose AND valid values
- Set `default` only when a safe default exists
- Use `validation` blocks for simple checks

Example pattern:
```hcl
variable "config_file" {
  type        = string
  description = "Path to the service YAML configuration file"
}

variable "image_tag" {
  type        = string
  description = "Container image tag to deploy (e.g., 'latest', 'v1.2.3', commit SHA)"
  default     = "latest"
}
```

### Step 4: Write main.tf with Resource Composition
- Use `locals` to parse configuration (e.g., yamldecode)
- Use `dynamic` blocks for optional nested configurations
- Create dependent resources in logical order
- Use `depends_on` only when implicit dependencies are insufficient

### Step 5: Write validations.tf with Preconditions
Use `null_resource` with `lifecycle.precondition` for guardrail enforcement:
```hcl
resource "null_resource" "validate_max_instances" {
  lifecycle {
    precondition {
      condition     = local.config.scaling.max_instances <= 50
      error_message = "max_instances cannot exceed 50. Got: ${local.config.scaling.max_instances}"
    }
  }
}
```

CRITICAL: Every guardrail must be a precondition, not just documentation.

### Step 6: Write outputs.tf
Export values that consumers or CI/CD pipelines need:
- Resource URLs/endpoints
- Resource names/IDs
- Service account emails
- Revision identifiers

### Quality Checklist
Before finalizing:
- [ ] All variables have descriptions
- [ ] Sensitive variables marked with `sensitive = true`
- [ ] Preconditions cover all guardrail rules from CLAUDE.md
- [ ] Outputs include everything CI/CD needs
- [ ] No hardcoded project IDs, regions, or credentials
- [ ] Uses for_each over count for conditional resources

## Common Issues

### Module consumers get cryptic errors
Cause: Missing or vague validation messages.
Fix: Every precondition error_message must include the actual value and the expected constraint.

### Circular dependencies
Cause: Resources referencing each other.
Fix: Use `locals` as intermediary or restructure resource graph.
