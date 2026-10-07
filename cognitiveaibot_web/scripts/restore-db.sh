#!/usr/bin/env bash
# Restores a backup made by backup-db.sh into the database at DATABASE_URL,
# replacing what's there. Stop the app first.
#
#   DATABASE_URL=postgresql://… scripts/restore-db.sh backups/cognitiveaibot-….dump
set -euo pipefail
FILE="${1:?Usage: restore-db.sh <backup file>}"
: "${DATABASE_URL:?Set DATABASE_URL}"
[[ -f "$FILE" ]] || { echo "No such file: $FILE" >&2; exit 1; }

if [[ "${CONFIRM:-}" != "yes" ]]; then
  read -r -p "This replaces everything in the target database. Type 'yes' to continue: " answer
  [[ "$answer" == "yes" ]] || { echo "Cancelled."; exit 1; }
fi
"${PG_BIN:+$PG_BIN/}pg_restore" --dbname="$DATABASE_URL" --clean --if-exists --no-owner --no-privileges --exit-on-error "$FILE"
echo "Restored $FILE"
