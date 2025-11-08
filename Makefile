.PHONY: help dev-up dev-down api worker seed run-rag-demo run-sft-demo clean

# ============================================================
# Train-My-AI Platform Makefile
# ============================================================

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Train-My-AI Platform - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# ============================================================
# Development Environment
# ============================================================

dev-up: ## Start all services (Docker Compose)
	@echo "$(BLUE)Starting all services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo ""
	@echo "Access services at:"
	@echo "  Frontend:  http://localhost:3000"
	@echo "  API:       http://localhost:8000"
	@echo "  API Docs:  http://localhost:8000/docs"
	@echo "  Grafana:   http://localhost:3001 (admin/admin)"
	@echo "  MLflow:    http://localhost:5000"
	@echo "  MinIO:     http://localhost:9001 (minioadmin/minioadmin)"
	@echo ""
	@echo "$(YELLOW)Run 'make logs' to view logs$(NC)"

dev-down: ## Stop all services
	@echo "$(BLUE)Stopping all services...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

dev-restart: ## Restart all services
	@echo "$(BLUE)Restarting all services...$(NC)"
	docker-compose restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all services
	docker-compose logs -f

logs-api: ## View API logs only
	docker-compose logs -f api

logs-worker: ## View worker logs only
	docker-compose logs -f worker

# ============================================================
# API Development
# ============================================================

api: ## Run API server with hot reload (local)
	@echo "$(BLUE)Starting FastAPI server...$(NC)"
	cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

api-shell: ## Open shell in API container
	docker-compose exec api bash

api-test: ## Run API tests
	@echo "$(BLUE)Running API tests...$(NC)"
	cd backend && pytest -v --cov=app --cov-report=html
	@echo "$(GREEN)✓ Tests completed$(NC)"
	@echo "Coverage report: backend/htmlcov/index.html"

api-lint: ## Lint API code
	@echo "$(BLUE)Linting API code...$(NC)"
	cd backend && ruff check . && black --check .
	@echo "$(GREEN)✓ Linting passed$(NC)"

api-format: ## Format API code
	@echo "$(BLUE)Formatting API code...$(NC)"
	cd backend && black . && ruff check --fix .
	@echo "$(GREEN)✓ Code formatted$(NC)"

# ============================================================
# Frontend Development
# ============================================================

frontend: ## Run frontend with hot reload (local)
	@echo "$(BLUE)Starting Next.js dev server...$(NC)"
	cd frontend && npm run dev

frontend-build: ## Build frontend for production
	@echo "$(BLUE)Building frontend...$(NC)"
	cd frontend && npm run build
	@echo "$(GREEN)✓ Build completed$(NC)"

frontend-test: ## Run frontend tests
	@echo "$(BLUE)Running frontend tests...$(NC)"
	cd frontend && npm test
	@echo "$(GREEN)✓ Tests completed$(NC)"

frontend-lint: ## Lint frontend code
	@echo "$(BLUE)Linting frontend code...$(NC)"
	cd frontend && npm run lint
	@echo "$(GREEN)✓ Linting passed$(NC)"

# ============================================================
# Worker Development
# ============================================================

worker: ## Run job worker (local)
	@echo "$(BLUE)Starting job worker...$(NC)"
	cd workers && python -m celery -A app worker --loglevel=info

worker-test: ## Run worker tests
	@echo "$(BLUE)Running worker tests...$(NC)"
	cd workers && pytest -v
	@echo "$(GREEN)✓ Tests completed$(NC)"

# ============================================================
# Database
# ============================================================

db-shell: ## Open PostgreSQL shell
	docker-compose exec postgres psql -U trainmyai -d trainmyai

db-migrate: ## Run database migrations
	@echo "$(BLUE)Running database migrations...$(NC)"
	cd backend && alembic upgrade head
	@echo "$(GREEN)✓ Migrations completed$(NC)"

db-rollback: ## Rollback last migration
	@echo "$(BLUE)Rolling back last migration...$(NC)"
	cd backend && alembic downgrade -1
	@echo "$(GREEN)✓ Rollback completed$(NC)"

db-reset: ## Reset database (WARNING: drops all data)
	@echo "$(RED)⚠️  WARNING: This will drop all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose exec postgres psql -U trainmyai -c "DROP DATABASE IF EXISTS trainmyai;"; \
		docker-compose exec postgres psql -U trainmyai -c "CREATE DATABASE trainmyai;"; \
		$(MAKE) db-migrate; \
		$(MAKE) seed; \
		echo "$(GREEN)✓ Database reset completed$(NC)"; \
	fi

seed: ## Seed database with demo data
	@echo "$(BLUE)Seeding database...$(NC)"
	docker-compose exec api python scripts/seed_db.py
	@echo "$(GREEN)✓ Database seeded$(NC)"
	@echo ""
	@echo "Demo user created:"
	@echo "  Email:    demo@train-my-ai.com"
	@echo "  Password: demo123456"

# ============================================================
# Demos
# ============================================================

run-rag-demo: ## Execute RAG workflow demo
	@echo "$(BLUE)Running RAG Demo...$(NC)"
	@echo ""
	@echo "This demo will:"
	@echo "  1. Create a workspace"
	@echo "  2. Upload sample documents (FAQs)"
	@echo "  3. Process and chunk the documents"
	@echo "  4. Train a RAG model with OpenAI embeddings"
	@echo "  5. Deploy inference endpoint"
	@echo "  6. Query the model"
	@echo ""
	@read -p "Make sure OPENAI_API_KEY is set in .env. Press Enter to continue..."
	@echo ""
	docker-compose exec api python scripts/demos/rag_demo.py
	@echo ""
	@echo "$(GREEN)✓ RAG demo completed!$(NC)"

run-sft-demo: ## Execute SFT workflow demo
	@echo "$(BLUE)Running SFT Demo...$(NC)"
	@echo ""
	@echo "This demo will:"
	@echo "  1. Create a workspace"
	@echo "  2. Upload SFT dataset (JSONL)"
	@echo "  3. Validate dataset schema"
	@echo "  4. Fine-tune Llama-3-8B with LoRA"
	@echo "  5. Evaluate on holdout set"
	@echo "  6. Deploy vLLM endpoint"
	@echo "  7. Test inference"
	@echo ""
	@echo "$(YELLOW)Note: This requires a GPU. Estimated time: 30-60 minutes$(NC)"
	@read -p "Make sure HUGGINGFACE_TOKEN is set in .env. Press Enter to continue..."
	@echo ""
	docker-compose exec worker python scripts/demos/sft_demo.py
	@echo ""
	@echo "$(GREEN)✓ SFT demo completed!$(NC)"

# ============================================================
# GPU Agent
# ============================================================

build-agent: ## Build GPU agent binary
	@echo "$(BLUE)Building GPU agent...$(NC)"
	cd gpu-agent && go build -o bin/gpu-agent main.go
	@echo "$(GREEN)✓ Agent built: gpu-agent/bin/gpu-agent$(NC)"

run-agent: ## Run GPU agent (requires registration first)
	@echo "$(BLUE)Starting GPU agent...$(NC)"
	cd gpu-agent && ./bin/gpu-agent \
		--node-id=${GPU_NODE_ID} \
		--name="Local Dev GPU" \
		--api=http://localhost:8000 \
		--cert=./certs/client.crt \
		--key=./certs/client.key

agent-test: ## Test GPU agent
	cd gpu-agent && go test -v ./...

# ============================================================
# Docker
# ============================================================

build: ## Build all Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	docker-compose build
	@echo "$(GREEN)✓ Images built$(NC)"

build-api: ## Build API image
	docker build -t trainmyai/api:latest -f backend/Dockerfile backend/

build-frontend: ## Build frontend image
	docker build -t trainmyai/frontend:latest -f frontend/Dockerfile frontend/

build-workers: ## Build worker images
	docker build -t trainmyai/ingest-worker:latest -f workers/Dockerfiles/ingest.Dockerfile workers/
	docker build -t trainmyai/rag-worker:latest -f workers/Dockerfiles/rag.Dockerfile workers/
	docker build -t trainmyai/sft-worker:latest -f workers/Dockerfiles/sft.Dockerfile workers/

push: ## Push images to registry (requires login)
	@echo "$(BLUE)Pushing images to registry...$(NC)"
	docker-compose push
	@echo "$(GREEN)✓ Images pushed$(NC)"

# ============================================================
# Kubernetes / Helm
# ============================================================

k8s-deploy-dev: ## Deploy to local k3d cluster
	@echo "$(BLUE)Deploying to local k3d...$(NC)"
	k3d cluster create train-my-ai || true
	kubectl create namespace train-my-ai || true
	helm upgrade --install train-my-ai ./helm/train-my-ai \
		--namespace train-my-ai \
		--values helm/train-my-ai/values-dev.yaml
	@echo "$(GREEN)✓ Deployed to k3d$(NC)"

k8s-deploy-staging: ## Deploy to staging cluster
	@echo "$(BLUE)Deploying to staging...$(NC)"
	kubectl config use-context staging
	helm upgrade --install train-my-ai ./helm/train-my-ai \
		--namespace train-my-ai \
		--values helm/train-my-ai/values-staging.yaml \
		--wait
	@echo "$(GREEN)✓ Deployed to staging$(NC)"

k8s-deploy-prod: ## Deploy to production cluster (requires confirmation)
	@echo "$(RED)⚠️  PRODUCTION DEPLOYMENT$(NC)"
	@read -p "Are you sure you want to deploy to production? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		kubectl config use-context production; \
		helm upgrade --install train-my-ai ./helm/train-my-ai \
			--namespace train-my-ai \
			--values helm/train-my-ai/values-prod.yaml \
			--wait; \
		echo "$(GREEN)✓ Deployed to production$(NC)"; \
	fi

# ============================================================
# Testing
# ============================================================

test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	$(MAKE) api-test
	$(MAKE) frontend-test
	$(MAKE) worker-test
	@echo "$(GREEN)✓ All tests passed$(NC)"

test-e2e: ## Run end-to-end tests
	@echo "$(BLUE)Running E2E tests...$(NC)"
	cd frontend && npm run test:e2e
	@echo "$(GREEN)✓ E2E tests passed$(NC)"

test-load: ## Run load tests (k6)
	@echo "$(BLUE)Running load tests...$(NC)"
	k6 run scripts/load_test.js
	@echo "$(GREEN)✓ Load tests completed$(NC)"

test-security: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	@echo "Scanning dependencies..."
	cd backend && safety check
	cd frontend && npm audit
	@echo "Scanning Docker images..."
	trivy image trainmyai/api:latest
	@echo "$(GREEN)✓ Security scans completed$(NC)"

# ============================================================
# Linting & Formatting
# ============================================================

lint: ## Lint all code
	@echo "$(BLUE)Linting all code...$(NC)"
	$(MAKE) api-lint
	$(MAKE) frontend-lint
	@echo "$(GREEN)✓ All linting passed$(NC)"

format: ## Format all code
	@echo "$(BLUE)Formatting all code...$(NC)"
	$(MAKE) api-format
	cd frontend && npm run format
	@echo "$(GREEN)✓ All code formatted$(NC)"

# ============================================================
# Monitoring & Observability
# ============================================================

grafana: ## Open Grafana in browser
	@echo "$(BLUE)Opening Grafana...$(NC)"
	@echo "URL: http://localhost:3001"
	@echo "User: admin / Password: admin"
	open http://localhost:3001 || xdg-open http://localhost:3001 || true

prometheus: ## Open Prometheus in browser
	@echo "$(BLUE)Opening Prometheus...$(NC)"
	@echo "URL: http://localhost:9090"
	open http://localhost:9090 || xdg-open http://localhost:9090 || true

mlflow: ## Open MLflow in browser
	@echo "$(BLUE)Opening MLflow...$(NC)"
	@echo "URL: http://localhost:5000"
	open http://localhost:5000 || xdg-open http://localhost:5000 || true

# ============================================================
# Cleanup
# ============================================================

clean: ## Clean up generated files and containers
	@echo "$(BLUE)Cleaning up...$(NC)"
	docker-compose down -v
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".next" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf backend/htmlcov backend/.coverage
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

clean-volumes: ## Remove all Docker volumes (WARNING: deletes all data)
	@echo "$(RED)⚠️  WARNING: This will delete all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		docker volume prune -f; \
		echo "$(GREEN)✓ Volumes removed$(NC)"; \
	fi

# ============================================================
# CI/CD
# ============================================================

ci: ## Run CI checks (lint, test, build)
	@echo "$(BLUE)Running CI checks...$(NC)"
	$(MAKE) lint
	$(MAKE) test
	$(MAKE) build
	@echo "$(GREEN)✓ CI checks passed$(NC)"

pre-commit: ## Run pre-commit checks
	@echo "$(BLUE)Running pre-commit checks...$(NC)"
	$(MAKE) lint
	$(MAKE) api-test
	@echo "$(GREEN)✓ Pre-commit checks passed$(NC)"

# ============================================================
# Documentation
# ============================================================

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	cd backend && python -m mkdocs build
	@echo "$(GREEN)✓ Documentation generated$(NC)"
	@echo "Open: backend/site/index.html"

docs-serve: ## Serve documentation locally
	cd backend && python -m mkdocs serve

# ============================================================
# Utilities
# ============================================================

status: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	@docker-compose ps

ps: status ## Alias for status

version: ## Show version information
	@echo "$(BLUE)Train-My-AI Platform$(NC)"
	@echo "Version: 1.0.0-alpha"
	@echo ""
	@echo "Component versions:"
	@echo "  Python:    $$(python --version 2>&1 | cut -d' ' -f2)"
	@echo "  Node.js:   $$(node --version)"
	@echo "  Docker:    $$(docker --version | cut -d' ' -f3 | tr -d ',')"
	@echo "  Kubectl:   $$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo 'not installed')"

install-deps: ## Install all dependencies
	@echo "$(BLUE)Installing dependencies...$(NC)"
	@echo "Installing backend dependencies..."
	cd backend && pip install -r requirements.txt
	@echo "Installing frontend dependencies..."
	cd frontend && npm install
	@echo "Installing worker dependencies..."
	cd workers && pip install -r requirements.txt
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

# ============================================================
# Default target
# ============================================================

.DEFAULT_GOAL := help
