# APIs & Models — Integration Plan

This document lists the APIs we want to add and the models we want to offer per plan tier.

---

## 1. APIs We Want to Add

### 1.1 OpenAI

| Item | Value |
|------|-------|
| **API URL** | `https://api.openai.com/v1` |
| **Auth** | Bearer token (API key) |
| **Docs** | https://platform.openai.com/docs |
| **Chat endpoint** | `POST /chat/completions` |

**Models to integrate:**
- GPT-3.5 Turbo
- GPT-4o Mini
- GPT-4o
- GPT-4 Turbo

---

### 1.2 Anthropic (Claude)

| Item | Value |
|------|-------|
| **API URL** | `https://api.anthropic.com/v1` |
| **Auth** | `x-api-key` header, `anthropic-version` header |
| **Docs** | https://docs.anthropic.com |
| **Chat endpoint** | `POST /messages` |

**Models to integrate:**
- Claude 3 Haiku
- Claude 3.5 Sonnet
- Claude 3 Opus

---

### 1.3 Google (Gemini)

| Item | Value |
|------|-------|
| **API URL** | `https://generativelanguage.googleapis.com/v1beta` |
| **Auth** | API key (query param or header) |
| **Docs** | https://ai.google.dev/docs |
| **Chat endpoint** | `POST /models/{model}:generateContent` |

**Models to integrate:**
- Gemini 1.5 Flash
- Gemini 1.5 Pro
- Gemini 2.0 Flash

---

### 1.4 DeepSeek

| Item | Value |
|------|-------|
| **API URL** | `https://api.deepseek.com/v1` |
| **Auth** | Bearer token (API key) |
| **Docs** | https://platform.deepseek.com/docs |
| **Chat endpoint** | `POST /chat/completions` (OpenAI-compatible) |

**Models to integrate:**
- DeepSeek Chat
- DeepSeek Coder
- DeepSeek-V3

---

### 1.5 Perplexity

| Item | Value |
|------|-------|
| **API URL** | `https://api.perplexity.ai` |
| **Auth** | Bearer token (API key) |
| **Docs** | https://docs.perplexity.ai |
| **Chat endpoint** | `POST /chat/completions` |

**Models to integrate:**
- Sonar (basic search)
- Sonar Pro (premium search)

---

### 1.6 xAI (Grok)

| Item | Value |
|------|-------|
| **API URL** | `https://api.x.ai/v1` |
| **Auth** | Bearer token (API key) |
| **Docs** | https://docs.x.ai |
| **Chat endpoint** | `POST /chat/completions` (OpenAI-compatible) |

**Models to integrate:**
- Grok 2

---

### 1.7 Mistral AI

| Item | Value |
|------|-------|
| **API URL** | `https://api.mistral.ai/v1` |
| **Auth** | Bearer token (API key) |
| **Docs** | https://docs.mistral.ai |
| **Chat endpoint** | `POST /chat/completions` (OpenAI-compatible) |

**Models to integrate:**
- Mistral Small (budget, fast)
- Mistral Large (premium, state-of-the-art)

---

## 2. Models We Want to Offer (By Plan Tier)

### Free

| Provider | Model | Notes |
|----------|-------|-------|
| OpenAI | GPT-3.5 Turbo | Legacy budget |
| Google | Gemini 1.5 Flash | Very cheap |
| Perplexity | Sonar (basic) | 5 searches/month |

---

### Starter ($9.99)

| Provider | Model | Notes |
|----------|-------|-------|
| OpenAI | GPT-3.5 Turbo | |
| OpenAI | GPT-4o Mini | Budget |
| Google | Gemini 1.5 Flash | |
| Anthropic | Claude 3 Haiku | |
| Perplexity | Sonar | 20 searches/month |
| DeepSeek | DeepSeek Chat | |
| **Mistral AI** | **Mistral Small** | Budget, fast |

---

### Basic ($19.99)

| Provider | Model | Notes |
|----------|-------|-------|
| OpenAI | GPT-4o Mini | |
| OpenAI | GPT-4 Turbo | High-end |
| Google | Gemini 1.5 Flash | |
| Google | Gemini 1.5 Pro | |
| Anthropic | Claude 3 Haiku | |
| Anthropic | Claude 3.5 Sonnet | |
| Perplexity | Sonar | 50 searches/month |
| DeepSeek | DeepSeek Chat | |
| DeepSeek | DeepSeek Coder | |
| xAI | Grok 2 | |
| **Mistral AI** | **Mistral Small** | |
| **Mistral AI** | **Mistral Large** | Premium |

---

### Pro ($29.99)

| Provider | Model | Notes |
|----------|-------|-------|
| OpenAI | GPT-4o | Premium |
| OpenAI | GPT-4 Turbo | |
| Google | Gemini 1.5 Pro | |
| Google | Gemini 2.0 Flash | |
| Anthropic | Claude 3.5 Sonnet | |
| Anthropic | Claude 3 Opus | Top-tier |
| Perplexity | Sonar | 80 searches/month |
| DeepSeek | DeepSeek-V3 | |
| xAI | Grok 2 | |
| **Mistral AI** | **Mistral Small** | |
| **Mistral AI** | **Mistral Large** | |

---

### Pro+ ($49.99)

| Provider | Model | Notes |
|----------|-------|-------|
| All Pro models | | |
| Early access | GPT-5, Claude 4, etc. | When available |
| Perplexity | Sonar | 100 searches/month |

---

### Team ($79.99)

| Provider | Model | Notes |
|----------|-------|-------|
| All Pro+ models | | Per team member access |

---

### Team+ ($99.99)

| Provider | Model | Notes |
|----------|-------|-------|
| All models | | Full catalog |

---

### Business ($199.99)

| Provider | Model | Notes |
|----------|-------|-------|
| All models | | Reserved model capacity (faster during peak) |

---

### Business+ ($299.99)

| Provider | Model | Notes |
|----------|-------|-------|
| All models | | Reserved capacity, beta access |

---

### Enterprise ($499.99)

| Provider | Model | Notes |
|----------|-------|-------|
| All models | | Dedicated model instances, private beta |

---

### Enterprise Premium ($999.99)

| Provider | Model | Notes |
|----------|-------|-------|
| All models | | Dedicated capacity, first access to new models |

---

## 3. Full Model Catalog (All Providers)

| Provider | Model ID | Display Name | Tier Availability |
|----------|----------|--------------|-------------------|
| **OpenAI** | gpt-3.5-turbo | GPT-3.5 Turbo | Free, Starter |
| | gpt-4o-mini | GPT-4o Mini | Starter, Basic |
| | gpt-4o | GPT-4o | Pro+ |
| | gpt-4-turbo | GPT-4 Turbo | Basic, Pro+ |
| **Anthropic** | claude-3-haiku | Claude 3 Haiku | Starter, Basic |
| | claude-3-5-sonnet | Claude 3.5 Sonnet | Basic, Pro+ |
| | claude-3-opus | Claude 3 Opus | Pro+ |
| **Google** | gemini-1.5-flash | Gemini 1.5 Flash | Free, Starter, Basic |
| | gemini-1.5-pro | Gemini 1.5 Pro | Basic, Pro+ |
| | gemini-2.0-flash | Gemini 2.0 Flash | Pro+ |
| **DeepSeek** | deepseek-chat | DeepSeek Chat | Starter, Basic |
| | deepseek-coder | DeepSeek Coder | Basic+ |
| | deepseek-v3 | DeepSeek-V3 | Pro+ |
| **Perplexity** | sonar | Sonar | All (quota by plan) |
| | sonar-pro | Sonar Pro | Pro+ |
| **xAI** | grok-2 | Grok 2 | Basic+ |
| **Mistral AI** | mistral-small | Mistral Small | Starter+ |
| | mistral-large | Mistral Large | Basic+ |

---

## 4. Integration Checklist

- [ ] OpenAI: API key, chat completions
- [ ] Anthropic: API key, messages API
- [ ] Google: API key, generateContent
- [ ] DeepSeek: API key, OpenAI-compatible endpoint
- [ ] Perplexity: API key, search-augmented chat
- [ ] xAI: API key, OpenAI-compatible endpoint
- [ ] **Mistral AI: API key, OpenAI-compatible chat completions**

---

## 5. Token Pricing Reference (Per 1M Tokens)

| Provider | Model | Input | Output |
|----------|-------|-------|--------|
| OpenAI | GPT-4o | $2.50 | $10.00 |
| OpenAI | GPT-4 Turbo | $10.00 | $30.00 |
| OpenAI | GPT-4o Mini | $0.15 | $0.60 |
| OpenAI | GPT-3.5 Turbo | $0.50 | $1.50 |
| Anthropic | Claude 3.5 Sonnet | $3.00 | $15.00 |
| Anthropic | Claude 3 Opus | $15.00 | $75.00 |
| Anthropic | Claude 3 Haiku | $0.25 | $1.25 |
| Google | Gemini 1.5 Pro | $1.25 | $5.00 |
| Google | Gemini 1.5 Flash | $0.075 | $0.30 |
| Google | Gemini 2.0 Flash | ~$0.10 | ~$0.40 |
| DeepSeek | DeepSeek Chat/Coder | $0.28 | $0.42 |
| DeepSeek | DeepSeek-V3 | Varies | Varies |
| Perplexity | Sonar | $1.00 | $1.00 |
| Perplexity | Sonar Pro | $3.00 | $15.00 |
| xAI | Grok 2 | $2–3 | $10–15 |
| **Mistral AI** | **Mistral Small** | **$0.20** | **$0.60** |
| **Mistral AI** | **Mistral Large** | **$2.00** | **$6.00** |
