# CognitiveAI Bot Web Application

A full-stack web application with an Express.js backend and Vue.js frontend.

## Project Structure

```
cognitiveaibot_web/
├── backend/     # Express.js API server
├── frontend/    # Vue.js UI application
└── README.md
```

## Getting Started

### Prerequisites

- Node.js 18+
- PostgreSQL 14+
- npm or yarn

### Backend Setup

1. Create a PostgreSQL database:
   ```bash
   createdb cognitiveaibot
   ```

2. Copy the example env file and configure:
   ```bash
   cd backend
   cp .env.example .env
   ```
   Edit `.env` and set `DATABASE_URL`, `JWT_SECRET`, and optionally `FRONTEND_URL`/`API_URL`.

   For Google & GitHub sign-in, create OAuth apps and add to `.env`:
   - **Google**: [Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials → Create OAuth client → Authorized redirect URI: `http://localhost:3000/api/auth/google/callback`
   - **GitHub**: [Developer settings](https://github.com/settings/developers) → New OAuth App → Authorization callback URL: `http://localhost:3000/api/auth/github/callback`

   For AI replies, set a provider key in `.env`. `OPENROUTER_API_KEY` alone reaches all
   46 catalog models; `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` or `GEMINI_API_KEY` route that
   provider's models directly instead. Models with no usable route are greyed out in the
   chat. Keys stay on the server and are never sent to a client.

   Replies cost credits. Give yourself some with `npm run credits:grant -- <email> 100`
   (or from the admin Users tab), or set `SIGNUP_TRIAL_CREDITS` to grant new accounts a
   starting balance.

3. Install and run:
   ```bash
   npm install
   npm run dev
   ```

The API server runs on `http://localhost:3000`. Pending database migrations
(`src/db/migrations`) are applied on startup; set `DB_AUTO_MIGRATE=false` to run them as a
separate step with `npm run db:migrate` instead. The schema is never auto-synced from the
models: change it by adding a migration.

Other backend commands:

| Command | What it does |
|---|---|
| `npm test` | Runs the test suite against a separate `<db>_test` database (or `TEST_DATABASE_URL`), wiped before each test file. No provider key needed. |
| `npm run dev:mock-ai` | Like `npm run dev`, but GPT models are answered by a local mock provider, with replies labelled as fake. For UI work without a key or cost. |
| `npm run models:verify` | Checks each model's `provider_model_id` against the provider's live model list. |
| `npm run credits:grant -- <email> <credits> [reason]` | Adds (or, if negative, removes) credits for a user, recorded in the credit ledger. |
| `npm run db:migrate:status` | Lists applied and pending migrations. |

4. (Optional) Seed demo data:
   ```bash
   npm run seed
   ```
   Creates AI models, a demo user (`demo@cognitiveaibot.com` / `demo123456`), chat history, usage records, and settings.

### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

The Vue app runs on `http://localhost:5173` and proxies API requests to the backend.

### Running Both

1. Start the backend first: `cd backend && npm run dev`
2. In a new terminal, start the frontend: `cd frontend && npm run dev`
3. Open http://localhost:5173 in your browser

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| GET /api/health | Health check |
| GET /api | API info and available endpoints |
| POST /api/auth/register | Register (body: `email`, `password`, `name?`) |
| POST /api/auth/login | Login (body: `email`, `password`) |
| GET /api/auth/me | Current user (requires `Authorization: Bearer <token>`) |
| GET /api/users/me | Profile (auth) |
| PATCH /api/users/me | Update profile (auth) |
| GET /api/models | List AI models (query: `category`, `provider`, `search`) |
| GET /api/models/:id | Get model by ID |
| GET /api/chats | List chats (auth, query: `limit`, `offset`, `search`, `category`) |
| GET /api/chats/search?q= | Search chats (auth) |
| POST /api/chats | Create chat (auth) |
| GET /api/chats/:id | Get chat with messages (auth) |
| PATCH /api/chats/:id | Update chat (auth) |
| DELETE /api/chats/:id | Delete chat (auth) |
| GET /api/chats/:chatId/messages | List messages (auth) |
| POST /api/chats/:chatId/messages | Save a user message without a reply (auth) |
| POST /api/chats/:chatId/completions | Send a message (`content`, `model_id`) and stream the model's reply as Server-Sent Events (auth) |
| GET /api/credits | Your credit balance (available after holds) and recent credit movements (auth) |
| GET /api/admin/requests | Recent model calls with tokens, hold, charge and provider cost (admin) |
| POST /api/admin/users/:id/credits | Grant or remove credits (`credits`, `reason`) (admin) |
| GET /api/usage/dashboard | Usage dashboard (auth) |
| GET /api/usage/records | Usage records (auth) |
| GET /api/settings | Chat settings (auth) |
| PATCH /api/settings | Update settings (auth) |
| GET /api/subscriptions | Subscription status (auth) |
| GET /api/subscriptions/pro | Pro entitlement check (auth) |
| GET /api/usage-limits | Usage limit (auth) |
| PATCH /api/usage-limits | Update limit (auth) |

## Development

- **Backend**: Add new API routes in `backend/src/`
- **Frontend**: Vue 3 with Composition API, Vite for build tooling
