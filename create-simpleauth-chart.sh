#!/bin/bash
set -e

CHART_NAME="simpleauth"
CHART_DIR="./${CHART_NAME}-chart"

echo "🚀 Tạo Helm Umbrella Chart mới tại: $CHART_DIR"
rm -rf "$CHART_DIR"
mkdir -p "$CHART_DIR"/{charts/{api,ui}/templates,templates}

# ------------------------------------------------------------------------
# Parent Chart.yaml
# ------------------------------------------------------------------------
cat > "$CHART_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: $CHART_NAME
description: SimpleAuth application with API, UI, PostgreSQL and Ingress
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  - name: api
    version: 1.0.0
    repository: "file://charts/api"
  - name: ui
    version: 1.0.0
    repository: "file://charts/ui"
  - name: postgresql
    version: 15.5.20
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
EOF

# ------------------------------------------------------------------------
# Parent values.yaml (đã sửa tất cả cấu hình)
# ------------------------------------------------------------------------
cat > "$CHART_DIR/values.yaml" <<'EOF'
global:
  environment: dev

# PostgreSQL subchart
postgresql:
  enabled: true
  auth:
    database: simpleauthdb
    username: postgres
    password: "StrongDBPassword123"
  primary:
    persistence:
      enabled: false
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi
  image:
    registry: 296725355870.dkr.ecr.ap-southeast-1.amazonaws.com
    repository: postgresql
    tag: latest
  imagePullSecrets:
    - name: ecr-secret

# API subchart
api:
  replicaCount: 2
  image:
    repository: 296725355870.dkr.ecr.ap-southeast-1.amazonaws.com/quyen-simpleauth-api
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
  jwtSecret: "your-strong-secret-at-least-32-characters-long"
  database:
    host: "simpleauth-postgresql"
    port: 5432
    name: "simpleauthdb"
    username: "postgres"
    password: "StrongDBPassword123"   # Dùng trực tiếp thay vì secret để tránh lỗi
  imagePullSecrets:
    - name: ecr-secret

# UI subchart
ui:
  replicaCount: 2
  image:
    repository: 296725355870.dkr.ecr.ap-southeast-1.amazonaws.com/quyen-simpleauth-ui
    tag: latest
    pullPolicy: Always
  service:
    type: ClusterIP
    port: 80
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
  apiUrl: "/api"
  imagePullSecrets:
    - name: ecr-secret

# Ingress configuration
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /index.html
  hosts:
    - host: ""
      paths:
        - path: /
          pathType: Prefix
          serviceName: simpleauth-ui
          servicePort: 80
        - path: /api
          pathType: Prefix
          serviceName: simpleauth-api
          servicePort: 80
EOF

# Parent _helpers.tpl
cat > "$CHART_DIR/templates/_helpers.tpl" <<'EOF'
{{- define "simpleauth.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
EOF

# Ingress template
cat > "$CHART_DIR/templates/ingress.yaml" <<'EOF'
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}-ingress
  labels:
    {{- include "simpleauth.labels" . | nindent 4 }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
  {{- range .Values.ingress.hosts }}
  - host: {{ .host | quote }}
    http:
      paths:
      {{- range .paths }}
      - path: {{ .path }}
        pathType: {{ .pathType }}
        backend:
          service:
            name: {{ .serviceName }}
            port:
              number: {{ .servicePort }}
      {{- end }}
  {{- end }}
{{- end }}
EOF

# ------------------------------------------------------------------------
# API Subchart
# ------------------------------------------------------------------------
API_DIR="$CHART_DIR/charts/api"
mkdir -p "$API_DIR/templates"

cat > "$API_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: api
description: .NET API for SimpleAuth
type: application
version: 1.0.0
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
  password: ""
imagePullSecrets: []
EOF

# API helpers
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

# API deployment (sửa: dùng password từ values thay vì secret)
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
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
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
          value: "Host={{ .Values.database.host }};Port={{ .Values.database.port }};Database={{ .Values.database.name }};Username={{ .Values.database.username }};Password={{ .Values.database.password }}"
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

# ------------------------------------------------------------------------
# UI Subchart
# ------------------------------------------------------------------------
UI_DIR="$CHART_DIR/charts/ui"
mkdir -p "$UI_DIR/templates"

cat > "$UI_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: ui
description: Angular UI for SimpleAuth
type: application
version: 1.0.0
appVersion: "1.0.0"
EOF

cat > "$UI_DIR/values.yaml" <<EOF
replicaCount: 2
image:
  repository: simpleauth-ui
  tag: latest
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
resources: {}
apiUrl: "/api"
imagePullSecrets: []
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
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
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

echo "✅ Helm chart đã được tạo tại $CHART_DIR"
echo "📦 Tiếp theo:"
echo "1. cd $CHART_DIR"
echo "2. helm dependency update"
echo "3. Tạo secret ecr-secret (nếu chưa có):"
echo "   kubectl -n simpleauth create secret docker-registry ecr-secret ..."
echo "4. Cài đặt:"
echo "   helm install simpleauth . -n simpleauth --create-namespace"