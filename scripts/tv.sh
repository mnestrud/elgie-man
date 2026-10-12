# Shared helper for scripts: run a command on a rooted LG TV over its root telnet shell.
# Source it with TV set; send "<command line>" prints the command's output.
send() {
  (exec 3<>"/dev/tcp/$TV/23"; sleep 0.5; printf '%s\r\nexit\r\n' "$1" >&3
   timeout "${SEND_TIMEOUT:-60}" cat <&3 | tr -d '\0\r' | sed '1,/^~ # /d' | grep -v '^~ # $' | grep -v '^exit$' || true)
}
