# ADR 0001: Presentation API Style

## Status
Accepted

## Context
Presentation services were undecided between exposing REST-only endpoints or layering GraphQL on top of existing services. The ambiguity complicates front-end contracts, caching, and documentation efforts across `51_Presentation_back` and `52_Presentation_front`.

## Decision
Expose presentation services via versioned REST APIs backed by JSON schemas and OpenAPI definitions. REST aligns with existing PostgREST patterns, keeps caching straightforward, and matches tooling already in place (OpenAPI generators, contract tests). GraphQL may be re-evaluated later if aggregation complexity grows.

API guidelines:
- `/v1` namespace for public endpoints, with explicit resource nouns (`/media`, `/search`, `/assets/{id}`).
- Authentik-issued JWTs required for all requests; mesh enforces mTLS between gateway and services.
- Use pagination via opaque cursors for list endpoints to accommodate large result sets.
- Document endpoints in `51_Presentation_back/openapi/` and generate client SDKs for frontends.

## Consequences
- Presentation backends must maintain rigorous OpenAPI specs and contract tests during CI.
- Front-end teams can rely on stable REST clients; GraphQL tooling is unnecessary for initial launch.
- Aggregation logic stays server-side; revisit GraphQL or BFF patterns when data composition becomes a bottleneck.
