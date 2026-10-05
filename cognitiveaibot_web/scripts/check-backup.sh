#!/usr/bin/env bash
# Proves a backup is usable: restores it into a scratch database and compares
# row counts of the key tables with the live database. Run it after setting
# up backups, and regularly after that (an untested backup isn't a backup).
#
#   DATABASE_URL=postgresql://…/cognitiveaibot scripts/check-backup.sh backups/cognitiveaibot-….dump
set -euo pipefail
FILE="${1:?Usage: check-backup.sh <backup file>}"
: "${DATABASE_URL:?Set DATABASE_URL}"
BIN="${PG_BIN:+$PG_BIN/}"
SCRATCH="cognitiveaibot_restore_check_$$"
ADMIN_URL="${DATABASE_URL%/*}/postgres"
SCRATCH_URL="${DATABASE_URL%/*}/$SCRATCH"

"${BIN}psql" "$ADMIN_URL" -qc "CREATE DATABASE \"$SCRATCH\""
trap '"${BIN}psql" "$ADMIN_URL" -qc "DROP DATABASE IF EXISTS \"$SCRATCH\""' EXIT
"${BIN}pg_restore" --dbname="$SCRATCH_URL" --no-owner --no-privileges --exit-on-error "$FILE"

TABLES="users chats messages credit_accounts credit_transactions subscriptions plans api_keys request_logs ai_models"
status=0
for t in $TABLES; do
  live=$("${BIN}psql" "$DATABASE_URL" -Atc "SELECT count(*) FROM $t")
  restored=$("${BIN}psql" "$SCRATCH_URL" -Atc "SELECT count(*) FROM $t")
  mark="ok"; [[ "$live" == "$restored" ]] || { mark="differs (newer rows since the backup?)"; }
  printf '%-20s live %-8s restored %-8s %s\n' "$t" "$live" "$restored" "$mark"
done
echo "The backup restores cleanly."
