# PostgreSQL and PostgREST Platform

## Purpose
PostgreSQL provides the authoritative relational store for the MyFarsi media platform. PostgREST exposes schema-controlled REST APIs that feed business services, processing pipelines, and presentation layers described in `ARCHITECTURE.md` and `DESIGN.md`. This document aligns storage and API practices with the requirements in `SystemReqs.md` and the retention policy captured in `22_db_back/adr/0001-data-retention.md`.

## Platform Overview
| Component | Responsibility | Notes |
| --- | --- | --- |
| PostgreSQL Cluster | Primary + read replicas per environment; hosts schemas for identity, content, analytics | Managed service or self-hosted on Equinix Metal; point-in-time recovery enabled. |
| PgBouncer | Connection pooling for PostgREST, processing services, and analytics jobs | Runs in the same namespace; enforces max connections to protect the database. |
| PostgREST | Stateless API layer mapping schemas/functions to HTTP resources | Deployed per schema in `data` namespace; integrates with Consul mesh and Authentik JWTs. |
| Migration Tooling | Atlas-based migrations kept in repo (see `1_mdiaDb/`) | CI validates drift and formatting before merge. |
| Optional GraphQL Gateway | PostGraphile pilot that reuses RLS and JWT policies | Enabled per schema when needed; sits behind API Gateway. |

## Data Model & Standards
- **Schemas**: one schema per bounded context (`identity`, `content`, `media`). Shared utilities live in `public`.
- **Roles**:
  - `api_anonymous`: disabled in production.
  - `api_user`: default for authenticated clients.
  - `api_editor`, `api_admin`: elevated privileges for CMS/editorial tooling.
  - `api_service_<name>`: service-to-service access tied to Authentik clients.
  - `postgrest`: execution role; never bypasses row level security (RLS).
- **Row Level Security**:
  ```sql
  ALTER TABLE content.articles ENABLE ROW LEVEL SECURITY;
  CREATE POLICY own_article ON content.articles
    USING (owner_id::text = current_setting('request.jwt.claim.sub', true));
  ```
  Policies rely on JWT claims supplied by Authentik/forward-auth. Every table exposed via PostgREST must have RLS enabled.
- **Functions and Views**: Expose complex operations via SQL functions (`SECURITY DEFINER` only when audited) and security-barrier views. RPC endpoints in PostgREST map to `content.publish_article(...)` style functions.
- **Retention**: Follow ADR guidance - primary data resides in EU region, snapshots retained 35 days, and weekly off-site copies stay within EU boundaries.

## PostgREST Configuration
- `db-uri`: PgBouncer DSN with TLS.
- `db-schemas`: schema(s) to expose.
- `db-anon-role`: set to `api_user` in production to force authenticated access.
- `jwt-secret` or `jwks-url`: uses Authentik JWKS; rotate quarterly.
- `role-claim-key`: `request.jwt.claim.role`; fallback to mapping table if claim absent.
- Pre-request function logs metadata (`request.jwt.claim.sub`, route) for auditing.
- Horizontal Pod Autoscaler scales instances based on CPU/QPS; connection pool sized to avoid exhausting PgBouncer limits.

### Authentication and Authorization Flow
1. Consul API Gateway authenticates via forward-auth; includes JWT and `x-auth-*` headers.
2. PostgREST validates JWT signature/audience using JWKS.
3. Role determined from JWT claim; RLS policies enforce per-tenant/per-user access.
4. Service tokens generated via Authentik client credentials map to dedicated roles (`api_service_cms`, `api_service_ingestor`).

### Performance & Limits
- Use PgBouncer transaction pooling for high QPS workloads.
- Enforce pagination and `max-rows` limits; require RPC endpoints for heavy aggregation.
- Add read replicas for analytics/reporting; restrict PostgREST to primary if writes required.
- Monitor `pg_stat_statements` to optimize slow queries; capture plans for regressions.

## Operations
- **Migrations**: `make migrate-validate` (Atlas) runs in CI; PRs require up/down scripts and drift checks.
- **Backups**: Automated nightly backups with PITR; monthly restore validation. Store snapshots in EU region per retention ADR.
- **Failover**: Documented runbooks for primary promotion, connection string updates, and PostgREST redeployments.
- **Secrets**: Database credentials managed by Vault; delivered via ExternalSecrets to PgBouncer/PostgREST. Rotate quarterly.
- **Maintenance**: Regular vacuum/analyze, index bloat checks, partitioning as dataset grows.

## Observability
- Export metrics via:
  - PostgreSQL exporter (connections, replication lag, slow queries).
  - PgBouncer exporter (pool usage).
  - PostgREST exporter (request counts, latency, errors).
- Log format: JSON with route, role, row count, latency. Forward to Loki for 35-day retention.
- Tracing: Envoy sidecars emit OTLP spans; include PostgREST annotations and slow query warnings.
- Alerts: high error rate (>5%), connection pool exhaustion, replication lag, failed backups, long-running transactions.

## Security
- TLS enforced end-to-end (API Gateway to PostgREST, PostgREST to PgBouncer/PostgreSQL).
- RBAC driven by Authentik; review roles quarterly.
- Audit triggers capture data changes to `audit.logged_actions`; forward to SIEM.
- Limit `SECURITY DEFINER` usage; require code review and automated tests.
- Remove unused roles and revoke privileges during access reviews.

## Roadmap
1. **Phase 1**: Deliver PostgREST endpoints for `identity` and `content` schemas with full RLS, dashboards, and backup validation.
2. **Phase 2**: Introduce PgBouncer, connection pooling metrics, and automatic query plan analysis. Pilot PostGraphile for targeted use cases.
3. **Phase 3**: Implement CDC feeds (Logical Replication) feeding analytics or search pipelines; automate data masking for PII exports.
4. **Phase 4**: Enable federated GraphQL if justified, add SLO monitoring with synthetic probes, and integrate cost-based optimization hints.

## References
- `ARCHITECTURE.md`, `DESIGN.md`, `SystemReqs.md` for platform context.
- `22_db_back/adr/0001-data-retention.md` for retention/residency requirements.
- `01_conf_mgmt/config-management.md` for configuration delivery via config-cli.
- `51_Presentation_back/adr/0001-api-contract.md` for downstream API expectations.
- `03_telemetry/observability-platform.md` for monitoring guidance.
