# Changelog

All notable changes to the `zabbix-enterprise` chart are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/), versions follow
the chart's own SemVer (`Chart.yaml` `version:`), independent of `appVersion` (the Zabbix
version being deployed).

## [0.2.0] - Robustness pass

### Fixed
- **Critical**: `NetworkPolicy` egress was locked to DNS-only with no path back out for
  the database, Vault, or any cloud/webhook endpoint - the platform as shipped in 0.1.0
  could not actually run with `global.networkPolicy.enabled: true` (the default).
  Replaced the label-based intra-namespace rules (which only matched this chart's own
  Zabbix components, not the ~10 bundled upstream subcharts using their own label
  conventions) with a namespace-is-the-trust-boundary model
  (`allow-same-namespace.yaml`) plus explicit external allows
  (`allow-egress.yaml`, HTTPS/Vault/SMTP by port).
- Two pod-affinity `labelSelector` blocks (zabbix-frontend, zabbix-proxy) were missing
  one level of `matchLabels` nesting, making the selector labels invalid siblings instead
  of children - caught by kubeconform schema validation.
- `values-<cloud>.yaml` forced `database.external.enabled: true` at the cloud layer,
  which combined with `values-dev.yaml` would have required an external database even in
  dev. Database activation is now purely an environment decision
  (`values-dev/hml/prd.yaml`); the cloud layer only supplies engine-specific defaults.
- An unquoted Slack channel value (`#noc-alerts`) rendered as a YAML comment, silently
  dropping the field. A duplicate `app.kubernetes.io/part-of` label from
  `global.labels` colliding with the standard labels helper.

### Added
- `startupProbe` on Zabbix Server/Frontend, generous enough to cover a first-boot schema
  migration or HA node registration without a premature restart.
- `wait-for-db` init container on Zabbix Server/Frontend, so a fresh install doesn't
  crash-loop racing against the internal MySQL/PostgreSQL subchart's own startup.
- `database.external.host` is now an actually-consumed plain value (hostnames aren't
  secret) with a `required` guard - forgetting it fails fast at render time instead of
  deploying a server that can never reach its database. Only username/password stay
  Vault-sourced for the external path.
- `PodDisruptionBudget` and readiness/liveness probes for Zabbix Proxy; readiness/
  liveness probes for all four cloud exporter Deployments.
- `ResourceQuota`/`LimitRange` baseline for the namespace (`gitops/infrastructure/`).
- helm-unittest coverage for the new NetworkPolicy model and the required-value guard's
  failure path.

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
