// Apps the user has running, for the "recent" view. System apps are left out.
import QtQuick 2.7

Item {
    id: running
    property var luna
    property var apps                  // Apps model, for titles and icons
    property var items: []
    property var ignore: ["com.webos.app.home", "airplay", "com.webos.app.livetv",
        "com.webos.app.inputcommon", "com.webos.app.voice", "com.webos.app.fullhome", "com.webos.app.livedmost"]
    property var sub: null

    function lookup(id) {
        var a = apps ? apps.all : [];
        for (var i = 0; i < a.length; i++) if (a[i].id === id) return a[i];
        return null;
    }

    // The subscription does not report closed apps on every TV, so hosts also
    // call refresh() whenever Home is shown.
    function start() {
        if (sub) { luna.cancel(sub); sub = null; }    // restartable: a restored snapshot has dead subscriptions
        sub = luna.call("com.webos.applicationManager", "running", {"subscribe": true}, update);
    }
    function refresh() { luna.call("com.webos.applicationManager", "running", {}, update); }

    function update(ok, r) {
        if (!ok || !r.running) return;
        var a = [];
        for (var i = 0; i < r.running.length; i++) {
            var id = r.running[i].id;
            if (ignore.indexOf(id) >= 0 || /^com\.webos\.app\.(hdmi|externalinput)/.test(id)) continue;
            var lp = lookup(id);
            a.push({id: id, title: lp ? lp.title : id, icon: lp ? lp.icon : "", color: lp ? lp.color : ""});
        }
        items = a;
    }
}
