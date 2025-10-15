# Logic Router

## Purpose
Provide a cohesive API layer that aggregates services behind Consul API Gateway so external clients see a consistent contract while internal services evolve independently.

## Responsibilities
- Terminate authenticated traffic (trusting forward-auth headers), apply RBAC, rate limits, and localization policies.
- Fan out to downstream services (CMS, Search, PostgREST, MinIO control) and compose responses.
- Offer versioned REST/GraphQL endpoints with backward compatibility guarantees.
- Emit observability signals for every request and capture audit trails for sensitive operations.

Non-goals: replace the API Gateway (TLS, coarse routing remain there), maintain long-running workflows, or act as a persistent store.

## Architecture
```
Client → Cloudflare / Consul API Gateway → Logic Router → Backend Services
                                                │
                                                ├─ CMS (content, workflow)
                                                ├─ Search (Elasticsearch)
                                                ├─ PostgREST (profiles, metadata)
                                                ├─ MinIO control (uploads)
                                                └─ Authentik APIs (optional)
```
- Implemented in Go with modular handler pipeline.
- Configuration-driven routing stored in GitOps repo (`apps/logic-router`) and synced via Argo CD.
- Runs on Kubernetes (`gateway` namespace) with HPA scaling on CPU/QPS.

## Routing & Policy Model
Routes defined declaratively:
```yaml
routes:
  - id: content-search
    match:
      path: /api/v1/content/search
      methods: [GET]
    handler: searchProxy
    policies: [auth-required, rate-limit-standard, attach-locale]
    backend: search
  - id: article-detail
    match:
      path: /api/v1/content/articles/{slug}
      methods: [GET]
    handler: articleAssembler
    backends:
      - cms
      - minio
    policies: [auth-optional, cache-60s]
```
- Policies executed as middleware (auth checks, RBAC, quota enforcement, schema validation, caching).
- Config hot-reloaded from ConfigMap/Consul KV; validation pipeline ensures syntax correctness.

## Key Modules
- **ArticleAssembler**: Fetches article metadata from CMS, obtains signed URLs from MinIO control, applies localization fallback, returns aggregated payload.
- **SearchProxy**: Adds user context (groups, locale) to search queries, enriches hits with personalization data.
- **ProfileGateway**: Bridges Authentik profile APIs and PostgREST identity tables; ensures audit logging.
- **UploadBroker**: Validates user quotas, requests upload session, records manifest for StoragePersistor.
- **TelemetryDecorator**: Injects correlation IDs, latency metrics, optional debug headers for non-prod.

## Security
- Requires `x-auth-user` / group headers; fallback to 401 if missing when `auth-required`.
- Additional RBAC mapping (`cms-author`, `cms-editor`) stored in configuration; denies logged in group mismatch.
- Service tokens/API keys validated via Authentik introspection endpoint.
- Request/response schema validation using JSON Schema to guard downstream services.
- Rate limiting backed by Redis cluster; fallback to Envoy rate limit service if available.
- Outbound calls use Consul Connect sidecars (mTLS).

## Observability
- Metrics: `logic_router_requests_total{route,status}`, `logic_router_request_duration_seconds`, `logic_router_backend_errors_total`.
- Logs: JSON structured with user, route, trace ID, backend statuses; no sensitive payloads.
- Traces: OpenTelemetry instrumentation; child spans for backend calls with attributes `backend`, `status`, `retry`.
- Dashboards show request mix, tail latency, error spikes; alerts trigger on error ratio, backend circuit breaker trips, rate limiter saturation.

## Deployment
- Helm chart packages deployment, service, configmap, and RBAC.
- CI pipeline builds Go binary, runs unit/integration tests, publishes container image, updates GitOps overlays.
- Argo CD syncs staging, then prod after approval; config changes follow same PR path.
- Canary strategy: duplicate route with `header=canary` match or use Consul service subsets.

## Local Development
- `make run-local` loads `config/dev.yaml` and starts router with mocked services.
- Integration tests using `httptest` simulate upstream responses and snapshot outputs.
- Contract tests validate route definitions against JSON Schema in `testdata/contracts`.

## Roadmap
1. Phase 1: implement core REST endpoints (search, articles), authentication middleware, baseline metrics.
2. Phase 2: add profile management, upload orchestration, response caching, declarative policy engine.
3. Phase 3: optional GraphQL facade, feature-flagged routing, circuit breaker with fallback cache.
4. Phase 4: multi-tenant support, weighted routing for experiments, request replay tooling for incident analysis.

## References
- Identity (`11_athentik_user/authentication.md`)
- Content (`01_conf_mgmt/content-management.md`)
- Storage (`21_content_manager/minio-content-server.md`)
- Search (`23_search_back/search-elasticsearch.md`)
- Observability (`03_telemetry/observability-platform.md`)
