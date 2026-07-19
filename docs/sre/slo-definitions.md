# SRE / Service Level Objectives

## Golden Signals

Tracked platform-wide via `templates/prometheusrule/golden-signals.yaml`: latency,
traffic, errors, saturation, plus two Zabbix-specific signals (HA cluster node count,
proxy buffer growth) that don't map cleanly onto the generic four.

## SLO model

Defaults in `values.yaml` `slo.defaults` (99.95% availability, 500ms P95 latency, 1% error
rate) apply platform-wide unless a specific service is listed in `slo.services` with its
own targets - populate that list per-application in the relevant
`gitops/clusters/<cloud>/<env>/values.yaml` overlay, not in the base chart (SLOs are a
per-service, per-environment decision, not a chart default).

```yaml
slo:
  services:
    - name: zabbix-frontend
      availability: "99.9"
      latencyP95Ms: 800
      errorRateThreshold: "0.02"
```

Each entry generates:
- Three recording rules (`slo:errors_ratio:ratio_rate5m/1h/6h`) - pre-aggregated so the
  burn-rate alert expressions stay cheap at query time.
- A fast-burn alert (`SLOFastBurn-<service>`, 14.4x burn rate over 5m+1h windows, 2m
  `for` - pages within minutes of a truly severe error spike).
- A slow-burn alert (`SLOSlowBurn-<service>`, 6x burn rate over 6h, 30m `for` - a ticket,
  not a page, for a sustained-but-moderate degradation).

This is the Google SRE Workbook's standard multi-window, multi-burn-rate pattern,
parameterized off each service's own `availability` target rather than a single
platform-wide constant - see `templates/prometheusrule/slo-burn-rate.yaml`.

## Error budget

Error budget = `1 - (availability / 100)`. At 99.95% availability that's a 0.05% budget,
or roughly 21.6 minutes of full-outage-equivalent error rate per 30 days. The
`SREGoldenSignals` Grafana dashboard's "Error Budget Burn Rate" panel plots the 1h and 6h
burn-rate series directly so a reviewer can see how much of the monthly budget a given
incident actually consumed, not just whether an alert fired.

## MTTR / MTTD / Incident Rate

Not computed automatically by this platform - they're derived from Alertmanager's alert
history (time-to-acknowledge, time-to-resolve) and your incident-management tool
(PagerDuty/Opsgenie incident timestamps). If you need these as first-class metrics,
export them from PagerDuty/Opsgenie's own API into a small Prometheus exporter and add it
as another `additionalScrapeConfigs` entry - the pattern is identical to the cloud
exporters in `docs/cloud/`.

## Where SLOs show up

- **SRE dashboard** (`templates/grafana/dashboard-sre-golden-signals.yaml`) - Golden
  Signals + burn-rate panels, filterable by service.
- **Alerting** (`templates/prometheusrule/slo-burn-rate.yaml`) - pages/tickets as
  described above.
- **Executive dashboards** - availability/SLA rollups are a natural addition to the
  `Executive` Grafana folder alongside the FinOps cost dashboard already shipped
  (`templates/grafana/dashboard-finops-cost.yaml`); not built out further here since the
  exact business-KPI framing is organization-specific.
