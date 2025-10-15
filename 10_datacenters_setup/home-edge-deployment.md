# Home Edge Deployment

## Objective
Expose a staging-grade slice of the platform from a residential network while maintaining security and reliability until cloud hosting is ready.

## Constraints
- Dynamic residential IP, potential CGNAT, constrained upstream bandwidth.
- Limited hardware redundancy; UPS required for short outages.
- Avoid broad exposure of home network; segregate lab traffic from household devices.

## Topology
```
Internet
  │
  ▼
Cloudflare Tunnel / WireGuard VPS ──► Zero Trust Access
  │
  ▼
Home Router / Firewall (VLAN isolation, static DHCP)
  │
  ▼
k3s Cluster (NUC/RPi) ──► Authentik, CMS, MinIO, Search, Observability
                           └─ Admin access via VPN only
```
- Prefer Cloudflare Tunnel with Cloudflare Access enforcing OAuth login. Alternative: WireGuard tunnel to lightweight VPS acting as reverse proxy.
- Dedicated VLAN (e.g., `192.168.50.0/24`) for servers; disable UPnP, restrict inbound to tunnel endpoints.
- Static IP assignments for cluster nodes; dynamic DNS script updates Cloudflare records if direct exposure required.

## Kubernetes Stack
- k3s single control plane (optionally two worker nodes). Storage via Longhorn or local PVs on SSD/NVMe.
- Deploy platform services with `home` overlay in GitOps repo; Argo CD manages manifests.
- Ingress handled by Traefik or Consul API Gateway; TLS terminated by Cloudflare origin certificates or mesh sidecars.
- Secrets managed with SOPS + age/GPG; decrypt during deployment. Vault optional if reachable securely.

## Security Controls
- Cloudflare Access or equivalent Zero Trust to gate public endpoints (Authentik, CMS, Grafana, Argo CD).
- WireGuard VPN for administrative SSH/kubectl; no direct SSH from internet.
- Firewall rules: outbound allow list (HTTPS, DNS, container registry); inbound limited to tunnel/established sessions.
- Monthly patch cycle for host OS, k3s, workloads; rotate credentials quarterly.
- IDS/IPS (optional) such as CrowdSec; log to central observability stack.

## DNS & Routes
- Subdomain `home.myfarsi.dev` managed in Cloudflare.
- Routes:
  - `auth.home.myfarsi.dev`
  - `cms.home.myfarsi.dev`
  - `minio.home.myfarsi.dev` (lock behind Access policies)
  - `obs.home.myfarsi.dev` (Grafana)
  - `gitops.home.myfarsi.dev` (Argo CD)
- Dynamic DNS script or tunnel hostname handles IP changes; consider VPS relay if ISP blocks tunnels.

## Observability
- Prometheus + Loki + Tempo + Grafana on cluster; dashboards include node health, tunnel status, UPS metrics.
- External uptime monitor (healthchecks/Upptime) from cloud vantage point to detect WAN outages.
- Alerts to Slack/email via SMTP/webhooks (ensure egress allowed).

## CI/CD Integration
- Optional self-hosted GitHub runners on k3s (resource bound). Set concurrency limits to avoid saturating bandwidth.
- GitOps pipeline (Argo CD) syncs home overlays; same repo houses staging/prod overlays for future cloud move.
- Build artifacts pushed to external registry to avoid large downloads from home network.

## Operations & Runbooks
- **Power/ISP outage**: UPS covers short downtime; on battery low, gracefully shut down nodes. Document restart order (modem → router → tunnel → cluster).
- **Backups**: Nightly PostgreSQL dump and MinIO sync to cloud storage during off-peak hours; verify restore monthly.
- **Node maintenance**: `kubectl drain`, apply updates, reboot, `kubectl uncordon`. Keep spare SD/NVMe images for quick replacement.
- **Security review**: Monthly checklist (patches, access logs, Cloudflare Access audit, tunnel key rotation).

## Migration Path
1. Maintain parity between `home` and `staging` overlays in GitOps repo.
2. Stand up cloud cluster; add as secondary Argo CD cluster.
3. Cut DNS from `home` to cloud environment service-by-service; keep home cluster as dev lab.
4. Decommission home exposure once cloud takes over or retain as backup.

## Risks & Mitigations
| Risk | Mitigation |
| --- | --- |
| CGNAT blocks inbound | Use Cloudflare Tunnel or WireGuard to VPS. |
| Power failure | UPS, automated shutdown scripts, documented recovery. |
| Bandwidth saturation | Rate-limit uploads, schedule backups overnight, monitor usage. |
| Security compromise | Zero Trust access, VLAN isolation, regular patching, centralized logging. |
| Hardware failure | Keep spare components, GitOps redeploy from repo, offsite backups. |

## Next Steps
1. Provision Cloudflare Tunnel + Access policies and validate connectivity.
2. Build k3s cluster with GitOps `home` overlay; deploy Authentik + CMS first.
3. Configure observability + external uptime checks.
4. Document recovery and migration runbooks; review quarterly.
