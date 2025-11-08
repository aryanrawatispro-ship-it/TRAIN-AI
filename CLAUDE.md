You are a senior full-stack architect + MLOps lead. Design and scaffold a no-code “Train-My-AI” platform where non-developers can bring data (≤10 GB per workspace) and optionally their own GPUs to auto-train/fine-tune models. Produce concrete outputs and runnable scaffolds.

## Mission
Create a secure, multi-tenant web app where users:
1) Upload/ingest data (docs, CSV/JSONL, websites/APIs) up to 10 GB.
2) Choose training mode:
   - RAG (build embeddings + retrieval + prompt orchestration)
   - Supervised fine-tuning (SFT) via parameter-efficient methods (LoRA/QLoRA) on open models (e.g., Llama/Mistral).
3) Provide API keys (OpenAI/Anthropic/HF/etc.) stored securely and scoped to their jobs.
4) Choose compute:
   - “Use my GPU”: connect a BYO GPU runner (SSH or agent daemon) for isolated jobs.
   - “Use provider GPU”: schedule on our managed cluster.
5) Click “Train”. Platform auto-validates data, chooses defaults, runs training/eval, versions artefacts, and exposes a simple “Use model” endpoint and playground.
6) See costs/usage in real time; set budget caps.

## Non-negotiable constraints
- Per-workspace storage cap: 10 GB hard limit with clear UI meter.
- Multi-tenant isolation: one tenant must never access another’s data/secrets/compute.
- Security: 
  - Secrets in a dedicated vault/KMS; never log secrets.
  - Data at rest encrypted; in transit TLS.
  - Per-job ephemeral containers; network-policy sandboxing.
- Compliance by design: audit logs for uploads, training, inference, secret access.
- Cost controls: metering (GPU hours, storage, egress), budgets, alerts, job pre-checks.
- Observability: structured logs, traces, metrics, per-run dashboards.

## Preferred reference stack (offer well-reasoned alternatives if you diverge)
- Frontend: Next.js + TypeScript; file uploads with resumable chunks; clean no-code workflow UI.
- Backend/API: Python FastAPI.
- Workers/Orchestration: Kubernetes Jobs (or Celery/K8s), queue (Redis/RabbitMQ).
- DB: Postgres (tenancy via schema + row-level security).
- Object store: S3-compatible (e.g., MinIO) for datasets/artifacts.
- Vector DB: pgvector or Milvus (justify choice).
- Model tooling: Hugging Face + bitsandbytes + PEFT for LoRA; Transformers + vLLM/TGI for serving.
- Experiment tracking & model registry: MLflow or Weights & Biases (pick one, justify).
- BYO GPU: lightweight agent (Go/Python) that registers node capacity, polls for jobs, runs containers via Docker/Podman, streams logs/metrics, enforces quotas.
- Managed GPU: K8s node pool with NVIDIA runtime + fair-share queue.
- Payments: usage-based billing (e.g., Stripe), per-workspace budgets & alerts.

## Data & training pipeline requirements
- Ingestion connectors: file uploads (zip, PDF, txt, md, csv, jsonl), URLs/site crawl, S3/GCS/Drive; show how each becomes a uniform Dataset spec.
- Pre-processing:
  - Text clean/normalize; optional PII redaction; chunking for RAG; JSONL schema for SFT.
  - Dataset validation (schema, size, duplicates).
- Training choices:
  - RAG: embed (OpenAI, HF, or local), store in Vector DB, build retriever, prompt templates, reranker option.
  - SFT: LoRA/QLoRA config with autoscaled batch size, early stopping; GPU/VRAM auto-fit; mixed precision; gradient checkpointing.
- Evaluation:
  - RAG: retrieval hit-rate, MRR, latency; light QA set; hallucination heuristics.
  - SFT: held-out eval, win-rate via pairwise judge (configurable with user's key), perplexity, exact-match/F1 when applicable.
- Output:
  - Versioned artefacts (model adapters, tokenizer, prompts), inference endpoint, and web playground.

## Deliverables (REQUIRED – provide all in this response)
1) High-level architecture diagram (ASCII) labeling user/ingest/core/train/serve/BYO GPU/managed GPU/data stores.
2) Component list with responsibilities & interfaces (bullet points).
3) API spec (OpenAPI-style) for key routes:
   - Auth, workspaces, uploads, datasets, jobs (train/eval/infer), secrets, billing, BYO GPU node register/heartbeat/accept-job/report-metrics.
4) Postgres schema (DDL) covering: users, workspaces, roles, datasets, dataset_files, secrets (pointer to vault), jobs, runs, artefacts, billing_usage, budgets, audit_log.
5) Queue/job schemas; state machine for job lifecycle (PENDING→RUNNING→SUCCEEDED/FAILED/CANCELLED with retries/backoff).
6) K8s manifests or Helm outline for:
   - API, worker, vector DB, object store, GPU node pool, network policies, autoscalers, PodSecurity, resource quotas.
7) BYO GPU agent:
   - Minimal spec + code sketch (CLI flags, auth, job protocol, logs/metrics streaming).
8) Training templates:
   - RAG pipeline pseudocode and SFT (LoRA/QLoRA) training script skeleton with sane defaults and override knobs.
9) Observability:
   - Logging/tracing layout, key dashboards, example alerts (budget overrun, OOM, GPU queue saturation).
10) Security & threat model:
   - Tenant escape, secret exfiltration, prompt injection in data, supply-chain risks; mitigations.
11) Pricing/Cost model:
   - Example unit economics; how metering rolls up to invoices; budget guardrails.
12) MVP delivery plan:
   - 3-week phased plan with tasks, owners, and acceptance criteria.
13) “Golden path” UX:
   - Step-by-step user flow (upload → choose mode → compute choice → train → eval → deploy → consume), with 3 minimal wireframe sketches (ASCII).

## Guardrails for your response
- Be decisive: pick defaults and justify briefly.
- Keep code snippets concise but runnable or near-runnable.
- No filler; focus on actionable detail over theory.
- Assume timezone Asia/Kolkata for timestamps in examples.
- If trade-offs exist (e.g., pgvector vs Milvus), present a quick table of 3–5 decisive criteria and choose one.
- Output should be directly usable by an engineering team to start building TODAY.

First task: produce all 13 deliverables with the concrete stack above, then propose a minimal repo structure and include a Makefile with targets: `dev-up`, `dev-down`, `api`, `worker`, `seed`, `run-rag-demo`, `run-sft-demo`.
