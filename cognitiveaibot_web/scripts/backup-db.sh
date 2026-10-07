#!/usr/bin/env bash
# Backs up the database to BACKUP_DIR (default ./backups) as a compressed
# pg_dump, and deletes backups older than BACKUP_KEEP_DAYS (default 14).
#
#   DATABASE_URL=postgresql://… scripts/backup-db.sh
#
# Run it on a schedule (cron, a systemd timer, or your host's scheduler), e.g.
#   15 3 * * *  cd /srv/cognitiveaibot_web && DATABASE_URL=… scripts/backup-db.sh
# With Docker Compose, run it inside the database container so the client
# matches the server:   scripts/backup-db.sh --compose
#
# A backup on the same machine isn't a backup: set BACKUP_UPLOAD_CMD to copy
# each file off-site, e.g. 'aws s3 cp "$1" s3://my-bucket/db/' ($1 is the file).
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="$BACKUP_DIR/cognitiveaibot-$STAMP.dump"
mkdir -p "$BACKUP_DIR"

if [[ "${1:-}" == "--compose" ]]; then
  docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$FILE.partial"
else
  : "${DATABASE_URL:?Set DATABASE_URL}"
  "${PG_BIN:+$PG_BIN/}pg_dump" --dbname="$DATABASE_URL" -Fc --file="$FILE.partial"
fi
# Only a finished dump gets the real name, so a failed run never looks like a backup.
mv "$FILE.partial" "$FILE"
echo "Backed up to $FILE ($(du -h "$FILE" | cut -f1))"

if [[ -n "${BACKUP_UPLOAD_CMD:-}" ]]; then
  bash -c "$BACKUP_UPLOAD_CMD" _ "$FILE"
  echo "Uploaded $FILE"
fi

find "$BACKUP_DIR" -name 'cognitiveaibot-*.dump' -mtime "+$KEEP_DAYS" -print -delete
