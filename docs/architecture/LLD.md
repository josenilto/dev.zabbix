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

The trust boundary is the **namespace**, not the pod: default-deny
(`templates/networkpolicy/default-deny.yaml`) locks every pod down to DNS-only egress,
then `allow-same-namespace.yaml` re-opens unrestricted ingress+egress *between pods in
this namespace only*. This chart bundles ~10 upstream components (kube-prometheus-stack,
Grafana, Loki, Alloy, Tempo, OTel Collector, the DB subchart) as one release, each with
its own pod-label conventions - hand-enumerating every internal service pairing across
charts this repo doesn't control would be fragile (silently breaks on a subchart upgrade
that changes a label or port) for little real security benefit, since namespace isolation
and RBAC are already the primary tenancy boundary (see `docs/security/iam-model.md`).

What stays explicitly scoped are the two genuine external boundaries
(`allow-internal.yaml`): frontend ingress from `networkPolicy.allowFromNamespaces`
(typically the ingress controller) and, optionally, a cluster-wide meta-monitoring
Prometheus scraping in from another namespace. Egress to the internet
(`allow-egress.yaml`) is scoped by port only (443/8200/587) to any destination, since
Vault/cloud provider APIs/webhook receivers are reached by DNS name with unstable IPs -
vanilla NetworkPolicy has no way to allow-by-DNS-name. For tighter control than
"by port, anywhere," add a network-layer egress firewall/proxy in front of the cluster.

## Storage classes

Referenced via `global.storageClass`, left empty (cluster default) at the base layer and
set explicitly per cluster in `gitops/clusters/<cloud>/<env>/values.yaml` (e.g. `gp3` on
EKS, `managed-csi-premium` on AKS, `premium-rwo` on GKE, `oci-bv` on OKE, `ceph-rbd`
on-prem, `ocs-storagecluster-ceph-rbd` on OpenShift/ODF).
