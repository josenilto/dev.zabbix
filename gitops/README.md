# GitOps layer

Argo CD-driven deployment of the `zabbix-enterprise` chart across every registered
cloud/environment cell, plus the cluster-scoped prerequisites each cluster needs before
that chart can reconcile successfully.

## Bootstrapping a new management cluster

```bash
kubectl apply -f gitops/bootstrap/app-of-apps.yaml
```

This is the **only** manual step. It creates a root Argo CD `Application` that
recursively watches `gitops/applications/**` and `gitops/infrastructure/**` - every
subsequent change (a new cluster, a new policy, a rotated cluster secret store) ships by
merging to `main`, never by running `kubectl apply` again by hand.

## Folder guide

| Path | Purpose |
|---|---|
| `applications/zabbix-enterprise/project.yaml` | `AppProject` - scopes which repos/destinations/resource kinds the platform is allowed to touch (least privilege, multi-tenancy boundary) |
| `applications/zabbix-enterprise/applicationset.yaml` | `ApplicationSet` (list generator) - one Argo CD `Application` per registered cloud × environment cell |
| `clusters/<cloud>/<env>/values.yaml` | The last values layer: things genuinely specific to *this* cluster (name, domain, storage class, real DB/object-storage endpoints) |
| `infrastructure/namespaces/` | Namespaces with Pod Security Admission labels |
| `infrastructure/rbac/` | Cluster-wide OIDC/SSO group → Kubernetes RBAC bindings |
| `infrastructure/policies/` | Kyverno `ClusterPolicy` baseline (non-root, no privileged, resource limits required, image signature verification) |
| `infrastructure/security/` | The Vault `ClusterSecretStore` every `ExternalSecret` in the chart references by name |

## Adding a new cluster

1. Register the cluster with Argo CD (`argocd cluster add <context>`), or reference it by
   its Kubernetes API server URL if already registered.
2. Add one element to the `list` generator in `applicationset.yaml` (cloud, environment,
   `clusterServer`).
3. Create `gitops/clusters/<cloud>/<env>/values.yaml` with that cluster's specifics
   (copy the pattern from an existing cloud - e.g. `clusters/aws/prd/values.yaml`).
4. Merge to `main`. The `ApplicationSet` controller picks up the new list element and
   creates the `Application` automatically - no separate `Application` YAML to write.

## Why an umbrella chart instead of six per-component Applications

The original spec sketches `gitops/applications/{zabbix,prometheus,grafana,loki,...}/` as
separate folders. In practice, Prometheus/Grafana/Loki/Alloy/Tempo/OTel are declared as
`Chart.yaml` *dependencies* of the single `zabbix-enterprise` chart (see
`charts/zabbix-enterprise/README.md`), so one Argo CD `Application` per cluster/environment
deploys the whole stack atomically, with Helm resolving install order via its own
dependency/hook mechanism. Splitting them into six independently-synced Applications would
mean hand-managing cross-chart ordering and version compatibility yourself instead of
letting Helm do it - only worth it if a component genuinely needs an independent release
cadence from the rest of the platform.
