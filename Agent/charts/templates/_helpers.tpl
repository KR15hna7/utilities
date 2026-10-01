{{- define "azp-agent.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "azp-agent.secretName" -}}
{{- default (printf "%s-token" (include "azp-agent.name" .)) .Values.existingSecret -}}
{{- end -}}

{{- define "azp-agent.labels" -}}
app.kubernetes.io/name: azp-agent
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
