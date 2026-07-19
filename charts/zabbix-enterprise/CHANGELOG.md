# Changelog

All notable changes to the `zabbix-enterprise` chart are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/), versions follow
the chart's own SemVer (`Chart.yaml` `version:`), independent of `appVersion` (the Zabbix
version being deployed).

## [0.1.0] - Initial scaffold

### Added
- Zabbix Server (native HA cluster mode, >=6.4), Frontend, Agent2 (DaemonSet), Proxy
  (multi-instance StatefulSets) templates.
- Dependencies on kube-prometheus-stack, grafana, loki, alloy, opentelemetry-collector,
  tempo, external-secrets, velero, opencost.
- Environment overlays (dev/hml/prd) and cloud overlays (aws/azure/gcp/oci/onprem/openshift).
- Worked-example cloud integrations: AWS (EC2, RDS), Azure (VM, SQL Database), GCP
  (Compute Engine, Cloud SQL), OCI (Compute, Autonomous Database), on-prem (VMware
  hypervisor via the native Zabbix Server collector).
- RBAC, NetworkPolicy (default-deny + explicit allows), ExternalSecrets/Vault wiring,
  SealedSecrets alternative.
- Grafana datasource/dashboard provisioning, Prometheus golden-signals + SLO burn-rate
  alerting, Alertmanager routing.
- Zabbix template auto-import CronJob (closes the Configuration-as-Code loop for the
  ConfigMap-shipped Zabbix templates).
- helm-unittest test suite, `values.schema.json`.
