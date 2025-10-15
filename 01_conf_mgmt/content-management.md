# Configuration Content Lifecycle

## Purpose
Define how configuration artifacts (KV exports, policies, templates) are created, reviewed, promoted, and audited inside the `platform-config` namespace. This complements `01_conf_mgmt/config-management.md` by focusing on the human workflows and content structure that keep configuration consistent across environments.

## Content Types
| Artifact | Location | Notes |
| --- | --- | --- |
| Consul KV exports | `configs/<service>/<env>/service.vN.yaml` | Versioned YAML produced by `config-cli consul export`. |
| Consul config entries | `configs/consul/config_entries/<type>/<name>.yaml` | Service defaults, intentions, routers, and splitters. |
| Vault policies and roles | `configs/vault/<env>/policy/<name>.hcl` | Managed via Terraform or direct API; stored for review. |
| Bootstrap scripts | `configs/bootstrap/<env>/*.sh` | One-off commands (e.g., ACL bootstrap); kept for reproducibility. |
| Documentation | `docs/platform-config/*.md` | How-to guides, runbooks, and policy rationale. |

Every artifact must be traceable to a change request (ticket, ADR, or incident) and carry environment ownership metadata in commit messages or file headers.

## Authoring Workflow
1. **Draft**: Engineers modify artifacts locally using `config-cli render` and `make config-validate`.
2. **Review**: Pull request reviewers validate structure, check impact using dry-run exports, and confirm references to relevant tickets or ADRs.
3. **Approval**: At least one domain owner approves. Sensitive changes (Vault policies, gateway intentions) require security sign-off.
4. **Promotion**: After merge, Argo CD syncs staging first. Production promotion uses either automatic sync with manual gate or timed release per change severity.
5. **Audit Trail**: `config-cli consul export --diff` runs nightly to generate drift reports stored under `reports/<date>/`. Any divergence opens an issue.

## Naming and Versioning
- Files use semantic versions (v1, v2...) appended to the service name. Deprecated versions remain for traceability until the next release train.
- KV keys follow `<env>/<service>/<component>/<key>` to avoid collisions. Avoid camelCase; prefer snake_case.
- Policies include a `metadata` block documenting owner, created date, and contact channel.
- Use `README.md` in each service directory to describe parameters, default values, and rollout notes.

## Validation
- `make config-validate`: runs schema validation, `config-cli consul export --validate`, and YAML linters.
- `make config-test`: spins up local Consul/Vault (dev mode) and executes smoke tests to ensure templates render and required keys exist.
- CI enforces both targets on every PR; failures block merge.
- For sensitive KV updates (feature flags, rate limits), include automated tests in service repos to assert behavior under new values.

## Promotion Strategy
- **Staging First**: All changes apply to staging and remain for at least one business day. Monitor telemetry dashboards (`03_telemetry/observability-platform.md`) for anomalies.
- **Emergency Fixes**: Use tagged `hotfix/` branches; document root cause and follow-up ADR if policy shifts.
- **Rollback**: Reapply previous version file and rerun `config-cli consul export --scope <env> --version <prev>`. Post-incident review required.
- **Multi-environment Changes**: Introduce toggles or conditional keys so staging and production can diverge temporarily without drift.

## Compliance and Retention
- Retain configuration history indefinitely in Git (point-in-time restore is trivial).
- Nightly snapshots of Consul and Vault ensure config remains recoverable even if Git history is inaccessible.
- Access reviews happen quarterly; reference `SystemReqs.md` for non-functional requirements.
- Align with data residency decisions from `22_db_back/adr/0001-data-retention.md`; exports stored in MinIO must remain in EU regions.

## Tooling Enhancements (Roadmap)
1. Generate human-readable release notes from config diffs to share with stakeholders.
2. Add policy-as-code checks (OPA) covering key namespaces, TTL bounds, and ACL scope.
3. Automate tagging of configuration releases so applications can correlate runtime behavior with config versions.
4. Integrate Slack notifications for pending approvals and failed validations.
5. Build dashboards that correlate config changes with service health to detect regressions faster.

## References
- `01_conf_mgmt/config-management.md` for platform responsibilities.
- `01_conf_mgmt/consul.md` and `01_conf_mgmt/mesh-gateway.md` for infrastructure specifics.
- `SystemReqs.md` and ADRs under `01_conf_mgmt/adr/` for policy decisions.
