# Search Platform (Elasticsearch)

## Purpose
Provide fast, relevance-ranked search across content authored in the CMS and assets stored in MinIO. Search results honor localization and Authentik-based permissions while exposing REST (and future GraphQL) APIs behind the Logic Router.

## Architecture
```
CMS / PostgreSQL ─┐
                  ├─► Indexer Workers ─► Elasticsearch Cluster ─► Search API ─► Consul API Gateway ─► Clients
MinIO (assets) ───┘
```
- Indexer reacts to CMS publish/unpublish events (Kafka topic or polling) to sync documents.
- Apache Tika (or similar) extracts text from attachments; cached to avoid reprocessing.
- Search API (Go) wraps Elasticsearch queries, enforces RBAC, localization fallback, facets, and suggestions.
- Kibana/OpenSearch Dashboards optional for operators.

## Index Design
- Index name pattern: `kb-content-<env>-v1`; alias `kb-content-<env>-current`.
- Document fields:
  ```json
  {
    "id": "article-uuid#locale",
    "article_id": "uuid",
    "locale": "fa-IR",
    "title": "string",
    "summary": "string",
    "body": "string",
    "tags": ["auth", "sso"],
    "category": "string",
    "published_at": "datetime",
    "attachments": [
      {"object_key": "cms/foo.pdf", "content_type": "application/pdf", "text": "extracted text"}
    ],
    "roles": ["cms-readers", "cms-admins"],
    "spaces": ["knowledge-base"],
    "boost": 1.0
  }
  ```
- Nested mapping for attachments; analyzers tuned per locale (Persian, English).
- Localization: one document per locale. Query fallback implemented in API (preferred locale → default).
- Reindexing via versioned indices; use `_reindex` to migrate, then switch alias.

## Indexer Workflow
1. Receive event (`article_published`, `article_updated`, `article_unpublished`).
2. Fetch latest article version + metadata from PostgreSQL.
3. Pull attachments from MinIO using signed URL; extract text.
4. Build document(s) per locale; send `_bulk` request to Elasticsearch.
5. On unpublish, delete document or set flag to exclude from results.

Bulk rebuild command reads from CMS database and repopulates index; used for DR or schema changes.

## Search API
- Endpoints:
  - `GET /search?q=...&locale=fa-IR&filters[tags]=sso&size=20`
  - `GET /suggest?q=auth`
  - `POST /search` for advanced queries.
- Features: BM25 scoring, highlight snippets, facets (tags, category, locale), autocomplete (completion suggester), pagination with `from/size` or search_after.
- Authorization: API inspects Authentik groups from forward-auth headers; applies `terms` filter on `roles`. Future enhancement: leverage Elasticsearch document-level security if licensing permits.
- Caching: optional Redis-backed short-term cache keyed by query + groups.
- Observability: metrics for query latency, hit count, zero-result rate; logs include hashed user ID, query, filters (PII-safe).

## Deployment
| Environment | Elasticsearch | Notes |
| --- | --- | --- |
| Local | Single-node via `docker-compose.search.yml` | Include Kibana optional; simplified auth. |
| Staging | 3-node cluster (Elastic Cloud or self-managed Operator) | TLS and security features enabled. |
| Production | 3+ data nodes, dedicated masters if self-managed; snapshots enabled | Sizing depends on content volume & query load. |

Search API & Indexer run in `search` namespace; GitOps overlays manage per-env configuration. Consul API Gateway routes `/search/*` to API; Kibana behind Cloudflare Access.

## Security
- TLS-in-transit; certificates from cert-manager/Vault. API authenticates using Elasticsearch API key with scoped privileges.
- Control plane (Kibana) gated by Authentik + Cloudflare Access.
- Signed URLs for attachment ingestion expire quickly; only indexer service account can access extraction bucket.
- Audit logs for indexing actions and search queries retained in Loki/SIEM.

## Observability
- Metrics: Elasticsearch cluster health, heap usage, query latency; indexer throughput/error counters; API latency/error rate.
- Dashboards: search traffic, zero-result rate, top queries, indexer backlog.
- Alerts: cluster status `red`, CPU/heap >80%, zero-result spike, indexer retries > threshold.

## Backup & DR
- Daily snapshots to S3-compatible storage; retention 14–30 d.
- DR procedure: deploy new cluster, restore snapshot, repoint alias; optionally replay from CMS to ensure freshness.
- Indexer can rebuild entire index from CMS metadata if snapshots unavailable.

## Roadmap
1. Phase 1: MVP index (articles only), REST API, group-based filtering, basic dashboards.
2. Phase 2: Attachment extraction, autocomplete, facets, Kibana dashboards.
3. Phase 3: GraphQL endpoint, personalization signals (boost by user history), CDC-driven near real-time updates.
4. Phase 4: Cross-lingual search, learning-to-rank, external search portal (if productized).

## References
- Content platform (`designs/content-management.md`)
- MinIO content server (`designs/minio-content-server.md`)
- Identity (`designs/authentication.md`)
- Observability (`designs/observability-platform.md`)
