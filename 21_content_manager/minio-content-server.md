# MinIO Content Platform

## Purpose
Store binary assets (documents, images, media bundles) with S3 semantics, enforce editorial governance, and supply signed URLs to downstream consumers. MinIO complements the CMS by housing artifacts while metadata lives in PostgreSQL.

## Components
- **MinIO Cluster**: StatefulSet or distributed deployment with erasure coding and versioning. Exposes S3 + console endpoints.
- **Control Service**: Go microservice that issues upload sessions, generates signed URLs, manages bucket policies, and records audit events.
- **CMS Integration**: CMS invokes control service to create/upload/promote assets; stores object keys, locale metadata, and schedules.
- **Delivery Path**: Clients request content via CMS/Logic Router; receive signed URLs pointing to MinIO or CDN edge.

## Deployment
- Namespace `content`; Helm chart `charts/minio-content`.
- Production: 4+ MinIO pods with erasure set (EC parity 2), persistent volumes on SSD. Staging/dev: 1–2 pods or standalone.
- `minio-control` deployment scales horizontally (stateless).
- ExternalSecrets supply root credentials and service access keys. Airlock `minio` service behind Consul Connect mTLS.
- Optional MinIO Console accessible only to operators (Cloudflare Access or VPN).

## Bucket Strategy
| Bucket | Usage | Notes |
| --- | --- | --- |
| `cms-attachments` | Knowledge-base binaries | Versioned; lifecycle retains non-current 180 d. |
| `cms-media/<locale>` | Locale-specific assets | Helps CDN routing; fallback to base locale. |
| `public-downloads` | Approved external assets | Strict promotion workflow; CDN-backed. |
| `sandbox-*` | Editorial previews | Auto-expire after 30 d via lifecycle rules. |

Buckets use naming convention `myfarsi-<env>-<bucket>` and enable versioning + server-side encryption. Lifecycle configs live in GitOps repo and applied with `mc ilm` job.

## Workflows
### Upload
1. CMS requests session from control service (`POST /v1/uploads`), passing asset metadata.
2. Control service validates user/group (Authentik headers), quota, and schedule; creates object placeholder and returns pre-signed PUT URL or temporary credentials.
3. Client uploads directly to MinIO using signed URL.
4. CMS confirms completion (`POST /v1/uploads/{id}/complete`); control service verifies object hash/size, moves from sandbox bucket to target bucket, emits Kafka event (`asset_uploaded`).

### Download
1. Consumer fetches metadata from CMS/Logic Router.
2. Service requests signed GET URL (`POST /v1/downloads`); control service ensures entitlements (group, locale, publish window) and returns short-lived URL.
3. Client downloads asset via MinIO or CDN; caching headers include object version/hashes.

### Governance
- Promotion requires Approved workflow state; control service logs operator, timestamp, new bucket.
- Optional virus scan step using async queue; only promote when scan passes.
- Revoking asset triggers lifecycle job to remove signed URLs and move object to archive prefix.

## Security
- Root credentials stored in Vault; per-service access keys generated via dynamic IAM (MinIO STS or manual key rotation).
- MinIO endpoints exposed only inside mesh; external access occurs through signed URLs with limited lifetime.
- Control service authenticates requests using Authentik headers; enforces RBAC mapping to Authentik groups (`cms-author`, `cms-publisher`).
- Enable server-side encryption (SSE-S3 or SSE-KMS). For SSE-KMS integrate with Vault Transit.
- Audit logs include upload session creation, promotion, download issuance; ship to Loki/SIEM.

## Observability
- Metrics:
  - MinIO: `minio_disk_storage_bytes_free`, `minio_http_requests_total`, `minio_bucket_usage_bytes`.
  - Control: `minio_control_requests_total`, `minio_control_request_duration_seconds`, `minio_control_policy_deny_total`.
- Dashboards track storage utilization, request latency, signed URL issuance, lifecycle job status.
- Alerts when disk usage > 80%, error rate spikes, lifecycle jobs fail, or audit events exceed thresholds.

## Backup & DR
- Daily replication to secondary bucket (mc mirror or built-in replication); maintain PITR for control DB if used.
- Weekly integrity verification (hash compare). Store CMS metadata backups to rebuild references.
- DR runbook: deploy empty cluster, restore data from replica, reapply bucket configs, test signed URLs.

## Operations
- CI builds control service, runs integration tests with Dockerized MinIO.
- Helm release includes init job to create buckets/policies via `mc`.
- Key rotation: update ExternalSecrets → rolling restart; schedule quarterly.
- Garbage collection: lifecycle rules + explicit cleanup job for orphaned uploads.
- Scaling: add MinIO nodes by extending StatefulSet and rebalancing; monitor rebalance progress.

## Roadmap
1. Phase 1: MVP cluster, control service (upload + signed GET), CMS integration.
2. Phase 2: Lifecycle automation, replication, CDN integration, audit dashboards.
3. Phase 3: Virus scanning, thumbnail/transcoding pipeline, webhook notifications.
4. Phase 4: Multi-tenant namespaces, analytics on asset usage, cost optimization tiers.

## References
- Content platform (`designs/content-management.md`)
- Identity (`designs/authentication.md`)
- Observability (`designs/observability-platform.md`)
- Search ingestion (`designs/search-elasticsearch.md`)
