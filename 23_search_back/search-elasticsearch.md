# Search Platform (Elasticsearch)

## Purpose
Provide fast, relevance-ranked search over CMS content and media metadata while honoring localization, access control, and retention requirements. Elasticsearch augments the data plane defined in `ARCHITECTURE.md` and `DESIGN.md`, consuming events from Kafka (`20_central_bus/kafka-messaging-bus.md`) and metadata from PostgreSQL/PostgREST (`22_db_back/postgres-api-platform.md`).

## Platform Overview
| Component | Responsibility | Notes |
| --- | --- | --- |
| Elasticsearch Cluster | Stores indexed documents and serves queries | Three-node cluster per environment (Elastic Cloud or self-managed operator) with TLS and security features enabled. |
| Indexer Workers | React to CMS and MinIO events to build/update documents | Reads from Kafka topics (`media.asset_uploaded.v1`, `cms.article_published.v1`) and PostgREST endpoints. |
| Search API | Go service wrapping Elasticsearch queries, enforcing Authentik RBAC, locale fallback, and caching | Exposed via Consul API Gateway; aligns with presentation REST contracts (`51_Presentation_back/adr/0001-api-contract.md`). |
| Optional Dashboards | Kibana or OpenSearch Dashboards for operators | Restricted behind Authentik + Cloudflare Access. |

## Index Design
- **Indexes**: `content-<env>-v1`, `assets-<env>-v1`; aliases `content-<env>-current`, etc. Versioned indices allow zero-downtime reindex.
- **Document Schema**:
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
    "roles": ["cms-readers", "cms-admins"],
    "spaces": ["knowledge-base"],
    "attachments": [
      {
        "object_key": "cms/foo.pdf",
        "content_type": "application/pdf",
        "text": "extracted text"
      }
    ],
    "boost": 1.0
  }
  ```
- One document per locale; API handles fallback (preferred locale -> default). Attachments stored as nested objects; text extracted via Apache Tika or similar.
- Analyzers tuned per language (Persian, English). Use synonyms and stopwords where appropriate.
- Document expiration driven by CMS events; no PII stored beyond what presentation APIs expose.

## Indexer Workflow
1. Consume publish/update/unpublish events from Kafka.
2. Fetch latest metadata from PostgREST (with service role `api_service_indexer`).
3. Pull attachments from MinIO using signed URLs (limited TTL).
4. Extract text, build locale-specific documents, send `_bulk` requests.
5. On unpublish or takedown, delete documents or flag them as hidden.
6. Bulk rebuild command replays from CMS/PostgreSQL for DR or schema changes.

## Search API
- Endpoints:
  - `GET /search?q=...&locale=fa-IR&filters[tags]=sso&size=20`
  - `POST /search` for advanced queries (facets, search_after).
  - `GET /suggest?q=auth`
- Features:
  - BM25 scoring with optional boosting (`boost` field).
  - Highlight snippets, faceted navigation (tags, category, locale).
  - Autocomplete via completion suggester.
  - Pagination with `from/size` or cursor (`search_after`).
- Authorization:
  - API inspects Authentik headers (`x-auth-groups`, JWT) and applies `terms` filter on `roles`.
  - For paid tiers, evaluate Elasticsearch document-level security (requires appropriate licensing).
- Caching: Optional Redis cache keyed by query + groups; TTL tuned to seconds/minutes.

## Deployment
| Environment | Cluster | Notes |
| --- | --- | --- |
| Local | Single-node Docker Compose | Simplified auth; developer-focused. |
| Staging | Three-node Elasticsearch with security enabled | TLS, built-in users disabled; credentials via Vault. |
| Production | Three data nodes + dedicated masters if needed | Snapshots to MinIO/S3; autoscaling sized for query volume. |

Search API and indexers run in the `search` namespace. Consul API Gateway routes `/search/*`; mesh gateways handle cross-domain access per `01_conf_mgmt/mesh-gateway.md`.

## Security & Compliance
- TLS for cluster transport and HTTP. Certificates issued via cert-manager or Vault PKI.
- Authentication for indexer/API via Elasticsearch API keys scoped to specific index operations. Keys stored in Vault and rotated quarterly.
- Kibana access restricted via Authentik + Cloudflare Access.
- Attachment extraction uses signed URLs that expire within minutes. No permanent external credentials stored in indexers.
- Audit logs capture indexing actions and search queries; forward to Loki/SIEM for 180-day retention.
- Retention of search indexes aligns with data residency (EU). Snapshots stored in EU regions.

## Observability
- Metrics: cluster health (`elasticsearch_cluster_health_status`), heap usage, search latency, indexer throughput (`indexer_events_processed_total`), error counts.
- Dashboards: query volume, zero-result rate, top queries, indexer backlog, cluster resource usage.
- Alerts: cluster status red/yellow, heap or CPU > 80%, zero-result spike, indexer retries > threshold, snapshot failures.
- Tracing: Search API emits OTLP spans, including slow query annotations; correlate with presentation service traces.

## Backup & DR
- Daily snapshots to MinIO/S3 with 14-30 day retention. Automated verification ensures latest snapshot is restorable.
- DR procedure: restore snapshot to new cluster, update aliases, replay recent events if needed.
- Bulk rebuild command documented to reindex from CMS/PostgreSQL when snapshot unavailable.

## Roadmap
1. **Phase 1**: Deliver core search index and REST API with group-based filtering, dashboards, and snapshot automation.
2. **Phase 2**: Add attachment extraction, autocomplete, facets, and Kibana dashboards.
3. **Phase 3**: Introduce GraphQL endpoint, personalization signals (boosting by user history), and near real-time CDC triggers.
4. **Phase 4**: Explore cross-lingual search, learning-to-rank, and external-facing search portal if productized.

## References
- `ARCHITECTURE.md`, `DESIGN.md`, `SystemReqs.md`.
- `20_central_bus/kafka-messaging-bus.md` for event contracts feeding the indexer.
- `21_content_manager/minio-content-server.md` for asset storage workflows.
- `22_db_back/postgres-api-platform.md` for metadata sourcing.
- `03_telemetry/observability-platform.md` for monitoring integration.
