# MinIO Content Platform

## Purpose
MinIO stores binary media (documents, images, derived assets) in support of the Layer 4 data plane described in `ARCHITECTURE.md` and `DESIGN.md`. Metadata remains in PostgreSQL/PostgREST; MinIO provides durable object storage, lifecycle governance, and secure delivery endpoints that align with retention and residency rules (`22_db_back/adr/0001-data-retention.md`).

## Platform Overview
| Component | Responsibility | Notes |
| --- | --- | --- |
| MinIO Cluster | Distributed object store with erasure coding, versioning, and SSE | Deployed in the `content` namespace; runs on Kubernetes worker pool sized per System Requirements. |
| Control Service (`minio-control`) | Issues upload/download sessions, enforces policy, emits audit events | Stateless Go service using Vault-issued credentials; integrates with Authentik RBAC. |
| Lifecycle Automation | Applies bucket policies, lifecycle rules, replication jobs | Managed via GitOps manifests executed by Argo workflows or Kubernetes Jobs. |
| CMS / Logic Router Integration | Requests signed URLs and promotion actions | Follows workflows outlined in `01_conf_mgmt/content-management.md` and presentation ADR `51_Presentation_back/adr/0001-api-contract.md`. |

## Deployment Model
- **Environments**:
  - Local: single MinIO pod (`minio/minio` in standalone mode) for development.
  - Staging: 4-node distributed MinIO (erasure set, parity 2) with persistent volumes on SSD.
  - Production: 6-node distributed MinIO with auto-healing; traffic behind Consul mesh gateways (`01_conf_mgmt/mesh-gateway.md`).
- **Access**: Services reach MinIO via mTLS endpoints (`https://minio.${env}.svc`); management console restricted to operators via VPN or Cloudflare Access.
- **Credentials**: Root credentials stored in Vault; per-service access keys generated via MinIO STS or Vault dynamic secrets (see `01_conf_mgmt/adr/0001-secret-rotation.md`). ExternalSecrets deliver credentials to workloads.
- **Configuration**: Buckets, policies, and lifecycle rules stored under `configs/minio/` and applied through GitOps jobs using `mc admin` and `mc ilm`.

## Bucket Layout & Governance
| Bucket | Purpose | Lifecycle |
| --- | --- | --- |
| `cms-attachments` | Editorial assets (knowledge base) | Versioning enabled; non-current versions retained 180 days. |
| `media-staging` | Temporary uploads pending approval | Auto-expire after 30 days; promotion moves objects to destination bucket. |
| `media-prod/<locale>` | Published assets per locale | Aligns with presentation caching; retains indefinitely unless takedown event logged. |
| `public-downloads` | Assets approved for external distribution | Versioning + CDN integration; signed URLs limited to minutes. |
| `sandbox-*` | Preview/testing buckets | Auto-clean daily via lifecycle rules. |

Bucket naming convention: `myfarsi-<env>-<bucket>`. All buckets enforce SSE-S3 (or SSE-KMS when Vault Transit integration lands) and block public ACLs by default.

## Workflows
### Upload & Promotion
1. CMS requests a session (`POST /v1/uploads`) from `minio-control` with asset metadata, locale, and publishing window.
2. `minio-control` validates Authentik headers, quotas, and retention policy; issues pre-signed PUT URL or STS credentials for the `media-staging` bucket.
3. Client uploads directly to MinIO and returns completion details (`POST /v1/uploads/{id}/complete`).
4. Control service verifies object checksum, moves object to target bucket, records audit entry, and publishes `media.asset_uploaded.v1` on Kafka (`20_central_bus/kafka-messaging-bus.md`).
5. Lifecycle job watches for pending promotions older than SLA and alerts editors.

### Download
1. Presentation service retrieves metadata from PostgREST/Logic Router.
2. Service calls `minio-control` (`POST /v1/downloads`) to obtain a signed GET URL. Control validates entitlement (group, locale, publish window).
3. Client downloads via MinIO or CDN edge. Cache headers include object version to support invalidation.

### Revocation
- For takedown requests, control service moves object to `archive/` prefix and invalidates signed URLs. Kafka event `media.asset_revoked.v1` notifies downstream systems.
- Lifecycle automation ensures archived objects adhere to retention requirements (indefinite unless policy change).

## Security & Compliance
- MinIO endpoints accessible only inside the Consul mesh; north-south traffic continues through API Gateway with signed URLs.
- Enable server-side encryption and audit logging. Forward audit logs (upload sessions, download issuance, policy changes) to Loki for 180-day retention.
- Virus scanning (Phase 3 roadmap) runs as asynchronous job using ClamAV or third-party service before promotion.
- Signed URLs default to 5 minutes (configurable per service). STS credentials limited to single-purpose buckets and expire within 15 minutes.
- Align with EU residency: replication targets remain in EU regions; replication outside EU requires new ADR.

## Observability
- Metrics scraped via Prometheus exporters:
  - MinIO: `minio_disk_storage_bytes`, `minio_api_requests_total`, `minio_bucket_usage_bytes`.
  - Control service: HTTP duration/latency, policy denials, signed URL issuance counts.
- Dashboards highlight storage utilization, upload latency, failed promotions, lifecycle job status, and replication health.
- Alerts trigger on disk usage > 80%, error rates > 5%, replication failures, or audit anomalies (spike in revoked downloads).
- `minio-control` emits OTLP traces correlated with CMS requests and Kafka events.

## Backup & DR
- Daily replication/mirroring to secondary MinIO cluster within EU; verification job checks object hashes weekly.
- Retain bucket configuration (policies, lifecycle JSON) in Git; recovery process reapplies configs before rehydrating data.
- Runbooks cover cluster rebuild, credential rotation, and failback. Documented in `docs/content/minio-runbook.md` (to be written).

## Operations
- CI builds the `minio-control` service, runs integration tests with ephemeral MinIO using Testcontainers.
- Helm charts include jobs to create buckets, apply policies, and configure lifecycle/replication.
- Quarterly credential rotation triggered via automation (GitOps pipeline) and validated through smoke tests.
- Garbage collection job purges abandoned uploads and stale signed URL entries from control service state.
- Scaling: add MinIO pods and run `mc admin rebalance`; monitor progress and adjust erasure set size.

## Roadmap
1. **Phase 1**: Deploy distributed MinIO, control service (upload + signed download), integrate with CMS and Kafka events.
2. **Phase 2**: Automate lifecycle rules, replication, and CDN integration; add observability dashboards and alerts.
3. **Phase 3**: Introduce virus scanning, thumbnail/transcoding hooks, and webhook notifications for external systems.
4. **Phase 4**: Support multi-tenant spaces, cost-aware storage tiers, and analytics on asset usage to drive optimization.

## References
- `ARCHITECTURE.md`, `DESIGN.md`, and `SystemReqs.md` for platform context.
- `01_conf_mgmt/content-management.md` for configuration governance.
- `20_central_bus/kafka-messaging-bus.md` for event contracts.
- `51_Presentation_back/adr/0001-api-contract.md` for presentation service expectations.
- `03_telemetry/observability-platform.md` for monitoring guidance.
