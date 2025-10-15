# Content Management Platform

## Mission
Deliver a headless CMS tailored to MyFarsi’s knowledge-base needs—workflow-heavy, localized content served through authenticated APIs behind Consul API Gateway. This platform must integrate seamlessly with Authentik SSO, publish on schedules, and expose structured APIs for consumers.

## Core Requirements
- Authoring with hierarchical taxonomy, tags, rich text, attachments, and related links.
- Editorial workflow (Draft → Review → Approved → Published → Archived) with notifications and SLA tracking.
- Localization per locale with configurable fallback order.
- Scheduled publish/unpublish windows (time-zone aware).
- Version history/diffs for compliance.
- Role-based access groups (author, editor, approver, publisher, viewer).
- Searchable delivery APIs (REST + future GraphQL) supporting metadata filters.
- Non-functional: Go 1.25 codebase, PostgreSQL primary store, Redis for jobs/cache, integrate with Observability stack, Kubernetes deployment in `content` namespace.

## Architecture
```
Editors ─► Consul API Gateway ─► Forward-Auth ─► CMS Admin API/UI ─► PostgreSQL
                                                 │                        │
                                                 │                        └► Redis (jobs/cache)
Consumers ─► Consul API Gateway ─► Forward-Auth ─► CMS Content API ─► CDN/cache (optional)

Supporting services: Authentik (SSO), MinIO/S3 for media, PostgreSQL full-text or Elasticsearch for search, Observability stack.
```
- Single Go service exposes admin and delivery APIs; SPA admin UI served from same binary.
- Background workers (Redis-backed queue) handle scheduling, search indexing, notifications.
- Publish/unpublish events raise Kafka messages for downstream consumers (search, personalization).

## Domain Model Highlights
| Entity | Description |
| --- | --- |
| `Space` | Logical tenant (e.g., `knowledge-base`), holds default locale and taxonomy rules. |
| `Article` | Canonical record with slug, status, scheduling window, ownership metadata. |
| `ArticleVersion` | Immutable snapshot per locale; stores title, body, attachments, SEO metadata. |
| `WorkflowState` | Tracks review state, assignee, due date, comments. |
| `Category` / `Tag` | Hierarchical taxonomy + many-to-many tagging for discovery. |
| `AuditLog` | Records state transitions, scheduling changes, permission updates. |

Localization fallback: e.g., `fa-IR` → `fa` → `en`. Delivery API accepts `Accept-Language` or explicit `locale`.

## Workflow & Scheduling
1. Draft created (auto-save, versioned).
2. Submit for review: assigns editor, sends notifications (email/Slack).
3. Approved: publisher schedules go-live/unpublish; validation ensures mandatory locales ready or flagged for fallback.
4. Scheduler job promotes content to `Published` at start, `Archived` or `Expired` at end.
5. Publishing triggers search indexing and cache invalidation events.

## API Strategy
- **Admin API**: Authentik-protected endpoints for CRUD, workflow transitions, localization tasks. GraphQL introspection disabled by default; rely on REST/JSON.
- **Content API**: Read-only, versioned endpoints (e.g., `/v1/articles/{slug}`) returning localized body plus metadata. Optional GraphQL view once schema stabilized.
- **Caching**: HTTP caching via gateway/CDN keyed by locale/version. Provide `ETag`/`Last-Modified`.
- **Search**: Start with PostgreSQL `tsvector`; shift to Elasticsearch/OpenSearch when traffic demands synonyms/highlighting.

## Storage & Infrastructure
- PostgreSQL with managed service in staging/prod; migrations via Atlas.
- Redis for job queue + caching (TTL-limited). Consider separate instances for background work vs. API caching.
- Media stored in MinIO/S3 with signed URL access; metadata stored in PostgreSQL.
- Helm chart under `charts/cms`; Argo CD deploys per environment. ExternalSecrets supply DB credentials, Redis URL, OAuth secrets.

## Security & Compliance
- Authentik forward-auth enforces login; trust headers `x-user`, `x-groups`.
- RBAC enforced at service level; group mapping maintained in configuration (`cms-authors`, `cms-editors`, etc.).
- CSRF protection for admin UI; SameSite cookies and anti-CSRF tokens.
- Audit trail retained 2 years; exportable for compliance.
- Rate limits and WAF policies configured at Consul API Gateway.
- Secrets stored in ExternalSecrets, rotated quarterly; background jobs use Vault-issued tokens for third-party integrations.

## Observability
- Metrics: publish count, pending approvals, job queue depth, API latency histograms.
- Logs: structured JSON with `trace_id`, `article_id`, sanitized payload.
- Traces: OpenTelemetry instrumentation around workflow transitions, DB queries, cache usage.
- Dashboards: editorial throughput, localization coverage, API success rate. Alerts on queue backlog, publish failures, 5xx spikes, SLA breaches (>48 h pending review).

## Operations
- CI builds Go binaries, packages container via multi-stage Dockerfile; run unit/integration tests on `self-hosted,k8s` runners.
- Migrations executed via Kubernetes Job Hook before deployment.
- Blue/green or canary rollout handled by Argo CD; ensure read-only replicas scale for Content API traffic.
- Backups: nightly PostgreSQL snapshot, object storage versioning for media. DR runbook restores DB, replays latest Kafka events if needed, validates API.
- Runbooks: emergency unpublish, workflow override, search reindex, translation backlog triage.

## Roadmap
1. **Phase 1**: MVP (core CRUD, workflow, scheduling start, REST delivery).
2. **Phase 2**: Unpublish scheduling, Slack/email notifications, search via Elasticsearch.
3. **Phase 3**: GraphQL delivery, translation tooling (import/export), analytics dashboard.
4. **Phase 4**: Multi-space tenancy, external contributor portal, experimentation (A/B), personalization hooks.

## Open Questions
- Background processing engine (internal queue vs. Temporal/CronJob).
- Preferred localization tooling (built-in vs external vendor integration).
- Governance for taxonomy updates (who owns categories/tags).
- Triggering search updates: push events vs. periodic reindex.

## References
- Identity blueprint (`designs/authentication.md`)
- Consul/API Gateway design (`designs/consul.md`)
- MinIO storage design (`designs/minio-content-server.md`)
- Search stack (`designs/search-elasticsearch.md`)
