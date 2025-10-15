# ADR 002: Authentik Subsystem Clarifications

## Status
Accepted

## Context
The Authentik design identified uncertainties around hybrid identity scope, SaaS integrations, secret ownership, and branding automation. Resolving these questions clears the path for infrastructure tickets.

## Decision
1. **Hybrid Identity**  
   Active Directory or other on-prem bridges are out of scope for GA. Authentik manages users plus optional OAuth/OIDC federation (Google, GitHub). Revisit hybrid connectors post-GA if operations demands surface.

2. **SaaS Integrations**  
   Launch supports core internal apps (Grafana, MinIO Console, CMS admin) via OIDC. SCIM provisioning and bespoke SAML connectors are deferred until at least two high-priority SaaS targets are requested.

3. **Secret Management Boundary**  
   Vault remains focused on service-to-service auth. Authentik stores its secrets via Kubernetes ExternalSecrets or cloud secret manager; no Vault integration required initially.

4. **Branding Automation**  
   Branding stays environment-scoped. `config-cli render authentik` templates themes from Consul KV (`authentik/<env>/branding/*`). Tenant-specific branding automation is future work.

## Consequences
- Implementation can proceed without AD dependencies, shortening lead time.
- SaaS connectors enter the roadmap only with demonstrated demand.
- Authentik avoid coupling to Vault, simplifying deployments.
- Operators maintain simple Consul-driven branding overrides; multi-tenant needs will trigger new ADR.

## Follow-Up
- Update `designsV2/authentication.md` to reference this ADR and remove open questions.
- Create backlog items for post-GA evaluations (hybrid identity, SCIM/SAML connectors).
- Extend `config-cli` templates to include branding variables.
