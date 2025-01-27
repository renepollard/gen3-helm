{{/*
  Postgres service secret lookup. 
  Usage:
    {{ include "gen3.service-postgres" (dict "key" "password" "service" "fence" "context" $) }}


  Params:
  - key - String - Required - Name of the key in the secret.
  - service - String - Which service are you looking up secret for? 
  - context - Context - Required - Parent context.


 Lookups for postgres service secret is done in this order, until it finds a value:
  - Secret provided via `.Values.postgres` (Can be database, username, password, host, port)
  - Lookup secret `{{service}}-dbcreds` with key `password` 
  - Generate a random string, as we can assume this is a fresh install at that point.
 
*/}}
{{- define "gen3.service-postgres" -}}
  {{- $chartName := default "" .context.Chart.Name }}
  {{- $valuesPostgres := get .context.Values.postgres .key}}
  {{- $localSecretPass := get ((lookup "v1" "Secret" .context.Release.Namespace (cat .service "-dbcreds")).data) .key }}
  
  {{- $randomPassword := "" }}
  {{- $valuesGlobalPostgres := get .context.Values.global.postgres.master .key}}
  {{- if eq .key "password" }}
    {{- $randomPassword = randAlphaNum 20 }}
    {{- $valuesGlobalPostgres = "" }}
  {{- end }}
  {{- $password := coalesce $valuesPostgres $localSecretPass $randomPassword  $valuesGlobalPostgres}}
  {{- printf "%v" $password -}}
{{- end }}


{{/*
Postgres Master Secret Lookup

Usage:
    {{ include "gen3.master-postgres" (dict "key" "database" "context" $) }}

 Lookups for secret is done in this order, until it finds a value:
  - Secret provided via `.Values.global.master.postgres` (Can be database, username, password, host, port)
  - Lookup secret `postgres-postgresql` with property `postgres-password` in `postgres` namespace. (This is for develop installation of gen3)
 

 # https://helm.sh/docs/chart_template_guide/function_list/#coalesce
*/}}
{{- define "gen3.master-postgres" }}
  {{- $chartName := default "" .context.Chart.Name }}
  
  {{- $valuesPostgres := get .context.Values.global.postgres.master .key}}
  {{- $secret :=  (lookup "v1" "Secret" "postgres" "postgres-postgresql" )}}
  {{- $devPostgresSecret := "" }}
  {{-  if $secret }}
    {{- $devPostgresSecret = (index $secret.data "postgres-password") | b64dec }}
  {{- end }}
  {{- $value := coalesce $valuesPostgres $devPostgresSecret  }}
  {{- printf "%v" $value -}}
{{- end }}






{{/*
 Postgres User lookup
*/}}
{{- define "peregrine.postgres.user" -}}
{{- $localpass := (lookup "v1" "Secret" "postgres" "postgres-postgresql" ) -}}
{{- if $localpass }}
{{- default (index $localpass.data "postgres-password" | b64dec) }}
{{- else }}
{{- default .Values.postgres.password }}
{{- end }}
{{- end }}


{{- if not (lookup "v1" "Secret" .Release.Namespace (printf "%s-%s" .Chart.Name "dbcreds")) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Chart.Name }}-dbcreds
  annotations:
    "helm.sh/hook": "pre-install,pre-upgrade"
    "helm.sh/resource-policy": "keep"
    "helm.sh/hook-weight": "-10"
stringData:
  host: {{ default .Values.global.postgres.host  .Values.postgres.host }}
  database: "{{ default .Chart.Name .Values.postgres.dbname }}"
  username: "{{ default .Chart.Name .Values.postgres.user }}"
  password: "{{ default (randAlphaNum 24 | nospace) .Values.postgres.password }}"
  port: "{{ default 5432 .Values.postgres.port }}"
{{- end -}}