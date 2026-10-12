// CX host (webOS 5): LG's Home binary loads this file from Home's qml/ folder.
// It implements the root-object contract the binary expects (docs/contract-cx.md)
// and drives the frame (Shell.qml) from the application manager's lifecycle events.
// Deployed as qml/main.qml next to Shell.qml.
import QtQuick 2.7
import WebOS.Global 1.0
import Qt.labs.settings 1.0

FocusScope {
    id: root
    width: 1920; height: 1080
    visible: true
    focus: true

    // Set by the host binary.
    property var videoSize
    property string appId: ""
    property bool cursorVisible: false
    property bool active: false

    // Signals the host binary connects to (docs/contract-cx.md). The binary fixes the
    // names and how many arguments each one carries; the rest is ours. In A to Z order.
    signal activateWindow(var how)
    signal appClosing()
    signal changeCacheDirectory(var dir)
    signal clearCache()
    signal createCache()
    signal enableLog()
    signal hideWindow()
    signal invokeExit()
    signal printLog(var text)
    signal printLS(var text)
    signal saveCache(var what, var folder, var file)
    signal setDebugLevel(string level)
    signal setWindowProperty(var name, var to)
    signal showWindow()

    readonly property string dataDir: "file:///var/lib/elgie-man/"
    property bool preloaded: false
    property var launchParams: ({})

    Settings {
        id: settings
        category: "elgieman"
        property double lastStart: 0
        property string debugLog: ""
    }
    // Kept apart from the settings above: a Settings object rewrites all its properties
    // when one changes, and after a snapshot restore this one still holds the list from
    // when the snapshot was taken. It is written only when the list is edited.
    Settings {
        id: hiddenSettings
        category: "elgieman"
        property string hiddenJson: "[]"
    }
    // Settings changed in the launcher's own menu; they override config.json on this TV.
    Settings {
        id: overrideSettings
        category: "elgieman"
        property string overridesJson: "{}"
    }
    readonly property string settingsFile: "file:///home/root/.config/Unknown%20Organization/com.webos.app.home.conf"

    QtObject {
        id: store
        property var hidden: []
        onHiddenChanged: hiddenSettings.hiddenJson = JSON.stringify(hidden)
        property var overrides: ({})
        function set(key, value) {
            var o = {};
            for (var k in overrides) o[k] = overrides[k];
            o[key] = value;
            overrides = o;
            overrideSettings.overridesJson = JSON.stringify(o);
            root.applyConfig();
        }
        function reset() { overrides = {}; overrideSettings.overridesJson = "{}"; root.applyConfig(); }
    }
    property var fileConfig: ({})
    function applyConfig() {
        var c = {}, k;
        for (k in fileConfig) c[k] = fileConfig[k];
        for (k in store.overrides) c[k] = store.overrides[k];
        home.config = c;
    }

    Shell {
        id: home
        anchors.fill: parent
        focus: true
        store: store
        dataDir: root.dataDir
        onRequestHide: { root.dismissPending = true; dismissFallback.restart(); }
    }

    // The system log drops app messages, so the last few lines are also kept in the
    // settings file (debugLog) where they can be read from a shell.
    property var logLines: []
    function log(s) {
        console.warn("[elgie] " + s);
        var a = logLines.slice(-11); a.push(new Date().toTimeString().substr(0, 8) + " " + s);
        logLines = a; settings.debugLog = a.join(" ~ ");
    }

    // Home is an overlay by default, so the app under it stays in front and keeps
    // playing. As a card window Home takes the foreground itself and the TV puts
    // that app in the background, as it does for any app switch.
    readonly property bool cover: home.config.pauseUnderHome !== false
    readonly property string selfId: appId || "com.webos.app.home"
    property bool fronted: false         // Home has been the foreground app since it was shown
    // With pauseOnHome the app in front gets the remote's Pause before Home appears.
    // The key goes to whichever window has focus, so Home is shown only after it is
    // sent. Play is never sent: the viewer resumes with the remote.
    readonly property bool pauseApps: home.config.pauseOnHome !== false
    property var pendingShow: null
    Timer { id: showAfterPause; interval: 150; onTriggered: root.reveal() }
    Timer { id: showFallback; interval: 700; onTriggered: root.reveal() }
    // Some players take the first Pause only to bring up their controls and pause on
    // the second (config pauseTwiceApps).
    readonly property var pauseTwice: home.config.pauseTwiceApps || ["com.cbs-all-access.webapp.prod"]
    Timer { id: secondPause; interval: 400; onTriggered: root.sendPause(false) }
    function sendPause(again) {
        home.bus.call("com.webos.service.networkinput", "controls/pause", {}, function (ok, r) {
            if (!ok) log("pause failed: " + JSON.stringify(r));
            if (again && root.pendingShow) secondPause.restart(); else showAfterPause.restart();
        });
    }
    function show(params) {
        var id = home.foreground.appId;
        if (pendingShow) return;
        pendingShow = params || {};
        if (!pauseApps || home.shown || !id || id === selfId || home.foreground.isInput(id)) { reveal(); return; }
        var twice = pauseTwice.indexOf(id) >= 0;
        showFallback.interval = twice ? 1600 : 700;
        showFallback.restart();
        sendPause(twice);
    }
    function reveal() {
        if (!pendingShow) return;
        var params = pendingShow;
        pendingShow = null; secondPause.stop(); showAfterPause.stop(); showFallback.stop();
        fronted = home.foreground.appId === selfId;
        home.activate(params);
        setWindowProperty("_WEBOS_WINDOW_TYPE", cover ? "_WEBOS_WINDOW_TYPE_CARD" : "_WEBOS_WINDOW_TYPE_HOME");
        showWindow();
        home.forceActiveFocus();
    }
    function hide() {
        home.deactivate();
        hideWindow();
    }

    // A card window gets no "pause" when another app takes over, so Home hides itself
    // when it loses the foreground.
    Connections {
        target: home.foreground
        onAppIdChanged: {
            var id = home.foreground.appId;
            if (id === root.selfId) root.fronted = true;
            else if (id && root.cover && root.fronted && home.shown) { root.log("covered by " + id); root.hide(); }
        }
    }

    // Back from Home: bring back the app Home was covering. Home hides when that app
    // is in front.
    // Carried out when the Back key is released: a release that lands on the app
    // brought to the front makes the TV launch Home again.
    property bool dismissPending: false
    Timer { id: dismissFallback; interval: 1000; onTriggered: root.dismiss() }
    function dismiss() {
        if (!dismissPending) return;
        dismissPending = false; dismissFallback.stop();
        var fg = home.foreground, id = fg.lastApp;
        if (!cover || !id || !fronted) { hide(); return; }
        if (fg.isInput(id)) { goBackTo(id); return; }
        // An app closed while Home was up is not started again; the last input is shown.
        home.bus.call("com.webos.applicationManager", "running", {}, function (ok, r) {
            var up = false, list = (ok && r.running) || [];
            for (var i = 0; i < list.length; i++) if (list[i].id === id) up = true;
            goBackTo(up ? id : fg.lastInput);
        });
    }
    function goBackTo(id) {
        log("back to " + (id || "(nothing)"));
        if (id) home.bus.launch(id, {}); else hide();
    }

    // Reads the hidden list and the changed settings from the settings file itself: a
    // process restored from a snapshot only has what it was snapshotted with.
    function stored(text, key) {
        var m = new RegExp("^" + key + "=(.*)$", "m").exec(text);
        if (!m) { log(key + " not read (" + text.length + " bytes)"); return undefined; }
        try { return JSON.parse(m[1].replace(/^"(.*)"$/, "$1").replace(/\\(["\\])/g, "$1")); }
        catch (e) { log(key + " unreadable: " + e); return undefined; }
    }
    function loadStored(done) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var text = x.responseText || "";
            var list = stored(text, "hiddenJson");
            if (list && JSON.stringify(list) !== JSON.stringify(store.hidden)) store.hidden = list;
            if (/^overridesJson=/m.test(text)) {
                var o = stored(text, "overridesJson");
                if (o) { store.overrides = o; overrideSettings.overridesJson = JSON.stringify(o); }
            }
            done();
        };
        x.open("GET", settingsFile);
        x.send();
    }

    function loadConfig() {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var c = {};
            try { c = JSON.parse(x.responseText); } catch (e) { log("config.json unreadable: " + e); }
            fileConfig = c;
            applyConfig();
            home.start();
        };
        x.open("GET", dataDir + "config.json");
        x.send();
    }

    // ----- host binary contract -----
    function appLaunched(params, restored) {
        var p = {};
        try { p = JSON.parse(params); } catch (e) { log("bad launch params"); }
        preloaded = p.hasOwnProperty("preload") || p.reason === "preload"
                    || (p.parameters && p.parameters.snapshot === true);
        launchParams = p.parameters || {};
        log("launched restored=" + restored + " preload=" + preloaded);
        settings.lastStart = Date.now();     // read by the boot hook's failsafe
        loadStored(loadConfig);              // (re)loads data; also runs after a snapshot restore
        subscribeLifecycle();
    }
    function windowIsVisible() { log("windowIsVisible"); }
    function windowIsInvisible() { log("windowIsInvisible"); }
    function focusIn() { active = true; }
    function focusOut() { active = false; }
    function remoteCursorOn() { cursorVisible = true; }
    function remoteCursorOff() { cursorVisible = false; }
    function cacheDirectoryChanged(url) { }
    function keyPressEvent(keyCode) { }

    // The registerApp subscription is created here, never at load time: the binary may
    // snapshot the process right after loading, and a bus connection inside a snapshot
    // is dead when the snapshot is restored.
    property var lifecycle: null
    function subscribeLifecycle() {
        if (lifecycle) home.bus.cancel(lifecycle);
        lifecycle = home.bus.call("com.webos.applicationManager", "registerApp",
                                  {"appId": appId || "com.webos.app.home", "subscribe": true}, function (ok, response) {
            if (!ok) { log("registerApp failed: " + JSON.stringify(response)); return; }
            var ev = response.event;
            log("event " + ev + " " + JSON.stringify(response.parameters || {}));
            if (ev === "registered") { if (!root.preloaded) root.show(root.launchParams); }
            else if (ev === "relaunch") { if (!response.hasOwnProperty("preload")) root.show(response.parameters || {}); }
            else if (ev === "pause") root.hide();
            else if (ev === "close") root.invokeExit();
        });
    }

    Keys.onReleased: if (event.key === WebOS.Key_webOS_Back && !event.isAutoRepeat) dismiss()
    Keys.onPressed: {
        if (event.key === WebOS.Key_webOS_Back) { event.accepted = home.back(); }
        else if (event.key === Qt.Key_Super_L) { home.activate({"activateType": "home"}); event.accepted = true; }
    }

    Component.onCompleted: {
        // Nothing that talks to the bus or the network here: the binary may snapshot the
        // process right after loading, and appLaunched() runs on every start and restore.
        try { store.hidden = JSON.parse(hiddenSettings.hiddenJson); } catch (e) { store.hidden = []; }
        try { store.overrides = JSON.parse(overrideSettings.overridesJson); } catch (e) { store.overrides = {}; }
    }
}
