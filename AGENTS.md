# Repository Guidelines

## Project Structure & Module Organization
Top-level directories are numbered (00-99) to mirror the platform stack: `00_coding_req` tracks requirements, `01_conf_mgmt` covers Consul/Vault/mesh, `02_cicd_mgmt` captures CI/CD, `03_telemetry` handles observability, and the 10-52 range maps runtime services from datacenter bootstrap through presentation tiers. Keep `ARCHITECTURE.md`, `DESIGN.md`, and `SystemReqs.md` aligned with structural changes. When contributing code or runbooks, add a `README.md`, `Makefile`, and service docs inside the relevant directory.

## Build, Test, and Development Commands
- `npx markdownlint-cli2 "**/*.md"` - lint new or edited Markdown before review; run from the repo root with Node 20 (the version used by the Pages pipeline).
- `go test ./...` - execute Go unit tests when extending CLI tooling under `90_cli_tools`; ensure modules stay module-local.
- `pytest -q` or `npm test -- --runInBand` - pick the runner that matches the language of the service you're touching; document the exact invocation in that module's README.

## Coding Style & Naming Conventions
Favor `Makefile` entry points for orchestration, then implement service code in the priority order: Make, Bash, Go, Python, JavaScript (see `00_coding_req/notes.txt`). Use snake_case for directories that describe data flows (`media_platform`), kebab-case for service binaries (`file-upload-api`), and keep Terraform/YAML indented by two spaces. Check in generated manifests only when reproducible and reference the generator in a comment.

## Testing Guidelines
Mirror the language ecosystem's defaults: Go tests live beside sources, Python tests in `tests/`, JS tests under `__tests__`. Add smoke tests for each new workflow, plus integration coverage for Kafka, PostgREST, and MinIO interactions before promoting changes across domains. Capture fixtures in version control, anonymized, and refresh them when schemas evolve. Surface coverage deltas in the PR description.

## Commit & Pull Request Guidelines
History currently contains only the template bootstrap; adopt Conventional Commits (e.g., `feat: add ingestion schema ADR`) so CI/GitOps automation can classify changes. Each PR should include context (what/why), linked design docs or tickets, testing evidence (`npx markdownlint-cli2`, unit/integration output), and screenshots or diagrams when visual assets change. Coordinate cross-domain updates by tagging domain owners (`@platform-config`, `@media-core`, etc.) before requesting approval.

## Security & Configuration Tips
Never hardcode secrets; reference Vault paths and Consul keys exactly as documented in `01_conf_mgmt`. When adding examples, mask credentials and include placeholder annotations. Document any new network egress, mesh policy, or identity scope adjustments, and update `SystemReqs.md` if hardware or cluster assumptions shift.
