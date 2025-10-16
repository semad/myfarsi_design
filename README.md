# myfarsi_design

## Overview
`myfarsi_design` hosts the source for the MyFarsi platform design docs and supporting automation. Markdown sources are kept authoritative; helper scripts build canonical HTML so product, platform, and on-call teams can browse the repository as a static site.

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
- Pandoc in the shell `PATH` for Markdown ⇒ HTML conversion.
- Git configured with access to the upstream repository.

## Key Commands
- `make html` — render every Markdown file (except `TableOfContents.md`) to standalone HTML via `script/convert.sh`.
- `make toc` — regenerate `TableOfContents.md` from tracked Markdown files.
- `npx markdownlint-cli2 "**/*.md"` — lint Markdown as enforced by CI.
- `go test ./...` (inside `90_cli_tools`) — verify Go-based CLI tooling.
- `pytest -q` or `npm test -- --runInBand` — run language-specific suites; document the chosen command inside the service/module README.
- `make publish` — rebuild HTML, drop Markdown, and prepare the `html` branch for release.

## Development Workflow
1. Extend or create service directories following the numbering scheme; update `ARCHITECTURE.md`, `DESIGN.md`, and `SystemReqs.md` when structure changes.
2. Prefer Make targets over ad hoc scripts; if new automation is required, wire it into `Makefile` before adding Bash, Go, Python, or JS.
3. Keep credentials out of samples. Reference Vault/Consul keys exactly as modeled in `01_conf_mgmt` and capture network mesh changes in service READMEs.

## Testing & Quality Gates
Run smoke tests for every enhancement and add integration coverage whenever Kafka, PostgREST, or MinIO components change. Refresh anonymized fixtures with schema updates and record coverage deltas in pull requests. Lint Markdown before opening a PR and ensure any language-specific formatters (e.g., `gofmt`, `black`, `prettier`) leave the tree clean.

## Contributing
Use Conventional Commits (`feat:`, `fix:`, `chore:`) and supply pull-request descriptions with the problem statement, solution summary, links to design artifacts, and evidence of lint/test runs. Tag domain owners (for example `@platform-config` or `@media-core`) for cross-cutting changes and attach runbook updates or diagrams when behaviour shifts. For more operational detail, start with `AGENTS.md` and the runbooks under `docs/`.
