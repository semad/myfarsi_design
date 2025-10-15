# On-Call Playbooks

Use this index to link PagerDuty rotations and SRE checklists to the relevant runbooks. Add these paths to the incident response documentation so responders can access procedures without searching the repository.

## Core Services
- Kafka Messaging: `docs/media/kafka-runbook.md`
- Media Processing Pipelines: `docs/media/processing-runbook.md`
- MinIO Storage: `docs/content/minio-runbook.md`
- Vault Secrets for MinIO: `docs/security/vault-minio.md`

## How to Integrate
1. Update PagerDuty service descriptions to include the applicable runbook URLs (repository path or internal docs link).
2. During handoff, remind incoming on-call engineers to bookmark these runbooks.
3. After incidents, append links to the referenced runbooks in postmortem templates.
4. Keep this index current whenever new runbooks are added.
