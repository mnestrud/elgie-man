#!/bin/sh
# webosbrew boot hook for a RetroArch library on a network share. Install to
# /var/lib/webosbrew/init.d/40-emu (no dot in the name: BusyBox run-parts skips those).
#
# Settings come from /var/lib/emu/emu.conf:
#   SERVER=<NFS server address>   EXPORT=<read-only export>   EXPORT_RW=<read-write export>
#   GAME_APP=<app id ...>         (optional, see below; several separated by spaces)
#   GAME_EXE=<executable name ...>  GAME_RT=<priority>   GAME_COMPOSITOR_RT=<priority>   (optional)
#   GAME_ACTIVITY_KEY=<key code>  GAME_ACTIVITY_SECS=<seconds>                       (optional)
#   GAME_RT_THREADS=<thread name ...>   threads of GAME_EXE that also get SCHED_FIFO GAME_RT (optional)
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
#  - while GAME_APP is in front: SCHED_FIFO GAME_RT for the main thread of GAME_EXE, SCHED_FIFO
#    GAME_COMPOSITOR_RT for surface-manager's main and mali-cmar-backe threads (normal priority
#    again when the app leaves), and GAME_ACTIVITY_KEY pressed on the remote's input device every
#    GAME_ACTIVITY_SECS seconds.
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

# The TV counts only remote input as activity; a pad the app reads itself is invisible to it. Every
# 130 s without remote input it asks for the screensaver, the app refuses, and the compositor then
# sleeps twice for one second (LG code: a QThread::sleep(1) retry on the OLED panel-care status), which
# freezes every app that draws through it. This script presses an unused key on the remote input
# device every <seconds>; the TV counts that as activity. Usage: emu-activity.sh <key code> <seconds>
cat > /tmp/emu-activity.sh <<'EOS'
#!/bin/sh
dev=/dev/input/$(awk '/^N: Name="LGE RCU"/{f=1} f&&/^H:/{for(i=1;i<=NF;i++) if($i ~ /^event/) print $i; exit}' /proc/bus/input/devices)
[ -c "$dev" ] || exit 0
lo=$(printf '\\x%02x' $(($1 & 255))); hi=$(printf '\\x%02x' $(($1 >> 8))); z='\0\0\0\0'
# struct input_event on this 32-bit TV: 8 bytes of time, type, code, value. Key down + sync, key up + sync.
while sleep "$2"; do
    printf "$z$z\x01\0$lo$hi\x01\0\0\0$z$z$z$z" > "$dev"
    printf "$z$z\x01\0$lo$hi$z$z$z$z$z" > "$dev"
done
EOS
chmod +x /tmp/emu-activity.sh

# Apps in GAME_APP read the pads themselves: the pad-as-remote service (padkeys) is told to stay
# quiet while one is in front.
mkdir -p /var/lib/padkeys
for a in $GAME_APP; do grep -qx "$a" /var/lib/padkeys/passthrough 2>/dev/null || echo "$a" >> /var/lib/padkeys/passthrough; done

# Game picture mode while GAME_APP is in front.
gpid=/tmp/emu-game.pid
if [ -n "$GAME_APP" ] && ! { [ -f "$gpid" ] && kill -0 "$(cat "$gpid")" 2>/dev/null; }; then
    (
        sh -c '
            APP=$1; LOG=$2; EXE=$3; RT=$4; CRT=$5; AKEY=$6; ASECS=${7:-100}; RTT=$8; NOTE=/var/lib/emu/picture-mode
            # active on | off: the periodic activity key (see the script written above).
            active() {
                p=$(cat /tmp/emu-active.pid 2>/dev/null); [ -n "$p" ] && kill "$p" 2>/dev/null; rm -f /tmp/emu-active.pid
                [ "$1" = on ] && [ -n "$AKEY" ] || return 0
                /tmp/emu-activity.sh "$AKEY" "$ASECS" > /dev/null 2>&1 &
                echo $! > /tmp/emu-active.pid
            }
            # The compositor draws every app frame; its render thread and its GPU thread run at normal
            # priority. comp fifo <n> | comp other 0 switches both.
            comp() {
                c=$(pidof surface-manager) || return
                for t in /proc/$c/task/*; do
                    case "$(cat $t/comm 2>/dev/null)" in surface-manager|mali-cmar-backe) [ "$1" = fifo ] && chrt -f -p "$2" "${t##*/}" || chrt -o -p 0 "${t##*/}";; esac
                done 2>/dev/null
            }
            S=luna://com.webos.settingsservice
            cur() { luna-send -n 1 $S/getSystemSettings "{\"category\":\"picture\",\"keys\":[\"pictureMode\"]}" < /dev/null | sed -n "s/.*\"pictureMode\": *\"\([^\"]*\)\".*/\1/p"; }
            mode() { luna-send -n 1 $S/setSystemSettings "{\"category\":\"picture\",\"settings\":{\"pictureMode\":\"$1\"}}" < /dev/null > /dev/null; }
            while true; do
                luna-send -i luna://com.webos.applicationManager/getForegroundAppInfo "{\"subscribe\":true}" < /dev/null | while read -r line; do
                    case "$line" in *"\"appId\":"*) ;; *) continue;; esac
                    id=$(echo "$line" | sed -n "s/.*\"appId\":\"\([^\"]*\)\".*/\1/p")
                    # GAME_APP and GAME_EXE may each list several, separated by spaces.
                    case " $APP " in
                    *" $id "*)
                        # The main thread at real-time priority (threads it starts later stay normal).
                        [ -e /tmp/emu-active.pid ] && kill -0 "$(cat /tmp/emu-active.pid)" 2>/dev/null || { active on; [ -e /tmp/emu-active.pid ] && echo "$(date "+%F %T") activity key $AKEY every $ASECS s" >> "$LOG"; }
                        if [ -n "$CRT" ] && [ ! -e /tmp/emu-comp-rt ]; then comp fifo "$CRT"; touch /tmp/emu-comp-rt; echo "$(date "+%F %T") compositor: SCHED_FIFO $CRT" >> "$LOG"; fi
                        if [ -n "$EXE" ] && [ -n "$RT" ]; then
                            for e in $EXE; do for p in $(pidof "$e"); do
                                chrt -p "$p" 2>/dev/null | grep -q SCHED_FIFO || { chrt -R -f -p "$RT" "$p" && echo "$(date "+%F %T") $e pid $p: SCHED_FIFO $RT" >> "$LOG"; }
                            done; done
                            # Named threads too (GAME_RT_THREADS), once they exist (they start after the app comes up).
                            [ -n "$RTT" ] && ( for try in 1 2 3 4 5 6; do sleep 2; for e in $EXE; do for p in $(pidof "$e"); do for t in /proc/$p/task/*; do
                                n=$(cat $t/comm 2>/dev/null); case " $RTT " in *" $n "*) chrt -p "${t##*/}" 2>/dev/null | grep -q SCHED_FIFO || { chrt -f -p "$RT" "${t##*/}" && echo "$(date "+%F %T") $e thread $n: SCHED_FIFO $RT" >> "$LOG"; };; esac
                            done; done; done; done ) &
                        fi
                        if [ ! -s "$NOTE" ]; then
                            m=$(cur)
                            case "$m" in ""|game|hdrGame|dolbyHdrGame) ;; *) echo "$m" > "$NOTE"; mode game; echo "$(date "+%F %T") $id in front: picture mode $m -> game" >> "$LOG";; esac
                        fi;;
                    *)
                        active off
                        if [ -e /tmp/emu-comp-rt ]; then comp other 0; rm -f /tmp/emu-comp-rt; echo "$(date "+%F %T") compositor: back to normal priority" >> "$LOG"; fi
                        if [ -s "$NOTE" ]; then
                            m=$(cat "$NOTE"); mode "$m"; rm -f "$NOTE"; echo "$(date "+%F %T") game app left: picture mode back to $m" >> "$LOG"
                        fi;;
                    esac
                done
                sleep 5
            done' emu-game "$GAME_APP" "$LOG" "$GAME_EXE" "$GAME_RT" "$GAME_COMPOSITOR_RT" "$GAME_ACTIVITY_KEY" "$GAME_ACTIVITY_SECS" "$GAME_RT_THREADS" &
        echo $! > "$gpid"
    ) >/dev/null 2>&1
fi
exit 0
