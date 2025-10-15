# Config CLI (ccm_consul)

## Purpose
`config-cli` is the platform’s Consul configuration orchestrator. It bootstraps containers from Consul KV, registers services with the catalog, and provides operators with repeatable import/export tooling. v2.0.0 deliberately removed Vault logic so the binary focuses on Consul-driven configuration while other subsystems handle secret delivery. The tool primarily targets the configuration management namespace/cluster, whose Consul + Vault pair also serves CI/CD workloads.

Primary jobs:
- Fetch environment-specific keys from Consul, transform them into environment variables, and launch the target process with those values.
- Register/deregister services with Consul (including health checks) so workloads participate in service discovery.
- Provide CLI workflows (`consul get/put/import/export`) for syncing versioned configuration files with Consul KV.
- Cache configuration locally to survive transient Consul outages.

## Architecture Overview
```
              +---------------------+
              |   config-cli run    |
              +----------+----------+
                         |
    +--------------------+--------------------+
    |                                         |
Consul KV                             Service Catalog
 (config values)                       (registration)
    |                                         |
    +-----------------+  +--------------------+
                      |  |
            Local cache (JSON)          Wrapped process
             (/etc/config-cli/...)      (app binary + env vars)
```

Key packages:
- `internal/commands`: CLI definitions (`run`, `consul ...`) built on `urfave/cli`.
- `internal/consul`: HashiCorp Consul client wrapper with retry/backoff, KV helpers, and service registration utilities.
- `internal/config`: Configuration item model, validation, disk cache, and versioned file helpers (`name.vN.yaml`).
- `internal/runtime`: Environment merge, process runner, signal handling.
- `internal/logging`: Slog-based JSON logging with level control (via `LOG_LEVEL`).

## Run Command Workflow
1. **Parse flags & args**: `config-cli run <service> --environment env --service-port 8080 -- ...`.
2. **Consul client**: uses `CONSUL_HTTP_ADDR`/`CONSUL_HTTP_TOKEN` (fallback `http://localhost:8500`).
3. **Fetch configuration**: `GetAllKeys()` reads `${environment}/${service}/` with exponential backoff and converts each key into a `ConfigurationItem`. On failure, the tool attempts to load the last JSON cache (`/etc/config-cli/config.cache` by default).
4. **Cache persistence**: successful retrieval writes to cache for future failover.
5. **Service registration**: constructs an `AgentServiceRegistration` (protocol, health check path, tags) and registers via Consul Agent API. Hostname is used if `--service-address` not provided.
6. **Signal handling**: background goroutine waits for SIGINT/SIGTERM and deregisters the service before exit (timeout 2s).
7. **Environment merge**: current environment merged with Consul keys (config overrides existing env vars; keys uppercased).
8. **Process execution**: `ProcessRunner` executes the wrapped command with merged env, streaming stdout/stderr.
9. **Exit handling**: after process exits, config-cli deregisters the service and returns the child exit code to the shell (preserving failures for orchestration systems).

## Manual Consul Operations
- `config-cli consul get <env/service/key>`: fetches a single key (validates path format).
- `config-cli consul put <env/service/key> <value>`: writes or updates a key.
- `config-cli consul import <service> <file> --environment env`: exports keys to a **versioned** file (`name.vN.yaml/json`). Optional `--version` rewrites the filename with the supplied version number.
- `config-cli consul export <service> <file> --environment env`: imports a versioned file back into Consul, validating path structure and writing each key via `PutAllKeys`.
- Versioned files enforce naming (`base.vN.yaml`) and prevent accidental overwrite unless the operator explicitly specifies a new version.

## Configuration & Caching
- Consul path convention: `<environment>/<service>/<key>`. Validation rejects anything outside the regex `^[a-z0-9\-]+/[a-z0-9\-]+/[a-z0-9_]+$`.
- Values are stored as strings but structured data can be encoded as JSON/YAML strings by convention.
- Cache: stored as pretty-printed JSON for auditability. Operators can change the path via `--cache-path` or delete with `Cache.DeleteCache()`.
- On Consul outage, cache load logs a warning but allows the service to start with stale configuration until Consul recovers.

## Logging & Observability
- All log output uses `log/slog` JSON format with context fields (`service`, `key_count`, `service_id`, etc.).
- `LOG_LEVEL`/`--log-level` controls verbosity (`DEBUG` useful for retry visibility).
- Startup banner: “configuration retrieved”, “service registered”, environment variable counts.
- Errors include context (e.g., invalid path, retry attempts). Import/export operations log key counts and operator tag (`manual`).
- Exit codes propagate to the caller; non-zero exit codes trigger `cli.Exit` with the child process code.

## Security & Operational Notes
- Requires network access to Consul and an ACL token when ACLs are enabled; tokens are pulled from `CONSUL_HTTP_TOKEN` and never logged.
- No secrets are pulled from Consul; sensitive values should be delivered via Vault/ExternalSecrets and merged by the wrapped process itself.
- Cache files may contain sensitive configuration; ensure filesystem permissions restrict access (default 0644).
- Ensure health check path matches the actual service endpoint—Consul will mark the service critical otherwise.
- Run inside containers with least privilege; avoid sharing tokens beyond the config-cli process.

## Integration Points
- **Consul Platform**: aligns with the service discovery strategy in `01_conf_mgmt/consul.md`; all services bootstrapped through config-cli appear automatically in the mesh.
- **CI/CD Pipelines**: runner pools and build jobs target the configuration management namespace’s Consul/Vault instances as their canonical source of configuration, using `config-cli` to render or inject runtime values during builds and deployments.
- **Application Containers**: Dockerfiles use multi-stage copy of `config-cli` as entrypoint; GitOps manifests set environment flags and health checks.
- **Home Edge / Bootstrap stacks**: leveraged to keep services configured even when Consul is intermittently unavailable thanks to the cache fallback.
- **Operational Tooling**: import/export commands support configuration reviews in Git by maintaining versioned YAML in repos.

## Roadmap Ideas
1. Add Consul namespace/partition support for multi-tenant clusters.
2. Expose `--deregister-on-failure=false` flag for long-running sidecars that should stay registered after crashes.
3. Optional structured diff output when importing/exporting config (validate drift before write).
4. Integrate with telemetry pipeline (Prometheus counters for runs, cache hits).
5. Evaluate Consul Connect registration (upstream/downstream intentions) in addition to basic service catalog entries.

## References
- System overview: `01_conf_mgmt/config-management.md`
- Implementation: `tools/ccm_consul/internal/`
- Specs: `tools/ccm_consul/specs/004-consul-only-lets/`
- Runbook guidance for Consul platform: `01_conf_mgmt/consul.md`
