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
