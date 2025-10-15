# Tracing Strategy

## Goal
Capture end-to-end traces for API calls, background jobs, and external integrations so latency hotspots and errors surface quickly. This document expands on the observability blueprint with tracing-specific guidance.

## Architecture
```
Services (Go, Node, Python) ─► OpenTelemetry SDKs ─► OTLP ─► OpenTelemetry Collector ─► Tempo ─► Grafana
                                                ▲
                                                └─ Consul API Gateway / forward-auth (Envoy) emits spans
```
- Collector runs as DaemonSet (agent mode) and as gateway; applies batching, attribute enrichment, and sampling.
- Tempo stores traces with S3-compatible backend; Grafana Explore visualizes.
- CLI tooling (`tempo-cli`, `ttrace`) fetch traces directly.

## Propagation
- Adopt W3C Trace Context (`traceparent`, `tracestate`) and `baggage`. Forward-auth preserves headers during redirects/login.
- gRPC uses metadata keys mirroring HTTP headers.
- Cloudflare tunnel configured to allow custom headers; verify no proxies strip trace headers.
- Background jobs propagate trace context via message headers (Kafka) or store parent trace ID for linking.

## Instrumentation Patterns
- **Go**: shared `internal/observability/tracing` package sets tracer provider and resource attributes. Wrap HTTP handlers with `otelhttp`, gRPC with `otelgrpc`. Annotate DB calls (`db.system=postgres`), cache hits, external API calls. Use `otelmetric` to correlate metrics.
- **Node/Python**: auto-instrumentation packages where possible (Express, FastAPI). Provide helper module to standardize resource attributes, exporter config, sampling flags.
- **Workers**: root span per job execution (`job.name`, `schedule`, `trigger`). Link to originating request via `SpanLink` if context not preserved.
- **GitHub Actions/CLI**: optional `opentelemetry-instrument` to trace critical automation (smoke tests, deploy scripts).
- **Third-parties**: wrap HTTP clients; capture `net.peer.name`, `http.url` (sanitized), `external.correlation_id`.

## Sampling
- Baseline probabilistic rates:
  - Home: 10%
  - Staging: 5%
  - Production: 1% plus rules
- Collector tail-based sampling retains:
  - Error spans (`status.code != OK`)
  - Spans with duration > 500 ms
  - Specific routes (`/login`, `/upload`) at 100%
- Sampling config stored in Consul KV; collector watches for changes to avoid redeploys.
- For stress debugging set `TRACE_DEBUG=1` to force 100% sampling locally.

## Storage & Retention
- Tempo retention: 7 d (staging) / 3 d (prod). Expand via object storage if necessary.
- Archive critical traces (manual export) for incident reports.
- Keep object storage lifecycle to purge after retention window.

## Developer Workflow
- `make obs-up` spins up local stack with 100% sampling.
- Logging includes `trace_id` & `span_id`; Grafana links from logs/metrics to traces.
- CLI helpers:
  - `obsctl trace find --service logic-router --route /api/v1/content --last 30m`
  - `obsctl trace show <trace-id>`
- Integration tests can assert on span attributes by exporting to in-memory collector.

## Governance
- Every new service must wire OpenTelemetry before production.
- Code reviews check for:
  - Root span coverage
  - Attributes for major operations (db, external calls)
  - Low-cardinality attribute names
  - No secrets/PII recorded
- Track coverage metric: percentage of requests with trace data per service; alert if below threshold.
- Document instrumentation checklist in `CONTRIBUTING.md`.

## Roadmap
1. Phase 1: Instrument forward-auth, API gateway routes, CMS, PostgREST, Logic Router; baseline dashboards.
2. Phase 2: Tail-based sampling, exemplars linking Prometheus latency metrics to traces, background job coverage.
3. Phase 3: Service dependency graph, synthetic tracing (probe key flows), automated anomaly detection.
4. Phase 4: Multi-region trace aggregation, optional export to managed APM, retention extension for compliance.

## References
- Observability platform (`designs/observability-platform.md`)
- Logic Router (`designs/logic-router.md`)
- Service-specific designs for instrumentation points.
