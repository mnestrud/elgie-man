# Shared helpers for lab scripts. Source this file; set TV first.
# send runs one shell command line over the TV's root telnet and prints its output.
send() {
  (exec 3<>"/dev/tcp/$TV/23"; sleep 0.5; printf '%s\r\nexit\r\n' "$1" >&3
   timeout "${SEND_TIMEOUT:-30}" cat <&3 | tr -d '\0\r' | sed '1,/^~ # /d' | grep -v '^~ # $' | grep -v '^exit$' || true)
}

# put copies a local file to the TV as base64 in short lines (telnet line limit 4096 bytes).
put() {
  send "mkdir -p $(dirname "$2") && rm -f $2.b64" >/dev/null
  base64 -w 900 "$1" | while read -r line; do send "echo $line >> $2.b64" >/dev/null; done
  send "base64 -d $2.b64 > $2 && rm $2.b64 && md5sum $2" | grep -E '^[0-9a-f]{32} '
}

# luna sends one luna-send -n 1 call: luna <uri> <json>
luna() { send "luna-send -n 1 -w 5000 '$1' '$2'"; }
