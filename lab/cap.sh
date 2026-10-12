#!/usr/bin/env bash
# Usage: cap.sh <tv-ip> <label>
# Screenshots the TV's display (video + UI planes) to lab/runs/<date>/<label>-<ip>.png.
set -euo pipefail
cd "$(dirname "$0")"
TV="$1"; LABEL="$2"
. ./lib.sh
DIR="runs/$(date +%F)"; mkdir -p "$DIR"
OUT="$DIR/$LABEL-$TV.png"
send "luna-send -n 1 -w 8000 luna://com.webos.service.capture/executeOneShot '{\"path\":\"/tmp/elgie-cap.png\",\"method\":\"DISPLAY\",\"width\":960,\"height\":540,\"format\":\"PNG\"}' >/dev/null; echo B64BEGIN; base64 /tmp/elgie-cap.png; echo B64END; rm -f /tmp/elgie-cap.png" \
  | sed -n '/^B64BEGIN$/,/^B64END$/p' | sed '1d;$d' | base64 -d > "$OUT"
echo "$OUT"
