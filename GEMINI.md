# Gemini Code Assistant Context

## Project Overview

This repository contains the design and documentation for the "MyFarsi" media platform. It outlines a microservices-based architecture for ingesting, processing, and serving media content. The documentation is highly structured and organized by domain, with detailed information on architecture, design, and operational procedures.

The platform follows a layered, event-driven architecture using the "claim-check" pattern. Services are grouped by domain in numbered directories at the root of the repository.

## Key Technologies

The platform is designed to use a modern, cloud-native stack:

*   **Configuration & Service Discovery:** HashiCorp Consul
*   **Secrets Management:** HashiCorp Vault
*   **Messaging Bus:** Apache Kafka
*   **Database:** PostgreSQL (exposed via PostgREST)
*   **Object Storage:** MinIO
*   **Search:** Elasticsearch
*   **Observability:** OpenTelemetry, Prometheus, Jaeger
*   **Identity & Access Management:** Authentik
*   **API Gateway & Service Mesh:** Envoy-based mesh gateways

## Development Conventions

The project emphasizes a "spec before code" philosophy and has a strong set of development conventions:

*   **Architectural Decisions:** Architectural decisions are tracked using Architecture Decision Records (ADRs) stored in `adr` subdirectories within each domain.
*   **Schema Management:** Event schemas are registered and managed in a central Schema Registry to ensure contract consistency.
*   **Build & Test Automation:** Each service is expected to have a `Makefile` with `build`, `test`, and `run` targets. CI/CD pipelines automate building, testing, linting, and deployment.
*   **Configuration:** Configuration is externalized and managed by Consul. The `config-cli` tool (documented in `90_cli_tools/config-cli.md`) is used to bootstrap services with their configuration.
*   **Secrets Management:** Secrets are managed by Vault and are never hard-coded or checked into the repository.
*   **Containerization:** The platform is designed to be deployed using Docker and Kubernetes.
*   **Toolchain:** The preferred toolchain is `make` -> `bash` -> Go -> Python.

## Building and Running

This is primarily a documentation repository, so there are no top-level build or run commands. However, the convention for individual services is to provide a `Makefile` with the following targets:

*   `make build`: Build the service.
*   `make test`: Run unit and integration tests.
*   `make run`: Run the service locally.

Services are bootstrapped using the `config-cli` tool, which fetches configuration from Consul and injects it into the service's environment. For example:

```bash
config-cli run <service-name> --environment <env> -- ... <service-command>
```
