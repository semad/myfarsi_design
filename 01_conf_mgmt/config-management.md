# Configuration Management System

## Mission
Provide a dedicated control plane namespace (`platform-config`) that owns configuration distribution for all platform services and CI/CD pipelines. This stack operates its own Consul and Vault clusters, exposes `config-cli` tooling for runtime bootstrap, and maintains versioned configuration artifacts governed through GitOps.

## Components
| Component | Responsibility |
| --- | --- |
| Consul Cluster | 3–5 server quorum (per environment) serving KV configuration, service discovery, and Connect CA for internal agents. |
| Vault Cluster | Manages ACL tokens for Consul, issues per-service credentials, and stores sensitive configuration that must not reside in Consul KV. |
| `config-cli` | Entry-point wrapper and CLI for retrieving Consul keys, registering services, and synchronising configuration files (see `designs/config-cli.md`). |
| GitOps Repository | Stores versioned configuration exports (`name.vN.yaml`) alongside environment manifests; changes flow through review and automated validation. |
| CI/CD Integrations | GitHub Actions runners and automation jobs that render/runtime-inject configuration via `config-cli` pointing to this namespace. |

## Deployment Model
- Namespace/cluster: `platform-config`.
- Consul servers run on dedicated nodes with persistent volumes; agents run as DaemonSet on shared worker pools for clients that need KV/service discovery.
- Vault servers deploy with integrated storage (Raft) and unseal automation; agent sidecars distribute dynamic credentials to workloads.
- `config-cli` container image published from `tools/ccm_consul`; pipelines and applications copy the binary during build.
- GitOps (Argo CD) manages Consul/Vault Helm charts, config entries, root policies, and RBAC.

## Workflows
1. **Configuration Authoring**
   - Operator edits YAML/JSON in repo → PR triggers validation (`config-cli consul export --validate` or unit tests).
   - After merge, GitOps sync job runs `config-cli consul export` to push changes into Consul KV.
2. **Service Bootstrap**
   - Application container entrypoint: `config-cli run <service> --environment <env> --service-port <port> -- <cmd>`.
   - `config-cli` fetches keys from `<env>/<service>/`, merges env vars, registers service in Consul, executes process, and handles deregistration on shutdown.
3. **CI/CD Usage**
   - Runners download `config-cli` binary (or use container image).
   - Pipelines run `config-cli consul get` / `config-cli render` to template environment files before builds or deployments.
   - When pipelines deploy new config, they use `config-cli consul import/export` to sync versioned files.
4. **Disaster Recovery**
   - Nightly Consul snapshots + Vault raft snapshots stored in encrypted object storage.
   - Recovery plan: restore Vault first, rotate Consul ACL tokens via Vault, restore Consul snapshot, validate `config-cli` cache eviction.

## Security Controls
- Vault issues scoped Consul ACL tokens via dynamic secrets; tokens injected through Vault Agent or `config-cli` runtime.
- Consul gossip TLS and ACL enforcement enabled; root tokens sealed in Vault.
- NetworkPolicies isolate `platform-config` namespace; only approved ingress (CI/CD runners, admin jumpboxes) allowed.
- Configuration cache files on workloads stored under `/etc/config-cli/` with restricted permissions.
- Audit logs:
  - Consul ACL/Config entry audits shipped to centralized logging.
  - Vault audit devices stream request logs to SIEM.
  - `config-cli` emits structured JSON logs (operations, counts, cache fallback).

## Observability
- Consul and Vault exporters scraped by platform Prometheus (`designs/observability-platform.md`).
- Dashboards track:
  - Consul leader changes, RPC latency, KV request volume, ACL token issuance.
  - Vault seal status, auth method usage, secret lease counts.
  - `config-cli` run metrics (success/fail counts) via pipeline instrumentation.
- Alerts: quorum loss, replicated state divergence, token issuance failures, config cache fallback rate > X%.

## GitOps & Governance
- Configuration repo structure:
  ```
  configs/
    <service>/
      production/
        service.v5.yaml
      staging/
        service.v3.yaml
  ```
- Promotion workflow: export staging version to new prod file (`vN+1`), review, merge, `config-cli consul export` pushes to Consul.
- ADRs capture significant policy or layout changes (see `designs/adr/*`).
- Access: operators require short-lived Vault tokens; CI users rely on OIDC Federation to assume roles that permit `consul:v1` API calls.

## Integration Points
- **Authentication System**: consumes configuration via `config-cli` and registers forward-auth/Authentik components with the authentication namespace’s Consul cluster.
- **Media Business Logic**: obtains runtime configuration through Consul (`config-cli`) but manages its own Consul/Vault for internal services.
- **External Tooling**: home-edge and bootstrap projects mount `config-cli` to fetch configuration even in constrained networks.

## Roadmap
1. Implement Consul namespaces/partitions for finer isolation across product lines.
2. Add automated drift detection comparing GitOps exports with live Consul KV.
3. Publish Prometheus metrics from `config-cli` runs to track cache fallbacks, runtime, and exit codes.
4. Introduce policy-as-code (OPA) to validate configuration keys before acceptance.
5. Evaluate integrating Vault secrets rendering into `config-cli` via pluggable providers once scoped needs arise.

## References
- Architecture context: `designs/ARCHITECTURE.md`
- Tooling: `designs/config-cli.md`
- Consul platform details: `designs/consul.md`
- Vault operations: internal runbooks under `0_mediaInfra/`
- CI/CD runner usage: `designs/cicd-runner.md`
- GitOps process: `designs/gitops-repository.md`
