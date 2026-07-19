# Rollback Procedure

GitOps means the default rollback is a **Git revert**, not a live cluster command - a
live-only rollback gets silently undone by Argo CD's `selfHeal` on the next reconcile
unless the Git state also changes.

## Standard rollback (recommended)

```bash
git revert <bad-commit-sha>
git push origin main
```

Argo CD detects the reverted `targetRevision`/values change and reconciles automatically
(`syncPolicy.automated`). This is auditable, goes through the same PR/CI path as any
other change, and is the only rollback method that survives a subsequent `selfHeal`.

## Emergency rollback (Argo CD directly)

When a revert PR would take too long for the severity of the incident:

```bash
argocd app history zabbix-enterprise-<cloud>-<env>
argocd app rollback zabbix-enterprise-<cloud>-<env> <history-id>
```

This is a **stopgap**, not a resolution - it puts the cluster ahead of Git, so
`selfHeal` will fight it on the next sync unless you also open the Git revert PR
immediately afterward (or temporarily disable `automated.selfHeal` on that Application
while the PR lands - remember to re-enable it).

## Helm-level rollback (non-GitOps / local dev only)

```bash
helm history zabbix-enterprise -n zabbix-enterprise
helm rollback zabbix-enterprise <revision> -n zabbix-enterprise
```

Not applicable to any Argo CD-managed environment - Argo CD manages Helm releases itself
and will overwrite a manual `helm rollback` on the next sync.

## Database schema rollback

Zabbix's own schema migrations are one-way (see [upgrade.md](upgrade.md)) - "rollback"
after a bad major-version upgrade means restoring the pre-upgrade database snapshot (see
[backup-restore.md](backup-restore.md)), not reverting the application version against
an already-migrated schema.
