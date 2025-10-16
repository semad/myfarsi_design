# Mesh Gateway Design

## Purpose

Consul mesh gateways bridge trust boundaries between the configuration backbone, authentication stack, media services, and remote clusters without collapsing networks into a flat topology. They provide encrypted east-west connectivity, controlled service export/import, and a consistent policy surface for cross-domain traffic.

## Scope

- Domains: `platform-config`, `authn`, `media-core`, and approved edge deployments.
- Traffic types: service-to-service (mTLS via Connect), limited Consul API access, and outbound egress to sanctioned third parties.
- This document works alongside `01_conf_mgmt/consul.md`, `11_athentik_user/authentication.md`, and `51_Presentation_back/adr/0001-api-contract.md`.

## Topology

```text
platform-config cluster          authn cluster                 media-core cluster
+-------------------------+      +-------------------------+   +-------------------------+
| Consul servers + CA     |      | Consul servers + CA     |   | Consul servers + CA     |
| Mesh Gateway (ing/eg)   |<---->| Mesh Gateway (ing/eg)   |<->| Mesh Gateway (ing/eg)   |
| Control workloads       |      | Authentik/forward-auth  |   | Ingestion/processing    |
+-------------------------+      +-------------------------+   +-------------------------+
```

Each cluster runs at least two gateway replicas (ingress and egress) managed by Consul. Federation occurs through mesh gateways rather than direct WAN gossip wherever possible.

## Service Export Model

| Exporting Domain | Upstreams                                                                            | Consumers                                                    |
| ---------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| platform-config  | Consul HTTPS API (read-only), configuration KV (via config-cli), telemetry exporters | CI/CD runners, downstream clusters during bootstrap          |
| authn            | Authentik OIDC, forward-auth gRPC, JWKS endpoints                                    | API Gateway, media services, presentation backends           |
| media-core       | Logic Router, PostgREST, MinIO control plane, Kafka brokers (selected topics)        | Presentation backends, analytics, approved external partners |

Export lists live in Consul config entries and must pass review by both exporting and consuming domain owners.

## Deployment

- Kubernetes deployments managed by the Consul Helm chart (mesh gateway component) with two replicas per environment. VM deployments use systemd units with the same Envoy binary.
- Configuration stored as version-controlled config entries: `mesh-gateway`, `service-defaults`, `service-resolver`, and `service-intentions`.
- TLS certificates issued via Consul Connect CA (backed by Vault). Rotation is automatic; alerts fire if rotation fails.
- Gateways expose metrics on `:9102` and logs on stdout. NetworkPolicies restrict inbound traffic to Consul servers and approved namespaces.

## Traffic Patterns

- **Namespace to Namespace**: Media services reach Authentik by dialing local Envoy sidecar -> local gateway -> remote gateway -> Authentik upstream. Intentions allow only required identities.
- **CI/CD Bootstrap**: Runners in `platform-config` fetch configuration from remote clusters through gateways, using scoped tokens from Vault.
- **Edge Sites**: Home-edge clusters establish outbound gateway connections; they can consume exported services without opening inbound ports.
- **Egress**: Dedicated egress gateways enforce domain allowlists for third-party APIs (e.g., Telegram). Policies are stored alongside other config entries.

## Observability

- Prometheus scrapes Envoy stats (connection counts, latency, TLS errors). Dashboards live under `03_telemetry/observability-platform.md`.
- Access logs route to Loki with fields for source service, destination service, SNI, and intention decision.
- Envoy tracing configured to emit OTLP spans, enabling end-to-end tracing across domains.
- Alerts monitor gateway availability, connection saturation, failed intentions, and handshake failures.

## Security Controls

- Service intentions implement least privilege; emergency allowlists carry TTL and require follow-up ADRs.
- ACL tokens for gateways are managed by Vault and rotated automatically (`01_conf_mgmt/adr/0001-secret-rotation.md`).
- Sidecars and gateways enforce strict TLS; only approved cipher suites allowed.
- API Gateway continues to handle north-south traffic; mesh gateways are restricted to east-west and egress.
- Config entry changes require PR review and automated validation (`consul config validate`) before deployment.

## Failure Handling

| Scenario                | Response                                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| Gateway pod crash       | Kubernetes restarts pod; second replica maintains connectivity. Alert on replica count.                       |
| Federation link loss    | Services rely on cached connections; on-call investigates network tunnels and Consul federation status.       |
| TLS rotation failure    | Trigger manual rotation procedure; reference runbook in `docs/platform-config/mesh-gateway-runbook.md` (TBD). |
| Misconfigured intention | Roll back via GitOps, apply temporary allowlist if needed, and document postmortem.                           |

## Roadmap

1. Automate policy-as-code reviews for exported service lists.
2. Add traffic mirroring between staging and production for regression testing.
3. Evaluate compression and circuit breaking for high-latency federated links.
4. Integrate egress policies with security scanners to detect unexpected destinations.
5. Surface mesh gateway status on the platform status dashboard consumed by operations.

## References

- `01_conf_mgmt/consul.md` for Consul deployment standards.
- `01_conf_mgmt/config-management.md` and `SystemReqs.md` for platform requirements.
- `20_central_bus/kafka-messaging-bus.md` and `22_db_back/adr/0001-data-retention.md` for downstream integrations.
- `03_telemetry/observability-platform.md` for monitoring configuration.
