# Docker Image Versioning & Tagging Strategy

## Objectives
- Ensure every container image produced by CI/CD is uniquely identifiable and traceable to source code, configuration, and runtime environment.
- Provide predictable tags for promotions (dev → staging → production) while retaining immutable digests for rollbacks.
- Integrate tagging with GitOps workflows so deployments consume approved tags only.
- Enforce consistency across all service domains (configuration, authentication, media).

## Tag Schema
| Tag Type | Format | Purpose |
| --- | --- | --- |
| Release | `vX.Y.Z` (semantic version) | Human-friendly releases and production deployments. |
| Channel | `env-<env>` (e.g., `env-staging`) | Mutable tags reflecting the latest build verified in a given environment. |
| Commit | `<git-sha>` (short SHA) | Immutable reference baked into every build for traceability. |
| Latest | `latest` | Optional; used only for local/dev workflows, never in production manifests. |

- CI builds always tag the image with: `vX.Y.Z` (if a release), `env-<target>`, and `<git-sha>`.
- GitHub Actions pipeline sets `AUTO_GIT_TAG=true` to add the commit SHA (implemented in `tools/echo_server/Makefile` and mirrored in service Makefiles).
- `env-<env>` tags are updated only after automated verification passes in that environment (e.g., staging smoke tests).

## Build & Tag Pipeline
1. **Version Resolution**
   - Release pipeline reads `VERSION` file or git tag to derive `vX.Y.Z`.
   - Feature builds use `env-dev` without bumping semantic versions.
2. **Build & Test**
   - Run unit/integration tests before container build.
   - Build image (`docker build` or Kaniko) and run vulnerability scanning (Trivy/Grype).
3. **Tagging**
   - Apply `vX.Y.Z` when present.
   - Apply `env-<env>` (dev/staging/prod) based on pipeline context.
   - Tag with short SHA (`AUTO_GIT_TAG=true`).
4. **Push**
- Push all tags to private registry (`designs/docker-registry.md`).
   - Capture pushed digests for release notes and GitOps updates.
5. **GitOps Update**
   - Update environment overlays (`apps/<service>/overlays/<env>/values.yaml`) with the immutable SHA tag or explicit `vX.Y.Z`.
   - CI opens PR to GitOps repo referencing the new tag and includes verification steps.
6. **Promotion**
   - Promotion pipeline (staging → prod) retags the tested image (`docker tag repo/service:<sha> repo/service:env-prod`), pushes, and updates GitOps manifests.

## Traceability
- Each image label includes:
  - `org.opencontainers.image.revision=<git-sha>`
  - `org.opencontainers.image.source=<repo-url>`
  - `org.opencontainers.image.version=<vX.Y.Z>`
- Build metadata stored in CI artifacts (build id, commit, tag list).
- GitOps PR template requires listing the image tags/digests that were deployed.
- `config-cli` logging records the image tag while bootstrapping services for audit alignment.

## Enforcement
- Policy in CI pipeline rejects:
  - Missing semantic version on main branch releases.
  - Attempting to push `latest` to protected registries.
  - Tags without accompanying SHA (ensures immutability).
- Admission controller (OPA/Kyverno) validates Kubernetes manifests to ensure only approved registries and tag patterns are used (e.g., must match `^(v\d+\.\d+\.\d+|env-\w+|[0-9a-f]{7})$`).
- Release checklist includes verification that `env-prod` tag points to the same digest as the approved SHA.

## Rollback
- Rollback uses immutable SHA tag recorded in GitOps history.
- `env-<env>` tag is reset after rollback to point back to the previous digest.
- Registry retention policy ensures at least N historical digests remain available for each service.

## Domain Considerations
- **Configuration Management System**: `config-cli`, Consul/Vault sidecars, and auxiliary tools follow the same tag scheme; CI uses tags to select appropriate bootstrap binaries.
- **Authentication System**: Authentik, forward-auth, and Redis images adopt the same tagging policy; promotions rely on staged validation before retagging.
- **Media Business Logic**: All ingestion/process services share the tagging pipeline; Kafka consumers and producers roll out based on immutable SHA, while `env-<env>` marks current channel.

## Integration Points
- CI/CD design (`designs/cicd-runner.md`): extends runner workflows with tagging steps (`registry-build-push` target, `AUTO_GIT_TAG=true`).
- GitOps design (`designs/gitops-repository.md`): environment overlays use explicit tags; promotion PRs documented with tag transitions.
- Registry design (`designs/docker-registry.md`): supports multiple tags per manifest; retention and GC configured to keep historical digests.
- Media/Authentication/Config designs reference this strategy to ensure uniform deployment semantics.

## Roadmap
1. Automate semantic version bumping (e.g., conventional commits → release workflow).
2. Introduce provenance attestations (SLSA) alongside tags.
3. Expose tag metadata via dashboard (e.g., chart showing env → digest mapping).
4. Add registry webhooks to notify GitOps when tag changes occur outside automation (policy enforcement).
5. Evaluate multi-arch builds; ensure tag scheme accommodates architecture suffixes (`vX.Y.Z-amd64`, `vX.Y.Z-arm64`).
