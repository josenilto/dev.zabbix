# Secrets Management

## Rule zero

No Secret object with real credential material is ever committed to this repository.
`.gitignore` blocks the obvious filename patterns (`*.secret.yaml`, `secrets.auto.yaml`,
`*.pem`, `*.key`) as a backstop, but the actual control is architectural: every credential
this chart consumes is either an `ExternalSecret` (production path) or a `SealedSecret`
(simpler-environment alternative) - there is no code path where a plaintext Secret
manifest is expected to exist in Git.

## Production path: Vault + External Secrets Operator

```
Vault (secret/data/zabbix-enterprise/<env>/<cloud>/<purpose>)
        │  (Kubernetes auth method, ServiceAccount token)
        ▼
ClusterSecretStore "vault-backend"  (gitops/infrastructure/security/, once per cluster)
        │
        ▼
ExternalSecret  (templates/database/externalsecret.yaml, etc. - per Helm release)
        │  (refreshInterval: 1h)
        ▼
Kubernetes Secret  (zabbix-db-credentials, zabbix-api-credentials, vmware-vcenter-credentials, ...)
        │
        ▼
Zabbix Server/Frontend/exporters (consumed via secretKeyRef, never inlined into env values directly)
```

Every path follows `secret/data/zabbix-enterprise/<environment>/<cloud>/<purpose>` -
this namespacing means a Vault policy can scope read access per environment/cloud without
touching the chart at all (least privilege at the secrets-backend layer, independent of
Kubernetes RBAC).

## Simpler-environment alternative: Sealed Secrets

For environments without Vault (a small dev sandbox, a short-lived proof-of-concept
cluster), `externalSecrets.sealedSecrets.enabled: true` switches to Bitnami Sealed
Secrets - encrypt with `kubeseal` against the target cluster's public cert, commit the
resulting `SealedSecret` (safe to commit - only the in-cluster controller can decrypt
it). See `templates/security/sealedsecret-example.yaml` for the exact command.

## Dev sandbox with neither installed

Pre-create the Secret manually (see the root README quickstart and
`docs/operations/runbook.md`) - acceptable for a throwaway local cluster only, never for
anything shared or long-lived.

## Rotation

- **Database credentials**: rotate in Vault; `ExternalSecret.refreshInterval` (1h)
  propagates the new value, but Zabbix Server/Frontend pods need a restart to pick up the
  new env var (`kubectl rollout restart` or wait for the next unrelated deploy) - env
  vars are not live-reloaded. Consider a `checksum/config`-style annotation keyed off the
  Secret if this needs to be automatic.
- **Zabbix API credentials**: same mechanism; the template-sync CronJob re-reads the
  Secret fresh on every scheduled run, so no restart is needed there.
- **Cloud workload identity**: no secret material to rotate at all (see
  [iam-model.md](iam-model.md)) - this is one of the concrete benefits of
  IRSA/Workload Identity/Instance Principal over static keys.
- **TLS certificates**: `cert-manager` (referenced via the
  `cert-manager.io/cluster-issuer` Ingress annotation) handles issuance and rotation
  automatically; not templated in this chart since it's a cluster-wide add-on like
  External Secrets Operator.

## What's intentionally NOT in this repo

Vault itself, cert-manager, External Secrets Operator's controller, and Sealed Secrets'
controller are all assumed pre-installed as cluster add-ons (see
`gitops/infrastructure/`). This chart only ever *consumes* the Secrets they produce - it
never runs a secrets backend itself.
