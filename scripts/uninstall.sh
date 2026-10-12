#!/usr/bin/env bash
# Usage: uninstall.sh <tv-ip>
# Removes elgie-man from a TV and returns it to stock Home. Exits 1, saying what was
# left in place, if the TV did not report the removal as done.
set -euo pipefail
cd "$(dirname "$0")/.."
TV="$1"
. scripts/tv.sh
finish() {
  echo "$1"
  if echo "$1" | grep -q '^result: ok'; then echo "uninstalled. Home restarts as stock LG Home."; exit 0; fi
  echo "NOT uninstalled: the TV did not report the removal as done (see above)."; exit 1
}
if send "test -x /usr/bin/flutter-client; echo rc=\$?" | grep -q 'rc=0'; then
  # webOS 25: the steps are in the script deploy.sh left on the TV.
  send "cp /var/lib/elgie-man/uninstall.sh /tmp/elgie-uninstall.sh" >/dev/null
  finish "$(send "sh /tmp/elgie-uninstall.sh; rm -f /tmp/elgie-uninstall.sh")"
fi
# The folder is removed only once both mounts are gone: it is what they show. If they
# will not come off, the disabled marker keeps the hook off and a reboot clears them.
# (R keeps the result line out of the shell's echo of these commands.)
finish "$(send "D=/var/lib/elgie-man; Q=/usr/palm/applications/com.webos.app.home/qml; R=result
S=/mnt/lg/cmn_data/checkpoint/com.webos.app.home
HP() { pgrep -f '^/usr/bin/com.webos.app.home'; }
M() { grep -q -e \" \$Q \" -e \" \$S \" /proc/mounts; }
U() { grep -q \" \$Q \" /proc/mounts && umount \$Q; grep -q \" \$S \" /proc/mounts && umount \$S; }
touch \$D/disabled 2>/dev/null; U
if M; then H=\$(HP); [ -n \"\$H\" ] && kill \$H; sleep 2; U; fi
if M; then echo \$R: FAILED: still mounted, nothing removed. Reboot the TV and uninstall again.; exit; fi
rm -f /var/lib/webosbrew/init.d/05elgieman
rm -rf /tmp/checkpoint/com.webos.app.home /tmp/checkpoint/hash_check_com.webos.app.home
[ -f /tmp/elgie-criu_enable.bak ] && mv /tmp/elgie-criu_enable.bak /tmp/criu_enable
C='/home/root/.config/Unknown Organization/com.webos.app.home.conf'
[ -f \"\$C\" ] && awk '/^\\[/{s=(\$0==\"[elgieman]\")} !s' \"\$C\" > /tmp/elgie.conf && mv /tmp/elgie.conf \"\$C\"
rm -rf \$D /tmp/elgie-man.log
H=\$(HP); [ -n \"\$H\" ] && kill \$H
sleep 12; echo home: \$(HP); echo mounts: \$(grep -c -e \" \$Q \" -e \" \$S \" /proc/mounts); echo \$R: ok")"
