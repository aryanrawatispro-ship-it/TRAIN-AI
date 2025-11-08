# Golden Path UX Flow

## 13. User Journey & Wireframes

### Step-by-Step User Flow

```
Sign Up → Create Workspace → Upload Data → Choose Mode →
Select Compute → Configure Training → Train → Evaluate → Deploy → Use
```

---

## Wireframe 1: Dashboard (Post-Login)

```
┌────────────────────────────────────────────────────────────────────────┐
│  Train-My-AI                        [@user]   [Settings]   [Logout]     │
├────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐                                                   │
│  │  My Workspaces ▼ │  [+ New Workspace]                               │
│  └──────────────────┘                                                   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Workspace: "Customer Support Bot"                              │   │
│  │                                                                  │   │
│  │  Storage: ████████░░ 6.8 GB / 10 GB                             │   │
│  │  Budget:  ████░░░░░░ $32 / $100                                 │   │
│  │                                                                  │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐   │   │
│  │  │ Datasets  │  │   Jobs    │  │  Models   │  │  Settings │   │   │
│  │  │           │  │           │  │           │  │           │   │   │
│  │  │     3     │  │     7     │  │     2     │  │           │   │   │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘   │   │
│  │                                                                  │   │
│  │  Recent Activity:                                                │   │
│  │  ✅ "FAQ RAG Model" training completed (2 hours ago)            │   │
│  │  🔄 "Product SFT" running... 45% (ETA: 1.5 hours)               │   │
│  │  ⚠️  Budget alert: 80% of monthly limit reached                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Quick Actions:                                                          │
│  [📂 Upload Dataset]  [🚀 Train Model]  [🔌 Connect GPU]                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Wireframe 2: Upload Data Workflow

### Step 1: Create Dataset

```
┌────────────────────────────────────────────────────────────────────────┐
│  ← Back to Dashboard                                                    │
├────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  📂 Create Dataset                                                       │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                   │  │
│  │  Dataset Name:  [Customer Support FAQs_____________]             │  │
│  │                                                                   │  │
│  │  Description:   [500+ FAQ pairs for chatbot training__________]  │  │
│  │                 [____________________________________________]    │  │
│  │                                                                   │  │
│  │  Training Mode:                                                   │  │
│  │    ◉ RAG (Retrieval-Augmented Generation)                        │  │
│  │        → Build a Q&A system with document retrieval              │  │
│  │                                                                   │  │
│  │    ○ SFT (Supervised Fine-Tuning)                                │  │
│  │        → Fine-tune an LLM on custom prompt/response pairs        │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────┐    │  │
│  │  │  Drag & Drop Files Here                                  │    │  │
│  │  │  or [Browse Files]                                        │    │  │
│  │  │                                                            │    │  │
│  │  │  Supported: PDF, TXT, CSV, JSONL, MD, DOCX               │    │  │
│  │  │  Max 10 GB per workspace                                  │    │  │
│  │  └─────────────────────────────────────────────────────────┘    │  │
│  │                                                                   │  │
│  │  [Cancel]                             [Next: Configure Training] │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Step 2: File Upload Progress

```
┌────────────────────────────────────────────────────────────────────────┐
│  📤 Uploading Files...                                                  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  support_faq.pdf         ████████████████░░ 85% (12 MB / 14 MB)  │  │
│  │  product_docs.txt        ████████████████████ 100% (2.4 MB)      │  │
│  │  customer_emails.csv     ██░░░░░░░░░░░░░░░░ 15% (0.8 MB / 5 MB)  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Total: 18.6 MB / 21.4 MB                                               │
│  Time remaining: ~45 seconds                                             │
│                                                                          │
│  [Pause]  [Cancel Upload]                                               │
└────────────────────────────────────────────────────────────────────────┘
```

### Step 3: Processing

```
┌────────────────────────────────────────────────────────────────────────┐
│  🔄 Processing Dataset...                                               │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  ✅ Files uploaded successfully (3 files, 21.4 MB)               │  │
│  │  🔄 Parsing documents... (2/3 complete)                          │  │
│  │  ⏳ Chunking text... (not started)                               │  │
│  │  ⏳ Validating data... (not started)                             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Estimated time: 3-5 minutes                                             │
│  We'll email you when processing is complete!                            │
│                                                                          │
│  [View Dashboard]                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Wireframe 3: Train Model Wizard

### Step 1: Choose Compute

```
┌────────────────────────────────────────────────────────────────────────┐
│  🚀 Train Model: "Customer Support Bot"                                 │
│                                                                          │
│  Step 1 of 3: Choose Compute                                             │
│  ●──────○──────○                                                         │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  ◉ Use Managed GPU (Recommended for beginners)                   │  │
│  │                                                                   │  │
│  │    Select GPU Type:                                               │  │
│  │    ┌─────────────────────────┐  ┌─────────────────────────┐     │  │
│  │    │  NVIDIA A10             │  │  NVIDIA A100            │     │  │
│  │    │  24 GB VRAM             │  │  40 GB VRAM             │     │  │
│  │    │  $1.50/hour             │  │  $3.00/hour             │     │  │
│  │    │  ✓ Fast training        │  │  ✓ Largest models       │     │  │
│  │    │  ✓ Good for most tasks  │  │  ✓ Production workloads │     │  │
│  │    │  [●] Selected           │  │  [ ] Select             │     │  │
│  │    └─────────────────────────┘  └─────────────────────────┘     │  │
│  │                                                                   │  │
│  │  ○ Use My GPU (Bring Your Own)                                   │  │
│  │                                                                   │  │
│  │    Available Nodes:                                               │  │
│  │    • RTX 4090 (24 GB) - ONLINE     [Use This]                    │  │
│  │    • No other nodes connected      [+ Connect GPU]               │  │
│  │                                                                   │  │
│  │    💰 Platform fee: $0.10/hour (95% cheaper than managed!)       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Estimated Cost: ~$3.00 (2 hours on A10)                                │
│  Your Budget: $68 remaining                                              │
│                                                                          │
│  [Back]                                                  [Next: Configure]│
└────────────────────────────────────────────────────────────────────────┘
```

### Step 2: Configure Training (RAG)

```
┌────────────────────────────────────────────────────────────────────────┐
│  🚀 Train Model: "Customer Support Bot"                                 │
│                                                                          │
│  Step 2 of 3: Configure RAG                                              │
│  ○──────●──────○                                                         │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Embedding Model:                                                 │  │
│  │  ┌────────────────────────────────────────────────────────────┐  │  │
│  │  │  OpenAI text-embedding-3-small  (Fast, cheap)         ▼   │  │  │
│  │  └────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  Chunk Size:          [512▼] tokens                              │  │
│  │  Chunk Overlap:       [50___] tokens                             │  │
│  │                                                                   │  │
│  │  Retrieval Settings:                                              │  │
│  │  Top-K Results:       [5▼]                                       │  │
│  │  Reranker:            [None▼] (Optional: Cohere, Cross-Encoder) │  │
│  │                                                                   │  │
│  │  ⚙️ Advanced Options (Optional)                                  │  │
│  │  [ ] Enable PII redaction                                        │  │
│  │  [ ] Deduplicate chunks                                          │  │
│  │                                                                   │  │
│  │  🔐 API Keys Required:                                           │  │
│  │  OpenAI: [sk-proj-abc123...] ✅ Valid                            │  │
│  │  [+ Add API Key]                                                 │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  [Back]                                                  [Next: Review]   │
└────────────────────────────────────────────────────────────────────────┘
```

### Step 3: Review & Start

```
┌────────────────────────────────────────────────────────────────────────┐
│  🚀 Train Model: "Customer Support Bot"                                 │
│                                                                          │
│  Step 3 of 3: Review & Start                                             │
│  ○──────○──────●                                                         │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  📊 Training Summary                                              │  │
│  │                                                                   │  │
│  │  Dataset:         Customer Support FAQs (21.4 MB, 487 chunks)    │  │
│  │  Mode:            RAG (Retrieval-Augmented Generation)            │  │
│  │  Embedding:       OpenAI text-embedding-3-small                   │  │
│  │  Compute:         NVIDIA A10 (Managed GPU)                        │  │
│  │                                                                   │  │
│  │  Estimated Time:  15-20 minutes                                   │  │
│  │  Estimated Cost:  $0.75                                           │  │
│  │                                                                   │  │
│  │  ✓ API key validated                                             │  │
│  │  ✓ Budget sufficient ($68 remaining)                             │  │
│  │  ✓ GPU available                                                 │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  [ ] Email me when training is complete                                 │
│                                                                          │
│  [Back]                                                  [🚀 Start Training]│
└────────────────────────────────────────────────────────────────────────┘
```

---

## Wireframe 4: Job Monitoring

```
┌────────────────────────────────────────────────────────────────────────┐
│  Job: "Customer Support Bot Training"                  [Cancel Job]     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Status: 🔄 RUNNING                                                      │
│  Progress: ████████████░░░░░░░░ 65%                                      │
│  Started: 2 minutes ago  •  ETA: 1 minute                                │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  📊 Metrics                                                       │  │
│  │                                                                   │  │
│  │  GPU Utilization:   ██████████████░░░░ 72%                       │  │
│  │  VRAM Usage:        15.2 GB / 24 GB                              │  │
│  │  Temperature:       68°C                                          │  │
│  │                                                                   │  │
│  │  Embeddings Generated: 316 / 487                                 │  │
│  │  Current Step: Storing embeddings in vector database...          │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  📜 Live Logs                                             [Pause] │  │
│  │                                                                   │  │
│  │  14:32:05  INFO  Loaded 487 chunks from dataset                  │  │
│  │  14:32:10  INFO  Generating embeddings (batch 1/5)...            │  │
│  │  14:32:45  INFO  Batch 1 complete (100 embeddings)               │  │
│  │  14:33:12  INFO  Batch 2 complete (100 embeddings)               │  │
│  │  14:33:40  INFO  Batch 3 complete (100 embeddings)               │  │
│  │  14:34:05  INFO  Storing embeddings in pgvector...               │  │
│  │  14:34:20  INFO  316/487 embeddings stored                       │  │
│  │  ▌                                                                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  💰 Cost so far: $0.05                                                  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Wireframe 5: Model Playground (Chat Interface)

```
┌────────────────────────────────────────────────────────────────────────┐
│  🎮 Playground: "Customer Support Bot"                 [Share] [Deploy] │
├────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Model Type: RAG  •  Deployed: ✅ Active  •  Endpoint: api.../infer     │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  💬 Chat                                                          │  │
│  │  ┌────────────────────────────────────────────────────────────┐  │  │
│  │  │                                                             │  │  │
│  │  │  You: How do I reset my password?                          │  │  │
│  │  │                                                             │  │  │
│  │  │  Bot: To reset your password, follow these steps:          │  │  │
│  │  │       1. Go to the login page                              │  │  │
│  │  │       2. Click "Forgot Password"                           │  │  │
│  │  │       3. Enter your email address                          │  │  │
│  │  │       4. Check your email for a reset link                 │  │  │
│  │  │                                                             │  │  │
│  │  │       📎 Sources:                                           │  │  │
│  │  │       • support_faq.pdf (page 3, 92% match)                │  │  │
│  │  │       • password_guide.txt (85% match)                     │  │  │
│  │  │                                                             │  │  │
│  │  │                                              Latency: 320ms │  │  │
│  │  │                                                             │  │  │
│  │  └────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  [Type your message...                                      ] [Send]│
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Settings:                                                               │
│  Temperature: [■■■□□□□□□□] 0.7  •  Max Tokens: [256▼]  •  Top-K: [5▼] │
│                                                                          │
│  📊 Usage Today: 47 requests  •  Cost: $0.03                            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Mobile-First Considerations

All screens are responsive (mobile, tablet, desktop):

- **Dashboard**: Stack cards vertically on mobile
- **Upload**: Use native file picker on mobile
- **Training Config**: Collapse advanced options by default
- **Playground**: Full-screen chat on mobile

---

## Accessibility (WCAG 2.1 AA)

- ✅ Keyboard navigation (Tab, Enter, Esc)
- ✅ Screen reader labels (ARIA)
- ✅ Color contrast 4.5:1 minimum
- ✅ Focus indicators visible
- ✅ Error messages descriptive
