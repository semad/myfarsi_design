# myfarsi_design

## Overview
`myfarsi_design` hosts the source for the MyFarsi platform design docs and supporting automation. Markdown sources are kept authoritative for product, platform, and on-call teams.

## Repository Layout
- `00_coding_req` — product requirements and language preferences for new workstreams.
- `01_conf_mgmt` — Consul and Vault paths referenced by service samples.
- `02_cicd_mgmt`, `02_vault_srv` — delivery infrastructure and vault service automation.
- `03_telemetry` — observability specs and dashboards.
- `10`–`52` — runtime services (each must provide its own `README.md`, Makefile, and runbook).
- `src/` — reusable helpers; `specs/` — shared interface definitions; `docs/` — global documentation including runbooks and on-call indexes.
- `tests/` — language-agnostic regression suites; co-locate Go tests beside sources when needed.

## Prerequisites
- Node.js 20.x for `npx markdownlint-cli2`.
- Git configured with access to the upstream repository.

## Key Commands
- `make toc` — regenerate README.md with embedded table of contents from tracked Markdown files.
- `make test` — lint and format Markdown files with markdownlint & prettier.
- `npx markdownlint-cli2 "**/*.md"` — lint Markdown as enforced by CI.
- `go test ./...` (inside `90_cli_tools`) — verify Go-based CLI tooling.
- `pytest -q` or `npm test -- --runInBand` — run language-specific suites; document the chosen command inside the service/module README.

## Development Workflow
1. Extend or create service directories following the numbering scheme; update `ARCHITECTURE.md`, `DESIGN.md`, and `SystemReqs.md` when structure changes.
2. Prefer Make targets over ad hoc scripts; if new automation is required, wire it into `Makefile` before adding Bash, Go, Python, or JS.
3. Keep credentials out of samples. Reference Vault/Consul keys exactly as modeled in `01_conf_mgmt` and capture network mesh changes in service READMEs.

## Testing & Quality Gates
Run smoke tests for every enhancement and add integration coverage whenever Kafka, PostgREST, or MinIO components change. Refresh anonymized fixtures with schema updates and record coverage deltas in pull requests. Lint Markdown before opening a PR and ensure any language-specific formatters (e.g., `gofmt`, `black`, `prettier`) leave the tree clean.

## Contributing
Use Conventional Commits (`feat:`, `fix:`, `chore:`) and supply pull-request descriptions with the problem statement, solution summary, links to design artifacts, and evidence of lint/test runs. Tag domain owners (for example `@platform-config` or `@media-core`) for cross-cutting changes and attach runbook updates or diagrams when behaviour shifts. For more operational detail, start with `AGENTS.md` and the runbooks under `docs/`.




---

## Documentation Table of Contents

<!-- AUTO-GENERATED: Do not edit below this line -->

## `00_coding_req`

- [docker-image-versioning.md](00_coding_req/docker-image-versioning.md)
- [static-content-github.md](00_coding_req/static-content-github.md)

## `01_conf_mgmt/adr`

- [0001-secret-rotation.md](01_conf_mgmt/adr/0001-secret-rotation.md)
- [002-authentik-subsystem-decisions.md](01_conf_mgmt/adr/002-authentik-subsystem-decisions.md)

## `01_conf_mgmt`

- [config-management.md](01_conf_mgmt/config-management.md)
- [consul.md](01_conf_mgmt/consul.md)
- [content-management.md](01_conf_mgmt/content-management.md)
- [mesh-gateway.md](01_conf_mgmt/mesh-gateway.md)

## `02_cicd_mgmt/adr`

- [0001-hosting-platform.md](02_cicd_mgmt/adr/0001-hosting-platform.md)

## `02_cicd_mgmt`

- [cicd-runner.md](02_cicd_mgmt/cicd-runner.md)
- [docker-registry.md](02_cicd_mgmt/docker-registry.md)
- [gitops-repository.md](02_cicd_mgmt/gitops-repository.md)

## `03_telemetry`

- [observability-platform.md](03_telemetry/observability-platform.md)
- [tracing-platform.md](03_telemetry/tracing-platform.md)

## `10_datacenters_setup`

- [home-edge-deployment.md](10_datacenters_setup/home-edge-deployment.md)

## `11_athentik_user/adr`

- [002-authentik-subsystem-decisions.md](11_athentik_user/adr/002-authentik-subsystem-decisions.md)

## `11_athentik_user`

- [authentication.md](11_athentik_user/authentication.md)
- [authentik-hybrid-identity.md](11_athentik_user/authentik-hybrid-identity.md)

## `20_central_bus`

- [kafka-messaging-bus.md](20_central_bus/kafka-messaging-bus.md)

## `21_content_manager`

- [minio-content-server.md](21_content_manager/minio-content-server.md)

## `22_db_back/adr`

- [0001-data-retention.md](22_db_back/adr/0001-data-retention.md)

## `22_db_back`

- [postgres-api-platform.md](22_db_back/postgres-api-platform.md)

## `23_search_back`

- [search-elasticsearch.md](23_search_back/search-elasticsearch.md)

## `31_Extraction`

- [media-platform.md](31_Extraction/media-platform.md)

## `40_ai`

- [ai-services.md](40_ai/ai-services.md)

## `50_public_cms`

- [public-cms.md](50_public_cms/public-cms.md)

## `51_Presentation_back/adr`

- [0001-api-contract.md](51_Presentation_back/adr/0001-api-contract.md)

## `51_Presentation_back`

- [logic-router.md](51_Presentation_back/logic-router.md)

## `52_Presentation_front`

- [frontend-app.md](52_Presentation_front/frontend-app.md)

## `90_cli_tools`

- [config-cli.md](90_cli_tools/config-cli.md)
- [echo-server.md](90_cli_tools/echo-server.md)

## `docs/content`

- [minio-runbook.md](docs/content/minio-runbook.md)

## `docs/events`

- [event-catalog.md](docs/events/event-catalog.md)

## `docs/media`

- [kafka-runbook.md](docs/media/kafka-runbook.md)
- [processing-runbook.md](docs/media/processing-runbook.md)

## `docs/oncall`

- [playbooks.md](docs/oncall/playbooks.md)

## `docs/security`

- [vault-minio.md](docs/security/vault-minio.md)

## `src/spec-improver/internal/templates`

- [spec.md](src/spec-improver/internal/templates/spec.md)

<!-- END AUTO-GENERATED -->
