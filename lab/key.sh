#!/usr/bin/env bash
# Usage: key.sh <tv-ip> <home|back|exit|myapps|recent|evdev-code> [holdMs]
# Presses a remote key on the TV by injecting evdev events into the LGE RCU device.
# KEYDEV=/dev/input/event0 selects the remote device (event0 on the C5, event1 on the CX).
set -euo pipefail
cd "$(dirname "$0")"
TV="$1"; K="$2"; HOLD="${3:-80}"
. ./lib.sh
case "$K" in power) C=116;; home) C=773;; back) C=412;; exit) C=174;; myapps) C=987;; recent) C=1008;; *) C="$K";; esac
REMOTE=/tmp/elgie-lab/tv-key.js
want=$(md5sum tv-key.js | cut -d' ' -f1)
have=$(send "md5sum $REMOTE 2>/dev/null" | grep -oE '^[0-9a-f]{32}' || true)
[ "$want" = "$have" ] || put tv-key.js "$REMOTE" >/dev/null
send "node $REMOTE $C $HOLD ${KEYDEV:-/dev/input/event1}" | grep "^key "
