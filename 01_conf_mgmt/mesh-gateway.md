# Mesh Gateway Design

## Purpose
Consul mesh gateways provide controlled L4/L7 connectivity between service namespaces/clusters while preserving zero-trust principles. They form the bridge between:
- `platform-config` (configuration management),
- `authn` (authentication stack),
- `media-core` (media business logic),
and any remote/home-edge environments. Gateways enable cross-datacenter service discovery, east-west traffic encryption, and ingress/egress policies without flattening networks.

## Goals
1. Allow services in one namespace to reach published services in another via Consul Connect with mTLS.
2. Support multi-cluster deployments (Kubernetes + VMs + home lab) with consistent routing.
3. Provide ingress and egress points for workload traffic (e.g., media services accessing external APIs).
4. Centralize observability and policy enforcement for cross-boundary traffic.

## Topology
```
platform-config cluster               authn cluster                    media-core cluster
┌───────────────────────┐             ┌─────────────────────────┐       ┌─────────────────────────┐
│ Consul servers + CA   │             │ Consul servers + CA     │       │ Consul servers + CA     │
│ Mesh Gateway (ing/eg) │◀──mTLS────▶ │ Mesh Gateway (ing/eg)   │ ◀────▶ │ Mesh Gateway (ing/eg)   │
│ Local workloads       │             │ Authentik/forward-auth  │       │ Ingestion/processing    │
└───────────────────────┘             └─────────────────────────┘       └─────────────────────────┘
           ▲                                    ▲                                 ▲
           │                                    │                                 │
      CI/CD runners                         API Gateway                    External clients (via gateway)
```

- Each cluster runs a pair of Consul mesh gateways (ingress + egress) alongside standard Consul agents.
- Consul federation (via WAN gossip or mesh gateway peering) allows exported services to be discovered across clusters.
- Traffic enters through Envoy proxies registered with mesh gateway service defaults and intentions.

## Service Export Model
| Domain | Exported Services | Consumers |
| --- | --- | --- |
| `platform-config` | Consul HTTPS API (limited), configuration KV via `config-cli`, Prometheus exporters | CI/CD runners, other clusters fetching config |
| `authn` | Authentik OIDC endpoints, forward-auth gRPC, JWKS | API Gateway, media services, observability stack |
| `media-core` | Logic Router, PostgREST, MinIO control API, Kafka (if external consumers) | API Gateway, content tooling, analytics |

Intention policy defines which service identities can access exported upstreams. Non-exported services remain isolated within their namespace.

## Deployment
- Mesh gateways deployed as Kubernetes `Deployment` (2 replicas) or VM systemd units, running Envoy with Consul Connect integration.
- Configuration stored as Consul `config_entries`:
  - `mesh-gateway` entry enabling federation and certificate rotation.
  - `service-defaults` specifying protocol (tcp/http).
  - `service-resolver` for routing customizations (failover).
  - `service-intentions` restricting access per service identity.
- For Kubernetes, Helm chart overlays (e.g., `hashicorp/consul` mesh gateway component) managed via Argo CD.
- TLS certificates issued via Consul CA; rotate automatically.

## Traffic Patterns
- **Namespace-to-Namespace**: e.g., Media service calls Authentik token introspection. Envoy sidecar dials local mesh gateway → remote gateway → Authentik service upstream.
- **CI/CD Access**: Runners in `platform-config` call remote Consul API through gateway for limited operations (list exported services).
- **Home Edge**: Edge cluster establishes outbound tunnel, registers mesh gateway, and consumes exported services without direct inbound connectivity.
- **Egress**: Media-core gateway routes traffic to approved external services (SaaS APIs) via egress gateways with allowlist.

## Observability
- Mesh gateway metrics scraped via Prometheus (Envoy stats).
- Access logs shipped to Loki with service identity, source, destination, TLS info.
- Distributed tracing: Envoy configured to propagate OpenTelemetry spans.
- Dashboards show connection counts, latency, error rates per upstream/downstream.

## Security Controls
- Service intentions enforce least privilege (e.g., only Logic Router identity can reach Authentik).
- ACL tokens for mesh gateways stored in Vault; tokens rotated automatically.
- NetworkPolicies restrict mesh gateway pods to required ports.
- External exposures managed via API Gateway; mesh gateways handle east-west only.
- Audit logs in Consul capture changes to config entries and intentions.

## Integration with GitOps
- Gateway config entries stored as YAML under `config_entries/mesh-gateway/`.
- PR review required for new exported services or intention changes.
- Automated tests validate config (e.g., `consul config validate`).
- Deployment orchestrated by Argo CD; gating ensures production changes follow staging verification.

## Failure Scenarios
| Scenario | Mitigation |
| --- | --- |
| Gateway pod crash | HPA ensures replica >1; readiness probe triggers restart. |
| TLS rotation failure | Monitor Consul Connect CA; fallback instructions to force rotate. |
| Federation link loss | Services fall back to cached connections; alert triggers investigation; use WAN gossip or alternative link. |
| Misconfigured intention | CI validation; runbook includes `consul intention check` before rollout; maintain emergency allowlist with TTL. |

## Roadmap
1. Implement automated service export approval (policy-as-code).
2. Add traffic mirroring tests between environments.
3. Evaluate cross-region compression/tuning for high-latency links.
4. Integrate egress allowlists with security scanning (e.g., deny unknown domains).
5. Expose mesh gateway status via platform status page.

## References
- Consul platform design: `designs/consul.md`
- Configuration management: `designs/config-management.md`
- Authentication platform: `designs/authentication.md`
- Media platform: `designs/media-platform.md`
- Observability: `designs/observability-platform.md`
