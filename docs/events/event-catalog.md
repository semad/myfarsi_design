# Kafka Event Catalog

## Purpose
Document the canonical Kafka topics, payload schemas, producers, and consumers that make up the MyFarsi event backbone. This catalog supplements `20_central_bus/kafka-messaging-bus.md` and provides a quick reference for engineers adding or consuming events.

## Naming Convention
- Topics follow `<domain>.<event>.v<number>` (e.g., `media.raw_ingest.v1`).
- Schema versions align with topic version; breaking changes require new topic (e.g., `v2`) and ADR.
- Topics reside in the `myfarsi-<env>` Kafka cluster; ACLs enforced per topic.

## Event Inventory

### media.raw_ingest.v1
- **Description**: Pointer event emitted by ingestion services when a client uploads media.
- **Producer(s)**: `file-upload-api`, `telegram-ingestor`.
- **Consumer(s)**: `storage-persistor`, audit pipeline, observability enrichment.
- **Schema** (`avsc`):
  ```json
  {
    "type": "record",
    "name": "RawIngestEvent",
    "namespace": "com.myfarsi.media",
    "fields": [
      {"name": "asset_id", "type": "string"},
      {"name": "tenant_id", "type": "string"},
      {"name": "ingest_path", "type": "string"},
      {"name": "original_filename", "type": "string"},
      {"name": "checksum_sha256", "type": "string"},
      {"name": "size_bytes", "type": "long"},
      {"name": "locale", "type": ["null", "string"], "default": null},
      {"name": "uploaded_at", "type": "long", "logicalType": "timestamp-micros"}
    ]
  }
  ```
- **Retention**: 30 days.
- **Notes**: Guarantees idempotency via `asset_id` key; consumers must handle retries.

### media.ingested.v1
- **Description**: Emitted by storage persistor after moving objects to durable buckets and writing metadata.
- **Producer(s)**: `storage-persistor`.
- **Consumer(s)**: Processing services (`pdf-processor`, `thumbnailer`), search indexer, analytics pipeline.
- **Schema**:
  ```json
  {
    "type": "record",
    "name": "MediaIngestedEvent",
    "namespace": "com.myfarsi.media",
    "fields": [
      {"name": "asset_id", "type": "string"},
      {"name": "tenant_id", "type": "string"},
      {"name": "bucket", "type": "string"},
      {"name": "object_key", "type": "string"},
      {"name": "metadata_version", "type": "string"},
      {"name": "mime_type", "type": "string"},
      {"name": "size_bytes", "type": "long"},
      {"name": "ingested_at", "type": "long", "logicalType": "timestamp-micros"}
    ]
  }
  ```
- **Retention**: 14 days.
- **Notes**: Includes pointer to PostgREST metadata via `metadata_version`. Search indexer relies on this event.

### media.asset_revoked.v1
- **Description**: Takedown or revocation notice for assets removed from public access.
- **Producer(s)**: `minio-control`.
- **Consumer(s)**: Presentation services (invalidate caches), search indexer (remove documents), analytics.
- **Schema**:
  ```json
  {
    "type": "record",
    "name": "AssetRevokedEvent",
    "namespace": "com.myfarsi.media",
    "fields": [
      {"name": "asset_id", "type": "string"},
      {"name": "tenant_id", "type": "string"},
      {"name": "reason", "type": "string"},
      {"name": "revoked_by", "type": "string"},
      {"name": "revoked_at", "type": "long", "logicalType": "timestamp-micros"}
    ]
  }
  ```
- **Retention**: 90 days (compacted).
- **Notes**: Consumers must honor takedown within SLA. Compaction keeps latest state.

### cms.article_published.v1
- **Description**: Signals that an article passed workflow approvals and is live.
- **Producer(s)**: CMS workflow engine.
- **Consumer(s)**: Search indexer, presentation cache warmer, analytics.
- **Schema**:
  ```json
  {
    "type": "record",
    "name": "ArticlePublishedEvent",
    "namespace": "com.myfarsi.cms",
    "fields": [
      {"name": "article_id", "type": "string"},
      {"name": "space", "type": "string"},
      {"name": "locales", "type": {"type": "array", "items": "string"}},
      {"name": "published_at", "type": "long", "logicalType": "timestamp-micros"},
      {"name": "editor", "type": "string"}
    ]
  }
  ```
- **Retention**: 14 days.
- **Notes**: Downstream services fetch localized content versions from PostgREST.

### cms.article_unpublished.v1
- **Description**: Article removed or expired.
- **Producer(s)**: CMS workflow engine.
- **Consumer(s)**: Search indexer (delete documents), presentation cache invalidation, analytics.
- **Schema** mirrors `ArticlePublishedEvent` with `unpublished_at` field.
- **Retention**: 14 days.

## Adding a New Event
1. Draft schema in `schemas/<domain>/<event>.avsc`.
2. Update this catalog with description, producers/consumers, retention, and notes.
3. Submit PR with schema and catalog update; reviewers validate topic naming, compatibility, and retention alignment.
4. After merge, update GitOps config with topic ACLs and deploy schema via Schema Registry pipeline.

## References
- `20_central_bus/kafka-messaging-bus.md`
- `SystemReqs.md` for retention requirements
- `22_db_back/adr/0001-data-retention.md`
- Schema registry repository (to be created) for Managed schemas
