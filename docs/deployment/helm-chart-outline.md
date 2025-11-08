# Kubernetes Deployment - Helm Chart

## 6. K8s Manifests & Helm Outline

### Helm Chart Structure

```
helm/train-my-ai/
├── Chart.yaml
├── values.yaml
├── values-prod.yaml
├── values-staging.yaml
├── values-dev.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── api/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   └── ingress.yaml
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   ├── workers/
│   │   ├── job-controller-deployment.yaml
│   │   └── worker-rbac.yaml
│   ├── postgres/
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   ├── redis/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── minio/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   ├── mlflow/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── vault/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── monitoring/
│   │   ├── prometheus.yaml
│   │   ├── grafana.yaml
│   │   └── servicemonitor.yaml
│   ├── network-policies/
│   │   ├── api-netpol.yaml
│   │   ├── worker-netpol.yaml
│   │   └── data-netpol.yaml
│   └── gpu/
│       ├── gpu-node-pool.yaml
│       └── gpu-quota.yaml
└── crds/
    └── job-crd.yaml
```

---

### Chart.yaml

```yaml
apiVersion: v2
name: train-my-ai
description: No-code AI training platform
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - ai
  - ml
  - training
  - rag
  - fine-tuning
maintainers:
  - name: Train-My-AI Team
    email: ops@train-my-ai.com
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
  - name: prometheus
    version: "15.x.x"
    repository: "https://prometheus-community.github.io/helm-charts"
    condition: prometheus.enabled
```

---

### values.yaml (Defaults)

```yaml
# Global settings
global:
  environment: production
  region: us-west-2
  domain: train-my-ai.com

# API deployment
api:
  replicaCount: 3
  image:
    repository: trainmyai/api
    tag: v1.0.0
    pullPolicy: IfNotPresent

  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

  env:
    - name: LOG_LEVEL
      value: "INFO"
    - name: WORKERS
      value: "4"
    - name: DB_POOL_SIZE
      value: "20"

  service:
    type: ClusterIP
    port: 8000

  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/rate-limit: "100"
    hosts:
      - host: api.train-my-ai.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: api-tls
        hosts:
          - api.train-my-ai.com

# Frontend
frontend:
  replicaCount: 3
  image:
    repository: trainmyai/frontend
    tag: v1.0.0

  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

  service:
    type: ClusterIP
    port: 3000

  ingress:
    enabled: true
    hosts:
      - host: app.train-my-ai.com
        paths:
          - path: /
            pathType: Prefix

# Workers
workers:
  jobController:
    replicaCount: 2
    image:
      repository: trainmyai/job-controller
      tag: v1.0.0
    resources:
      requests:
        cpu: 1000m
        memory: 2Gi

  ingestWorker:
    image:
      repository: trainmyai/ingest-worker
      tag: v1.0.0

  ragWorker:
    image:
      repository: trainmyai/rag-worker
      tag: v1.0.0

  sftWorker:
    image:
      repository: trainmyai/sft-worker
      tag: v1.0.0

# PostgreSQL
postgresql:
  enabled: true
  auth:
    existingSecret: postgres-credentials
  primary:
    persistence:
      enabled: true
      size: 100Gi
      storageClass: "gp3"
    resources:
      requests:
        cpu: 2000m
        memory: 8Gi
      limits:
        cpu: 4000m
        memory: 16Gi
    podSecurityContext:
      enabled: true
      fsGroup: 1001
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

# Redis
redis:
  enabled: true
  architecture: standalone
  auth:
    existingSecret: redis-credentials
  master:
    persistence:
      enabled: true
      size: 20Gi
    resources:
      requests:
        cpu: 500m
        memory: 2Gi

# MinIO (S3-compatible storage)
minio:
  enabled: true
  replicas: 4
  mode: distributed
  persistence:
    enabled: true
    size: 1Ti
    storageClass: "gp3"
  resources:
    requests:
      cpu: 1000m
      memory: 4Gi
  buckets:
    - name: train-my-ai
      policy: none
      purge: false

# MLflow
mlflow:
  enabled: true
  replicaCount: 2
  image:
    repository: trainmyai/mlflow
    tag: "2.9.2"
  backendStore:
    type: postgresql
  artifactStore:
    type: s3
    s3:
      bucket: train-my-ai
      prefix: mlflow/

# Vault
vault:
  enabled: true
  server:
    ha:
      enabled: true
      replicas: 3
    dataStorage:
      enabled: true
      size: 10Gi
    resources:
      requests:
        cpu: 500m
        memory: 1Gi

# GPU Node Pool
gpu:
  enabled: true
  nodePools:
    - name: gpu-a10
      machineType: n1-standard-8
      accelerator:
        type: nvidia-tesla-a10
        count: 1
      minNodes: 0
      maxNodes: 10
      diskSize: 200Gi

    - name: gpu-a100
      machineType: a2-highgpu-1g
      accelerator:
        type: nvidia-tesla-a100
        count: 1
      minNodes: 0
      maxNodes: 5
      diskSize: 500Gi

  # Resource quotas per workspace
  quotas:
    enabled: true
    default:
      pods: "10"
      requests.nvidia.com/gpu: "2"
      limits.memory: "100Gi"

# Monitoring
prometheus:
  enabled: true
  server:
    retention: 15d
    persistentVolume:
      size: 50Gi

grafana:
  enabled: true
  adminPassword: changeme
  dashboards:
    enabled: true
  datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server

loki:
  enabled: true
  persistence:
    enabled: true
    size: 100Gi

jaeger:
  enabled: true
  storage:
    type: elasticsearch

# Network Policies
networkPolicies:
  enabled: true
  defaultDeny: true

# Security
podSecurityPolicy:
  enabled: true

rbac:
  create: true

serviceAccount:
  create: true
  name: train-my-ai

# Secrets
secrets:
  create: true
  postgres:
    username: trainmyai
    password: CHANGE_ME_IN_PRODUCTION
  redis:
    password: CHANGE_ME_IN_PRODUCTION
  minio:
    accessKey: CHANGE_ME
    secretKey: CHANGE_ME
```

---

### Example Manifests

#### API Deployment

```yaml
# templates/api/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "train-my-ai.fullname" . }}-api
  labels:
    {{- include "train-my-ai.labels" . | nindent 4 }}
    component: api
spec:
  {{- if not .Values.api.autoscaling.enabled }}
  replicas: {{ .Values.api.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "train-my-ai.selectorLabels" . | nindent 6 }}
      component: api
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "train-my-ai.selectorLabels" . | nindent 8 }}
        component: api
    spec:
      serviceAccountName: {{ include "train-my-ai.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: api
        image: "{{ .Values.api.image.repository }}:{{ .Values.api.image.tag }}"
        imagePullPolicy: {{ .Values.api.image.pullPolicy }}

        ports:
        - name: http
          containerPort: 8000
          protocol: TCP

        env:
        {{- range .Values.api.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        - name: POSTGRES_HOST
          valueFrom:
            secretKeyRef:
              name: {{ .Values.postgresql.auth.existingSecret }}
              key: host
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.postgresql.auth.existingSecret }}
              key: password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.redis.auth.existingSecret }}
              key: password
        - name: S3_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: access-key
        - name: S3_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: secret-key

        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2

        resources:
          {{- toYaml .Values.api.resources | nindent 10 }}

        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]

        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /.cache

      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}

      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

#### Network Policy (API)

```yaml
# templates/network-policies/api-netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "train-my-ai.fullname" . }}-api
spec:
  podSelector:
    matchLabels:
      component: api
  policyTypes:
  - Ingress
  - Egress

  ingress:
  # Allow from ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000

  # Allow from frontend
  - from:
    - podSelector:
        matchLabels:
          component: frontend
    ports:
    - protocol: TCP
      port: 8000

  egress:
  # Allow to PostgreSQL
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: postgresql
    ports:
    - protocol: TCP
      port: 5432

  # Allow to Redis
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: redis
    ports:
    - protocol: TCP
      port: 6379

  # Allow to MinIO
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: minio
    ports:
    - protocol: TCP
      port: 9000

  # Allow to Vault
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: vault
    ports:
    - protocol: TCP
      port: 8200

  # Allow DNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53

  # Allow HTTPS egress (for external APIs)
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
```

#### GPU Job CRD

```yaml
# templates/gpu/job-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: trainingjobs.trainmyai.com
spec:
  group: trainmyai.com
  names:
    kind: TrainingJob
    listKind: TrainingJobList
    plural: trainingjobs
    singular: trainingjob
    shortNames:
    - tj
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              jobId:
                type: string
              workspaceId:
                type: string
              jobType:
                type: string
                enum: ["RAG_TRAIN", "SFT_TRAIN", "EVAL"]
              datasetId:
                type: string
              config:
                type: object
                x-kubernetes-preserve-unknown-fields: true
              resources:
                type: object
                properties:
                  gpuCount:
                    type: integer
                  gpuType:
                    type: string
                  memoryGb:
                    type: integer
              timeoutSeconds:
                type: integer
                default: 7200
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Running", "Succeeded", "Failed"]
              startTime:
                type: string
                format: date-time
              completionTime:
                type: string
                format: date-time
              message:
                type: string
```

---

### Resource Quotas

```yaml
# templates/gpu/gpu-quota.yaml
{{- range $workspace := .Values.workspaces }}
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: workspace-{{ $workspace.id }}-quota
  namespace: {{ $.Release.Namespace }}
spec:
  hard:
    requests.nvidia.com/gpu: {{ $workspace.gpuQuota | default 2 | quote }}
    limits.memory: {{ $workspace.memoryQuota | default "100Gi" | quote }}
    pods: {{ $workspace.podQuota | default 10 | quote }}
    persistentvolumeclaims: "5"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["workspace-{{ $workspace.id }}"]
{{- end }}
```

---

### PodDisruptionBudget

```yaml
# templates/api/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "train-my-ai.fullname" . }}-api
spec:
  minAvailable: 2
  selector:
    matchLabels:
      component: api
```

---

### Installation Commands

```bash
# Add Helm repo (if publishing)
helm repo add train-my-ai https://charts.train-my-ai.com
helm repo update

# Install with default values
helm install train-my-ai train-my-ai/train-my-ai \
  --namespace train-my-ai \
  --create-namespace

# Install with custom values
helm install train-my-ai train-my-ai/train-my-ai \
  --namespace train-my-ai \
  --create-namespace \
  --values values-prod.yaml

# Upgrade
helm upgrade train-my-ai train-my-ai/train-my-ai \
  --namespace train-my-ai \
  --values values-prod.yaml

# Rollback
helm rollback train-my-ai 1 --namespace train-my-ai
```
