#!/bin/bash
# Daily OpenCEX recovery dump. Prints no secret values.
set -euo pipefail

DEST=/root/opencex-backups
KEEP_DAYS=7
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
umask 077
install -d -m 700 "$DEST"

dump="$DEST/opencex-${STAMP}.dump"
envcopy="$DEST/backend.env-${STAMP}"
composecopy="$DEST/docker-compose.yml-${STAMP}"

docker exec postgresql pg_dump -U opencex -d opencex -Fc > "$dump"
chmod 600 "$dump"
# Config recovery copies (contain secrets). Mode 600.
cp -a /app/opencex/backend/.env "$envcopy"
cp -a /app/opencex/docker-compose.yml "$composecopy"
chmod 600 "$envcopy" "$composecopy"

# Drop dumps older than KEEP_DAYS. Never touch /root/opencex-custody.
find "$DEST" -maxdepth 1 -type f -mtime +${KEEP_DAYS} -name 'opencex-*.dump' -delete
find "$DEST" -maxdepth 1 -type f -mtime +${KEEP_DAYS} -name 'backend.env-*' -delete
find "$DEST" -maxdepth 1 -type f -mtime +${KEEP_DAYS} -name 'docker-compose.yml-*' -delete

dump_bytes=$(stat -c %s "$dump")
echo "backup_ok stamp=${STAMP} dump_bytes=${dump_bytes} dest=${DEST}"
