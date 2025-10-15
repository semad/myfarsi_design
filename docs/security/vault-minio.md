# Vault Secrets for MinIO

## Purpose
Document how MinIO credentials are managed in Vault so operators can rotate secrets, troubleshoot access, and ensure compliance. This runbook supports the references in `docs/content/minio-runbook.md` and `21_content_manager/minio-content-server.md`.

## Secret Layout
| Path | Description | Notes |
| --- | --- | --- |
| `secret/minio/root` | Root user access key and secret for bootstrap/emergency use | Encrypted, read by ops only; rotate quarterly. |
| `secret/minio/replication` | Credentials used for cross-cluster replication jobs | Scoped to replication tasks; no console access. |
| `secret/minio/<service>/static` | Long-lived access keys for legacy services (avoid when possible) | Marked for deprecation; migrate to STS. |
| `kv/minio/roles/<service>` | STS role definitions for dynamic credentials issued to workloads | Used by `minio-control` and automation pipelines. |

Secrets live in Vault KV v2 (`secret/`) unless otherwise stated. Access is granted through Vault policies attached to Consul/Vault identities or AppRole logins.

## Dynamic Credential Workflow
1. Platform team defines STS role data in Vault (`kv/minio/roles/<service>`), including allowed buckets and policies.
2. `minio-control` or workloads authenticate to Vault (Kubernetes auth or AppRole) and request the role path.
3. Vault function calls MinIO AssumeRole API (or wrapper) to mint short-lived credentials (TTL <= 15 minutes).
4. `minio-control` caches credentials in memory only; services use them to upload or download objects.

## Rotation Procedures
### Root Credentials
1. Generate new keys via MinIO console or `mc admin user svcacct add`.
2. Update Vault entry:
   ```bash
   vault kv put secret/minio/root access_key=<new> secret_key=<newSecret>
   ```
3. Restart control-plane deployments consuming root credentials (if any).
4. Remove old keys from MinIO (`mc admin user svcacct rm`).

### Replication Credentials
1. Pause replication jobs (`mc admin replicate pause`).
2. Create new user/keys dedicated to replication.
3. Update `secret/minio/replication` and restart replication job pods.
4. Resume replication; monitor `mc admin replicate status`.

### Static Service Keys
1. Identify services using static keys (`secret/minio/<service>/static`).
2. Migrate to STS roles by updating service configuration to request dynamic credentials.
3. After migration, delete static keys from Vault and MinIO.

## Access Control
- Policies (`policies/minio-*.hcl`) grant least privilege:
  - Ops: read/write root and replication secrets.
  - Automation: read-only specific role paths.
  - Services: access only through AppRole/Kubernetes auth with restrictions (`bound_service_account_names`, CIDR).
- Enable audit devices (file, syslog) to capture secret read/write events; logs forwarded to SIEM.
- Review policy assignments quarterly per security requirements.

## Troubleshooting
- **Access Denied**: Check Vault policy for role path; ensure TTL not expired. Validate MinIO policy attached to the STS role.
- **STS Failure**: Inspect `minio-control` logs for AssumeRole errors; verify MinIO IAM configuration.
- **Drift Detection**: Scheduled job compares Vault role definitions with GitOps source. Investigate mismatches promptly.

## References
- `docs/content/minio-runbook.md`
- `21_content_manager/minio-content-server.md`
- `01_conf_mgmt/adr/0001-secret-rotation.md`
- Vault operator guide (`docs/security/vault-ops.md`, pending)
