#!/bin/sh
# webosbrew boot hook for a RetroArch library on a network share. Install to
# /var/lib/webosbrew/init.d/40-emu (no dot in the name: BusyBox run-parts skips those).
#
# Settings come from /var/lib/emu/emu.conf:
#   SERVER=<NFS server address>   EXPORT=<read-only export>   EXPORT_RW=<read-write export>
#   GAME_APP=<app id>             (optional, see below)
#
# What it does:
#  - mounts EXPORT at /media/developer/emu and EXPORT_RW at /media/developer/emu/rw (NFSv3; the
#    TV has no mount.nfs helper, so the kernel's own mount options are given), retrying until the
#    network and the server are up, and again whenever the mount is gone;
#  - shows both mounts to natively-run apps: those are chrooted with /media/developer bound without
#    its sub-mounts, so an edited copy of the jail config that names the two mounts is bound over
#    LG's file. LG's file is not written;
#  - with GAME_APP set in emu.conf (an app id): while that app is in front the TV's picture mode is
#    Game, LG's low-lag mode; the mode it replaced is noted in /var/lib/emu/picture-mode and put
#    back when the app leaves the front (or at the next start of this hook, after a crash).
CONF=/var/lib/emu/emu.conf
M=/media/developer/emu
LOG=/tmp/emu-hook.log
[ -r "$CONF" ] || exit 0
. "$CONF"
[ -n "$SERVER" ] && [ -n "$EXPORT" ] || exit 0
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# Mount points must exist with or without the share: the jail config below names them, and a
# missing directory there would stop every native app from starting.
mounted() { grep -q " $1 nfs " /proc/mounts; }
mounted "$M" || mkdir -p "$M/rw"

J=/etc/jail_native_devmode.conf
C=/var/lib/emu/jail_native_devmode.conf
if [ -r "$J" ] && ! grep -q "^mount ro $M\$" "$J"; then
    awk -v m="$M" '{ print } /^mount rw \/media\/developer$/ { print "mount ro " m; print "mount rw " m "/rw" }' "$J" > "$C.new"
    if grep -q "^mount ro $M\$" "$C.new"; then
        mv "$C.new" "$C" && mount --bind "$C" "$J" && log "jail config: share added"
    else
        rm -f "$C.new"; log "jail config: anchor line not found, left alone"
    fi
fi

OPTS="nolock,vers=3,proto=tcp,mountproto=tcp,soft,timeo=100,retrans=3,addr=$SERVER"
pid=/tmp/emu-mount.pid
if ! { [ -f "$pid" ] && kill -0 "$(cat "$pid")" 2>/dev/null; }; then
    (
        sh -c '
            M=$1; SERVER=$2; EXPORT=$3; EXPORT_RW=$4; OPTS=$5; LOG=$6
            while true; do
                if ! grep -q " $M nfs " /proc/mounts; then
                    mount -t nfs -o "ro,$OPTS" "$SERVER:$EXPORT" "$M" 2>/dev/null && echo "$(date "+%F %T") mounted $M" >> "$LOG"
                fi
                if [ -n "$EXPORT_RW" ] && grep -q " $M nfs " /proc/mounts && ! grep -q " $M/rw nfs " /proc/mounts; then
                    mount -t nfs -o "rw,$OPTS" "$SERVER:$EXPORT_RW" "$M/rw" 2>/dev/null && echo "$(date "+%F %T") mounted $M/rw" >> "$LOG"
                fi
                sleep 15
            done' emu-mount "$M" "$SERVER" "$EXPORT" "$EXPORT_RW" "$OPTS" "$LOG" &
        echo $! > "$pid"
    ) >/dev/null 2>&1
fi

# Game picture mode while GAME_APP is in front.
gpid=/tmp/emu-game.pid
if [ -n "$GAME_APP" ] && ! { [ -f "$gpid" ] && kill -0 "$(cat "$gpid")" 2>/dev/null; }; then
    (
        sh -c '
            APP=$1; LOG=$2; NOTE=/var/lib/emu/picture-mode
            S=luna://com.webos.settingsservice
            cur() { luna-send -n 1 $S/getSystemSettings "{\"category\":\"picture\",\"keys\":[\"pictureMode\"]}" < /dev/null | sed -n "s/.*\"pictureMode\": *\"\([^\"]*\)\".*/\1/p"; }
            mode() { luna-send -n 1 $S/setSystemSettings "{\"category\":\"picture\",\"settings\":{\"pictureMode\":\"$1\"}}" < /dev/null > /dev/null; }
            while true; do
                luna-send -i luna://com.webos.applicationManager/getForegroundAppInfo "{\"subscribe\":true}" < /dev/null | while read -r line; do
                    case "$line" in
                    *"\"appId\":\"$APP\""*)
                        if [ ! -s "$NOTE" ]; then
                            m=$(cur)
                            case "$m" in ""|game|hdrGame|dolbyHdrGame) ;; *) echo "$m" > "$NOTE"; mode game; echo "$(date "+%F %T") $APP in front: picture mode $m -> game" >> "$LOG";; esac
                        fi;;
                    *"\"appId\":"*)
                        if [ -s "$NOTE" ]; then
                            m=$(cat "$NOTE"); mode "$m"; rm -f "$NOTE"; echo "$(date "+%F %T") $APP left: picture mode back to $m" >> "$LOG"
                        fi;;
                    esac
                done
                sleep 5
            done' emu-game "$GAME_APP" "$LOG" &
        echo $! > "$gpid"
    ) >/dev/null 2>&1
fi
exit 0
