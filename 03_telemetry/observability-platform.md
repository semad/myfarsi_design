# Observability Platform

## Mission
Provide unified metrics, logs, and traces across MyFarsi services so teams can detect issues quickly, understand user journeys, and meet reliability targets.

## Stack Overview
```
Services/Agents ──► OpenTelemetry Collector ──► Prometheus (metrics)
                                                  Tempo (traces)
                                                  Loki/OpenSearch (logs)
                                       Grafana + Alertmanager for visualization & alerting
```
- Services emit OTLP data (metrics/traces/logs). Collectors run as DaemonSet and/or gateway.
- Prometheus handles metrics scraping and alert evaluation; remote-write to Thanos optional later.
- Loki (or OpenSearch) stores logs collected via Fluent Bit DaemonSet.
- Tempo retains traces; Jaeger UI optionally exposed for developers.
- Grafana provides dashboards, SSO via Authentik, and visualizes all data sources.

## Environments
| Environment | Delivery | Notes |
| --- | --- | --- |
| Local | `docker-compose.observability.yml` (Prometheus, Loki, Tempo, Grafana, OTEL collector) | Starts with `make obs-up`; no auth, short retention. |
| Staging/Prod | Helm-based install (`kube-prometheus-stack`, `tempo`, `loki-stack`) in namespace `observability` | Uses Consul Connect mTLS, integrates with Authentik for Grafana login, retention tuned per environment. |

## Instrumentation Standards
- **Metrics**: `service_operation_metric{env,service,route}` naming; latency histograms share bucket config. Services expose `/metrics` via Prometheus client libs.
- **Logs**: JSON with keys `timestamp`, `level`, `service`, `env`, `trace_id`, `span_id`, `user`, `msg`. Mask secrets before emission; Fluent Bit filters enforce redaction.
- **Traces**: W3C Trace Context (`traceparent`, `tracestate`), `baggage` for optional metadata. Sampling baseline: home 10%, staging 5%, prod 1% + tail-based rules for errors/slow spans.
- **Dashboards**: Standard templates per subsystem (Identity, CMS, MinIO, Postgres, Search, Infrastructure). Variables include `env`, `service`, `namespace`.
- **Alerts**: Severity levels (info/warn/critical), routed via Alertmanager to Slack/email/PagerDuty depending on service ownership.

## Key Components
| Component | Responsibilities |
| --- | --- |
| OpenTelemetry Collector | Receives OTLP, batches, exports to Prometheus remote write, Tempo, Loki; tail-based sampling (future). |
| Prometheus + Alertmanager | Scrape metrics (kube-state-metrics, node-exporter, service exporters), evaluate alert rules, deliver notifications. |
| Loki + Fluent Bit | Collect and index logs; support label-based search; optional log retention tiers. |
| Tempo | Store traces with object storage backend (S3/MinIO). |
| Grafana | Unified UI; dashboards as code; integrates with Authentik via OIDC; RBAC for viewers/admins. |

## Observability Catalog (Initial Dashboards/Alerts)
| Service | Dashboard Focus | Sample Alerts |
| --- | --- | --- |
| Authentik / Forward-Auth | Login throughput, failures, latency | Login failure rate >10% (5m), forward-auth p95 >300 ms |
| CMS | Workflow backlog, API latency, job queue depth | Queue depth >100 (10m), publish failures >5% |
| MinIO | Capacity, request rate, errors | Free storage <20%, signed URL errors spike |
| PostgREST | Request stats, DB connections, latency | p95 latency >300 ms, connection saturation |
| Search | Query volume, zero-result %, indexer throughput | Zero-result rate >40%, index failure burst |
| Platform | Cluster health, resource usage | Node not-ready, etcd/Consul issues (fed from exporters) |

## Security & Access
- Grafana OIDC via Authentik; groups `obs-viewers`, `obs-admins`.
- NetworkPolicies restrict Prometheus/Tempo/Loki to trusted namespaces; admin ingress protected via Consul API Gateway + forward-auth.
- Fluent Bit sanitizes tokens/passwords; dynamic allowlist to prevent PII leakage.
- TLS everywhere via Consul Connect or cert-manager; rotate certificates automatically.

## Data Retention
- Metrics: 15 d local retention (staging/prod). Evaluate Thanos/remote-write for >90 d.
- Logs: 30 d in Loki by default; archive to S3 if compliance requires. Local dev retention minimal.
- Traces: 7 d in Tempo (staging/prod); high-value traces optionally exported to cold storage.

## Operations
- Helm charts stored under `charts/observability-stack`; GitOps manages values per environment.
- CI pipeline validates dashboards/alert rules (`grafanalib`, `promtool`, `tempo-check`).
- Runbooks: Prometheus scale-out, Loki label explosion mitigation, Tempo ingestion failures, collector sampling adjustments.
- Backups: configuration stored in Git; data backups handled via storage snapshots/object storage versioning.

## Roadmap
1. Phase 1: Deploy stack in staging, onboard core services, build baseline dashboards/alerts.
2. Phase 2: Integrate Alertmanager routes (Slack, PagerDuty), enable log parsing for gateway/Envoy, add synthetic monitoring (Blackbox Exporter/k6).
3. Phase 3: Implement SLO dashboards and error-budget policies; adopt tail-based sampling; automate dashboard/alert provisioning via GitOps.
4. Phase 4: Multi-cluster federation (Thanos, Loki ruler), anomaly detection, business-level observability (user journeys, funnel analytics).

## References
- Identity (`11_athentik_user/authentication.md`)
- Content (`01_conf_mgmt/content-management.md`)
- Storage (`21_content_manager/minio-content-server.md`)
- Search (`23_search_back/search-elasticsearch.md`)
- CI/CD (`02_cicd_mgmt/cicd-runner.md`)
