# OCI

## What's wired up

- `values-oci.yaml` - enables `cloudIntegrations.oci`, Instance/Resource Principal auth,
  two proxy instances (us-ashburn-1, eu-frankfurt-1), external MySQL HeatWave/Autonomous
  Database target, OCI Object Storage (S3-compatible API)-backed Loki/Tempo storage.
- `templates/cloud-integrations/oci/exporter-deployment.yaml` - an OCI Monitoring
  exporter Deployment (no static API key files - Instance Principal auth).
- Worked-example Zabbix templates: `zabbix-template-compute.yaml` (CPU utilization,
  per-instance discovery), `zabbix-template-autonomous-database.yaml` (CPU utilization,
  storage utilization, per-database discovery).

## Collection pattern

Same dual-pipeline bridge as the other clouds - one exporter, scraped by both Prometheus
and Zabbix.

## Extending to other OCI services (MySQL HeatWave, Load Balancer, Object Storage,
Functions, Streaming, VCN, NAT Gateway)

Same pattern as the other clouds: add the OCI Monitoring namespace/metric list to
`cloudIntegrations.oci.exporters.ociMetrics.namespaces`, copy the
`zabbix-template-compute.yaml` discovery-rule structure, register the new template in
`cloudIntegrations.oci.zabbixTemplates`.

## Still a placeholder

`cloudIntegrations.oci.exporters.ociMetrics.image` is empty - pin it before deploying.
This is the least-standardized of the four cloud exporters (no single dominant
Prometheus-exporter project for OCI Monitoring the way CloudWatch/Azure
Monitor/Stackdriver exporters are standardized) - budget extra evaluation time here.

## Integration points not templated here

`OCI Events` service notification forwarding
(`cloudIntegrations.oci.eventIntegration.ociEvents`) is a toggle without an
implementation, same caveat as the other clouds' event-forwarding toggles.
