{{/* Generate basic labels */}}
{{- define "android-build.labels" }}
  labels:
    app.kubernetes.io/name: {{ include "android-build.name" . }}
    helm.sh/chart: {{ include "android-build.chart" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "android-build.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "android-build.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "android-build.envVars" -}}
{{- $envFile := .Files.Get "build.env" -}}
{{- if $envFile -}}
{{- range $line := splitList "\n" $envFile }}
{{- if and $line (not (hasPrefix "#" $line)) (contains "=" $line) }}
{{- $parts := splitList "=" $line }}
{{- $key := index $parts 0 | trim }}
{{- $value := rest $parts | join "=" | trim | trimPrefix "\"" | trimSuffix "\"" | trimPrefix "'" | trimSuffix "'" }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- else if .Values.buildConfig.env }}
{{- range $key, $value := .Values.buildConfig.env }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}
