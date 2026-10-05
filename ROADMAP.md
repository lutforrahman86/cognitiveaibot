# CognitiveAI Bot — Feature List & Development Plan

Last updated: 2026-10-05, after Phase 1 (the text gateway: credits, metering, 46 models, 4 providers)
Starting point: [PROGRESS.md](PROGRESS.md) (2026-08-09, with corrections).

## The target

1. **One product on web, mobile and desktop** where a user can work with 100+ AI models
   across every modality: text, code, image, audio and video.
2. **A paid developer API** sold as subscription packages. A subscriber activates an API
   key and gets the same models the apps offer.

---

## Status — 2026-10-05

| Measure | Morning audit | After Phase 0 | Now (Phase 1) |
|---|---|---|---|
| **Whole roadmap** (65 features, equal weight) | 8% | 14% | **20%** |
| **P0 features** (the 26 needed for the first paid launch) | 14% | 28% | **41%** |
| **Planned build effort** (weighted by the phase estimates below) | 4% | 14% | **23%**. About **26.6 of ~34.5 weeks** remain |
| Feature count | 1 done · 20 partial · 44 not started | 3 · 25 · 37 | **4** done · **27** partial · **34** not started |

| Area | Morning | After Phase 0 | Now |
|---|---|---|---|
| A. AI Gateway & model platform | 4% | 9% | 26% |
| B. End-user apps | 14% | 16% | 16% |
| C. Developer API product | 0% | 1% | 2% |
| D. Billing & plans | 3% | 6% | 6% |
| E. Admin & operations | 6% | 6% | 21% |
| F. Platform foundations | 14% | 54% | 57% |

**What this means.** The text gateway is built. Every reply now holds its worst-case
cost in credits, then charges exactly what it used and logs it, and admins can see our
provider cost against the charge. It covers 46 current models across four providers
(OpenAI, Anthropic, Google direct, plus OpenRouter for the rest). **No real reply has been
received yet:** both provider keys in `backend/.env` are dead, so every successful reply
so far came from local stand-in providers. Credit prices are placeholders (1 credit =
US$0.01, priced at cost) until Decision 4. Billing (buying credits) and the developer API
are next.

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
(C3, Phase 3). Paid credits currently never expire and subscription credits roll over;
whether they should is part of Decision 4.

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
  when that provider's key is set, otherwise through OpenRouter.
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

**Still needed from you:** a working provider key in `backend/.env`, and Stripe test keys
(`STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET`; `stripe listen --forward-to
localhost:3000/api/billing/webhook` gives a local webhook secret) to make the first test
payment.
`OPENROUTER_API_KEY` alone unlocks all 46 models; then `npm run models:verify` checks
the model ids. Also needed: access to the new iPhone simulator, so the phone layout of the
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
     OpenAI        Anthropic       Google        Aggregators (e.g. OpenRouter,
     (direct)      (direct)        (direct)      fal, Replicate) → long tail of
                                                  text/image/audio/video models
```

Why it has to be this way:

- **API parity becomes structural.** "Our API must provide all the models like our app"
  is true automatically, because there is only one model pipeline.
- Routing, metering, billing, rate limiting, safety and failover are each built once.
- Every app request exercises the same code paths that paying API customers depend on.

### How to realistically reach 100+ models

- **Direct integrations with roughly 4–6 major providers** (OpenAI, Anthropic, Google, plus
  1–3 more by demand). These give the best margins and reliability, and new features arrive first.
- **Aggregators for the long tail**: open-weight text models and most image, audio and
  video models. One integration brings in hundreds of models.
- Every model sits behind a common **adapter interface**. A model can move from an
  aggregator to a direct integration later without any client noticing.

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

### A. AI Gateway & model platform — 26% (1 done · 6 partial · 7 not started)

- **A1 · P0** 🟡 25% · Provider adapter layer with one interface for chat, images, audio,
  embeddings and video jobs, with SSE streaming for text.
  *Today:* `src/gateway/` has two chat adapters: one for any OpenAI-compatible API, and
  Anthropic's on its official SDK. Both stream, cancel cleanly, report token usage even
  when stopped, and map provider errors to clear codes. Images, audio, embeddings and
  video aren't built.
- **A2 · P0** 🟡 50% · Model registry schema and admin-set pricing.
  *Today:* `ai_models` holds a direct and an aggregator route id, context window, output
  cap, our cost and the credit price per 1M tokens, loaded from a dated catalog snapshot.
  An unpriced model can't be called. There are still no modality or capability flags or
  tiers, and admins can see prices but can't edit them.
- **A3 · P0** 🟡 75% · Text and code models: OpenAI, Anthropic and Google direct, plus one
  aggregator. *Today:* all four are wired (OpenRouter is the aggregator), with 46 priced
  models, each tested against a stand-in provider. *Not yet:* a real reply from any of
  them, because the keys in `.env` are dead. The OpenAI and Google direct model ids are
  assumed to match OpenRouter's and need `npm run models:verify`.
- **A4 · P0** ✅ 100% · Per-request metering into `request_logs`. *Done:* one row per call
  with route, model, tokens (marked when estimated), hold, charge, unbilled amount,
  provider cost, time to first token, duration and outcome. The daily `usage_records`
  rollup is still kept for the user dashboard.
- **A5 · P0** 🟡 75% · Credit ledger: hold, settle and refund; never negative; idempotent.
  *Today:* hold → settle on every reply, with integer micro-credits and a database check
  against negative balances. Each request settles at most once, holds from crashes are
  released, and parallel holds are tested. Grants and adjustments are recorded. *Not
  yet:* a refund flow for a specific charge, which only an admin adjustment covers today.
- **A6 · P1** ⬜ 0% · Image generation and editing, and image input (vision).
- **A7 · P1** ⬜ 0% · Audio: text-to-speech and speech-to-text.
- **A8 · P1** ⬜ 0% · Embeddings.
- **A9 · P1** ⬜ 0% · Video generation as async jobs: queue, progress, webhooks, output
  storage behind signed URLs, and a retention policy.
- **A10 · P1** 🟡 10% · Fallback provider per model when the primary is down; provider
  health checks with auto-disable. *Today:* each model has two routes (direct and
  OpenRouter), chosen by which keys are set. There's no automatic switch when one fails.
- **A11 · P1** 🟡 25% · Catalog sync, with admin approval required before a model goes
  live. *Today:* `modelChecker.js` fetches OpenAI's model list and reports models not yet
  in the database, triggered from an admin button. The Gemini fetch is commented out, and
  there is no approve/price/publish step. New: `npm run models:verify` checks every mapped
  `provider_model_id` against the provider's live list.
- **A12 · P2** ⬜ 0% · Tool/function calling and structured-output passthrough.
- **A13 · P2** ⬜ 0% · Web-search-grounded answers and code execution.
- **A14 · P2** ⬜ 0% · Prompt-caching passthrough to cut provider cost.

### B. End-user apps (web, mobile, desktop) — 16% (0 done · 12 partial · 7 not started)

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
- **B17 · P0** 🟡 50% · Real Settings page on web.
  *Today:* the backend settings API is complete (theme, font size, enter-to-send,
  timestamps, read-aloud, voice, system prompt, temperature). The web page is a
  "coming soon" placeholder.
- **B18 · P1** ⬜ 0% · Password reset, email verification, account deletion and data export.
- **B19 · P1** 🟡 10% · Notifications: low balance, job finished, payment failed.
  *Today:* mobile has notification preference toggles only, with nothing behind them.

### C. Developer API product — 2% (0 done · 1 partial · 11 not started)

The app's own JWT-protected REST API exists, but none of the developer API product does.
The gateway core in `src/gateway/` is written so `/v1` can call the same code later.

- **C1 · P0** ⬜ 0% · API key management: create, name and revoke; shown once, stored
  hashed, with a visible prefix (`sk-cog-…`) and a last-used time.
- **C2 · P0** ⬜ 0% · OpenAI-compatible `/v1` endpoints, starting with text.
- **C3 · P0** 🟡 25% · Plan enforcement on every call: requests and tokens per minute,
  model-tier access, credit check; `402` and `429` errors with clear codes.
  *Today:* the credit check is done (`402 INSUFFICIENT_CREDITS` before any provider
  call), plus one reply at a time per user (`429`, per server process). There are no
  per-minute limits or tiers.
- **C4 · P0** ⬜ 0% · Developer dashboard: keys, usage by key/model/day, balance, invoices.
- **C5 · P0** ⬜ 0% · Docs portal and quickstart: curl, Python and JavaScript, using the
  OpenAI SDK with `base_url` swapped.
- **C6 · P1** ⬜ 0% · Every modality on the API, including video jobs and signed webhooks.
- **C7 · P1** ⬜ 0% · Playground: try any model in the browser and copy the generated code.
- **C8 · P1** ⬜ 0% · Per-key spending caps, model/modality scopes and IP allowlists.
- **C9 · P1** ⬜ 0% · Usage export (CSV) and a usage endpoint.
- **C10 · P2** ⬜ 0% · Organizations and teams: members, roles, shared credits, per-member keys.
- **C11 · P2** ⬜ 0% · Status page and thin official SDK wrappers.
- **C12 · P2** ⬜ 0% · Enterprise: invoiced billing, an SLA, dedicated rate limits.

### D. Billing & plans — 6% (0 done · 2 partial · 4 not started)

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

- **E1 · P0** 🟡 10% · Model admin: enable/disable, set price and tier, assign the provider
  route. *Today:* admin can view every model, including inactive ones, and the API now says
  why a model can't be called (no provider id, no adapter, no key). Nothing can be changed
  from the admin screens yet.
- **E2 · P0** 🟡 50% · User admin: suspend and adjust credits, audit-logged.
  *Today:* admins see each user's balance and can grant or remove credits with a required
  reason. The acting admin is recorded on the credit transaction, and a change that would
  push a balance below its holds is refused. There's no suspend yet.
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

### F. Platform foundations — 57% (3 done · 2 partial · 2 not started)

- **F1 · P0** ✅ 100% · Replace `sequelize.sync()` with real migrations. *Done:* umzug
  migrations in `src/db/migrations`, applied on startup (or `npm run db:migrate`, with
  `DB_AUTO_MIGRATE=false`). The baseline is a cleaned dump of the real schema. Tests
  rebuild a fresh database from migrations every run, and the dev database was migrated
  with no data change.
- **F2 · P0** 🟡 75% · Automated tests for auth, ledger, gateway and billing webhooks.
  *Today:* 44 backend tests (`npm test`) cover auth, chat privacy, migrations, billing webhooks, both
  adapters and every ledger rule, including parallel holds and crash cleanup. 5 mobile
  tests (`flutter test`) check the screens show no fabricated data. *Not yet:* the
  RevenueCat webhook (it doesn't exist yet) and frontend tests.
- **F3 · P0** ✅ 100% · Secrets stay server-side; provider keys never reach any client.
  *Today:* still true with the gateway built. Keys are read only on the server, provider
  error bodies are logged rather than returned, and the public model list hides which
  keys are configured.
- **F4 · P0** ⬜ 0% · Redis for rate limits, the job queue and caching. *Deliberately
  deferred to when rate limiting (C3) is built*, so it isn't added as unused infrastructure.
- **F5 · P0** ✅ 100% · Remove the fabricated data from mobile before any outside user sees
  a build. *Done:* fake Pro badges and billing dates now show the real entitlement state
  ("Free plan"); hardcoded names say "Not signed in"; Usage says "No usage yet"; History
  starts empty; a new chat starts empty. Widget tests fail if any of those strings return.
  *Not yet checked visually on the phone layout* (simulator access pending).
- **F6 · P1** 🟡 25% · CI, a staging environment, database backups. *Today:*
  `.github/workflows/ci.yml` runs backend tests on Postgres 18, the web build, and Flutter
  analyze and tests. It has never run on GitHub because the repo has no commits or remote
  yet; the same commands pass locally. There is no staging environment and no backups.
- **F7 · P1** ⬜ 0% · Legal: Terms, Privacy Policy, Acceptable Use Policy, data-retention
  policy, and a review of each provider's terms for resale.

---

## Development plan

The estimates assume **1–2 backend/full-stack developers and 1 Flutter developer**. They are
rough planning ranges, not commitments. The mobile track runs in parallel with Phases 2–3.

| Phase | Weeks | What ships | Done when | Status |
|---|---|---|---|---|
| **0. Foundations** | 2–3 | Migrations, test harness, Redis, CI, staging. RevenueCat config fixed, fake mobile data removed. Open decisions settled. | Staging deploys from CI with tests passing | 🟡 **59%**. Migrations, tests, CI config, RevenueCat fix and fake-data removal done. Redis deferred to C3; staging and the open decisions remain; CI hasn't run on GitHub yet |
| **1. Gateway MVP: text** | 4–6 | Adapter layer, 3 direct providers + 1 aggregator, ~30–50 priced text/code models, request logs, credit ledger, streaming. Web chat wired: the placeholder in `Chat.vue` is replaced. | A web user gets a real streamed reply from any listed model, credits drop by the right amount, and admin can see cost against charge | 🟡 **95%**. Everything in the done-when test works against stand-in providers: streamed replies from 46 priced models across 4 providers, exact credit charges, admin cost-vs-charge. *Left:* one real reply, which needs a working key, and verifying the direct model ids |
| **2. Plans & billing** | 3–4 | Plan catalog, Stripe checkout, subscriptions, top-ups and webhooks, real Upgrade page, limits enforced, balance UI | A real card payment leads to credits, usage, then a lower balance. A failed renewal downgrades the account correctly | 🟡 **70%**. Plan catalog with admin editing, Stripe checkout, billing portal, webhooks and the real Upgrade page are done; the failed-renewal downgrade is tested against a stand-in Stripe. *Left:* a real test-mode payment (needs Stripe keys), pricing (Decision 4), and plan limits, which come with Phase 3 |
| **3. Public API beta: text** | 3–4 | API keys, `/v1/chat/completions` + `/v1/models`, rate limits, developer dashboard, docs and quickstart | An outside developer buys a plan, creates a key, calls us from the stock OpenAI SDK, and sees the usage | 🟡 **5%**. The credit check (402) and one-at-a-time guard exist; the gateway core is ready to be put behind `/v1` |
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
1. Add a working key to `backend/.env`. `OPENROUTER_API_KEY` alone is enough. Then run
   `npm run models:verify` and send one real message, which closes Phase 1.
2. Decide credit pricing (Decision 4). The current prices are at cost, with 1 credit =
   US$0.01.
3. Start Phase 2: a plan catalog and Stripe checkout, subscriptions and top-ups whose
   webhooks grant credits through the ledger that now exists.
4. Make the first git commit and add a GitHub remote, so CI actually runs.

---

## Decisions needed from you

All still open as of 2026-10-05.

1. **Direct vs. aggregator mix.** *Recommendation:* go direct for the 3–4 providers that will
   carry most traffic, since they give the best margin and reliability. Use aggregators for everything
   else, and move a model to direct only once its volume justifies the work.
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
4. **Pricing.** Set a credit price and a markup target per model class. Video and frontier
   models need a different markup from cheap open models. Also review the 11 hardcoded
   mobile plans (audit finding 5) against this. *Placeholder in use:* 1 credit = US$0.01
   (`CREDIT_USD_VALUE`) at 0% markup. Credit prices are per-model data, so changing them
   needs a new catalog snapshot, not code.
5. **Free tier.** *Recommendation:* trial credits for app users; **no free API tier**, or a
   tiny one that requires card verification. A free API tier attracts abuse immediately.
6. **Data retention.** Decide whether prompts and outputs are stored and for how long. Many API
   buyers will require a no-retention option, so it should be a setting from day one.

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
