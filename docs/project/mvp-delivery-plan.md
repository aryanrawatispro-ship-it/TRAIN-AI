# MVP Delivery Plan

## 12. 3-Week Phased Implementation Plan

### Team Composition
- **Tech Lead** (1): Architecture, code review, DevOps
- **Backend Engineer** (2): API, workers, database
- **Frontend Engineer** (1): Next.js UI
- **ML Engineer** (1): Training pipelines, RAG/SFT
- **DevOps Engineer** (1): K8s, monitoring, CI/CD

---

## Week 1: Foundation & Core Infrastructure

### Sprint Goal
Set up infrastructure, database, auth, and basic API

### Tasks

#### Day 1-2: Infrastructure Setup
- [ ] **DevOps Lead** (Owner: DevOps Engineer)
  - Set up GCP/AWS project with Terraform
  - Provision K8s cluster (GKE/EKS) with 3 nodes
  - Deploy Postgres (Cloud SQL or RDS)
  - Deploy Redis (ElastiCache or GKE)
  - Set up S3/MinIO for object storage
  - **Acceptance**: `kubectl get nodes` shows 3 ready nodes
  - **Time**: 16 hours

#### Day 2-3: Database Schema
- [ ] **Database Implementation** (Owner: Backend Eng #1)
  - Run schema.sql DDL to create all tables
  - Set up Alembic for migrations
  - Seed roles and demo user
  - Write DB connection pooling (SQLAlchemy)
  - **Acceptance**: `SELECT * FROM users` returns demo user
  - **Time**: 12 hours

#### Day 3-4: Authentication & API Foundation
- [ ] **Auth System** (Owner: Backend Eng #2)
  - Implement JWT token generation/validation
  - `/v1/auth/signup` and `/v1/auth/login` endpoints
  - Password hashing with bcrypt
  - RBAC middleware (check workspace membership)
  - **Acceptance**: Postman collection successfully logs in
  - **Time**: 12 hours

- [ ] **FastAPI Skeleton** (Owner: Backend Eng #1)
  - Project structure (routers, services, models)
  - CORS, logging, error handlers
  - Health check endpoints
  - Prometheus metrics middleware
  - **Acceptance**: `/health` returns 200, `/docs` shows OpenAPI
  - **Time**: 8 hours

#### Day 4-5: Frontend Foundation
- [ ] **Next.js Setup** (Owner: Frontend Engineer)
  - Create Next.js 14 app with TypeScript
  - Set up TailwindCSS + shadcn/ui
  - Auth pages (login, signup)
  - API client with JWT handling
  - Protected route wrapper
  - **Acceptance**: Login flow works end-to-end
  - **Time**: 12 hours

#### Day 5: Deployment Pipeline
- [ ] **CI/CD** (Owner: DevOps Engineer)
  - GitHub Actions workflows
    - Lint, test, build on PR
    - Build Docker images on merge
    - Deploy to K8s (staging)
  - Helm chart v1 (API, frontend, postgres, redis)
  - **Acceptance**: PR triggers CI, merge deploys to staging
  - **Time**: 8 hours

**Week 1 Milestone**: Auth works, API deployed, database ready

---

## Week 2: Core Features (Dataset Upload, Jobs, RAG)

### Sprint Goal
Users can upload data, start RAG training, view results

### Tasks

#### Day 6-7: Workspace & Dataset Management
- [ ] **Workspace API** (Owner: Backend Eng #1)
  - `POST /v1/workspaces` (create)
  - `GET /v1/workspaces` (list for user)
  - `GET /v1/workspaces/{id}` (details)
  - Enforce 10 GB storage limit
  - **Acceptance**: User can create workspace via API
  - **Time**: 8 hours

- [ ] **Dataset Upload** (Owner: Backend Eng #2)
  - `POST /v1/workspaces/{id}/datasets` (get presigned URLs)
  - S3 presigned URL generation (15-min expiry)
  - Upload completion webhook
  - Dataset status tracking (UPLOADING → READY)
  - **Acceptance**: Upload 100 MB file via presigned URL
  - **Time**: 12 hours

- [ ] **Frontend: Workspace UI** (Owner: Frontend Engineer)
  - Dashboard showing workspaces
  - Create workspace modal
  - Storage usage gauge
  - **Acceptance**: User can create workspace and see storage
  - **Time**: 8 hours

#### Day 8-9: Dataset Processing (Ingest Worker)
- [ ] **Ingest Worker** (Owner: ML Engineer)
  - Parse PDF, TXT, CSV, JSONL files
  - Chunking (fixed 512 tokens with 50 overlap)
  - Store chunks in dataset_chunks table
  - Update dataset status to READY
  - **Acceptance**: Upload PDF, chunks appear in DB
  - **Time**: 12 hours

- [ ] **Job Queue** (Owner: Backend Eng #1)
  - Redis queue implementation
  - `POST /v1/workspaces/{id}/jobs` (create job)
  - Job state machine (PENDING → QUEUED → RUNNING)
  - K8s Job CRD creation
  - **Acceptance**: Job submitted, appears in queue
  - **Time**: 12 hours

- [ ] **Frontend: Dataset Upload UI** (Owner: Frontend Engineer)
  - File upload with progress bar (tus.js)
  - Dataset list view
  - Processing status indicator
  - **Acceptance**: User uploads file, sees progress
  - **Time**: 12 hours

#### Day 10-11: RAG Training Pipeline
- [ ] **RAG Worker** (Owner: ML Engineer)
  - Implement rag_trainer.py
  - OpenAI embedding integration
  - Store embeddings in pgvector
  - MLflow logging
  - **Acceptance**: RAG job completes, embeddings in DB
  - **Time**: 16 hours

- [ ] **Secrets Management** (Owner: Backend Eng #2)
  - Deploy HashiCorp Vault (dev mode for now)
  - `POST /v1/secrets` endpoint
  - Fetch secrets for job execution
  - Inject as env vars in K8s Job
  - **Acceptance**: OpenAI key stored, used in RAG job
  - **Time**: 8 hours

- [ ] **Frontend: Job Creation & Monitoring** (Owner: Frontend Engineer)
  - "Train Model" wizard (select dataset, config)
  - Job list view
  - Job detail page with logs (mock for now)
  - **Acceptance**: User starts RAG job from UI
  - **Time**: 12 hours

#### Day 12: Integration Testing
- [ ] **End-to-End Test** (Owner: Tech Lead)
  - Playwright test: signup → create workspace → upload dataset → start RAG job
  - Verify job completes successfully
  - Check embeddings in pgvector
  - **Acceptance**: E2E test passes
  - **Time**: 8 hours

**Week 2 Milestone**: Full RAG workflow works (upload → process → train → embeddings)

---

## Week 3: SFT, Inference, Polish

### Sprint Goal
SFT training works, inference endpoints deployed, MVP ready for alpha users

### Tasks

#### Day 13-14: SFT Training
- [ ] **SFT Worker** (Owner: ML Engineer)
  - Implement sft_trainer.py
  - LoRA/QLoRA configuration
  - Train on JSONL dataset
  - Save adapters to S3
  - MLflow logging
  - **Acceptance**: SFT job trains Llama-3-8B, saves LoRA
  - **Time**: 16 hours

- [ ] **Frontend: SFT Workflow** (Owner: Frontend Engineer)
  - SFT config form (base model, LoRA params, epochs)
  - Dataset schema validation (prompt/completion)
  - **Acceptance**: User starts SFT job
  - **Time**: 8 hours

#### Day 15-16: Inference Endpoints
- [ ] **Inference Worker** (Owner: ML Engineer)
  - Deploy vLLM server in K8s
  - Load RAG model (embeddings + LLM)
  - Load SFT model (base + LoRA adapter)
  - `POST /v1/models/{id}/infer` endpoint
  - **Acceptance**: Query RAG model, get response
  - **Time**: 16 hours

- [ ] **Model Deployment** (Owner: Backend Eng #1)
  - `POST /v1/models/{id}/deploy` endpoint
  - Create K8s Deployment for vLLM
  - Track deployment status
  - **Acceptance**: Model deployed, inference works
  - **Time**: 12 hours

- [ ] **Frontend: Playground** (Owner: Frontend Engineer)
  - Chat interface for deployed models
  - Query input, streaming response
  - Show retrieved sources (for RAG)
  - **Acceptance**: User chats with deployed model
  - **Time**: 12 hours

#### Day 17: Billing & Monitoring
- [ ] **Usage Tracking** (Owner: Backend Eng #2)
  - Record GPU seconds in usage_events table
  - Update workspace.budget_used_usd
  - Budget limit enforcement
  - **Acceptance**: Job logs usage, budget updated
  - **Time**: 8 hours

- [ ] **Monitoring** (Owner: DevOps Engineer)
  - Deploy Prometheus + Grafana
  - System health dashboard (API latency, error rate)
  - Job analytics dashboard (queue depth, duration)
  - Alerts (high error rate, job failures)
  - **Acceptance**: Dashboards show live data
  - **Time**: 12 hours

- [ ] **Frontend: Billing Page** (Owner: Frontend Engineer)
  - Show current usage (GPU hours, storage)
  - Budget gauge
  - Usage history chart
  - **Acceptance**: User sees current month usage
  - **Time**: 8 hours

#### Day 18: BYO GPU Agent (MVP)
- [ ] **GPU Agent** (Owner: Backend Eng #2)
  - Compile Go agent binary
  - Registration endpoint
  - Heartbeat + job polling
  - Docker execution
  - **Acceptance**: Agent registers, runs a test job
  - **Time**: 12 hours

- [ ] **Frontend: GPU Node Management** (Owner: Frontend Engineer)
  - Register GPU node page
  - Download agent + certs
  - Node status dashboard
  - **Acceptance**: User registers BYO GPU
  - **Time**: 6 hours

#### Day 19-20: Testing & Bug Fixes
- [ ] **Load Testing** (Owner: DevOps Engineer)
  - k6 load test (100 concurrent users)
  - Identify bottlenecks (DB connections, API rate limits)
  - Tune autoscalers
  - **Acceptance**: System handles 100 req/s
  - **Time**: 8 hours

- [ ] **Security Audit** (Owner: Tech Lead)
  - Run OWASP ZAP scan
  - Check for SQL injection, XSS
  - Verify secrets not logged
  - Test multi-tenancy (can't access other workspace)
  - **Acceptance**: No critical vulnerabilities
  - **Time**: 8 hours

- [ ] **Bug Bash** (Owner: All)
  - Each team member tests full workflow
  - Log bugs in Linear/Jira
  - Fix P0/P1 bugs
  - **Acceptance**: No blocking bugs
  - **Time**: 16 hours (team-wide)

#### Day 21: Documentation & Launch Prep
- [ ] **User Documentation** (Owner: Frontend Engineer)
  - Getting started guide
  - Video tutorial (5 min)
  - API reference (auto-generated from OpenAPI)
  - **Acceptance**: New user can follow docs
  - **Time**: 8 hours

- [ ] **Deployment to Production** (Owner: DevOps Engineer)
  - Provision production K8s cluster
  - Deploy with Helm (values-prod.yaml)
  - Set up DNS (app.train-my-ai.com, api.train-my-ai.com)
  - SSL certs via Let's Encrypt
  - **Acceptance**: Production live, HTTPS working
  - **Time**: 8 hours

- [ ] **Alpha Launch** (Owner: Tech Lead)
  - Invite 50 alpha testers
  - Send onboarding email
  - Set up support channel (Discord)
  - Monitor logs for errors
  - **Acceptance**: 10 users complete RAG workflow
  - **Time**: Ongoing

**Week 3 Milestone**: MVP live in production, alpha users testing

---

## Post-MVP Roadmap (Next 3 months)

### Month 2
- Public beta launch (1,000 users)
- Stripe billing integration
- Advanced RAG (rerankers, hybrid search)
- Model fine-tuning for specific tasks (summarization, QA)

### Month 3
- Enterprise features (SSO, private VPC)
- Workflow automation (trigger training on new data)
- Model marketplace (share/sell models)
- Mobile app (iOS/Android)

### Month 4
- Scale to 10,000 users
- Multi-region deployment (EU, APAC)
- Advanced observability (distributed tracing)
- AI-powered cost optimization

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Postgres bottleneck at scale | Medium | High | Use read replicas, pgbouncer pooling |
| GPU spot instances terminated mid-job | High | Medium | Checkpointing every 10 min, auto-resume |
| OpenAI rate limits hit | Medium | Medium | Batch embeddings, retry with backoff |
| Security vulnerability | Low | Critical | Weekly Snyk scans, penetration testing |
| Team member leaves | Low | High | Document everything, pair programming |

---

## Success Criteria (End of Week 3)

- [ ] 10 alpha users complete full workflow (upload → train → deploy → infer)
- [ ] System uptime > 99% (max 1 hour downtime)
- [ ] P95 API latency < 500ms
- [ ] No P0 bugs, < 5 P1 bugs
- [ ] All tests passing (unit, integration, E2E)
- [ ] Documentation complete
- [ ] Production monitoring dashboards live

---

## Daily Standup Format (15 min, 9 AM IST)

1. **What did you ship yesterday?**
2. **What will you ship today?**
3. **Blockers?**

## Weekly Demo (Friday, 4 PM IST)

- Each engineer demos what they built
- Stakeholders provide feedback
- Adjust priorities for next week
