# Azure

## What's wired up

- `values-azure.yaml` - enables `cloudIntegrations.azure`, Workload Identity auth, two
  proxy instances (eastus, westeurope), external MySQL/PostgreSQL flexible server target,
  Azure Blob-backed Loki/Tempo storage.
- `templates/cloud-integrations/azure/exporter-deployment.yaml` - an Azure Monitor
  exporter Deployment, Workload-Identity-annotated ServiceAccount + Pod label.
- Worked-example Zabbix templates: `zabbix-template-vm.yaml` (CPU percentage,
  per-VM discovery), `zabbix-template-sql.yaml` (Azure SQL Database CPU percent, DTU
  consumption, per-database discovery).

## Collection pattern

Same dual-pipeline bridge as AWS (see `docs/cloud/aws.md` "Collection pattern") - one
exporter, scraped by both Prometheus and Zabbix.

## Extending to other Azure services (Azure Functions, App Service, Storage Account,
Event Hubs, Service Bus, Cosmos DB, Azure Cache for Redis, Virtual Network, Azure Firewall)

Same three-step pattern as AWS (see `docs/cloud/aws.md`): add the resource
type/metric list to `cloudIntegrations.azure.exporters.azureMonitor.resourceTypes`, copy
the `zabbix-template-vm.yaml` discovery-rule structure, register the new template in
`cloudIntegrations.azure.zabbixTemplates`.

## Still a placeholder

`cloudIntegrations.azure.exporters.azureMonitor.image` is empty - pin it before
deploying.

## Integration points not templated here

Microsoft Entra ID is referenced as the SSO/IAM provider (see
`docs/security/iam-model.md`) but the actual App Registration/Enterprise Application
setup is outside this repository. `Azure Event Grid` event forwarding is a toggle
(`cloudIntegrations.azure.eventIntegration.eventGrid`) without an implementation, same
caveat as AWS EventBridge.
