{{- $flags := fromJson (include "mw.feature_flags" . ) }}
{{- if $flags.web }}
apiVersion: batch/v1
kind: Job
metadata:
  name: test-{{ template "base.name.release" . }}
  {{- include "mw.labels" . | indent 2 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      securityContext:
        runAsUser: 1000
      containers:
      - name: test-{{ template "base.name.release" . }}
        image: {{ .Values.docker.registry }}/{{ .Values.common_images.wmfdebug }}
        command:
          - curl
          - -sSf
          - --connect-to
          - "test.wikipedia.org:80:{{ template "base.name.release" . }}:{{ .Values.service.port.port }}"
          - -H
          - "X-Forwarded-Proto: https"
          - http://test.wikipedia.org/wiki/Main_Page
      restartPolicy: Never
{{- end }}
