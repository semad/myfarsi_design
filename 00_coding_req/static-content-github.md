# Static Content Delivery (GitHub)

## Intent
Publish marketing/docs content quickly using GitHub-hosted static outputs before migrating to a dedicated CDN. All changes flow through GitHub Actions and GitOps so releases are auditable.

## Workflow
```
Developer commits → GitHub Actions builds static site → Upload Pages artifact → Deploy to GitHub Pages → Cloudflare DNS → End users
```
- Source lives under `web/static-site/` (Hugo, Next.js static export, MkDocs, etc.).
- CI workflow (`.github/workflows/static-site.yml`) installs dependencies, runs build, uploads artifact, and deploys to GitHub Pages.
- GitHub Environment (`production`) gates deploy with required reviewers if desired.

### Sample Workflow
```yaml
name: Build & Deploy Static Site
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-pages-artifact@v2
        with:
          path: build
  deploy:
    needs: build
    permissions:
      pages: write
      id-token: write
    environment:
      name: production
      url: https://www.myfarsi.dev
    runs-on: ubuntu-latest
    steps:
      - uses: actions/deploy-pages@v3
```

## DNS & Delivery
- Cloudflare manages domain; CNAME `www` → `username.github.io` with proxy enabled for caching + TLS.
- Verification TXT record required for GitHub Pages. Apex domain handled via CNAME flattening or redirect to `www`.
- Cloudflare rules configure cache TTLs, HTTP security headers, and optional redirects.

## Access & Previews
- Main site is public. Preview builds use Actions artifacts or temporary deploys (Surge/Cloudflare Pages) with secret tokens.
- No secrets stored in repo; runtime config (analytics keys) injected via Actions environment variables and baked into build.

## GitOps Integration
- GitOps repo tracks DNS, Cloudflare rules, and references current static build (commit SHA, artifact URL).
- Optional automation creates metadata file (`static-site/version.json`) consumed by Logic Router or observability dashboards.
- Releases recorded via GitHub releases and environment history.

## Monitoring
- External uptime checks (e.g., healthchecks, GitHub status). Cloudflare analytics monitor traffic/caching.
- Actions workflow uploads Lighthouse report for performance/regression tracking.
- Alert triggers: failed deploy workflow, uptime monitor failure, Pages incident.

## Roadmap
1. Phase 1: Stand up site + workflow + Cloudflare config.
2. Phase 2: Add PR preview builds, Lighthouse gating, analytics instrumentation.
3. Phase 3: Localized content support, automation to sync release notes.
4. Phase 4: Migrate to dedicated CDN (S3/CloudFront or Cloudflare Pages) while keeping GitHub outputs as backup.

## References
- GitOps layout (`designs/gitops-repository.md`)
- Observability (`designs/observability-platform.md`)
- Home edge fallback (`designs/home-edge-deployment.md`)
