# Observability Framework

## 9. Logging, Tracing, Metrics & Dashboards

### Overview

Three-pillar observability: **Logs** (Loki), **Metrics** (Prometheus), **Traces** (Jaeger)

### Logging Stack

#### Structured Logging Format (JSON)

```json
{
  "timestamp": "2025-11-08T14:30:00.123+05:30",
  "level": "INFO",
  "service": "api",
  "version": "1.0.0",
  "trace_id": "abc123def456",
  "span_id": "xyz789",
  "workspace_id": "ws_001",
  "user_id": "user_123",
  "job_id": "job_456",
  "message": "Job started successfully",
  "duration_ms": 1234,
  "http_method": "POST",
  "http_status": 200,
  "error": null
}
```

#### Log Aggregation with Loki

```yaml
# promtail-config.yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
    pipeline_stages:
      - json:
          expressions:
            level: level
            workspace_id: workspace_id
            job_id: job_id
      - labels:
          level:
          workspace_id:
          job_id:
```

### Metrics (Prometheus)

#### Key Metrics

```python
# backend/app/core/metrics.py
from prometheus_client import Counter, Histogram, Gauge, Info

# API metrics
http_requests_total = Counter(
    'trainmyai_http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'trainmyai_http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint']
)

# Job metrics
job_queue_depth = Gauge(
    'trainmyai_job_queue_depth',
    'Jobs in queue',
    ['compute_type', 'job_type']
)

job_duration_seconds = Histogram(
    'trainmyai_job_duration_seconds',
    'Job execution time',
    ['job_type', 'status'],
    buckets=[60, 300, 600, 1800, 3600, 7200, 14400]
)

job_gpu_seconds_total = Counter(
    'trainmyai_job_gpu_seconds_total',
    'Total GPU seconds consumed',
    ['workspace_id', 'compute_type']
)

# Workspace metrics
workspace_storage_bytes = Gauge(
    'trainmyai_workspace_storage_bytes',
    'Storage used per workspace',
    ['workspace_id']
)

workspace_budget_used_usd = Gauge(
    'trainmyai_workspace_budget_used_usd',
    'Budget spent',
    ['workspace_id']
)

# GPU node metrics
gpu_node_status = Gauge(
    'trainmyai_gpu_node_status',
    'GPU node status (1=online, 0=offline)',
    ['node_id', 'workspace_id']
)

gpu_vram_free_mb = Gauge(
    'trainmyai_gpu_vram_free_mb',
    'Free GPU VRAM',
    ['node_id', 'gpu_id']
)

# Database metrics
db_connections_active = Gauge(
    'trainmyai_db_connections_active',
    'Active DB connections'
)

db_query_duration_seconds = Histogram(
    'trainmyai_db_query_duration_seconds',
    'DB query latency',
    ['query_type']
)
```

### Distributed Tracing (Jaeger)

#### Instrumentation

```python
# backend/app/core/tracing.py
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

def setup_tracing(app):
    """Setup distributed tracing"""

    # Configure tracer
    tracer_provider = TracerProvider()
    trace.set_tracer_provider(tracer_provider)

    # Jaeger exporter
    jaeger_exporter = JaegerExporter(
        agent_host_name=os.getenv("JAEGER_AGENT_HOST", "localhost"),
        agent_port=int(os.getenv("JAEGER_AGENT_PORT", "6831")),
    )

    tracer_provider.add_span_processor(
        BatchSpanProcessor(jaeger_exporter)
    )

    # Auto-instrument FastAPI
    FastAPIInstrumentor.instrument_app(app)

    # Auto-instrument SQLAlchemy
    SQLAlchemyInstrumentor().instrument()

# Usage in route
@app.post("/v1/workspaces/{workspace_id}/jobs")
async def create_job(workspace_id: str, job: JobCreate):
    tracer = trace.get_tracer(__name__)

    with tracer.start_as_current_span("create_job") as span:
        span.set_attribute("workspace_id", workspace_id)
        span.set_attribute("job_type", job.job_type)

        # Business logic...
        with tracer.start_as_current_span("validate_dataset"):
            dataset = await validate_dataset(job.dataset_id)

        with tracer.start_as_current_span("enqueue_job"):
            job_id = await enqueue_job(job)

        return {"job_id": job_id}
```

### Grafana Dashboards

#### Dashboard 1: System Health

```json
{
  "title": "Train-My-AI System Health",
  "panels": [
    {
      "title": "API Request Rate",
      "targets": [
        {
          "expr": "rate(trainmyai_http_requests_total[5m])"
        }
      ]
    },
    {
      "title": "API Latency (p95)",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, rate(trainmyai_http_request_duration_seconds_bucket[5m]))"
        }
      ]
    },
    {
      "title": "Error Rate",
      "targets": [
        {
          "expr": "rate(trainmyai_http_requests_total{status=~\"5..\"}[5m])"
        }
      ]
    }
  ]
}
```

#### Dashboard 2: Job Analytics

- Job queue depth by type
- Job success/failure rate
- Average job duration by type
- GPU utilization over time
- Jobs by workspace (top 10)

#### Dashboard 3: Cost Tracking

- Total GPU hours (managed vs BYO)
- Storage usage by workspace
- Cost per workspace (top spenders)
- Budget burn rate
- Projected monthly cost

#### Dashboard 4: Workspace Overview

- Storage used / limit
- Budget used / limit
- Active jobs count
- Models deployed
- API call rate

### Alerts (Prometheus Alertmanager)

```yaml
# alerts.yaml
groups:
  - name: system_alerts
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: |
          rate(trainmyai_http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # API latency high
      - alert: HighAPILatency
        expr: |
          histogram_quantile(0.95,
            rate(trainmyai_http_request_duration_seconds_bucket[5m])
          ) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "API p95 latency > 2s"

      # Job queue backlog
      - alert: JobQueueBacklog
        expr: trainmyai_job_queue_depth > 50
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Job queue has {{ $value }} pending jobs"

      # GPU node offline
      - alert: GPUNodeOffline
        expr: trainmyai_gpu_node_status == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "GPU node {{ $labels.node_id }} is offline"

      # Budget threshold exceeded
      - alert: BudgetThresholdExceeded
        expr: |
          (trainmyai_workspace_budget_used_usd /
           trainmyai_workspace_budget_limit_usd) > 0.9
        labels:
          severity: warning
        annotations:
          summary: "Workspace {{ $labels.workspace_id }} at 90% budget"

      # Storage quota exceeded
      - alert: StorageQuotaExceeded
        expr: |
          (trainmyai_workspace_storage_bytes /
           trainmyai_workspace_storage_limit_bytes) > 0.95
        labels:
          severity: critical
        annotations:
          summary: "Workspace {{ $labels.workspace_id }} at 95% storage"

      # Database connection pool exhaustion
      - alert: DBConnectionPoolExhausted
        expr: trainmyai_db_connections_active > 90
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "DB connection pool nearly exhausted"
```

### Log Queries (LogQL - Loki)

```logql
# All errors in last hour
{app="api"} | json | level="ERROR" | line_format "{{.timestamp}} {{.message}}"

# Failed jobs
{app="job-controller"} | json | status="FAILED" | line_format "{{.job_id}}: {{.error}}"

# Slow queries (> 1s)
{app="api"} | json | duration_ms > 1000 | line_format "{{.endpoint}}: {{.duration_ms}}ms"

# Budget alerts
{app="api"} | json | message=~".*budget.*"

# Specific workspace activity
{workspace_id="ws_abc123"} | json | line_format "{{.timestamp}} {{.service}}: {{.message}}"
```

### Example Dashboard Queries

```promql
# Top 10 workspaces by GPU usage (last 7 days)
topk(10, sum by (workspace_id) (
  increase(trainmyai_job_gpu_seconds_total[7d])
))

# Job success rate by type
sum by (job_type) (
  rate(trainmyai_job_duration_seconds_count{status="SUCCEEDED"}[1h])
) / sum by (job_type) (
  rate(trainmyai_job_duration_seconds_count[1h])
)

# Average job duration by type
avg by (job_type) (
  rate(trainmyai_job_duration_seconds_sum[1h]) /
  rate(trainmyai_job_duration_seconds_count[1h])
)

# GPU node availability
avg(trainmyai_gpu_node_status) by (compute_type)
```

### On-Call Runbook

#### Alert: HighErrorRate
1. Check Grafana system health dashboard
2. Query logs: `{app="api"} | json | level="ERROR"`
3. Check recent deployments
4. Scale up API pods if CPU/memory high
5. Escalate to engineering if > 15 minutes

#### Alert: GPUNodeOffline
1. Check node heartbeat logs
2. SSH to node, check agent status: `systemctl status gpu-agent`
3. Check network connectivity
4. Restart agent if needed
5. Notify workspace owner

#### Alert: BudgetThresholdExceeded
1. Check workspace billing dashboard
2. Calculate projected end-of-month cost
3. Email workspace owner with alert
4. Auto-pause new job submissions at 100%

### Log Retention Policy

- **Hot storage (Loki)**: 30 days
- **Warm storage (S3)**: 90 days
- **Cold storage (Glacier)**: 2 years
- **Audit logs**: 7 years (compliance)
