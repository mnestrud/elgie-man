#!/bin/sh
# Runs on the TV (webOS 25), from the unpacked package in /tmp/elgie-new. Called by
# deploy.sh. Puts the launcher in /var/lib/elgie-man, installs the boot hook and
# applies it now.
D=/var/lib/elgie-man; O=$D/c5home; N=/tmp/elgie-new
mkdir -p $O
[ -f $D/config.json ] && [ ! -f $N/config.force ] && rm $N/config.json
for f in config.json bg.jpg bg-blur.jpg; do [ -f $N/$f ] && mv $N/$f $D/$f; done
chmod 600 $D/config.json
rm -f $D/force; [ -f $N/force ] && mv $N/force $D/force
# The folder may be mounted over Home's, so its files are replaced in place.
rm -rf $O/main.qml $O/HomeApp.qml $O/Shell.qml $O/Luna.qml $O/models $O/ui $O/dashboards
cp -r $N/qml/* $O/
cp $N/tv-uninstall-c5.sh $D/uninstall.sh
cp $N/05elgieman /var/lib/webosbrew/init.d/05elgieman; chmod 755 /var/lib/webosbrew/init.d/05elgieman
echo "installed: $(ls $O | tr '\n' ' ')"

# The health baseline is recorded once, before the launcher has ever run.
if [ ! -f $D/health.env ]; then
  echo INPUTS=$(luna-send -n 1 -w 5000 luna://com.webos.service.eim/getAllInputStatus '{}' | grep -o '"appId"' | wc -l) > $D/health.env
  echo SOUND_OUTPUT=$(luna-send -n 1 -w 5000 luna://com.webos.service.apiadapter/audio/getSoundOutput '{}' | grep -o '"soundOutput":"[^"]*"' | cut -d'"' -f4) >> $D/health.env
  cat $D/health.env
fi

rm -f $D/disabled; rm -rf $N
/var/lib/webosbrew/init.d/05elgieman; sleep 1; tail -3 /tmp/elgie-man.log
