# Kafka Messaging Bus

## Purpose
Provide a durable event backbone so services share data asynchronously, decouple deployment lifecycles, and implement the claim-check pattern for large media assets.

## Cluster Topology
- Kafka 3.x (KRaft mode) with three brokers per environment; dedicated ZooKeeper-free configuration.
- Listeners:
  - `INTERNAL_PLAINTEXT` (home dev only)
  - `INTERNAL_TLS` for cluster-internal SASL/OAUTHBEARER
  - `EXTERNAL_TLS` for ingress via Consul API Gateway if needed
- Storage: SSD-backed volumes sized for 7–30 day retention; monitor disk > 70%.
- Quorum voters colocated with brokers; metadata quorum of 3 to tolerate single failure.
- Use Strimzi or Confluent Operator for Kubernetes deployment; include Cruise Control for balancing.

## Supporting Services
- **Schema Registry**: Avro/Protobuf schemas with backward-compatibility checks; stored in Git for review.
- **Kafka Connect**: Optional for integrations (Postgres CDC, MinIO events).
- **Kafka Exporter / JMX Exporter**: Prometheus metrics.
- **Burrow or Kafka Lag Exporter**: Consumer lag monitoring.
- **MirrorMaker 2**: Future cross-region replication + DR.

## Client Standards
- Producers: `acks=all`, idempotence enabled, retries with exponential backoff, request timeout 30 s.
- Consumers: use consumer groups, `enable.auto.commit=false`, commit after processing; handle poison messages via retry/DLQ topics.
- Serialization: Avro/Protobuf using common libraries; schema stored under `schemas/<domain>/<topic>.avsc`.
- Configuration delivered via Consul KV/`config-cli` (see `designs/config-cli.md` for entrypoint behavior).
- Provide SDK/sidecar examples in Go and Python with consistent retry and circuit-breaker behavior.

## Topic Design
- Naming convention: `<domain>.<event>.<version>` (e.g., `media.raw-ingest.v1`, `media.ingested.v1`).
- Partitioning: stable key (e.g., asset ID) to maintain ordering; default 6 partitions; adjust for throughput.
- Replication factor: 3 (staging/prod), 1 (home dev).
- Retention tiers:
  - Raw ingest: 30 d (allow reprocessing).
  - Processed events: 7–14 d.
  - Audit topics: 90 d (compacted).
- Compaction for state topics (e.g., metadata snapshots).
- Access control via ACL bundles; producers limited to write on specific topics, consumers to read.

## Operations & Observability
- Metrics to track: under-replicated partitions, offline partitions, ISR shrink, request latency, consumer lag, broker disk usage.
- Alerts:
  - URP > 0 for >5 m (critical)
  - Consumer lag above threshold (per service)
  - Disk usage >80%
  - Controller election frequency anomalies
- Logging centralized via Fluent Bit; audit logs retained 90 d.
- Cruise Control automates rebalancing after broker addition/removal; require change approvals.
- Backups: nightly partition dumps (optional) or rely on MirrorMaker replication.

## Security
- mTLS between brokers and clients; certs issued by Vault PKI with automated rotation.
- SASL/OAUTHBEARER tokens minted via Authentik or dedicated OAuth provider; short-lived (1 h).
- ACL management automated via GitOps (YAML definitions → Kafka ACL tool).
- Secrets stored in ExternalSecrets; no static passwords.
- Enable encryption at rest if storage supports; otherwise rely on disk-level encryption.

## Governance
- Change review for new topics: include schema, retention, owners, SLAs.
- Schema Registry compatibility: backward by default; break glass for major version changes.
- Document event catalog (producer, consumer, payload) in `docs/events.md`.
- Monitor DLQ volume; create runbooks for remediation.

## Roadmap
1. Phase 1: Stand up cluster (Strimzi helm), Schema Registry, baseline topics (raw ingest, ingested, audit).
2. Phase 2: Add Burrow/Kafka Lag Exporter, Cruise Control, GitOps-managed ACLs.
3. Phase 3: Introduce MirrorMaker for DR, Connect connectors (Postgres CDC), automated schema tests in CI.
4. Phase 4: Multi-tenant quotas, tiered storage evaluation, schema evolution tooling (compatibility checks in PRs).

## References
- Architecture blueprint (`designs/ARCHITECTURE.md`)
- Content ingestion (`designs/content-management.md`)
- Storage pipeline (`designs/minio-content-server.md`)
- Observability (`designs/observability-platform.md`)
