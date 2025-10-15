# ADR 0001: Data Retention and Residency

## Status
Accepted

## Context
System requirements previously deferred decisions about how long to retain media assets, metadata, and telemetry, as well as where data must reside. Lack of clarity blocks storage sizing, lifecycle policy, and compliance planning across MinIO, PostgreSQL, Kafka, and observability stacks.

## Decision
Store primary media assets and metadata in the eu-central region (Frankfurt) to satisfy current stakeholder expectations for EU residency. Retain assets indefinitely unless explicit takedown requests arrive; derived artifacts follow the same lifecycle. Telemetry data (metrics, traces, logs) will keep 30 days of hot storage and archive raw logs to cold storage for 180 days.

Key policies:
- MinIO buckets use versioning with a quarterly review for stale assets; manual curation handles removals.
- PostgreSQL snapshots retained for 35 days with weekly off-site copies in a secondary EU region.
- Kafka topics keep seven days of history plus compacted streams for metadata change topics.
- Prometheus retains 30 days; traces (Jaeger/Tempo) keep 14 days; Loki retains 30 days hot and exports monthly archives to cold storage within the EU.

## Consequences
- Storage planning must consider indefinite growth of media buckets; implement cost monitoring and quota alerts.
- Backup and archival automation must respect EU boundaries; cross-region replication limited to EU data centers.
- Downstream consumers (search, analytics) need to purge derived indexes when assets are deleted to honor takedown requests.
- Future multi-region work must keep replicas inside EU or document exceptions via additional ADRs.
