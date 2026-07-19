# Disaster Recovery

## Targets

| Component | RTO | RPO | Notes |
|---|---|---|---|
| Zabbix Server (single cluster failure) | < 15 min | 0 (no data loss) | Multi-AZ HA cluster already tolerates a single node/AZ failure with zero RTO; this row is for a full-cluster loss requiring failover to a standby region |
| Zabbix database | < 1h | < 15 min | Cloud-native automated backups (managed DB) or Velero+CSI snapshot (internal MySQL) |
| Prometheus/Loki/Tempo (metrics/logs/traces history) | < 4h | Best-effort beyond the object-storage replication window | These are observability data, not systems of record - prioritize restoring collection over historical backfill |
| Argo CD / GitOps control plane | < 30 min | 0 (Git is the source of truth) | Re-bootstrap via `gitops/bootstrap/app-of-apps.yaml` against any cluster with Argo CD installed |
| Whole-platform, single-region cloud outage | < 4h | < 15 min | Requires a pre-registered standby cluster in another region/cloud - see below |

## Cross-region / cross-cloud failover

1. A standby cluster (same cloud, different region, or a different cloud entirely) must
   already be registered in the `ApplicationSet` (`gitops/applications/zabbix-enterprise/applicationset.yaml`)
   with its own `gitops/clusters/<cloud>/<env>/values.yaml` - **provisioning the standby
   cluster during the incident is not a DR plan**, it must exist beforehand.
2. Point `database.external.host` (or restore the internal MySQL PVC from the latest
   Velero/cloud-native backup, see [backup-restore.md](backup-restore.md)) at the
   restored database.
3. Update DNS (`global.domain`) to the standby cluster's ingress.
4. Confirm Zabbix Proxies for the affected region can reach the new Zabbix Server
   endpoint (proxy `ZBX_SERVER_HOST` is derived from the chart's own headless Service, so
   this only needs attention if proxies are pinned to a hardcoded address outside the
   chart).

## Immutable backups

Velero backups target object storage with versioning/object-lock enabled
(`backupStorageLocation`) so a compromised cluster credential cannot also delete the
backups that would be used to recover from that same compromise - this is a deliberate
Zero Trust control, not just a retention setting.

## DR testing cadence

- Quarterly: restore drill (see [backup-restore.md](backup-restore.md) "Testing restores").
- Annually: full regional failover game-day against the standby cluster, including DNS
  cutover, with a written retrospective.
