# Backend Media Server Overview

MyFarsi’s backend platform ingests media from heterogeneous sources, stores artifacts durably, and exposes curated assets through secure APIs. This document restates the layered reference architecture, the event-driven flow, and the operational guardrails that keep the system resilient.

## Layered Architecture
```
Layer 5 ─ Business Logic & APIs
Layer 4 ─ Data & Storage
Layer 3 ─ Observability
Layer 2 ─ Config, Secrets & Mesh
Layer 1 ─ CI/CD & Build Infra
```

### Layer 1 · CI/CD & Build Infrastructure
- GitHub Actions backed by self-hosted runners (`designs/cicd-runner.md`) handle build, test, scan, and deployment automation.
- Container images published to private Docker registry; provenance tracked via build metadata.
- Makefiles standardize local and CI workflows across services.

### Layer 2 · Configuration, Secrets & Mesh
- Consul provides service discovery, KV configuration, and Connect service mesh (`designs/consul.md`).
- Vault stores credentials, issues mTLS identities, and integrates with Consul Connect for certificate rotation.
- Consul API Gateway (Envoy) fronts external traffic, integrates with forward-auth for Authentik SSO.

### Layer 3 · Observability
- OpenTelemetry SDKs in every service export traces, metrics, and logs to the OpenTelemetry Collector.
- Prometheus stores metrics, Tempo/Jaeger hold traces, Loki aggregates logs; Grafana visualizes all three.
- Standard dashboards track ingestion throughput, Kafka lag, API latency, storage health.

### Layer 4 · Data & Storage
- PostgreSQL (via PostgREST) persists structured metadata and operational state.
- MinIO/S3 holds all binary media with lifecycle policies.
- Redis supplies ephemeral caching/queues where needed.
- Schema Registry governs Kafka payload schemas.

### Layer 5 · Business Logic & APIs
- API Gateway accepts client traffic (`mediaCli`, web apps), enforces auth, applies rate limits.
- Ingestion services (file uploads, Telegram ingest) validate input, stage files, and publish Kafka events.
- Storage Persistor moves objects to durable buckets and writes metadata to PostgREST.
- Processing services (e.g., `pdfProcessor`) enrich assets and post downstream events.
- Client tooling (CLI, internal apps) consumes APIs for search, download, moderation.

## Event Flow (Claim Check Pattern)
1. **Ingest**: Client uploads via API Gateway → ingestion service; file placed in temporary MinIO location.
2. **Claim Check**: Ingestion service publishes lightweight Kafka message referencing staged object and metadata.
3. **Persist**: Storage Persistor consumes message, moves file to long-term bucket, writes metadata via PostgREST.
4. **Signal**: Persistor emits `media_ingested` event; processing services react to perform extraction, transcoding, etc.
5. **Serve**: Processed metadata and assets accessed through business APIs with Authentik-protected headers.

Idempotent consumers, explicit acknowledgements, and dead-letter topics keep the pipeline resilient. Kafka retention policies plus Schema Registry compatibility rules guard against data loss and schema drift.

## Cross-Cutting Concerns
- **Service Segmentation**: Configuration Management, Authentication, and Media Business Logic each run in their own namespace/cluster with dedicated Consul + Vault instances; the configuration stack’s pair also serves CI/CD pipelines that rely on `config-cli` (`designs/config-management.md`).
- **Messaging**: Kafka cluster with replication factor 3, ZooKeeper-free KRaft mode, MirrorMaker 2 for DR replication (`designs/kafka-messaging-bus.md`).
- **Identity**: Authentik SSO with forward-auth service injecting trusted headers; service-to-service auth handled by Consul/Vault.
- **Security**: mTLS across mesh, secrets stored in Vault/ExternalSecrets, audit logging across identity and content workflows.
- **Governance**: ADRs capture architectural decisions (`designs/adr/*`). Roadmaps call out evolution points for each subsystem.

## Data Consistency
- Consumers designed to be idempotent; state transitions validated before mutating storage.
- Exactly-once semantics approximated via Kafka idempotent producers and transactional writes where necessary.
- Dead-letter queues isolate poison messages; runbooks cover triage and reprocessing.

## Representative Use Cases
- **Document Archive**: Ingest PDFs, extract text, index for search, expose via knowledge-base CMS.
- **Telegram Capture**: Poll channel, download media, convert, catalog for moderation.
- **Video Library**: Transcode to multiple renditions, generate thumbnails, store metadata with playback policies.
- **Image Pipeline**: Process EXIF, generate responsive sizes, update content tags.

## Development & Operations
- Container-first workflow; local dev via Docker Compose with mock dependencies.
- CI enforces lint/test/build; deployments orchestrated by Argo CD GitOps pipelines.
- Externalized configuration via Consul KV, typically injected through `config-cli` (see `designs/config-cli.md`); secrets fetched at runtime.
- Backups cover PostgreSQL snapshots, MinIO bucket versioning, Kafka topic exports, and Consul snapshots.

This layered architecture keeps services loosely coupled, leverages durable messaging, and ensures observability/security are first-class across the platform.
