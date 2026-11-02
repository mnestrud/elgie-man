// A stand-in for qml/Luna.qml, for running the launcher on a PC with qmlscene
// (lab/preview.sh). Answers the calls the models make with made-up apps and inputs.
import QtQuick 2.7

Item {
    id: luna
    property string appId: "com.webos.app.home"
    property url iconDir                 // set by the harness: where the placeholder icons are

    property var apps: [
        {id: "app.streamly", title: "Streamly", bgColor: "#e50914"},
        {id: "app.tubeway", title: "Tubeway", bgColor: "#282828"},
        {id: "app.primetime", title: "Primetime", bgColor: "#00a8e1"},
        {id: "app.orchard", title: "Orchard TV", bgColor: "#1c1c1e"},
        {id: "app.mouseplus", title: "Mouse+", bgColor: "#0a1a4a"},
        {id: "app.peafowl", title: "Peafowl", bgColor: "#000000"},
        {id: "app.topnotch", title: "Topnotch", bgColor: "#0a0a2a"},
        {id: "app.cloudgames", title: "Cloud Games", bgColor: "#1f1f1f"},
        {id: "app.radiola", title: "Radiola", bgColor: "#1db954"},
        {id: "app.pictures", title: "Pictures", bgColor: "#f59e0b"},
        {id: "app.browser", title: "Web Browser", bgColor: "#2563eb"},
        {id: "app.livetv", title: "Live TV", bgColor: "#7c3aed"},
        {id: "app.weatherly", title: "Weatherly", bgColor: "#0ea5e9"},
        {id: "app.homebrew", title: "Homebrew Channel", bgColor: "#111827"},
        {id: "app.media", title: "Media Player", bgColor: "#334155"},
        {id: "app.sports", title: "Sports Zone", bgColor: "#dc2626"},
        {id: "app.kids", title: "Kids Corner", bgColor: "#f472b6"},
        {id: "app.music", title: "Music Hall", bgColor: "#0f766e"},
        {id: "app.news", title: "Daily News", bgColor: "#1e3a8a"},
        {id: "app.fitness", title: "Fit & Flex", bgColor: "#65a30d"},
        {id: "app.podcasts", title: "Podcasts", bgColor: "#9333ea"},
        {id: "app.screensaver", title: "Screensaver", bgColor: "#374151"}
    ]
    function launchPoints() {
        var a = [];
        for (var i = 0; i < apps.length; i++) {
            var p = apps[i];
            a.push({launchPointId: p.id + "_default", id: p.id, title: p.title, bgColor: p.bgColor,
                    largeIcon: String(iconDir) + p.id + ".png", params: {}});
        }
        return a;
    }
    function indexOf(id) { for (var i = 0; i < apps.length; i++) if (apps[i].id === id) return i; return -1; }

    function call(service, method, params, cb) {
        var r = {returnValue: true};
        if (method === "listLaunchPoints") r = {launchPoints: launchPoints()};
        else if (method === "getAllInputStatus")
            r = {devices: [{appId: "com.webos.app.hdmi1", label: "HDMI 1", connected: true},
                           {appId: "com.webos.app.hdmi2", label: "HDMI 2", connected: false},
                           {appId: "com.webos.app.hdmi3", label: "HDMI 3", connected: true},
                           {appId: "com.webos.app.hdmi4", label: "HDMI 4", connected: false}]};
        else if (method === "running") r = {running: [{id: "app.streamly"}, {id: "app.tubeway"}]};
        else if (method === "getForegroundAppInfo") r = {appId: ""};
        else if (method === "moveLaunchPoint") {
            var from = indexOf(String(params.launchPointId).replace(/_default$/, ""));
            if (from >= 0) { var it = apps.splice(from, 1)[0]; apps.splice(params.position, 0, it); }
        }
        else if (method === "getAppInfo") r = {appInfo: {}};
        else if (method === "getCurrentMemState") r = {usable: 1150, currentLevel: "normal", prevLevel: "normal"};
        if (cb) Qt.callLater(function () { cb(true, r); });
        return {cancel: function () {}, destroy: function () {}};
    }
    function cancel(handle) {}
    function launch(id, params) { console.log("[preview] launch " + id); }
}
