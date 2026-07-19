# Backup & Restore

## What's backed up and how

| Component | Method | Schedule (prd) | Retention |
|---|---|---|---|
| Zabbix database (internal MySQL, dev/hml only) | Velero (PVC snapshot via CSI) | Daily, 02:00 (`values.velero.schedules.daily`) | 90 days, immutable object-storage backend |
| Zabbix database (external/managed, prd) | Cloud-native DB backup (RDS/Azure DB/Cloud SQL/Autonomous DB automated backups) - **not** Velero | Per cloud provider defaults, aligned to 90-day retention | 90 days |
| Kubernetes object state (all namespaces in scope) | Velero | Daily, 02:00 | 90 days |
| Grafana dashboards/datasources | Git (they're provisioned from ConfigMaps in this chart) | N/A - source of truth is this repo | N/A |
| Zabbix templates | Git (ConfigMaps under `templates/cloud-integrations/`) + the template-sync CronJob re-applies them | N/A | N/A |
| Prometheus/Loki/Tempo data | Object storage replication (S3/GCS/Azure Blob/OCI Object Storage per cloud), not Velero | Continuous | Per `loki`/`tempo`/`prometheus` retention settings |

Velero itself is a cluster-wide add-on (`values.velero.enabled`, but the controller
typically lives in the `monitoring` namespace per cluster, installed once - see
`gitops/infrastructure/`).

## Restore procedure

### Kubernetes object state (Velero)

```bash
velero backup get
velero restore create --from-backup <backup-name> --include-namespaces zabbix-enterprise
```

Restoring object state does **not** restore PVC contents unless the backup used CSI
snapshots (`velero.io/csi-snapshot`) or File System Backup (restic/kopia) - confirm which
mode is configured before relying on this for the database PVC specifically.

### Zabbix database (internal MySQL)

```bash
# Restore the PVC via Velero (see above), then let the StatefulSet's mysqld
# reattach - no separate mysqldump/restore step needed if the PVC snapshot is consistent.
# For a logical (mysqldump) backup/restore instead:
kubectl -n zabbix-enterprise exec -it zabbix-enterprise-mysql-0 -- \
  mysql -u root -p zabbix < zabbix-backup.sql
```

### Zabbix database (external/managed)

Follow the cloud provider's point-in-time-restore procedure (RDS/Azure DB/Cloud SQL/ADB
all support this natively) - restore to a new instance, then update
`gitops/clusters/<cloud>/<env>/values.yaml` `database.external.host` to point at it
during a maintenance window, rather than restoring in place.

## Testing restores

A backup that has never been restored is not a backup. At minimum, quarterly: restore the
most recent Velero backup into a scratch namespace/cluster and confirm Zabbix Server
starts cleanly against the restored database. Track this as its own recurring
maintenance-window activity, not something to only discover is broken during a real DR
event.
