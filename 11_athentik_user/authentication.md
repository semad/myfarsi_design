# Authentik Identity Platform

## Purpose & Mandate
Consolidate how MyFarsi authenticates human users and API clients via Authentik so infra, security, and product teams implement a consistent SSO posture. This rewrite replaces prior hybrid-identity notes, forward-auth specs, and platform runbooks with a single source of truth.

## Scope
- Offer resilient login experiences (native + social) for browser and programmatic clients.
- Enforce authentication at the Consul API Gateway edge through an external authorization service.
- Keep boundaries clear between user identity (Authentik), service identity (Vault/Consul Connect), and fine-grained authorization engines (OPA, app-level RBAC).
- Surface operations, observability, recovery, and roadmap expectations.
- Operates in the dedicated `authn` namespace/cluster with its own Consul + Vault pair; only published OIDC/forward-auth endpoints are shared with other stacks.

Out of scope: mTLS between services, device-posture enforcement, Vault-managed secrets for Authentik (still delivered via ExternalSecrets).

## Platform Topology
```
User / API Client
   │
   ▼
Consul API Gateway (Envoy)
   │  ext_authz (gRPC)
   ▼
Forward-Auth Service ──► Redis (sessions)
       │
       ├─► Authentik Core ─► PostgreSQL (managed)
       │                   └► Redis (queue/session)
       └─► JWKS cache / telemetry exporters
```
- Gateway delegates authentication decisions to the forward-auth service.
- Forward-auth exchanges OIDC tokens with Authentik, maintains a short-lived session cache, and returns trusted headers to Envoy.
- Downstream apps consume headers rather than integrating Authentik directly.

## Component Responsibilities
| Component | Summary |
| --- | --- |
| Authentik Core | Django-based identity provider hosting providers, policies, admin UI, and async workers. |
| Forward-Auth | Implements Envoy `ext_authz`; handles redirects, token validation, session storage, and header injection. |
| Consul API Gateway | Edge ingress enforcing external auth before routing to internal services. |
| Persistence | Managed PostgreSQL for configuration/state; Redis clusters for Authentik queue + session cache and forward-auth cache. |
| Secrets | ExternalSecrets/Kubernetes Secrets storing OAuth credentials, signing keys, SMTP, webhook secrets. |
| Observability | Prometheus, Loki, Tempo fed via OpenTelemetry exporters from Authentik and forward-auth. |

## Deployment Model
- Namespace: `auth`.
- Delivery: official Authentik Helm chart templated with `config-cli render authentik` (see `90_cli_tools/config-cli.md` for templating workflow).
- Pods:
  - `ak-server` (web/API) with horizontal pod autoscaler.
  - `ak-worker` for background jobs.
  - Optional bundled Redis for non-prod; production uses managed Redis.
- External backing services:
  - Managed PostgreSQL (PITR enabled, TLS required).
  - Managed Redis for Authentik; distinct Redis for forward-auth sessions (TLS + AUTH).
- Ingress:
  - Consul API Gateway terminates TLS for `auth.<env>.myfarsi.dev`.
  - Callback route from Authentik bypasses forward-auth to avoid loops.
- Configuration:
  - Non-secret defaults pulled from Consul KV (`authentik/<env>/`).
  - Secrets delivered by ExternalSecrets referencing cloud KMS.
- Backups:
  - PostgreSQL snapshots + pgBackRest logical dumps.
  - Weekly `ak backup` export stored encrypted in version control.

## Identity Providers & Account Strategy
| Provider | Audience | Notes |
| --- | --- | --- |
| Authentik Native | Platform admins, internal staff, limited beta users. Enforce Web/MFA policies per group. |
| Google OIDC | External or Workspace users; optionally restrict to specific domains. |
| Facebook OAuth | Consumer cohorts; ensure App Review coverage and privacy notices. |
| GitHub OAuth | Engineering and partner developers; map org/team to Authentik groups. |
| Future Enterprise IdP | Reserved for hybrid identity rollout (SAML/OIDC). |

Account personas:
- **Administrators**: Manage platform; strong MFA, short tokens.
- **Employees**: Access internal tools; group-based RBAC `employees`, `cms-editor`, etc.
- **Consumers**: Access front-end features; coarse-grained groups.
- **Service Accounts**: Machine clients with JWT credentials used by PostgREST, Grafana, etc.

## Access Policies & Session Flow
1. Gateway receives request and forwards to forward-auth `ext_authz`.
2. Forward-auth validates session cookie or bearer token; if absent/invalid it crafts an Authentik redirect.
3. Authentik completes OIDC flow, issues tokens, and sets session cookie scoped to forward-auth domain.
4. Forward-auth caches decision metadata in Redis, then injects headers (`x-auth-user`, `x-groups`, `Authorization: Bearer <jwt>`) before allowing the request.
5. Downstream services trust headers; PostgREST, Grafana, MinIO map groups to authorization logic.

Headers and cookies follow the `auth.<env>.myfarsi.dev` domain standard; TTLs align with OAuth client defaults (60 m access, 7 d refresh) unless the app requires shorter windows.

## Security & Compliance
- Mandate TLS (mTLS inside mesh) for all hops.
- Rotate signing keys and session secrets quarterly; store metadata in secret manager with rotation runbook.
- Enforce rate limiting and CAPTCHA on public login forms via Authentik policies.
- Audit logging: capture login success/failure, consent changes, policy denies, admin actions; ship to centralized logging with retention aligned to compliance requirements.
- Redis instances isolated by VPC/security groups; enable NetworkPolicies in Kubernetes for forward-auth pods.
- Document emergency procedures for revoking compromised tokens and disabling external IdPs.

## Observability
- **Metrics**: login success/failure counts, token issuance latency, worker queue depth, forward-auth decision counts/latency, Redis cache miss rate.
- **Logs**: structured JSON with correlation IDs (`x-request-id`). Forward-auth logs include policy outcomes and redirect reasons.
- **Traces**: instrument Authentik (Django) and forward-auth via OpenTelemetry; propagate W3C trace context headers through the gateway.
- **Dashboards/Alerts**:
  - p95 forward-auth latency > 300 ms for 5 m (page SRE).
  - Login failure ratio > 10% for 10 m (warn support + security).
  - Redis connection pool saturation or eviction rate > 5% (investigate).
  - Signing key expiry < 14 d (rotate).

## Operations Runbook
- **Deploy/Upgrade**: `make deploy-authentik ENV=<env>` triggers Helm upgrade; forward-auth uses kustomize overlay with canary capability via Consul subsets.
- **Probes**: `/healthz` endpoint on forward-auth used for Kubernetes and gateway checks; failing health triggers circuit break at the edge.
- **User Lifecycle**: native accounts managed via Authentik admin or API; social-to-native linking documented to prevent duplicate identities.
- **Integration Checklist** (per downstream service):
  - Register OIDC client in Authentik.
  - Create required groups and policies.
  - Update forward-auth mapping to emit new headers.
  - Validate route in staging before production cutover.
- **Incident Response**:
  - Redeploy forward-auth to flush session cache on suspected compromise.
  - Use Authentik admin to revoke tokens or disable providers.
  - Notify stakeholders and confirm dashboards recover to baseline.

## Backup & Disaster Recovery
1. Restore PostgreSQL from latest PITR snapshot.
2. Rehydrate Authentik via Helm with restored database; rotate secrets if compromise suspected.
3. Re-deploy forward-auth and purge stale Redis sessions.
4. Validate login → token issuance → header propagation before re-opening traffic.

## Roadmap
- Hybrid identity: connect enterprise IdP, enable SCIM provisioning, adopt outposts for legacy apps.
- Automated key rotation pipeline for forward-auth session secrets.
- Evaluate passkey/WebAuthn support once Authentik surfaces `amr` claims consistently.
- Expand social login coverage (Apple, Twitter) upon product sign-off.

## References
- ADR 002 (`11_athentik_user/adr/002-authentik-subsystem-decisions.md`)
- Forward-auth integration guide (`0_mediaInfra/00_consul_mesh/envoy/README.md`)
- Authentik documentation: <https://docs.goauthentik.io/>
