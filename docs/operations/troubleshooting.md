# Troubleshooting

## Zabbix Server won't start / CrashLoopBackOff

1. `kubectl -n zabbix-enterprise logs deploy/zabbix-enterprise-zabbix-server` - almost
   always a database connectivity or schema issue on first boot.
2. Confirm the `zabbix-db-credentials` (or external DB) Secret resolved
   (`kubectl -n zabbix-enterprise get secret zabbix-db-credentials -o yaml` - values are
   base64, decode to check they're non-empty, not that they're correct).
3. If using the internal MySQL subchart, confirm it's actually `Ready`
   (`kubectl -n zabbix-enterprise get pods -l app.kubernetes.io/name=mysql`) before the
   server - Helm does not sequence subchart readiness automatically; a first install can
   race. A second `helm upgrade`/Argo CD auto-heal resolves this.

## HA cluster split-brain / node stuck as standby

Check `zabbix_server -R ha_status` on every replica (see runbook.md). If more than one
node claims `active`, it almost always means two nodes can't see the same database (e.g.
a network partition mid-failover) - check connectivity from both pods before touching
`ha_remove_node`.

## Proxy buffer growing (`ZabbixProxyBufferGrowing` alert)

The proxy can reach its local buffer but not the central Zabbix Server. Check:

```bash
kubectl -n zabbix-enterprise exec sts/zabbix-enterprise-zabbix-proxy-<instance> -- \
  nc -zv zabbix-enterprise-zabbix-server-headless 10051
```

If connectivity is fine, check the server isn't itself saturated (`ZBX_STARTPOLLERS` too
low for the actual host count, or the HA cluster genuinely down).

## Prometheus target down

`up{job="..."} == 0` fires `ZabbixServerDown` and similar. Check the `ServiceMonitor`
selector actually matches the Service's labels
(`kubectl -n zabbix-enterprise get servicemonitor zabbix-enterprise-zabbix -o yaml`) and
that `kube-prometheus-stack.prometheus.prometheusSpec.additionalScrapeConfigs`
(for the cloud exporters) points at a Service that exists.

## AlertmanagerConfig not taking effect

`kube-prometheus-stack.alertmanager.alertmanagerSpec.alertmanagerConfigSelector` and
`alertmanagerConfigNamespaceSelector` must both be empty (`{}`) - the default in
`values.yaml` - for the `AlertmanagerConfig` in `templates/prometheusrule/alertmanager-config.yaml`
to be picked up regardless of which namespace this chart lands in relative to
`kube-prometheus-stack`. If either was tightened by an override, this is the first thing
to check.

## Grafana dashboard shows "no data" but the datasource test succeeds

Almost always a label mismatch between the dashboard's PromQL (`cloud=~"$cloud"`,
`environment=~"$environment"`) and what's actually attached to the metric. Confirm your
`ServiceMonitor`/scrape target relabeling actually sets `cloud`/`environment` labels
(external scrape jobs like the cloud exporters need this added explicitly via
`relabel_configs` - it isn't automatic).

## CI failing on `helm dependency update`

Almost always a stale/wrong version range in `Chart.yaml` `dependencies:` - the ranges
shipped here are indicative starting points (see the chart README), not verified-latest
pins. Widen or correct the range, re-run, then narrow it back down and commit the
resulting `Chart.lock`.
