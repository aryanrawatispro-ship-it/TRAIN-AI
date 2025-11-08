# Component Specifications & Interfaces

## 2. Component List

### Frontend Layer

#### 1. Next.js Web Application
**Responsibilities:**
- Server-side rendering for SEO and initial page load
- Client-side SPA for interactive workflows
- Resumable file upload with chunking (tus protocol or similar)
- Real-time job status via WebSocket
- Cost/usage dashboards with live updates
- Model playground (chat interface for RAG/SFT models)
- Budget alerts and workspace settings

**Interfaces:**
- **HTTP/REST**: Calls FastAPI backend via `/api/*`
- **WebSocket**: Connects to `/ws/jobs/{job_id}` for live updates
- **S3 Direct Upload**: Presigned URLs for chunked uploads

**Tech Stack:**
- Next.js 14+ (App Router)
- TypeScript
- TailwindCSS + shadcn/ui
- React Query for data fetching
- Zustand for state management
- tus-js-client for resumable uploads

**Key Files:**
```
frontend/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   └── signup/
│   ├── (dashboard)/
│   │   ├── workspaces/
│   │   ├── datasets/
│   │   ├── jobs/
│   │   ├── models/
│   │   ├── playground/
│   │   └── billing/
│   └── api/           # Next.js API routes (proxy to backend)
├── components/
│   ├── FileUploader.tsx
│   ├── JobMonitor.tsx
│   ├── PlaygroundChat.tsx
│   └── UsageChart.tsx
└── lib/
    ├── api-client.ts
    └── websocket.ts
```

---

### API & Gateway Layer

#### 2. FastAPI Core API
**Responsibilities:**
- REST API for all CRUD operations
- JWT-based authentication & RBAC
- Rate limiting per workspace (Redis-backed)
- Multi-tenant request validation (workspace scoping)
- Request/response logging for audit
- Job orchestration (submit to queue)
- Presigned URL generation for S3 uploads
- Webhook dispatching for job events

**Interfaces:**
- **HTTP REST** (OpenAPI 3.0 spec at `/docs`)
  - `POST /v1/auth/login` → JWT token
  - `GET /v1/workspaces` → List workspaces
  - `POST /v1/workspaces/{ws_id}/datasets` → Create dataset
  - `POST /v1/workspaces/{ws_id}/jobs` → Submit training job
  - `GET /v1/jobs/{job_id}` → Job status
  - `POST /v1/secrets` → Store API key (writes to Vault)
  - `GET /v1/billing/usage` → Current period usage
- **Database**: Postgres (via SQLAlchemy ORM)
- **Cache**: Redis (session, rate limits, job metadata)
- **Queue**: Publishes jobs to Redis/RabbitMQ
- **Secrets**: Reads/writes via Vault HTTP API

**Tech Stack:**
- FastAPI + Pydantic v2
- SQLAlchemy 2.0 (async)
- Alembic (migrations)
- Redis (aioredis)
- HTTPX (async HTTP client)
- structlog (structured logging)

**Key Files:**
```
backend/
├── app/
│   ├── api/
│   │   ├── v1/
│   │   │   ├── auth.py
│   │   │   ├── workspaces.py
│   │   │   ├── datasets.py
│   │   │   ├── jobs.py
│   │   │   ├── secrets.py
│   │   │   └── billing.py
│   ├── core/
│   │   ├── auth.py          # JWT, RBAC
│   │   ├── config.py        # Pydantic settings
│   │   ├── db.py            # DB session
│   │   └── security.py      # Password hashing, secrets
│   ├── models/              # SQLAlchemy models
│   ├── schemas/             # Pydantic schemas
│   ├── services/            # Business logic
│   │   ├── job_service.py
│   │   ├── dataset_service.py
│   │   └── billing_service.py
│   └── main.py
└── tests/
```

#### 3. WebSocket Server (can be integrated into FastAPI)
**Responsibilities:**
- Real-time job status streaming
- Log tailing for running jobs
- Metrics push (GPU usage, ETA, loss curves)

**Interfaces:**
- **WebSocket** `/ws/jobs/{job_id}`
- **Redis Pub/Sub** (subscribe to job events)

---

### Worker & Orchestration Layer

#### 4. Job Orchestrator (Kubernetes Jobs or Celery)
**Responsibilities:**
- Pull jobs from queue
- Dispatch to appropriate worker type (ingest/train/infer)
- Manage job lifecycle (PENDING → RUNNING → SUCCEEDED/FAILED)
- Retry logic with exponential backoff (3 retries)
- Timeout enforcement (configurable per job type)
- Resource allocation (CPU/GPU/memory requests)
- Clean up on completion/failure

**Interfaces:**
- **Queue Consumer**: Redis/RabbitMQ
- **Kubernetes API**: Create/monitor Job CRDs (if K8s)
- **Database**: Update job status in Postgres
- **S3**: Read input data, write outputs

**Tech Stack (K8s approach):**
- Python controller (kopf or custom operator)
- K8s Job CRDs with pod templates
- Argo Workflows (optional, for DAG-based pipelines)

**Tech Stack (Celery approach):**
- Celery workers
- Redis broker
- Flower for monitoring

**Decision: Use Kubernetes Jobs for managed GPU cluster + standalone agent for BYO GPU**

#### 5. Ingest Worker
**Responsibilities:**
- Fetch uploaded files from S3
- Parse formats (PDF, DOCX, CSV, JSONL, TXT, MD, HTML)
- Chunking strategies:
  - Fixed-size (512/1024 tokens)
  - Recursive (respect paragraphs/sections)
  - Semantic (sentence-transformer clustering)
- PII redaction (optional, using Presidio)
- Data validation (schema checks for SFT JSONL)
- Duplicate detection (hash-based)
- Store processed chunks in S3 + metadata in Postgres

**Interfaces:**
- **Input**: Job spec from queue (dataset_id, processing config)
- **Output**: Processed dataset in S3, update dataset status
- **Libraries**: LangChain, PyMuPDF, pandas, presidio-analyzer

**Container Image**: `train-my-ai/ingest-worker:latest`

#### 6. RAG Training Worker
**Responsibilities:**
- Load processed dataset from S3
- Generate embeddings:
  - OpenAI `text-embedding-3-small/large` (via user API key)
  - HuggingFace models (local inference)
  - Cohere Embed (via API)
- Insert embeddings into pgvector with metadata
- Build retriever config (top-k, similarity threshold, reranker)
- Run eval queries (if provided):
  - Hit rate @ k
  - MRR (Mean Reciprocal Rank)
  - Latency percentiles
- Save config to MLflow (prompt templates, retriever params)
- Deploy inference endpoint

**Interfaces:**
- **Input**: Dataset + RAG config (embedding model, chunk size, top-k)
- **Output**: Vector index in pgvector, MLflow run ID, inference endpoint URL
- **External APIs**: OpenAI/HuggingFace (via secrets from Vault)

**Container Image**: `train-my-ai/rag-worker:latest`

#### 7. SFT Training Worker
**Responsibilities:**
- Load SFT dataset (JSONL with `{"prompt": ..., "completion": ...}`)
- Validate schema and tokenize
- Load base model from HuggingFace (e.g., Llama-3-8B, Mistral-7B)
- Apply LoRA/QLoRA:
  - Quantization (4-bit via bitsandbytes)
  - PEFT config (r=16, alpha=32, dropout=0.05)
  - Target modules (q_proj, v_proj)
- Training:
  - Auto-scale batch size to fit GPU VRAM
  - Gradient checkpointing
  - Mixed precision (bf16/fp16)
  - Early stopping on eval loss
- Evaluation:
  - Perplexity on holdout
  - Win-rate via pairwise LLM judge (GPT-4/Claude via user key)
  - Task-specific metrics (BLEU, ROUGE for summarization)
- Save LoRA adapters + tokenizer to S3
- Log to MLflow (hyperparams, metrics, model artifact URI)

**Interfaces:**
- **Input**: Dataset, base model ID, LoRA config, eval config
- **Output**: Adapter weights in S3, MLflow run, vLLM endpoint
- **Libraries**: Transformers, PEFT, bitsandbytes, TRL (SFTTrainer), accelerate

**Container Image**: `train-my-ai/sft-worker:latest` (CUDA 12.1, PyTorch 2.2)

#### 8. Inference Worker
**Responsibilities:**
- Serve RAG queries:
  - Embed query → search pgvector → rerank → prompt LLM
- Serve SFT models:
  - Load base model + LoRA adapter
  - vLLM for batched inference
- Endpoint API:
  - `POST /infer` with `{"query": "...", "max_tokens": 100}`
- Metrics: latency, throughput, token counts

**Interfaces:**
- **HTTP API**: Exposed via Kubernetes Service (internal) or Ingress (public)
- **Database**: pgvector for RAG retrieval
- **S3**: Load model artifacts
- **Monitoring**: Prometheus metrics

**Container Image**: `train-my-ai/inference-worker:latest` (vLLM)

---

### Data Storage Layer

#### 9. PostgreSQL Database
**Responsibilities:**
- Primary data store for all metadata
- Multi-tenant isolation via:
  - Schema-per-tenant (e.g., `tenant_<ws_id>`)
  - Row-level security (RLS) policies
- ACID transactions
- Full-text search on datasets/jobs
- Audit log retention (7 years)

**Schema Highlights** (see detailed DDL in Section 4):
- `users`, `workspaces`, `roles`, `workspace_members`
- `datasets`, `dataset_files`, `dataset_chunks`
- `jobs`, `runs`, `artifacts`
- `secrets_metadata` (actual secrets in Vault)
- `billing_usage`, `budgets`, `invoices`
- `audit_log`

**Interfaces:**
- **Protocol**: PostgreSQL wire protocol (port 5432, TLS)
- **Clients**: SQLAlchemy (Python), pgvector extension
- **Backups**: WAL archiving to S3, daily snapshots

**Config:**
- `max_connections`: 200
- `shared_buffers`: 4GB
- `work_mem`: 64MB
- Extensions: `pgvector`, `uuid-ossp`, `pg_stat_statements`

#### 10. Redis Cache
**Responsibilities:**
- Session storage (JWT blacklist for logout)
- Rate limiting counters (per workspace, per API key)
- Job queue (if using Redis as broker)
- Pub/Sub for real-time events
- Leaderboard (sorted sets for top models)

**Interfaces:**
- **Protocol**: Redis RESP (port 6379, TLS optional)
- **Clients**: aioredis (Python), ioredis (Node.js)

**Data Structures:**
- `session:{token_id}` → Hash (user_id, workspace_id, exp)
- `ratelimit:{workspace_id}:{window}` → String (counter)
- `job:{job_id}:status` → String (JSON)
- `queue:jobs:pending` → List
- `events:job:{job_id}` → Pub/Sub channel

#### 11. S3/MinIO Object Store
**Responsibilities:**
- Dataset storage (raw + processed)
- Model artifacts (adapters, tokenizers, checkpoints)
- Training logs and metrics
- 10 GB quota per workspace (enforced via bucket policies)
- Lifecycle policies (delete temp files after 7 days)
- Versioning enabled

**Bucket Structure:**
```
train-my-ai/
├── workspaces/
│   └── {workspace_id}/
│       ├── datasets/
│       │   └── {dataset_id}/
│       │       ├── raw/
│       │       └── processed/
│       ├── jobs/
│       │   └── {job_id}/
│       │       ├── logs/
│       │       ├── checkpoints/
│       │       └── outputs/
│       └── models/
│           └── {model_id}/
│               ├── adapter/
│               └── tokenizer/
```

**Interfaces:**
- **S3 API**: boto3 (Python), AWS SDK
- **Presigned URLs**: 15-minute expiry for uploads
- **Encryption**: SSE-S3 (AES-256) at rest

#### 12. pgvector (Vector Database)
**Responsibilities:**
- Store embeddings (1536-dim for OpenAI, 768-dim for HF)
- ANN search via HNSW or IVFFlat indexes
- Multi-tenant isolation (workspace_id column + index)
- Metadata filtering (e.g., date range, document type)

**Schema:**
```sql
CREATE TABLE embeddings (
    id UUID PRIMARY KEY,
    workspace_id UUID NOT NULL,
    dataset_id UUID NOT NULL,
    chunk_id UUID NOT NULL,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops)
    WHERE workspace_id = current_setting('app.workspace_id')::uuid;
```

**Justification vs. Milvus:**
| Criteria | pgvector | Milvus |
|----------|----------|--------|
| **Ops Complexity** | Low (same Postgres) | High (separate cluster) |
| **Scale** | ~10M vectors/ws | Billions |
| **Latency (p95)** | <50ms @ 1M vectors | <20ms @ 100M+ |
| **Multi-tenancy** | Native (RLS) | Manual sharding |
| **Cost** | Included in Postgres | Extra infra |
| **Decision** | **pgvector** (simpler for MVP, 10GB cap limits scale) | Use later if >50M vectors |

#### 13. MLflow (Experiment Tracking & Model Registry)
**Responsibilities:**
- Log hyperparameters, metrics, artifacts for each training run
- Model versioning (staging, production)
- Lineage tracking (dataset → job → model)
- Compare runs (A/B testing)
- Serve models via MLflow Model Serving (optional)

**Interfaces:**
- **HTTP API**: MLflow Tracking Server (port 5000)
- **Artifact Store**: S3 backend
- **Database**: Postgres (MLflow metadata tables)

**Logged Data:**
- Params: learning_rate, lora_r, batch_size, ...
- Metrics: train_loss, eval_loss, perplexity, win_rate, ...
- Artifacts: model.pth, adapter_config.json, training_args.json

#### 14. HashiCorp Vault (Secrets Management)
**Responsibilities:**
- Store API keys (OpenAI, HuggingFace, Anthropic)
- Database credentials
- Encryption keys for PII
- Auto-rotation of secrets
- Audit log of secret access

**Interfaces:**
- **HTTP API**: RESTful (port 8200, TLS)
- **Auth**: AppRole (for services), JWT (for users)

**Secret Paths:**
- `secret/workspaces/{workspace_id}/api_keys/{provider}` → `{"key": "sk-..."}`
- `secret/db/postgres` → `{"username": "...", "password": "..."}`

**Access Policy Example:**
```hcl
path "secret/workspaces/{{identity.entity.metadata.workspace_id}}/*" {
  capabilities = ["read", "create", "update"]
}
```

---

### Compute Layer

#### 15. Managed GPU Cluster (Kubernetes)
**Responsibilities:**
- Auto-scale GPU nodes (NVIDIA A10, A100)
- Fair-share scheduling (prevent one workspace from monopolizing)
- Resource quotas per workspace
- Pod preemption for high-priority jobs
- Network policies (isolate job pods)
- Node affinity for GPU types

**Tech Stack:**
- **K8s Distribution**: GKE, EKS, or AKS
- **GPU Operator**: NVIDIA GPU Operator
- **Scheduler**: Kueue or Volcano for fair-share
- **Autoscaler**: Cluster Autoscaler or Karpenter

**Node Pool Config:**
```yaml
nodePool:
  name: gpu-a10
  machineType: n1-standard-8
  accelerators:
    - type: nvidia-tesla-a10
      count: 1
  autoscaling:
    minNodes: 0
    maxNodes: 10
  taints:
    - key: nvidia.com/gpu
      value: "true"
      effect: NoSchedule
```

#### 16. BYO GPU Agent
**Responsibilities:**
- Register user's GPU hardware with platform
- Heartbeat every 30s (report VRAM, utilization, health)
- Poll job queue for assigned tasks
- Pull Docker image for job
- Run container with resource limits (cgroup, ulimit)
- Stream logs/metrics back to API
- Upload artifacts to S3 on completion
- Clean up containers and temp files

**Interfaces:**
- **Registration**: `POST /v1/gpu-nodes/register` (returns node_id, mTLS cert)
- **Heartbeat**: `POST /v1/gpu-nodes/{node_id}/heartbeat`
- **Job Polling**: `GET /v1/gpu-nodes/{node_id}/jobs/next`
- **Job Updates**: `POST /v1/jobs/{job_id}/status`
- **Log Stream**: `POST /v1/jobs/{job_id}/logs` (chunked upload)

**Tech Stack:**
- Go (for agent binary, static compilation)
- Docker/Podman (container runtime)
- mTLS (mutual TLS for authentication)
- NVIDIA Docker runtime

**Security:**
- Agent runs as non-root user
- Containers have no network access (except S3, API endpoints)
- File system mounted read-only except `/tmp`
- Secrets injected as env vars (fetched from Vault by API, passed to job)

---

### Observability & Monitoring

#### 17. Prometheus (Metrics)
**Responsibilities:**
- Scrape metrics from all services (API, workers, K8s)
- Store time-series data (15-day retention)
- Alerting rules (send to Alertmanager)

**Metrics Examples:**
- `http_requests_total{service="api", endpoint="/v1/jobs", status="200"}`
- `job_duration_seconds{workspace_id="...", job_type="sft", status="success"}`
- `gpu_utilization_percent{node="byo-gpu-123", gpu_id="0"}`
- `workspace_storage_bytes{workspace_id="..."}`

#### 18. Grafana (Dashboards)
**Responsibilities:**
- Visualize metrics from Prometheus
- Pre-built dashboards:
  - System health (API latency, error rate, DB connections)
  - Job analytics (queue depth, success rate, avg duration)
  - Cost tracking (GPU hours, storage, egress)
  - Per-workspace usage

#### 19. Loki (Logs)
**Responsibilities:**
- Centralized log aggregation
- Indexed by labels (service, workspace_id, job_id)
- Fast grep-like queries
- 30-day retention, then archive to S3

**Log Format (JSON):**
```json
{
  "timestamp": "2025-11-08T14:30:00.123+05:30",
  "level": "INFO",
  "service": "sft-worker",
  "workspace_id": "ws_abc123",
  "job_id": "job_xyz789",
  "message": "Training epoch 2/10 complete",
  "metrics": {"loss": 1.23, "lr": 0.0001}
}
```

#### 20. Jaeger (Distributed Tracing)
**Responsibilities:**
- Trace request flow (API → Queue → Worker → S3 → MLflow)
- Identify bottlenecks
- Correlate logs across services via trace_id

---

### External Integrations

#### 21. Stripe (Billing)
**Responsibilities:**
- Usage-based billing (GPU seconds, storage GB-hours, API calls)
- Invoice generation (monthly)
- Payment method management
- Budget alerts via webhooks

**Integration:**
- Meter API for usage reporting
- Subscriptions with tiered pricing
- Checkout session for payments

#### 22. Email/SMS (Alerts)
**Responsibilities:**
- Job completion notifications
- Budget threshold alerts (80%, 100%, exceeded)
- Security alerts (new API key added, unusual login)

**Providers:**
- SendGrid (email)
- Twilio (SMS)

---

## Interface Contracts Summary

| From | To | Protocol | Auth | Payload |
|------|-----|----------|------|---------|
| Frontend | API | HTTPS/REST | JWT | JSON |
| Frontend | WS Server | WebSocket | JWT | JSON |
| API | Postgres | PostgreSQL | Password | SQL |
| API | Redis | RESP | None | Commands |
| API | S3 | S3 API | IAM/STS | Objects |
| API | Vault | HTTPS | AppRole | KV |
| API | Queue | AMQP/Redis | None | Job spec |
| Worker | Queue | AMQP/Redis | None | Job spec |
| Worker | S3 | S3 API | IAM/STS | Objects |
| Worker | Postgres | PostgreSQL | Password | SQL |
| Worker | MLflow | HTTPS | None | JSON |
| Worker | External APIs | HTTPS | API Key | JSON |
| BYO Agent | API | HTTPS | mTLS | JSON |
| BYO Agent | Docker | Unix socket | None | API calls |
| Prometheus | Services | HTTP | None | Metrics |
