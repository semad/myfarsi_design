# Presentation Front-End Application

## Purpose

Outline the architecture, tooling, and operational practices for the user-facing web application that consumes Logic Router and Search APIs to deliver the public CMS experience. This complements `50_public_cms/public-cms.md` (experience overview) by focusing on the implementation details.

## Tech Stack

- Framework: Next.js (React) with TypeScript.
- Styling: Tailwind CSS + component library for accessibility.
- State/Data: React Query (server data), Zustand/Redux for client state.
- Testing: Jest + Testing Library (unit), Playwright (E2E).
- Linting/Formatting: ESLint, Prettier.
- Build: Node.js 20, Vite or Next.js build pipeline.
- Package manager: npm or pnpm (decide and document; default npm unless repo dictates otherwise).

## Application Layers

| Layer        | Responsibility                                                                                |
| ------------ | --------------------------------------------------------------------------------------------- |
| Pages/Routes | Map URLs to Next.js pages; enable static generation or server-side rendering as needed.       |
| Data Fetch   | Centralized API client hitting Logic Router (`/api/v1/*`), Search, Authentik token endpoints. |
| Components   | UI building blocks with localization support and design system compliance.                    |
| Hooks        | Encapsulate data fetching, caching, and feature flag logic.                                   |
| Utilities    | i18n helpers, error handling, analytics instrumentation.                                      |

## Environment Configuration

- Environment variables prefixed with `NEXT_PUBLIC_` for client-side usage, sourced from `config-cli` or CI pipeline secrets.
- `env.example` maintained for onboarding; sensitive values only in Vault-backed secrets.
- Feature flags retrieved from Logic Router or Consul via server-side API routes.

## Build & Deploy Pipeline

1. CI: `npm ci`, `npm run lint`, `npm run test`, `npm run build`.
2. Bundle analysis optional for regression checks.
3. Artifacts uploaded to CDN (Cloudflare Pages/S3+CloudFront) through GitHub Actions.
4. GitOps PR updates deployment manifests (`apps/frontend/*`).
5. Preview environments generated per PR for QA (Vercel/Cloudflare preview).

## Localization & Accessibility

- i18n library (e.g., `next-i18next`) with locale files under `locales/<locale>/*.json`.
- Layouts support RTL via CSS logical properties.
- Run accessibility tests (axe, Storybook a11y) in CI.
- Ensure dynamic content from Logic Router includes locale metadata to drive UI.

## Authentication

- Uses Authentik Authorization Code Flow with PKCE.
- Session tokens stored in HttpOnly cookies; refresh handled via API route.
- Guarded routes check `useAuth()` hook; SSR pages validate session server-side.
- Handle token expiration gracefully with silent re-auth flows.

## Caching & Performance

- Static generation for high-traffic pages where content is cacheable.
- Incremental Static Regeneration (ISR) or revalidation triggered by CMS events (webhooks from Logic Router).
- Client caching via React Query; background refetch keep data fresh.
- Monitor Core Web Vitals; optimize images via Next.js Image component and CDN.

## Observability

- Error reporting via Sentry/New Relic Browser.
- Performance metrics (LCP, FID, CLS) sent to analytics backend.
- Log correlation ID from Logic Router for debugging.
- Feature usage events (search queries, filter actions) published to analytics pipeline.

## Security

- Strict CSP, X-Frame-Options, and Referrer-Policy headers.
- Sanitize HTML content from CMS to prevent XSS.
- Ensure dependencies audited via `npm audit`/`snyk`.
- Implement Content Security controls consistent with System Requirements.

## Development Workflow

- Local dev: `npm run dev` with `.env.local` pointing to staging APIs or mocks.
- Storybook for component development and visual regression tests (`chromatic`, `loki`).
- Git hooks (Husky) enforce lint/test on commit.
- Document onboarding steps in `README.md` within this directory.

## Roadmap

1. Phase 1: SSR/ISR pages for knowledge base, authentication flow, baseline analytics.
2. Phase 2: Media galleries, search-driven views, offline caching for key pages.
3. Phase 3: Personalization features, SSR caching layers, A/B testing harness.
4. Phase 4: Multi-brand theming, white-label deployments, integration with native mobile shells.

## References

- `50_public_cms/public-cms.md`
- `51_Presentation_back/logic-router.md`
- `23_search_back/search-elasticsearch.md`
- `SystemReqs.md`
