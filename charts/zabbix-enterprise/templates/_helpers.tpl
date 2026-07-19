{{/*
Chart name and version label.
*/}}
{{- define "zabbix-enterprise.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zabbix-enterprise.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "zabbix-enterprise.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every object this chart renders.
*/}}
{{- define "zabbix-enterprise.labels" -}}
helm.sh/chart: {{ include "zabbix-enterprise.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: zabbix-enterprise
zabbix-enterprise/environment: {{ .Values.global.environment }}
zabbix-enterprise/cloud: {{ .Values.global.cloud }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels for a given component.
Usage: {{ include "zabbix-enterprise.selectorLabels" (dict "root" $ "component" "zabbix-server") }}
NOTE: always pass a (dict "root" ... "component" ...) - "$" is rebound to whatever
pipeline value is passed to "include" at the start of every template invocation, so a
bare string argument here would make "$.Release.Name" fail.
*/}}
{{- define "zabbix-enterprise.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}

{{/*
Component labels = common labels + name/instance/component, ready to merge under metadata.labels.
Usage: {{ include "zabbix-enterprise.componentLabels" (dict "root" $ "component" "zabbix-server") }}
*/}}
{{- define "zabbix-enterprise.componentLabels" -}}
{{ include "zabbix-enterprise.labels" .root }}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Fully-qualified resource name for a component, e.g. "release-name-zabbix-server".
Usage: {{ include "zabbix-enterprise.componentName" (dict "root" $ "component" "zabbix-server") }}
*/}}
{{- define "zabbix-enterprise.componentName" -}}
{{- printf "%s-%s" .root.Release.Name .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Service account name used by all Zabbix components (single SA + scoped Roles).
*/}}
{{- define "zabbix-enterprise.serviceAccountName" -}}
{{- if .Values.rbac.create -}}
{{ default (include "zabbix-enterprise.fullname" .) .Values.rbac.serviceAccountName }}
{{- else -}}
{{ default "default" .Values.rbac.serviceAccountName }}
{{- end -}}
{{- end -}}

{{/*
Namespace helper - always deploy into .Release.Namespace, kept as a named template
so it can be swapped centrally if a dedicated namespace strategy is required later.
*/}}
{{- define "zabbix-enterprise.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{/*
Standard Pod-level securityContext, sourced from values.security.podSecurityContext.
*/}}
{{- define "zabbix-enterprise.podSecurityContext" -}}
{{- toYaml .Values.security.podSecurityContext -}}
{{- end -}}

{{/*
Standard container-level securityContext, sourced from values.security.containerSecurityContext.
*/}}
{{- define "zabbix-enterprise.containerSecurityContext" -}}
{{- toYaml .Values.security.containerSecurityContext -}}
{{- end -}}

{{/*
Image reference helper honoring global.imageRegistry.
Usage: {{ include "zabbix-enterprise.image" (dict "root" $ "repository" .Values.zabbix.server.image.repository "tag" .Values.zabbix.server.image.tag) }}
*/}}
{{- define "zabbix-enterprise.image" -}}
{{- if .root.Values.global.imageRegistry -}}
{{- printf "%s/%s:%s" .root.Values.global.imageRegistry .repository .tag -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end -}}

{{/*
The database port isn't broken out as its own value - it follows from which engine is
active. Centralized here so the wait-for-db init container and any future template that
needs it stay in sync with database.external.enabled / .external.port /
.internal.postgresql.enabled automatically.
Usage: {{ include "zabbix-enterprise.databasePort" . }}
*/}}
{{- define "zabbix-enterprise.databasePort" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.port -}}
{{- else if .Values.database.internal.postgresql.enabled -}}
5432
{{- else -}}
3306
{{- end -}}
{{- end -}}

{{/*
DB_SERVER_HOST env entry. A hostname is not sensitive, so for an external/managed
database (values.database.external.*, the common prod path - RDS/Azure DB/Cloud
SQL/Autonomous DB) it comes straight from values (GitOps-visible, no Vault round-trip
needed) with a required guard so a forgotten host fails fast at render time instead of
deploying a Zabbix Server that can never reach its database. The internal MySQL/
PostgreSQL quick-start path keeps sourcing host from the same Secret as the credentials,
since docs/operations/runbook.md already walks through provisioning that Secret once.
Usage: {{ include "zabbix-enterprise.dbServerHostEnv" (dict "root" $) }}
*/}}
{{- define "zabbix-enterprise.dbServerHostEnv" -}}
- name: DB_SERVER_HOST
{{- if .root.Values.database.external.enabled }}
  value: {{ required "database.external.host must be set when database.external.enabled is true (see values-<cloud>.yaml / gitops/clusters/<cloud>/<env>/values.yaml)" .root.Values.database.external.host | quote }}
{{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.database.internal.mysql.auth.existingSecret }}
      key: host
{{- end }}
{{- end -}}

{{/*
Blocks the main container from starting until the database TCP port accepts
connections - avoids a crash-loop race on a fresh install where the internal MySQL/
PostgreSQL subchart's Pod hasn't finished starting yet (Helm does not sequence subchart
readiness for you). Harmless against an already-up external managed database too.
Usage: {{ include "zabbix-enterprise.waitForDbInitContainer" (dict "root" $) }}
*/}}
{{- define "zabbix-enterprise.waitForDbInitContainer" -}}
- name: wait-for-db
  image: busybox:1.36
  securityContext:
    {{- include "zabbix-enterprise.containerSecurityContext" .root | nindent 4 }}
  env:
    {{- include "zabbix-enterprise.dbServerHostEnv" (dict "root" .root) | nindent 4 }}
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for database ${DB_SERVER_HOST}:{{ include "zabbix-enterprise.databasePort" .root }} ..."
      until nc -z -w2 "${DB_SERVER_HOST}" {{ include "zabbix-enterprise.databasePort" .root }}; do
        echo "Database not reachable yet, retrying in 3s..."
        sleep 3
      done
      echo "Database is reachable."
  resources:
    requests: { cpu: 10m, memory: 16Mi }
    limits: { cpu: 100m, memory: 32Mi }
{{- end -}}
