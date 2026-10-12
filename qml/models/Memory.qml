// Free memory from /proc/meminfo. The frame's ticker calls read() while the launcher is on screen.
import QtQuick 2.7

Item {
    id: memory
    property int totalMb: 0
    property int availableMb: 0
    property real freeRatio: totalMb > 0 ? availableMb / totalMb : 0

    function read(cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var t = x.responseText, m;
            if ((m = /MemTotal:\s+(\d+)/.exec(t))) totalMb = Math.round(m[1] / 1024);
            if ((m = /MemAvailable:\s+(\d+)/.exec(t))) availableMb = Math.round(m[1] / 1024);
            if (cb) cb(availableMb);
        };
        x.open("GET", "file:///proc/meminfo");
        x.send();
    }
}
