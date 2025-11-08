"""
Multi-provider LLM support for Train-My-AI

Supported providers:
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude 3)
- DeepSeek (V2, Coder)
- Zhipu AI (GLM-4)
- Google (Gemini)
- Groq (Ultra-fast Llama/Mixtral)
- Cohere (Command R)
- Mistral AI
"""

from .factory import get_provider, list_providers, get_pricing
from .router import LLMRouter

__all__ = ['get_provider', 'list_providers', 'get_pricing', 'LLMRouter']
