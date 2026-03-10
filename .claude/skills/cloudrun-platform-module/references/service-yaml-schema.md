# service.yaml Schema Reference

## Complete Schema

```yaml
# REQUIRED: Service identity
service:
  name: string          # kebab-case, 1-63 chars, must start with letter
  project: string       # GCP project ID
  region: string        # Allowed: us-central1, us-east1, europe-west1

# REQUIRED: Container configuration
container:
  image: string         # Full Artifact Registry path (without tag)
  port: number          # Default: 8080, Range: 1-65535
  resources:
    cpu: string         # Default: "1000m", Format: millicores
    memory: string      # Default: "512Mi", Format: Mi/Gi

# OPTIONAL: Scaling behavior
scaling:
  min_instances: number # Default: 0, Range: 0-50
  max_instances: number # Default: 5, Range: 1-50
  concurrency: number   # Default: 80, Range: 1-1000

# OPTIONAL: Environment variables
env_vars:               # Map of string key-value pairs
  KEY_NAME: "value"

# OPTIONAL: Secret Manager references
secrets:
  - name: string        # Env var name in container
    secret_id: string   # Secret Manager secret ID
    version: string     # Default: "latest"

# OPTIONAL: Networking
networking:
  ingress: string       # Default: "internal-and-cloud-load-balancing"
                        # Allowed: "all", "internal", "internal-and-cloud-load-balancing"
  vpc_connector: bool   # Default: false
  cloud_armor: bool     # Default: false

# REQUIRED: Governance labels
labels:
  team: string          # Required, non-empty
  cost_center: string   # Required, non-empty
  environment: string   # Required, non-empty
```

## Minimal Example
```yaml
service:
  name: my-api
  project: my-gcp-project
  region: us-central1
container:
  image: us-central1-docker.pkg.dev/my-gcp-project/cloud-run-images/my-api
labels:
  team: backend
  cost_center: engineering
  environment: dev
```

## Full Example
```yaml
service:
  name: ad-bidding-api
  project: freestar-platform
  region: us-central1
container:
  image: us-central1-docker.pkg.dev/freestar-platform/cloud-run-images/ad-bidding-api
  port: 8080
  resources:
    cpu: "2000m"
    memory: "1Gi"
scaling:
  min_instances: 1
  max_instances: 20
  concurrency: 100
env_vars:
  LOG_LEVEL: "info"
  CACHE_TTL: "300"
secrets:
  - name: API_KEY
    secret_id: ad-bidding-api-key
    version: "latest"
  - name: DB_PASSWORD
    secret_id: ad-bidding-db-pass
    version: "3"
networking:
  ingress: "internal-and-cloud-load-balancing"
  vpc_connector: true
  cloud_armor: true
labels:
  team: adtech
  cost_center: revenue
  environment: production
```
