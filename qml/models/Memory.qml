// Memory for apps. LG's memory manager (memchute) reports "usable": what apps can have
// right now, counting the page cache it would drop for them; it is what the TV's own
// low-memory levels are measured against. The share shown is usable over the most
// usable this TV has reported, which is the pool with nothing open: the frame keeps that
// peak in the settings store (memoryPeakMb). /proc/meminfo is read as well for totalMb
// and availableMb. The frame's ticker calls read() while the launcher is on screen.
import QtQuick 2.7

Item {
    id: memory
    property var luna
    property int totalMb: 0
    property int availableMb: 0
    property real freeRatio: totalMb > 0 ? availableMb / totalMb : 0
    property int usableMb: 0
    property int storedPeakMb: 0             // the frame binds the saved peak
    property int peakMb: 0                   // the highest usable seen this run
    readonly property int poolMb: Math.max(storedPeakMb, peakMb)
    readonly property real usableRatio: poolMb > 0 ? Math.min(1, usableMb / poolMb) : 0

    function read(cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var t = x.responseText, m;
            if ((m = /MemTotal:\s+(\d+)/.exec(t))) totalMb = Math.round(m[1] / 1024);
            if ((m = /MemAvailable:\s+(\d+)/.exec(t))) availableMb = Math.round(m[1] / 1024);
            if (!luna && cb) cb(availableMb);
        };
        x.open("GET", "file:///proc/meminfo");
        x.send();
        if (!luna) return;
        luna.call("com.webos.memorymanager", "getCurrentMemState", {}, function (ok, r) {
            if (ok && r && r.usable > 0) {
                usableMb = Math.round(r.usable);
                if (usableMb > peakMb) peakMb = usableMb;
            }
            if (cb) cb(usableMb);
        });
    }
}
