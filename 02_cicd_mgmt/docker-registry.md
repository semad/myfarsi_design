# Docker Registry Service

## Role

Private registry backing Layer 1 CI/CD pipelines. It stores build artifacts, serves pulls to Kubernetes clusters and developers, and avoids reliance on public registries.

## Deployment Model

- Base image: `registry:3` (Docker Distribution).
- Wrapped by `config-cli run docker-registry` to load configuration from Consul and register health checks (see `90_cli_tools/config-cli.md`).
- Runs as StatefulSet in `cicd` namespace with PVC-based storage or S3/MinIO backend depending on environment.
- Exposes port `5000` (HTTPS via mesh sidecar) and optional `/metrics` endpoint for Prometheus.

## Configuration Flow

1. `config-cli` fetches Consul KV under `registry/<env>/` (details in `90_cli_tools/config-cli.md`).
2. Keys map to env vars (`REGISTRY_STORAGE_*`, `REGISTRY_AUTH_*`, `REGISTRY_HTTP_TLS_*`).
3. Service registered with Consul, health-checked via `/v2/`.
4. Registry process starts; on SIGTERM `config-cli` deregisters and stops gracefully.

## Storage Options

- **Filesystem (PVC)**: Default for staging/prod; replicates via underlying storage class (e.g., Ceph, EBS). Daily snapshots + retention policy.
- **S3/MinIO**: Configure `REGISTRY_STORAGE_S3_BUCKET`, `REGISTRY_STORAGE_S3_REGION`, `REGISTRY_STORAGE_S3_ROOTDIRECTORY`. Ideal for multi-node registry or DR; requires IAM role/credentials from Vault.
- Enable garbage collection (`registry garbage-collect`) via cronjob or on-demand job; ensure no pushes during run.

## Security

- TLS termination handled by Consul Connect sidecar or fronting ingress; internal traffic uses mTLS.
- Basic auth/OIDC tokens enforced via `REGISTRY_AUTH` configuration; credentials stored in Vault and injected by `config-cli`.
- Content trust: sign images with Notation or Cosign; store signatures alongside artifacts.
- Restrict network access to CI runners, Kubernetes nodes, and authorized developer IPs via SecurityGroups/NetworkPolicies.

## Observability & Operations

- Metrics: enable `REGISTRY_HTTP_HEADERS_Access-Control-Expose-Headers` for metrics; scrape `/metrics` (if using distribution >= 3.0) or deploy sidecar exporter.
- Logs: JSON structured logs emitted by `config-cli` + registry; collected by OpenTelemetry Collector.
- Alerts: high 5xx error rate, storage capacity > 80%, auth failures spike, garbage collection failures.
- Backup: snapshot PVC or rely on S3 versioning. Test restore by promoting staging registry from backup monthly.

## Runbooks

- **Upgrade**: Pull new distribution image, rotate pods sequentially after verifying compatibility.
- **Garbage Collect**: Scale deployment to 0, run `registry garbage-collect`, restart. For S3 backend, run from maintenance job with `delete-untagged`.
- **Credential Rotation**: Update Vault secret → Consul KV update → rolling restart to pick up new creds.
- **Incident Response**: On suspected compromise, revoke tokens, clear cached credentials, rotate TLS certs, rebuild images from source and republish.

## References

- CI/CD platform (`02_cicd_mgmt/cicd-runner.md`)
- Storage guidelines (`21_content_manager/minio-content-server.md`)
