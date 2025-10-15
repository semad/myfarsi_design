# Media Business Logic Platform

## Mission
Deliver ingestion, cataloging, enrichment, and retrieval of media assets while remaining autonomous from the configuration and authentication stacks. The `media-core` namespace/cluster owns its Consul + Vault pair, Kafka bus, and storage services, exposing APIs and events consumed by clients and downstream systems.

## Core Services
| Service | Responsibility | Design Docs |
| --- | --- | --- |
| Ingestion Services (`file-upload-api`, `telegram-ingestor`, …) | Accept media from clients, stage artifacts in MinIO, and publish metadata pointers to Kafka. | `designs/content-management.md`, `designs/kafka-messaging-bus.md` |
| StoragePersistor | Consumes raw ingest events, moves objects into long-term buckets, persists metadata via PostgREST, and emits `media_ingested` events. | `designs/minio-content-server.md`, `designs/postgres-api-platform.md` |
| Processing Services (`pdfProcessor`, OCR, enrichment jobs) | React to ingested events to extract text, enrich metadata, and update PostgREST. | `designs/content-management.md`, `designs/search-elasticsearch.md` |
| Public APIs (Logic Router, PostgREST, search endpoints) | Provide consistent interfaces (REST/GraphQL) for clients to query catalogs and retrieve assets. | `designs/logic-router.md`, `designs/postgres-api-platform.md`, `designs/search-elasticsearch.md` |
| Observability Agents | Emit telemetry (metrics/logs/traces) into shared observability stack. | `designs/observability-platform.md`, `designs/tracing-platform.md` |

Supporting infrastructure includes Kafka (KRaft) with Schema Registry, MinIO cluster with control service, PostgreSQL + PostgREST, Elasticsearch search stack, and Redis for queues/caches.

## Namespace Architecture
- Consul and Vault dedicated to `media-core`; services register locally and receive mesh identities via Consul Connect.
- Vault issues service credentials (PostgreSQL, MinIO, Kafka) with short TTL leases; secrets stored in ExternalSecrets for workloads requiring file mounts.
- Kafka brokers, Schema Registry, and MinIO reside within the namespace, exposing load-balanced endpoints to external consumers through mesh gateways or API Gateway as needed.
- Argo CD manages Helm releases for each subsystem; GitOps repo stores values overlays and configuration exports.

## Data Flow
1. **Ingestion**
   - API Gateway forwards client uploads to ingestion endpoints.
   - Ingestion service stages file in MinIO (temporary bucket) and publishes a `media.raw-ingest.v1` event to Kafka.
2. **Persistence**
   - StoragePersistor consumes the event, moves the object into a versioned bucket, writes metadata (PostgREST), and emits `media.ingested.v1`.
3. **Processing**
   - Processing services subscribe to `media.ingested.v1`, perform transformations (text extraction, thumbnail generation), update PostgREST, and optionally publish new events (`media.processed.v1`).
4. **Delivery**
   - Logic Router/PostgREST serve metadata, while signed URLs from MinIO deliver binary assets.
   - Search API queries Elasticsearch indices populated by indexer workers.

Kafka topics follow `<domain>.<event>.<version>` naming with schema compatibility enforced via Schema Registry. Dead-letter topics capture failed events for manual triage.

## Configuration & Secrets
- Runtime configuration stored in local Consul KV (`media-core/<service>/…`); services bootstrap using `config-cli` but pointing at the media Consul cluster.
- Authentication stack endpoints (forward-auth, OIDC) consumed via external HTTP; credentials stored in Vault or ExternalSecrets.
- Shared/lower environments may consume base configuration from `platform-config` Consul while overriding service-specific keys locally.

## Observability & Operations
- Metrics scraped by namespace-level Prometheus; dashboards include ingestion throughput, Kafka lag, MinIO capacity, PostgREST latency, search zero-result rate.
- Loki collects structured logs (JSON) with correlation IDs; traces propagated via OpenTelemetry middleware.
- Runbooks cover Kafka maintenance, MinIO lifecycle policies, Postgres backups (PITR), Elasticsearch snapshots, and Logic Router canary releases.
- Incident response: on schema breaks or Kafka backlog, pause producers via feature flags in Consul; restart consumers after remediation.

## Security
- API Gateway + forward-auth enforce user identity; service-to-service communication uses Consul Connect mTLS.
- Asset delivery uses signed URLs with short-lived tokens; MinIO buckets enforce versioning and lifecycle rules.
- Kafka ACLs managed via GitOps; services hold producer/consumer credentials issued by Vault.
- PostgREST row-level security ensures user-scoped data access; Logic Router performs additional RBAC header checks.

## Deployment Pipeline
- Code repositories build via GitHub Actions runners (configuration from `platform-config`).
- Container images published to private registry (`designs/docker-registry.md`).
- GitOps PR updates Helm values (image tags, config) under `apps/media/*`; Argo CD synchronizes staging → production after approvals.
- Integration tests run against ephemeral environments using namespace overlays.

## Roadmap
1. Introduce data residency controls (bucket replication policies, regional Kafka mirrors).
2. Add background job orchestration (e.g., Temporal) for complex workflows.
3. Extend processing services with ML enrichment and content moderation.
4. Implement user-facing GraphQL gateway for media search/browse experiences.
5. Automate drift detection between PostgREST schema and ingestion processors.

## References
- Messaging & events: `designs/kafka-messaging-bus.md`
- Ingestion & CMS: `designs/content-management.md`
- Object storage: `designs/minio-content-server.md`
- Catalog API: `designs/postgres-api-platform.md`
- Search platform: `designs/search-elasticsearch.md`
- Logic Router: `designs/logic-router.md`
- Observability/Tracing: `designs/observability-platform.md`, `designs/tracing-platform.md`
