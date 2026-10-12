// The frame every dashboard runs in, shared by every TV host. Hosts create it, pass
// config and the settings store, call start() on every launch, activate(params) when
// Home is shown and deactivate() when it is hidden, and handle requestHide().
// Every folder of qml/dashboards/ is deployed. The one chosen at deploy time is also
// copied to dashboards/current/ and loaded with this file; another one picked on the
// TV (config key "dashboard") replaces it in start(). A dashboard receives this
// object as its "tv" property (qml/dashboards/README.md).
import QtQuick 2.7
import "models"

FocusScope {
    id: tv
    width: 1920; height: 1080

    property var config: ({})                // config.json with this TV's changed settings on top
    property var store                       // { hidden: [...], set(key, value), reset() }, persisted by the host
    property string dataDir: "file:///var/lib/elgie-man/"
    property bool overlayOnly: false         // set by hosts where Home is always an overlay window
    property bool shown: false
    property var now: new Date()             // refreshed every second while Home is on screen

    signal requestHide()

    property alias bus: luna
    property alias apps: apps
    property alias inputs: inputs
    property alias running: running
    property alias foreground: foreground
    property alias memory: memory
    Luna { id: luna }
    Apps { id: apps; luna: luna; demo: tv.config.demo === true; onHiddenEdited: if (tv.store) tv.store.hidden = list }
    Inputs { id: inputs; luna: luna }
    Running { id: running; luna: luna; apps: apps }
    Foreground { id: foreground; luna: luna }
    Memory { id: memory }

    function launch(id, params) { luna.launch(id, params); }
    function hide() { requestHide(); }
    // A missing on/off key in config counts as on.
    function flag(key) { return config[key] !== false; }

    // A dashboard implements only the functions it needs, and an error in one must
    // not stop the host from showing or hiding the window.
    function ask(name, arg) {
        var d = loader.item;
        if (!d || typeof d[name] !== "function") return undefined;
        try { return d[name](arg); }
        catch (e) { console.warn("[elgie] dashboard " + name + "(): " + e); return undefined; }
    }

    // Called by the host on every launch, including after a snapshot restore, where the
    // process comes back with dead bus connections and timers. Safe to call again.
    function start() {
        tickers.active = false; tickers.active = true;
        if (store && store.hidden) apps.hidden = store.hidden;
        apps.start(); inputs.start(); running.start(); foreground.start();
        started = true;
        ask("start");
        readThemes();
    }

    // ----- themes -----
    // dashboards/list.json is written by deploy.sh: {"default": name, "names": [...]}.
    property bool started: false
    property var themes: []                  // names of the installed dashboards
    property string defaultTheme: ""         // the one deployed as dashboards/current/
    property string loadedTheme: ""          // "" while dashboards/current/ is loaded
    readonly property string theme: loadedTheme || defaultTheme
    readonly property string wantedTheme: config.dashboard || ""
    onWantedThemeChanged: if (started) Qt.callLater(applyTheme)

    function readThemes() {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            try { var l = JSON.parse(x.responseText); themes = l.names || []; defaultTheme = l["default"] || ""; }
            catch (e) { console.warn("[elgie] dashboards/list.json: " + e); }
            applyTheme();
        };
        x.open("GET", Qt.resolvedUrl("dashboards/list.json"));
        x.send();
    }
    function applyTheme() {
        var name = themes.indexOf(wantedTheme) >= 0 ? wantedTheme : defaultTheme;
        if (!name || name === theme) return;
        loadTheme(name === defaultTheme ? "" : name);
    }
    function loadTheme(name) {
        loadedTheme = name;
        loader.setSource(Qt.resolvedUrl("dashboards/" + (name || "current") + "/Dashboard.qml"), {"tv": tv});
    }
    // Opens the list of dashboards over whichever one is showing.
    function pickTheme() {
        var at = themes.indexOf(theme);
        picker.visible = true;
        pickList.currentIndex = at < 0 ? 0 : at;
        pickList.forceActiveFocus();
    }
    function closePicker() { if (picker.visible) { picker.visible = false; loader.forceActiveFocus(); } }
    function chooseTheme(name) {
        closePicker();
        if (store) store.set("dashboard", name);
        else { var c = {}; for (var k in config) c[k] = config[k]; c.dashboard = name; config = c; }
    }
    function themeTitle(name) { return name.charAt(0).toUpperCase() + name.slice(1); }

    // Shown by the Home key, the long press (recent) or the menu key (myapps).
    function activate(params) {
        shown = true;
        now = new Date();
        running.refresh(); memory.read();
        ask("activate", params || {});
    }
    function deactivate() { shown = false; picker.visible = false; ask("deactivate"); }

    // Back goes to the dashboard first; when it has nothing left to close, Home hides.
    function back() {
        if (picker.visible) closePicker();
        else if (ask("back") !== true) requestHide();
        return true;
    }

    // Timers live in a Loader so start() can rebuild them after a snapshot restore.
    Loader {
        id: tickers
        active: false
        sourceComponent: Item {
            Timer { interval: 1000; repeat: true; running: tv.shown; triggeredOnStart: true; onTriggered: tv.now = new Date() }
            Timer { interval: 5000; repeat: true; running: tv.shown; triggeredOnStart: true; onTriggered: memory.read() }
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        // A dashboard loaded after start-up (a theme change) is started and shown here.
        onLoaded: {
            item.focus = true;
            if (tv.started) tv.ask("start");
            if (tv.shown) tv.ask("activate", {});
        }
        // A picked dashboard that does not load gives way to the deployed one.
        onStatusChanged: if (status === Loader.Error && tv.loadedTheme) {
            console.warn("[elgie] dashboard " + tv.loadedTheme + " did not load; back to " + tv.defaultTheme);
            Qt.callLater(function () { tv.loadTheme(""); });
        }
    }
    // A dashboard that does not load leaves Home usable: Back still hides it.
    Rectangle {
        anchors.fill: parent
        visible: loader.status === Loader.Error
        color: "#0f172a"
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "white"; font.pixelSize: 36
            text: "The dashboard did not load.\nPress Back to close Home."
        }
    }

    // The list of dashboards, opened with pickTheme().
    FocusScope {
        id: picker
        anchors.fill: parent
        visible: false
        Rectangle { anchors.fill: parent; color: "black"; opacity: 0.6 }
        Rectangle {
            anchors.centerIn: parent
            width: 620; height: 170 + Math.min(tv.themes.length, 8) * 76
            color: "#0f172a"; border.width: 2; border.color: "#7dd3fc"
            Text { x: 40; y: 28; color: "white"; font.pixelSize: 36; text: "Theme" }
            Text { x: 40; y: parent.height - 50; color: "white"; opacity: 0.6; font.pixelSize: 20; text: "OK: use this theme    Back: close" }
            ListView {
                id: pickList
                x: 40; y: 92; width: parent.width - 80; height: Math.min(tv.themes.length, 8) * 76
                spacing: 8
                clip: true
                focus: true
                model: tv.themes
                highlightMoveDuration: 0
                delegate: Rectangle {
                    width: pickList.width; height: 68
                    color: ListView.isCurrentItem ? "#7dd3fc" : "#22ffffff"
                    Text {
                        x: 24; anchors.verticalCenter: parent.verticalCenter
                        color: parent.ListView.isCurrentItem ? "#0b1220" : "white"; font.pixelSize: 30
                        text: tv.themeTitle(modelData)
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                        visible: modelData === tv.theme
                        color: parent.ListView.isCurrentItem ? "#0b1220" : "white"; font.pixelSize: 22
                        text: "In use"
                    }
                }
                Keys.onReturnPressed: tv.chooseTheme(tv.themes[currentIndex])
                Keys.onEnterPressed: tv.chooseTheme(tv.themes[currentIndex])
            }
        }
    }

    // Loaded here, with the rest of the file, so it is part of a snapshot of the process.
    Component.onCompleted: loader.setSource(Qt.resolvedUrl("dashboards/current/Dashboard.qml"), {"tv": tv})
}
