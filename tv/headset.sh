#!/bin/sh
# USB headset sound on a rooted webOS 5 TV. Installed as /var/lib/elgie-man/headset.sh and run
# by the launcher's Headset pill (over the Homebrew Channel's exec) and by the boot hook.
#   headset.sh on       route the TV's sound to the USB headset; prints the status as JSON
#   headset.sh off      undo it and put the sound output back; prints the status
#   headset.sh status   {"present":..,"on":..,"soundOutput":"..","prev":"..","simplink":".."}
#   headset.sh reset    at boot and on a resume from standby: "off" if a route was left on
#   headset.sh listen   started by "on": ends the route when the headset's link drops
#
# webOS 5 never sends sound to a USB audio device itself. The TV's mix is readable on the ALSA
# capture hw:0,12 (16-bit 48 kHz stereo, before the volume stage, so the TV's volume does not
# apply; the headset's own dial does). PulseAudio sees the USB device as a sink, so the route
# is a parec | pacat pipe from a PulseAudio source on hw:0,12 into that sink. LG's PulseAudio
# has no module-loopback, and its policy module moves a new stream to the TV's own sink, so
# the stream is moved onto the headset sink right after it starts.
#
# While the route is on, Sound Out is Wired Headphones (soundOutput "headphone"), which keeps
# the room quiet: it drives an analog path with nothing on it. SIMPLINK is off for the while:
# with it on, audiod puts the sound back on a receiver on HDMI ARC within seconds of a CEC
# event. Both are restored by "off", SIMPLINK first, since the receiver only takes the sound
# again once CEC is back.
#
# The route ends: from the pill; when the dongle is unplugged (the pipe exits, and its wrapper
# calls "off"); when the headset is switched off; at a real boot and on a resume from standby
# ("reset"). A switched-off headset shows nowhere on USB, ALSA, PulseAudio or HID, but the
# dongle's USB serial port (INZONE Hub's channel, 460800 8N1) pushes a link event while the
# port is held open: 04 ff 0a 00 96 c3 12 01 a0 00 00 <link> <sum>, link 01 up, 00 down.
# "listen" holds the port, asks once for the state at start, and otherwise only reads.
# State: /var/lib/elgie-man/headset.state (PREV=<sound output before>, SIMPLINK=<on|off before>).
D=/var/lib/elgie-man
ST=$D/headset.state
DOWN=$D/headset.down          # the link dropped; removed when it comes back
L=/tmp/elgie-man.log
SRC=tvmix
TAP=hw:0,12
PORT=/dev/ttyACM0
GRACE=0                       # seconds a link drop must last before the route ends (0: at once)

log() { echo "$(date '+%F %T') headset: $*" >> $L; }
toast() {
  luna-send -n 1 -w 3000 luna://com.webos.notification/createToast \
    "{\"sourceId\":\"com.webos.app.home\",\"message\":\"$1\"}" >/dev/null 2>&1 < /dev/null
}
# luna-send quits at once, printing nothing, when its stdin is a closed pipe (a shell over ssh
# without a terminal, the Homebrew Channel's exec): it gets /dev/null. Its output is lost
# when piped straight on, so it goes through a file. An empty reply is asked once more.
luna() {
  f=/tmp/headset-luna.$$
  luna-send -n 1 -w 5000 "$@" > $f 2>&1 < /dev/null
  [ -s $f ] || { usleep 300000; luna-send -n 1 -w 5000 "$@" > $f 2>&1 < /dev/null; }
  cat $f; rm -f $f
}
setting() { luna luna://com.webos.settingsservice/getSystemSettings "{\"category\":\"$1\",\"keys\":[\"$2\"]}" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p"; }
set_setting() { luna luna://com.webos.settingsservice/setSystemSettings "{\"category\":\"$1\",\"settings\":{\"$2\":\"$3\"}}" | grep -q '"returnValue":true'; }
sound_output() { luna luna://com.webos.service.apiadapter/audio/getSoundOutput '{}' | sed -n 's/.*"soundOutput":"\([^"]*\)".*/\1/p'; }
# Through the settings service: apiadapter's changeSoundOutput answers true and changes nothing.
set_sound_output() {
  set_setting sound soundOutput "$1" || return 1
  n=0; while [ $n -lt 4 ]; do [ "$(sound_output)" = "$1" ] && return 0; usleep 250000; n=$((n + 1)); done
  return 1
}
simplink() { setting other simplinkEnable; }
set_simplink() { set_setting other simplinkEnable "$1"; }
power_state() { luna luna://com.webos.service.tvpower/power/getPowerState '{}' | sed -n 's/.*"state": *"\([^"]*\)".*/\1/p'; }

usb_sink() { pactl list short sinks 2>/dev/null | awk '$2 ~ /^alsa_output\.usb-/ { print $2; exit }'; }
present() { grep -q USB-Audio /proc/asound/cards 2>/dev/null && [ -n "$(usb_sink)" ]; }
source_module() { pactl list short modules 2>/dev/null | awk -v s="source_name=$SRC" 'index($0, s) { print $1; exit }'; }
pipe_pids() { pgrep -f "parec -d $SRC" 2>/dev/null; pgrep -f "pacat -p -d alsa_output.usb-" 2>/dev/null; }
is_on() { [ -f $ST ] && [ -n "$(pgrep -f "pacat -p -d alsa_output.usb-")" ]; }
prev() { sed -n 's/^PREV=//p' $ST 2>/dev/null; }
prev_simplink() { sed -n 's/^SIMPLINK=//p' $ST 2>/dev/null; }
listener_pids() { pgrep -f "headset.sh listen$" 2>/dev/null; }

status() {
  p=false; o=false; present && p=true; is_on && o=true
  echo "{\"present\":$p,\"on\":$o,\"soundOutput\":\"$(sound_output)\",\"prev\":\"$(prev)\",\"simplink\":\"$(prev_simplink)\"$1}"
}
fail() { log "$1"; echo "{\"ok\":false,\"error\":\"$1\"}"; exit 1; }
name_of() {
  case "$1" in
    external_arc) echo "HDMI ARC" ;; tv_speaker) echo "TV speaker" ;; external_optical) echo "Optical" ;;
    bt_soundbar) echo "Bluetooth" ;; headphone) echo "Wired Headphones" ;; *) echo "$1" ;;
  esac
}

# Moves every pacat stream onto the USB sink (the policy module parks it on the TV's) and
# puts the sink at full level: the headset's dial is the volume.
place_stream() {
  sink=$1; n=0
  while [ $n -lt 20 ]; do
    ids=$(pactl list sink-inputs 2>/dev/null | awk '/^Sink Input #/ { id=substr($3, 2) } /application.process.binary = "pacat"/ { print id }')
    [ -n "$ids" ] && break
    usleep 250000; n=$((n + 1))
  done
  [ -n "$ids" ] || return 1
  for id in $ids; do pactl move-sink-input $id $sink 2>/dev/null; done
  pactl set-sink-volume $sink 100% 2>/dev/null
}

# The listener gets its own session and nohup: the Homebrew Channel's exec ends what is left
# of its command's process group when the command returns.
start_listener() {
  [ -c $PORT ] || { log "no $PORT: a switched-off headset is not detected"; return 0; }
  [ -n "$(listener_pids)" ] && return 0
  nohup setsid "$0" listen </dev/null >/dev/null 2>&1 &
}
stop_listener() {
  for lp in $(listener_pids); do kill -TERM -$lp 2>/dev/null || kill $lp 2>/dev/null; done
  rm -f $DOWN
}
# Holds the dongle's serial port; a link-down that lasts GRACE seconds ends the route.
listen() {
  stty -F $PORT 460800 raw -echo clocal -hupcl 2>/dev/null || { log "listener: stty failed"; exit 0; }
  exec 3<> $PORT || { log "listener: cannot open $PORT"; exit 0; }
  log "listening on $PORT"
  # The one write: a ConnectStatus2Ghz GET (transaction 1), since the dongle only pushes changes
  # and the headset may already be off. The reply is 04 ff 0a 00 96 c3 12 01 10 01 00 <link> <sum>.
  printf '\001\000\374\010\226\303\041\001\001\001\000\175' >&3
  while [ -f $ST ]; do
    c=$(dd bs=64 count=1 <&3 2>/dev/null | od -An -tx1 -v | tr -d " \n")
    [ -n "$c" ] || { sleep 1; continue; }
    case "$c" in
      *1201a00000010d*|*1201100100017e*) rm -f $DOWN; log "link up" ;;
      *1201a00000000c*|*1201100100007d*)
        [ -f $DOWN ] && continue
        touch $DOWN; log "link down"
        if [ "$GRACE" -gt 0 ]; then
          ( sleep $GRACE; [ -f $ST ] && [ -f $DOWN ] && setsid "$0" off headset-off >/dev/null 2>&1 ) &
        else
          setsid "$0" off headset-off >/dev/null 2>&1 < /dev/null &
        fi
        ;;
    esac
  done
}

on() {
  present || fail "no USB headset"
  ps=$(power_state)
  case "$ps" in ""|Active|"Screen Off"|"Screen Saver") ;; *) fail "TV is not on ($ps)" ;; esac
  sink=$(usb_sink)
  cur=$(sound_output)
  if [ ! -f $ST ]; then
    [ -n "$cur" ] || fail "sound output not read"
    echo "PREV=$cur" > $ST
    sl=$(simplink); [ -n "$sl" ] && echo "SIMPLINK=$sl" >> $ST
  fi
  [ "$(simplink)" = off ] || set_simplink off || log "SIMPLINK not turned off"
  if [ "$cur" != headphone ]; then
    set_sound_output headphone || { set_simplink "$(prev_simplink)"; rm -f $ST; fail "could not set Wired Headphones"; }
  fi
  [ -n "$(source_module)" ] || pactl load-module module-alsa-source device=$TAP source_name=$SRC rate=48000 channels=2 format=s16le tsched=0 >/dev/null 2>&1 \
    || { rm -f $ST; fail "could not open the TV mix"; }
  if [ -z "$(pgrep -f "pacat -p -d alsa_output.usb-")" ]; then
    setsid sh -c "parec -d $SRC --format=s16le --rate=48000 --channels=2 --latency-msec=40 \
      | pacat -p -d $sink --format=s16le --rate=48000 --channels=2 --latency-msec=40; \
      [ -f $ST ] && $0 off ended" >/dev/null 2>&1 < /dev/null &
  fi
  place_stream $sink || { "$0" off >/dev/null; fail "no sound stream to the headset"; }
  start_listener
  log "on: $cur -> headphone, sink $sink"
  status ",\"message\":\"Headset on\""
}

# $1: "" (the pill), "ended" (the pipe stopped: dongle unplugged), "headset-off" (the link
# dropped), "reset" (boot or resume).
off() {
  why=$1
  was=$(prev); sl=$(prev_simplink); rm -f $ST     # read and removed first: the pipe's wrapper must find no route
  [ "$sl" = on ] && { set_simplink on || log "SIMPLINK not turned back on"; }
  stop_listener
  for pid in $(pipe_pids); do kill $pid 2>/dev/null; done
  m=$(source_module); [ -n "$m" ] && pactl unload-module $m 2>/dev/null
  cur=$(sound_output); back=""
  # No wait between SIMPLINK on and the output change until a run shows one is needed.
  if [ -n "$was" ] && [ "$was" != headphone ] && [ "$cur" = headphone ]; then
    set_sound_output "$was" && back=$was || log "set $was failed (reads $(sound_output))"
  fi
  log "off${why:+ ($why)}: sound ${back:-left as $cur}${sl:+, SIMPLINK $sl}"
  msg="Headset off${back:+; sound back to $(name_of $back)}"
  case "$why" in
    ended) toast "Headset unplugged${back:+; sound back to $(name_of $back)}" ;;
    headset-off) toast "$msg" ;;
    reset) [ -n "$back" ] && toast "$msg" ;;
  esac
  status ",\"message\":\"$msg\""
}

case "$1" in
  on) if is_on; then place_stream "$(usb_sink)" >/dev/null; start_listener; status ",\"message\":\"Headset already on\""; else on; fi ;;
  off) if [ -f $ST ] || [ -z "$2" ]; then off "$2"; else status; fi ;;
  status) status ;;
  reset) if [ -f $ST ]; then off reset; else status; fi ;;
  listen) listen ;;
  *) echo "usage: headset.sh on|off|status|reset" >&2; exit 2 ;;
esac
