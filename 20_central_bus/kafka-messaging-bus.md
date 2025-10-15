# Kafka Messaging Bus

## Purpose
Kafka underpins Layer 4 of the MyFarsi platform by providing durable, replayable events that connect ingestion, persistence, enrichment, and presentation services. This document updates the messaging design to match the architecture outlined in `ARCHITECTURE.md`, the requirements in `SystemReqs.md`, and the data retention policy in `22_db_back/adr/0001-data-retention.md`.

## Cluster Architecture
- **Version & Mode**: Kafka 3.x running in KRaft mode (no ZooKeeper) with three brokers per environment (staging, production). Development environments may run single-node clusters for convenience.
- **Hardware**: Brokers run on the Equinix Metal-backed Kubernetes worker pool or dedicated VMs, using SSD/NVMe storage sized for 30 days of retention with headroom to avoid exceeding 70% disk utilization.
- **Listeners**:
  - `INTERNAL_TLS`: mTLS for broker-to-broker and internal client traffic.
  - `CLIENT_TLS`: Authenticated client access (producers/consumers) within the mesh.
  - `EDGE_TLS` (optional): Exposed through API Gateway for approved external consumers.
- **Controller Quorum**: Three KRaft controllers colocated with brokers to tolerate single-node failure.
- **Deployment**: Managed by Strimzi operator (preferred) or Confluent Platform on Kubernetes. Cruise Control handles balancing; MirrorMaker 2 reserved for future DR/multi-region work.

## Supporting Components
- **Schema Registry**: Hosts Avro/JSON Schema/Protobuf definitions with backward compatibility enforced. Schemas live in `schemas/<domain>/<topic>.avsc` and publish via GitOps.
- **Kafka Exporter & JMX Exporter**: Prometheus metrics collectors deployed per cluster.
- **Burrow/Kafka Lag Exporter**: Monitors consumer lag and integrates with alerting.
- **Kafka Connect**: Optional connectors for Postgres CDC, MinIO events, and external sinks; deployed when needed with dedicated namespaces.
- **Access Tooling**: GitOps-managed ACL definitions (`acls/*.yaml`) rendered into Kafka via automation pipelines.

## Topic Standards
- **Naming**: `<domain>.<event>.v<number>` (e.g., `media.raw_ingest.v1`, `media.ingested.v1`).
- **Partitioning**: Stable keys such as asset IDs or tenant IDs maintain ordering. Start with six partitions; scale based on throughput/SLA.
- **Replication Factor**: Three in staging/production, one in local development.
- **Retention**:
  - Raw ingest topics: 30 days to allow reprocessing.
  - Processed events: 14 days.
  - Audit/compacted topics: 90 days with log compaction enabled.
- **Compaction**: Enabled for stateful topics (`media.metadata_snapshot.v1`).
- **Schema Evolution**: Backward compatible by default. Breaking changes require major version (e.g., `v2`) and ADR review.
- **ACLs**: Producers limited to Write/Describe on their topics; consumers limited to Read/Describe. Managed via GitOps using service identities from Consul/Vault.

## Client Guidelines
- **Producers**:
  - `acks=all`, `enable.idempotence=true`.
  - Retries with exponential backoff; log and surface failures to observability stack.
  - Include headers for `service.name`, `deployment.env`, and `schema.version`.
- **Consumers**:
  - Use consumer groups; disable auto commit.
  - Commit offsets after successful processing; handle retries and DLQ handoffs.
  - Track lag metrics and integrate with Burrow alerts.
- **Serialization**: Avro (preferred) or Protobuf using shared libraries. Include schema references (`schema.registry.url`, subject).
- **Configuration Delivery**: All clients bootstrap via `config-cli` pulling broker endpoints, credentials, and topic names from Consul KV (`01_conf_mgmt/config-management.md`).

## Operations & Observability
- **Metrics**: Monitor under-replicated partitions, offline partitions, ISR counts, controller changes, request latency, throughput, consumer lag, disk usage, and network utilization.
- **Alerts**:
  - URP > 0 for 5 minutes (critical).
  - Consumer lag above service-specific thresholds.
  - Disk usage > 80%.
  - Controller election frequency spikes.
  - Cruise Control rebalance failures.
- **Logging**: Brokers stream logs through Fluent Bit to Loki; retain 90 days. Audit logs capture ACL changes and administrative operations.
- **Backup/Recovery**: MirrorMaker 2 for cross-cluster replication (Phase 3). For interim recovery, maintain documented procedures for partition dumps using `kafka-exporter` or object storage snapshots.
- **Testing**: Integration tests for publishers/consumers run in CI using ephemeral Kafka (testcontainers) and schema registry mocks.

## Security
- **Authentication**: mTLS via Vault-issued certificates for internal services. OAuth/OIDC tokens (minted via Authentik) for human tooling or external consumers.
- **Authorization**: Kafka ACLs generated from GitOps manifests; automation pipelines apply changes post-review.
- **Encryption**: TLS for all listeners; storage encryption handled by infrastructure (encrypted disks).
- **Secrets**: Stored in Vault and delivered via ExternalSecrets or `config-cli`. No secrets committed to Git.
- **Compliance**: Align with EU residency requirements; avoid replicating data outside EU without additional ADR approval.

## Governance & Runbooks
- Topic creation requires a change request documenting producers, consumers, schema references, and retention rationale. Maintain event catalog in `docs/event-catalog.md`.
- Schema changes follow review checklist: compatibility check, fixture updates, contract tests.
- DLQ runbook defines triage, reprocess, and discard procedures. Monitor DLQ volume and include KPIs in service dashboards.
- Incident playbooks cover broker failure, topic saturation, and schema incompatibility.

## Roadmap
1. **Phase 1**: Provision Kafka via Strimzi, deploy Schema Registry, establish baseline topics for raw ingest (`media.raw_ingest.v1`) and processed events (`media.ingested.v1`), integrate with observability.
2. **Phase 2**: Add Burrow/Kafka Lag Exporter, Cruise Control, GitOps-managed ACLs, and schema validation pipelines.
3. **Phase 3**: Configure MirrorMaker 2 for disaster recovery, introduce Kafka Connect for Postgres CDC and MinIO event sinks.
4. **Phase 4**: Implement multi-tenant quotas, evaluate tiered storage, automate schema compliance checks in PR workflows, and extend event catalog automation.

## References
- `ARCHITECTURE.md` and `DESIGN.md` for end-to-end workflow context.
- `SystemReqs.md` for Layer 4 requirements and roadmap alignment.
- `01_conf_mgmt/config-management.md` for configuration delivery and bootstrap guidance.
- `22_db_back/adr/0001-data-retention.md` for retention/residency constraints.
- `03_telemetry/observability-platform.md` for monitoring integrations.
