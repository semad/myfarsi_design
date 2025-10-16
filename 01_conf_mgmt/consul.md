# Consul Control Plane

## Role

Consul is the backbone of Layer 2 for configuration management, providing service discovery, health checking, KV configuration, and Consul Connect mesh features. Every domain runs its own Consul cluster paired with Vault, but the `platform-config` cluster is the canonical endpoint for CI/CD and shared tooling. This document complements `SystemReqs.md` and `ARCHITECTURE.md` by detailing deployment and operations expectations.

## Capabilities

- **Registry and Health**: Registers workloads, publishes health checks, and removes failed instances from discovery. Services are addressed via DNS (`service.namespace.consul`) or the HTTP API.
- **Key-Value Store**: Stores non-secret configuration consumed through `config-cli`. Keys follow `<env>/<service>/<key>` hierarchy. Secrets stay in Vault.
- **Connect Service Mesh**: Issues certificates, enforces intentions, and manages Envoy sidecars for east-west traffic. Mesh gateways extend connectivity across domains (`01_conf_mgmt/mesh-gateway.md`).
- **Gateway Coordination**: Drives API gateway, ingress, egress, and terminating gateways through Consul config entries.

## Deployment Topology

| Environment | Servers                                     | Notes                                                           |
| ----------- | ------------------------------------------- | --------------------------------------------------------------- |
| Local       | Single agent in dev mode via Docker Compose | Simplified for developers; no persistence.                      |
| Staging     | 3 server quorum on Kubernetes worker pool   | Gossip encryption enabled; WAN federation optional.             |
| Production  | 5 server quorum across availability zones   | Ready for federation with other clusters; paired mesh gateways. |

Agents run on every node (DaemonSet for Kubernetes, systemd for VMs). Servers use persistent NVMe or SSD storage. Gossip keys rotate quarterly, management tokens rotate monthly.

## Configuration Standards

- Managed as HCL under `configs/consul/` and exported via GitOps. `config-cli consul export --validate` must pass before merge.
- Required settings: `verify_incoming`, `verify_outgoing`, `verify_server_hostname`, `acl.enabled = true`, `primary_datacenter`, and scoped ACL tokens distributed through Vault.
- Namespaces map to product areas (`platform`, `media`, `authn`). Service defaults, routers, splitters, and intentions live in version-controlled config entries.
- API Gateway configuration (routes, JWT providers) managed via `service-router` and `service-splitter` entries to keep parity across environments.

## Operations

- **Bootstrap**: Initialize ACLs (`consul acl bootstrap`), capture management token in Vault, create initial policies and roles. Document process in runbook.
- **Upgrades**: Perform rolling upgrade one server at a time, verifying `serfHealth` and raft state before proceeding. Maintain compatibility matrix with Envoy version.
- **Backups**: Nightly `consul snapshot save` stored in MinIO (EU region per `22_db_back/adr/0001-data-retention.md`) with 35 day retention.
- **Disaster Recovery**: Restore Vault first, rotate management token, restore Consul snapshot, rejoin clients and mesh gateways, verify intentions.
- **Maintenance**: Rotate gossip TLS keys, prune stale services/KV keys, validate intentions against policy inventory, and run `consul validate` in CI for every configuration change.

## Observability

- Prometheus scrapes `/metrics` from servers and gateways. Dashboards include leader changes, raft latency, RPC error rate, Connect certificate issuance, and DNS query volume.
- Loki captures audit logs (ACL changes, intention updates). Alerts fire on quorum loss, raft apply latency spikes, high KV latency, Connect CA rotation failures, or Envoy sync stalls.
- `config-cli` emits OTLP spans tagged with `consul.datacenter` and `consul.service`; correlate with Consul metrics for troubleshooting.

## Security

- TLS enforced for all RPC, HTTP, and gossip channels. Certificates issued via Vault PKI tied to Consul Connect.
- ACL tokens scoped to service identity; injection handled through Vault Agent sidecars or AppRole exchange in CI. TTL <= 24 hours except for emergency break-glass tokens.
- NetworkPolicies and firewalls restrict Consul ports to trusted namespaces and VPN endpoints. WAN federation restricted to known peers.
- Audit changes to KV, intentions, and config entries. Run access reviews quarterly.

## Integrations

- **Vault**: Supplies certificates, stores management tokens, handles dynamic token issuance and third-party secret rotation (see `01_conf_mgmt/adr/0001-secret-rotation.md`).
- **Consul API Gateway**: Edge routing and forward-auth configuration stored as config entries; authentication stack documented in `11_athentik_user/authentication.md`.
- **CI/CD**: Runners use `config-cli` to query Consul KV; management tokens never leave Vault. Automation policy detailed in `02_cicd_mgmt/gitops-repository.md`.
- **Observability**: Telemetry forwarded to OpenTelemetry Collector; dashboards in `03_telemetry/observability-platform.md`.

## Roadmap

1. Enable Consul namespaces and partitions to segment multi-tenant workloads.
2. Automate drift detection between GitOps config entries and live state.
3. Adopt Consul 1.17 xDS improvements to manage advanced L7 policies.
4. Implement service intentions policy-as-code checks in CI.
5. Pilot Mesh Gateway federation with home-edge environments.
