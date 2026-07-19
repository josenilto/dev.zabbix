# Incident Response

## Severity model

| Severity | Definition | Examples | Response |
|---|---|---|---|
| Critical (P1) | Fast error-budget burn (`SLOFastBurn-*`) or a mission-critical component fully down (`ZabbixServerDown`, HA cluster below quorum) | Zabbix Server HA cluster degraded, RDS/Cloud SQL unreachable | Page immediately (PagerDuty), incident commander assigned within 5 min |
| Warning (P2) | Slow error-budget burn (`SLOSlowBurn-*`), saturation trending toward a threshold | CPU throttling, proxy buffer growing | Ticket + Slack notification, business-hours response |
| Info | Non-actionable signal, informational only | Deploy notifications, scaling events | No paging |

This maps directly onto `alerting.route` (`templates/prometheusrule/alertmanager-config.yaml`)
and the burn-rate alerts in `templates/prometheusrule/slo-burn-rate.yaml`.

## On call

Configured per `alerting.receivers` (`values.yaml`): PagerDuty for critical, Slack/Teams
for warning, email as a fallback. Maintenance windows are declared in
`alerting.maintenanceWindows` (populate per planned change to suppress noise without
disabling the underlying alert).

## Incident workflow

1. **Detect** - alert fires via Alertmanager → PagerDuty/Slack, or a NOC operator notices
   in Grafana.
2. **Triage** - open the relevant Grafana dashboard (`SRE - Golden Signals` for
   application-level incidents, `Platform Overview` for infra-level), confirm scope
   (single cloud/cluster vs. platform-wide).
3. **Mitigate** - follow [troubleshooting.md](troubleshooting.md) for the specific
   symptom; for anything touching Kubernetes resources, prefer `kubectl rollout
   undo`/Argo CD rollback (see [rollback.md](rollback.md)) over ad-hoc `kubectl edit`,
   since GitOps will otherwise silently revert an untracked manual fix on the next sync.
4. **Communicate** - status updates in the incident channel every 30 min for P1, every
   2h for P2, referencing the specific PromQL/Zabbix trigger driving severity.
5. **Resolve** - confirm the alert has cleared in Alertmanager, not just that the
   dashboard "looks fine" (a flapping alert that auto-resolves is still worth a
   post-incident note).
6. **Post-incident** - blameless review within 5 business days for any P1; capture the
   error-budget impact (see [SRE/SLOs](../sre/slo-definitions.md)) and whether a new
   `PrometheusRule`/Zabbix trigger would have caught it earlier.

## Escalation

Default escalation path: on-call SRE → platform engineering lead → incident commander
(for cross-team/customer-visible incidents). Configure the actual PagerDuty escalation
policy outside this repository (PagerDuty service config), referenced here only by the
`integrationKeySecretRef` in `values.yaml`.
