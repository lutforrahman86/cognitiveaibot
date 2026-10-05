# CognitiveAI Bot — Progress

Last updated: 2026-08-09, with corrections on 2026-10-05.

> **This is the August snapshot.** On 2026-10-05 the web chat was wired to a real AI
> provider through a new gateway, migrations and tests were added, and the fabricated
> mobile data was removed. Several "Not done" items below are therefore done now. Current
> status and percentages live in [ROADMAP.md](ROADMAP.md) ("Done on 2026-10-05").

Two independent apps live in this repo: a web app (`cognitiveaibot_web`, Express +
Postgres + Vue 3) and a mobile app (`cognitiveaibot_app`, Flutter). Both were run
locally and exercised by hand for this report — backend and frontend dev servers on
`localhost:3000`/`5173`, mobile app built and launched in the iOS Simulator
(iPhone 17 Pro).

**Headline finding, true of both apps: no LLM is ever actually called.** Every "AI"
reply, on web and mobile, is a hardcoded placeholder string. That's the core feature
of the product and it doesn't exist yet — everything described below as "functional"
is the scaffolding around that missing piece.

---

## Web app — backend (`cognitiveaibot_web/backend`)

Express + Sequelize + Postgres. Schema auto-creates on startup; seed script creates a
demo admin, one regular user, 13 AI models, chat history and usage records.

### Functional (verified against a running Postgres instance)
- Auth: register/login (bcrypt + JWT, 7-day expiry), `GET /auth/me`. Google and GitHub
  OAuth are wired via Passport and correctly return 503 when their env vars aren't set,
  rather than failing open.
- Users: get/update profile, avatar upload (multer, 2MB cap, rejects oversize/invalid
  type).
- Chats: full CRUD, scoped to the owning user; Postgres full-text search
  (`to_tsvector`/`plainto_tsquery`) across title/excerpt/category/model name.
- Messages: create/list per chat, ownership-checked.
- AI models: list/get, filterable by category/provider/search.
- Chat settings: get/update, persisted per user.
- Usage: dashboard (cost/token totals, daily series, per-model breakdown) and raw
  records — reads from a real `usage_records` table.
- Usage limits: get/update (defaults to $16/month).
- Subscriptions: read-only status + Pro-entitlement check.
- Admin (role-gated, `403` verified for non-admins): dashboard totals, user list,
  subscription list, usage stats, model list, "check for new models" (live call to the
  OpenAI models API if `OPENAI_API_KEY` is set).

### Not done
- **No LLM provider is ever called to generate a reply.** `POST /chats/:id/messages`
  just stores whatever `role`/`content` the client sends — there's no server-side
  generation step at all.
- **No RevenueCat webhook.** `Subscription.upsert()` exists on the model but nothing in
  `routes/` or `controllers/` calls it — a subscription row can only be created by a
  direct database write. The Pro-entitlement path is wired to read a table nothing
  ever populates.
- No payment/billing provider is actually connected (no Stripe, no RevenueCat server
  SDK) despite `revenuecat_customer_id` existing on the schema.
- Gemini model-check is written but commented out in `modelChecker.js` — only OpenAI's
  list is ever fetched, and only with a key configured.
- Admin panel is **read-only**: no editing/banning users, no adding or deactivating
  models, no granting/revoking subscriptions from the UI.
- No password-reset / forgot-password flow.
- No automated tests (`npm test` is the unset default: `echo "Error: no test
  specified" && exit 1`).

---

## Web app — frontend (`cognitiveaibot_web/frontend`)

Vue 3 + Vite, proxying `/api` to the backend.

### Functional (verified live in-browser)
- Landing page — fully built marketing page, no placeholder content.
- Sign in / sign up with the seeded demo account
  (`demo@cognitiveaibot.com` / `demo123456`); Google/GitHub buttons present, correctly
  disabled server-side without OAuth keys.
- Chat screen: real model picker (13 models from the DB), sidebar with real chat
  history, create and open chat. Sending a message does persist both the user turn
  and a reply to the database — the reply text is just the hardcoded placeholder
  (see below). *(Corrected 2026-10-05: an earlier version of this line said the UI had
  working search and delete. It doesn't — see "Not done".)*
- Admin dashboard: Overview/Models/Users/Subscriptions/Usage tabs, every number backed
  by a real query (confirmed: 2 real users, 13 real models, live usage totals).
- Profile page: real read/update of name, avatar, "member since" date.
- Auth guard: signing in as an admin auto-redirects to `/admin`.
- Zero console errors and zero failed network requests across every screen tested.

### Not done
- **Chat replies are 100% hardcoded** — verified by sending a live message:
  > *"This is a placeholder response. Connect an LLM API to enable real AI responses."*
- **No search, rename or delete in the chat UI.** The backend endpoints for all three
  exist and work, but `Chat.vue` never calls them.
- `/models` — "AI model selection coming soon" placeholder (distinct from the working
  in-chat model picker, which is real).
- `/settings` — "Settings coming soon" placeholder, even though the backend's settings
  API is fully functional and just has no UI pointed at it.
- `/upgrade` — "Subscription options coming soon" placeholder; no billing UI exists.
- File attachment and voice recording controls exist in the chat input, but nothing is
  actually uploaded — a picked file becomes the literal text
  `[Attached 2 file(s): a.png, b.png]` in the message body.
- No password-reset UI.

---

## Mobile app (`cognitiveaibot_app`)

Flutter, Clean Architecture (domain/data/presentation), Riverpod for DI/state. The
architecture itself is well done — the gap is entirely in what's plugged into it.

### Functional (built and run live in the iOS Simulator, iPhone 17 Pro)
- Builds and launches cleanly (Flutter 3.44.8, `flutter build ios --debug
  --simulator`).
- Five-tab shell (Home, History, Models, Usage, Settings) — every screen is a real,
  polished, native-feeling UI, not a stub.
- Chat screen: message bubbles, a model switcher (7 providers defined in
  `ai_services.dart`: OpenAI, Anthropic, Gemini, DeepSeek, Perplexity, Grok, Mistral),
  copy/like/dislike/regenerate controls on messages.
- History screen: conversations grouped by Today/Yesterday/Last week, category icons,
  model badges, search bar.
- Model selection screen: filterable/searchable catalog with capability tags
  (Reasoning, Coding, "2M Context", etc.).
- Usage Dashboard: full chart UI — total cost/tokens, most-used models, a 7-day daily
  spending bar chart, per-model breakdown.
- Settings: profile block, subscription block, notification toggles — all genuinely
  interactive (native switches respond).
- RevenueCat SDK (`purchases_flutter`) is properly integrated in code: initialize,
  entitlement check, purchase, restore all call the real SDK.

### Not done, and a few things worth flagging directly
- **No connection to the backend at all.** There is no `http`/`dio` package in
  `pubspec.yaml` — the app has never made a network call to the Express API. It's a
  fully local, offline shell.
- **No authentication exists in the app** — no sign-in/sign-up screen anywhere.
- **Chat replies are hardcoded**, same pattern as the web app
  (`chat_remote_datasource_impl.dart`): *"This is a placeholder response. Configure
  OpenAI, Anthropic, Gemini, or other LLM APIs to get real AI responses."*
- **All persistence is in-memory** (`ChatLocalDataSourceImpl` uses plain Dart `Map`s)
  — every conversation is lost on app restart. No SQLite/Hive/`shared_preferences`.
- **History and Usage Dashboard show fixed demo data, not real activity.** The Usage
  Dashboard always reads "$12.45 / 2.5M tokens / 12% from last month" regardless of
  anything the user actually does — confirmed live, the numbers never moved.
- **Settings shows a fabricated active "Pro Member" subscription** — "Next billing
  date: Oct 12, 2024" (a date in the past) is hardcoded copy, not the result of the
  real entitlement check anywhere visible in that screen.
- **Settings shows a hardcoded name** ("Lutfor Rahman", and "Alex Rivera" in the desktop
  layouts) with no login system behind it. *(Corrected 2026-10-05: this line originally
  said the name was pulled from the device. It wasn't; it was a hardcoded string. Removed
  on 2026-10-05.)*
- **RevenueCat is misconfigured for this app.** `revenuecat_config.dart` still has the
  entitlement ID and doc comments from a *different* app —
  `'Flora Diary - Journal, Gratitude & Mindfulness Pro'` — evidently copy-pasted
  boilerplate that was never updated. As configured, it will never match a real
  entitlement for CognitiveAI Bot.
- Profile "Edit Full Name / Edit Email / Change Password" actions only show a snackbar
  — no edit actually happens.
- Export-data modal is UI only; no file is produced.
- All settings toggles are in-memory Riverpod state — reset on every app restart.
- The one file under `test/` is the unmodified default Flutter counter-app template
  (asserts on a counter widget that doesn't exist in this app) — there is no real test
  coverage.
- Android not tested this session (iOS Simulator only).

---

## What "finishing touch" actually requires

In order of what blocks the core product:

1. **Wire an actual LLM call** (OpenAI/Anthropic/etc.) on at least one side — right
   now this is the single missing piece that makes both apps demos rather than a
   product.
2. **Connect the mobile app to the backend** — auth, chat persistence, and usage
   tracking all need to move from in-memory/hardcoded to the real API before the two
   "apps" are one product.
3. **Decide the mobile subscription story** — fix or remove the fake "Pro Member"
   state, and either wire `RevenueCatConfig` to a real project or drop the SDK calls
   until it's configured.
4. **Wire the RevenueCat webhook** on the backend so a real purchase ever produces a
   `subscriptions` row.
5. Lower priority: web Settings/Models/Upgrade pages, admin edit actions, password
   reset, real file/voice upload, mobile local persistence, test coverage on both
   sides.
