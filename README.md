# Train-My-AI Platform

> No-code AI training platform with **10+ LLM providers**, RAG, fine-tuning, and BYO GPU support

## Overview

Train-My-AI is a multi-tenant SaaS platform that enables non-developers to:

### 🤖 **Universal LLM Access** (NEW!)
- **10+ providers**: OpenAI, Claude, DeepSeek, GLM, Gemini, Groq, Cohere, Mistral, and more
- **Smart routing**: Auto-select cheapest/fastest/best provider per request
- **Cost savings**: Use DeepSeek at $0.14/1M tokens (70x cheaper than GPT-4)
- **Speed**: Groq delivers 750+ tokens/sec for real-time chat

### 🧠 Train Your Own Models
- Upload data (documents, CSV, JSONL) up to 10 GB per workspace
- Train AI models via two modes:
  - **RAG** (Retrieval-Augmented Generation): Build Q&A systems with document retrieval
  - **SFT** (Supervised Fine-Tuning): Fine-tune LLMs with LoRA/QLoRA
- Choose compute: Use our managed GPUs or bring your own hardware
- Deploy inference endpoints with a simple playground UI

### 💰 Cost Control
- Track costs across all providers in real-time
- Set budget limits per workspace
- Compare pricing across 40+ models instantly
- **Example**: Save $5,958/month switching from GPT-4 to DeepSeek

## Repository Structure

```
train-my-ai/
├── backend/                  # FastAPI application
│   ├── app/
│   │   ├── api/              # API routes (v1)
│   │   │   ├── auth.py
│   │   │   ├── workspaces.py
│   │   │   ├── datasets.py
│   │   │   ├── jobs.py
│   │   │   ├── models.py
│   │   │   ├── secrets.py
│   │   │   └── billing.py
│   │   ├── core/             # Core utilities
│   │   │   ├── config.py
│   │   │   ├── auth.py
│   │   │   ├── db.py
│   │   │   └── security.py
│   │   ├── models/           # SQLAlchemy models
│   │   ├── schemas/          # Pydantic schemas
│   │   ├── services/         # Business logic
│   │   └── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── tests/
│
├── frontend/                 # Next.js application
│   ├── app/                  # App router
│   │   ├── (auth)/
│   │   │   ├── login/
│   │   │   └── signup/
│   │   ├── (dashboard)/
│   │   │   ├── workspaces/
│   │   │   ├── datasets/
│   │   │   ├── jobs/
│   │   │   ├── models/
│   │   │   ├── playground/
│   │   │   └── billing/
│   │   └── api/
│   ├── components/
│   ├── lib/
│   ├── package.json
│   ├── Dockerfile
│   └── next.config.js
│
├── workers/                  # Training workers
│   ├── ingest_worker.py
│   ├── rag_trainer.py
│   ├── sft_trainer.py
│   ├── inference_worker.py
│   ├── requirements.txt
│   └── Dockerfiles/
│       ├── ingest.Dockerfile
│       ├── rag.Dockerfile
│       └── sft.Dockerfile
│
├── gpu-agent/                # BYO GPU agent (Go)
│   ├── main.go
│   ├── go.mod
│   ├── go.sum
│   ├── Dockerfile
│   └── README.md
│
├── docs/                     # Documentation
│   ├── architecture/
│   │   ├── 01-system-architecture.md
│   │   ├── 02-component-specifications.md
│   │   └── 05-job-orchestration.md
│   ├── api/
│   │   └── openapi-spec.yaml
│   ├── database/
│   │   └── schema.sql
│   ├── deployment/
│   │   └── helm-chart-outline.md
│   ├── security/
│   │   └── threat-model.md
│   ├── observability/
│   │   └── monitoring-setup.md
│   ├── business/
│   │   └── pricing-model.md
│   ├── project/
│   │   └── mvp-delivery-plan.md
│   └── ux/
│       └── golden-path-wireframes.md
│
├── helm/                     # Helm charts
│   └── train-my-ai/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-prod.yaml
│       └── templates/
│
├── scripts/                  # Utility scripts
│   ├── seed_db.py
│   ├── run_migrations.sh
│   └── generate_certs.sh
│
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── deploy-staging.yml
│       └── deploy-prod.yml
│
├── Makefile                  # Development commands
├── docker-compose.yml        # Local development
├── .env.example
├── CLAUDE.md                 # Project instructions
└── README.md
```

## ✨ Key Features

### 🌐 Universal LLM Provider Support
- **10+ Providers**: OpenAI, Anthropic (Claude), DeepSeek, Zhipu AI (GLM), Google Gemini, Groq, Cohere, Mistral, Together AI, Local vLLM
- **40+ Models**: From GPT-4 to ultra-cheap DeepSeek ($0.14/1M tokens)
- **Smart Routing**: Auto-select cheapest, fastest, or highest quality provider
- **Cost Optimization**: Save up to 95% by switching providers
- **Provider Catalog**: Compare pricing, features, and performance instantly

### 🎯 Training Modes
- **RAG (Retrieval-Augmented Generation)**: Build document Q&A systems with embeddings
- **SFT (Supervised Fine-Tuning)**: Fine-tune LLMs with LoRA/QLoRA on custom data
- **Multi-Provider Embeddings**: OpenAI, Cohere, Voyage, Jina, Google, local models

### 💻 Flexible Compute
- **Managed GPU**: A10, A100, T4 instances with auto-scaling
- **BYO GPU**: Bring your own hardware (95% cheaper)
- **Hybrid**: Mix managed and BYO for cost optimization

### 📊 Cost Intelligence
- **Real-time tracking**: See costs per provider, model, and job
- **Budget limits**: Auto-stop jobs when limit reached
- **Cost comparison**: Compare 40+ models side-by-side
- **Provider recommendations**: Get suggestions for your use case

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Make
- Node.js 18+ (for frontend development)
- Python 3.11+ (for backend development)

### Local Development

```bash
# 1. Clone repository
git clone https://github.com/train-my-ai/platform.git
cd platform

# 2. Copy environment file
cp .env.example .env
# Edit .env with your configuration

# 3. Start all services
make dev-up

# 4. Access services
# Frontend: http://localhost:3000
# API: http://localhost:8000
# API Docs: http://localhost:8000/docs
# Grafana: http://localhost:3001 (admin/admin)
# MLflow: http://localhost:5000
```

### Run Demos

```bash
# RAG demo (upload docs, train, query)
make run-rag-demo

# SFT demo (fine-tune Llama-3)
make run-sft-demo
```

## Makefile Targets

See `Makefile` for all available commands:

```bash
make dev-up          # Start all services (Docker Compose)
make dev-down        # Stop all services
make api             # Run API server (hot reload)
make worker          # Run job worker
make seed            # Seed database with demo data
make test            # Run all tests
make lint            # Run linters (ruff, eslint)
make migrate         # Run database migrations
make run-rag-demo    # Execute RAG workflow demo
make run-sft-demo    # Execute SFT workflow demo
```

## Key Technologies

### Backend
- **FastAPI** (Python) - API server
- **SQLAlchemy** - ORM
- **Alembic** - Database migrations
- **Redis** - Job queue & cache
- **Celery** - Alternative worker orchestration

### Frontend
- **Next.js 14** (TypeScript) - React framework
- **TailwindCSS** - Styling
- **shadcn/ui** - Component library
- **React Query** - Data fetching
- **tus.js** - Resumable file uploads

### Data & ML
- **PostgreSQL** (pgvector) - Database & vector store
- **MLflow** - Experiment tracking
- **HuggingFace Transformers** - Model training
- **PEFT** (LoRA/QLoRA) - Parameter-efficient fine-tuning
- **vLLM** - Inference serving
- **Sentence Transformers** - Embeddings

### Infrastructure
- **Kubernetes** - Container orchestration
- **Helm** - K8s package manager
- **Prometheus** - Metrics
- **Grafana** - Dashboards
- **Loki** - Logs
- **Jaeger** - Distributed tracing
- **HashiCorp Vault** - Secrets management

## Documentation

### 🎯 Quick Start Guides
| Document | Description |
|----------|-------------|
| [Multi-Provider Guide](docs/features/multi-provider-guide.md) | **10+ LLM providers, cost comparison, smart routing** |
| [API Spec](docs/api/openapi-spec.yaml) | OpenAPI 3.0 specification for all endpoints |
| [Getting Started](docs/ux/golden-path-wireframes.md) | User journey with wireframes |

### 🏗️ Architecture
| Document | Description |
|----------|-------------|
| [System Architecture](docs/architecture/01-system-architecture.md) | System design, data flows, network topology |
| [Components](docs/architecture/02-component-specifications.md) | Component responsibilities & interfaces |
| [Multi-Provider LLMs](docs/architecture/06-multi-provider-llms.md) | **Provider abstraction, smart routing, fallback** |
| [Job Orchestration](docs/architecture/05-job-orchestration.md) | Queue schemas, state machine, retry logic |
| [Database Schema](docs/database/schema.sql) | PostgreSQL DDL with RLS |

### 🚀 Deployment & Operations
| Document | Description |
|----------|-------------|
| [Deployment](docs/deployment/helm-chart-outline.md) | Helm chart, K8s manifests, network policies |
| [GPU Agent](gpu-agent/README.md) | BYO GPU agent installation & usage |
| [Observability](docs/observability/monitoring-setup.md) | Metrics, logs, traces, dashboards, alerts |
| [Security](docs/security/threat-model.md) | Threat model, mitigations, compliance |

### 💼 Business
| Document | Description |
|----------|-------------|
| [Pricing Model](docs/business/pricing-model.md) | Unit economics, billing workflow |
| [MVP Plan](docs/project/mvp-delivery-plan.md) | 3-week delivery plan with tasks |

## Deployment

### Staging

```bash
# Deploy to staging cluster
make deploy-staging
```

### Production

```bash
# Deploy to production (requires approval)
make deploy-prod
```

### Helm

```bash
# Install via Helm
helm install train-my-ai ./helm/train-my-ai \
  --namespace train-my-ai \
  --create-namespace \
  --values helm/train-my-ai/values-prod.yaml
```

## Environment Variables

See `.env.example` for all required variables:

```bash
# Database
POSTGRES_HOST=localhost
POSTGRES_DB=trainmyai
POSTGRES_USER=trainmyai
POSTGRES_PASSWORD=changeme

# Redis
REDIS_URL=redis://localhost:6379

# S3
S3_BUCKET=train-my-ai
S3_ENDPOINT=http://localhost:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin

# Secrets
VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=root

# External APIs (optional)
OPENAI_API_KEY=sk-...
HUGGINGFACE_TOKEN=hf_...

# MLflow
MLFLOW_TRACKING_URI=http://localhost:5000

# Auth
JWT_SECRET=your-secret-key-change-in-production
```

## Testing

```bash
# Backend tests
cd backend
pytest

# Frontend tests
cd frontend
npm test

# E2E tests
npm run test:e2e

# Load tests
k6 run scripts/load_test.js
```

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## Security

- Report vulnerabilities to [security@train-my-ai.com](mailto:security@train-my-ai.com)
- See [Security Policy](docs/security/threat-model.md)

## License

MIT License - see [LICENSE](LICENSE) file

## Support

- **Documentation**: https://docs.train-my-ai.com
- **Discord**: https://discord.gg/train-my-ai
- **Email**: support@train-my-ai.com
- **Status**: https://status.train-my-ai.com

## Roadmap

- [x] MVP (RAG + SFT training)
- [x] BYO GPU support
- [ ] Public beta
- [ ] Stripe billing integration
- [ ] Model marketplace
- [ ] Multi-region deployment
- [ ] Enterprise SSO
- [ ] Mobile apps

---

Built with ❤️ by the Train-My-AI team
