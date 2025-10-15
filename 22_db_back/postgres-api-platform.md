# PostgreSQL & PostgREST Platform

## Objective
Expose relational data via secure, consistent APIs while keeping SQL as the source of truth. PostgREST converts database schemas, views, and functions into REST endpoints; optional GraphQL gateways may layer on top once policies prove out.

## Architecture
```
Clients → Consul API Gateway → Forward-Auth → PostgREST / GraphQL Gateway → PostgreSQL
                                                   │
                                                   ├─ PgBouncer (pooling)
                                                   └─ Observability exporters
```
- Managed PostgreSQL (with read replicas) hosts schemas per bounded context (`identity`, `content`, `analytics`).
- PostgREST instances align with schema boundaries and run statelessly in Kubernetes (`data` namespace).
- Authentik issues JWTs; forward-auth injects headers and bearer tokens; PostgREST enforces row-level security (RLS) via claims.
- Optionally, PostGraphile or Hasura can expose GraphQL endpoints using the same policies.

## Database Standards
- **Schemas**: one per domain. Shared utilities in `public`.
- **Roles**:
  - `api_anonymous`: minimal read; disabled in prod by default.
  - `api_user`: default for authenticated front-end users.
  - `api_editor`, `api_admin`: elevated roles.
  - `api_service_<name>`: machine-to-machine access.
  - `postgrest`: execution role; never bypasses RLS.
- **Row-Level Security**: enabled on all exposed tables. Policies inspect JWT claims via `current_setting('request.jwt.claims', true)::json`.
- **Functions/Views**: Expose complex logic as SQL functions (`SECURITY DEFINER` with caution) and views flagged `security_barrier`. Use `rpc` routes for procedures.
- **Migrations**: Atlas-based workflow under `1_mdiaDb`; CI enforces formatting, drift detection, and migration validation.

## PostgREST Configuration
- `db-uri`: points to PgBouncer DSN (preferred) or direct DB connection.
- `db-schemas`: schema(s) to expose.
- `db-anon-role`: typically `api_anonymous`; in prod set to `api_user` to force auth.
- `jwt-secret` or `jwt-aud` + `jwks-url`: integrate with Authentik signing keys.
- `db-pre-request`: optional PL/pgSQL hook for auditing.
- `role-claim-key`: map `role` claim from JWT; fallback to groups mapping table.
- Horizontal Pod Autoscaler scales based on CPU/QPS; connection pool sized to avoid DB saturation.

### Authentication & Authorization
1. Forward-auth validates session, forwards JWT and headers (`x-auth-user`, `x-auth-groups`).
2. PostgREST verifies JWT signature/audience, sets `role` per claim (`request.jwt.claim.role`).
3. RLS policies enforce per-user filters:
   ```sql
   CREATE POLICY own_records ON identity.accounts
   USING (id::text = current_setting('request.jwt.claim.sub', true));
   ```
4. Service tokens use Authentik client credentials with custom roles (`api_service_cms`).

### Rate Limiting & Budgets
- API Gateway applies coarse rate limits; PostgREST enforces `max-rows`, `response-headers` (e.g., `Content-Range`).
- For heavy queries, expose dedicated RPC endpoints guarded by roles.

## GraphQL Option
- Pilot PostGraphile for `identity` schema:
  - Shares RLS policies and Authentik JWTs.
  - Deploy as separate service `/graphql/identity`.
  - Instrument with Prometheus plugin and tracing.
- Evaluate expansion after pilot (DX, performance, governance).

## Observability
- Export metrics via `postgrest_exporter` (requests, latency, status codes) and PgBouncer/PostgreSQL exporters.
- Logs: JSON with route, role, row count. Forward to Loki.
- Tracing: instrument PostgREST via OpenTelemetry middleware or Envoy tracing; include SQL duration using pg_stat_statements.
- Dashboards: request volume, latency percentiles, row count per route, DB connection usage, slow queries.
- Alerts: high error rate, DB connections > threshold, long transaction duration, RLS policy failures.

## Security
- TLS termination at API Gateway; PostgreSQL connection uses TLS (require client cert or scram-sha-256).
- Secrets via ExternalSecrets referencing Vault (DB creds, JWT secrets).
- Rotate JWT signing keys quarterly; update JWKS URL; rolling restart PostgREST.
- Audit triggers log data changes to `audit.log` table; export to SIEM.
- Database backups nightly with PITR; verify restore monthly.

## Deployment
- Helm chart `charts/postgrest-api` includes Deployment, Service, ConfigMap, PodDisruptionBudget, and PodSecurityContext (non-root).
- GitOps overlays (`apps/postgrest/<schema>/overlays/{staging,prod}`) manage config differences.
- CI pipeline:
  1. Run migrations (`make migrate-validate`).
  2. Execute unit/integration tests targeting ephemeral Postgres.
  3. Build container image, push to registry.
  4. Update GitOps repo with new tag.

## Roadmap
1. Phase 1: Deploy `identity` and `content` APIs via PostgREST; enforce JWT/RLS; baseline dashboards.
2. Phase 2: Introduce PgBouncer, caching headers, schema diff checks; pilot PostGraphile.
3. Phase 3: Multi-tenant support (tenant column in policies), CDC pipeline for analytics, automated query plan insights.
4. Phase 4: Federated GraphQL if adoption justifies; data masking policies; SLO monitoring & synthetic checks.

## References
- Identity blueprint (`designs/authentication.md`)
- Content platform (`designs/content-management.md`)
- Observability (`designs/observability-platform.md`)
- Database repo (`1_mdiaDb/`)
