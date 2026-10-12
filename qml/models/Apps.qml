// App tiles from the system's launch points, in the system's order. Order changes go
// back to the system (moveLaunchPoint); hiding is local to the launcher.
import QtQuick 2.7

Item {
    id: apps
    property var luna
    property var hidden: []            // launchPointIds hidden by the user
    property var all: []               // every launch point, system order
    property var shown: []             // all minus hidden
    property bool ready: false
    // Stand-in names and no icons, for screenshots that show no one else's artwork.
    property bool demo: false
    onDemoChanged: if (ready) refresh()
    readonly property var demoNames: ["Movies", "Series", "Music", "Sport", "News", "Kids", "Photos", "Weather",
        "Games", "Radio", "Cooking", "Travel", "Fitness", "Nature", "Comedy", "Classics", "Podcasts", "Live TV"]
    signal hiddenEdited(var list)

    property var sub: null

    function iconUrl(lp) {
        var p = lp.largeIcon || lp.mediumIcon || lp.icon || "";
        if (p.indexOf("/") === 0) return "file://" + p;
        return p;
    }

    function rebuild(list) {
        var a = [];
        for (var i = 0; i < list.length; i++) {
            var lp = list[i];
            a.push({
                launchPointId: lp.launchPointId,
                id: lp.id,
                title: demo ? demoNames[i % demoNames.length] : lp.title || lp.id,
                icon: demo ? "" : iconUrl(lp),
                color: demo ? "" : lp.bgColor || lp.iconColor || "",
                params: lp.params || {},
                removable: !!lp.removable,
                unmovable: !!lp.unmovable
            });
        }
        all = a;
        refilter();
        ready = true;
    }

    function refilter() {
        var s = [];
        for (var i = 0; i < all.length; i++)
            if (hidden.indexOf(all[i].launchPointId) < 0) s.push(all[i]);
        shown = s;
    }

    function start() {
        if (sub) { luna.cancel(sub); sub = null; }    // restartable: a restored snapshot has dead subscriptions
        sub = luna.call("com.webos.applicationManager", "listLaunchPoints", {"subscribe": true}, function (ok, r) {
            if (!ok) { console.warn("[elgie] listLaunchPoints: " + JSON.stringify(r)); return; }
            if (r.launchPoints) rebuild(r.launchPoints);
            else if (r.launchPoint && r.change) refresh();   // incremental update: reload whole list
        });
    }

    function refresh(done) {
        luna.call("com.webos.applicationManager", "listLaunchPoints", {}, function (ok, r) {
            if (ok && r.launchPoints) rebuild(r.launchPoints);
            if (done) done();
        });
    }

    function indexOfLp(lpId) {
        for (var i = 0; i < all.length; i++) if (all[i].launchPointId === lpId) return i;
        return -1;
    }

    // Moves a tile one step left (-1) or right (+1) past its neighbour in the list
    // on screen (all tiles while editing, shown tiles otherwise).
    function step(lpId, dir, onScreen, done) {
        var vis = onScreen, vi = -1;
        for (var i = 0; i < vis.length; i++) if (vis[i].launchPointId === lpId) vi = i;
        var ti = vi + dir;
        if (vi < 0 || ti < 0 || ti >= vis.length) { if (done) done(false); return; }
        var target = indexOfLp(vis[ti].launchPointId);
        luna.call("com.webos.applicationManager", "moveLaunchPoint",
                  {"launchPointId": lpId, "position": target}, function (ok, r) {
            if (!ok) { console.warn("[elgie] moveLaunchPoint: " + JSON.stringify(r)); if (done) done(false); return; }
            refresh(function () { if (done) done(true); });
        });
    }

    function isHidden(lpId) { return hidden.indexOf(lpId) >= 0; }

    function toggleHidden(lpId) {
        var h = hidden.slice(), i = h.indexOf(lpId);
        if (i >= 0) h.splice(i, 1); else h.push(lpId);
        hidden = h;
        refilter();
        hiddenEdited(h);
    }
}
