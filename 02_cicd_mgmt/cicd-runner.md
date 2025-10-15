# GitOps CI/CD Platform

## Overview
Combine GitHub Actions with Argo CD so application changes flow through declarative manifests, and workflows land on the right execution environment via labeled self-hosted runners. The platform spans Kubernetes-hosted ephemeral runners for containerized jobs, persistent Docker runners for lightweight tasks, and GitOps synchronization that keeps Kubernetes clusters in lockstep with source control.

## Runner Classes
| Label Set | Executor | Primary Workloads | Resources / Placement |
| --- | --- | --- | --- |
| `self-hosted`, `k8s` | Kubernetes (actions-runner-controller) | Container builds, integration/E2E tests, canary deploys | `runner-k8s` namespace; 2 vCPU / 6 GiB pods with Kaniko cache |
| `self-hosted`, `k8s-hi` | Kubernetes, high-memory pool | Load/perf suites, long-running jobs | Dedicated node pool; 4 vCPU / 12 GiB pods, PVC-backed workspace |
| `self-hosted`, `docker` | Dedicated Docker host/VM | Lint/unit tests, docs, CLI builds | Developer workstation or builds VM; inherits host limits |
| `self-hosted`, `docker-slim` | Pre-baked laptop image | Offline/air-gapped scenarios | Cached registries, fixed toolchain snapshot |

Add specialized labels (`gpu`, `arm64`) by registering additional RunnerDeployments or host agents following the same pattern.

## Kubernetes Runner Stack
- Managed by [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller) (ARC) installed via Helm.
- ARC authenticates with GitHub using an App; it watches pending jobs and spins up ephemeral runner pods that deregister after completion.
- Pod template considerations:
  - Base image `ghcr.io/actions/actions-runner:<version>`.
  - Init container to pre-load Kaniko cache (PVC).
  - Vault AppRole env vars injected from Kubernetes Secret for downstream credential fetch.
  - `runAsNonRoot`, read-only root filesystem, dropped capabilities.

### Provisioning Steps
1. Create namespace, NetworkPolicies, and GitHub App secret (`github_app_id`, `installation_id`, `private_key`).
2. Install ARC Helm chart with metrics enabled, 2 controller replicas, and shortened sync period (`1m`).
3. Define `RunnerDeployment` for each label set; scale baseline replicas (e.g., 2) and wire up HorizontalRunnerAutoscaler based on pending job count.
4. Configure Kaniko cache PVC and object storage bucket lifecycle (30-day retention).

### Execution Flow
1. Workflow with `runs-on: [self-hosted, k8s]` hits GitHub.
2. ARC receives webhook, creates runner pod.
3. Pod executes steps using job container or Kaniko; optionally pulls kubeconfig from Vault.
4. Completion triggers pod deletion and runner deregistration; logs shipped to central logging.

## Docker Runner Stack
- Containerized GitHub Actions runner managed via systemd or Nomad on a hardened host.
- Shared DinD sidecar (TLS-enabled) for Docker builds, nightly `docker system prune`.
- Cached toolchains kept under `runner-cache/` with cron cleanup.
- Use GitHub App tokens or short-lived PAT with scopes `repo`, `workflow`, `admin:repo_hook`.

## Argo CD Integration
| Capability | Approach |
| --- | --- |
| GitOps Repo | `infra/gitops` with environment folders or ApplicationSets. |
| Sync Targets | Workloads under `9_mediaCli`, `1_mdiaDb`, `0_mediaInfra`, auxiliary tooling. |
| Promotion Flow | GitHub Actions updates manifests (image tags, configs), opens PR, Argo CD syncs after merge. |
| Access Control | Argo CD RBAC maps Authentik groups (`dev`, `ops`, `platform`) to roles; CLI access via short-lived kubeconfigs minted through GitHub OIDC + `kubelogin`. |
| Progressive Delivery | Optional Argo Rollouts for canary/blue-green; integrate once traffic shaping required. |

## Security & Compliance
- GitHub App credentials stored in Vault; rotate private key quarterly and automate AppRole SecretID refresh weekly.
- Runners drop `NET_RAW`, run as non-root, use read-only root FS; NetworkPolicies limit egress to Vault, registries, GitHub endpoints.
- Prefer OIDC for cloud provider access; remove long-lived cloud keys from runners.
- Argo CD audit trail retained; GitHub PR history combined with Argo sync logs covers change tracking.
- Secrets in GitOps repo managed via ExternalSecrets or SOPS; avoid plain SealedSecret keys without rotation policy.

## Observability
- ARC metrics scraped by Prometheus (`github_runner_controller_*`, `github_runner_pending_jobs`).
- Host runners expose exporter (`github-runner-exporter`) for job counts and health.
- Dashboards:
  - Runner availability/queue length.
  - Job success/failure rates by label.
  - Argo CD sync status, drift, health degradations.
- Alerts:
  - Pending jobs > 5 for > 5 m.
  - Runner pod start failures (`runner_pod_error_total`).
  - Argo CD sync failures or app health `Degraded` for > 10 m.

## Operations
- **Scaling:** Adjust `replicas` or rely on HorizontalRunnerAutoscaler; ensure cluster autoscaler can add nodes in runner pools.
- **Upgrades:** Track GitHub runner releases; canary via `RunnerDeployment` clone (`k8s-canary`). Upgrade ARC chart quarterly.
- **Cache Hygiene:** Nightly prune of Kaniko cache bucket and DinD images; monitor PVC usage.
- **Disaster Recovery:** Store Helm values, RunnerDeployment manifests, and GitHub App config in Git; reapply manifests, restore secrets from Vault, and runners re-register automatically.
- **Incident Response:** On compromise, revoke GitHub App tokens, rotate secrets, redeploy ARC. For Kubernetes runner issues, cordon runner nodes and drain pending jobs.

## Roadmap & Open Questions
1. ApplicationSet-powered preview environments with automatic teardown.
2. Policy-as-code enforcement (OPA/Kyverno) in CI and Argo CD pipelines.
3. Expand runner fleets (ARM64, GPU) as workloads demand.
4. Determine long-term secret management pattern for GitOps (SOPS vs ExternalSecrets).
5. Decide whether Terraform infrastructure should also flow through Argo CD or remain in dedicated pipelines.

## References
- Observability platform blueprint (`03_telemetry/observability-platform.md`)
- Identity blueprint (`11_athentik_user/authentication.md`)
- Container image versioning & tagging (`00_coding_req/docker-image-versioning.md`)
- Argo CD docs: <https://argo-cd.readthedocs.io/>
