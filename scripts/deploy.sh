#!/usr/bin/env bash
# Usage: [DASHBOARD=<name>] deploy.sh <tv-ip>
# Installs or updates elgie-man on a TV: copies the QML, config and background to
# /var/lib/elgie-man, installs the boot hook, and applies it now. The TV family is
# read from the TV: webOS 5 (CX, Home is LG's QML host) or webOS 25 (C5, Home is a
# Flutter app and is run under qml-runner instead).
# Uses config.json (or the file named in CONFIG) and backgrounds/ from the repo root
# if present (both gitignored).
# Every folder of qml/dashboards/ with a Dashboard.qml is installed, and can be picked
# on the TV (Launcher settings, Look, Theme). The TV starts with the config's "dashboard"
# key if it has one, else the one named in DASHBOARD, else glass.
set -euo pipefail
cd "$(dirname "$0")/.."
TV="$1"
. scripts/tv.sh

# Only the tested model and webOS pairs are installed on. FORCE=1 installs anyway and
# leaves a marker on the TV so the boot hook's own check lets it through too.
# Short commands only: the webOS 25 shell echoes long lines back into the output.
MODEL=$(send "grep product_id /var/run/nyx/device_info.json" | sed -n 's/.*"product_id": *"\([^"]*\)".*/\1/p' | head -1)
VER=$(send "grep ^VERSION_ID= /etc/os-release" | sed -n 's/^VERSION_ID="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | head -1)
echo "tv: ${MODEL:-unknown model}, webOS ${VER:-unknown}"
case "$MODEL/$VER" in
  OLED??CX*/5.6.2)  FAMILY=cx ;;
  OLED??C5*/10.3.1) FAMILY=c5 ;;
  *)
    if [ "${FORCE:-}" != 1 ]; then
      echo "not installed: tested only on LG CX with webOS 5.6.2 and LG C5 with webOS 10.3.1."
      echo "FORCE=1 scripts/deploy.sh $TV installs anyway, at your own risk."
      exit 1
    fi
    echo "untested TV; installing anyway (FORCE=1)"; FORCED=1
    if send "test -x /usr/bin/flutter-client; echo rc=\$?" | grep -q 'rc=0'; then FAMILY=c5; else FAMILY=cx; fi ;;
esac
echo "family: $FAMILY"
CFG="${CONFIG:-config.json}"

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"; [ -n "${SRV:-}" ] && kill "$SRV" 2>/dev/null || true' EXIT
mkdir -p "$STAGE/pkg/qml/dashboards"
DASH="${DASHBOARD:-$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("dashboard", "glass"))' "$CFG" 2>/dev/null || echo glass)}"
[ -f "qml/dashboards/$DASH/Dashboard.qml" ] || { echo "no dashboard '$DASH' (qml/dashboards/$DASH/Dashboard.qml)"; exit 1; }
echo "dashboard: $DASH"
cp -r qml/Shell.qml qml/Luna.qml qml/models qml/ui "$STAGE/pkg/qml/"
NAMES=""
for d in qml/dashboards/*/; do
  n=$(basename "$d"); [ -f "$d/Dashboard.qml" ] || continue
  [ "$n" = starter ] && [ "$DASH" != starter ] && continue    # the example has no Themes entry to leave it by
  cp -r "$d" "$STAGE/pkg/qml/dashboards/$n"; NAMES="$NAMES\"$n\","
done
cp -r "qml/dashboards/$DASH" "$STAGE/pkg/qml/dashboards/current"
echo "{\"default\": \"$DASH\", \"names\": [${NAMES%,}]}" > "$STAGE/pkg/qml/dashboards/list.json"
cp "qml/hosts/$FAMILY/main.qml" "$STAGE/pkg/qml/main.qml"
# A local config.json always replaces the TV's; otherwise the TV keeps its own
# (or gets the example on first install).
if [ -f "$CFG" ]; then cp "$CFG" "$STAGE/pkg/config.json"; touch "$STAGE/pkg/config.force"
else cp config.example.json "$STAGE/pkg/config.json"; fi
for f in bg.jpg bg-blur.jpg; do [ -f "backgrounds/$f" ] && cp "backgrounds/$f" "$STAGE/pkg/"; done
[ -n "${FORCED:-}" ] && touch "$STAGE/pkg/force"
if [ $FAMILY = c5 ]; then
  cp init.d/05elgieman-c5 "$STAGE/pkg/05elgieman"
  cp scripts/tv-install-c5.sh scripts/tv-uninstall-c5.sh "$STAGE/pkg/"
else
  cp init.d/05elgieman "$STAGE/pkg/05elgieman"
fi
tar -C "$STAGE/pkg" -czf "$STAGE/elgie-man.tgz" .
echo "package: $(du -h "$STAGE/elgie-man.tgz" | cut -f1), $(tar -tzf "$STAGE/elgie-man.tgz" | grep -c .) entries"

# Serve the package to the TV for this run only.
HOST=$(ip route get "$TV" | grep -o 'src [0-9.]*' | cut -d' ' -f2)
PORT=$((18000 + RANDOM % 1000))
python3 -m http.server --bind "$HOST" --directory "$STAGE" "$PORT" >/dev/null 2>&1 & SRV=$!
sleep 1

if [ $FAMILY = c5 ]; then
  for try in 1 2 3; do
    W=$(send "wget -q -O /tmp/elgie-man.tgz http://$HOST:$PORT/elgie-man.tgz; echo wget=\$?" | grep -o 'wget=[0-9][0-9]*' | tail -1)
    [ "$W" = wget=0 ] && break; sleep 2
  done
  [ "$W" = wget=0 ] || { echo "not installed: the TV could not download the package from http://$HOST:$PORT (${W:-no reply})"; exit 1; }
  send "rm -rf /tmp/elgie-new; mkdir /tmp/elgie-new; cd /tmp/elgie-new" >/dev/null
  send "tar -xzf /tmp/elgie-man.tgz -C /tmp/elgie-new; rm /tmp/elgie-man.tgz" >/dev/null
  OUT=$(send "sh /tmp/elgie-new/tv-install-c5.sh"); echo "$OUT"
  echo "$OUT" | grep -q '^installed:' || { echo "not installed: the TV did not report the install as done"; exit 1; }
  echo "done. Press Home on the TV; the failsafe check runs 45 s after the restart (see /tmp/elgie-man.log)."
  exit 0
fi

OUT=$(send "set -e; D=/var/lib/elgie-man; mkdir -p \$D; cd \$D
wget -q -O /tmp/elgie-man.tgz http://$HOST:$PORT/elgie-man.tgz
rm -rf \$D/new; mkdir \$D/new; tar -xzf /tmp/elgie-man.tgz -C \$D/new; rm /tmp/elgie-man.tgz
[ -f \$D/config.json ] && [ ! -f \$D/new/config.force ] && rm \$D/new/config.json || true
for f in config.json bg.jpg bg-blur.jpg; do [ -f \$D/new/\$f ] && mv \$D/new/\$f \$D/\$f; done
chmod 600 \$D/config.json
rm -f \$D/force; [ -f \$D/new/force ] && mv \$D/new/force \$D/force
rm -rf \$D/qml.old; [ -d \$D/qml ] && mv \$D/qml \$D/qml.old; mv \$D/new/qml \$D/qml
cp \$D/new/05elgieman /var/lib/webosbrew/init.d/05elgieman; chmod 755 /var/lib/webosbrew/init.d/05elgieman; rm -rf \$D/new
echo installed: \$(ls \$D/qml | tr '\n' ' ')"); echo "$OUT" | grep -v ' # '
echo "$OUT" | grep -q '^installed:' || { echo "not installed: the TV did not report the install as done (download from http://$HOST:$PORT failed?)"; exit 1; }

# Record the health baseline once, before the launcher has ever run.
send "D=/var/lib/elgie-man; [ -f \$D/health.env ] && exit 0
echo INPUTS=\$(luna-send -n 1 -w 5000 luna://com.webos.service.eim/getAllInputStatus '{}' | grep -o '\"appId\"' | wc -l) > \$D/health.env
echo SOUND_OUTPUT=\$(luna-send -n 1 -w 5000 luna://com.webos.service.apiadapter/audio/getSoundOutput '{}' | grep -o '\"soundOutput\":\"[^\"]*\"' | cut -d'\"' -f4) >> \$D/health.env
cat \$D/health.env"

# Apply now: remove a stale disabled marker and any launcher snapshot made from the
# old QML, then restart Home on the new QML.
send "rm -f /var/lib/elgie-man/disabled; rm -rf /var/lib/elgie-man/snapshot/*; Q=/usr/palm/applications/com.webos.app.home/qml
grep -q \" \$Q \" /proc/mounts && umount \$Q
/var/lib/webosbrew/init.d/05elgieman; sleep 1; tail -2 /tmp/elgie-man.log"
echo "done. Press Home on the TV; the failsafe check runs 45 s after the restart (see /tmp/elgie-man.log)."
