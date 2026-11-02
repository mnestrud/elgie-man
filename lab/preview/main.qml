// Runs the frame and the chosen dashboard on a PC under qmltestrunner, plays the steps
// in scenario.json and saves screenshots (lab/preview.sh). The stage dir has this file,
// Shell.qml and its folders, data/ (config.json and the background), icons/ and the
// mock Luna.qml.
import QtQuick 2.7
import QtTest 1.1

Item {
    id: root
    width: 1920; height: 1080

    readonly property url here: Qt.resolvedUrl(".")
    property var fileConfig: ({})
    property var scenario
    property var config

    Rectangle { anchors.fill: parent; color: "black" }
    Shell {
        id: home
        anchors.fill: parent
        dataDir: root.here + "data/"
        store: QtObject {
            property var hidden: []
            property var overrides: ({})
            function set(key, value) { var o = {}; for (var k in overrides) o[k] = overrides[k]; o[key] = value; overrides = o; root.applyConfig(); }
            function reset() { overrides = {}; root.applyConfig(); }
        }
        onRequestHide: console.log("[preview] hide requested")
    }
    function applyConfig() {
        var c = {}, k;
        for (k in fileConfig) c[k] = fileConfig[k];
        for (k in home.store.overrides) c[k] = home.store.overrides[k];
        home.config = c;
    }
    function read(name, cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            try { cb(JSON.parse(x.responseText)); } catch (e) { console.log("[preview] " + name + ": " + e); cb({}); }
        };
        x.open("GET", root.here + name);
        x.send();
    }

    TestCase {
        id: test
        name: "preview"
        when: windowShown
        readonly property var keyNames: ({"Left": Qt.Key_Left, "Right": Qt.Key_Right, "Up": Qt.Key_Up, "Down": Qt.Key_Down,
                                          "OK": Qt.Key_Return})

        function snapshot(file) {
            var done = false;
            home.grabToImage(function (r) {
                console.log("[preview] " + (r.saveToFile(file) ? "saved " : "could not save ") + file);
                done = true;
            });
            tryVerify(function () { return done; }, 10000);
        }

        function test_scenario() {
            root.read("data/config.json", function (c) { root.config = c; });
            root.read("scenario.json", function (s) { root.scenario = s; });
            tryVerify(function () { return root.config !== undefined && root.scenario !== undefined; }, 5000);
            root.fileConfig = root.config;
            root.applyConfig();
            home.bus.iconDir = root.here + "icons/";
            home.start();
            home.activate({activateType: root.scenario.activate || "home"});
            wait(1500);
            var steps = root.scenario.steps || [];
            for (var i = 0; i < steps.length; i++) {
                var s = steps[i];
                if (s.key === "Back") home.back();
                else if (s.key) keyClick(keyNames[s.key]);
                if (s.hold) { keyPress(keyNames[s.hold]); wait(s.ms || 900); keyRelease(keyNames[s.hold]); }
                if (s.ask) home.ask(s.ask, s.arg);
                if (s.hide) home.deactivate();
                if (s.show) home.activate({activateType: s.show});
                wait(s.wait || 200);
                if (s.shot) snapshot(s.shot);
            }
        }
    }
}
