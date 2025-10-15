# Configuration Management System

## Purpose
Operate the `platform-config` namespace as the source of truth for configuration, secrets, and bootstrap tooling that every MyFarsi service depends on. This stack owns Consul, Vault, and the `config-cli` workflow referenced throughout `ARCHITECTURE.md`, `SystemReqs.md`, and `90_cli_tools/config-cli.md`.

## Responsibilities
- Deliver validated configuration to services and CI/CD pipelines via Consul KV and GitOps exports.
- Issue scoped Consul ACL tokens and runtime secrets through Vault (see `01_conf_mgmt/adr/0001-secret-rotation.md`).
- Ship the `config-cli` binary and container image so workloads can hydrate configuration before process start.
- Provide disaster recovery, observability, and governance guardrails for configuration changes.

## Component Map
| Component | Description | Key Notes |
| --- | --- | --- |
| Consul Servers | 3 node (staging) or 5 node (production) cluster supplying KV, service discovery, Connect CA. | Runs on the Equinix Metal-backed Kubernetes worker pool defined in Layer 1 ADR `02_cicd_mgmt/adr/0001-hosting-platform.md`. |
| Vault Cluster | Integrated storage (raft) deployment handling secrets, Consul token management, and third-party credential rotation. | Vault audit devices forward logs to Layer 3 observability sinks. |
| config-cli | Go-based CLI that fetches configuration, registers services, renders templates, and executes wrapped commands. | Published from `90_cli_tools/config-cli.md`; pipelines pin semantic versions. |
| GitOps Repository | `configs/<service>/<env>/service.vN.yaml` artifacts plus Consul config entries. | Managed by Argo CD; validation jobs run `config-cli consul export --validate`. |
| Automation | CI pipelines, Argo Workflows, and cronjobs that perform exports, rotations, and drift detection. | Credentials obtained via Vault AppRole with short TTL tokens. |

## Environments
- **Local**: Docker Compose with single Consul (`-dev`) and Vault dev server for experimentation. No persistence.
- **Staging**: Consul 3 node quorum, Vault HA (3 nodes). Namespaces mirror production. Metrics shipped to staging observability stack.
- **Production**: Consul 5 node quorum across AZs, Vault 5 node raft cluster, dedicated worker pool for control-plane workloads. Mesh gateways expose limited services to other domains.

## Core Workflows
### Authoring and Promotion
1. Engineer edits configuration under `configs/<service>/<env>/`.
2. PR triggers lint (`npx markdownlint-cli2` for docs) and `make config-validate` which calls `config-cli consul export --validate`.
3. Merge triggers Argo CD to reconcile; job runs `config-cli consul export --scope <env>` pushing to Consul KV.
4. Drift checker compares live KV to exported artifacts daily; discrepancies open issues.

### Service Bootstrap
1. Entry point wraps application with `config-cli run <service> --environment <env> --service-port <port> -- <command>`.
2. `config-cli` retrieves Consul/Vault credentials via Vault Agent or AppRole, pulls KV data from `<env>/<service>/`, renders templates, registers health checks, and launches the process.
3. On shutdown it deregisters the service and clears cache directories (`/var/lib/config-cli/<service>`).

### CI/CD Usage
1. Self-hosted runners mount `config-cli` binary (managed artifact).
2. Pipelines run `config-cli render` to produce `.env` or YAML files for builds, and `config-cli consul import/export` during promotion.
3. Deployment pipelines publish configuration checksums alongside container images so promotion jobs can verify parity.

### Recovery
1. Nightly Consul snapshots (`consul snapshot save`) and Vault raft snapshots stored in encrypted MinIO bucket (EU residency per `22_db_back/adr/0001-data-retention.md`).
2. Recovery order: restore Vault -> rotate Consul management token via Vault -> restore Consul snapshot -> invalidate stale caches (trigger `config-cli cache purge` across services).

## Security
- All Consul traffic uses TLS with Verify Incoming/Outgoing enabled; gossip keys rotate quarterly.
- Vault issues dynamic Consul tokens and third-party secrets with TTL <= 24 hours.
- Kubernetes NetworkPolicies isolate control-plane pods; only approved namespaces (CI/CD, ops bastions) reach Consul/Vault APIs.
- `config-cli` caches on disk with `0700` permissions; cache encryption is optional but recommended for production (feature flag pending).
- Audit trails: Consul audit log, Vault audit devices, and `config-cli` structured logs feed into the observability stack.

## Observability
- Prometheus scrapes Consul and Vault exporters; key dashboards track quorum health, ACL issuance, secret lease churn, and config-cli run outcomes.
- Alerts: quorum loss, raft apply latency, snapshot failures, token issuance errors, cache fallback rates over agreed thresholds.
- Traceability: `config-cli` emits OTLP traces around Consul/Vault calls for correlation with dependent service spans.

## Governance
- Every change to configuration hierarchy must link to a ticket or ADR. Breaking changes require preview environments or feature flags.
- ADRs for configuration policy live under `01_conf_mgmt/adr/`. Update System Requirements when decisions materially change scope.
- Access managed through Vault roles. Human operators use short-lived tokens obtained via SSO; automation relies on AppRole with CIDR and TTL limits.

## Roadmap
1. Introduce Consul namespaces and partitions for service segmentation across business units.
2. Integrate policy-as-code (OPA) to validate configuration keys before acceptance.
3. Publish config-cli metrics to Prometheus via native exporter for richer SLO tracking.
4. Automate GitOps drift detection with pull request suggestions.
5. Extend config-cli to render Vault secrets alongside Consul data with provider plugins.

## References
- `ARCHITECTURE.md` and `DESIGN.md` for platform context.
- `SystemReqs.md` for layer requirements and recent decisions.
- `90_cli_tools/config-cli.md` for tooling usage.
- `01_conf_mgmt/consul.md` and `01_conf_mgmt/mesh-gateway.md` for platform specifics.
- `02_cicd_mgmt/cicd-runner.md` and `02_cicd_mgmt/gitops-repository.md` for CI/CD integration.
