# Cognitive AI Bot — Packages with Image, Video & Audio Services

## Assumptions

### Media API costs (2024–2025)

| Service | Provider | Unit | Cost/Unit |
|---------|----------|------|-----------|
| **Image** | Replicate (Flux) / DALL-E 3 | Per image | $0.03 |
| **Video** | Luma Ray2 / Runway | Per 5-sec clip | $0.55 |
| **Audio** | OpenAI TTS / ElevenLabs | Per minute TTS | $0.05 |

### Allocation logic

- Free: No media.
- Starter–Basic: Limited media for trial.
- Pro–Growth: More media for regular use.
- Business+: Higher quotas for teams.
- Enterprise/Elite: Large quotas for heavy usage.

---

## Full Package Table: Tokens | Images | Videos | Audio | Costs | Profit | Margin

### Master table (with media)

| # | Plan | Price | Tokens | Images | Videos | Audio (min) | Chat API | Image API | Video API | Audio API | Perplexity | Infra | **Total cost** | **Profit** | **Margin** |
|---|------|-------|--------|--------|--------|-------------|---------|-----------|-----------|-----------|------------|-------|----------------|-----------|------------|
| 1 | Free | $0 | 10K | 0 | 0 | 0 | $0.01 | $0 | $0 | $0 | $0 | $0.01 | **$0.02** | -$0.02 | — |
| 2 | Starter | $9.99 | 1M | 15 | 2 | 10 | $2.88 | $0.45 | $1.10 | $0.50 | $0.80 | $0.40 | **$6.13** | $3.86 | **39%** |
| 3 | Basic | $19.99 | 3M | 30 | 5 | 25 | $9.10 | $0.90 | $2.75 | $1.25 | $1.50 | $1.00 | **$16.50** | $3.49 | **17%** |
| 4 | Pro | $29.99 | 4.5M | 50 | 10 | 50 | $14.50 | $1.50 | $5.50 | $2.50 | $1.50 | $0.50 | **$26.00** | $3.99 | **13%** |
| 5 | Growth | $49.99 | 7.5M | 100 | 20 | 100 | $21.60 | $3.00 | $11.00 | $5.00 | $5.90 | $1.50 | **$48.00** | $1.99 | **4%** |
| 6 | Growth+ | $79.99 | 12M | 150 | 35 | 150 | $41.00 | $4.50 | $19.25 | $7.50 | $0 | $4.50 | **$76.75** | $3.24 | **4%** |
| 7 | Pro Plus | $99.99 | 15M | 200 | 50 | 200 | $50.40 | $6.00 | $27.50 | $10.00 | $0 | $6.60 | **$100.50** | -$0.51 | **-1%** |
| 8 | Business | $199.99 | 30M | 400 | 100 | 400 | $105.00 | $12.00 | $55.00 | $20.00 | $0 | $9.00 | **$201.00** | -$1.01 | **-1%** |
| 9 | Scale | $299.99 | 50M | 600 | 150 | 600 | $165.00 | $18.00 | $82.50 | $30.00 | $0 | $9.00 | **$304.50** | -$4.51 | **-2%** |
| 10 | Enterprise | $499.99 | 80M | 1000 | 250 | 1000 | $276.00 | $30.00 | $137.50 | $50.00 | $0 | $14.00 | **$507.50** | -$7.51 | **-2%** |
| 11 | Elite | $999.99 | 160M | 1500 | 400 | 1500 | $548.00 | $45.00 | $220.00 | $75.00 | $0 | $27.00 | **$915.00** | $84.99 | **9%** |

**Conclusion:** With current prices, margins collapse or turn negative once media is added. Prices need to rise.

---

## Revised Packages — Price Increases to Maintain ≥42% Margin

### Option A: Add media, raise prices

| # | Plan | **New price** | Tokens | Img | Vid | Audio | Total cost | Profit | Margin |
|---|------|---------------|--------|-----|-----|-------|------------|--------|--------|
| 1 | Free | $0 | 10K | 0 | 0 | 0 | $0.02 | -$0.02 | — |
| 2 | Starter | **$12.99** | 1M | 15 | 2 | 10 | $6.13 | $6.86 | **53%** |
| 3 | Basic | **$29.99** | 3M | 30 | 5 | 25 | $16.50 | $13.49 | **45%** |
| 4 | Pro | **$46.99** | 4.5M | 50 | 10 | 50 | $26.00 | $20.99 | **45%** |
| 5 | Growth | **$84.99** | 7.5M | 100 | 20 | 100 | $48.00 | $36.99 | **44%** |
| 6 | Growth+ | **$134.99** | 12M | 150 | 35 | 150 | $76.75 | $58.24 | **43%** |
| 7 | Pro Plus | **$175.99** | 15M | 200 | 50 | 200 | $100.50 | $75.49 | **43%** |
| 8 | Business | **$349.99** | 30M | 400 | 100 | 400 | $201.00 | $148.99 | **43%** |
| 9 | Scale | **$529.99** | 50M | 600 | 150 | 600 | $304.50 | $225.49 | **43%** |
| 10 | Enterprise | **$879.99** | 80M | 1000 | 250 | 1000 | $507.50 | $372.49 | **42%** |
| 11 | Elite | **$1,599.99** | 160M | 1500 | 400 | 1500 | $915.00 | $684.99 | **43%** |

---

### Option B: Reduce media allocations, keep current prices closer

Target: keep price rises moderate and still hit ~42%.

| # | Plan | Price | Tokens | Img | Vid | Audio | Chat | Media | Other | **Total** | Profit | Margin |
|---|------|-------|--------|-----|-----|-------|------|-------|-------|----------|--------|--------|
| 1 | Free | $0 | 10K | 0 | 0 | 0 | $0.01 | $0 | $0.01 | **$0.02** | -$0.02 | — |
| 2 | Starter | $9.99 | 1M | 5 | 1 | 5 | $3.68 | $0.55 | $0.40 | **$4.63** | $5.36 | **54%** |
| 3 | Basic | $19.99 | 3M | 15 | 3 | 15 | $10.60 | $1.65 | $1.00 | **$13.25** | $6.74 | **34%** |
| 4 | Pro | $29.99 | 4.5M | 25 | 5 | 25 | $15.50 | $2.75 | $0.50 | **$18.75** | $11.24 | **37%** |
| 5 | Growth | $49.99 | 7.5M | 50 | 10 | 50 | $21.60 | $5.50 | $1.50 | **$28.60** | $21.39 | **43%** ✓ |
| 6 | Growth+ | $79.99 | 12M | 75 | 15 | 75 | $41.00 | $8.25 | $4.50 | **$53.75** | $26.24 | **33%** |
| 7 | Pro Plus | $99.99 | 15M | 100 | 25 | 100 | $50.40 | $13.75 | $6.60 | **$70.75** | $29.24 | **29%** |
| 8 | Business | $199.99 | 30M | 200 | 50 | 200 | $105.00 | $36.00 | $9.00 | **$150.00** | $49.99 | **25%** |
| 9 | Scale | $299.99 | 50M | 300 | 75 | 300 | $165.00 | $54.00 | $9.00 | **$228.00** | $71.99 | **24%** |
| 10 | Enterprise | $499.99 | 80M | 500 | 125 | 500 | $276.00 | $90.00 | $14.00 | **$380.00** | $119.99 | **24%** |
| 11 | Elite | $999.99 | 160M | 800 | 200 | 800 | $548.00 | $144.00 | $27.00 | **$719.00** | $280.99 | **28%** |

Even with lower media, higher tiers fall short of 42%. Enterprise plans need either higher prices or lower media.

---

### Option C: Media as add‑on (base plans unchanged)

Keep existing chat‑only pricing and margin. Offer media as paid add‑on packs:

| Add-on pack | Images | Videos | Audio | Cost to you | Price to user | Margin |
|-------------|--------|--------|-------|-------------|---------------|--------|
| **Starter media** | 20 | 5 | 30 min | $2.35 | $4.99 | 53% |
| **Pro media** | 75 | 15 | 90 min | $7.05 | $14.99 | 53% |
| **Unlimited media** | 200 | 50 | 300 min | $23.50 | $49.99 | 53% |

Base plans stay at current prices and margins. Media revenue is incremental.

---

## Recommended Structure: Hybrid

- Keep base plans and prices as today (chat + tokens).
- Add **small included media** per plan (for trial and low usage).
- Add **media add‑on packs** for heavier use.

### Included media by plan (no price change)

| Plan | Images | Videos | Audio | Added cost | New total cost | New margin |
|------|--------|--------|-------|------------|----------------|------------|
| Free | 0 | 0 | 0 | $0 | $0.02 | — |
| Starter | 3 | 0 | 0 | $0.09 | $4.17 | 58% |
| Basic | 10 | 1 | 5 min | $0.58 | $12.18 | 39% |
| Pro | 20 | 2 | 10 min | $1.16 | $17.66 | 41% |
| Growth | 30 | 5 | 20 min | $2.40 | $31.40 | 37% |
| Growth+ | 50 | 10 | 40 min | $4.50 | $50.00 | 37% |
| Pro Plus | 75 | 15 | 60 min | $6.75 | $63.75 | 36% |
| Business | 100 | 25 | 100 min | $11.25 | $125.25 | 37% |
| Scale | 150 | 40 | 150 min | $16.88 | $190.88 | 36% |
| Enterprise | 250 | 60 | 250 min | $28.13 | $318.13 | 36% |
| Elite | 400 | 100 | 400 min | $45.00 | $620.00 | 38% |

Margins stay in the mid‑30s to low‑40s. Heavier media users pay for add‑on packs.

---

## Summary Table: Final Recommended Full Packages

*(With modest included media and optional add‑ons; base prices unchanged)*

| # | Plan | Price | Tokens | Images | Videos | Audio | Chat cost | Media cost | Other | **Total cost** | **Profit** | **Margin** |
|---|------|-------|--------|--------|--------|-------|------------|------------|-------|----------------|-----------|------------|
| 1 | Free | $0 | 10K | 0 | 0 | 0 | $0.01 | $0 | $0.01 | **$0.02** | -$0.02 | — |
| 2 | Starter | $9.99 | 1M | 3 | 0 | 0 | $3.68 | $0.09 | $0.40 | **$4.17** | $5.82 | **58%** ✓ |
| 3 | Basic | $19.99 | 3M | 10 | 1 | 5 min | $10.60 | $0.58 | $1.00 | **$12.18** | $7.81 | **39%** |
| 4 | Pro | $29.99 | 4.5M | 20 | 2 | 10 min | $15.50 | $1.16 | $0.50 | **$17.16** | $12.83 | **43%** ✓ |
| 5 | Growth | $49.99 | 7.5M | 30 | 5 | 20 min | $21.60 | $2.40 | $1.50 | **$25.50** | $24.49 | **49%** ✓ |
| 6 | Growth+ | $79.99 | 12M | 50 | 10 | 40 min | $41.00 | $4.50 | $4.50 | **$50.00** | $29.99 | **37%** |
| 7 | Pro Plus | $99.99 | 15M | 75 | 15 | 60 min | $50.40 | $6.75 | $6.60 | **$63.75** | $36.24 | **36%** |
| 8 | Business | $199.99 | 30M | 100 | 25 | 100 min | $105.00 | $11.25 | $9.00 | **$125.25** | $74.74 | **37%** |
| 9 | Scale | $299.99 | 50M | 150 | 40 | 150 min | $165.00 | $16.88 | $9.00 | **$190.88** | $109.11 | **36%** |
| 10 | Enterprise | $499.99 | 80M | 250 | 60 | 250 min | $276.00 | $28.13 | $14.00 | **$318.13** | $181.86 | **36%** |
| 11 | Elite | $999.99 | 160M | 400 | 100 | 400 min | $548.00 | $45.00 | $27.00 | **$620.00** | $379.99 | **38%** ✓ |

---

## Media Cost Reference

| Item | Cost |
|------|------|
| Image (Flux/Replicate) | $0.03 |
| Video (5‑sec, Luma) | $0.55 |
| Audio (1 min TTS, OpenAI) | $0.05 |

---

## Notes

1. Starter and Pro/Growth keep strong margins.
2. Basic is borderline; consider slightly fewer images or a small price increase.
3. Enterprise tiers are 36–38%; to reach 42% you’d need to trim media or raise prices.
4. Media add‑on packs make it easy to improve margins on heavy media users.
