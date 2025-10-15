# Kafka Operations Runbook

## Purpose
Provide on-call guidance for the Kafka cluster described in `20_central_bus/kafka-messaging-bus.md`. This runbook covers daily checks, incident response, and recovery tasks for the MyFarsi messaging backbone.

## Environment Overview
- **Cluster**: Kafka 3.x (KRaft) with three brokers per environment; controllers colocated.
- **Deployment**: Managed by Strimzi operator on Kubernetes (`central-bus` namespace).
- **Supporting Services**: Schema Registry, Kafka Exporter, Burrow, Cruise Control, MirrorMaker (future).
- **Storage**: SSD/NVMe volumes sized for 30-day retention; replication factor 3.

## Daily Checks
1. Grafana dashboard `Messaging / Kafka`:
   - `kafka_server_replicamanager_underreplicatedpartitions` == 0.
   - Broker disk usage < 70%.
   - Controller changes steady (no spikes).
2. Burrow consumer lag panels: investigate lag > threshold.
3. Schema Registry compatibility job in CI green.
4. Review alerts from the last 24h and ensure acknowledgements.

## Weekly Tasks
- Cruise Control rebalance review; remediate proposals as needed.
- Verify Kafka Exporter scrape success (`up{job="kafka-exporter"} == 1`).
- Check topic retention vs. disk growth; adjust retention or add brokers if trending high.
- Review DLQ topics for messages needing remediation.

## Incident Response
### Under-Replicated Partitions (URP)
1. Identify broker(s): `kubectl logs <broker-pod>` or `kafka-topics --describe`.
2. Restart affected broker if pod unhealthy; confirm ISR returns to size 3.
3. If disk full, expand storage or purge old topics (after sign-off).
4. Use Cruise Control `rebalance` if imbalance persists.

### Broker Pod CrashLoop
1. Check pod events (`kubectl describe pod`).
2. Inspect logs for storage or auth errors.
3. Ensure PVC attached; if corrupted, replace PVC (data loss risk – confirm replication first).
4. Monitor cluster to confirm controller elections stabilize.

### Elevated Consumer Lag
1. Identify consumer group via Burrow.
2. Verify consumer deployment status and logs.
3. Assess throughput spikes; scale consumer replicas if needed.
4. Communicate with owning team; consider pausing producers if backlog threatens SLO.

### Schema Incompatibility
1. Roll back offending deployment.
2. Update Schema Registry with compatible schema version.
3. Replay DLQ messages after validation.

### Authentication Failures
1. Check SASL/OAuth token expiry; refresh Authentik client credentials.
2. Ensure Vault-issued certs valid; rotate if near expiry.
3. Validate ACL definitions via GitOps; reapply if drift detected.

## Maintenance Procedures
- **Add Broker**: Scale Strimzi `Kafka` resource; wait for sync; run Cruise Control `rebalance`.
- **Rolling Upgrade**: Use Strimzi upgrade path; verify compatibility; monitor during rollout.
- **Garbage Collect Topics**: Use `kafka-topics --delete` (after retention confirmation); update GitOps manifest to avoid recreation.
- **ACL Updates**: Submit PR to ACL manifests; pipeline applies via automation.

## Backup & Recovery
- MirrorMaker (when enabled) replicates to DR cluster. Until then, rely on event replay from source systems.
- For catastrophic loss:
  1. Recreate cluster via Strimzi.
  2. Reapply topic/ACL configurations from GitOps.
  3. Notify teams to replay events from upstream sources or archives.

## Verification after Changes
- Produce/consume smoke test topic (`ops.smoketest.v1`).
- Check Grafana dashboards for stability 30 minutes post-change.
- Confirm Burrow reports healthy consumer status.
- Document actions in incident tracker.

## Contacts
- Messaging on-call: `#oncall-kafka` / PagerDuty `Messaging`.
- Platform SRE: `platform-sre@myfarsi.dev`.
- Data platform stakeholders for schema decisions.

## References
- `20_central_bus/kafka-messaging-bus.md`
- `docs/events/event-catalog.md`
- Strimzi documentation: <https://strimzi.io/docs/>
- Apache Kafka docs: <https://kafka.apache.org/documentation/>
