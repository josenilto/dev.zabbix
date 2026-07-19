# zabbix-enterprise

Umbrella Helm chart: Zabbix Server/Frontend/Agent2/Proxy (custom-built templates in this
chart) plus Prometheus, Grafana, Loki, Grafana Alloy, the OpenTelemetry Collector and
Tempo (declared as `Chart.yaml` dependencies on their official upstream charts).

## Layering model

```
values.yaml  →  values-<env>.yaml  →  values-<cloud>.yaml  →  gitops/clusters/<cloud>/<env>/values.yaml
 (safe          (dev/hml/prd           (aws/azure/gcp/oci/       (this exact cluster: name,
  defaults)      sizing/HA)             onprem/openshift          domain, storage class,
                                        specifics)                 real endpoints)
```

Every file after the first only overrides what's actually different at that layer - don't
duplicate settings that are already correct from an earlier layer.

## Installing dependencies

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add external-secrets https://charts.external-secrets.io
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update
helm dependency update .
```

The dependency version ranges in `Chart.yaml` are indicative starting points, not
verified-latest pins - review `Chart.lock` after the first `dependency update` and pin
exact versions before production use.

## Folder guide

| Path | Contents |
|---|---|
| `templates/zabbix-server/` | Zabbix Server Deployment (native 6.4+ HA cluster mode), Service, ConfigMap, PVC, PDB, template-sync CronJob, API ExternalSecret |
| `templates/zabbix-frontend/` | Frontend Deployment/Service/Ingress/HPA/PDB |
| `templates/zabbix-agent/` | Agent2 DaemonSet (node-level facts) |
| `templates/zabbix-proxy/` | Per-instance StatefulSets (one per cloud/region/datacenter, see `zabbix.proxy.instances`) |
| `templates/database/` | ExternalSecret bridging Vault → the DB credentials Secret consumed by server/frontend/the bitnami DB subchart |
| `templates/rbac/` | ServiceAccount, namespaced Role, cluster-scoped read-only ClusterRole |
| `templates/networkpolicy/` | Zero-Trust default-deny + explicit allow-* policies |
| `templates/servicemonitor/`, `templates/prometheusrule/` | Prometheus Operator wiring: scrape config, golden-signals alerts, SLO burn-rate alerts, Alertmanager routing |
| `templates/security/` | SealedSecrets alternative to ExternalSecrets |
| `templates/grafana/` | Datasource + dashboard provisioning ConfigMaps (sidecar pattern) |
| `templates/alloy/` | Grafana Alloy River pipeline config (K8s discovery → Prometheus/Loki, OTLP front door → Tempo) |
| `templates/cloud-integrations/<cloud>/` | Exporter Deployment + worked-example Zabbix templates per cloud |
| `tests/` | helm-unittest suite |

## Security notes specific to this chart

- Cluster-scoped objects that should exist **once per cluster**, not once per Helm
  release (Kyverno `ClusterPolicy`, the Vault `ClusterSecretStore`, namespace PSS labels)
  are deliberately **not** templated here - they live in `gitops/infrastructure/` so a
  `helm uninstall` can never accidentally remove a policy other tenants depend on.
- No Secret ever contains plaintext credentials in this repository. Every credential is
  either an `ExternalSecret` (`externalSecrets.enabled: true`, the production path) or,
  for simpler environments, a `SealedSecret` (`externalSecrets.sealedSecrets.enabled: true`).
  For a from-scratch dev sandbox with neither installed, pre-create the Secret manually
  (see the root README quickstart and `docs/operations/runbook.md`).
