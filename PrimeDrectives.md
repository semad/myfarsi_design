Prime Directives
----------------
1. Learn, experiment, and have fun while building; research mindset beats production polish at this stage.
2. Externalize configuration — `.env`, YAML, or Consul/Vault — never hard-code.
3. Preferred toolchain: `make` ➔ `bash` ➔ Go ➔ Python; lean on CLI-driven workflows.
4. Support every environment tier (local, home lab, staging, cloud) with near-identical tooling.
5. Default to automation: CI/CD orchestrates builds, tests, lint, and deploys.
6. Observe everything: metrics, logs, traces, and configuration history are mandatory.
7. Mesh mindset: services discover each other through Consul and communicate over Kafka as the shared bus.

Constitutional Practices
------------------------
- **Container-first**: Docker/Compose for local dev; Kubernetes for shared environments.
- **Makefile entrypoint**: every service exposes `make build`, `make test`, `make run`.
- **Centralized control plane**: Consul for config/service discovery; Vault for secrets.
- **API-oriented**: PostgREST, Logic Router, and CLI tools expose functionality programmatically.
- **Instrumentation required**: Prometheus, Loki, Tempo wired into all services.
- **Database-as-code**: Schemas and migrations live in Git, managed via Atlas.
- **Async workloads**: background workers and Kafka topics handle long-running tasks.
- **CLI emphasis**: tooling favors terminal workflows for consistency and automation.
- **Spec before code**: design docs and contracts precede implementation.
- **Layered testing**: unit, integration, contract, and smoke tests run in CI before deploy.
