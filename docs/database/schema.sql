-- ============================================================
-- Train-My-AI Platform - PostgreSQL Schema
-- Version: 1.0.0
-- Multi-tenant architecture with row-level security
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "vector";  -- pgvector for embeddings

-- Set timezone
SET timezone = 'Asia/Kolkata';

-- ============================================================
-- USERS & AUTHENTICATION
-- ============================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);

-- ============================================================
-- WORKSPACES (Multi-tenancy)
-- ============================================================

CREATE TABLE workspaces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    -- Resource limits
    storage_limit_bytes BIGINT DEFAULT 10737418240,  -- 10 GB
    storage_used_bytes BIGINT DEFAULT 0,
    gpu_hours_limit INTEGER,  -- NULL = unlimited

    -- Billing
    budget_limit_usd DECIMAL(10, 2),
    budget_used_usd DECIMAL(10, 2) DEFAULT 0,
    budget_alert_threshold DECIMAL(3, 2) DEFAULT 0.8,  -- Alert at 80%
    stripe_customer_id VARCHAR(255),

    -- Metadata
    settings JSONB DEFAULT '{}',
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_workspaces_owner ON workspaces(owner_id);
CREATE INDEX idx_workspaces_slug ON workspaces(slug);

-- ============================================================
-- WORKSPACE MEMBERS & ROLES
-- ============================================================

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    permissions JSONB NOT NULL,  -- {"datasets": ["read", "write"], "jobs": ["read", "create"]}
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default roles
INSERT INTO roles (name, description, permissions) VALUES
('OWNER', 'Full workspace access', '{"datasets": ["create", "read", "update", "delete"], "jobs": ["create", "read", "cancel"], "models": ["read", "deploy", "delete"], "secrets": ["create", "read", "delete"], "billing": ["read"], "members": ["invite", "remove"]}'),
('ADMIN', 'Manage resources but not billing', '{"datasets": ["create", "read", "update", "delete"], "jobs": ["create", "read", "cancel"], "models": ["read", "deploy"], "secrets": ["create", "read"], "members": ["invite"]}'),
('MEMBER', 'Create and manage own resources', '{"datasets": ["create", "read"], "jobs": ["create", "read"], "models": ["read"]}'),
('VIEWER', 'Read-only access', '{"datasets": ["read"], "jobs": ["read"], "models": ["read"]}');

CREATE TABLE workspace_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id),
    invited_by UUID REFERENCES users(id),
    invited_at TIMESTAMPTZ DEFAULT NOW(),
    joined_at TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'REMOVED')),
    UNIQUE(workspace_id, user_id)
);

CREATE INDEX idx_workspace_members_workspace ON workspace_members(workspace_id);
CREATE INDEX idx_workspace_members_user ON workspace_members(user_id);

-- ============================================================
-- DATASETS
-- ============================================================

CREATE TABLE datasets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),

    name VARCHAR(255) NOT NULL,
    description TEXT,
    dataset_type VARCHAR(50) NOT NULL CHECK (dataset_type IN ('RAG', 'SFT')),

    -- Status
    status VARCHAR(50) DEFAULT 'UPLOADING' CHECK (status IN ('UPLOADING', 'PROCESSING', 'READY', 'FAILED')),

    -- Metrics
    size_bytes BIGINT DEFAULT 0,
    num_files INTEGER DEFAULT 0,
    num_chunks INTEGER DEFAULT 0,

    -- Processing config
    processing_config JSONB,  -- chunk_size, overlap, pii_redaction, etc.

    -- S3 location
    s3_bucket VARCHAR(255),
    s3_prefix VARCHAR(500),

    -- Metadata
    metadata JSONB DEFAULT '{}',
    tags TEXT[],

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX idx_datasets_workspace ON datasets(workspace_id);
CREATE INDEX idx_datasets_status ON datasets(status);
CREATE INDEX idx_datasets_type ON datasets(dataset_type);
CREATE INDEX idx_datasets_tags ON datasets USING GIN(tags);

-- ============================================================
-- DATASET FILES
-- ============================================================

CREATE TABLE dataset_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dataset_id UUID NOT NULL REFERENCES datasets(id) ON DELETE CASCADE,

    filename VARCHAR(500) NOT NULL,
    file_type VARCHAR(50),  -- pdf, txt, csv, jsonl, etc.
    size_bytes BIGINT NOT NULL,

    -- S3 location
    s3_key TEXT NOT NULL,

    -- Upload tracking
    upload_status VARCHAR(50) DEFAULT 'PENDING' CHECK (upload_status IN ('PENDING', 'UPLOADING', 'COMPLETED', 'FAILED')),
    upload_started_at TIMESTAMPTZ,
    upload_completed_at TIMESTAMPTZ,

    -- Processing
    processed BOOLEAN DEFAULT FALSE,
    processing_error TEXT,

    -- Content hash for deduplication
    content_hash VARCHAR(64),

    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dataset_files_dataset ON dataset_files(dataset_id);
CREATE INDEX idx_dataset_files_upload_status ON dataset_files(upload_status);
CREATE INDEX idx_dataset_files_hash ON dataset_files(content_hash);

-- ============================================================
-- DATASET CHUNKS (for RAG)
-- ============================================================

CREATE TABLE dataset_chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dataset_id UUID NOT NULL REFERENCES datasets(id) ON DELETE CASCADE,
    file_id UUID REFERENCES dataset_files(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,

    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,

    -- Token count
    token_count INTEGER,

    -- Metadata for retrieval
    metadata JSONB DEFAULT '{}',  -- page_num, section, author, date, etc.

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(dataset_id, file_id, chunk_index)
);

CREATE INDEX idx_chunks_dataset ON dataset_chunks(dataset_id);
CREATE INDEX idx_chunks_workspace ON dataset_chunks(workspace_id);

-- ============================================================
-- EMBEDDINGS (pgvector)
-- ============================================================

CREATE TABLE embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    dataset_id UUID NOT NULL REFERENCES datasets(id) ON DELETE CASCADE,
    chunk_id UUID NOT NULL REFERENCES dataset_chunks(id) ON DELETE CASCADE,

    -- Vector embedding (dimension depends on model)
    -- OpenAI text-embedding-3-small: 1536
    -- OpenAI text-embedding-3-large: 3072
    -- sentence-transformers: 384-768
    embedding vector(1536),

    -- Embedding metadata
    embedding_model VARCHAR(255) NOT NULL,

    -- For hybrid search
    metadata JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HNSW index for fast ANN search
CREATE INDEX idx_embeddings_vector_cosine ON embeddings
    USING hnsw (embedding vector_cosine_ops);

-- For filtering by workspace/dataset
CREATE INDEX idx_embeddings_workspace ON embeddings(workspace_id);
CREATE INDEX idx_embeddings_dataset ON embeddings(dataset_id);

-- ============================================================
-- JOBS
-- ============================================================

CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),

    -- Job specification
    job_type VARCHAR(50) NOT NULL CHECK (job_type IN ('INGEST', 'RAG_TRAIN', 'SFT_TRAIN', 'EVAL', 'INFER')),
    dataset_id UUID REFERENCES datasets(id) ON DELETE SET NULL,

    -- Status & lifecycle
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
    progress DECIMAL(3, 2) DEFAULT 0,  -- 0 to 1

    -- Compute
    compute_type VARCHAR(50) DEFAULT 'MANAGED_GPU' CHECK (compute_type IN ('MANAGED_GPU', 'BYO_GPU')),
    gpu_node_id UUID,  -- Reference to gpu_nodes table
    gpu_type VARCHAR(100),  -- "A10", "A100", "RTX4090", etc.

    -- Configuration
    config JSONB NOT NULL,  -- Job-specific config (see API spec)

    -- Results
    result JSONB,
    error TEXT,
    logs_url TEXT,

    -- Resource usage
    gpu_seconds INTEGER DEFAULT 0,
    cpu_seconds INTEGER DEFAULT 0,
    memory_mb_seconds BIGINT DEFAULT 0,
    estimated_cost_usd DECIMAL(10, 4),

    -- Timing
    created_at TIMESTAMPTZ DEFAULT NOW(),
    queued_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    -- Retry logic
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,

    -- Parent job (for pipelines)
    parent_job_id UUID REFERENCES jobs(id) ON DELETE CASCADE
);

CREATE INDEX idx_jobs_workspace ON jobs(workspace_id);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_type ON jobs(job_type);
CREATE INDEX idx_jobs_created_at ON jobs(created_at DESC);
CREATE INDEX idx_jobs_compute ON jobs(compute_type, gpu_node_id);

-- ============================================================
-- RUNS (MLflow integration)
-- ============================================================

CREATE TABLE runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,

    -- MLflow tracking
    mlflow_run_id VARCHAR(255) UNIQUE,
    mlflow_experiment_id VARCHAR(255),

    -- Run metadata
    run_name VARCHAR(255),

    -- Hyperparameters
    params JSONB DEFAULT '{}',

    -- Metrics (final values)
    metrics JSONB DEFAULT '{}',

    -- Artifact locations
    artifact_uri TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_runs_workspace ON runs(workspace_id);
CREATE INDEX idx_runs_job ON runs(job_id);
CREATE INDEX idx_runs_mlflow ON runs(mlflow_run_id);

-- ============================================================
-- ARTIFACTS (Model outputs)
-- ============================================================

CREATE TABLE artifacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,
    run_id UUID REFERENCES runs(id) ON DELETE SET NULL,

    artifact_type VARCHAR(50) NOT NULL CHECK (artifact_type IN ('MODEL', 'ADAPTER', 'TOKENIZER', 'CONFIG', 'METRICS', 'LOGS')),

    -- S3 location
    s3_key TEXT NOT NULL,
    size_bytes BIGINT,

    -- Metadata
    metadata JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_artifacts_workspace ON artifacts(workspace_id);
CREATE INDEX idx_artifacts_job ON artifacts(job_id);
CREATE INDEX idx_artifacts_type ON artifacts(artifact_type);

-- ============================================================
-- MODELS
-- ============================================================

CREATE TABLE models (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),

    name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Model specification
    model_type VARCHAR(50) NOT NULL CHECK (model_type IN ('RAG', 'SFT')),
    base_model VARCHAR(255),  -- e.g., "meta-llama/Llama-3-8B"

    -- Training job
    job_id UUID REFERENCES jobs(id),
    run_id UUID REFERENCES runs(id),

    -- Artifact locations
    artifacts_uri TEXT,
    mlflow_model_uri TEXT,

    -- Deployment
    deployment_status VARCHAR(50) DEFAULT 'UNDEPLOYED' CHECK (deployment_status IN ('UNDEPLOYED', 'DEPLOYING', 'DEPLOYED', 'FAILED')),
    endpoint_url TEXT,
    endpoint_config JSONB,

    -- Metrics
    eval_metrics JSONB DEFAULT '{}',

    -- Versioning
    version INTEGER DEFAULT 1,
    parent_model_id UUID REFERENCES models(id),

    -- Metadata
    tags TEXT[],
    metadata JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deployed_at TIMESTAMPTZ
);

CREATE INDEX idx_models_workspace ON models(workspace_id);
CREATE INDEX idx_models_type ON models(model_type);
CREATE INDEX idx_models_deployment ON models(deployment_status);
CREATE INDEX idx_models_tags ON models USING GIN(tags);

-- ============================================================
-- SECRETS (metadata only, actual secrets in Vault)
-- ============================================================

CREATE TABLE secrets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),

    name VARCHAR(255) NOT NULL,
    provider VARCHAR(50) NOT NULL CHECK (provider IN ('OPENAI', 'ANTHROPIC', 'HUGGINGFACE', 'COHERE', 'CUSTOM')),

    -- Vault reference
    vault_path TEXT NOT NULL,

    -- Usage tracking
    last_used_at TIMESTAMPTZ,
    usage_count INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(workspace_id, name)
);

CREATE INDEX idx_secrets_workspace ON secrets(workspace_id);
CREATE INDEX idx_secrets_provider ON secrets(provider);

-- ============================================================
-- GPU NODES (BYO GPU)
-- ============================================================

CREATE TABLE gpu_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    registered_by UUID NOT NULL REFERENCES users(id),

    name VARCHAR(255) NOT NULL,

    -- Status
    status VARCHAR(50) DEFAULT 'OFFLINE' CHECK (status IN ('ONLINE', 'OFFLINE', 'BUSY', 'ERROR', 'MAINTENANCE')),

    -- Hardware info
    gpu_info JSONB NOT NULL,  -- {count, model, vram_total_mb, vram_free_mb, cuda_version}
    cpu_info JSONB,
    system_info JSONB,  -- OS, kernel, etc.

    -- Authentication
    agent_token_hash VARCHAR(255),  -- Hashed JWT token
    mtls_cert_fingerprint VARCHAR(255),

    -- Networking
    public_ip INET,
    last_heartbeat TIMESTAMPTZ,

    -- Metadata
    metadata JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gpu_nodes_workspace ON gpu_nodes(workspace_id);
CREATE INDEX idx_gpu_nodes_status ON gpu_nodes(status);
CREATE INDEX idx_gpu_nodes_heartbeat ON gpu_nodes(last_heartbeat);

-- ============================================================
-- BILLING & USAGE
-- ============================================================

CREATE TABLE billing_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,

    -- Billing period
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,

    -- Compute usage
    gpu_seconds_managed INTEGER DEFAULT 0,
    gpu_seconds_byo INTEGER DEFAULT 0,
    cpu_seconds INTEGER DEFAULT 0,

    -- Storage
    storage_gb_hours DECIMAL(12, 2) DEFAULT 0,

    -- Network
    egress_gb DECIMAL(10, 2) DEFAULT 0,

    -- API calls
    api_calls INTEGER DEFAULT 0,

    -- Costs (calculated based on pricing model)
    compute_cost_usd DECIMAL(10, 4) DEFAULT 0,
    storage_cost_usd DECIMAL(10, 4) DEFAULT 0,
    network_cost_usd DECIMAL(10, 4) DEFAULT 0,
    total_cost_usd DECIMAL(10, 4) DEFAULT 0,

    -- Stripe
    stripe_invoice_id VARCHAR(255),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(workspace_id, period_start)
);

CREATE INDEX idx_billing_workspace ON billing_usage(workspace_id);
CREATE INDEX idx_billing_period ON billing_usage(period_start, period_end);

-- Real-time usage tracking (micro-billing)
CREATE TABLE usage_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,

    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('GPU_SECOND', 'STORAGE_GB_HOUR', 'API_CALL', 'EGRESS_GB')),
    quantity DECIMAL(12, 4) NOT NULL,
    unit_cost_usd DECIMAL(10, 6),
    total_cost_usd DECIMAL(10, 4),

    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Partition by month for performance
CREATE INDEX idx_usage_events_workspace ON usage_events(workspace_id, timestamp DESC);
CREATE INDEX idx_usage_events_type ON usage_events(event_type);

CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,
    limit_usd DECIMAL(10, 2) NOT NULL,
    period VARCHAR(50) DEFAULT 'MONTHLY' CHECK (period IN ('DAILY', 'WEEKLY', 'MONTHLY', 'ANNUAL')),

    -- Alert thresholds (0-1)
    alert_thresholds DECIMAL[] DEFAULT ARRAY[0.5, 0.8, 0.9, 1.0],

    -- Actions on limit breach
    auto_stop_jobs BOOLEAN DEFAULT TRUE,

    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_budgets_workspace ON budgets(workspace_id);

-- ============================================================
-- AUDIT LOG
-- ============================================================

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID REFERENCES workspaces(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Event
    action VARCHAR(100) NOT NULL,  -- "dataset.created", "job.started", "secret.accessed", etc.
    resource_type VARCHAR(50),
    resource_id UUID,

    -- Request context
    ip_address INET,
    user_agent TEXT,
    request_id UUID,

    -- Details
    details JSONB DEFAULT '{}',

    -- Compliance
    severity VARCHAR(50) DEFAULT 'INFO' CHECK (severity IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')),

    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Partition by month for retention policy
CREATE INDEX idx_audit_workspace ON audit_log(workspace_id, timestamp DESC);
CREATE INDEX idx_audit_user ON audit_log(user_id, timestamp DESC);
CREATE INDEX idx_audit_action ON audit_log(action);

-- ============================================================
-- API KEYS (for programmatic access)
-- ============================================================

CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),

    name VARCHAR(255) NOT NULL,
    key_prefix VARCHAR(20) NOT NULL,  -- First 8 chars (e.g., "tmyai_...")
    key_hash VARCHAR(255) NOT NULL,

    -- Permissions
    scopes TEXT[] NOT NULL,  -- ["datasets:read", "jobs:create", "models:infer"]

    -- Rate limiting
    rate_limit_per_minute INTEGER DEFAULT 60,

    -- Usage
    last_used_at TIMESTAMPTZ,
    usage_count BIGINT DEFAULT 0,

    -- Expiry
    expires_at TIMESTAMPTZ,

    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'REVOKED')),

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_api_keys_workspace ON api_keys(workspace_id);
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);

-- ============================================================
-- ROW-LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all tenant tables
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE datasets ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE models ENABLE ROW LEVEL SECURITY;
ALTER TABLE secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE gpu_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Example RLS policy (repeat for each table)
-- Application sets workspace_id in session: SET app.workspace_id = 'uuid';

CREATE POLICY workspace_isolation ON datasets
    USING (workspace_id = current_setting('app.workspace_id')::uuid);

CREATE POLICY workspace_isolation ON jobs
    USING (workspace_id = current_setting('app.workspace_id')::uuid);

CREATE POLICY workspace_isolation ON embeddings
    USING (workspace_id = current_setting('app.workspace_id')::uuid);

-- Similar policies for other tables...

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_workspaces_updated_at BEFORE UPDATE ON workspaces
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_datasets_updated_at BEFORE UPDATE ON datasets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_models_updated_at BEFORE UPDATE ON models
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Update workspace storage usage
CREATE OR REPLACE FUNCTION update_workspace_storage()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE workspaces
        SET storage_used_bytes = storage_used_bytes + NEW.size_bytes
        WHERE id = NEW.workspace_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE workspaces
        SET storage_used_bytes = storage_used_bytes - OLD.size_bytes
        WHERE id = OLD.workspace_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_storage_on_dataset AFTER INSERT OR DELETE ON datasets
    FOR EACH ROW EXECUTE FUNCTION update_workspace_storage();

-- Audit log trigger
CREATE OR REPLACE FUNCTION log_sensitive_actions()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (workspace_id, action, resource_type, resource_id, details, severity)
    VALUES (
        NEW.workspace_id,
        TG_TABLE_NAME || '.' || lower(TG_OP),
        TG_TABLE_NAME,
        NEW.id,
        row_to_json(NEW),
        'INFO'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_secrets AFTER INSERT OR UPDATE OR DELETE ON secrets
    FOR EACH ROW EXECUTE FUNCTION log_sensitive_actions();

-- ============================================================
-- VIEWS
-- ============================================================

-- Workspace usage summary
CREATE VIEW workspace_usage_summary AS
SELECT
    w.id AS workspace_id,
    w.name,
    w.storage_used_bytes,
    w.storage_limit_bytes,
    w.budget_used_usd,
    w.budget_limit_usd,
    COUNT(DISTINCT d.id) AS num_datasets,
    COUNT(DISTINCT j.id) AS num_jobs,
    COUNT(DISTINCT m.id) AS num_models,
    SUM(CASE WHEN j.status = 'RUNNING' THEN 1 ELSE 0 END) AS running_jobs,
    SUM(j.gpu_seconds) AS total_gpu_seconds
FROM workspaces w
LEFT JOIN datasets d ON w.id = d.workspace_id
LEFT JOIN jobs j ON w.id = j.workspace_id
LEFT JOIN models m ON w.id = m.workspace_id
GROUP BY w.id, w.name, w.storage_used_bytes, w.storage_limit_bytes, w.budget_used_usd, w.budget_limit_usd;

-- Job queue view
CREATE VIEW job_queue AS
SELECT
    j.id,
    j.workspace_id,
    j.job_type,
    j.status,
    j.compute_type,
    j.created_at,
    EXTRACT(EPOCH FROM (NOW() - j.created_at)) AS queue_time_seconds,
    w.name AS workspace_name
FROM jobs j
JOIN workspaces w ON j.workspace_id = w.id
WHERE j.status IN ('PENDING', 'QUEUED')
ORDER BY j.created_at ASC;

-- ============================================================
-- SEED DATA
-- ============================================================

-- Create a demo user (for development only)
-- Password: "demo123456" (bcrypt hash)
INSERT INTO users (email, email_verified, password_hash, name)
VALUES (
    'demo@train-my-ai.com',
    true,
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqNQPjxTq6',
    'Demo User'
);

-- ============================================================
-- PERFORMANCE OPTIMIZATION
-- ============================================================

-- Analyze tables for query planner
ANALYZE users;
ANALYZE workspaces;
ANALYZE datasets;
ANALYZE jobs;
ANALYZE embeddings;

-- ============================================================
-- BACKUP & RETENTION POLICIES
-- ============================================================

-- Audit log retention: 7 years
-- Implementation: Partition by month, drop old partitions
-- Usage events: Archive to S3 after 90 days

-- ============================================================
-- COMMENTS
-- ============================================================

COMMENT ON TABLE workspaces IS 'Multi-tenant workspaces with storage and budget limits';
COMMENT ON TABLE datasets IS 'User-uploaded datasets for RAG or SFT training';
COMMENT ON TABLE embeddings IS 'Vector embeddings for RAG retrieval (pgvector)';
COMMENT ON TABLE jobs IS 'Training, evaluation, and inference jobs';
COMMENT ON TABLE models IS 'Trained models with deployment status';
COMMENT ON TABLE gpu_nodes IS 'User-provided GPU nodes for BYO compute';
COMMENT ON TABLE audit_log IS 'Compliance audit trail (7-year retention)';
COMMENT ON COLUMN workspaces.storage_limit_bytes IS 'Hard limit: 10 GB = 10737418240 bytes';
