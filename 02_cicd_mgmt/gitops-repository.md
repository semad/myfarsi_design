# GitOps Repository Blueprint

## Goal

Structure and govern the GitOps repo that feeds Argo CD so every production change flows through Git history, validation, and review.

## Repository Layout

```text
infra-gitops/
├── README.md
├── .github/workflows/validate.yaml
├── apps/
│   └── <service>/
│       ├── base/         # shared manifests or Helm chart refs
│       └── overlays/
│           ├── staging/
│           └── prod/
├── argo-apps/
│   ├── staging/
│   └── prod/
├── clusters/
│   ├── staging/
│   └── prod/
├── environments/
│   ├── staging/
│   └── prod/
├── policies/             # OPA / Kyverno / conftest policies
└── scripts/              # helper scripts (render, lint)
```

- `apps/` holds application manifests; each overlay encodes env-specific Helm values or Kustomize patches.
- `argo-apps/` defines Argo CD `Application` or `ApplicationSet` resources pointing to overlays.
- `clusters/` contains cluster-scoped resources (namespaces, ingress controllers, cert-manager).
- `environments/` captures shared configs such as network policies, quotas, and shared services.
- `policies/` stores validation rules run in CI and optionally enforced in-cluster.

## Branching & Promotion

- Single branch (`main`) recommended; environment separation managed by directories. Promotion occurs via PRs updating `prod` overlays after staging validation.
- Optional `release/*` branches for long-running initiatives but avoid diverging manifests.
- CODEOWNERS ensures service teams approve changes touching their overlays (`apps/cms/**` etc.).

## Workflow

1. Service pipeline bumps image tag in staging overlay and opens PR to GitOps repo.
2. GitHub Actions workflow (`validate.yaml`) renders manifests (`make render-all`), runs lint (`kubeconform`, `kubeval`), policy checks (`conftest`), secret scans, and Helm/Kustomize validations.
3. Once merged, Argo CD auto-syncs staging `Application`. Observability verifies rollout.
4. A follow-up PR (or automated promotion job) copies changes into `prod` overlay; requires elevated reviewers.
5. Production sync gated by Argo CD Sync Waves + manual approval if desired.

## Secrets

- Git repo stores only references. Use ExternalSecrets or Sealed Secrets manifests pointing to Vault/secret manager paths (`vault://platform/<service>/<env>`).
- Document required secrets per service in overlay README.
- Rotation handled outside repo; update references if secret path changes.

## Tooling

- `make render-all`: iterates overlays, outputs manifests under `render/`.
- `make validate`: wraps lint + conftest + policy checks.
- Pre-commit hooks enforce YAML formatting, detect secrets, run `conftest`.
- Optional `scripts/promote.sh staging prod <service>` to copy manifests and open PR automatically.

## Governance

- Require PR approval from service owners + platform team for `prod` overlays.
- Protect `main` with required status checks (`validate`, `lint`, `policy`).
- Use signed commits and GitHub environments if compliance demands.
- Track change log automatically via GitHub releases or `scripts/changelog`.

## Observability & Audit

- Argo CD audit logs stored centrally; map sync events to Git commit SHA.
- Collect deployment metrics (lead time, MTTR) from GitHub + Argo CD APIs.
- Alerts on sync failures, drift, or app health degrade integrate with on-call rotations.

## Roadmap

1. ApplicationSet-powered preview environments with automatic teardown.
2. Policy-as-code expansion (OPA/Kyverno enforcement in-cluster).
3. Multi-cluster support (DR region) by adding directories under `clusters/` and updating ApplicationSets.
4. ChatOps commands for promoting or syncing via Argo CD API with RBAC controls.

## References

- CI/CD runner design (`02_cicd_mgmt/cicd-runner.md`)
- Observability platform (`03_telemetry/observability-platform.md`)
- Service-specific designs referenced within overlays.
