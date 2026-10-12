#!/bin/sh
# Runs on the TV (webOS 25). Removes elgie-man and returns Home to the stock app.
# deploy.sh keeps a copy at /var/lib/elgie-man/uninstall.sh; uninstall.sh runs it.
# Ends with "result: ok", or "result: FAILED" and what was left in place.
D=/var/lib/elgie-man; APP=com.webos.app.home; H=/usr/palm/applications/$APP
HOOK=/var/lib/webosbrew/init.d/05elgieman
SAM=luna://com.webos.applicationManager
BLOCKED=/var/preferences/com.webos.applicationManager/blockedSystemAppList
call() { luna-send -n 1 -w 5000 "$1" "$2" 2>/dev/null; }
mounted() { grep -q " $H " /proc/mounts; }
blocked() { grep -q "\"$APP\"" $BLOCKED/*.json 2>/dev/null; }

# The hook and the disabled marker stay until Home is unmounted and unblocked: with
# the marker the hook does nothing at boot except release a block left behind.
touch $D/disabled 2>/dev/null
if mounted; then umount $H 2>/dev/null || umount -l $H; fi
if mounted; then
  echo "result: FAILED: Home's folder is still mounted; nothing removed. Reboot the TV and uninstall again."
  exit 1
fi
call $SAM/blockSystemApp "{\"id\":\"$APP\"}" >/dev/null
call $SAM/releaseBlockSystemApp "{\"id\":\"$APP\"}" >/dev/null
if blocked; then sleep 2; call $SAM/releaseBlockSystemApp "{\"id\":\"$APP\"}" >/dev/null; fi
if blocked; then
  echo "result: FAILED: Home is still blocked; hook kept, it releases Home at the next boot. Reboot the TV and uninstall again."
  exit 1
fi
P=$(pgrep -f "qml-runner.*$APP"); [ -n "$P" ] && kill $P
rm -f $HOOK
rm -rf $D /tmp/elgie-man.log /tmp/elgie-man.boot
sleep 12
echo "type: $(call $SAM/getAppInfo "{\"id\":\"$APP\"}" | grep -o '"type": *"[a-z]*"' | head -1)"
echo "mounted: $(grep -c " $H " /proc/mounts)"
echo "blocked: $(grep -c "\"$APP\"" $BLOCKED/*.json)"
echo "home: $(pgrep -f "flutter-client -i $APP" | head -1)"
echo "result: ok"
