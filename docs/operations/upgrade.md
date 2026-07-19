# Upgrade Procedure

## Chart/application upgrades (GitOps path)

1. Bump `version:` (and `appVersion:` if the underlying Zabbix version changed) in
   `Chart.yaml`.
2. Open a PR - CI (`ci.yaml`) runs `helm lint`/`helm-unittest`/`kubeconform`/security
   scans against every env × cloud combination automatically.
3. Merge to `main` - CI packages and pushes the new chart version to
   `oci://ghcr.io/.../charts`.
4. Bump `targetRevision` in `gitops/applications/zabbix-enterprise/applicationset.yaml`
   (or the chart version pin, if pinning instead of tracking `main`) and merge.
5. Argo CD syncs automatically (`syncPolicy.automated`) - watch the sync in the Argo CD
   UI/`argocd app get zabbix-enterprise-<cloud>-<env>`, or let `selfHeal` handle drift.

Roll out non-prod (`dev` → `hml`) before `prd` by merging the `dev`/`hml` `ApplicationSet`
entries first and confirming health before touching `prd` entries - the `ApplicationSet`
list generator makes this an explicit, auditable two-step change, not an implicit "deploy
everywhere at once."

## Zabbix major version upgrades specifically

Zabbix major upgrades run a one-way database schema migration on Zabbix Server's first
boot against the new version - there is no supported downgrade path once that migration
has run.

1. **Snapshot first** - confirm a recent Velero backup exists (see
   [backup-restore.md](backup-restore.md)) covering the Zabbix database PVC/external DB,
   independent of the application-level DB backup.
2. Bump `zabbix.server.image.tag`/`zabbix.frontend.image.tag`/`zabbix.agent2.image.tag`/
   `zabbix.proxy.image.tag` together - Zabbix components must all be on compatible major
   versions.
3. Roll out to `dev` first and manually verify the schema migration log
   (`kubectl logs` on the first server pod to come up) completes cleanly before
   promoting.
4. With `zabbix.server.replicaCount > 1` (HA cluster), the schema migration runs once
   (whichever replica starts first and acquires it); the rolling update strategy
   (`maxUnavailable: 0`) intentionally prevents all replicas restarting simultaneously
   mid-migration.

## Kubernetes / cluster upgrades

Not managed by this chart. Before a cluster control-plane upgrade, confirm
`kubeVersion:` in `Chart.yaml` still satisfies the target version, and re-run
`kubeconform` in CI against the new `-kubernetes-version` to catch any deprecated API
removed in that release (particularly relevant for `PodDisruptionBudget`,
`HorizontalPodAutoscaler`, and any `NetworkPolicy` API changes).
