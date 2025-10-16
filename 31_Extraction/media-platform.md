# Media Business Logic Platform

## Purpose

Coordinate ingestion, persistence, enrichment, and delivery workflows for media assets within the `media-core` domain. This document aligns the media platform with the updated architecture (`ARCHITECTURE.md`), requirements (`SystemReqs.md`), and supporting specs (Kafka, MinIO, PostgREST, Logic Router, Search).

## Domain Overview

| Layer         | Services                                                  | References                                                                            |
| ------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Ingestion     | `file-upload-api`, `telegram-ingestor`, future connectors | `20_central_bus/kafka-messaging-bus.md`, `21_content_manager/minio-content-server.md` |
| Persistence   | `storage-persistor`, metadata migrations                  | `22_db_back/postgres-api-platform.md`                                                 |
| Processing    | `pdf-processor`, thumbnailer, OCR, ML enrichment          | `40_ai/ai-services.md` (to be created as models mature)                               |
| Delivery      | Logic Router, Search API, PostgREST endpoints             | `51_Presentation_back/logic-router.md`, `23_search_back/search-elasticsearch.md`      |
| Observability | Metrics/logs/traces, runbooks                             | `03_telemetry/observability-platform.md`, `docs/content/minio-runbook.md`             |

The domain operates its own Consul + Vault pair, Kafka cluster, MinIO storage, and Elasticsearch stack. Cross-domain access occurs via mesh gateways (`01_conf_mgmt/mesh-gateway.md`).

## Workflows

1. **Ingestion**
   - Clients authenticate via API Gateway (forward-auth).
   - Ingestion service stages file in MinIO `media-staging` bucket and emits `media.raw_ingest.v1`.
   - Metadata such as tenant, locale, checksum packaged in the event.
2. **Persistence**
   - Storage Persistor listens to `media.raw_ingest.v1`, moves object to durable bucket, writes metadata via PostgREST, and emits `media.ingested.v1`.
   - Dead-letter topic captures failures for manual replay.
3. **Processing**
   - Workers subscribe to `media.ingested.v1`, perform extraction/ML tasks, update metadata (`content.asset_metadata` table), store derived objects (thumbnails) in MinIO, and emit follow-up events (e.g., `media.asset_enriched.v1`).
4. **Delivery**
   - Logic Router aggregates metadata (PostgREST) and signed URLs (MinIO control) to serve client requests.
   - Search API indexes documents using events and PostgREST snapshots.
   - Presentation front-ends consume Logic Router and Search APIs (`52_Presentation_front/frontend-app.md`).

## Configuration & Secrets

- Services bootstrap via `config-cli` pointing to the `media-core` Consul cluster (`media-core/<service>/config` paths).
- Vault issues credentials for PostgreSQL, MinIO, Kafka; AppRole policies scoped per service.
- Feature flags (e.g., enabling new processors) stored in Consul; toggled via GitOps.

## Observability & Runbooks

- Metrics instrumented with OTLP exports. Key KPIs: ingestion latency, Kafka lag, MinIO promotion time, processing success rate.
- Runbooks available under `docs/`:
  - `docs/content/minio-runbook.md` (storage)
  - `docs/events/event-catalog.md` (event references)
  - `docs/media/kafka-runbook.md` (messaging)
  - `docs/media/processing-runbook.md` (processing)
- Alerts tie to SLOs defined in `SystemReqs.md`: ingestion throughput, processing backlog, delivery latency.

## Deployment

- GitHub Actions build container images; artifacts pushed to private registry.
- GitOps repository contains Helm values under `apps/media/<service>`.
- Argo CD syncs staging before production; manual approval required for schema changes or breaking events.
- Feature rollout strategy: toggle in Consul, canary release via Logic Router route targeting.

## Roadmap

1. Implement additional ingestion connectors (email, RSS) with shared libraries.
2. Add ML enrichment pipeline (transcription, moderation) with GPU-capable workers.
3. Introduce Temporal or Workflow engine for long-running processing sequences.
4. Define multi-region replication policies for MinIO and PostgreSQL (per System Requirements).
5. Automate event contract testing in CI using schemas from `docs/events/event-catalog.md`.

## References

- `20_central_bus/kafka-messaging-bus.md`
- `21_content_manager/minio-content-server.md`
- `22_db_back/postgres-api-platform.md`
- `23_search_back/search-elasticsearch.md`
- `51_Presentation_back/logic-router.md`
- `SystemReqs.md`
