# Echo Server Utility

## Purpose
`env-server` (a.k.a. echo_server) is a lightweight HTTP utility used in integration tests and local clusters to inspect environment variables, validate configuration, and run basic network diagnostics (ping, traceroute). It is **not** intended for production exposure; the service helps platform engineers verify container configuration, Vault auth state, and network reachability during build pipelines and home-edge deployments.

## Capabilities
- **Environment Inspection**: `GET /` renders all environment variables sorted alphabetically using an embedded HTML template (auto-escaped). The list is read on demand from `os.Environ()`.
- **Health & Stats**:
  - `GET /health` returns JSON with uptime, memory usage, and optional Vault auth state (if a JSON status file exists). Degraded auth status triggers HTTP 503.
  - `GET /stats` exposes aggregate request counts, success/error rates, and latency statistics.
  - `GET /metrics/history` returns a 60‑bucket time series (1‑minute buckets) with requests, errors, latency, and memory snapshots.
- **Prometheus Metrics**: `GET /metrics` serves Prometheus-formatted metrics; `GET /metrics/ping/{target}` surfaces per-target ping statistics.
- **Ping Management**: `POST /ping` starts a monitored ping loop; `GET /ping` lists active operations; `DELETE /ping/{target}` stops a running ping. Concurrency is guarded by a semaphore and configurable limits. Optional JSON config (`ping.config_file`) can pre-seed ping targets at startup.
- **Traceroute**: `GET /traceroute?target=&format=` or `POST /traceroute` (JSON) executes the system `traceroute` binary with configurable timeout/max hops and formats results (plain text or JSON).
- **Request Metrics**: All routes (except `/metrics`) are wrapped with middleware that records per-endpoint counters and response times into circular buffers used for p50/p95/p99 summaries.
- **Configuration Validation**: Binary flag `--validate-config` validates YAML/.env without starting the server.

## Configuration Model
- Config is expressed in YAML (see `tools/echo_server/config.example.yaml`) and loaded via `ConfigLoader`.
- **Precedence**: explicit environment variables (`APP_CONFIG_*`, `SERVER_PORT`, `CONFIG_FILE`, `PING_CONFIG_FILE`, `VAULT_AUTH_STATE_FILE`) → `.env` file → YAML config → embedded defaults.
- **Structure**:
  - `messages`: externalized templates for errors, warnings, informational strings, and help text. Templates support Go `text/template` placeholders (e.g., `{{.Port}}`). The `MessageRenderer` component injects values into responses/logs.
  - `server`: port (default 9999), read/write/shutdown timeouts, log level, Vault auth state path.
  - `ping`: concurrency limit, default timeout/interval/count, optional JSON config file path.
  - `traceroute`: concurrency limit, default timeout, default max hops.
- Validation enforces numeric ranges (e.g., port 1024–65535) and ensures unknown config keys emit warnings.
- Missing config/logging assets fall back to defaults and emit warnings (e.g., `.env` absent).

## Runtime Behaviour
- **Graceful Shutdown**: listens for SIGINT/SIGTERM, shuts down with configurable timeout, logs status via message templates.
- **External Dependencies**: relies on system `ping` and `traceroute` commands—missing binaries generate warnings and degrade endpoint functionality.
- **Auth State Integration**: optional Vault auth JSON file is merged into `/health` responses to surface “frozen” sessions.
- **Concurrency Control**: separate `ConcurrentRequestTracker` instances limit simultaneous ping and traceroute operations; hitting limits returns HTTP 429 with templated messages.
- **Metrics Engine**: `MetricsCollector` maintains rolling counters, circular buffer of response times (10k entries/endpoint), and rotating minute buckets for historical trends. Background goroutine rotates buckets and updates Prometheus gauges every 15s.

## Packaging & Tooling
- Makefile targets:
  - `make build-binary` / `make run-local` for local execution.
  - `make build` to containerize (`env-server:latest`).
  - `make test`, `make test-coverage`.
  - Registry helpers: `make registry-login`, `registry-build-push`, `registry-push`, `registry-validate` (supports Docker Hub, ECR, GCR, ACR, custom registries; see `docs/registry-examples.md`).
  - `make config-validate` leverages the binary `--validate-config`.
- Docker image listens on port 9999; health check typically points at `/health`.
- Makefile auto-tags with Git SHA when `AUTO_GIT_TAG=true`.

## Endpoints Summary
| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/` | HTML page enumerating environment variables. |
| `GET` | `/health` | JSON health (uptime, memory, Vault auth state). Returns 503 when degraded. |
| `GET` | `/stats` | Aggregate per-endpoint metrics (counts, latencies). |
| `GET` | `/metrics/history` | 60-minute historical metrics window. |
| `GET` | `/metrics` | Prometheus metrics export. |
| `GET` | `/metrics/ping/{target}` | Ping metrics for a specific target. |
| `GET` | `/traceroute` | Run traceroute with query parameters (`target`, `format`). |
| `POST` | `/traceroute` | Run traceroute via JSON payload. |
| `POST` | `/ping` | Start monitored ping (JSON body). |
| `GET` | `/ping` | List active ping sessions. |
| `DELETE` | `/ping/{target}` | Stop an active ping. |

## Security & Usage Notes
- Designed for controlled test environments; do not expose publicly. If deployed in shared environments, restrict access via network policies or API gateway.
- No built-in authentication; rely on surrounding infrastructure (e.g., Consul API Gateway + forward-auth) when necessary.
- Ping/traceroute endpoints execute system commands; sandbox appropriately and run in least-privilege containers.

## Integration Points
- **Home Edge / Show Env Mesh**: Docker Compose stacks (`0_mediaInfra/00_show_env_mesh`) consume the pre-built `env-server` image for config validation inside home lab deployments.
- **Observability**: Prometheus-compatible metrics feed the platform observability stack; `/metrics/history` provides JSON for ad-hoc inspection without Prometheus.
- **Vault**: `/health` optionally surfaces Vault auth state to assist in diagnosing frozen sessions.

## References
- Implementation: `tools/echo_server/src/`
- Configuration example: `tools/echo_server/config.example.yaml`
- Registry guidance: `tools/echo_server/docs/registry-examples.md`
- Configuration externalization spec: `tools/echo_server/specs/005-externalize-configuration-lets/`
