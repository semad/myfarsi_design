# ADR 002: Authentik Subsystem Decisions (Imported)

> Status: Accepted (migrated from legacy Authentik ADR in the previous documentation repository). Original detailed rationale will be re-imported in a future revision; this placeholder maintains the link used throughout the identity documentation.

## Summary
- Authentik is the primary identity provider for internal and customer-facing apps.
- Forward-auth handles Envoy external authorization with Authentik-issued tokens.
- Separate Redis instances support Authentik workers and forward-auth caches.
- PostgreSQL with PITR is required for Authentik persistence.
- Consul API Gateway relies on forward-auth headers for downstream authorization.

## Next Steps
- Recover full ADR content from legacy repository and update this file.
- Validate that assumptions still hold after platform redesign.
