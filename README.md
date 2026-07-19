# Zabbix Enterprise Multi-Cloud Observability Platform

A single Helm chart + GitOps repository that deploys Zabbix as the infrastructure/business
monitoring core of a unified observability platform - wired together with Prometheus,
Grafana, Loki, Grafana Alloy, the OpenTelemetry Collector and Tempo - across AWS, Azure,
GCP, OCI, on-premises, Kubernetes and OpenShift.

```
                    ┌──────────────────────────────┐
                    │  NOC / SOC / SRE / DEV / OPS  │
                    └──────────────┬───────────────┘
                                   ▼
                         Grafana (dashboards/SLOs)
                                   ▲
                ┌──────────────────┼──────────────────┐
             Zabbix            Prometheus            Loki
          (infra/ITSM)          (metrics)             (logs)
                └──────────────────┼──────────────────┘
                                   ▼
                  OpenTelemetry Collector + Grafana Alloy
                                   ▲
        ┌──────────┬──────────┬───┴────┬──────────┬──────────┐
       AWS        Azure       GCP      OCI      On-Prem   OpenShift
```

## What's actually in this repo vs. what's a starting point

This is a **working scaffold**, not a fully populated production estate:

- **Zabbix + the GitOps/CI/CD/security plumbing are built out for real** - Helm
  templates, RBAC, NetworkPolicy, ExternalSecrets/Vault wiring, Argo CD
  AppProject/ApplicationSet, Kyverno policies, GitHub Actions pipeline, helm-unittest
  tests.
- **Prometheus/Grafana/Loki/Alloy/Tempo/OTel Collector are wired in as dependencies** on
  their official upstream Helm charts (not reimplemented), configured through `values.yaml`.
- **Cloud integrations (AWS/Azure/GCP/OCI/On-Prem) ship one or two fully worked examples
  each** (EC2+RDS, Azure VM+SQL, GCE+Cloud SQL, OCI Compute+Autonomous DB, VMware) as a
  documented pattern - see [docs/cloud/](docs/cloud/). Extending to the dozens of other
  services listed in the original spec means copying that pattern, not writing a new
  architecture.
- Exporter **image references for Azure/GCP/OCI are placeholders** (`TODO` in
  `values-<cloud>.yaml`) - pin them to your org's approved images before deploying.

## Repository layout

```
charts/zabbix-enterprise/   Umbrella Helm chart (Zabbix core + all platform dependencies)
gitops/                     Argo CD AppProject/ApplicationSet, per-cluster overlays, infra
.github/workflows/          CI: lint, unit test, kubeconform, security scan, SBOM, publish
docs/                       Architecture, operations, security, SRE and per-cloud docs
```

See [charts/zabbix-enterprise/README.md](charts/zabbix-enterprise/README.md) for the chart
itself and [gitops/README.md](gitops/README.md) for how deployment is orchestrated.

## Quickstart (local dev, no GitOps)

Prerequisites: Helm >= 3.14, a Kubernetes cluster (kind/minikube is fine for dev),
`kubectl`.

```bash
git clone <this-repo> && cd zabbix-helm

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm dependency update charts/zabbix-enterprise

# Dev has no External Secrets Operator/Vault by default - pre-create the DB secret it expects:
kubectl create namespace zabbix-enterprise
kubectl -n zabbix-enterprise create secret generic zabbix-db-credentials \
  --from-literal=host=zabbix-enterprise-mysql \
  --from-literal=username=zabbix \
  --from-literal=password=change-me

helm install zabbix-enterprise charts/zabbix-enterprise \
  --namespace zabbix-enterprise \
  -f charts/zabbix-enterprise/values.yaml \
  -f charts/zabbix-enterprise/values-dev.yaml \
  -f charts/zabbix-enterprise/values-onprem.yaml
```

Then `kubectl -n zabbix-enterprise port-forward svc/zabbix-enterprise-zabbix-frontend 8080:8080`
and log in at `http://localhost:8080` (default Zabbix credentials: `Admin` / `zabbix` -
**change immediately**).

## Production path

Production is never `helm install` by hand - it's GitOps end to end:
1. Merge to `main` triggers `.github/workflows/ci.yaml` (lint → unit test → kubeconform →
   security scan → SBOM → package → push to `oci://ghcr.io/.../charts`).
2. Argo CD's `zabbix-enterprise` `ApplicationSet` (`gitops/applications/zabbix-enterprise/`)
   picks up the chart per registered cluster/environment, layering
   `values.yaml → values-<env>.yaml → values-<cloud>.yaml → gitops/clusters/<cloud>/<env>/values.yaml`.
3. Cluster-scoped prerequisites (namespaces, Kyverno policies, the Vault
   `ClusterSecretStore`, RBAC group bindings) live in `gitops/infrastructure/` and are
   applied once per cluster via the `gitops/bootstrap/app-of-apps.yaml` entrypoint.

## Documentation

- [Architecture (HLD/LLD/C4)](docs/architecture/)
- [Operations runbooks](docs/operations/) (upgrade, rollback, backup/restore, DR, incident response)
- [Security](docs/security/) (threat model, IAM model, secrets management)
- [SRE / SLOs](docs/sre/slo-definitions.md)
- [Per-cloud integration notes](docs/cloud/)
