# Backend Media Server Overview

MyFarsi's backend media platform ingests heterogeneous content, persists binaries and metadata durably, and exposes curated assets through well-governed APIs. This overview extends `ARCHITECTURE.md` with design intent, contract details, and operational guardrails for each layer.

## Layered Stack
The platform layers map to the numbered directories in the repo. Treat the layers as seams for ownership and deployment.

- **Layer 1 - CI/CD & Build Infrastructure** (`02_cicd_mgmt/`)<br>
  Self-hosted runners, registry, and GitOps tooling create signed artifacts and promote changes through environments. Each service exports a `Makefile` target consumed by the pipelines. See `02_cicd_mgmt/cicd-runner.md` and `02_cicd_mgmt/docker-registry.md`.
- **Layer 2 - Configuration, Secrets & Mesh** (`01_conf_mgmt/`)<br>
  Consul supplies runtime configuration, DNS, and service discovery; Vault issues workload identities and secrets; Envoy-based mesh gateways enforce ingress and east-west policy (`01_conf_mgmt/consul.md`, `01_conf_mgmt/mesh-gateway.md`). Workloads bootstrap via `90_cli_tools/config-cli.md`.
- **Layer 3 - Observability** (`03_telemetry/`)<br>
  OpenTelemetry Collector receives OTLP signals and routes metrics to Prometheus, traces to Jaeger, and logs to the central aggregation stack (`03_telemetry/observability-platform.md`, `03_telemetry/tracing-platform.md`). Dashboards monitor ingestion latency, Kafka lag, error budgets, and storage health.
- **Layer 4 - Data & Storage** (`20_`, `21_`, `22_`, `23_` directories)<br>
  PostgreSQL (fronted by PostgREST) stores metadata, MinIO holds binaries, search services index derived content, and Kafka provides durable fan-out (`22_db_back/postgres-api-platform.md`, `21_content_manager/minio-content-server.md`, `23_search_back/search-elasticsearch.md`, `20_central_bus/kafka-messaging-bus.md`).
- **Layer 5 - Business Logic & APIs** (`31_`, `40_`, `50_`, `51_`, `52_` directories)<br>
  Ingestion, enrichment, and presentation services orchestrate claim-check workflows, emit domain events, and expose authenticated APIs (`31_Extraction/media-platform.md`, `51_Presentation_back/logic-router.md`, `50_public_cms/` roadmap).

## Event-Driven Flow
1. **Ingest**: Clients authenticate via the API gateway. Ingestion services validate payloads, stage binaries in MinIO, record pre-ingest metadata, and publish pointer events on Kafka topics (`ingest.raw`).
2. **Persist**: Storage Persistor consumes pointer events, performs idempotent moves to durable buckets, writes normalized metadata through PostgREST, and emits `media.ingested`.
3. **Enrich**: Processing services subscribe to `media.ingested`, fetch assets, derive representations (text extraction, thumbnails), update metadata/search indexes, and emit follow-on events such as `media.enriched`.
4. **Serve**: Presentation services answer queries via REST/GraphQL endpoints, combining PostgREST data with search indices. Edge access uses Authentik-issued tokens and mesh policies.

Exactly-once semantics are approximated with Kafka idempotent producers, transactional writes, and idempotent consumers. Dead-letter topics capture poison events; runbooks for redrive live beside each service.

## Cross-Cutting Design Decisions
- **Contracts**: All event payloads register JSON schemas in Schema Registry. Pull requests that modify schemas must update fixtures and compatibility tests (`20_central_bus/kafka-messaging-bus.md`).
- **Identity**: Authentik manages user and service identities; mesh mTLS plus Vault-issued certificates secure service calls (`11_athentik_user/authentication.md`).
- **Configuration Policy**: Consul KV is the canonical configuration store; changes go through GitOps workflows. Services read configuration at startup and watch for changes when supported.
- **Security Posture**: Secrets never enter repositories. Vault + ExternalSecrets deliver runtime credentials. Every public endpoint enforces Authentik or gateway JWT validation.
- **Governance**: Architectural decisions are tracked via per-domain ADRs (create `adr/` subdirectories as designs evolve). `AGENTS.md` sets repo-wide contribution rules.

## Quality & Operations
- **Testing**: Require unit + integration coverage per layer. Kafka, PostgREST, and MinIO integrations must have smoke tests before cross-domain promotion. Capture anonymized fixtures under the owning directory.
- **Resilience**: Operate Kafka in KRaft mode with replication factor 3. Enable MinIO versioning and scheduled PostgreSQL snapshots. Validate Vault token rotation and Consul snapshot automation quarterly.
- **Deployability**: Each service exports `make build`, `make test`, `make deploy`. CI pipelines verify linting (`npx markdownlint-cli2` for docs, language-specific tooling for code), run tests, and sign container images.
- **Observability**: Emit OTLP logs/metrics/traces with consistent attribute naming (`service.name`, `deployment.env`). Dashboards and alert policies live under `03_telemetry/`.
- **Documentation**: When implementing or changing a service, update its directory README, adjust architecture/design docs, and record open questions in `prime_directives_and_constiruations.txt` until answered.

This design keeps services loosely coupled, enables incremental delivery across domains, and provides enough platform scaffolding to scale into multi-region deployments once requirements demand it.
