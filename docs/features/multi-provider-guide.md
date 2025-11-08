# Multi-Provider LLM Guide

## Quick Start

### 1. Add Your API Keys

```bash
# Via Web UI
Dashboard → Settings → API Keys → Add Provider

# Via API
POST /v1/workspaces/{workspace_id}/secrets
{
  "name": "My DeepSeek Key",
  "provider": "deepseek",
  "key": "sk-..."
}
```

### 2. Use Any Provider

```python
# Python example
import requests

response = requests.post(
    "https://api.train-my-ai.com/v1/chat/completions",
    headers={"Authorization": f"Bearer {your_api_token}"},
    json={
        "provider": "deepseek",  # or "openai", "anthropic", "groq", etc.
        "model": "deepseek-chat",
        "messages": [
            {"role": "user", "content": "Explain quantum computing"}
        ],
        "temperature": 0.7
    }
)
```

### 3. Let Platform Choose (Smart Routing)

```python
response = requests.post(
    "https://api.train-my-ai.com/v1/chat/completions",
    json={
        "provider": "auto",  # Platform selects best provider
        "routing_strategy": "cheapest",  # or "fastest", "highest_quality", "balanced"
        "messages": [...]
    }
)
```

## Cost Comparison (per 1M tokens)

| Provider | Model | Input | Output | Total | Best For |
|----------|-------|-------|--------|-------|----------|
| **DeepSeek** | deepseek-chat | $0.14 | $0.28 | **$0.42** | 💰 Ultra-cheap |
| **Groq** | llama3-8b | $0.05 | $0.10 | **$0.15** | ⚡ Ultra-fast (900 tok/s) |
| **Groq** | llama3-70b | $0.59 | $0.79 | $1.38 | ⚡ Fast + quality |
| **Mistral** | mistral-small | $1.00 | $3.00 | $4.00 | 🇪🇺 European |
| **OpenAI** | gpt-3.5-turbo | $0.50 | $1.50 | $2.00 | ⚖️ Balanced |
| **Anthropic** | claude-haiku | $0.25 | $1.25 | $1.50 | 📄 Long context |
| **Anthropic** | claude-sonnet | $3.00 | $15.00 | $18.00 | 🧠 Smart |
| **Google** | gemini-flash | $0.35 | $1.05 | $1.40 | 🎥 Multimodal |
| **Cohere** | command-r | $0.50 | $1.50 | $2.00 | 🔍 RAG-optimized |

## Provider Recommendations

### For Different Use Cases

#### 📊 High Volume Chatbots
```yaml
Recommended: DeepSeek + Groq
- DeepSeek: $0.42/1M tokens (70x cheaper than GPT-4)
- Groq: 750+ tokens/sec (instant responses)
- Fallback: GPT-3.5 Turbo
```

#### 🧠 Complex Reasoning
```yaml
Recommended: Claude Opus or GPT-4
- Claude 3 Opus: Best reasoning, 200K context
- GPT-4 Turbo: Excellent for analysis
- Fallback: Claude Sonnet (cheaper)
```

#### 💻 Code Generation
```yaml
Recommended: DeepSeek Coder
- Specifically trained for code
- $0.14/1M tokens (ultra-cheap)
- Supports 100+ languages
- Fallback: GPT-4
```

#### 🇨🇳 Chinese Language
```yaml
Recommended: GLM-4 or GLM-4-Air
- Native Chinese understanding
- GLM-4-Air: $0.14/1M (cheap)
- GLM-4: $14/1M (high quality)
```

#### 📚 RAG (Document Q&A)
```yaml
Recommended: Cohere Command R+
- Built-in citation support
- RAG-optimized architecture
- Alternative: Claude with long context
```

#### 🎥 Multimodal (Image/Video)
```yaml
Recommended: Gemini 1.5 Pro
- 1M token context (can analyze entire videos)
- Vision + audio support
- $3.50/1M input tokens
```

#### ⚡ Real-Time Streaming
```yaml
Recommended: Groq
- 750-900 tokens/second
- Llama 3 70B: High quality + speed
- Perfect for live chat
```

## Smart Routing Strategies

### 1. Cheapest

Automatically selects the cheapest provider for your query:

```python
{
  "provider": "auto",
  "routing_strategy": "cheapest",
  # Result: Usually DeepSeek or Groq Llama-3-8B
}
```

**Savings**: Up to **95% cheaper** than GPT-4

### 2. Fastest

Selects provider with lowest latency:

```python
{
  "provider": "auto",
  "routing_strategy": "fastest",
  # Result: Groq (750+ tokens/sec)
}
```

### 3. Highest Quality

Best performance regardless of cost:

```python
{
  "provider": "auto",
  "routing_strategy": "highest_quality",
  # Result: Claude Opus or GPT-4
}
```

### 4. Balanced (Default)

Optimizes for quality/cost/speed:

```python
{
  "provider": "auto",
  "routing_strategy": "balanced",
  # Uses scoring algorithm to pick best overall
}
```

## Embeddings Comparison

| Provider | Model | Dimensions | Cost/1M | Best For |
|----------|-------|------------|---------|----------|
| **Jina AI** | jina-embeddings-v2 | 768 | $0.02 | Ultra-cheap |
| **OpenAI** | text-embedding-3-small | 1536 | $0.02 | Balanced |
| **Google** | text-embedding-004 | 768 | $0.025 | Gemini integration |
| **Cohere** | embed-english-v3 | 1024 | $0.10 | Multilingual |
| **Voyage** | voyage-2 | 1024 | $0.12 | RAG-optimized |
| **OpenAI** | text-embedding-3-large | 3072 | $0.13 | Highest quality |

## Provider-Specific Features

### OpenAI
✅ Function calling
✅ Vision (GPT-4 Vision)
✅ DALL-E integration
✅ Best ecosystem

### Anthropic (Claude)
✅ 200K context (longest)
✅ Excellent reasoning
✅ Strong safety
✅ Citations support

### DeepSeek
✅ Ultra-cheap ($0.14/1M)
✅ Strong at coding
✅ Fast inference
✅ Chinese company

### Groq
✅ Ultra-fast (750 tok/s)
✅ Real-time streaming
✅ Open models (Llama, Mixtral)
✅ Predictable latency

### Google Gemini
✅ 1M+ context window
✅ Multimodal (vision + audio)
✅ Free tier available
✅ Integrated with Google Cloud

### Zhipu AI (GLM)
✅ Native Chinese support
✅ Multimodal (GLM-4V)
✅ Long context (128K)
✅ Competitive pricing

## Real-World Cost Examples

### Example 1: Customer Support Chatbot (1M messages/month)

| Provider | Cost/month | Savings vs GPT-4 |
|----------|------------|------------------|
| DeepSeek | $42 | **99.3%** 💰 |
| Groq Llama-3-8B | $150 | **97.5%** |
| GPT-3.5 Turbo | $2,000 | **66%** |
| Claude Haiku | $1,500 | **75%** |
| GPT-4 Turbo | $6,000 | - |

**Winner**: DeepSeek saves **$5,958/month** vs GPT-4!

### Example 2: Code Assistant (100K requests/month)

| Provider | Cost/month | Quality Rating |
|----------|------------|----------------|
| DeepSeek Coder | $14 | ⭐⭐⭐⭐ |
| Groq Llama-3-70B | $138 | ⭐⭐⭐⭐ |
| GPT-4 | $3,000 | ⭐⭐⭐⭐⭐ |

**Winner**: DeepSeek Coder (214x cheaper than GPT-4, excellent quality)

### Example 3: RAG Document Q&A (10K queries/month)

| Provider | Cost/month | Best Feature |
|----------|------------|--------------|
| Cohere Command R | $20 | Native citations |
| Claude Sonnet | $180 | 200K context |
| GPT-3.5 Turbo | $20 | Balanced |

**Winner**: Tie between Cohere and GPT-3.5 (depends on citation needs)

## Migration Guide

### From OpenAI to DeepSeek (95% savings)

```python
# Before (OpenAI)
response = openai.ChatCompletion.create(
    model="gpt-3.5-turbo",
    messages=[{"role": "user", "content": "Hello"}]
)

# After (DeepSeek via Train-My-AI)
response = requests.post(
    "https://api.train-my-ai.com/v1/chat/completions",
    json={
        "provider": "deepseek",
        "model": "deepseek-chat",
        "messages": [{"role": "user", "content": "Hello"}]
    }
)
# Save $1,958/month on 1M requests!
```

### Multi-Provider Fallback

```python
providers = ["groq", "deepseek", "openai"]  # Try in order

for provider in providers:
    try:
        response = chat_completion(provider=provider, ...)
        break
    except Exception as e:
        print(f"{provider} failed: {e}")
        continue
```

## FAQ

**Q: Which provider is cheapest?**
A: DeepSeek at $0.14/1M input tokens (70x cheaper than GPT-4)

**Q: Which is fastest?**
A: Groq at 750+ tokens/second (5-10x faster than others)

**Q: Can I use multiple providers in one workspace?**
A: Yes! Add API keys for all providers, switch per-request

**Q: What happens if a provider is down?**
A: Use `"provider": "auto"` with fallback routing

**Q: Do you support local/self-hosted models?**
A: Yes! Use vLLM to run any HuggingFace model on your GPU

**Q: How do I track costs per provider?**
A: Dashboard → Billing → Provider Breakdown
