{{- define "flows.dbHost" -}}
flows-db-rw.{{ .Values.database.namespace }}.svc
{{- end }}

{{- define "flows.backendImage" -}}
{{- required "images.backend is required" .Values.images.backend }}
{{- end }}

{{- define "flows.imagePullSecrets" -}}
{{- with .Values.imagePullSecret.name }}
imagePullSecrets:
  - name: {{ . }}
{{- end }}
{{- end }}

{{- define "flows.podSecurityContext" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  fsGroupChangePolicy: OnRootMismatch
  seccompProfile: {type: RuntimeDefault}
{{- end }}

{{- define "flows.containerSecurityContext" -}}
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities: {drop: [ALL]}
{{- end }}

{{/* The blob directories must exist before the health checks run; the storage layer creates them only on the first write. */}}
{{- define "flows.blobsInit" -}}
initContainers:
  - name: blobs-dir
    image: {{ include "flows.backendImage" . }}
    command: ["mkdir", "-p", "/data/objects"]
    {{- include "flows.containerSecurityContext" . | nindent 4 }}
    volumeMounts:
      - {name: blobs, mountPath: /data}
{{- end }}

{{- define "flows.backendMounts" -}}
volumeMounts:
  - {name: config, mountPath: /config, readOnly: true}
  - {name: blobs, mountPath: /data}
  - {name: tmp, mountPath: /tmp}
  - {name: scratch, mountPath: /scratch}
{{- end }}

{{- define "flows.backendVolumes" -}}
volumes:
  - name: config
    secret:
      secretName: flows-runtime
      defaultMode: 0440
  - name: blobs
    persistentVolumeClaim: {claimName: blobs}
  - name: tmp
    emptyDir: {medium: Memory, sizeLimit: 1Gi}
  - name: scratch
    emptyDir: {sizeLimit: 5Gi}
{{- end }}

{{/* Restart the pods when the configuration they read changes. */}}
{{- define "flows.configChecksum" -}}
checksum/runtime: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
{{- end }}
