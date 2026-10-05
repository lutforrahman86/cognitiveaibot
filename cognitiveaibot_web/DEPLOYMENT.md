# Deploying CognitiveAI Bot (web stack)

The web stack is four services: **Postgres 18**, **Redis**, the **API**
(`backend/`, Node 24) and the **web app** (`frontend/`, served by nginx, which
also forwards `/api`, `/v1` and `/uploads` to the API). `docker-compose.yml`
runs all four on one machine, which is enough for staging and a first
production launch. CI builds the images and starts the stack on every pull
request.

## Staging in five steps

1. **A server** with Docker (any VPS with 2 GB RAM is plenty to start), or a
   host that runs Compose files. The host is still to be chosen.
2. **Configuration:** `cp backend/.env.example .env.staging` and fill it in (see
   the checklist below), adding a `POSTGRES_PASSWORD=` line for the database.
   `.env.staging` is git-ignored.
3. **Start it:**
   ```bash
   docker compose --env-file .env.staging up -d --build
   ```
   Migrations run automatically when the API starts.
4. **HTTPS:** put a TLS proxy in front of port 8080 (Caddy, your host's load
   balancer, or Cloudflare). Set `FRONTEND_URL` and `API_URL` to the public
   `https://` address.
5. **The first admin:** sign up on the site, then
   ```bash
   docker compose exec backend npm run make-admin -- you@example.com
   ```

## Configuration checklist

| Setting | Why |
|---|---|
| `JWT_SECRET` | A long random string (`openssl rand -hex 32`). Changing it signs everyone out. |
| `FRONTEND_URL`, `API_URL` | Public addresses; used in emails, Stripe redirects and OAuth callbacks. |
| `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` | Direct provider keys. Run `npm run models:verify` after setting them. |
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | Web payments. Webhook URL: `https://<site>/api/billing/webhook`, with the events listed in `.env.example`. |
| `REVENUECAT_WEBHOOK_AUTH` | App Store purchases. Webhook URL: `https://<site>/api/billing/revenuecat`. Link each plan to its product in the admin Plans tab. |
| `SMTP_URL`, `EMAIL_FROM` | Password reset and email confirmation. Without them emails are only printed to the log. |
| `ADMIN_ALERT_EMAIL` | Where spending-spike and moderation alerts go. |
| `GOOGLE_CLIENT_ID/SECRET`, `GITHUB_CLIENT_ID/SECRET` | Optional social sign-in. Callback: `https://<site>/api/auth/google/callback` (or `/github/`). |
| `SIGNUP_TRIAL_CREDITS` | Credits granted when a new user confirms their email. |

Compose sets `DATABASE_URL`, `REDIS_URL`, `MEDIA_STORAGE_DIR` and `TRUST_PROXY`
for you. Everything else is documented in `backend/.env.example`.

## Backups

`scripts/backup-db.sh` writes a compressed `pg_dump`, keeps 14 days, and can
copy each backup off the machine (`BACKUP_UPLOAD_CMD`). Schedule it daily:

```bash
# crontab -e on the server
15 3 * * * cd /srv/cognitiveaibot_web && BACKUP_UPLOAD_CMD='aws s3 cp "$1" s3://<bucket>/db/' scripts/backup-db.sh --compose >> backups/backup.log 2>&1
```

A backup is only proven by restoring it. After setting up, and then monthly:

```bash
DATABASE_URL=postgresql://… scripts/check-backup.sh backups/cognitiveaibot-<stamp>.dump
```

It restores into a scratch database, compares key table counts, and drops the
scratch copy. To actually restore (stop the API first):
`DATABASE_URL=… scripts/restore-db.sh <file>`.

Also back up the `media` volume if generated videos must survive a server loss
(they expire after 7 days anyway) and the `uploads` volume (profile pictures).

## Before the first real customer

- [ ] Staging runs from CI-built images, and a test payment works end to end
      (Stripe test mode, then one real card).
- [ ] Daily backups are scheduled, copied off-site, and `check-backup.sh` passed.
- [ ] SMTP is set, and a password reset email arrives (check spam scoring).
- [ ] The legal pages' placeholders are filled in and a lawyer has reviewed them.
- [ ] Each provider's terms allow reselling access (see `docs/provider-terms-review.md`).
- [ ] Error alerts reach someone: at least `ADMIN_ALERT_EMAIL` and uptime monitoring of `/api/health`.
