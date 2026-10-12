// External inputs from the input manager (label, connected, app id).
import QtQuick 2.7

Item {
    id: inputs
    property var luna
    property var items: []
    property var sub: null

    function start() {
        if (sub) { luna.cancel(sub); sub = null; }    // restartable: a restored snapshot has dead subscriptions
        sub = luna.call("com.webos.service.eim", "getAllInputStatus", {"subscribe": true}, function (ok, r) {
            if (!ok || !r.devices) return;
            var a = [];
            for (var i = 0; i < r.devices.length; i++) {
                var d = r.devices[i];
                if (!d.appId) continue;
                a.push({label: d.label || d.appId, id: d.appId, connected: !!d.connected, active: !!d.activate});
            }
            items = a;
        });
    }
}
