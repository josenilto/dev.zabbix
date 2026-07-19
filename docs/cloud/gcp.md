# GCP

## What's wired up

- `values-gcp.yaml` - enables `cloudIntegrations.gcp`, GKE Workload Identity auth, two
  proxy instances (us-central1, europe-west1), external Cloud SQL target, GCS-backed
  Loki/Tempo storage.
- `templates/cloud-integrations/gcp/exporter-deployment.yaml` - a Stackdriver
  (Cloud Monitoring) exporter Deployment, Workload-Identity-annotated ServiceAccount.
- Worked-example Zabbix templates: `zabbix-template-compute-engine.yaml` (CPU
  utilization, per-instance discovery), `zabbix-template-cloud-sql.yaml` (CPU
  utilization, connection count, per-database discovery).

## Collection pattern

Same dual-pipeline bridge as AWS/Azure - one exporter, scraped by both Prometheus and
Zabbix.

## Extending to other GCP services (Cloud Run, Cloud Functions, Load Balancing,
Cloud Storage, Pub/Sub, Memorystore, BigQuery, VPC, Cloud NAT)

Same pattern as AWS/Azure: add the monitored-resource-type/metric list to
`cloudIntegrations.gcp.exporters.stackdriver.monitoredResourceTypes`, copy the
`zabbix-template-compute-engine.yaml` discovery-rule structure, register the new template
in `cloudIntegrations.gcp.zabbixTemplates`.

## Still a placeholder

`cloudIntegrations.gcp.exporters.stackdriver.image` is empty - pin it before deploying.

## Integration points not templated here

`Pub/Sub`-based event forwarding (`cloudIntegrations.gcp.eventIntegration.pubsub`) is a
toggle without an implementation, same caveat as the AWS/Azure event-forwarding toggles.
