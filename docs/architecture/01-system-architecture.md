# Train-My-AI Platform Architecture

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL USERS                                  │
│                          (Web Browser / API Clients)                         │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │ HTTPS/TLS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            INGRESS / CDN LAYER                               │
│                     (NGINX Ingress / Cloudflare / Load Balancer)            │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌────────────────┐      ┌────────────────┐     ┌────────────────┐
│  FRONTEND APP  │      │  API GATEWAY   │     │   WEBSOCKET    │
│   (Next.js)    │      │   (FastAPI)    │     │    SERVER      │
│                │      │                │     │  (Real-time)   │
│ • File Upload  │      │ • Auth/AuthZ   │     │ • Job Status   │
│ • Workflow UI  │      │ • Rate Limit   │     │ • Log Stream   │
│ • Playground   │      │ • Validation   │     │ • Metrics      │
│ • Dashboards   │      │ • Multi-tenant │     └────────────────┘
└────────────────┘      └────────┬───────┘
                                 │
                    ┌────────────┴─────────────┐
                    │                          │
                    ▼                          ▼
        ┌───────────────────┐      ┌──────────────────┐
        │   AUTH SERVICE    │      │  CORE API SERVER │
        │                   │      │   (FastAPI)      │
        │ • JWT Issue/Ver   │      │                  │
        │ • RBAC            │      │ • Workspaces     │
        │ • Session Mgmt    │      │ • Datasets       │
        │ • API Keys        │      │ • Jobs           │
        └────────┬──────────┘      │ • Artifacts      │
                 │                 │ • Billing        │
                 │                 └────────┬─────────┘
                 │                          │
                 └──────────┬───────────────┘
                            │
        ┌───────────────────┼──────────────────────────────────┐
        │                   │                                  │
        ▼                   ▼                                  ▼
┌──────────────┐   ┌────────────────┐              ┌──────────────────┐
│  POSTGRES    │   │  REDIS CACHE   │              │  MESSAGE QUEUE   │
│              │   │                │              │  (Redis/RabbitMQ)│
│ • Users      │   │ • Session      │              │                  │
│ • Workspaces │   │ • Rate Limit   │              │ • Job Queue      │
│ • Datasets   │   │ • Job Status   │              │ • Event Bus      │
│ • Jobs       │   │ • Leaderboard  │              │ • Dead Letter    │
│ • Billing    │   └────────────────┘              └────────┬─────────┘
│ • Audit Log  │                                            │
└──────┬───────┘                                            │
       │                                                    │
       │ Row-Level Security                                 │
       │ + Schema Isolation                                 │
       │                                                    │
       └────────────────────────────────────────────────────┤
                                                            │
                            ┌───────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────────────────────────┐
        │                    WORKER ORCHESTRATION                    │
        │                  (Kubernetes Job Controller)               │
        │                                                            │
        │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
        │  │ INGEST       │  │ TRAINING     │  │ INFERENCE    │   │
        │  │ WORKERS      │  │ WORKERS      │  │ WORKERS      │   │
        │  │              │  │              │  │              │   │
        │  │ • Chunking   │  │ • RAG Build  │  │ • Model Serve│   │
        │  │ • Validation │  │ • SFT/LoRA   │  │ • Embedding  │   │
        │  │ • Transform  │  │ • Eval       │  │ • Retrieval  │   │
        │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
        └─────────┼──────────────────┼──────────────────┼───────────┘
                  │                  │                  │
                  └────────┬─────────┴──────────┬───────┘
                           │                    │
          ┌────────────────┼────────────────────┼─────────────────┐
          │                │                    │                 │
          ▼                ▼                    ▼                 ▼
  ┌──────────────┐  ┌─────────────┐   ┌─────────────┐   ┌──────────────┐
  │  S3/MinIO    │  │ VECTOR DB   │   │   MLflow    │   │ SECRETS VAULT│
  │              │  │ (pgvector)  │   │             │   │ (HashiCorp   │
  │ • Datasets   │  │             │   │ • Models    │   │  Vault)      │
  │ • Models     │  │ • Embeddings│   │ • Metrics   │   │              │
  │ • Artifacts  │  │ • Metadata  │   │ • Artifacts │   │ • API Keys   │
  │ • Logs       │  │ • Multi-ten │   │ • Lineage   │   │ • Creds      │
  └──────────────┘  └─────────────┘   └─────────────┘   │ • Enc Keys   │
                                                         └──────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPUTE ORCHESTRATION                                │
├──────────────────────────────────┬──────────────────────────────────────────┤
│    MANAGED GPU CLUSTER           │        BYO GPU (User's Hardware)         │
│                                  │                                          │
│  ┌────────────────────────────┐  │  ┌────────────────────────────────────┐ │
│  │  Kubernetes GPU Nodes      │  │  │  GPU Agent (Go/Python Daemon)      │ │
│  │                            │  │  │                                    │ │
│  │  • NVIDIA Runtime          │  │  │  • Heartbeat                       │ │
│  │  • Fair-share Scheduler    │  │  │  • Job Poller                      │ │
│  │  • Auto-scaling            │  │  │  • Docker/Podman Runner            │ │
│  │  • Resource Quotas         │  │  │  • Log/Metrics Streamer            │ │
│  │  • Network Policies        │  │  │  • Quota Enforcer                  │ │
│  │                            │  │  │  • SSH Tunnel (optional)           │ │
│  │  ┌──────┐  ┌──────┐       │  │  │                                    │ │
│  │  │ GPU1 │  │ GPU2 │  ...  │  │  │  Connects via mTLS to Job Queue    │ │
│  │  └──────┘  └──────┘       │  │  │                                    │ │
│  └────────────────────────────┘  │  └────────────────────────────────────┘ │
│                                  │                                          │
│  Jobs: K8s Job CRDs             │  Jobs: Pulled as Docker images           │
└──────────────────────────────────┴──────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        OBSERVABILITY & MONITORING                            │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Prometheus   │  │ Grafana      │  │ Loki/ES      │  │ Jaeger       │   │
│  │ (Metrics)    │  │ (Dashboards) │  │ (Logs)       │  │ (Traces)     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                                              │
│  • Per-job metrics   • Cost tracking   • Audit trail   • Performance trace │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        EXTERNAL INTEGRATIONS                                 │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Stripe       │  │ HuggingFace  │  │ OpenAI       │  │ Email/SMS    │   │
│  │ (Billing)    │  │ (Models)     │  │ (Embed/LLM)  │  │ (Alerts)     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### A. Ingestion Flow
```
User Upload → API → Validation → S3 → Queue → Ingest Worker
                                                    │
                                    ┌───────────────┴──────────────┐
                                    ▼                              ▼
                              Chunking/Clean              Store Metadata
                                    │                              │
                                    ▼                              ▼
                              Process Queue                    Postgres
```

### B. RAG Training Flow
```
Dataset → Worker → Embedding (OpenAI/HF) → pgvector → Build Retriever
                                                            │
                                                            ▼
                                                    Test Queries → Eval
                                                            │
                                                            ▼
                                                    Save Config → MLflow
                                                            │
                                                            ▼
                                                    Deploy Endpoint
```

### C. SFT Training Flow
```
Dataset → Validation → Worker → LoRA/QLoRA Training → Checkpoints → S3
                                        │
                                        ├─► Eval on Holdout
                                        │
                                        └─► Metrics → MLflow
                                                │
                                                ▼
                                        Adapter + Tokenizer → Registry
                                                │
                                                ▼
                                        Deploy vLLM Endpoint
```

### D. BYO GPU Flow
```
User GPU Machine → Install Agent → Register (mTLS) → Heartbeat
                                                          │
                                    Job Queue ←───────────┘
                                        │
                                        ▼
                            Pull Job Spec + Docker Image
                                        │
                                        ▼
                            Run Container (Resource-Limited)
                                        │
                            ┌───────────┴───────────┐
                            ▼                       ▼
                    Stream Logs/Metrics     Report Progress
                            │                       │
                            └───────────┬───────────┘
                                        ▼
                                Upload Artifacts → S3
                                        │
                                        ▼
                                Mark Job Complete
```

## Network Security Zones

```
┌─────────────────────────────────────────────────────────────┐
│ DMZ (Public Internet)                                        │
│   • CDN / Ingress (HTTPS only)                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ Firewall
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Application Zone (VPC - 10.0.0.0/16)                        │
│   • Frontend (10.0.1.0/24)                                  │
│   • API Gateway (10.0.2.0/24)                               │
│   • No direct DB access                                     │
└─────────────────────┬───────────────────────────────────────┘
                      │ Network Policy
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Service Zone (VPC - 10.0.0.0/16)                            │
│   • Workers (10.0.10.0/24)                                  │
│   • Only API → Worker, Worker → Data                        │
└─────────────────────┬───────────────────────────────────────┘
                      │ Network Policy (Strict)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Data Zone (VPC - 10.0.0.0/16)                               │
│   • Postgres (10.0.20.0/24)                                 │
│   • Redis (10.0.21.0/24)                                    │
│   • No public IPs, private DNS only                         │
└─────────────────────────────────────────────────────────────┘
                      │ Private Link
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Storage Zone (Object Storage Network)                       │
│   • S3/MinIO (private endpoints)                            │
│   • Encrypted at rest (AES-256)                             │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Topology

**Production**: 3 AZs, replicated DBs, multi-region object store, managed K8s
**Staging**: 1 AZ, smaller node pools, shared resources
**Dev**: Local k3d/kind, MinIO, Postgres containers
