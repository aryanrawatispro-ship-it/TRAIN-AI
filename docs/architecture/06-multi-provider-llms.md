# Multi-Provider LLM Support

## Overview

Train-My-AI supports **all major LLM providers** for both embedding and inference, giving users maximum flexibility and cost optimization.

## Supported Providers

### Inference Models (Chat/Completion)

| Provider | Models | Cost/1M tokens | Use Case |
|----------|--------|----------------|----------|
| **OpenAI** | GPT-4, GPT-4 Turbo, GPT-3.5 | $10-60 | General purpose, highest quality |
| **Anthropic** | Claude 3 Opus, Sonnet, Haiku | $3-75 | Long context, reasoning |
| **Google** | Gemini 1.5 Pro, Flash | $1.25-7 | Multimodal, fast |
| **DeepSeek** | DeepSeek-V2, DeepSeek-Coder | $0.14-0.28 | Ultra-cheap, coding |
| **Zhipu AI** | GLM-4, GLM-4-Air | $0.50-14 | Chinese language |
| **Cohere** | Command R, Command R+ | $0.50-3 | RAG-optimized |
| **Mistral** | Mistral Large, Medium, Small | $2-8 | European, open weights |
| **Groq** | Llama 3, Mixtral (ultra-fast) | $0.27-0.70 | Speed critical |
| **Together AI** | Llama 3, Mixtral, Qwen | $0.20-0.90 | Open models |
| **Replicate** | Any open model | Variable | Experimentation |
| **Local (vLLM)** | Any HF model | Free (GPU cost) | Privacy, control |

### Embedding Models

| Provider | Model | Dimensions | Cost/1M tokens | Use Case |
|----------|-------|------------|----------------|----------|
| **OpenAI** | text-embedding-3-large | 3072 | $0.13 | High quality |
| **OpenAI** | text-embedding-3-small | 1536 | $0.02 | Cost-effective |
| **Cohere** | embed-english-v3.0 | 1024 | $0.10 | Multilingual |
| **Voyage AI** | voyage-2 | 1024 | $0.12 | Retrieval-optimized |
| **Jina AI** | jina-embeddings-v2 | 768 | $0.02 | Fast, cheap |
| **Google** | text-embedding-004 | 768 | $0.025 | Integrated with Gemini |
| **Local (HF)** | bge-large-en-v1.5 | 1024 | Free | Privacy |

---

## Provider Configuration Schema

```yaml
# backend/app/config/providers.yaml
providers:
  openai:
    name: OpenAI
    type: chat
    api_base: https://api.openai.com/v1
    auth_type: bearer
    models:
      - id: gpt-4-turbo
        name: GPT-4 Turbo
        context_length: 128000
        input_cost_per_1m: 10.0
        output_cost_per_1m: 30.0
        supports_vision: true
        supports_function_calling: true
      - id: gpt-3.5-turbo
        name: GPT-3.5 Turbo
        context_length: 16385
        input_cost_per_1m: 0.5
        output_cost_per_1m: 1.5
    rate_limits:
      rpm: 10000
      tpm: 2000000

  anthropic:
    name: Anthropic
    type: chat
    api_base: https://api.anthropic.com/v1
    auth_type: x-api-key
    models:
      - id: claude-3-opus-20240229
        name: Claude 3 Opus
        context_length: 200000
        input_cost_per_1m: 15.0
        output_cost_per_1m: 75.0
        supports_vision: true
      - id: claude-3-sonnet-20240229
        name: Claude 3 Sonnet
        context_length: 200000
        input_cost_per_1m: 3.0
        output_cost_per_1m: 15.0
      - id: claude-3-haiku-20240307
        name: Claude 3 Haiku
        context_length: 200000
        input_cost_per_1m: 0.25
        output_cost_per_1m: 1.25

  deepseek:
    name: DeepSeek
    type: chat
    api_base: https://api.deepseek.com/v1
    auth_type: bearer
    models:
      - id: deepseek-chat
        name: DeepSeek V2
        context_length: 32768
        input_cost_per_1m: 0.14
        output_cost_per_1m: 0.28
        supports_function_calling: true
      - id: deepseek-coder
        name: DeepSeek Coder
        context_length: 16384
        input_cost_per_1m: 0.14
        output_cost_per_1m: 0.28

  zhipuai:
    name: Zhipu AI (GLM)
    type: chat
    api_base: https://open.bigmodel.cn/api/paas/v4
    auth_type: bearer
    models:
      - id: glm-4
        name: GLM-4
        context_length: 128000
        input_cost_per_1m: 14.0
        output_cost_per_1m: 14.0
        supports_chinese: true
      - id: glm-4-air
        name: GLM-4-Air
        context_length: 128000
        input_cost_per_1m: 0.14
        output_cost_per_1m: 0.14

  google:
    name: Google Gemini
    type: chat
    api_base: https://generativelanguage.googleapis.com/v1beta
    auth_type: query_param  # ?key=...
    models:
      - id: gemini-1.5-pro
        name: Gemini 1.5 Pro
        context_length: 1000000
        input_cost_per_1m: 3.5
        output_cost_per_1m: 10.5
        supports_vision: true
        supports_audio: true
      - id: gemini-1.5-flash
        name: Gemini 1.5 Flash
        context_length: 1000000
        input_cost_per_1m: 0.35
        output_cost_per_1m: 1.05

  groq:
    name: Groq (Ultra-Fast)
    type: chat
    api_base: https://api.groq.com/openai/v1
    auth_type: bearer
    models:
      - id: llama3-70b-8192
        name: Llama 3 70B
        context_length: 8192
        input_cost_per_1m: 0.59
        output_cost_per_1m: 0.79
        tokens_per_second: 750  # Ultra-fast!
      - id: mixtral-8x7b-32768
        name: Mixtral 8x7B
        context_length: 32768
        input_cost_per_1m: 0.27
        output_cost_per_1m: 0.27

  cohere:
    name: Cohere
    type: chat
    api_base: https://api.cohere.ai/v1
    auth_type: bearer
    models:
      - id: command-r-plus
        name: Command R+
        context_length: 128000
        input_cost_per_1m: 3.0
        output_cost_per_1m: 15.0
        supports_rag: true
      - id: command-r
        name: Command R
        context_length: 128000
        input_cost_per_1m: 0.5
        output_cost_per_1m: 1.5

  mistral:
    name: Mistral AI
    type: chat
    api_base: https://api.mistral.ai/v1
    auth_type: bearer
    models:
      - id: mistral-large-latest
        name: Mistral Large
        context_length: 32000
        input_cost_per_1m: 8.0
        output_cost_per_1m: 24.0
      - id: mistral-medium-latest
        name: Mistral Medium
        context_length: 32000
        input_cost_per_1m: 2.7
        output_cost_per_1m: 8.1
```

---

## Unified Provider Abstraction

```python
# backend/app/services/llm_providers/base.py
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

@dataclass
class Message:
    role: str  # "system", "user", "assistant"
    content: str

@dataclass
class ChatCompletionResponse:
    id: str
    model: str
    content: str
    finish_reason: str
    usage: Dict[str, int]  # {"prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30}
    provider: str

class LLMProvider(ABC):
    """Base class for all LLM providers"""

    def __init__(self, api_key: str):
        self.api_key = api_key

    @abstractmethod
    async def chat_completion(
        self,
        model: str,
        messages: List[Message],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        stream: bool = False,
        **kwargs
    ) -> ChatCompletionResponse:
        """Generate chat completion"""
        pass

    @abstractmethod
    async def embed(
        self,
        texts: List[str],
        model: str,
        **kwargs
    ) -> List[List[float]]:
        """Generate embeddings"""
        pass

    @abstractmethod
    def get_pricing(self, model: str) -> Dict[str, float]:
        """Get pricing info for model"""
        pass


# backend/app/services/llm_providers/openai_provider.py
import openai
from .base import LLMProvider, Message, ChatCompletionResponse

class OpenAIProvider(LLMProvider):
    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.client = openai.AsyncOpenAI(api_key=api_key)

    async def chat_completion(
        self,
        model: str,
        messages: List[Message],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> ChatCompletionResponse:

        response = await self.client.chat.completions.create(
            model=model,
            messages=[{"role": m.role, "content": m.content} for m in messages],
            temperature=temperature,
            max_tokens=max_tokens,
            **kwargs
        )

        return ChatCompletionResponse(
            id=response.id,
            model=response.model,
            content=response.choices[0].message.content,
            finish_reason=response.choices[0].finish_reason,
            usage={
                "prompt_tokens": response.usage.prompt_tokens,
                "completion_tokens": response.usage.completion_tokens,
                "total_tokens": response.usage.total_tokens
            },
            provider="openai"
        )

    async def embed(self, texts: List[str], model: str = "text-embedding-3-small") -> List[List[float]]:
        response = await self.client.embeddings.create(
            model=model,
            input=texts
        )
        return [item.embedding for item in response.data]


# backend/app/services/llm_providers/anthropic_provider.py
import anthropic
from .base import LLMProvider, Message, ChatCompletionResponse

class AnthropicProvider(LLMProvider):
    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.client = anthropic.AsyncAnthropic(api_key=api_key)

    async def chat_completion(
        self,
        model: str,
        messages: List[Message],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> ChatCompletionResponse:

        # Separate system message
        system_msg = next((m.content for m in messages if m.role == "system"), None)
        user_messages = [{"role": m.role, "content": m.content} for m in messages if m.role != "system"]

        response = await self.client.messages.create(
            model=model,
            system=system_msg,
            messages=user_messages,
            temperature=temperature,
            max_tokens=max_tokens,
            **kwargs
        )

        return ChatCompletionResponse(
            id=response.id,
            model=response.model,
            content=response.content[0].text,
            finish_reason=response.stop_reason,
            usage={
                "prompt_tokens": response.usage.input_tokens,
                "completion_tokens": response.usage.output_tokens,
                "total_tokens": response.usage.input_tokens + response.usage.output_tokens
            },
            provider="anthropic"
        )


# backend/app/services/llm_providers/deepseek_provider.py
import httpx
from .base import LLMProvider, Message, ChatCompletionResponse

class DeepSeekProvider(LLMProvider):
    """DeepSeek uses OpenAI-compatible API"""

    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.api_base = "https://api.deepseek.com/v1"

    async def chat_completion(
        self,
        model: str,
        messages: List[Message],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> ChatCompletionResponse:

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.api_base}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": model,
                    "messages": [{"role": m.role, "content": m.content} for m in messages],
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    **kwargs
                }
            )
            data = response.json()

        return ChatCompletionResponse(
            id=data["id"],
            model=data["model"],
            content=data["choices"][0]["message"]["content"],
            finish_reason=data["choices"][0]["finish_reason"],
            usage=data["usage"],
            provider="deepseek"
        )


# backend/app/services/llm_providers/zhipuai_provider.py
import httpx
from .base import LLMProvider, Message, ChatCompletionResponse

class ZhipuAIProvider(LLMProvider):
    """GLM (ChatGLM) provider"""

    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.api_base = "https://open.bigmodel.cn/api/paas/v4"

    async def chat_completion(
        self,
        model: str,
        messages: List[Message],
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> ChatCompletionResponse:

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.api_base}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": model,
                    "messages": [{"role": m.role, "content": m.content} for m in messages],
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    **kwargs
                }
            )
            data = response.json()

        return ChatCompletionResponse(
            id=data["id"],
            model=data["model"],
            content=data["choices"][0]["message"]["content"],
            finish_reason=data["choices"][0]["finish_reason"],
            usage=data["usage"],
            provider="zhipuai"
        )


# backend/app/services/llm_providers/factory.py
from typing import Dict, Type
from .base import LLMProvider
from .openai_provider import OpenAIProvider
from .anthropic_provider import AnthropicProvider
from .deepseek_provider import DeepSeekProvider
from .zhipuai_provider import ZhipuAIProvider
# ... import others

PROVIDER_REGISTRY: Dict[str, Type[LLMProvider]] = {
    "openai": OpenAIProvider,
    "anthropic": AnthropicProvider,
    "deepseek": DeepSeekProvider,
    "zhipuai": ZhipuAIProvider,
    "google": GoogleProvider,
    "groq": GroqProvider,
    "cohere": CohereProvider,
    "mistral": MistralProvider,
}

def get_provider(provider_name: str, api_key: str) -> LLMProvider:
    """Factory to get provider instance"""
    if provider_name not in PROVIDER_REGISTRY:
        raise ValueError(f"Unknown provider: {provider_name}")

    return PROVIDER_REGISTRY[provider_name](api_key=api_key)
```

---

## Smart Router (Auto-Select Best Provider)

```python
# backend/app/services/llm_router.py
from typing import List, Optional
from .llm_providers.base import LLMProvider, Message
from .llm_providers.factory import get_provider

class LLMRouter:
    """Intelligent routing between providers based on cost, latency, quality"""

    def __init__(self):
        self.providers = {}

    async def route_request(
        self,
        messages: List[Message],
        user_preferences: dict,
        workspace_id: str
    ):
        """Route to best provider based on criteria"""

        # Get user's API keys
        available_providers = await self.get_available_providers(workspace_id)

        # Selection criteria
        criteria = user_preferences.get("criteria", "balanced")

        if criteria == "cheapest":
            provider = self.select_cheapest(available_providers, messages)
        elif criteria == "fastest":
            provider = self.select_fastest(available_providers)
        elif criteria == "highest_quality":
            provider = self.select_highest_quality(available_providers)
        else:  # balanced
            provider = self.select_balanced(available_providers, messages)

        return await provider.chat_completion(
            model=provider.default_model,
            messages=messages
        )

    def select_cheapest(self, providers, messages):
        """Select provider with lowest cost for this request"""
        estimated_tokens = self.estimate_tokens(messages)

        costs = []
        for provider_name, provider_info in providers.items():
            pricing = provider_info['pricing']
            cost = (estimated_tokens['input'] * pricing['input_cost_per_1m'] / 1_000_000 +
                   estimated_tokens['output'] * pricing['output_cost_per_1m'] / 1_000_000)
            costs.append((cost, provider_name))

        cheapest = min(costs, key=lambda x: x[0])
        return get_provider(cheapest[1], providers[cheapest[1]]['api_key'])

    def select_fastest(self, providers):
        """Select provider with lowest latency"""
        # Groq is typically fastest
        if "groq" in providers:
            return get_provider("groq", providers["groq"]['api_key'])
        return self.select_default(providers)

    def select_highest_quality(self, providers):
        """Select highest quality provider"""
        # Priority: Claude Opus > GPT-4 > others
        if "anthropic" in providers:
            return get_provider("anthropic", providers["anthropic"]['api_key'])
        elif "openai" in providers:
            return get_provider("openai", providers["openai"]['api_key'])
        return self.select_default(providers)
```

---

## Database Updates

```sql
-- Add provider tracking to models table
ALTER TABLE models ADD COLUMN provider VARCHAR(50);
ALTER TABLE models ADD COLUMN provider_model_id VARCHAR(255);

-- Add to secrets table
ALTER TABLE secrets ALTER COLUMN provider TYPE VARCHAR(50);
-- New providers: OPENAI, ANTHROPIC, DEEPSEEK, ZHIPUAI, GOOGLE, GROQ, COHERE, MISTRAL

-- Provider usage tracking
CREATE TABLE provider_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,

    provider VARCHAR(50) NOT NULL,
    model VARCHAR(255) NOT NULL,

    input_tokens INTEGER NOT NULL,
    output_tokens INTEGER NOT NULL,
    total_tokens INTEGER NOT NULL,

    cost_usd DECIMAL(10, 6) NOT NULL,
    latency_ms INTEGER,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_provider_usage_workspace ON provider_usage(workspace_id, created_at DESC);
CREATE INDEX idx_provider_usage_provider ON provider_usage(provider);
```

---

## Updated API Endpoints

```yaml
# POST /v1/workspaces/{workspace_id}/secrets
# Store API key for any provider
{
  "name": "My DeepSeek Key",
  "provider": "deepseek",
  "key": "sk-..."
}

# POST /v1/chat/completions (Unified endpoint)
{
  "messages": [
    {"role": "user", "content": "Explain quantum computing"}
  ],
  "provider": "deepseek",  # or "auto" for smart routing
  "model": "deepseek-chat",
  "temperature": 0.7,
  "max_tokens": 500
}

# GET /v1/providers (List all available providers + user's configured ones)
{
  "providers": [
    {
      "id": "openai",
      "name": "OpenAI",
      "configured": true,
      "models": [...],
      "supports_chat": true,
      "supports_embeddings": true
    },
    {
      "id": "deepseek",
      "name": "DeepSeek",
      "configured": true,
      "models": [...]
    },
    {
      "id": "anthropic",
      "name": "Anthropic",
      "configured": false  # User hasn't added API key
    }
  ]
}

# GET /v1/providers/pricing (Compare pricing across providers)
{
  "comparisons": [
    {
      "provider": "deepseek",
      "model": "deepseek-chat",
      "input_cost_per_1m": 0.14,
      "output_cost_per_1m": 0.28,
      "total_cost_for_100k_tokens": 0.042
    },
    {
      "provider": "openai",
      "model": "gpt-3.5-turbo",
      "input_cost_per_1m": 0.5,
      "output_cost_per_1m": 1.5,
      "total_cost_for_100k_tokens": 0.2
    }
  ]
}
```

---

## Frontend Provider Selector

```typescript
// frontend/components/ProviderSelector.tsx
export function ProviderSelector({ onSelect }) {
  const { data: providers } = useProviders();

  return (
    <Select onValueChange={onSelect}>
      <SelectTrigger>
        <SelectValue placeholder="Select LLM provider" />
      </SelectTrigger>
      <SelectContent>
        <SelectGroup label="Configured Providers">
          {providers?.configured.map(p => (
            <SelectItem key={p.id} value={p.id}>
              <div className="flex items-center justify-between w-full">
                <span>{p.name}</span>
                <span className="text-xs text-muted-foreground">
                  from ${p.cheapest_model_cost}/1M
                </span>
              </div>
            </SelectItem>
          ))}
        </SelectGroup>

        <SelectSeparator />

        <SelectGroup label="Available Providers">
          {providers?.unconfigured.map(p => (
            <SelectItem key={p.id} value={p.id} disabled>
              <div className="flex items-center gap-2">
                <span className="text-muted-foreground">{p.name}</span>
                <Badge variant="outline">Add API Key</Badge>
              </div>
            </SelectItem>
          ))}
        </SelectGroup>

        <SelectSeparator />

        <SelectItem value="auto">
          <div className="flex items-center gap-2">
            <Zap className="h-4 w-4" />
            <span>Auto-select (Smart Routing)</span>
          </div>
        </SelectItem>
      </SelectContent>
    </Select>
  );
}
```

---

## Cost Comparison Dashboard

```typescript
// frontend/app/(dashboard)/billing/provider-comparison/page.tsx
export default function ProviderComparisonPage() {
  return (
    <div className="space-y-6">
      <h1>Provider Cost Comparison</h1>

      <Card>
        <CardHeader>
          <CardTitle>Your Monthly Usage by Provider</CardTitle>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={providerUsageData}>
              <XAxis dataKey="provider" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="cost_usd" fill="#8884d8" />
            </BarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Estimated Cost for 1M Tokens</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Provider</TableHead>
                <TableHead>Model</TableHead>
                <TableHead>Input</TableHead>
                <TableHead>Output</TableHead>
                <TableHead>Total</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow>
                <TableCell>DeepSeek</TableCell>
                <TableCell>deepseek-chat</TableCell>
                <TableCell>$0.14</TableCell>
                <TableCell>$0.28</TableCell>
                <TableCell className="font-bold text-green-600">$0.42</TableCell>
              </TableRow>
              <TableRow>
                <TableCell>Groq</TableCell>
                <TableCell>llama3-70b</TableCell>
                <TableCell>$0.59</TableCell>
                <TableCell>$0.79</TableCell>
                <TableCell>$1.38</TableCell>
              </TableRow>
              <TableRow>
                <TableCell>OpenAI</TableCell>
                <TableCell>gpt-3.5-turbo</TableCell>
                <TableCell>$0.50</TableCell>
                <TableCell>$1.50</TableCell>
                <TableCell>$2.00</TableCell>
              </TableRow>
              {/* ... more rows */}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
```

---

## Environment Variables Update

```bash
# .env - Add all provider API keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
DEEPSEEK_API_KEY=sk-...
ZHIPUAI_API_KEY=...
GOOGLE_API_KEY=...
GROQ_API_KEY=gsk_...
COHERE_API_KEY=...
MISTRAL_API_KEY=...
TOGETHER_API_KEY=...

# Smart routing preferences
DEFAULT_PROVIDER=auto  # or specific provider
ROUTING_STRATEGY=balanced  # cheapest, fastest, highest_quality, balanced
```

---

## Benefits

✅ **Cost Optimization**: Auto-route to cheapest provider (DeepSeek @ $0.14/1M vs GPT-4 @ $10/1M)
✅ **Speed**: Use Groq for ultra-fast responses (750 tokens/sec)
✅ **Quality**: Fall back to Claude Opus for complex reasoning
✅ **Redundancy**: If one provider is down, auto-fail-over
✅ **Flexibility**: Users choose per-job or let platform decide
✅ **Transparency**: Track costs per provider in real-time
