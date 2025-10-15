# System Requirements - MyFarsi Platform

## Scope
This document captures functional and non-functional requirements for the MyFarsi media platform across Layers 1-5. It aligns with the current repository layout, where numbered directories own designs, runbooks, and implementation plans. Use this specification to validate new work, track delivery status, and surface open questions that need conversion into ADRs.

## Current State Overview
| Layer | Directory Roots | Status | Notes |
| --- | --- | --- | --- |
| Layer 1 - CI/CD & Build | `02_cicd_mgmt/` | Designed | Runners, registry, and GitOps workflow defined; implementation pending hardware allocation. |
| Layer 2 - Config, Secrets, Mesh | `01_conf_mgmt/`, `90_cli_tools/` | Designed | Consul, Vault, mesh gateway, and config-cli specifications ready; requires integration with Layer 1 pipelines. |
| Layer 3 - Observability | `03_telemetry/` | Designed | Collector, metrics, tracing documents complete; deployment awaits infrastructure from Layers 1-2. |
| Layer 4 - Data & Storage | `20_central_bus/`, `21_content_manager/`, `22_db_back/`, `23_search_back/` | Designed | Kafka, MinIO, PostgREST/PostgreSQL, and search backends specified; depends on platform services for secrets and telemetry. |
| Layer 5 - Business & Presentation | `31_Extraction/`, `40_ai/`, `50_public_cms/`, `51_Presentation_back/`, `52_Presentation_front/` | Partially Designed | Core claim-check workflow defined; presentation layers require detailed specs and UI/service contracts. |

Implementation proceeds from Layer 1 upward. Each layer must expose health probes, metrics, and configuration interfaces before dependent layers graduate from design to development.

## Functional Requirements
### Layer 1 - CI/CD & Build Infrastructure
- Provide reproducible builds for every service using make targets (`make test`, `make build`, `make package`).
- Host a private registry with signed images and provenance metadata.
- Run self-hosted runners capable of Docker-in-Docker and Kubernetes builds; tag runners for workload routing.
- Enforce GitOps flow: changes land in Git, automation promotes artifacts, and environments sync via Argo CD or equivalent.

### Layer 2 - Configuration, Secrets, Mesh
- Consul: supply service discovery, KV configuration, and health checking; expose HTTP (8500) and DNS (8600) endpoints.
- Vault: manage secrets and workload identities; rotate certificates automatically; integrate with Consul Connect.
- Mesh gateway: Envoy-based ingress supporting JWT validation, rate limiting, and mTLS passthrough for internal services.
- Config bootstrap: `config-cli` hydrates workloads from Consul/Vault before application startup; tooling runs locally and in CI.

### Layer 3 - Observability
- OpenTelemetry Collector must accept OTLP/gRPC and OTLP/HTTP input from all services.
- Metrics stored in Prometheus with dashboards for ingestion latency, Kafka lag, storage saturation, and error budgets.
- Traces captured in Jaeger or Tempo with 7-day retention and sampling policies defined per service criticality.
- Logs routed to centralized storage (Loki or ELK). Enforce structured logging with trace correlation IDs.

### Layer 4 - Data & Storage
- Kafka (KRaft mode, RF=3) supplies durable messaging, schema validation via Schema Registry, and dead-letter topics per critical stream.
- MinIO provides S3-compatible object storage with versioning and lifecycle policies; supports staging and durable buckets.
- PostgreSQL behind PostgREST exposes RESTful metadata access; migrations tracked via GitOps; backups automated daily.
- Search stack (OpenSearch/Elasticsearch) indexes enriched assets; connectors ingest from Kafka or PostgREST change feeds.

### Layer 5 - Business Logic & Presentation
- Ingestion services accept authenticated uploads, validate payloads, stage objects, and emit `ingest.raw` events.
- Storage Persistor moves staged objects to durable buckets, writes metadata through PostgREST, and produces `media.ingested`.
- Processing services subscribe to `media.ingested`, enrich assets, update metadata/search, and emit `media.enriched`.
- Presentation APIs expose search/read operations with Authentik-backed tokens and mesh policies. Front-end clients consume these APIs and respect rate limits.

## Non-Functional Requirements
- **Security**: No secrets in source control. Vault policies and Consul ACLs must be documented per service. All network paths protected by mTLS where supported.
- **Reliability**: Layer 2+ components must sustain single-node failures. Kafka, PostgreSQL, and MinIO require backup and restore runbooks.
- **Scalability**: Support at least 10 instances per service with horizontal scaling for Kafka consumers and ingestion services.
- **Compliance**: Maintain audit logs for configuration changes, deployments, and authentication events. Retain logs for minimum 90 days.
- **Operability**: All services expose readiness/liveness endpoints, metrics at `/metrics`, and trace exporters. Provide runbooks for restart, failover, and incident response.

## Implementation Roadmap
1. **Layer 1 Bring-up**: Stand up CI/CD runners, registry, and GitOps control plane. Validate build/test/deploy automation against sample services (`90_cli_tools/echo-server.md`).
2. **Layer 2 Integration**: Deploy Consul, Vault, mesh gateway; wire config-cli into build pipelines; validate ACL/AppRole policies.
3. **Layer 3 Instrumentation**: Launch OpenTelemetry Collector, Prometheus, Jaeger, and logging sink. Instrument sample services to confirm end-to-end telemetry.
4. **Layer 4 Deployment**: Provision Kafka, PostgREST/PostgreSQL, MinIO, and search stack. Configure schema compatibility tests and backup schedules.
5. **Layer 5 Services**: Implement ingestion and persistence services, followed by processing and presentation layers. Ensure all services register with Consul, emit telemetry, and satisfy contracts.
6. **Cross-Layer Hardening**: Run chaos drills (broker loss, Vault outage), document recovery procedures, and update ADR indexes per domain.

## Recent Decisions
- Initial hosting platform: Layer 1 services run on an Equinix Metal-backed Kubernetes cluster (`02_cicd_mgmt/adr/0001-hosting-platform.md`).
- Data retention and residency: Primary data remains in EU regions with defined retention windows for each store (`22_db_back/adr/0001-data-retention.md`).
- Presentation API style: Adopt versioned REST APIs with OpenAPI contracts (`51_Presentation_back/adr/0001-api-contract.md`).
- Third-party secret rotation: Manage external credentials through Vault with automated rotation workflows (`01_conf_mgmt/adr/0001-secret-rotation.md`).

## References
- `ARCHITECTURE.md` - platform topology and workflow view.
- `DESIGN.md` - detailed design guidance by layer.
- Domain-specific specs under numbered directories (see table above).
- `AGENTS.md` - contributor workflow and coding conventions.
