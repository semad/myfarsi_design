# Consul Control Plane

## Role
Consul anchors Layer 2 of the platform by delivering service discovery, runtime configuration, and the control plane for Consul Connect service mesh. Every workload relies on it for naming, health, and secure communication. Each major service domain (configuration management, authentication, media business logic) runs its own Consul cluster alongside a paired Vault instance; the configuration management cluster is also the canonical Consul endpoint consumed by CI/CD pipelines.

## Capabilities
- **Service Registry & Health Checks**: Agents register services, provide script/HTTP/TCP checks, and remove failing instances from discovery.
- **DNS & HTTP Discovery**: Consumers resolve `service.namespace.consul` or call the HTTP API for richer metadata.
- **KV Store**: Hierarchical key space for non-secret configuration (feature flags, tuning params, UI branding). Secrets remain in Vault.
- **Connect (mTLS Mesh)**: Issues and rotates service certificates, distributes intentions (access policies), and programs sidecar proxies.
- **Gateway Management**: Drives mesh gateways (ingress/egress/API Gateway) used for cross-cluster traffic and edge exposure.

## Deployment Model
| Environment | Topology | Notes |
| --- | --- | --- |
| Local | Single agent in `docker-compose`. `-dev` mode, no persistence. | Simplified for developer workflows. |
| Staging | 3-server cluster (bootstrap expect 3) across availability zones; dedicated clients on worker nodes. | Gossip encryption enabled; WAN federation optional. |
| Production | 5-server quorum for resilience; federation ready for DR region; dedicated mesh gateways. | Servers run on managed instances with persistent storage. |

Agents run on every node (Kubernetes via DaemonSet, VMs via systemd). Server agents store state on disks (NVMe or SSD). Gossip encryption keys rotated quarterly.

## Configuration Standards
- Configuration in HCL under `0_mediaInfra/00_consul_mesh/` with environment overlays rendered by `config-cli` (see `designs/config-cli.md` for bootstrap patterns).
- Key settings: `verify_incoming`, `verify_outgoing`, `verify_server_hostname` (TLS on), `datacenter`, `primary_datacenter`, `acl.enabled=true`, `acl.tokens` distributed via Vault.
- Namespaces map to product areas (`platform`, `media`, `infra`). Service defaults (splits, timeouts) stored in `config_entries`.
- API Gateway and service routers defined as `config_entries` so they version-control cleanly.

## Operations & Runbooks
- **Bootstrapping**: Initialize ACL system (`consul acl bootstrap`), store management token in Vault, issue scoped tokens per service.
- **Upgrades**: Rolling upgrade servers one at a time, wait for `serfHealth=passing` before advancing. Maintain compatibility matrix with Envoy.
- **Backups**: Nightly `consul snapshot save` for servers; store in encrypted object storage with 30 day retention.
- **Disaster Recovery**: Restore snapshot, redeploy servers, rejoin clients via gossip. Update DNS/load balancer endpoints.
- **Routine Tasks**: Rotate gossip/TLS keys, prune stale services and KV paths, validate intentions vs policy inventory, run `consul validate` in CI.

## Observability
- Prometheus scrapes server `/metrics`; dashboards track leader elections, RPC latency, client sessions, intention denies.
- Loki captures audit logs (ACL create/delete, intention changes).
- Alerts: loss of quorum, raft apply latency, high KV latency, connect CA rotation failures, envoy sync stalled.

## Security
- TLS everywhere using Vault-issued certificates; Connect CA managed via Consul + Vault integration.
- ACL tokens scoped per workload; tokens injected through Vault Agent or Kubernetes secrets with short TTL.
- NetworkPolicies restrict agent ports; firewall limits WAN gossip to trusted peers.
- Audit changes to KV, intentions, config entries (Consul audit log + centralized logging).

## Integration Points
- **Vault**: Provides PKI for Connect, stores bootstrap/management tokens, issues scoped tokens dynamically.
- **Consul API Gateway**: External auth via forward-auth (see `designs/authentication.md`); gateway configs stored as config entries.
- **Telemetry**: Agents emit telemetry to the OpenTelemetry Collector for correlation with service metrics.

## Roadmap
1. Implement namespace-based ACL defaults to simplify token issuance.
2. Introduce Mesh Gateways for cross-region service discovery.
3. Automate KV drift detection using GitOps reconciliation.
4. Evaluate Envoy xDS via Consul 1.17+ features for richer L7 traffic policies.
