// C5 host (webOS 25): Home's manifest is overridden to type "qml", so the TV's
// qml-runner loads this file under Home's app id (docs/contract-c5.md). The runner
// only does two things for us: on a relaunch it replaces the context property
// "params" and shows the window. Everything else (staying hidden on preload, hiding
// on Back or when another app comes forward) is done here.
// Deployed as main.qml next to Shell.qml in the folder mounted over Home's.
import QtQuick 2.7
import Eos.Window 0.1
import WebOS.Global 1.0
import Qt.labs.settings 1.0

WebOSWindow {
    id: root
    appId: "com.webos.app.home"
    windowType: "_WEBOS_WINDOW_TYPE_HOME"
    width: 1920; height: 1080
    visible: false               // a preload launch must stay hidden
    color: "transparent"
    keepAlive: true              // a close from the compositor hides the window instead

    readonly property string dataDir: "file:///var/lib/elgie-man/"
    readonly property string settingsPath: "/var/lib/elgie-man/settings.conf"

    Settings {
        id: settings
        fileName: root.settingsPath
        category: "elgieman"
        property double lastStart: 0
        property string debugLog: ""
    }
    Settings {
        id: hiddenSettings
        fileName: root.settingsPath
        category: "elgieman"
        property string hiddenJson: "[]"
    }
    // Settings changed in the launcher's own menu; they override config.json on this TV.
    Settings {
        id: overrideSettings
        fileName: root.settingsPath
        category: "elgieman"
        property string overridesJson: "{}"
    }

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

    // The system log drops app messages. With "debug" in the config the last lines
    // are also kept in the settings file (debugLog), where they can be read from a
    // shell; without it the file is not written on every show and hide.
    property var logLines: []
    function log(s) {
        console.warn("[elgie] " + s);
        var a = logLines.slice(-59); a.push(new Date().toTimeString().substr(0, 8) + " " + s);
        logLines = a;
        if (home.config && home.config.debug === true) settings.debugLog = a.join(" ~ ");
    }

    function parsed(p) {
        if (typeof p === "string") { try { return JSON.parse(p) || {}; } catch (e) { return {}; } }
        return p || {};
    }
    // The launch message sam gave the runner (its first argument). Its "reason" tells a
    // hidden preload from a launch that is meant to be seen.
    function launchInfo() {
        var a = Qt.application.arguments;
        for (var i = 1; i < a.length; i++) {
            try { var o = JSON.parse(a[i]); if (o && typeof o === "object") return o; } catch (e) {}
        }
        return {};
    }

    // ----- shown by the TV -----
    // The runner replaces "params" and then shows the window. The binding signals on
    // every relaunch, identical parameters included; the window becoming visible
    // counts as well, for a show that comes without a relaunch.
    property bool started: false
    property var launchParams: params
    onLaunchParamsChanged: if (started) { log("params " + JSON.stringify(parsed(launchParams))); show(parsed(launchParams)); }
    onVisibleChanged: {
        log("visible " + visible);
        if (visible && pausing) holdBack.restart();
        else if (visible && !home.shown && !pendingShow) show(parsed(launchParams));
        else if (!visible && home.shown) home.deactivate();
    }
    onWindowStateChanged: log("windowState " + windowState)
    // When the compositor takes Home away (another app comes forward) the window only
    // loses "active"; Qt still counts it as visible and a later showFullScreen() from
    // the runner would do nothing. Hiding it here keeps the two in step.
    onActiveChanged: {
        log("active " + active);
        if (!active && visible && !pendingShow) hide();
    }
    onVisibilityChanged: log("visibility " + visibility)
    Connections {
        target: root
        ignoreUnknownSignals: true
        onWindowCloseRequested: root.log("windowCloseRequested")
        onClosing: root.log("closing")
    }

    // With pauseOnHome the app in front gets the remote's Pause before Home appears.
    // The key goes to whichever window has focus, and the runner shows Home's window
    // as soon as it has passed on the relaunch, so the window is taken back off the
    // screen until the Pause has been sent. Play is never sent: the viewer resumes
    // with the remote.
    readonly property bool pauseApps: home.config.pauseOnHome !== false
    property var pendingShow: null
    property bool pausing: false
    Timer { id: holdBack; interval: 0; onTriggered: if (root.pausing && root.visible) { root.log("held back"); root.visible = false; } }
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
    // The screensaver closes Home, and with nothing else in front the TV then launches
    // Home again as the last app; a window shown then would close the screensaver.
    // Only the Home key brings Home up while the screensaver is in front.
    // The screensaver is not reported as the app in front, only in the full list.
    readonly property string saverId: "com.webos.app.screensaver"
    property bool saverUp: false
    property var saverWatch: null
    function watchSaver() {
        saverWatch = home.bus.call("com.webos.applicationManager", "getForegroundAppInfo", {"subscribe": true, "extraInfo": true}, function (ok, r) {
            var up = false, list = (ok && r.foregroundAppInfo) || [];
            for (var i = 0; i < list.length; i++) if (list[i].appId === root.saverId) up = true;
            if (up !== root.saverUp) { root.saverUp = up; root.log("screensaver " + (up ? "up" : "gone")); }
        });
    }
    function show(p) {
        var id = home.foreground.appId;
        if (pendingShow) return;
        if (saverUp && (p || {}).launchType !== "homeKey") {
            log("left to the screensaver");
            if (root.visible) root.visible = false;
            return;
        }
        pendingShow = p || {};
        if (!pauseApps || home.shown || !id || id === root.appId || home.foreground.isInput(id)) { reveal(); return; }
        pausing = true;
        var twice = pauseTwice.indexOf(id) >= 0;
        showFallback.interval = twice ? 1600 : 700;
        showFallback.restart();
        sendPause(twice);
    }
    function reveal() {
        if (!pendingShow) return;
        var p = pendingShow;
        pausing = false; holdBack.stop(); secondPause.stop(); showAfterPause.stop(); showFallback.stop();
        home.activate(p);
        pendingShow = null;
        if (!root.visible) root.showFullScreen();
        home.forceActiveFocus();
    }
    // Hide and never close: the runner ignores relaunches once the window is closed.
    function hide() {
        pendingShow = null; pausing = false; holdBack.stop(); secondPause.stop(); showAfterPause.stop(); showFallback.stop();
        home.deactivate();
        root.visible = false;
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

    // Back from Home is carried out when the key is released: a release that lands on
    // the app under Home would be taken as a second Back.
    property bool dismissPending: false
    Timer { id: dismissFallback; interval: 1000; onTriggered: root.dismiss() }
    function dismiss() {
        if (!dismissPending) return;
        dismissPending = false; dismissFallback.stop();
        hide();
    }

    // Sized from the window's own properties: its content item has no size until the
    // window has been shown once, and Home is laid out before that.
    FocusScope {
        width: root.width; height: root.height
        focus: true

        Shell {
            id: home
            anchors.fill: parent
            focus: true
            store: store
            dataDir: root.dataDir
            overlayOnly: true
            onRequestHide: { root.dismissPending = true; dismissFallback.restart(); }
        }

        Keys.onReleased: if (event.key === WebOS.Key_webOS_Back && !event.isAutoRepeat) root.dismiss()
        Keys.onPressed: {
            if (home.config.debug === true) root.log("key 0x" + event.key.toString(16));
            if (event.key === WebOS.Key_webOS_Back) { event.accepted = home.back(); }
            else if (event.key === Qt.Key_Super_L) { home.activate({"activateType": "home"}); event.accepted = true; }
        }
    }

    Component.onCompleted: {
        try { store.hidden = JSON.parse(hiddenSettings.hiddenJson); } catch (e) { store.hidden = []; }
        try { store.overrides = JSON.parse(overrideSettings.overridesJson); } catch (e) { store.overrides = {}; }
        // Without this the compositor closes Home on Back and the key never arrives.
        try { root.windowProperties["_WEBOS_ACCESS_POLICY_KEYS_BACK"] = "true"; }
        catch (e) { log("back key policy not set: " + e); }
        var p = parsed(launchParams), reason = launchInfo().reason || "";
        log("loaded reason=" + reason + " params=" + JSON.stringify(p));
        settings.lastStart = Date.now();     // read by the boot hook's failsafe
        loadConfig();
        watchSaver();
        started = true;
        if (reason !== "preload") show(p);
    }
}
