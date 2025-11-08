# Job Orchestration & Queue Schemas

## 5. Queue/Job Schemas and State Machine

### Job Queue Schema (Redis)

#### Queue Structure

```
# Pending jobs (FIFO queue per compute type)
queue:jobs:managed_gpu        → List of job_ids
queue:jobs:byo_gpu            → List of job_ids

# Job metadata (fast access)
job:{job_id}:metadata         → Hash
  - workspace_id
  - job_type
  - compute_type
  - priority (0-10)
  - created_at
  - timeout_seconds

# Job status (pubsub for real-time updates)
channel:job:{job_id}:status   → Pub/Sub channel
  - Message: {"status": "RUNNING", "progress": 0.5, "timestamp": "..."}

# GPU node queues (for BYO GPU)
queue:gpu_node:{node_id}      → List of assigned job_ids

# Dead letter queue (failed jobs for manual review)
queue:jobs:dead_letter        → List of failed job specs
```

#### Job Message Format

```json
{
  "job_id": "job_abc123",
  "workspace_id": "ws_xyz789",
  "job_type": "SFT_TRAIN",
  "dataset_id": "ds_def456",
  "compute_type": "MANAGED_GPU",
  "gpu_node_id": null,

  "config": {
    "base_model": "meta-llama/Llama-3-8B",
    "lora_r": 16,
    "lora_alpha": 32,
    "learning_rate": 0.0002,
    "num_epochs": 3,
    "batch_size": 4,
    "use_4bit": true
  },

  "secrets": {
    "HUGGINGFACE_TOKEN": "vault://workspaces/ws_xyz789/api_keys/huggingface"
  },

  "resources": {
    "gpu_count": 1,
    "gpu_type": "A10",
    "memory_gb": 24,
    "timeout_seconds": 7200
  },

  "retry_policy": {
    "max_retries": 3,
    "backoff_multiplier": 2,
    "initial_delay_seconds": 60
  },

  "callbacks": {
    "on_complete": "https://api.train-my-ai.com/v1/jobs/job_abc123/complete",
    "on_failure": "https://api.train-my-ai.com/v1/jobs/job_abc123/fail"
  },

  "priority": 5,
  "created_at": "2025-11-08T14:30:00+05:30"
}
```

---

### Job State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                        JOB LIFECYCLE                             │
└─────────────────────────────────────────────────────────────────┘

                      [User submits job]
                             │
                             ▼
                      ┌─────────────┐
                      │   PENDING   │ ◄─────────────────┐
                      └──────┬──────┘                   │
                             │                          │
                             │ [Validation passed]      │
                             ▼                          │
                      ┌─────────────┐                   │
                      │   QUEUED    │                   │ [Retry]
                      └──────┬──────┘                   │
                             │                          │
                             │ [Worker picks up job]    │
                             ▼                          │
                      ┌─────────────┐                   │
                  ┌──►│   RUNNING   │                   │
                  │   └──────┬──────┘                   │
                  │          │                          │
                  │          ├──────────────────────┐   │
                  │          │                      │   │
                  │          │ [Success]            │ [Failure, retries left]
                  │          │                      │   │
                  │          ▼                      ▼   │
                  │   ┌─────────────┐        ┌──────────┴───┐
                  │   │  SUCCEEDED  │        │    FAILED    │
                  │   └─────────────┘        └──────────────┘
                  │                                 │
                  │                                 │ [No retries left]
                  │                                 ▼
                  │                          ┌─────────────┐
                  │                          │  DEAD_LETTER │
                  │                          └─────────────┘
                  │
                  │   [User cancels]
                  │          │
                  │          ▼
                  │   ┌─────────────┐
                  └───┤  CANCELLED  │
                      └─────────────┘
```

### State Transitions

| From | To | Trigger | Actions |
|------|-----|---------|---------|
| `PENDING` | `QUEUED` | Validation passed | Add to queue, notify user |
| `PENDING` | `FAILED` | Validation failed | Log error, notify user |
| `QUEUED` | `RUNNING` | Worker picks job | Allocate resources, start container |
| `QUEUED` | `CANCELLED` | User cancels | Remove from queue, notify user |
| `RUNNING` | `SUCCEEDED` | Job completes successfully | Save artifacts, update DB, bill usage |
| `RUNNING` | `FAILED` | Job fails (retry possible) | Log error, increment retry_count, re-queue if retries left |
| `RUNNING` | `DEAD_LETTER` | Job fails (no retries) | Move to DLQ, notify user, alert ops |
| `RUNNING` | `CANCELLED` | User cancels | Stop container, cleanup resources |
| `FAILED` | `QUEUED` | Retry triggered | Reset progress, re-queue |

---

### Worker Orchestration (Kubernetes Jobs)

#### Job Template (K8s CRD)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sft-train-job-abc123
  namespace: train-my-ai
  labels:
    app: train-my-ai
    job-type: sft-train
    workspace-id: ws_xyz789
    job-id: job_abc123
spec:
  ttlSecondsAfterFinished: 3600  # Cleanup after 1 hour
  backoffLimit: 0  # No K8s retries (we handle retries)
  activeDeadlineSeconds: 7200  # 2-hour timeout

  template:
    metadata:
      labels:
        app: train-my-ai
        job-id: job_abc123
    spec:
      restartPolicy: Never
      serviceAccountName: train-my-ai-worker

      # Node affinity (GPU required)
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: nvidia.com/gpu.product
                operator: In
                values: ["NVIDIA-A10", "NVIDIA-A100-SXM4-40GB"]

      # Tolerations for GPU nodes
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule

      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: sft-trainer
        image: trainmyai/sft-worker:v1.0.0
        imagePullPolicy: IfNotPresent

        # Resource limits
        resources:
          requests:
            cpu: "4"
            memory: "16Gi"
            nvidia.com/gpu: "1"
          limits:
            cpu: "8"
            memory: "24Gi"
            nvidia.com/gpu: "1"

        # Environment variables
        env:
        - name: JOB_ID
          value: "job_abc123"
        - name: WORKSPACE_ID
          value: "ws_xyz789"
        - name: DATASET_ID
          value: "ds_def456"
        - name: S3_BUCKET
          value: "train-my-ai"
        - name: POSTGRES_HOST
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: host
        - name: HUGGINGFACE_TOKEN
          valueFrom:
            secretKeyRef:
              name: workspace-ws-xyz789-secrets
              key: huggingface_token
        - name: MLFLOW_TRACKING_URI
          value: "http://mlflow-server:5000"

        # Volume mounts
        volumeMounts:
        - name: workspace-data
          mountPath: /workspace
        - name: shm
          mountPath: /dev/shm

        # Container security
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]

      volumes:
      - name: workspace-data
        emptyDir:
          sizeLimit: 50Gi
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi

      # Image pull secrets
      imagePullSecrets:
      - name: dockerhub-secret
```

---

### BYO GPU Job Polling

#### Agent Polling Loop

```python
import time
import requests
from typing import Optional

class GPUAgent:
    def __init__(self, node_id: str, api_url: str, mtls_cert: str, mtls_key: str):
        self.node_id = node_id
        self.api_url = api_url
        self.session = requests.Session()
        self.session.cert = (mtls_cert, mtls_key)

    def poll_for_job(self) -> Optional[dict]:
        """Poll for next job assignment."""
        response = self.session.get(
            f"{self.api_url}/v1/gpu-nodes/{self.node_id}/jobs/next",
            timeout=5
        )

        if response.status_code == 200:
            return response.json()
        elif response.status_code == 204:
            return None  # No jobs available
        else:
            raise Exception(f"Poll failed: {response.status_code}")

    def run_loop(self):
        """Main agent loop."""
        while True:
            try:
                # Send heartbeat
                self.send_heartbeat()

                # Check for jobs
                job = self.poll_for_job()

                if job:
                    self.execute_job(job)
                else:
                    time.sleep(10)  # Wait before next poll

            except Exception as e:
                print(f"Error: {e}")
                time.sleep(30)
```

---

### Job Retry Logic

#### Retry Strategy

```python
from datetime import datetime, timedelta

class RetryPolicy:
    def __init__(self, max_retries: int = 3, backoff_multiplier: float = 2.0):
        self.max_retries = max_retries
        self.backoff_multiplier = backoff_multiplier

    def should_retry(self, job: dict) -> bool:
        """Check if job should be retried."""
        retry_count = job.get('retry_count', 0)

        # Don't retry if max retries exceeded
        if retry_count >= self.max_retries:
            return False

        # Don't retry certain errors
        error = job.get('error', '')
        non_retriable_errors = [
            'INVALID_CONFIG',
            'DATASET_NOT_FOUND',
            'QUOTA_EXCEEDED',
            'PERMISSION_DENIED'
        ]

        if any(err in error for err in non_retriable_errors):
            return False

        return True

    def calculate_delay(self, retry_count: int) -> int:
        """Calculate backoff delay in seconds."""
        base_delay = 60  # 1 minute
        delay = base_delay * (self.backoff_multiplier ** retry_count)
        return min(delay, 3600)  # Cap at 1 hour
```

---

### Job Lifecycle Hooks

#### Event Hooks

```python
from typing import Callable, Dict

class JobEventHooks:
    """Hooks for job lifecycle events."""

    hooks: Dict[str, list[Callable]] = {
        'on_queued': [],
        'on_started': [],
        'on_progress': [],
        'on_completed': [],
        'on_failed': [],
        'on_cancelled': []
    }

    @classmethod
    def register(cls, event: str, callback: Callable):
        """Register a callback for an event."""
        if event in cls.hooks:
            cls.hooks[event].append(callback)

    @classmethod
    async def trigger(cls, event: str, job: dict):
        """Trigger all callbacks for an event."""
        if event in cls.hooks:
            for callback in cls.hooks[event]:
                await callback(job)

# Example usage
async def notify_user(job: dict):
    """Send notification to user."""
    # Send email/websocket notification
    pass

async def update_billing(job: dict):
    """Update billing usage."""
    # Calculate cost and update DB
    pass

JobEventHooks.register('on_completed', notify_user)
JobEventHooks.register('on_completed', update_billing)
```

---

### Monitoring & Alerting

#### Job Queue Metrics (Prometheus)

```python
from prometheus_client import Gauge, Counter, Histogram

# Queue depth
job_queue_depth = Gauge(
    'train_my_ai_job_queue_depth',
    'Number of jobs in queue',
    ['compute_type', 'job_type']
)

# Job duration
job_duration_seconds = Histogram(
    'train_my_ai_job_duration_seconds',
    'Job execution time',
    ['job_type', 'status']
)

# Job failures
job_failures_total = Counter(
    'train_my_ai_job_failures_total',
    'Total job failures',
    ['job_type', 'error_type']
)

# Active jobs
active_jobs = Gauge(
    'train_my_ai_active_jobs',
    'Currently running jobs',
    ['compute_type']
)
```

#### Alerts

```yaml
# Prometheus AlertManager rules
groups:
- name: job_alerts
  interval: 30s
  rules:

  # High queue depth
  - alert: JobQueueBacklog
    expr: train_my_ai_job_queue_depth > 20
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Job queue backlog on {{ $labels.compute_type }}"
      description: "Queue has {{ $value }} pending jobs"

  # High failure rate
  - alert: JobFailureRateHigh
    expr: rate(train_my_ai_job_failures_total[5m]) > 0.5
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High job failure rate for {{ $labels.job_type }}"
      description: "Failure rate: {{ $value | humanize }}/s"

  # Job timeout
  - alert: JobStuck
    expr: train_my_ai_job_duration_seconds{status="RUNNING"} > 3600
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Job {{ $labels.job_id }} running longer than expected"

  # GPU node offline
  - alert: GPUNodeOffline
    expr: time() - train_my_ai_gpu_node_last_heartbeat_seconds > 120
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "GPU node {{ $labels.node_id }} is offline"
```

---

### Graceful Shutdown

```python
import signal
import asyncio

class JobWorker:
    def __init__(self):
        self.current_job = None
        self.shutdown_requested = False

        # Register signal handlers
        signal.signal(signal.SIGTERM, self.handle_shutdown)
        signal.signal(signal.SIGINT, self.handle_shutdown)

    def handle_shutdown(self, signum, frame):
        """Handle graceful shutdown."""
        print("Shutdown requested, finishing current job...")
        self.shutdown_requested = True

    async def run(self):
        """Main worker loop."""
        while not self.shutdown_requested:
            job = await self.fetch_job()

            if job:
                self.current_job = job
                await self.execute_job(job)
                self.current_job = None
            else:
                await asyncio.sleep(5)

        # Wait for current job to finish
        if self.current_job:
            print(f"Waiting for job {self.current_job['id']} to complete...")
            # Allow up to 5 minutes for graceful completion
            await asyncio.wait_for(self.wait_for_completion(), timeout=300)

        print("Worker shut down gracefully")
```

---

### Job Prioritization

#### Priority Scoring

```python
from datetime import datetime

def calculate_priority_score(job: dict) -> int:
    """Calculate job priority (higher = more urgent)."""

    base_priority = job.get('priority', 5)  # User-set priority (0-10)

    # Time waiting (age bonus)
    created_at = datetime.fromisoformat(job['created_at'])
    age_hours = (datetime.now() - created_at).total_seconds() / 3600
    age_bonus = min(age_hours * 0.5, 5)  # Max +5 for age

    # Workspace tier bonus (paid customers get +2)
    tier_bonus = 2 if job.get('workspace_tier') == 'PAID' else 0

    # Job type urgency
    type_urgency = {
        'INFER': 10,      # Real-time inference is urgent
        'EVAL': 7,
        'RAG_TRAIN': 5,
        'SFT_TRAIN': 3,   # Training can wait
        'INGEST': 1
    }.get(job['job_type'], 5)

    # Retry penalty (failed jobs get lower priority)
    retry_penalty = job.get('retry_count', 0) * -1

    return base_priority + age_bonus + tier_bonus + type_urgency + retry_penalty

# Sort queue by priority
jobs_sorted = sorted(job_queue, key=calculate_priority_score, reverse=True)
```

---

### Dead Letter Queue (DLQ) Handler

```python
async def process_dead_letter_queue():
    """Manual review and reprocessing of failed jobs."""

    dlq_jobs = await redis.lrange('queue:jobs:dead_letter', 0, -1)

    for job_json in dlq_jobs:
        job = json.loads(job_json)

        # Analyze failure
        error_type = classify_error(job['error'])

        if error_type == 'TRANSIENT':
            # Maybe retry after fixing issue
            await notify_ops(f"DLQ job {job['id']} might be retriable")

        elif error_type == 'CONFIG_ERROR':
            # Notify user to fix config
            await notify_user(job['workspace_id'],
                             f"Job {job['id']} failed due to config error")

        elif error_type == 'PLATFORM_BUG':
            # Alert engineering
            await alert_engineering(f"Platform bug caused job {job['id']} to fail")

        # Archive to S3 for long-term storage
        await archive_to_s3(job)
```
