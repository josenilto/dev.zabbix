# AWS

## What's wired up

- `values-aws.yaml` - enables `cloudIntegrations.aws`, configures IRSA auth, two proxy
  instances (us-east-1, us-west-2), external MySQL/Aurora database target, S3-backed
  Loki/Tempo storage.
- `templates/cloud-integrations/aws/exporter-deployment.yaml` - a CloudWatch-exporter
  Deployment, IRSA-annotated ServiceAccount, scraped by both Prometheus
  (`additionalScrapeConfigs`) and Zabbix (below).
- Worked-example Zabbix templates: `zabbix-template-ec2.yaml` (CPU utilization, status
  check failed, per-instance discovery), `zabbix-template-rds.yaml` (CPU, freeable
  memory, connection count, per-instance discovery).

## Collection pattern

One CloudWatch-exporter deployment serves both pipelines: Prometheus scrapes it directly;
Zabbix discovers instances and items from the *same* `/metrics` endpoint via an
`HTTP_AGENT` discovery rule with `PROMETHEUS_TO_JSON`/`PROMETHEUS_PATTERN`
preprocessing. This avoids a second AWS API integration just for Zabbix, and means
Prometheus/Zabbix never disagree about what a metric's raw value was.

## Extending to other AWS services (Lambda, ECS/Fargate, ELB/ALB/NLB, API Gateway,
CloudFront, S3, EBS/EFS, VPC/NAT/Transit Gateway, Route 53, SQS/SNS, MSK, ElastiCache,
DynamoDB)

1. Add the CloudWatch namespace/metric list to `cloudIntegrations.aws.exporters.cloudwatch.metrics`
   in `values-aws.yaml` (the exporter Deployment's ConfigMap already ranges over this
   list, no template change needed).
2. Copy `zabbix-template-ec2.yaml`'s structure: one `discovery_rules` entry with
   `PROMETHEUS_TO_JSON` against a representative metric for that service, an
   `lld_macro_paths` entry mapping the resource's ID label, and `item_prototypes`/
   `trigger_prototypes` per metric you want tracked.
3. Add the new template filename to `cloudIntegrations.aws.zabbixTemplates` and gate the
   new ConfigMap on `has "<name>" .Values.cloudIntegrations.aws.zabbixTemplates`,
   matching the existing `ec2`/`rds` entries.

## Still a placeholder

`cloudIntegrations.aws.exporters.cloudwatch.image` is empty - pin it to your
organization's approved CloudWatch-exporter image/tag before deploying (see the `TODO` in
`values-aws.yaml`).

## Integration points not templated here

`AWS EventBridge`/`AWS SNS` event forwarding (for pushing AWS Health/CloudTrail events
into Zabbix as trap-style items) is listed as a toggle
(`cloudIntegrations.aws.eventIntegration.eventBridge`) but not implemented - it requires
an SNS-to-webhook bridge specific to your account structure.
