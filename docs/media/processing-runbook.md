# Media Processing Runbook

## Purpose
Provide operational guidance for the enrichment services described in `31_Extraction/media-platform.md` and `40_ai/ai-services.md`. This runbook covers monitoring, incident triage, and recovery of processing pipelines.

## Service Overview
- **Workers**: `pdf-processor`, `thumbnailer`, `ocr-service`, moderation jobs.
- **Event Sources**: Kafka topics `media.ingested.v1`, `media.asset_enriched.v1`.
- **Dependencies**: MinIO (object download/upload), PostgREST (metadata updates), Vault (credentials), optional GPU nodes.
- **Deployment**: Kubernetes Deployments with autoscalers per workload.

## Monitoring
- Grafana dashboard `Media / Processing`:
  - Event throughput (`processor_events_processed_total`).
  - Error rate (`processor_events_failed_total`).
  - Processing latency.
  - Queue depth (consumer lag).
- Check OTLP traces for long-running steps (download, model inference).
- Ensure MinIO and PostgREST dashboards healthy before blaming processors.

## Daily Checks
1. Verify Kafka consumer lag < threshold for each processor.
2. Confirm success/error counts within normal range.
3. Review DLQ topics (`media.processing.dlq`) and triage messages.
4. Inspect GPU node utilization (if applicable) to prevent saturation.

## Incident Response
### High Error Rate
1. Examine pod logs for stack traces (e.g., extraction failures, MinIO errors).
2. Identify failing asset IDs; check if input data malformed.
3. If regression after deploy, rollback to previous image tag (immutable SHA from GitOps history).
4. Communicate with content team if asset-specific issues require re-upload.

### Consumer Lag Growth
1. Confirm Kafka cluster healthy (see Kafka runbook).
2. Scale replicas or increase resource limits.
3. Inspect downstream dependencies (MinIO/PostgREST) for latency.
4. Pause ingestion (feature flag) if backlog threatens SLA; document decision.

### MinIO Access Failures
1. Validate STS credentials still valid; check Vault token.
2. Confirm MinIO runbook status (storage capacity, service health).
3. Retry manually using `minio-control` API; if successful, examine code path.

### PostgREST Write Failures
1. Check PostgREST status (latency, error rates).
2. Inspect database logs for locks or RLS policy violations.
3. Use replay script after underlying issue resolved.

## Maintenance Tasks
- **Deployment Upgrades**: Use GitOps PR to bump image tags; monitor after rollout.
- **Model Updates**: Update model artifact references in configuration; run canary processors.
- **Credential Rotation**: Trigger Vault role rotation; restart deployments to pick up new credentials.
- **DLQ Reprocessing**:
  1. Export DLQ messages.
  2. Validate fix.
  3. Replay using tooling (`scripts/replay_dlq.py`—to be implemented).

## Recovery & Replay
- For missed events, backfill using Kafka offsets or PostgREST snapshots.
- Use replay job that reads from `media.ingested.v1` with start offset/time.
- Ensure idempotency (processors should upsert metadata and avoid duplicate MinIO objects).

## Verification After Change
- Process sample asset end-to-end; confirm metadata updates and derived assets created.
- Check metrics for return to baseline.
- Validate that search index updates appear if processors emit follow-up events.

## Contacts
- Media processing on-call: `#oncall-media-processing`.
- AI/ML team for model issues.
- Storage/Database teams for dependency escalations.

## References
- `31_Extraction/media-platform.md`
- `40_ai/ai-services.md`
- `21_content_manager/minio-content-server.md`
- `22_db_back/postgres-api-platform.md`
- `docs/media/kafka-runbook.md`
