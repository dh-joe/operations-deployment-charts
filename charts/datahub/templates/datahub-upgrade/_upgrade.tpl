{{/* vim: set filetype=mustache: */}}
{{/*
Return the env variables for upgrade jobs
*/}}
{{/* Generate a service name for the GMS service, depending on whether or not it uses TLS */}}
{{- define "wmf.gms-service.upgrade" -}}
  {{- if .Values.global.datahub.gms.useSSL }}
    {{- printf "datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}-tls-service.{{ .Release.Namespace }}.svc.cluster.local
  {{- else -}}
    {{- printf "datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}.{{ .Release.Namespace }}.svc.cluster.local
  {{- end }}
{{- end -}}
{{- define "wmf.gms-service.scheme" -}}
  {{- if .Values.global.datahub.gms.useSSL }}
  https://
  {{- else -}}
  http://
  {{- end }}
{{- end -}}

{{- define "datahub.upgrade.env" -}}
- name: ENTITY_REGISTRY_CONFIG_PATH
  value: /datahub/datahub-gms/resources/entity-registry.yml
- name: DATAHUB_GMS_HOST
  value: {{ template "wmf.gms-service.upgrade" $ }}
- name: DATAHUB_GMS_PORT
  value: "{{ .Values.global.datahub.gms.port }}"
{{- if .Values.global.datahub.gms.useSSL }}
- name: DATAHUB_GMS_PROTOCOL
  value: "https"
{{- end }}
- name: EBEAN_DATASOURCE_USERNAME
  {{- $usernameValue := (.Values.sql).datasource.username | default .Values.global.sql.datasource.username }}
  {{- if and (kindIs "string" $usernameValue) $usernameValue }}
  value: {{ $usernameValue | quote }}
  {{- else }}
  valueFrom:
    secretKeyRef:
      name: "{{ (.Values.sql).datasource.username.secretRef | default .Values.global.sql.datasource.username.secretRef }}"
      key: "{{ (.Values.sql).datasource.username.secretKey | default .Values.global.sql.datasource.username.secretKey }}"
  {{- end }}
- name: EBEAN_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ template "base.name.release" $ }}-secret-config
      key: mysql_password
- name: EBEAN_DATASOURCE_HOST
  value: "{{ .Values.global.sql.datasource.host }}"
- name: EBEAN_DATASOURCE_URL
  value: "{{ .Values.global.sql.datasource.url }}"
- name: EBEAN_DATASOURCE_DRIVER
  value: "{{ .Values.global.sql.datasource.driver }}"
{{- if .Values.global.datahub.metadata_service_authentication.enabled }}
- name: DATAHUB_SYSTEM_CLIENT_ID
  value: {{ .Values.global.datahub.metadata_service_authentication.systemClientId }}
- name: DATAHUB_SYSTEM_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.datahub.metadata_service_authentication.systemClientSecret.secretRef }}
      key: {{ .Values.global.datahub.metadata_service_authentication.systemClientSecret.secretKey }}
{{- end }}
- name: KAFKA_BOOTSTRAP_SERVER
  value: "{{ .Values.global.kafka.bootstrap.server }}"
{{- if eq .Values.global.kafka.schemaregistry.type "INTERNAL" }}
- name: KAFKA_SCHEMAREGISTRY_URL
  value: {{ printf "%s%s:%s/schema-registry/api/" ( include "wmf.gms-service.scheme" $ ) ( include "wmf.gms-service.upgrade" $ ) ( .Values.global.datahub.gms.port | toString ) }}
{{- else if eq .Values.global.kafka.schemaregistry.type "KAFKA" }}
- name: KAFKA_SCHEMAREGISTRY_URL
  value: "{{ .Values.global.kafka.schemaregistry.url }}"
{{- end }}
- name: ELASTICSEARCH_HOST
  value: {{ .Values.global.elasticsearch.host | quote }}
- name: ELASTICSEARCH_PORT
  value: {{ .Values.global.elasticsearch.port | quote }}
- name: SKIP_ELASTICSEARCH_CHECK
  value: {{ .Values.global.elasticsearch.skipcheck | quote }}
- name: ELASTICSEARCH_INSECURE
  value: {{ .Values.global.elasticsearch.insecure | quote }}
{{- with .Values.global.elasticsearch.useSSL }}
- name: ELASTICSEARCH_USE_SSL
  value: {{ . | quote }}
{{- end }}
{{- with .Values.global.elasticsearch.auth }}
- name: ELASTICSEARCH_USERNAME
  value: {{ .username }}
- name: ELASTICSEARCH_PASSWORD
  {{- if .password.value }}
  value: {{ .password.value | quote }}
  {{- else }}
  valueFrom:
    secretKeyRef:
      name: "{{ .password.secretRef }}"
      key: "{{ .password.secretKey }}"
  {{- end }}
{{- end }}
{{- with .Values.global.elasticsearch.indexPrefix }}
- name: INDEX_PREFIX
  value: {{ . }}
{{- end }}
- name: GRAPH_SERVICE_IMPL
  value: {{ .Values.global.graph_service_impl }}
{{- if eq .Values.global.graph_service_impl "neo4j" }}
- name: NEO4J_HOST
  value: "{{ .Values.global.neo4j.host }}"
- name: NEO4J_URI
  value: "{{ .Values.global.neo4j.uri }}"
- name: NEO4J_USERNAME
  value: "{{ .Values.global.neo4j.username }}"
- name: NEO4J_PASSWORD
  {{- if .Values.global.neo4j.password.value }}
  value: {{ .Values.global.neo4j.password.value | quote }}
  {{- else }}
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.global.neo4j.password.secretRef }}"
      key: "{{ .Values.global.neo4j.password.secretKey }}"
  {{- end }}
{{- end }}
{{- if .Values.global.springKafkaConfigurationOverrides }}
{{- range $configName, $configValue := .Values.global.springKafkaConfigurationOverrides }}
- name: SPRING_KAFKA_PROPERTIES_{{ $configName | replace "." "_" | upper }}
  value: {{ $configValue | quote }}
{{- end }}
{{- end }}
{{- if .Values.global.credentialsAndCertsSecrets }}
{{- range $envVarName, $envVarValue := .Values.global.credentialsAndCertsSecrets.secureEnv }}
- name: SPRING_KAFKA_PROPERTIES_{{ $envVarName | replace "." "_" | upper }}
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.global.credentialsAndCertsSecrets.name }}
      key: {{ $envVarValue }}
{{- end }}
{{- end }}
{{- with .Values.global.kafka.topics }}
- name: METADATA_CHANGE_EVENT_NAME
  value: {{ .metadata_change_event_name }}
- name: FAILED_METADATA_CHANGE_EVENT_NAME
  value: {{ .failed_metadata_change_event_name }}
- name: METADATA_AUDIT_EVENT_NAME
  value: {{ .metadata_audit_event_name }}
- name: METADATA_CHANGE_PROPOSAL_TOPIC_NAME
  value: {{ .metadata_change_proposal_topic_name }}
- name: FAILED_METADATA_CHANGE_PROPOSAL_TOPIC_NAME
  value: {{ .failed_metadata_change_proposal_topic_name }}
- name: METADATA_CHANGE_LOG_VERSIONED_TOPIC_NAME
  value: {{ .metadata_change_log_versioned_topic_name }}
- name: METADATA_CHANGE_LOG_TIMESERIES_TOPIC_NAME
  value: {{ .metadata_change_log_timeseries_topic_name }}
- name: DATAHUB_UPGRADE_HISTORY_TOPIC_NAME
  value: {{ .datahub_upgrade_history_topic_name }}
{{- end }}
{{- end -}}
