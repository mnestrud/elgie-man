#!/usr/bin/env bash
# Usage: snap.sh <tv-ip> <label>
# Read-only capture of TV state to lab/runs/<date>/<label>-<ip>.txt.
set -euo pipefail
cd "$(dirname "$0")"
TV="$1"; LABEL="$2"
. ./lib.sh
REMOTE=/tmp/elgie-lab/tv-snap.sh
want=$(md5sum tv-snap.sh | cut -d' ' -f1)
have=$(send "md5sum $REMOTE 2>/dev/null" | grep -oE '^[0-9a-f]{32}' || true)
[ "$want" = "$have" ] || put tv-snap.sh "$REMOTE" >/dev/null
DIR="runs/$(date +%F)"; mkdir -p "$DIR"
OUT="$DIR/$LABEL-$TV.txt"
{ echo "# snap $LABEL $TV at $(date '+%F %T %Z')"
  SEND_TIMEOUT=60 send "sh $REMOTE"; } > "$OUT"
echo "$OUT"
