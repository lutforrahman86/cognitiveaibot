# API Cost & Profit Analysis

## Real API Costs Per Token (2024–2025)

All prices are **per 1 million tokens** (input / output). Sourced from official provider pricing pages.

---

### OpenAI

| Model | Input ($/1M) | Output ($/1M) | Use Case |
|-------|--------------|---------------|----------|
| GPT-4o | $2.50 | $10.00 | Premium |
| GPT-4 Turbo | $10.00 | $30.00 | High-end |
| GPT-4o Mini | $0.15 | $0.60 | Budget |
| GPT-3.5 Turbo | $0.50 | $1.50 | Legacy budget |

---

### Anthropic

| Model | Input ($/1M) | Output ($/1M) | Use Case |
|-------|--------------|---------------|----------|
| Claude 3.5 Sonnet | $3.00 | $15.00 | Premium |
| Claude 3 Opus | $15.00 | $75.00 | Top-tier |
| Claude 3 Haiku | $0.25 | $1.25 | Budget |

---

### Google (Gemini)

| Model | Input ($/1M) | Output ($/1M) | Use Case |
|-------|--------------|---------------|----------|
| Gemini 1.5 Pro | $1.25 | $5.00 | Mid-premium |
| Gemini 1.5 Flash | $0.075 | $0.30 | Very cheap |
| Gemini 2.0 Flash | ~$0.10 | ~$0.40 | Cheap |

---

### DeepSeek

| Model | Input ($/1M) | Output ($/1M) | Use Case |
|-------|--------------|---------------|----------|
| DeepSeek Chat | $0.28 | $0.42 | Budget |
| DeepSeek Coder | $0.28 | $0.42 | Budget |

---

### Perplexity

| Model | Input ($/1M) | Output ($/1M) | Use Case |
|-------|--------------|---------------|----------|
| Sonar (basic) | $1.00 | $1.00 | Search |
| Sonar Pro | $3.00 | $15.00 | Premium search |

---

### xAI (Grok)

| Model | Input ($/1M) | Output ($/1M) | Use Case |
|-------|--------------|---------------|----------|
| Grok 2 | $2.00–3.00 | $10.00–15.00 | Premium |

---

### Mistral AI

| Model | Input ($/1M) | Output ($/1M) | Use Case |
|-------|--------------|---------------|----------|
| Mistral Small | $0.20 | $0.60 | Budget, fast |
| Mistral Large | $2.00 | $6.00 | Premium, state-of-the-art |

---

## Blended Cost by Plan (Estimated Usage Mix)

Assumptions:
- **Input : Output ratio** ≈ 1 : 2 (user sends ~1 token, AI returns ~2)
- **Model mix** varies by plan (cheaper plans use more Flash/mini, premium plans use more Pro/Sonnet)
- **Infra & ops**: ~$0.50–2.00/user depending on plan
- **Perplexity** treated as fixed cost per search (~$0.02–0.05/search)

---

### Cost per 1M Input + 2M Output Tokens (Typical Conversation)

| Model Tier | Blended $/3M tokens | Example Models |
|------------|---------------------|-----------------|
| Budget | ~$0.50–1.00 | Flash, Mini, DeepSeek |
| Mid | ~$5–8 | GPT-4o, Gemini Pro, Sonnet |
| Premium | ~$15–25 | GPT-4 Turbo, Claude Opus |

---

### Plan-by-Plan Cost & Profit

#### 1. FREE — $0/month

| Item | Value |
|------|-------|
| Tokens (I/O) | 7K / 3K (10K total) |
| Blended cost/1M tokens | ~$2.00 (Flash, 3.5) |
| **API cost** | **~$0.01** |
| Infra + ops | ~$0.01 |
| **Total cost** | **~$0.02/user** |
| Price | $0 |
| **Profit** | **-$0.02 (loss leader)** |

---

#### 2. STARTER — $9.99/month ✓ 59% margin

| Item | Value |
|------|-------|
| Messages | 1,366 |
| Tokens (I/O) | 683K / 342K (1.03M total) |
| Blended cost/1M tokens | ~$3.98 |
| **API cost** | **~$2.88** |
| Perplexity (50) | ~$0.80 |
| Infra + ops | ~$0.40 |
| **Total cost** | **~$4.08** |
| Price | $9.99 |
| **Profit** | **$5.91** |
| **Margin** | **59%** ✓ |

---

#### 3. BASIC — $19.99/month ✓ 42% margin

| Item | Value |
|------|-------|
| Messages | 4,100 |
| Tokens (I/O) | 2M / 1M (3M total) |
| Blended cost/1M tokens | ~$3.87 |
| **API cost** | **~$9.10** |
| Perplexity (50) | ~$1.50 |
| Infra + ops | ~$1.00 |
| **Total cost** | **~$11.60** |
| Price | $19.99 |
| **Profit** | **$8.39** |
| **Margin** | **42%** ✓ |

---

#### 4. PRO — $29.99/month ✓ 45% margin

| Item | Value |
|------|-------|
| Messages | 12,300 |
| Tokens (I/O) | 2.93M / 1.47M (4.4M total) |
| Blended cost/1M tokens | ~$3.75 |
| **API cost** | **~$14.50** |
| Perplexity (100) | ~$1.50 |
| Infra + ops | ~$0.50 |
| **Total cost** | **~$16.50** |
| Price | $29.99 |
| **Profit** | **$13.49** |
| **Margin** | **45%** ✓ |

---

#### 5. PRO+ — $49.99/month ✓ 42% margin

| Item | Value |
|------|-------|
| Messages | 15,100 |
| Tokens (I/O) | 3.6M / 1.8M (5.4M total) |
| Blended cost/1M tokens | ~$5.37 |
| **API cost** | **~$21.60** |
| Perplexity (200) | ~$5.90 |
| Infra + ops | ~$1.50 |
| **Total cost** | **~$29.00** |
| Price | $49.99 |
| **Profit** | **$20.99** |
| **Margin** | **42%** ✓ |

---

#### 6. TEAM — $79.99/month ✓ 43% margin

| Item | Value |
|------|-------|
| Messages | 32,800 (shared) |
| Tokens (I/O) | 9.1M / 4.6M (13.7M total, pooled) |
| Blended cost/1M tokens | ~$3.32 |
| **API cost** | **~$41.00** |
| Infra + ops (5 seats) | ~$4.50 |
| **Total cost** | **~$45.50** |
| Price | $79.99 |
| **Profit** | **$34.49** |
| **Margin** | **43%** ✓ |

---

#### 7. TEAM+ — $99.99/month ✓ 43% margin

| Item | Value |
|------|-------|
| Messages | 43,700 (shared) |
| Tokens (I/O) | 11.2M / 5.6M (16.8M total) |
| Blended cost/1M tokens | ~$3.39 |
| **API cost** | **~$50.40** |
| Infra + ops (8 seats) | ~$6.60 |
| **Total cost** | **~$57.00** |
| Price | $99.99 |
| **Profit** | **$42.99** |
| **Margin** | **43%** ✓ |

---

#### 8. BUSINESS — $199.99/month ✓ 43% margin

| Item | Value |
|------|-------|
| Messages | 109,300 |
| Tokens (I/O) | 28.7M / 14.3M (43M total) |
| Blended cost/1M tokens | ~$2.65 |
| **API cost** | **~$105.00** |
| Infra + ops (15 seats) | ~$9.00 |
| **Total cost** | **~$114.00** |
| Price | $199.99 |
| **Profit** | **$85.99** |
| **Margin** | **43%** ✓ |

---

#### 9. BUSINESS+ — $299.99/month ✓ 42% margin

| Item | Value |
|------|-------|
| Messages | 177,600 |
| Tokens (I/O) | 48M / 24M (72M total) |
| **API cost** | **~$165.00** |
| Infra + ops (25 seats) | ~$9.00 |
| **Total cost** | **~$174.00** |
| Price | $299.99 |
| **Profit** | **$125.99** |
| **Margin** | **42%** ✓ |

---

#### 10. ENTERPRISE — $499.99/month ✓ 42% margin

| Item | Value |
|------|-------|
| Messages | 410,000 |
| Tokens (I/O) | 112M / 56M (168M total) |
| **API cost** | **~$276.00** |
| Infra + ops (50 seats) | ~$14.00 |
| **Total cost** | **~$290.00** |
| Price | $499.99 |
| **Profit** | **$209.99** |
| **Margin** | **42%** ✓ |

---

#### 11. ENTERPRISE PREMIUM — $999.99/month ✓ 42% margin

| Item | Value |
|------|-------|
| Messages | 956,000 |
| Tokens (I/O) | 260M / 130M (390M total) |
| **API cost** | **~$548.00** |
| Infra + ops (150 seats) | ~$27.00 |
| **Total cost** | **~$575.00** |
| Price | $999.99 |
| **Profit** | **$424.99** |
| **Margin** | **42%** ✓ |

---

## Summary: What We Charge vs. Real Cost (Revised for ≥42% Margin)

**All paid plans achieve ≥42% profit.** Basic = 4,100 messages; ratio ≈1.24× applied to all plans.

| # | Tier | Plan | Price | Est. Cost | Profit | Margin |
|---|------|------|-------|-----------|--------|--------|
| 1 | Free | Free | $0 | $0.02 | -$0.02 | N/A |
| 2 | Individual | Starter | $9.99 | $4.08 | $5.91 | **59%** ✓ |
| 3 | | Basic | $19.99 | $11.60 | $8.39 | **42%** ✓ |
| 4 | | Pro | $29.99 | $16.50 | $13.49 | **45%** ✓ |
| 5 | | Pro+ | $49.99 | $29.00 | $20.99 | **42%** ✓ |
| 6 | Team | Team | $79.99 | $45.50 | $34.49 | **43%** ✓ |
| 7 | | Team+ | $99.99 | $57.00 | $42.99 | **43%** ✓ |
| 8 | Business | Business | $199.99 | $114.00 | $85.99 | **43%** ✓ |
| 9 | Enterprise | Business+ | $299.99 | $174.00 | $125.99 | **42%** ✓ |
| 10 | | Enterprise | $499.99 | $290.00 | $209.99 | **42%** ✓ |
| 11 | | Enterprise Premium | $999.99 | $575.00 | $424.99 | **42%** ✓ |

---

## Key Changes for ≥42% Margin

**Scaling: Basic = 4,100 messages; ratio 4,100/3,300 (≈1.24×) applied to all plans.**

| Plan | Messages | Tokens (I/O) | Price | Cost | Profit | Margin |
|------|----------|--------------|-------|------|--------|--------|
| Free | 20 | 10K (7K/3K) | $0 | $0.02 | -$0.02 | — |
| Starter | 1,366 | 1.03M (683K/342K) | $9.99 | $4.08 | $5.91 | **59%** |
| Basic | 4,100 | 3M (2M/1M) | $19.99 | $11.60 | $8.39 | **42%** |
| Pro | 12,300 | 4.4M (2.93M/1.47M) | $29.99 | $16.50 | $13.49 | **45%** |
| Pro+ | 15,100 | 5.4M (3.6M/1.8M) | $49.99 | $29.00 | $20.99 | **42%** |
| Team | 32,800 | 13.7M (9.1M/4.6M) | $79.99 | $45.50 | $34.49 | **43%** |
| Team+ | 43,700 | 16.8M (11.2M/5.6M) | $99.99 | $57.00 | $42.99 | **43%** |
| Business | 109,300 | 43M (28.7M/14.3M) | $199.99 | $114.00 | $85.99 | **43%** |
| Business+ | 177,600 | 72M (48M/24M) | $299.99 | $174.00 | $125.99 | **42%** |
| Enterprise | 410,000 | 168M (112M/56M) | $499.99 | $290.00 | $209.99 | **42%** |
| Enterprise Premium | 956,000 | 390M (260M/130M) | $999.99 | $575.00 | $424.99 | **42%** |

---

## Recommendations

### 1. Volume Discounts

Negotiate 20–40% off list price with providers at scale. This can support higher token limits at the same margin.

### 2. Optimize Model Mix

- Steer users toward cheaper models (Flash, DeepSeek, Mistral Small, GPT-4o-mini) where quality is sufficient
- Use caching and prompt optimization to cut input costs

### 3. Overage Revenue

Charge $0.01 per 1,000 extra tokens—adds revenue when users exceed limits.

### 4. Annual Billing

Offer 2 months free (pay 10, get 12) to improve retention; margin stays healthy.

---

## Token Cost Reference (Quick Lookup)

| Provider | Model | Input ($/1M) | Output ($/1M) |
|----------|-------|--------------|---------------|
| OpenAI | GPT-4o | 2.50 | 10.00 |
| OpenAI | GPT-4o Mini | 0.15 | 0.60 |
| Anthropic | Claude 3.5 Sonnet | 3.00 | 15.00 |
| Anthropic | Claude 3 Haiku | 0.25 | 1.25 |
| Google | Gemini 1.5 Pro | 1.25 | 5.00 |
| Google | Gemini 1.5 Flash | 0.075 | 0.30 |
| DeepSeek | DeepSeek Chat | 0.28 | 0.42 |
| Perplexity | Sonar | 1.00 | 1.00 |
| Perplexity | Sonar Pro | 3.00 | 15.00 |
| xAI | Grok 2 | 2.00–3.00 | 10.00–15.00 |
| Mistral AI | Mistral Small | 0.20 | 0.60 |
| Mistral AI | Mistral Large | 2.00 | 6.00 |
