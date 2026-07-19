# Operations Runbook

## Bootstrapping database credentials

Production and hml **always** use `externalSecrets.enabled: true`, so the DB credentials
Secret is materialized by `templates/database/externalsecret.yaml` from Vault - nothing to
do manually beyond writing the credentials to the Vault path once:
`secret/data/zabbix-enterprise/<env>/<cloud>/database` with keys `host`, `username`,
`password`.

For a from-scratch dev sandbox with no Vault/External Secrets Operator installed, create
the same Secret directly:

```bash
kubectl -n zabbix-enterprise create secret generic zabbix-db-credentials \
  --from-literal=host=zabbix-enterprise-mysql \
  --from-literal=username=zabbix \
  --from-literal=password=change-me
```

The Zabbix API credentials consumed by the template-sync CronJob follow the same pattern
at `secret/data/zabbix-enterprise/<env>/<cloud>/zabbix-api` (or
`kubectl create secret generic zabbix-api-credentials ...` for dev).

## Common procedures

### Check Zabbix Server HA cluster status

```bash
kubectl -n zabbix-enterprise exec deploy/zabbix-enterprise-zabbix-server -- \
  zabbix_server -R ha_status
```

Every replica should show `active` or `standby` with a recent `lastaccess` timestamp. A
node stuck in `unknown` for more than a few minutes has lost contact with the shared
database - check DB connectivity from that pod first.

### Force a Zabbix template re-sync

The CronJob runs hourly; to force it immediately:

```bash
kubectl -n zabbix-enterprise create job --from=cronjob/zabbix-enterprise-template-sync \
  manual-template-sync-$(date +%s)
```

### Add a new cloud/region proxy

1. Add an entry to `zabbix.proxy.instances` in the relevant `values-<cloud>.yaml` (name,
   mode, region).
2. Merge to `main` - Argo CD reconciles a new StatefulSet automatically (see
   `templates/zabbix-proxy/statefulset.yaml`, which ranges over that list).
3. Register the proxy in Zabbix (Data collection → Proxies) if it isn't auto-registered,
   and reassign the hosts it should collect for.

### Rotate the Vault AppRole/Kubernetes-auth role used by ExternalSecrets

Rotating credentials in Vault itself requires no chart change - `refreshInterval` (1h by
default, `values.externalSecrets.vault.refreshInterval`) picks up the new value on the
next reconcile. Rotating the *auth method* (e.g. a new Kubernetes auth role) is a
`gitops/infrastructure/security/clustersecretstore-vault.yaml` change, applied once per
cluster.

## Where to look when something's wrong

| Symptom | Start here |
|---|---|
| Frontend 502/503 | `kubectl -n zabbix-enterprise logs deploy/zabbix-enterprise-zabbix-frontend`, then check `ZBX_SERVER_HOST` resolves (server headless Service) |
| No new data for a host | Check the owning proxy's buffer (`ZabbixProxyBufferGrowing` alert), then agent connectivity |
| Alerts not reaching Slack/PagerDuty | `AlertmanagerConfig` receiver secret refs - confirm the referenced Secret exists and has the right key name |
| Dashboards show "no data" | Datasource health in Grafana UI first (Zabbix datasource needs the `alexanderzobnin-zabbix-app` plugin actually installed - check `grafana.plugins`) |

See also [troubleshooting.md](troubleshooting.md) and [incident-response.md](incident-response.md).
