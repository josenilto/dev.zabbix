# Low-Level Design

## Namespace layout (per cluster)

| Namespace | Contents | Managed by |
|---|---|---|
| `zabbix-enterprise` | The entire `zabbix-enterprise` Helm release: Zabbix Server/Frontend/Agent2/Proxy + Prometheus/Grafana/Loki/Alloy/OTel Collector/Tempo subcharts | Argo CD `Application` (per-cluster, from the `ApplicationSet`) |
| `monitoring` | Cluster-wide shared controllers used by every tenant: External Secrets Operator, Kyverno, Velero | `gitops/infrastructure/` (once per cluster) |
| `argocd` | Argo CD itself | Pre-existing / bootstrapped separately |

Everything in the observability stack lives in one namespace per environment because it
is one Helm release - see `gitops/README.md` "Why an umbrella chart" for the reasoning.

## Zabbix Server HA cluster

Native HA clustering (Zabbix >=6.4, `ZBX_HANODENAME`/`ZBX_NODEADDRESS` env vars, no
external leader-election sidecar needed). `zabbix.server.replicaCount` nodes share one
database; each Pod registers itself under its own pod name as HA node name. Pod
anti-affinity (`zabbix.server.podAntiAffinity: hard` in prd) plus topology spread
constraints keep replicas off the same node/zone. Export directory PVC must be
ReadWriteMany once `replicaCount > 1` (see `templates/zabbix-server/pvc.yaml`).

## Zabbix Proxy topology

One StatefulSet per logical proxy instance (`values.zabbix.proxy.instances`, populated
per `values-<cloud>.yaml`), each independently scaled via `zabbix.proxy.ha.replicaCount`.
Active proxies (`mode: active`, the default for cloud regions) pull their configuration
from and push data to Zabbix Server outbound - this is what lets a proxy sit behind NAT
with no inbound firewall rule. Passive proxies (`mode: passive`, used on-prem in
`values-onprem.yaml` where the server can reach the datacenter directly) are polled by
the server instead. Store-and-forward buffering (`zabbix.proxy.buffering.offlineBuffer`,
90 days in prd) keeps history intact through a prolonged link outage to the central
server.

## Resource sizing baseline (prd, per Zabbix Server HA node)

| Resource | Request | Limit |
|---|---|---|
| CPU | 1 core | 4 cores |
| Memory | 2Gi | 8Gi |
| Cache (`ZBX_CACHESIZE`) | 256M | - |
| History cache | 256M | - |
| Trend cache | 128M | - |
| Value cache | 512M | - |

Prometheus (`kube-prometheus-stack.prometheus.prometheusSpec`) in prd: 3 replicas, 90d
retention, 500Gi PVC each. Adjust retention/storage against actual cardinality - these are
starting points, not a substitute for capacity planning against real query load.

## Network policy model

Default-deny (`templates/networkpolicy/default-deny.yaml`) plus four explicit allow
policies: server ingress (from any `part-of=zabbix-enterprise` pod, i.e. proxies/frontend,
plus the `monitoring` namespace for external scrapers), frontend ingress (from
`networkPolicy.allowFromNamespaces`, typically the ingress controller), agent ingress
(trapper reverse-connections from server/proxies only), and monitoring-scrape ingress
(Prometheus/Alloy pulling `/metrics`). Egress is deny-all except DNS - every component
that needs to reach outside the namespace (Vault, cloud APIs, the exporters) does so over
the podSelector-scoped allow rules, not a namespace-wide egress punch-through.

## Storage classes

Referenced via `global.storageClass`, left empty (cluster default) at the base layer and
set explicitly per cluster in `gitops/clusters/<cloud>/<env>/values.yaml` (e.g. `gp3` on
EKS, `managed-csi-premium` on AKS, `premium-rwo` on GKE, `oci-bv` on OKE, `ceph-rbd`
on-prem, `ocs-storagecluster-ceph-rbd` on OpenShift/ODF).
