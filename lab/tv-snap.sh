#!/bin/sh
# Read-only state capture, run on the TV by lab/snap.sh. Prints "### <section>" headers.
L='luna-send -n 1 -w 5000'
sec() { echo; echo "### $1"; }
homepid() { { pgrep -f '^/usr/bin/com.webos.app.home'; pgrep -f 'flutter-client -i com.webos.app.home'; pgrep -f 'qml-runner.*com.webos.app.home'; } | head -1; }

sec uptime; date; uptime
sec memory; free; grep -E 'MemTotal|MemFree|MemAvailable|Cached|SwapFree' /proc/meminfo
sec home-rss-pss
P=$(homepid)
if [ -n "$P" ]; then echo "pid=$P"; grep -E '^(Rss|Pss|Swap):' /proc/$P/smaps_rollup; tr '\0' ' ' < /proc/$P/cmdline | cut -c1-300; echo
else echo "home not running"; fi
sec processes
ps -eo pid,rss,etime,args | grep -E 'com.webos.app.home|/sam|/eim|homelaunchpoints|criu|preload-manager|qml-runner|flutter-client|elgie' | grep -v grep | cut -c1-200
sec units
for u in sam eim homelaunchpoints criu preload-manager; do printf '%s: ' $u; systemctl is-active $u 2>&1; done
systemctl --failed --no-legend 2>&1 | head -20
sec foreground
$L luna://com.webos.applicationManager/getForegroundAppInfo '{}'
sec running
$L luna://com.webos.applicationManager/running '{}' | tr '{' '\n' | grep -o '"id":"[^"]*"' | sort
sec launchpoints
LP=$($L luna://com.webos.applicationManager/listLaunchPoints '{}')
echo "count: $(echo "$LP" | grep -o '"launchPointId":"[^"]*"' | wc -l)"
echo "$LP" | grep -o '"launchPointId":"[^"]*"'
sec inputs
$L luna://com.webos.service.eim/getAllInputStatus '{}' | tr '{' '\n' | grep -oE '"(label|connected|appId|activate)":[^,}]*' | paste -d' ' - - - - 2>/dev/null
sec audio
$L luna://com.webos.audio/getVolume '{}'; echo
$L luna://com.webos.audio/status '{}' | cut -c1-600; echo
$L luna://com.webos.service.apiadapter/audio/getSoundOutput '{}'; echo
sec power
$L luna://com.webos.service.tvpower/power/getPowerState '{}'
sec default-apps
$L luna://com.webos.service.applicationmanager/getDefaultApp '{"category":"home"}' 2>/dev/null; echo
sec mounts
grep -E 'palm/applications|elgie' /proc/mounts
sec checkpoint
ls -la /tmp/checkpoint /tmp/checkpoint/com.webos.app.home 2>&1 | head -40
md5sum /tmp/checkpoint/com.webos.app.home/* 2>/dev/null | head -5
ls -la /mnt/lg/cmn_data/checkpoint/com.webos.app.home 2>&1 | head -10
sec preload-conf
cat /var/preferences/webos-preload-manager-conf.json; echo
sec system-app-lists
for f in $(find /var /mnt/lg/cmn_data -xdev \( -name '*blockedSystemAppList*' -o -name '*deletedSystemAppList*' \) 2>/dev/null); do echo "-- $f"; cat "$f"; echo; done
sec pmlog
tail -200 /var/log/messages
sec dmesg
dmesg | tail -100
