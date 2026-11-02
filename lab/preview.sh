#!/usr/bin/env bash
# Usage: preview.sh <scenario.json> [dashboard]
# Runs the launcher on this PC under qmltestrunner with made-up apps (lab/preview/Luna.qml),
# plays the scenario's steps and writes its screenshots. Needs qmltestrunner with the
# QtQuick 2 and QtTest modules and Pillow (Debian: qtdeclarative5-dev-tools
# qml-module-qtquick2 qml-module-qttest python3-pil). Uses config.json and backgrounds/
# from the repo root when present, so a weather entry there is tried for real.
# A scenario: {"activate": "home", "steps": [{"key": "Down"}, {"ask": "setEdit", "arg": true},
# {"hold": "OK", "ms": 900}, {"shot": "/abs/path.png", "wait": 800}]}. Keys: Left Right Up Down OK Back.
set -euo pipefail
cd "$(dirname "$0")/.."
SCENARIO="$(readlink -f "$1")"; DASH="${2:-glass}"
if [ -n "${STAGE:-}" ]; then rm -rf "$STAGE"/*; else STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT; fi
mkdir -p "$STAGE/data" "$STAGE/icons" "$STAGE/dashboards"
cp -r qml/Shell.qml qml/models qml/ui "$STAGE/"
NAMES=""
for d in qml/dashboards/*/; do
  n=$(basename "$d"); [ -f "$d/Dashboard.qml" ] || continue
  cp -r "$d" "$STAGE/dashboards/$n"; NAMES="$NAMES\"$n\","
done
cp -r "qml/dashboards/$DASH" "$STAGE/dashboards/current"
echo "{\"default\": \"$DASH\", \"names\": [${NAMES%,}]}" > "$STAGE/dashboards/list.json"
cp lab/preview/Luna.qml lab/preview/main.qml "$STAGE/"
cp "${CONFIG:-$([ -f config.json ] && echo config.json || echo config.example.json)}" "$STAGE/data/config.json"
[ -f backgrounds/bg.jpg ] && cp backgrounds/bg.jpg "$STAGE/data/"
cp "$SCENARIO" "$STAGE/scenario.json"
python3 lab/preview/icons.py "$STAGE/icons" >/dev/null
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_LOGGING_RULES='qt.qpa.*=false' \
  timeout "${PREVIEW_TIMEOUT:-60}" "${QMLTESTRUNNER:-/usr/lib/qt5/bin/qmltestrunner}" -input "$STAGE/main.qml" 2>&1 \
  | grep -vE '^(\*{9}|Config:|Totals:|QINFO|PASS   : preview::(init|cleanup)|$)' || true
