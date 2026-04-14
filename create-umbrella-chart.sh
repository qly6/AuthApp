#!/bin/bash
set -e

CHART_NAME="simpleauth"
CHART_DIR="./${CHART_NAME}-chart"

echo "🚀 Tạo Umbrella Helm Chart (có PostgreSQL) tại: $CHART_DIR"

# Tạo thư mục gốc
mkdir -p "$CHART_DIR"/charts/{api,ui}/templates
mkdir -p "$CHART_DIR"/templates

# Parent Chart.yaml với dependency PostgreSQL
cat > "$CHART_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: $CHART_NAME
description: Umbrella chart for SimpleAuth application (API + UI + PostgreSQL)
type: application
version: 0.2.0
appVersion: "1.0.0"

dependencies:
  - name: api
    version: 0.1.0
    repository: "file://charts/api"
  - name: ui
    version: 0.1.0
    repository: "file://charts/ui"
  - name: postgresql
    version: 15.5.20
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
EOF

# Parent values.yaml
cat > "$CHART_DIR/values.yaml" <<'EOF'
global:
  environment: dev

postgresql:
  enabled: true
  auth:
    database: simpleauthdb
    username: postgres
    password: ""  # Set via --set or secret
  primary:
    persistence:
      size: 8Gi
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi
  service:
    type: ClusterIP

api:
  replicaCount: 2
  image:
    repository: simpleauth-api
    tag: latest
    pullPolicy: Always
  service:
    type: ClusterIP
    port: 80
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  jwtSecret: "change-me-in-production"
  database:
    host: "simpleauth-postgresql"
    port: 5432
    name: simpleauthdb
    username: postgres

ui:
  replicaCount: 2
  image:
    repository: simpleauth-ui
    tag: latest
    pullPolicy: Always
  service:
    type: LoadBalancer
    port: 80
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
  apiUrl: "http://simpleauth-api:80/api"
EOF

# Tạo API subchart (tương tự nhưng cập nhật deployment)
API_DIR="$CHART_DIR/charts/api"

cat > "$API_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: api
description: .NET API for SimpleAuth
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF

cat > "$API_DIR/values.yaml" <<EOF
replicaCount: 2
image:
  repository: simpleauth-api
  tag: latest
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
resources: {}
jwtSecret: ""
database:
  host: ""
  port: 5432
  name: ""
  username: ""
EOF

# API _helpers.tpl
cat > "$API_DIR/templates/_helpers.tpl" <<'EOF'
{{- define "api.fullname" -}}
{{- printf "simpleauth-api" -}}
{{- end -}}

{{- define "api.labels" -}}
app.kubernetes.io/name: api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
EOF

# API deployment (dùng secret cho password)
cat > "$API_DIR/templates/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "api.fullname" . }}
  labels:
    {{- include "api.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "api.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "api.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: 80
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        - name: Jwt__Key
          value: {{ .Values.jwtSecret | quote }}
        - name: ConnectionStrings__DefaultConnection
          value: "Host={{ .Values.database.host }};Port={{ .Values.database.port }};Database={{ .Values.database.name }};Username={{ .Values.database.username }};Password=$(DB_PASSWORD)"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Release.Name }}-postgresql
              key: password
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
EOF

# API service
cat > "$API_DIR/templates/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "api.fullname" . }}
  labels:
    {{- include "api.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: 80
  selector:
    {{- include "api.selectorLabels" . | nindent 4 }}
EOF

# UI subchart (giữ nguyên)
UI_DIR="$CHART_DIR/charts/ui"

cat > "$UI_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: ui
description: Angular UI for SimpleAuth
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF

cat > "$UI_DIR/values.yaml" <<EOF
replicaCount: 2
image:
  repository: simpleauth-ui
  tag: latest
  pullPolicy: IfNotPresent
service:
  type: LoadBalancer
  port: 80
resources: {}
apiUrl: "http://simpleauth-api:80/api"
EOF

# UI helpers
cat > "$UI_DIR/templates/_helpers.tpl" <<'EOF'
{{- define "ui.fullname" -}}
{{- printf "simpleauth-ui" -}}
{{- end -}}

{{- define "ui.labels" -}}
app.kubernetes.io/name: ui
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "ui.selectorLabels" -}}
app.kubernetes.io/name: ui
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
EOF

# UI configmap
cat > "$UI_DIR/templates/configmap.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "ui.fullname" . }}-config
  labels:
    {{- include "ui.labels" . | nindent 4 }}
data:
  env.js: |
    (function(window) {
      window.__env = window.__env || {};
      window.__env.apiUrl = '{{ .Values.apiUrl }}';
    })(this);
EOF

# UI deployment
cat > "$UI_DIR/templates/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "ui.fullname" . }}
  labels:
    {{- include "ui.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "ui.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "ui.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: 80
        volumeMounts:
        - name: env-config
          mountPath: /usr/share/nginx/html/assets/env.js
          subPath: env.js
      volumes:
      - name: env-config
        configMap:
          name: {{ include "ui.fullname" . }}-config
EOF

# UI service
cat > "$UI_DIR/templates/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "ui.fullname" . }}
  labels:
    {{- include "ui.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: 80
  selector:
    {{- include "ui.selectorLabels" . | nindent 4 }}
EOF

echo "✅ Umbrella Chart (với PostgreSQL) đã được tạo tại: $CHART_DIR"
echo ""
echo "📦 Tiếp theo:"
echo "1. cd $CHART_DIR"
echo "2. helm dependency update"
echo "3. helm upgrade --install simpleauth . --namespace simpleauth --create-namespace \\"
echo "     --set postgresql.auth.password=<your-password> \\"
echo "     --set api.jwtSecret=<your-jwt-secret>"