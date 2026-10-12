#!/usr/bin/env bash
# Usage: diff.sh <snapA> <snapB>
# Diffs two snapshots. The launchpoints, inputs and audio sections are shown first
# and flagged; log sections (pmlog, dmesg) are left out of the full diff.
set -euo pipefail
A="$1"; B="$2"
section() { awk -v s="### $2" '$0==s{f=1;next} /^### /{f=0} f' "$1"; }
red=$'\e[1;31m'; grn=$'\e[1;32m'; off=$'\e[0m'
for s in launchpoints inputs audio; do
  if d=$(diff <(section "$A" $s) <(section "$B" $s)); then echo "${grn}== $s: unchanged${off}"
  else echo "${red}!! $s: CHANGED${off}"; echo "$d"; fi
done
echo; echo "== full diff (logs excluded)"
strip() { awk '/^### (pmlog|dmesg)$/{f=1} /^### /&&!/^### (pmlog|dmesg)$/{f=0} !f' "$1"; }
diff <(strip "$A") <(strip "$B") || true
