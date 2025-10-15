# ADR 0001: Initial Hosting Platform

## Status
Accepted

## Context
CI/CD services (self-hosted runners, registry, GitOps control plane) need a reliable environment before the rest of the platform can ship. Earlier documentation referenced generic Docker-compose sandboxes and deferred the production decision, leaving tooling, networking, and security policies ambiguous. We must decide where Layer 1 components will run to right-size infrastructure, networking, and operations.

## Decision
Host Layer 1 services on a self-managed Kubernetes cluster deployed on Equinix Metal hardware. Kubernetes gives us consistent primitives for runners (Kubernetes executor), long-running services (registry, GitOps controllers), and network policy. Equinix Metal provides bare-metal nodes with predictable performance and private networking, aligning with the project's desire for full control over build infrastructure.

Key points:
- Kubernetes version 1.28 LTS, managed via Flux CD, with worker pools sized for build concurrency.
- Use Equinix private VLAN for runner-to-registry traffic; expose registry via public load balancer with TLS.
- Provision GitOps controllers (Argo CD + Flux) inside the same cluster to manage downstream environments.
- Maintain Terraform IaC for cluster lifecycle within `02_cicd_mgmt/`.

## Consequences
- Infrastructure automation must cover Kubernetes bootstrap on Equinix Metal (Terraform modules, kubeadm or managed offering).
- Runners default to Kubernetes executor; Docker executor remains available via DinD pods for legacy jobs.
- Networking and security baselines (firewall rules, load balancers) must be documented alongside CI/CD specs.
- Local Docker-compose development remains for experimentation, but production promotion targets the Equinix-backed cluster.
