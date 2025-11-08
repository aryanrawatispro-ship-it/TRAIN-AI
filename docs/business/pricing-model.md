# Pricing & Cost Model

## 11. Unit Economics & Billing

### Pricing Tiers

#### Free Tier
- **Storage**: 2 GB
- **GPU Hours**: 5 hours/month (managed GPU only)
- **Models**: 1 deployed model
- **Inference**: 1,000 requests/month
- **Support**: Community (Discord/forums)

#### Pro Tier ($49/month)
- **Storage**: 10 GB included, then $0.10/GB/month
- **GPU Hours**: 20 hours/month included
  - Managed GPU (A10): $1.50/hour
  - Managed GPU (A100): $3.00/hour
  - BYO GPU: Free compute, $0.10/hour platform fee
- **Models**: 10 deployed models
- **Inference**: 100,000 requests/month, then $0.01/1K requests
- **Support**: Email (24-hour SLA)
- **Features**: Advanced metrics, priority queue

#### Enterprise (Custom pricing)
- **Storage**: Custom (TB scale)
- **GPU Hours**: Volume discounts (>1,000 hours/month)
- **Models**: Unlimited
- **Inference**: Custom SLA, dedicated endpoints
- **Support**: Dedicated Slack channel, 1-hour SLA
- **Features**: SSO, SOC 2, SLA guarantees, private VPC

---

### Unit Costs (Provider Perspective)

#### Managed GPU Compute

| GPU Type | Cloud Cost/hour | Markup | Customer Price/hour | Margin |
|----------|----------------|--------|---------------------|--------|
| A10 (24GB) | $1.10 | 36% | $1.50 | $0.40 |
| A100 (40GB) | $2.20 | 36% | $3.00 | $0.80 |
| T4 (16GB) | $0.60 | 50% | $0.90 | $0.30 |

**Target Margin**: 35-40%

#### Storage

| Resource | Cost | Customer Price | Margin |
|----------|------|----------------|--------|
| S3 storage | $0.023/GB/month | $0.10/GB/month | $0.077 |
| Egress | $0.09/GB | $0.15/GB | $0.06 |
| Postgres (per workspace) | $0.01/GB/month | Included | - |
| Vector DB (pgvector) | $0.02/GB/month | Included | - |

**Target Margin**: 60-70%

#### Inference

| Resource | Cost | Customer Price | Margin |
|----------|------|----------------|--------|
| vLLM instance (T4) | $0.60/hour | $0.01/1K requests (~10 req/min) | ~60% |
| API overhead | $0.001/1K requests | Included | - |

**Assumption**: 1 vLLM instance serves 10K req/hour

#### Platform Overhead

| Resource | Monthly Cost (1,000 users) | Per-User Cost |
|----------|---------------------------|---------------|
| Kubernetes cluster | $2,000 | $2.00 |
| Postgres (RDS) | $500 | $0.50 |
| Redis | $200 | $0.20 |
| MLflow/Vault | $300 | $0.30 |
| Observability (Grafana Cloud) | $500 | $0.50 |
| **Total** | **$3,500** | **$3.50** |

---

### Billing Workflow

#### 1. Metering

```python
# Real-time usage tracking
async def record_usage(workspace_id: str, event_type: str, quantity: float):
    """Record usage event for billing"""

    # Calculate cost
    unit_cost = PRICING[event_type]
    total_cost = quantity * unit_cost

    # Insert into usage_events table
    await db.execute(
        """
        INSERT INTO usage_events (workspace_id, event_type, quantity, unit_cost_usd, total_cost_usd)
        VALUES ($1, $2, $3, $4, $5)
        """,
        workspace_id, event_type, quantity, unit_cost, total_cost
    )

    # Update running total
    await db.execute(
        """
        UPDATE workspaces
        SET budget_used_usd = budget_used_usd + $1
        WHERE id = $2
        """,
        total_cost, workspace_id
    )

    # Check budget threshold
    workspace = await get_workspace(workspace_id)
    if workspace.budget_used_usd > workspace.budget_limit_usd * 0.9:
        await send_budget_alert(workspace)
```

#### 2. Aggregation (Daily Cron)

```sql
-- Aggregate usage for billing period
INSERT INTO billing_usage (workspace_id, period_start, period_end, gpu_seconds_managed, storage_gb_hours, total_cost_usd)
SELECT
    workspace_id,
    date_trunc('month', NOW()) AS period_start,
    NOW() AS period_end,
    SUM(CASE WHEN event_type = 'GPU_SECOND' THEN quantity ELSE 0 END) AS gpu_seconds,
    SUM(CASE WHEN event_type = 'STORAGE_GB_HOUR' THEN quantity ELSE 0 END) AS storage,
    SUM(total_cost_usd) AS total_cost
FROM usage_events
WHERE workspace_id = :workspace_id
  AND timestamp >= date_trunc('month', NOW())
GROUP BY workspace_id;
```

#### 3. Invoice Generation (Monthly)

```python
async def generate_invoice(workspace_id: str, period_start: date, period_end: date):
    """Generate Stripe invoice for billing period"""

    # Get usage summary
    usage = await get_billing_usage(workspace_id, period_start, period_end)

    # Create Stripe invoice
    invoice = stripe.Invoice.create(
        customer=workspace.stripe_customer_id,
        auto_advance=True,  # Auto-finalize
    )

    # Add line items
    stripe.InvoiceItem.create(
        customer=workspace.stripe_customer_id,
        invoice=invoice.id,
        description=f"GPU Compute ({usage.gpu_seconds_managed / 3600:.1f} hours)",
        amount=int(usage.compute_cost_usd * 100),  # cents
        currency="usd"
    )

    stripe.InvoiceItem.create(
        customer=workspace.stripe_customer_id,
        invoice=invoice.id,
        description=f"Storage ({usage.storage_gb_hours / 730:.1f} GB avg)",
        amount=int(usage.storage_cost_usd * 100),
        currency="usd"
    )

    # Finalize and send
    invoice = stripe.Invoice.finalize_invoice(invoice.id)
    await db.execute(
        "UPDATE billing_usage SET stripe_invoice_id = $1 WHERE workspace_id = $2 AND period_start = $3",
        invoice.id, workspace_id, period_start
    )

    return invoice
```

#### 4. Payment Flow

```
User subscribes → Stripe creates customer → Save stripe_customer_id in DB
Usage occurs → Record in usage_events → Update workspace.budget_used_usd
End of month → Aggregate usage → Generate Stripe invoice → Charge payment method
Payment fails → Retry 3 times → Suspend workspace → Email user
```

---

### Budget Guardrails

#### Workspace Budget Limits

```python
@app.post("/v1/workspaces/{workspace_id}/jobs")
async def create_job(workspace_id: str, job: JobCreate):
    workspace = await get_workspace(workspace_id)

    # Check budget
    if workspace.budget_used_usd >= workspace.budget_limit_usd:
        raise HTTPException(
            status_code=402,  # Payment Required
            detail="Budget limit exceeded. Please increase your budget limit or upgrade your plan."
        )

    # Estimate job cost
    estimated_cost = estimate_job_cost(job)

    if workspace.budget_used_usd + estimated_cost > workspace.budget_limit_usd:
        raise HTTPException(
            status_code=402,
            detail=f"Estimated job cost (${estimated_cost:.2f}) would exceed budget limit. ${workspace.budget_limit_usd - workspace.budget_used_usd:.2f} remaining."
        )

    # Proceed with job creation
    return await create_job_internal(job)
```

#### Cost Estimation

```python
def estimate_job_cost(job: JobCreate) -> float:
    """Estimate job cost before execution"""

    if job.job_type == "SFT_TRAIN":
        # Estimate based on dataset size, model size, epochs
        dataset_size_mb = get_dataset_size(job.dataset_id)
        num_epochs = job.config.get("num_epochs", 3)

        # Rule of thumb: 1 epoch on 1GB dataset takes 1 hour on A10
        estimated_hours = (dataset_size_mb / 1000) * num_epochs

        gpu_type = job.config.get("gpu_type", "A10")
        gpu_cost_per_hour = PRICING[f"GPU_{gpu_type}"]

        return estimated_hours * gpu_cost_per_hour

    elif job.job_type == "RAG_TRAIN":
        # Embedding generation cost
        dataset_size_mb = get_dataset_size(job.dataset_id)
        embedding_model = job.config.get("embedding_model")

        if "openai" in embedding_model:
            # OpenAI charges per token
            estimated_tokens = (dataset_size_mb / 1000) * 1_000_000  # 1M tokens per MB
            return (estimated_tokens / 1000) * 0.0001  # $0.0001 per 1K tokens
        else:
            # Local embedding
            return 0.5 * PRICING["GPU_T4"]  # ~30 minutes on T4

    return 0.0
```

---

### Pricing Comparison (Competitive Analysis)

| Feature | Train-My-AI | RunPod | Lambda Labs | Replicate |
|---------|-------------|--------|-------------|-----------|
| **A10 GPU/hour** | $1.50 | $0.79 | $0.60 | $2.00 |
| **A100 GPU/hour** | $3.00 | $2.89 | $1.10 | $4.50 |
| **BYO GPU** | $0.10/hr fee | ❌ No | ❌ No | ❌ No |
| **No-code UI** | ✅ Yes | ❌ CLI only | ❌ CLI only | ✅ Yes |
| **RAG built-in** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Free tier** | 5 hours/month | ❌ No | ❌ No | $10 credit |

**Value Prop**: We're 30-50% more expensive than bare metal providers, but offer:
1. No-code workflow (saves engineering time)
2. Built-in RAG (would cost extra dev time elsewhere)
3. BYO GPU option (massive savings for power users)
4. Managed MLOps (MLflow, monitoring, deployment)

**Target Margin**: 40% gross margin on compute, 70% on storage

---

### Revenue Projections (Year 1)

**Assumptions**:
- 10,000 sign-ups
- 20% convert to Pro ($49/month)
- Pro users spend $50/month extra on GPU
- 5 Enterprise customers ($5,000/month each)

| Revenue Stream | Monthly | Annual |
|----------------|---------|--------|
| Pro subscriptions (2,000 users × $49) | $98,000 | $1,176,000 |
| Usage fees (2,000 users × $50 avg) | $100,000 | $1,200,000 |
| Enterprise (5 × $5,000) | $25,000 | $300,000 |
| **Total** | **$223,000** | **$2,676,000** |

**Costs**:
| Cost | Monthly | Annual |
|------|---------|--------|
| Cloud (AWS/GCP) | $80,000 | $960,000 |
| Engineering (5 FTE × $150K) | $62,500 | $750,000 |
| Sales & marketing | $20,000 | $240,000 |
| Operations | $10,000 | $120,000 |
| **Total** | **$172,500** | **$2,070,000** |

**Net Income**: $606,000/year (23% margin)

**Break-even**: Month 8 (with $500K seed funding)
