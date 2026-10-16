#!/bin/bash
# O-08: host health for RPC, QOGE cursor, redis, postgres, ticker.
# Prints no secrets. Exit 1 if a hard check fails.
set -euo pipefail

STATE_DIR=/var/lib/opencex
LOG=/var/log/opencex-health.log
STATUS="$STATE_DIR/health.status"
CURSOR_FILE="$STATE_DIR/qoge.cursor"
QOGE_CURRENCY=21
CLI=/root/qogecoin/src/qogecoin-cli
CONF=/root/.qogecoin/qogecoin.conf
GAP_HARD=50

umask 077
install -d -m 700 "$STATE_DIR"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
fail=0
notes=()

log() { echo "$ts $*" | tee -a "$LOG" >/dev/null; echo "$*"; }

if ! docker exec redis redis-cli PING 2>/dev/null | grep -qx PONG; then
  log "FAIL redis_ping"
  fail=1
  notes+=("redis")
fi

if ! docker exec postgresql pg_isready -U opencex -d opencex >/dev/null 2>&1; then
  log "FAIL postgres"
  fail=1
  notes+=("postgres")
fi

if ! docker exec opencex-qoge python -c "import socket; s=socket.socket(); s.settimeout(4); s.connect(('host.docker.internal',8332)); s.close()" >/dev/null 2>&1; then
  log "FAIL qoge_rpc_tcp"
  fail=1
  notes+=("qoge_rpc")
fi

tip=""
cursor=""
gap=""
if [ -x "$CLI" ]; then
  tip=$("$CLI" -conf="$CONF" getblockcount 2>/dev/null || true)
fi
cursor=$(docker exec postgresql psql -U opencex -d opencex -tAc "SELECT block_id FROM cryptocoins_lastprocessedblock WHERE currency=${QOGE_CURRENCY};" 2>/dev/null | tr -d '[:space:]' || true)

if [[ "$tip" =~ ^[0-9]+$ && "$cursor" =~ ^[0-9]+$ ]]; then
  gap=$((tip - cursor))
  prev=""
  if [ -f "$CURSOR_FILE" ]; then
    prev=$(cat "$CURSOR_FILE")
  fi
  echo "$cursor" > "$CURSOR_FILE"
  if [ "$gap" -gt "$GAP_HARD" ]; then
    if [ -n "$prev" ] && [ "$cursor" = "$prev" ]; then
      log "FAIL qoge_cursor_stalled tip=$tip cursor=$cursor gap=$gap"
      fail=1
      notes+=("qoge_stalled")
    else
      log "WARN qoge_catchup tip=$tip cursor=$cursor gap=$gap"
      notes+=("qoge_catchup")
    fi
  fi
else
  log "FAIL qoge_height tip=${tip:-empty} cursor=${cursor:-empty}"
  fail=1
  notes+=("qoge_height")
fi

code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 https://exchange.qoge.org/api/public/v1/ticker || echo 000)
if [ "$code" != "200" ]; then
  log "FAIL ticker http=$code"
  fail=1
  notes+=("ticker")
fi

{
  echo "ts=$ts"
  echo "ok=$([ "$fail" -eq 0 ] && echo true || echo false)"
  echo "tip=${tip:-}"
  echo "cursor=${cursor:-}"
  echo "gap=${gap:-}"
  echo "ticker=$code"
  echo "notes=${notes[*]-}"
} > "$STATUS"
chmod 600 "$STATUS"

if [ "$fail" -ne 0 ]; then
  log "HEALTH_FAIL ${notes[*]}"
  exit 1
fi
log "HEALTH_OK tip=$tip cursor=$cursor gap=$gap ticker=$code"
exit 0
