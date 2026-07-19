# On-Premises

## What's wired up

- `values-onprem.yaml` - enables `cloudIntegrations.onprem`, two passive proxy instances
  (one per datacenter), internal MySQL (no managed DB on-prem by default), filesystem or
  S3-compatible (MinIO/Ceph RGW) Loki/Tempo storage, SNMP network-device discovery
  toggle.
- **Linux/Windows**: no custom template needed - Zabbix Agent2 (the DaemonSet in
  `templates/zabbix-agent/`) ships with Zabbix's own native "Linux by Zabbix agent"/
  "Windows by Zabbix agent" templates out of the box; import them via the frontend or the
  template-sync CronJob if you add them as a ConfigMap following the same pattern as the
  cloud templates.
- **VMware**: `templates/cloud-integrations/onprem/zabbix-template-vmware.yaml` - unlike
  every cloud example, this does **not** use an exporter bridge. Zabbix Server has a
  native VMware collector (`ZBX_STARTVMWARECOLLECTORS`, enabled automatically in
  `templates/zabbix-server/deployment.yaml` when
  `cloudIntegrations.onprem.hypervisors.vmware.enabled: true`) that polls vCenter's SOAP
  API directly - no separate exporter Deployment required. Credentials come from the
  `vmware-vcenter-credentials` Secret (ExternalSecret-backed, see
  `templates/cloud-integrations/onprem/externalsecret-vmware.yaml`).

## Why VMware is a different pattern from the cloud examples

The cloud examples (AWS/Azure/GCP/OCI) all bridge through a Prometheus-style exporter
because there's no equivalent native Zabbix collector for those APIs. VMware is the one
target in this platform where Zabbix Server already has first-class, built-in support -
using an exporter bridge there would be strictly worse (an extra moving part, an extra
thing to patch) than the native collector, so this repo deliberately does not do that.

## Extending to Hyper-V/KVM/OpenStack/CloudStack, network devices, storage, firewalls,
load balancers

- **Hyper-V/KVM**: no equivalent native Zabbix collector; the practical path is a small
  agent-side script (Zabbix Agent2 `UserParameter`) exposing hypervisor stats, or (for
  KVM specifically) the community `libvirt` Zabbix template polling via SSH/agent.
  `cloudIntegrations.onprem.hypervisors.hyperv`/`kvm` are toggles reserved for this, not
  yet implemented.
- **Network devices (SNMP)**: `cloudIntegrations.onprem.network.snmpDiscovery` toggles a
  Zabbix native SNMP discovery rule (built into Zabbix Server, not templated here as a
  K8s object since SNMP discovery is configured entirely within Zabbix itself) - populate
  `subnets` and the `snmp-community` Secret, then configure the discovery action in the
  Zabbix frontend/API to auto-add discovered devices to the "Network" host group with the
  matching official SNMP template (Cisco/Juniper/generic-RFC1213, per your actual
  inventory).
- **Storage/Firewalls/Load Balancers/Databases/Middleware**: use Zabbix's extensive
  official template library (imported the same way as the Linux/Windows templates above)
  rather than authoring custom ones - only build a custom template when the official
  library doesn't already cover the specific vendor/product.
