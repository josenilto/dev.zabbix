# IAM Model

## Human identity → platform access

```
Microsoft Entra ID / LDAP / SAML IdP
        │
        ▼ (OIDC/SAML group claims)
   Zabbix Frontend SSO  ──────────────► Zabbix User Groups (per tenant/team)
   Grafana auth.generic_oauth/saml ───► Grafana Organizations/Folders/Teams
   Argo CD SSO ────────────────────────► AppProject roles (platform-admin / sre-readonly)
   Kubernetes OIDC ─────────────────────► ClusterRoleBinding (edit for platform-engineering, view for sre/noc/soc)
```

Group names (`platform-engineering`, `sre`, `noc`, `soc`) are illustrative - map them to
your actual IdP group names in `gitops/infrastructure/rbac/platform-groups-clusterrolebinding.yaml`
and `gitops/applications/zabbix-enterprise/project.yaml` `roles:`.

## Workload identity → cloud APIs

No static cloud credentials are stored anywhere in this repository. Every cloud exporter
uses the cloud's native workload-identity federation:

| Cloud | Mechanism | Where configured |
|---|---|---|
| AWS | IRSA (IAM Roles for Service Accounts) | `values-aws.yaml` `cloudIntegrations.aws.auth.roleArn`, annotated on the exporter's ServiceAccount |
| Azure | Workload Identity (Entra ID federated credential) | `values-azure.yaml` `cloudIntegrations.azure.auth.clientId`, `azure.workload.identity/*` labels/annotations |
| GCP | Workload Identity (GKE → Google service account binding) | `values-gcp.yaml` `cloudIntegrations.gcp.auth.serviceAccountEmail`, `iam.gke.io/gcp-service-account` annotation |
| OCI | Instance/Resource Principal | `values-oci.yaml` `cloudIntegrations.oci.auth.mode: instance-principal` |

Each of these federated identities should be granted **read-only monitoring** permissions
only (`CloudWatchReadOnlyAccess`-equivalent, Azure Monitoring Reader, GCP
`roles/monitoring.viewer`, OCI `read metrics` policy) - creating/binding the actual
cloud-side role is outside this repository's scope (Terraform/cloud IaC), but the
principle applies regardless of tooling: the exporter never needs write access to
anything.

## Zabbix's own RBAC

Zabbix User Groups + Permissions (configured via the Zabbix API/UI, not Helm) should
mirror the multi-tenancy boundaries in section "Multi-Tenancy" - one User Group per
team/business unit, scoped to the Host Groups that team owns, with the "API access"
setting off for anyone who doesn't need programmatic access, and the Zabbix API user used
by the template-sync CronJob (`zabbix-api-credentials`) restricted to a dedicated
service-account User Group with only `configuration.import` rights - not an
Admin/Super Admin account.

## Grafana's own RBAC

`grafana.grafana.ini.users.auto_assign_org_role: Viewer` (the default in `values.yaml`) -
nobody gets Editor/Admin by default; elevate explicitly per team via Organizations/Teams,
matching the "Multi-Tenancy" folder-per-team model.

## Argo CD RBAC

Scoped via the `AppProject` `roles:` block (`gitops/applications/zabbix-enterprise/project.yaml`):
`platform-admin` (full sync/override) vs. `sre-readonly` (get only) - map these role
names to actual Argo CD RBAC policy CSV entries in `argocd-rbac-cm`
(`argocd`namespace, managed outside this repo alongside the rest of the Argo CD
installation itself).
