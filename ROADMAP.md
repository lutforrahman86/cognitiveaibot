# CognitiveAI Bot — Feature List & Development Plan

Last updated: 2026-10-05, after Phase 3 (the developer API); Phases 1 done, 2 and 3 at 90%
Starting point: [PROGRESS.md](PROGRESS.md) (2026-08-09, with corrections).

## The target

1. **One product on web, mobile and desktop** where a user can work with 100+ AI models
   across every modality: text, code, image, audio and video.
2. **A paid developer API** sold as subscription packages. A subscriber activates an API
   key and gets the same models the apps offer.

---

## Status — 2026-10-05

| Measure | Morning audit | After Phase 0 | After Phase 1 | Phase 2 | Now (Phase 3) |
|---|---|---|---|---|---|
| **Whole roadmap** (65 features, equal weight) | 8% | 14% | 20% | 22% | **29%** |
| **P0 features** (the 26 needed for the first paid launch) | 14% | 28% | 41% | 48% | **66%** |
| **Planned build effort** (weighted by the phase estimates below) | 4% | 14% | 23% | 28% | **39%**. About **21.2 of ~34.5 weeks** remain |
| Feature count | 1 done · 20 partial · 44 not started | 3 · 25 · 37 | 4 · 27 · 34 | 4 · 27 · 34 | **7** done · **28** partial · **30** not started |

| Area | Morning | After Phase 0 | After Phase 1 | Phase 2 | Now |
|---|---|---|---|---|---|
| A. AI Gateway & model platform | 4% | 9% | 26% | 25% | 25% |
| B. End-user apps | 14% | 16% | 16% | 18% | 18% |
| C. Developer API product | 0% | 1% | 2% | 2% | 38% |
| D. Billing & plans | 3% | 6% | 6% | 29% | 29% |
| E. Admin & operations | 6% | 6% | 21% | 21% | 21% |
| F. Platform foundations | 14% | 54% | 57% | 57% | 61% |

Area A dipped because the second route per model (through OpenRouter) was removed under
Decision 1, so A10 has no fallback route left.

**What this means.** The text gateway is built. Every reply now holds its worst-case
cost in credits, then charges exactly what it used and logs it, and admins can see our
provider cost against the charge. The catalog lists 45 current models, all called
**directly** at their provider (Decision 1: no aggregators). Only OpenAI, Anthropic and
Google are connected so far; the other 25 models wait for direct integrations. **The first
real reply arrived on 2026-10-05** (OpenAI, billed exactly), which completes Phase 1. The
Google key is rejected and there's no Anthropic key yet. Credit prices are placeholders (1 credit =
US$0.01, priced at cost) until Decision 4. Billing (buying credits) and the developer API
are next.

### Done on 2026-10-05: Phase 3, the developer API (text)

- **API keys.** Created and revoked on the new Developer API page. A key (`sk-cog-…`) is
  shown once and stored only as a hash, and each key records when it was last used.
  Only plans with API access can create or use keys (Decision 5: no free API tier).
- **OpenAI-compatible `/v1`.** `GET /v1/models`, `GET /v1/models/{id}` and
  `POST /v1/chat/completions`, streamed or not, in OpenAI's formats, on the same gateway
  as the apps: plan check, rate limit, credit hold, direct provider call, exact charge.
  Anthropic models get system messages and stop sequences in Anthropic's own fields.
- **Nothing an API caller sends or receives is stored** (Decision 6); only billing
  metadata is.
- **Rate limits.** Requests and tokens per minute per account, set per plan (admins edit
  them in the Plans tab), counted in Redis, with OpenAI-style `429` and headers.
- **Developer dashboard and docs.** Usage by model, key and day, and a public
  `/docs/api` page with a quickstart for Python, JavaScript and curl.
- **Verified for real:** the official OpenAI SDK listed models and got a normal and a
  streamed reply from OpenAI through `/v1`, each billed exactly from OpenAI's token
  counts and shown on the dashboard. **Tests: 46 → 56**, including the SDK itself, rate
  limits on real Redis, and checks that refused requests never reach a provider or cost
  anything.

### Done on 2026-10-05: Phase 1 complete, pricing set (Decision 4)

- **First real reply.** A message in the web chat to GPT-4o-mini streamed a real answer
  from OpenAI. It was billed from OpenAI's own token counts (19 in, 7 out), exactly
  705 micro-credits, the hold was released, and the admin request log shows our provider
  cost beside the charge. Time to first token is now measured from the provider call
  (it was missing the provider's wait before).
- **30% markup.** Every model's credit price is provider cost × 130 credits per 1M tokens
  (at 1 credit = US$0.01). A test checks this for every priced model.
- **Plan credits expire each period.** The ledger tracks which part of a balance is the
  current period's plan credits. Replies spend those first; a renewal expires what's left
  and grants the new period's; without a renewal, a sweep expires them a day after the
  period ends (a grace period so renewals, which Stripe charges about an hour late,
  never leave a gap). Expiry never takes credits a reply in progress is holding. Top-up
  credits never expire. The Upgrade page shows how many plan credits expire and when.

### Done on 2026-10-05: direct providers only (Decision 1)

- **OpenRouter removed.** The gateway calls every model at its own provider with that
  provider's key and has no aggregator route at all. The adapter config, the
  `aggregator_model_id` column (dropped by a migration), `OPENROUTER_API_KEY` and the
  aggregator ids in the catalog snapshot are gone. A test checks that a model with no
  direct integration is refused without any provider being called.
- **`gpt-oss-120b` retired.** OpenAI doesn't serve it through its API, so it has no direct
  route. It's kept inactive, not deleted, so old chats keep its name. The catalog is now
  45 models.
- **What can be called:** OpenAI 12 of 12 (key valid), Google 5 (key set but rejected by
  Google), Anthropic 5 (no key). DeepSeek, Mistral, xAI, Perplexity, Qwen, Moonshot,
  Z.ai and MiniMax (21 models) need direct integrations; most use OpenAI's request format,
  so the existing adapter can serve them. Meta's 2 Llama models have no first-party paid
  API, so they need a decision.

### Done on 2026-10-05: Phase 2 started, plans and Stripe billing

- **Plan catalog (D1).** A `plans` table holds subscriptions (monthly or yearly, with
  credits each paid period) and one-off top-ups. Admins create and edit plans in a new
  **Plans** tab; plans are deactivated, never deleted. `GET /api/plans` lists active ones
  publicly. Four **placeholder** plans are seeded for development only (Decision 4 is open).
- **Stripe checkout, portal and webhooks (D2).** `POST /api/billing/checkout` opens Stripe
  Checkout at the price stored in our catalog; `POST /api/billing/portal` opens Stripe's
  billing portal for card changes, cancelling and invoices. **Credits are granted only by
  Stripe's signed webhook**, through the existing ledger, as a new `purchase` entry type.
- **Money rules, each tested:** a payment can grant at most once, even when Stripe delivers
  it twice or through two different events (a unique payment reference on every grant,
  also enforced by the database). A forged or unsigned webhook changes nothing. Subscription
  credits come per paid invoice, so a failed renewal grants nothing. The plan stays usable
  while Stripe retries, then ends when Stripe cancels it; paid credits are kept. A late,
  out-of-order event can't revive a cancelled subscription. A running subscription keeps
  the price and credits it was bought at, even if an admin edits the plan.
- **Web.** The Upgrade page is real: current plan and renewal date, balance, monthly plans,
  top-ups, recent credit activity, a notice after returning from checkout that waits for
  the credits to land, and "Manage billing". Running out of credits in chat now links
  there, and the sidebar shows the real plan name.
- **Tests: 35 → 44**, against a local stand-in for Stripe's API (no Stripe account needed).

**Not yet:** a real Stripe payment (no Stripe keys yet); RevenueCat for mobile purchases
(D3, Phase 4); receipts, tax and proration (D4); plan-based rate limits and model tiers
(C3, Phase 3). *Later the same day:* Decision 4 set a 30% markup and made plan credits
expire each period (see below).

### Done on 2026-10-05: Phase 1, the text gateway

- **Credit ledger (A5).** Balances are integer micro-credits with a database rule that
  they can't go negative. Each reply **holds its worst-case cost first** and is refused
  with `402` if the user can't cover a minimal reply. A low balance shortens the reply
  instead of overspending. The charge is never more than the hold; any shortfall is
  logged as "unbilled". Failed calls cost nothing, stopped replies cost what was produced,
  and holds left by a crash are released automatically.
- **Per-request log (A4).** One `request_logs` row per call: route, model, tokens
  (marked when estimated), hold, charge, our provider cost, time to first token, duration,
  outcome.
- **46 priced models (A2, A3).** The catalog was rebuilt from OpenRouter's public list
  on 2026-10-05. **6 of our original 13 models are retired by their providers**, including
  Gemini 2.0 Flash, mapped earlier today; they are kept inactive so old chats keep their
  names. Each model stores both our cost and its credit price.
- **Four providers.** OpenAI and Google (direct), **Anthropic** (new adapter on the
  official SDK) and **OpenRouter**, which reaches all 46 with one key. A model goes direct
  when that provider's key is set, otherwise through OpenRouter. *(Later the same day,
  OpenRouter was removed under Decision 1; see above.)*
- **Admin (E2, E3).** User balances and "Adjust credits" (a reason is required, and the
  acting admin is recorded); a provider-cost-vs-charged margin view by model and route;
  a recent-requests endpoint; model prices and the reason a model can't be called.
- **Web.** The live credit balance is shown in the chat sidebar and updates after every
  reply; a clear message appears when credits run out.
- **A real intermittent bug found and fixed:** under garbage collection, Node's `fetch`
  cancelled a reply's body before the server started reading it, so **replies could
  silently come back empty**. Proven with forced GC (20 of 20 lost before the fix, 0 after),
  and a regression test now runs with GC forced. The bug was in this morning's code.
- **Tests: 19 → 35**, all passing on repeated runs, covering every money rule above,
  parallel holds, crash cleanup, Anthropic streaming/errors/refusals, routing, admin
  credits and trial credits.

### Done earlier on 2026-10-05: Phase 0 and the first provider

- **Migrations replace `sync({ alter: true })` (F1).** A baseline migration captures the
  schema, and the dev database was migrated with every row count unchanged. The baseline
  is built from the real schema; a fresh database is built and tested from it on every
  test run.
- **125 duplicate unique constraints removed.** Every restart under `alter: true` had
  added another copy of each unique index; the dev database went from 131 to 6.
- **Backend test suite, 19 tests (F2, partly).** Covers auth, chat privacy, migrations
  and the whole AI-reply path (streaming, context, provider errors, mid-reply failure,
  Stop, one reply at a time), run against a mock provider so no key or cost is needed.
- **AI gateway with one adapter for OpenAI-compatible APIs (A1, A3, partly).** OpenAI is
  wired; Google's OpenAI-compatible endpoint is configured but untested. Models carry a
  `provider_model_id` (A2), and the model list says which ones can be called.
- **Web chat is real (B1).** The placeholder reply is gone. Replies stream in, can be
  stopped, keep partial text, and title the chat from its first message. Models that
  can't be called are greyed out.
- **Token usage is recorded from real replies (A4, partly)**, per message and in the
  daily rollup. Clients can no longer write assistant messages or token counts directly.
- **Fabricated data removed from mobile (F5).** That covers the fake "Pro Member" badges
  and billing dates, the hardcoded names, the sample usage figures, the invented history
  and the pre-filled demo chat. Each now shows the honest state, and tests check that
  none of the strings come back.
- **RevenueCat config fixed (D3, partly).** The copied "Flora Diary" entitlement and its
  test key are gone, along with the subscription screen's "Flora Diary Pro" title and the
  Flora Diary setup doc. Keys now come from build-time settings, and a missing key turns
  purchases off instead of crashing startup.
- **CI added (F6, partly):** backend tests, web build, Flutter analyze and tests. It has
  **not run on GitHub yet**: the repo has no commits or remote. The same commands pass
  locally.
- **Bugs fixed along the way:** chat rename crashed (`Chat.update` called itself);
  `npm run seed` on a fresh database created no models and `GET /api/models/:id` crashed
  (an `AIModel.findAll` override broke Sequelize's `findOne`); the seed duplicated
  chats; the chat page grew with the sidebar instead of scrolling inside it; failed
  first messages left empty chats behind; mobile analyzer warnings went from 5 to 0.

**Still needed from you:** a working `GEMINI_API_KEY` and an `ANTHROPIC_API_KEY` in
`backend/.env` (OpenAI's key works), then `npm run models:verify` from
`cognitiveaibot_web/backend` checks the model ids. Also Stripe test keys
(`STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET`; `stripe listen --forward-to
localhost:3000/api/billing/webhook` gives a local webhook secret) to make the first test
payment. Also needed: access to the new iPhone simulator, so the phone layout of the
mobile changes can be checked visually (the desktop layout is covered by widget tests).

**How it was scored.** Every item was checked against the code on 2026-10-05:

| Score | Meaning |
|---|---|
| ✅ 100% | Done and verified |
| 🟡 75% | Mostly done, small gaps |
| 🟡 50% | About half: e.g. backend done but no UI, or one of two clients done |
| 🟡 25% | A real, working piece exists, but most of the item is missing |
| 🟡 10% | Groundwork only: a table/field, a UI mock-up, or an SDK stub that can't do the job yet |
| ⬜ 0% | Not started |

Area and overall figures are plain averages, with every item weighted equally. The
effort figure weights each phase by its estimated weeks.

### Already built (the baseline the roadmap builds on)

- **Web:** marketing landing page; email/password sign-in with Google and GitHub OAuth
  (enabled once keys are set); chat screen with a model picker fed from the database;
  chats and messages saved to Postgres; profile editing with avatar upload; admin screens
  for overview, models, users, subscriptions and usage (all read-only).
- **Backend:** JWT auth and an admin role check; chat/message API with full-text search;
  settings, usage and usage-limit APIs; a "check for new models" call to OpenAI.
- **Mobile:** five polished screens (Home, Chat, History, Models, Usage, Settings) on a
  clean architecture; RevenueCat SDK wired in code.

### Found during the morning audit

1. **The web chat UI has no search, rename or delete.** The backend supports all three,
   but `Chat.vue` never calls them. PROGRESS.md said otherwise and has been corrected.
   *Still open. Rename was also broken in the backend, which is now fixed.*
2. ~~**The backend runs `sequelize.sync({ alter: true })` on every startup.**~~ *Fixed:
   replaced by migrations.*
3. ~~**The seed script isn't idempotent.**~~ *Fixed for future runs.* The dev database
   still holds the three copies of each demo chat; reseed a fresh database to clear them.
4. **15 mobile buttons are wired to empty handlers (`onPressed: () {}`).** These include
   Copy, Like, Dislike and Regenerate on every chat message. *Still open.*
5. **Mobile hardcodes 11 subscription plans** (Free through "Elite" at $999.99) in
   `subscription_plans.dart`. These should come from the server's plan catalog (item D1).
   *Still open.*
6. **The API has no rate limiting or security headers.** There's no rate limiter and no
   `helmet`. *Still open; replies are limited to one at a time per user, which is all so
   far.* This must exist before compute or money sits behind the API (items C3 and E4).
7. *Correction to PROGRESS.md:* the mobile app never read the device owner's name. "Lutfor
   Rahman" (and "Alex Rivera" elsewhere) were hardcoded strings. Both are removed.

---

## The architectural decision everything else depends on

**Build one AI Gateway, and send every client through it.** That means our own web,
mobile and desktop apps *and* paying API customers. Our apps are simply the gateway's
first customers.

```
  Web (Vue)    Mobile (Flutter)    Desktop    Customer code (OpenAI SDK / curl)
      \              |                |                 /
       \      session token (JWT)     |        API key (sk-cog-…)
        ▼            ▼                ▼                ▼
   ┌──────────────────────── AI Gateway  /v1/… ─────────────────────────┐
   │ authenticate → check plan & model tier → rate limit → hold credits │
   │ → look up model route → provider adapter → stream / queue job      │
   │ → meter actual usage → settle credits → write request log          │
   └────────────────────────────────────────────────────────────────────┘
        │              │              │                   │
     OpenAI        Anthropic       Google        More providers, each direct
     (direct)      (direct)        (direct)      (DeepSeek, Mistral, xAI, …) →
                                                  text/image/audio/video models
```

Why it has to be this way:

- **API parity becomes structural.** "Our API must provide all the models like our app"
  is true automatically, because there is only one model pipeline.
- Routing, metering, billing, rate limiting, safety and failover are each built once.
- Every app request exercises the same code paths that paying API customers depend on.

### How to realistically reach 100+ models

- **Direct integrations only** (Decision 1). Every model is called at its own provider
  with that provider's key; no aggregator or reseller is used.
- **Most providers share a wire format.** DeepSeek, Mistral, xAI, Qwen, Moonshot and
  others accept OpenAI-style requests, so each one is configuration plus tests on the
  existing adapter, not new code. Image, audio and video providers will mostly need
  their own adapters.
- **The cost is operational:** one account, key, invoice and terms review per provider.
  Plan for roughly 10–20 providers to reach 100+ models.
- Every model sits behind a common **adapter interface**, so clients never see which
  provider serves a model.

### API shape: OpenAI-compatible

`/v1/chat/completions`, `/v1/models`, `/v1/embeddings`, `/v1/images/generations`,
`/v1/audio/speech`, `/v1/audio/transcriptions`, plus `/v1/jobs` for long-running
video generation (poll or webhook).

Compatibility means a developer can switch to us by changing `base_url` in the OpenAI SDK
they already use. That is the lowest-friction adoption path, and it is what developers
expect from a multi-model API.

### Billing unit: credits

Model costs differ by orders of magnitude and are measured in different units: tokens,
images, seconds of audio or video, characters. Everything is normalized to **credits**:

- Each model has a price per unit, expressed in credits.
- A plan grants monthly credits, rate limits and access to model tiers. Users can buy top-ups.
- **Hold, then settle.** Before a request runs, the gateway reserves the worst-case cost.
  Afterwards it charges the actual cost and releases the rest. A request can never cost
  more than the balance, so we never pay a provider for usage nobody paid us for.

### New tables, alongside what exists

| Exists today | Becomes |
|---|---|
| `ai_models` (provider, name, slug, category) | Model registry: input/output modalities, provider model id, context window, capability flags (vision, tools, JSON, streaming), price per unit, required tier, status (beta/active/deprecated) |
| `usage_records` (daily rollup per user/model) | Kept as the dashboard rollup. A new **`request_logs`** table records one row per call: key, model, units, our cost, credits charged, latency, status |
| `usage_limits` (a flat $16 cap) | Spending caps derived from the plan, per account and per API key |
| `subscriptions` (never populated) | Populated by Stripe and RevenueCat webhooks |
| — | `plans`, `credit_ledger`, `api_keys`, `model_routes`, `jobs`, `files`, `organizations` (later) |

---

## Feature list

**P0** = required for the first paid launch · **P1** = shortly after · **P2** = later
Each item shows its status and, where something exists, what is there today.

### A. AI Gateway & model platform — 25% (1 done · 5 partial · 8 not started)

- **A1 · P0** ✅ 100% · Provider adapter layer with one interface for chat, images, audio,
  embeddings and video jobs, with SSE streaming for text. *Done:* chat adapters (OpenAI-format
  and Anthropic) plus `openaiMedia.js` for embeddings, image generation, speech,
  transcription and video, all called directly at OpenAI (Decision 1). Each call holds its
  worst case and is charged what the provider reports: tokens (embeddings, images),
  characters (speech), seconds of audio (transcription) or seconds of video. Verified for
  real on 2026-10-05 for embeddings, a `gpt-image-1-mini` image, `tts-1` speech and
  `whisper-1` transcription, each charged exactly; video is tested against a stand-in
  (a real 4-second `sora-2` video costs about US$0.40 and hasn't been run).
- **A2 · P0** ✅ 100% · Model registry schema and admin-set pricing. *Done:* `ai_models`
  holds the direct route, the kind of call (`api_kind`: chat, embedding, image, speech,
  transcription, video), input/output modalities, capability flags (streaming, vision,
  tools, JSON), lifecycle status (beta/active/deprecated), access tier, billing unit and
  prices, our cost alongside. Admins edit all of it in the Models tab.
- **A3 · P0** 🟡 75% · Text and code models from OpenAI, Anthropic and Google, called
  directly. *Today:* all three are wired and tested against a stand-in provider; 45 priced
  models are listed, and OpenAI's 12 model ids were confirmed against OpenAI's live list.
  *Not yet:* a real reply, a working Google key, an Anthropic key, and direct integrations
  for the other providers in the catalog (25 models).
- **A4 · P0** ✅ 100% · Per-request metering into `request_logs`. *Done:* one row per call
  with route, model, tokens (marked when estimated), hold, charge, unbilled amount,
  provider cost, time to first token, duration and outcome. The daily `usage_records`
  rollup is still kept for the user dashboard.
- **A5 · P0** ✅ 100% · Credit ledger: hold, settle and refund; never negative; idempotent.
  *Done:* hold → settle on every call (also for media and long video jobs), integer
  micro-credits, database checks against negative balances. Admins refund one request's
  charge (once, audit-logged). A refunded payment, from Stripe or the App Store, takes back
  the refunded share of the credits it granted, never below what replies are holding and
  never twice; credits already spent are recorded as a shortfall.
- **A6 · P1** ⬜ 0% · Image generation and editing, and image input (vision).
- **A7 · P1** ⬜ 0% · Audio: text-to-speech and speech-to-text.
- **A8 · P1** ⬜ 0% · Embeddings.
- **A9 · P1** ⬜ 0% · Video generation as async jobs: queue, progress, webhooks, output
  storage behind signed URLs, and a retention policy.
- **A10 · P1** ⬜ 0% · Fallback provider per model when the primary is down; provider
  health checks with auto-disable. Under Decision 1 a fallback must also be a direct
  provider (e.g. another first-party host of the same open model). *Today:* each model
  has one route.
- **A11 · P1** 🟡 25% · Catalog sync, with admin approval required before a model goes
  live. *Today:* `modelChecker.js` fetches OpenAI's model list and reports models not yet
  in the database, triggered from an admin button. The Gemini fetch is commented out, and
  there is no approve/price/publish step. New: `npm run models:verify` checks every mapped
  `provider_model_id` against the provider's live list.
- **A12 · P2** ⬜ 0% · Tool/function calling and structured-output passthrough.
- **A13 · P2** ⬜ 0% · Web-search-grounded answers and code execution.
- **A14 · P2** ⬜ 0% · Prompt-caching passthrough to cut provider cost.

### B. End-user apps (web, mobile, desktop) — 18% (0 done · 12 partial · 7 not started)

**Core**
- **B1 · P0** 🟡 50% · Real AI chat: streaming, a model picker covering every model,
  stop/regenerate, Markdown and code highlighting, copy.
  *Today:* on web, replies stream from the gateway, Stop works and keeps the partial
  reply, and models that can't be called are greyed out. All of this is verified in the
  browser against the mock provider, and the error path against the real OpenAI API.
  Mobile replies are still a placeholder (Phase 4). There's no Markdown, copy or
  regenerate on web, and on mobile those buttons are empty.
- **B2 · P0** 🟡 50% · Server-side conversation storage.
  *Today:* done for web via Postgres. Mobile keeps everything in memory, so a restart
  loses it.
- **B3 · P0** 🟡 50% · Sign-in on every client.
  *Today:* backend and web are done (email/password, Google, GitHub). Mobile has no
  sign-in screen, and desktop doesn't exist yet.
- **B4 · P0** 🟡 25% · Real balance and usage display.
  *Today:* the web chat sidebar shows the live credit balance, and `GET /api/credits`
  returns it with recent movements. There's no usage page for users on web, and mobile
  shows "No usage yet" until it's connected (Phase 4).
- **B5 · P1** 🟡 10% · Real file attachments (PDF, documents, images) sent to vision and
  document models. *Today:* the web file picker code exists but the button is now
  disabled ("coming soon"): it only inserted a text tag, which a real model would answer
  as if it had seen the file.
- **B6 · P1** 🟡 10% · Voice: record, transcribe and send; read replies aloud.
  *Today:* the web recorder code exists but the button is disabled for the same reason.
  Mobile has a mic button and voice-choice settings that do nothing.
- **B7 · P1** ⬜ 0% · Image studio: prompt, generate, view in a gallery, download.
- **B8 · P1** ⬜ 0% · Audio studio: text-to-speech voices and transcription of uploaded audio.
- **B9 · P1** ⬜ 0% · Video studio: async generation with progress and a "your video is
  ready" notification.
- **B10 · P1** ⬜ 0% · Code mode: code-tuned models, copyable code blocks, language detection.
- **B11 · P1** ⬜ 0% · **Model comparison**: the same prompt sent to 2–4 models side by side.
- **B12 · P1** 🟡 25% · Folders/projects and search across chats.
  *Today:* the backend's full-text search works, but the web UI has no search box. Mobile
  history search filters demo data only. There are no folders.
- **B13 · P2** 🟡 10% · Prompt library, per-chat system prompts, custom assistants.
  *Today:* backend settings store one global system prompt and temperature, and mobile has
  a system-prompt field. Neither is applied to any request.
- **B14 · P2** 🟡 10% · Shareable conversation links and real export.
  *Today:* the mobile export dialog exists but produces no file.
- **B15 · P2** ⬜ 0% · Offline history cache on mobile and desktop.

**Account**
- **B16 · P0** 🟡 50% · Plans and checkout: Stripe on web and desktop; in-app purchase via
  RevenueCat on mobile. *Today:* the web Upgrade page lists the server's plans and opens
  Stripe Checkout and the billing portal, tested against a stand-in Stripe (no real
  payment yet: no keys). Mobile has RevenueCat purchase/restore/paywall code with no key
  and still shows its 11 hardcoded plans.
- **B17 · P0** ✅ 100% · Real Settings page on web. *Done:* text size, Enter-to-send,
  message times, custom instructions (sent to the model at the start of every chat) and
  temperature (sent only when set, since reasoning models reject one), all applied. A
  partial save no longer resets the other settings. Theme, read-aloud and notification
  settings aren't shown: the web app is dark-only and those features come later (B6, B19).
- **B18 · P1** ⬜ 0% · Password reset, email verification, account deletion and data export.
- **B19 · P1** 🟡 10% · Notifications: low balance, job finished, payment failed.
  *Today:* mobile has notification preference toggles only, with nothing behind them.

### C. Developer API product — 38% (3 done · 2 partial · 7 not started)

The developer API is built for text (Phase 3): `/v1` runs on the same gateway as the apps.

- **C1 · P0** ✅ 100% · API key management: create, name and revoke; shown once, stored
  hashed, with a visible prefix (`sk-cog-…`) and a last-used time. *Done:* 256-bit keys,
  SHA-256 hash only, up to 20 active per account; only plans with API access can create
  or use them (Decision 5).
- **C2 · P0** ✅ 100% · OpenAI-compatible `/v1` endpoints, starting with text. *Done:*
  `GET /v1/models`, `GET /v1/models/{id}` and `POST /v1/chat/completions`, streamed or not,
  with OpenAI's response, chunk, usage and error formats; system/developer roles,
  `max_tokens`, `temperature`, `top_p`, `stop`, `stream_options.include_usage`. Unsupported
  features (images, tools, `response_format`, `n > 1`) get a clear `400`. Tested with the
  official OpenAI SDK, and verified for real against OpenAI on 2026-10-05.
- **C3 · P0** ✅ 100% · Plan enforcement on every call: requests and tokens per minute,
  model-tier access, credit check; `402` and `429` errors with clear codes. *Done:* plan
  check (`403 api_access_required`), model tier (`403 model_requires_plan`), credits
  (`402`), and per-account requests and tokens per minute from the plan (`429` with
  `retry-after` and `x-ratelimit-*` headers), counted in Redis. Tiers exist but every model
  is open (tier 0) until an admin restricts one.
- **C4 · P0** ✅ 100% · Developer dashboard: keys, usage by key/model/day, balance, invoices.
  *Done:* the Developer API page has plan and limits, balance, base URL, keys, 30-day
  usage by model, key and day, and the account's Stripe invoices (also on the Upgrade page).
- **C5 · P0** ✅ 100% · Docs portal and quickstart: curl, Python and JavaScript, using the
  OpenAI SDK with `base_url` swapped. *Done:* a public `/docs/api` page with quickstart,
  streaming, a live model and price list, billing, rate limits, errors, what's supported,
  and privacy.
- **C6 · P1** ⬜ 0% · Every modality on the API, including video jobs and signed webhooks.
- **C7 · P1** ⬜ 0% · Playground: try any model in the browser and copy the generated code.
- **C8 · P1** ⬜ 0% · Per-key spending caps, model/modality scopes and IP allowlists.
- **C9 · P1** ⬜ 0% · Usage export (CSV) and a usage endpoint.
- **C10 · P2** ⬜ 0% · Organizations and teams: members, roles, shared credits, per-member keys.
- **C11 · P2** ⬜ 0% · Status page and thin official SDK wrappers.
- **C12 · P2** ⬜ 0% · Enterprise: invoiced billing, an SLA, dedicated rate limits.

### D. Billing & plans — 29% (0 done · 3 partial · 3 not started)

- **D1 · P0** 🟡 75% · Admin-configurable plan catalog: price, monthly credits, rate limits,
  model tiers, whether the plan includes API access. *Today:* a `plans` table with price,
  credits, interval, kind (subscription or top-up), an API-access flag and on/off sale,
  edited from the admin Plans tab and served by `GET /api/plans`. *Not yet:* rate limits
  and model tiers (they arrive with C3), and mobile still hardcodes its own 11 plans.
- **D2 · P0** 🟡 75% · Stripe subscriptions, top-ups and webhooks that create subscription rows
  and grant credits. *Today:* checkout, billing portal and signed webhooks are built; grants
  are idempotent; renewals, failed renewals and cancellation are handled and tested against
  a stand-in Stripe. *Not yet:* one real test-mode payment, which needs Stripe keys.
- **D3 · P0** 🟡 25% · RevenueCat webhook for mobile purchases into the same model, and
  replacing the copied "Flora Diary" entitlement. *Today:* the "Flora Diary" entitlement
  and key are gone, and keys and the entitlement id now come from build-time settings.
  The client SDK is wired and `subscriptions` has a `revenuecat_customer_id` column. There
  is no webhook yet.
- **D4 · P1** ⬜ 0% · Receipts and invoices, tax via Stripe Tax, failed-payment retries and
  downgrade, proration.
- **D5 · P1** ⬜ 0% · Promo codes and trial credits.
- **D6 · P2** ⬜ 0% · Usage-based overage billing for API customers.

### E. Admin & operations — 21% (0 done · 4 partial · 3 not started)

- **E1 · P0** ✅ 100% · Model admin: enable/disable, set price and tier, assign the provider
  route. *Done:* the admin Models tab edits on/off, status, tier, the provider's model id,
  prices and our cost (per token, character or second), limits and capability flags. Each
  change is audit-logged with before and after, applies to the next request, and `npm run
  seed` no longer overwrites it.
- **E2 · P0** ✅ 100% · User admin: suspend and adjust credits, audit-logged. *Done:*
  suspend/unsuspend with a required reason; a suspended account can't sign in, use the app
  or use API keys, and keeps its data. Credit adjustments, refunds, suspensions, plan and
  model edits all go to an audit log (Audit log tab: who, what, when, details).
- **E3 · P1** 🟡 75% · Margin dashboard: our provider cost against credits charged.
  *Today:* the admin Usage tab shows requests, provider cost, charged, margin and unbilled,
  in total and by model and route. *Not yet:* a per-day margin breakdown.
- **E4 · P1** ⬜ 0% · Abuse controls: spend-spike alerts, card fraud screening, fast key
  revocation, velocity limits.
- **E5 · P1** ⬜ 0% · Content moderation on inputs and outputs, plus a way to report content.
- **E6 · P1** 🟡 10% · Observability: structured logs, per-provider latency and error
  metrics, alerts, error tracking. *Today:* the request log records per-provider latency
  and error codes, but there are no metrics, alerts or structured logs.
- **E7 · P2** ⬜ 0% · Support ticketing.

### F. Platform foundations — 61% (3 done · 2 partial · 2 not started)

- **F1 · P0** ✅ 100% · Replace `sequelize.sync()` with real migrations. *Done:* umzug
  migrations in `src/db/migrations`, applied on startup (or `npm run db:migrate`, with
  `DB_AUTO_MIGRATE=false`). The baseline is a cleaned dump of the real schema. Tests
  rebuild a fresh database from migrations every run, and the dev database was migrated
  with no data change.
- **F2 · P0** ✅ 100% · Automated tests for auth, ledger, gateway and billing webhooks.
  *Done:* 77 backend tests (`npm test`) cover auth, chat privacy, migrations, every ledger
  rule, both chat adapters, all media endpoints and video jobs, the developer API through
  the official OpenAI SDK, rate limits on real Redis, Stripe and RevenueCat webhooks
  (including refunds), admin actions and tiers. The web app has its first tests
  (`npm test` in `frontend`, Vitest: Markdown sanitising and the Settings page). Mobile has
  its own `flutter test` suite.
- **F3 · P0** ✅ 100% · Secrets stay server-side; provider keys never reach any client.
  *Today:* still true with the gateway built. Keys are read only on the server, provider
  error bodies are logged rather than returned, and the public model list hides which
  keys are configured.
- **F4 · P0** ✅ 100% · Redis for rate limits, the job queue and caching. *Done:* rate
  limits and a short-lived cache of the public model list and plan catalog live in Redis
  (`REDIS_URL`; per-process memory without it), and admin edits clear the cache. The job
  queue for video runs on Postgres instead (`media_jobs`, claimed with `FOR UPDATE SKIP
  LOCKED`): durable across restarts and safe with several processes, with no extra moving
  part. Revisit if job volume outgrows it.
- **F5 · P0** ✅ 100% · Remove the fabricated data from mobile before any outside user sees
  a build. *Done:* fake Pro badges and billing dates now show the real entitlement state
  ("Free plan"); hardcoded names say "Not signed in"; Usage says "No usage yet"; History
  starts empty; a new chat starts empty. Widget tests fail if any of those strings return.
  *Not yet checked visually on the phone layout* (simulator access pending).
- **F6 · P1** ⬜ 0% · CI, a staging environment, database backups. *Today:* the CI workflow
  written on 2026-10-05 (`.github/workflows/ci.yml`: backend tests on Postgres 18, web
  build, Flutter analyze and tests) **is no longer in the repo**; it was removed outside
  this work later that day and never committed. It needs restoring, with a Redis service
  added for the API tests. There is no staging environment and no backups.
- **F7 · P1** ⬜ 0% · Legal: Terms, Privacy Policy, Acceptable Use Policy, data-retention
  policy, and a review of each provider's terms for resale.

---

## Development plan

The estimates assume **1–2 backend/full-stack developers and 1 Flutter developer**. They are
rough planning ranges, not commitments. The mobile track runs in parallel with Phases 2–3.

| Phase | Weeks | What ships | Done when | Status |
|---|---|---|---|---|
| **0. Foundations** | 2–3 | Migrations, test harness, Redis, CI, staging. RevenueCat config fixed, fake mobile data removed. Open decisions settled. | Staging deploys from CI with tests passing | 🟡 **50%**. Migrations, tests, RevenueCat fix and fake-data removal done; Redis in use for rate limits. The CI workflow file was removed outside this work and needs restoring; staging and the remaining open decisions (2, 3) remain |
| **1. Gateway MVP: text** | 4–6 | Adapter layer, 3 direct providers, ~30–50 priced text/code models, request logs, credit ledger, streaming. Web chat wired: the placeholder in `Chat.vue` is replaced. | A web user gets a real streamed reply from any listed model, credits drop by the right amount, and admin can see cost against charge | ✅ **100%**. Verified 2026-10-05 with a real reply from OpenAI (`gpt-4o-mini`) in the web chat: streamed, billed exactly from OpenAI's token counts (19 in, 7 out = 705 micro-credits), hold released, provider cost shown to admin. Google needs a working key and Anthropic a key to be checked the same way |
| **2. Plans & billing** | 3–4 | Plan catalog, Stripe checkout, subscriptions, top-ups and webhooks, real Upgrade page, limits enforced, balance UI | A real card payment leads to credits, usage, then a lower balance. A failed renewal downgrades the account correctly | 🟡 **90%**. Plan catalog with admin editing, Stripe checkout, billing portal and webhooks, the real Upgrade page, 30% markup, and expiring plan credits are done and tested (46 tests). *Left:* the done-when test for real: one Stripe test-mode card payment and a failed renewal, which need your Stripe test key |
| **3. Public API beta: text** | 3–4 | API keys, `/v1/chat/completions` + `/v1/models`, rate limits, developer dashboard, docs and quickstart | An outside developer buys a plan, creates a key, calls us from the stock OpenAI SDK, and sees the usage | 🟡 **90%**. Keys, `/v1/models` and `/v1/chat/completions`, per-plan rate limits on Redis, the developer dashboard and the docs are done, and the done-when test passes except its first step: the stock OpenAI SDK called `/v1` for real (OpenAI), was billed exactly, and the usage showed on the dashboard. *Left:* buying the API plan through Stripe (waits on Phase 2's Stripe key), and invoices on the dashboard |
| **4. Mobile connected** *(parallel with 2–3)* | 4–6 | HTTP client and sign-in, in-memory datasources replaced by the API, streaming chat, real history/usage/settings, RevenueCat flowing to the backend | The same account shows the same chats and balance on web and mobile | 🟡 **2%**. Screens and architecture are ready (which will speed this up); no connection work done |
| **5. Multimodal** | 6–8 | Images (generation + vision), audio (TTS/STT), embeddings, async video jobs with queue, storage and webhooks. Studios in the apps, the same endpoints on the API, moderation | Every modality works in both the apps and the API, billed in credits | 🟡 **2%**. Only the file picker and voice recorder code exist, now disabled until real uploads |
| **6. Desktop app** | 2–4 | Desktop build (see Decision 2), auto-update, native shortcuts and notifications | Signed installers for macOS and Windows | ⬜ **0%**. The Flutter project has empty desktop folders, relevant only if option (b) is chosen |
| **7. 100+ models & launch hardening** *(overlaps 5–6)* | 4–6 | Catalog sync with admin approval, failover, provider health, margin dashboard, abuse controls, observability, legal pages, load test, status page, store submissions | 100+ models priced and live, and the launch checklist is complete | 🟡 **12%**. Margin dashboard by model and route, two routes per model, partial catalog check; no automatic failover, health checks or abuse controls |

**Effort remaining:** about **26.6 of ~34.5 planned weeks** (≈23% done; it was ≈4% this
morning). The milestones below still count from now.

### Milestones

| Milestone | Target | Status |
|---|---|---|
| **M1, first revenue:** paid web app with real text/code models (end of Phase 2) | ~3 months | 🟡 Text gateway and credits built; payments (Phase 2) not started |
| **M2, API beta and mobile:** developers can buy API access; the mobile app is connected to real data (end of Phases 3–4) | ~4 months | ⬜ Not started |
| **M3, multimodal:** image, audio and video in the apps and the API | ~6 months | ⬜ Not started |
| **M4, general launch:** desktop app, 100+ models, hardened operations | ~7–8 months | ⬜ Not started |

**Recommended next step:**
1. Add a Stripe test key so Phase 2's payment test can run. Fix `GEMINI_API_KEY`, add
   `ANTHROPIC_API_KEY`, and rerun `npm run models:verify` from `cognitiveaibot_web/backend`.
2. Decide credit pricing (Decision 4). The current prices are at cost, with 1 credit =
   US$0.01.
3. Start Phase 2: a plan catalog and Stripe checkout, subscriptions and top-ups whose
   webhooks grant credits through the ledger that now exists.
4. Make the first git commit and add a GitHub remote, so CI actually runs.

---

## Decisions needed from you

Decisions 1, 4, 5 and 6 (for the API) are settled; 2 and 3 are still open as of 2026-10-05.

1. ~~**Direct vs. aggregator mix.**~~ **Decided 2026-10-05: direct only.** Every model is
   reached with its own provider's key and a direct integration. No aggregator or reseller
   (OpenRouter, fal, Replicate or similar) will be used. The OpenRouter route was
   removed from the gateway the same day, and reaching 100+ models means more direct integrations.
2. **Desktop technology.**
   - *(a) Tauri or Electron wrapping the Vue web app.* Fastest, and desktop always matches web.
   - *(b) Flutter desktop.* Shares code with mobile, and the Flutter project already has
     macOS/Windows/Linux folders plus some desktop layouts.

   *Recommendation: (a)*, ideally Tauri for smaller installers. The web app is the client
   that is actually connected and will get every feature first, and desktop usage (big
   screen, keyboard, long sessions) is closer to web than to mobile. Choose (b) if you would
   rather converge on Flutter long-term.
3. **Where API packages are sold.** *Recommendation:* sell **API packages only on the web,
   through Stripe**. Sell consumer plans on every platform (in-app purchase on mobile, as the
   stores require). This keeps API revenue clear of store fees and store rules. Keep one ledger per
   account, with each credit grant tagged by source.
4. ~~**Pricing.**~~ **Decided 2026-10-05:** 1 credit = US$0.01; every model costs provider
   price + 30%; subscription credits expire at the end of each paid period (with a day's
   grace for the renewal to clear) and are spent first; top-up credits never expire; the
   only plan limit for now is the credit balance. The four plans are Starter ($10/month,
   900 credits), Pro ($25/month, 2,250 credits, API access), and top-ups of $5 (450) and
   $20 (1,800). *Still to do:* replace mobile's 11 hardcoded plans (Phase 4). Video and
   other modalities may need their own markup when they arrive.
5. ~~**Free tier.**~~ **Decided 2026-10-05: no free API tier.** API keys work only on plans
   that include API access. App users can still get trial credits (`SIGNUP_TRIAL_CREDITS`).
6. ~~**Data retention.**~~ **Decided 2026-10-05 for the API: nothing is stored.** API prompts
   and replies are never saved; only billing metadata (time, model, key, tokens, cost) is
   kept. The apps still save chats so users can see their history; how long to keep those
   is still open.

## Risks

- **Anthropic refusal fallbacks are off.** Anthropic can re-run a refused request on
  another model, billed at that model's rates. That's left off so a user is always billed
  for the model they picked; a refusal shows "The model declined to answer this request".
  Turning it on would need per-model billing of the fallback.
- **46 models in a row of pills.** The web chat's model picker works but is unwieldy at
  this size. A searchable picker belongs with the Models page (roadmap B items).

- **Provider terms on resale.** Some providers restrict reselling raw access, or require
  specific agreements for it. **Review each provider's commercial terms before listing its
  models in the paid API.** This decides which models can launch.
- **Provider price changes and margin.** Prices change often. Run catalog sync with price
  alerts, and keep hold-then-settle so no single request can lose money.
- **Fraud and abuse.** Stolen cards used to buy credits and burn compute, leaked keys, and
  disallowed image or video content. Mitigate with Radar, spend caps, velocity limits,
  moderation and fast key revocation.
- **Video cost and latency.** Video generation is expensive and slow. It must be async,
  prepaid, and cancellable.
- **Model churn.** Keeping 100+ models current is **ongoing operations work, not a one-time
  build**. Plan staff time for it.
- **App store review.** AI apps that generate images or video need moderation, reporting
  and an appropriate age rating to pass review.

## What carries over from today

- **Web `Chat.vue`:** swap the placeholder reply for a streaming gateway call. The rest of
  the chat UI stays.
- **Flutter Clean Architecture:** replace the `ChatRemoteDataSourceImpl` and
  `ChatLocalDataSourceImpl` implementations. The architecture itself does not change.
- **`ai_models`, `usage_records`, `usage_limits`, `subscriptions`:** extend them, as in the
  table above.
- **`modelChecker.js`:** the starting point for catalog sync.
- **Admin dashboard:** add write actions to the existing read-only screens.
- **Backend search, rename and delete endpoints:** built (rename fixed 2026-10-05); the web UI only needs to
  call them.
