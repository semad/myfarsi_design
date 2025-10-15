# ADR 0001: Third-Party Secret Rotation

## Status
Accepted

## Context
Several ingestion workflows (e.g., Telegram polling) rely on third-party API credentials. Earlier documents deferred how these secrets would be rotated and audited, increasing the risk of credential leaks or drift between environments.

## Decision
Manage third-party API credentials through Vault static secrets wrapped by short-lived AppRole tokens. Rotation is automated via Vault's periodic secret engines (where supported) or scheduled pipelines that call provider APIs and update Vault entries.

Implementation details:
- Store secrets under `kv/v1/third-party/<service>/<env>`; access gated by Consul service identity and Vault policies.
- For providers with API-driven rotation (Telegram bots, OAuth tokens), run a scheduled job (Argo Workflow) that issues new credentials, updates Vault, and triggers downstream services to reload via Consul watch hooks.
- For providers without automation, require manual rotation every 90 days with approval workflow tracked in GitOps repository.
- All secret access and rotation events logged via Vault audit devices and forwarded to the observability stack.

## Consequences
- Services must support dynamic reload of credentials (via config-cli or hot-reload endpoints).
- CI/CD pipelines need helper tasks to fetch AppRole tokens securely using per-environment credentials.
- Incident runbooks must include procedures for forced secret revocation and redeployment.
- Future integrations should prefer providers with API-driven rotation to minimize manual effort.
