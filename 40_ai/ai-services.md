# AI Enrichment Services

## Purpose

Describe the machine learning and AI components that enrich media assets within the MyFarsi platform. These services consume events from Kafka, augment metadata stored in PostgreSQL, and publish derived artifacts back to MinIO and downstream consumers.

## Scope

- Natural language processing (text extraction, summarization, translation).
- Computer vision (thumbnail generation, OCR, image tagging).
- Moderation (policy checks, sensitive content detection).
- Recommendation signals (future).

## Architecture

| Component          | Responsibility                                                      | Integration Points                           |
| ------------------ | ------------------------------------------------------------------- | -------------------------------------------- |
| Event Consumers    | Subscribe to `media.ingested.v1`, `media.asset_enriched.v1`         | `20_central_bus/kafka-messaging-bus.md`      |
| Processing Workers | Containerized jobs (Go/Python) performing ML tasks                  | `31_Extraction/media-platform.md`            |
| Model Hosting      | Docker images with open-source or custom models; GPU nodes optional | Managed via Kubernetes workloads             |
| Metadata Writer    | Updates PostgREST via service role `api_service_ai`                 | `22_db_back/postgres-api-platform.md`        |
| Artifact Publisher | Stores derived assets (thumbnails, transcripts) in MinIO            | `21_content_manager/minio-content-server.md` |
| Event Publisher    | Emits `media.asset_enriched.v1`, `media.asset_moderated.v1`         | `docs/events/event-catalog.md`               |

## Workflow Example (PDF Extraction)

1. Worker receives `media.ingested.v1` event.
2. Downloads object using signed URL from MinIO control service.
3. Runs extraction pipeline (PDF text, images).
4. Writes transcript to PostgreSQL (`content.asset_transcripts`) and stores derived text file in MinIO.
5. Publishes `media.asset_enriched.v1` with pointers to new metadata.

## Infrastructure

- Workers deployed as Kubernetes Deployments or Jobs; prefer horizontal scaling with autoscalers based on queue lag.
- Some models require GPUs; use node pools labeled `gpu=true` and schedule via tolerations.
- Configuration delivered through `config-cli` (Consul paths `media-core/ai/<service>`).
- Secrets (API keys, model registry tokens) provided by Vault (AppRole or Kubernetes auth).

## Model Management

- Models stored in private registry or artifact store.
- Versioned via semantic tags (e.g., `ocr-service:1.2.0`).
- Promote through staging before production; track model metadata in PostgreSQL (`ai.model_registry` table).
- Monitoring includes accuracy metrics, drift detection alerts, and human review queue for moderation decisions.

## Observability

- Metrics: processing latency, success/error counts, queue depth, GPU utilization.
- Logs: structured JSON with `asset_id`, `model_version`, `duration_ms`.
- Traces: OTLP spans with `model.name`, `model.version`, `result.status`.
- Dashboards correlate model performance with ingestion volume; alerts fire on error spikes, backlog growth, model drift thresholds.

## Security & Compliance

- Store only necessary data; redact sensitive outputs before logging.
- Maintain audit trail for moderation decisions to satisfy compliance.
- Ensure ML models respect residency (training data stored in EU-compliant storage).
- For external APIs (e.g., translation providers), manage credentials via Vault and rotate per `01_conf_mgmt/adr/0001-secret-rotation.md`.

## Roadmap

1. Phase 1: OCR/text extraction, thumbnail generation, basic moderation.
2. Phase 2: Language translation, summarization, entity tagging.
3. Phase 3: Personalized recommendations, search relevance boosts.
4. Phase 4: Human-in-the-loop review tooling, active model monitoring dashboards.

## References

- `31_Extraction/media-platform.md`
- `21_content_manager/minio-content-server.md`
- `22_db_back/postgres-api-platform.md`
- `docs/events/event-catalog.md`
- `03_telemetry/observability-platform.md`
