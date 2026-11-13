#!/usr/bin/env bash
# Usage: scripts/emu-deploy.sh <ssh-host> [retroarch.ipk]
# Sets a rooted LG CX up to run RetroArch from a library on an NFS share:
#   - installs tv/emu-hook.sh as the boot hook 40-emu and runs it (mounts, jail config, Game mode);
#   - writes /var/lib/emu/emu.conf from emu.conf in the repo root (gitignored; see emu.conf.example);
#   - installs the RetroArch IPK when one is given (webosbrew/RetroArch, the gles3 build);
#   - puts tv/retroarch.cfg where RetroArch reads it (its HOME is the app folder);
#   - lists RetroArch in /var/lib/padkeys/passthrough, for a pad-as-remote service that honors it.
# <ssh-host> is a root ssh alias (Homebrew Channel's dropbear). Nothing here shows on the screen.
set -euo pipefail
cd "$(dirname "$0")/.."
H="${1:?usage: emu-deploy.sh <ssh-host> [retroarch.ipk]}"; IPK="${2:-}"
ID=com.retroarch.webos
APPDIR=/media/developer/apps/usr/palm/applications/$ID
[ -r emu.conf ] || { echo "emu.conf missing (copy emu.conf.example)"; exit 1; }
tv() { ssh -o ConnectTimeout=8 "$H" "$@"; }

tv 'mkdir -p /var/lib/emu /var/lib/padkeys /media/developer/temp'
scp -q emu.conf "$H":/var/lib/emu/emu.conf
scp -q tv/emu-hook.sh "$H":/var/lib/webosbrew/init.d/40-emu
tv "chmod +x /var/lib/webosbrew/init.d/40-emu; grep -qx $ID /var/lib/padkeys/passthrough 2>/dev/null || echo $ID >> /var/lib/padkeys/passthrough
    /var/lib/webosbrew/init.d/40-emu; sleep 3; tail -4 /tmp/emu-hook.log; grep -c ' /media/developer/emu' /proc/mounts"

if [ -n "$IPK" ]; then
    scp -q "$IPK" "$H":/media/developer/temp/retroarch.ipk
    # Installed as "testing" from /media/developer/temp, as the Homebrew Channel does; the
    # subscription is kept open because the call returns before the installer answers.
    tv "luna-send -i luna://com.webos.appInstallService/dev/install '{\"id\":\"testing\",\"ipkUrl\":\"/media/developer/temp/retroarch.ipk\",\"subscribe\":true}' < /dev/null > /tmp/emu-install.log 2>&1 & p=\$!
        for _ in \$(seq 90); do sleep 1; grep -q -E '\"state\": *\"(installed|install failed)\"|errorText' /tmp/emu-install.log && break; done
        kill \$p 2>/dev/null; grep -o -E '\"state\": *\"[^\"]*\"|errorText[^,]*' /tmp/emu-install.log | tail -1; rm -f /media/developer/temp/retroarch.ipk"
fi
tv "[ -d $APPDIR ]" || { echo "RetroArch is not installed: give the IPK as the second argument"; exit 1; }
tv "mkdir -p $APPDIR/.config/retroarch && cat > $APPDIR/.config/retroarch/retroarch.cfg && chmod -R a+rwX $APPDIR/.config" < tv/retroarch.cfg
echo "done: $H"
