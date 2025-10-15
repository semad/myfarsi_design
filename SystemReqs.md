# System Requirements - 0_infra_cicd Repository

## Overview

This repository implements **Layer 1: CI/CD & Build Infrastructure** for the MyFarsi Backend Media Server project. It provides the foundational infrastructure services using HashiCorp Consul for service discovery and distributed configuration, and Envoy Proxy as the API gateway.

## Implementation Status

### 📁 Configuration Templates (Not Yet Implemented)

The following configuration files exist but services are not yet fully implemented and tested:

1. **Consul Configuration** (`config/consul.hcl`)
   - Single-node development mode setup
   - HTTP API and UI on port 8500
   - DNS interface on port 8600
   - Telemetry and Prometheus metrics configured
   - **Status**: Configuration exists, needs implementation and testing

2. **Envoy Gateway Configuration** (`config/envoy.yaml`)
   - API gateway routing configuration
   - Routes for Consul UI and API defined
   - Admin interface on port 9901
   - **Status**: Configuration exists, needs implementation and testing

3. **Network Infrastructure** (`docker-compose.yml`)
   - Docker bridge network: `mycicd_network`
   - Service definitions for Consul and Envoy
   - Volume definitions
   - **Status**: Defined, needs implementation and testing

4. **Configuration Management**
   - Centralized `.env` file for all configuration
   - Configuration schema with validation (`config/config-schema.yaml`)
   - **Status**: Templates exist, needs validation

5. **Development Tooling**
   - Comprehensive Makefile with all common operations
   - Speckit workflow for feature development
   - **Status**: Framework in place, ready to use

### 🚧 Next Implementation Steps (Priority Order)

1. **Implement Consul Service** (FIRST)
   - Validate consul.hcl configuration
   - Test service startup and registration
   - Verify HTTP API and UI accessibility
   - Test health checking functionality
   - Verify KV store operations
   - Confirm Prometheus metrics endpoint works

2. **Implement Envoy Gateway** (SECOND)
   - Validate envoy.yaml configuration
   - Test routing to Consul
   - Verify admin interface
   - Test service discovery integration
   - Confirm metrics and logging work

3. **Integration Testing** (THIRD)
   - End-to-end tests of Consul + Envoy
   - Service discovery testing
   - Configuration management validation
   - Network isolation verification

### 📋 Next Priority Features (Designed, Not Implemented)

These features have complete design documents in `desing/` directory:

1. **Docker Registry** (`desing/docker-registry.md`)
   - Private container image storage
   - Dynamic configuration via `config-cli` wrapper
   - Consul integration for service discovery
   - Health checking and metrics

2. **CI/CD Runner Fleet** (`desing/cicd-runner.md`)
   - Kubernetes executor for cloud deployments
   - Docker executor for local development
   - Tag-based job routing
   - Kaniko for secure image builds

### ❓ Future Features (Planned, Not Yet Designed)

These features are planned but lack detailed design documents:

1. **Vault** - Secret management (Layer 2)
2. **Consul Connect** - Service mesh with mTLS (Layer 2)
3. **OpenTelemetry Collector** - Unified telemetry pipeline (Layer 3)
4. **Prometheus** - Metrics storage and querying (Layer 3)
5. **Jaeger** - Distributed tracing backend (Layer 3)
6. **Grafana** - Metrics and traces visualization (Layer 3)
7. **Loki/ELK** - Centralized logging (Layer 3)

## System Architecture

### Multi-Layer Architecture

The complete MyFarsi system follows a 5-layer architecture:

#### **Layer 1: CI/CD & Build Infrastructure** (this repository)
- **Consul** - Service discovery and distributed configuration
- **Envoy Gateway** - API gateway and ingress controller
- **Docker Registry** - Private container image storage (planned)
- **CI/CD Runners** - Build and deployment automation (planned)

#### **Layer 2: Configuration, Secrets, & Service Mesh** (future)
- **Vault** - Secret management for API keys, credentials, certificates
- **Consul Connect** - Service mesh with automatic mTLS encryption
- **Service Authentication** - Vault integration with Consul using AppRole

#### **Layer 3: Observability** (future)
- **OpenTelemetry Collector** - Central telemetry pipeline
- **Prometheus** - Time-series metrics database
- **Jaeger** - Distributed tracing visualization
- **Grafana** - Unified monitoring dashboards
- **Loki/ELK** - Centralized log aggregation and search

#### **Layer 4: Data & Storage** (future, separate repo)
- **PostgreSQL** - Relational database
- **MinIO** - S3-compatible object storage
- **PostgREST** - RESTful API for PostgreSQL
- **Message Bus** - Event streaming (Kafka/NATS)

#### **Layer 5: Business Logic & APIs** (future, separate repo)
- **API Gateway** - Public API interface
- **Media Ingestion Services** - Content processing pipeline
- **Processing Services** - Business logic implementation
- All instrumented with OpenTelemetry SDK

### Core Design Patterns

1. **Claim Check Pattern**
   - Large files (media) stored in MinIO object storage
   - Small metadata messages flow through message bus
   - Reduces network load and improves throughput

2. **Idempotent Consumer Pattern**
   - All services designed for safe retry operations
   - Duplicate message handling
   - At-least-once delivery semantics

3. **Service Mesh Pattern**
   - Consul Connect provides service-to-service security
   - Automatic mTLS encryption without application code changes
   - Service identity and authorization

4. **Dynamic Configuration Pattern**
   - Services use `config-cli` wrapper to fetch config from Consul at startup
   - Configuration stored in Consul KV store
   - Enables centralized configuration management
   - Services register themselves with Consul for discovery

## Functional Requirements

### Service Discovery & Configuration

1. All services MUST register with Consul on startup
2. All services MUST provide health check endpoints
3. Services MUST fetch non-sensitive configuration from Consul KV store
4. Services MUST use Docker service names for DNS-based discovery
5. Configuration updates in Consul MUST be applied without service restart where possible

### Networking

1. All services MUST communicate over a dedicated Docker bridge network: `mycicd_network`
2. Services MUST resolve each other using Docker DNS (e.g., `consul`, `envoy`)
3. External access MUST go through Envoy Gateway on port 9080
4. Internal service-to-service communication MUST use service discovery
5. Network isolation MUST be maintained between different environments

### API Gateway (Envoy)

1. Gateway MUST provide a unified HTTP entry point on port 9080
2. Gateway MUST expose traffic metrics in Prometheus format at `/metrics` endpoint
3. Gateway MUST restart automatically within 10 seconds if it crashes
4. Gateway MUST log all traffic in structured format
5. When service is both manually configured AND discovered from Consul, Consul discovery MUST win (dynamic overrides static)
6. Gateway MUST support up to 10 backend instances per service
7. Gateway MUST NOT require authentication for backend services (rely on Docker network isolation)

### Configuration Management

1. All configuration MUST be externalized in `.env` or service-specific config files
2. No default values MUST exist in `docker-compose.yml` - all must be explicit in `.env`
3. Configuration schema MUST be maintained in `config/config-schema.yaml`
4. Configuration validation MUST pass before services can start
5. Sensitive configuration (secrets) MUST use Vault (future requirement)

### Container & Orchestration

1. All system components MUST be containerized using Docker
2. Services MUST be orchestrated using Docker Compose version 3.8 or compatible
3. Container images MUST follow semantic versioning
4. All services MUST support graceful shutdown on SIGTERM/SIGINT
5. Data persistence MUST use Docker volumes (e.g., `consul-data`)

### Observability

1. All services MUST emit metrics in Prometheus format
2. All services MUST provide structured JSON logs to stdout/stderr
3. All services MUST support distributed tracing via OpenTelemetry (future)
4. Services MUST expose health check endpoints for monitoring
5. Consul MUST expose `/metrics` endpoint for monitoring its health

### High Availability & Resilience

1. Services MUST be designed to handle failures gracefully
2. Operations MUST be idempotent and safe to retry
3. Services MUST implement health checks with appropriate timeouts
4. Failed service instances MUST be automatically removed from service registry
5. Services MUST reconnect to dependencies automatically after transient failures

## Non-Functional Requirements

### 1. Core Motivation
To have fun, learn, and conduct research in microservices architecture, service mesh, and cloud-native technologies.

### 2. Configuration Philosophy
All configuration MUST be externalized (`.env`, YAML, HCL files). No hardcoded values in application code or Docker Compose files.

### 3. Technology Stack Preference (in order)
1. **make** - Primary interface for all operations
2. **bash** - Scripting and automation
3. **golang** - Service implementation and CLI tools
4. **python** - Secondary scripting language

### 4. Environment Support
Support development environments from local Docker to Kubernetes clusters:
- Local Docker-only development (current)
- Local Kubernetes (Minikube, Docker Desktop)
- Cloud Kubernetes (GKE, EKS, AKS)

### 5. CI/CD First Mentality
- Automated build pipelines for all services
- Automated testing (contract, integration, unit)
- Infrastructure as code
- GitOps workflow preferred

### 6. Observability Priority
- Comprehensive monitoring with Prometheus and Grafana
- Centralized logging with structured logs
- Distributed tracing for request flows
- Centralized configuration and secret management

### 7. Architecture Style
Service mesh architecture with:
- Consul for service discovery
- Consul Connect for mTLS between services
- Central data bus for event streaming
- API-first design for all services

## Development Practices (Constitution)

These practices are mandatory for all development in this repository:

### Containerization
- Docker and Docker Compose are the foundation
- Everything runs in containers for consistency
- No "works on my machine" issues

### Makefile as Universal Interface
- All operations accessible via `make` targets
- Standard interface across all projects
- Self-documenting via `make help`

### Centralized Control
- Consul for distributed configuration
- Vault for secret management (planned)
- Single source of truth for service state

### API-Driven
- API-first approach for all services
- RESTful APIs with OpenAPI/Swagger documentation
- CLI tools for command-line operations

### Everything is Monitored
- Dedicated monitoring stack (Prometheus + Grafana)
- All services expose metrics
- Centralized logging via OpenTelemetry Collector

### Command-Line First
- CLI tools for service interaction
- Automation via scripts
- Terminal-friendly workflows

### Spec-Driven Development
- Write specifications before coding
- Use `/speckit` workflow for all features
- Documentation-first approach

### Comprehensive Testing
- Multi-layered testing strategy:
  - Contract tests for API boundaries
  - Integration tests for service interactions
  - Unit tests for business logic
- Tests written before implementation (TDD)

## Gateway-Specific Requirements

From clarification questions in original document:

### Crash Recovery
**Q**: When the gateway container crashes or stops, how should the system behave?
**A**: Gateway restarts automatically and resumes traffic within 10 seconds; clients retry failed requests.

### Metrics Format
**Q**: What format should the gateway use to expose traffic metrics?
**A**: Prometheus format at `/metrics` endpoint (industry standard, pull-based).

### Authentication
**Q**: How should the gateway authenticate when communicating with backend services?
**A**: No authentication required; rely on Docker network isolation (services trust internal network).

### Configuration Conflicts
**Q**: When a service is both manually configured in the gateway AND discovered from Consul, how should conflicts be resolved?
**A**: Consul discovery always wins (dynamic overrides static).

### Scale Limits
**Q**: What is the maximum number of backend instances per service?
**A**: Up to 10 instances per service (suitable for small-scale deployments).

## Network Configuration

### Current Network Setup
- **Network Name**: `mycicd_network` (configurable via `NETWORK_NAME` in `.env`)
- **Network Driver**: `bridge`
- **DNS Resolution**: Automatic via Docker DNS (service names resolve to container IPs)

### Port Mappings
- **Consul HTTP API/UI**: 8500 (host) → 8500 (container)
- **Consul DNS**: 8600 (host) → 8600 (container) - UDP+TCP
- **Envoy Gateway**: 9080 (host) → 10000 (container)
- **Envoy Admin**: 9901 (host) → 9901 (container)

### Future Ports (Planned)
- **Docker Registry**: 5000 (TBD)
- **Vault**: 8200 (TBD)
- **Prometheus**: 9090 (TBD)
- **Grafana**: 3000 (TBD)
- **Jaeger UI**: 16686 (TBD)

## Success Criteria

This repository will be considered successful when:

1. **Foundation Services Operational**
   - Consul provides reliable service discovery and configuration
   - Envoy Gateway routes traffic correctly to all backend services
   - All services register and deregister cleanly

2. **CI/CD Pipeline Functional**
   - Docker Registry stores and serves container images
   - CI/CD runners build and test all services automatically
   - Images are versioned and deployed consistently

3. **Development Experience**
   - Developers can start entire stack with `make up`
   - Configuration changes apply with `make restart`
   - Debugging via centralized logs and metrics

4. **Ready for Next Layers**
   - Vault integration points defined
   - Observability stack integration prepared
   - Service mesh foundation in place

5. **Production-Ready Infrastructure**
   - All services have health checks
   - Graceful shutdown and restart
   - Configuration validated before startup
   - Data persists across restarts

## Dependencies

### Current External Dependencies
- Docker Engine 20.10+
- Docker Compose 1.29+ (or Docker Compose V2)
- Make 3.81+
- Bash 4.0+
- curl (for Consul KV operations)
- jq (optional, for JSON processing)

### Future External Dependencies
- Kubernetes 1.24+ (for K8s-based deployments)
- kubectl (for K8s operations)
- GitLab Runner or similar CI/CD tool
- Cloud provider CLI tools (optional, for cloud deployments)

## Constraints

1. **Development Focus**: This is a learning and research project, not production-critical
2. **Scale**: Designed for small-scale deployments (< 10 service instances per service)
3. **Security**: Internal network isolation only; no production-grade security yet
4. **High Availability**: Single-node Consul for development; HA considerations deferred
5. **Resource Limits**: Optimized for local development on laptop/workstation

## References

- **Design Documents**: `desing/*.md` - Detailed service designs
- **CLAUDE.md**: Development guidance and architecture overview
- **Makefile**: All available operations and commands
- **config/config-schema.yaml**: Complete configuration schema
- **Consul Documentation**: https://www.consul.io/docs
- **Envoy Documentation**: https://www.envoyproxy.io/docs
