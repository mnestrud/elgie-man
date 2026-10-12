// The glass dashboard: rows of tiles for apps, running apps, inputs and TV actions,
// with edit mode and a settings panel. What the frame gives a dashboard and calls on
// it is described in qml/dashboards/README.md.
import QtQuick 2.7
import "../../ui"

FocusScope {
    id: home

    property var tv                          // the frame (Shell.qml)
    readonly property var config: tv.config
    readonly property var store: tv.store    // { hidden: [...], set(key, value), reset() }
    readonly property var luna: tv.bus
    readonly property var apps: tv.apps
    readonly property var inputs: tv.inputs
    readonly property var running: tv.running
    readonly property var memory: tv.memory
    readonly property bool shown: tv.shown
    readonly property bool overlayOnly: tv.overlayOnly
    // Colours. A colour variant (qml/dashboards/nord/, gruvbox/) is this dashboard with
    // a palette: {top, bottom, panel, ink, glass, accents: [{name, color}]}. With a palette the
    // background is its two colours instead of the picture.
    property var palette: ({})
    readonly property bool plain: !!palette.top
    readonly property color ink: palette.ink || "white"
    readonly property color panel: palette.panel || "#0b1220"
    readonly property color glass: palette.glass || "white"
    readonly property var accents: palette.accents || [
        {name: "Sky", color: "#7dd3fc"}, {name: "Mint", color: "#6ee7b7"}, {name: "Amber", color: "#fcd34d"},
        {name: "Rose", color: "#fda4af"}, {name: "Violet", color: "#c4b5fd"}, {name: "White", color: "#f8fafc"}
    ]
    property url backgroundSource: plain ? "" : tv.dataDir + "bg.jpg"
    property url blurSource: plain ? "" : tv.dataDir + "bg-blur.jpg"
    // A palette keeps to its own accents: a colour set for another look gives way to its first.
    function chosenAccent() {
        var c = String(config.accent || "").toLowerCase();
        if (!palette.accents) return c || accents[0].color;
        for (var i = 0; i < accents.length; i++) if (accents[i].color === c) return c;
        return accents[0].color;
    }
    property color baseAccent: chosenAccent()
    property color accent: baseAccent
    property bool editMode: false
    property string grabbed: ""              // launchPointId being moved in edit mode
    property var sysIcons: ({})              // app id -> icon url for the TV row

    // Called by the frame on every launch, including after a snapshot restore.
    function start() { loadIcon(settingsId()); }

    function settingsId() { return config.settingsId || "com.palm.app.settings"; }

    function loadIcon(id) {
        luna.call("com.webos.applicationManager", "getAppInfo", {"id": id}, function (ok, r) {
            if (!ok || !r.appInfo) return;
            var a = r.appInfo, f = a.largeIcon || a.icon || "";
            if (!f) return;
            if (f.indexOf("/") !== 0) f = (a.folderPath || "") + "/" + f;
            var m = {};
            for (var k in sysIcons) m[k] = sysIcons[k];
            m[id] = "file://" + f;
            sysIcons = m;
        });
    }

    // Shown by the Home key, the long press (recent) or the menu key (myapps).
    function activate(params) {
        var p = params || {};
        var type = p.activateType || "home";
        sheet.visible = false; settingsPanel.shown = false;
        if (type === "myapps" || type === "editMode") { setEdit(true); focusRow(appsRow, 0); }
        else {
            setEdit(false);
            wantRecent = type === "recent" && !running.items.length;
            if (type === "recent" && running.items.length) focusRow(runningRow, 0);
            else focusRow(appsRow, 0);
            if (type !== "home" && type !== "powerOn") console.warn("[elgie] activateType " + type + " shown as home");
        }
    }

    function deactivate() { grabbed = ""; sheet.visible = false; settingsPanel.shown = false; }

    function focusRow(r, index) {
        if (!r.visible) r = appsRow;
        r.forceActiveFocus();
        if (index !== undefined) r.setIndex(index);
    }

    // Keeps the focused row on screen.
    function reveal(r) {
        var top = r.y, bottom = r.y + r.height, view = scroller.height;
        if (view <= 0) return;
        if (top < scroller.contentY) scroller.contentY = top;
        else if (bottom > scroller.contentY + view) scroller.contentY = Math.max(0, bottom - view);
    }
    function resampleRows() {
        var all = [appsRow, runningRow, inputsRow, systemRow];
        for (var i = 0; i < all.length; i++) all[i].resampleAll();
    }

    // "recent" before the running list has arrived: focus it when it does.
    property bool wantRecent: false
    Connections {
        target: running
        onItemsChanged: if (home.wantRecent && home.shown && running.items.length) { home.wantRecent = false; home.focusRow(runningRow, 0); }
    }

    function setEdit(on) { editMode = on; grabbed = ""; if (on) toast.show("Edit: OK on an app or input to move or hide it, Back when done"); }

    // ----- rows -----
    function appEntries() {
        var src = editMode ? apps.all : apps.shown, a = [];
        for (var i = 0; i < src.length; i++)
            a.push({title: src[i].title, icon: src[i].icon, color: src[i].color, dim: editMode && apps.isHidden(src[i].launchPointId),
                    lp: src[i]});
        return a;
    }
    function inputEntries() {
        var a = [];
        for (var i = 0; i < inputs.items.length; i++) {
            var d = inputs.items[i], hidden = apps.isHidden(d.id);
            if (hidden && !editMode) continue;
            // While editing, dim marks a hidden input; otherwise one with nothing connected.
            a.push({title: d.label, glyph: d.label.replace(/^HDMI\s*/, "HDMI\n"), dim: editMode ? hidden : !d.connected,
                    id: d.id, input: true});
        }
        return a;
    }
    function systemEntries() {
        var si = settingsId();
        return [
            {title: "Settings", glyph: "≡", icon: config.demo === true ? "" : (sysIcons[si] || ""), id: si},
            {title: "Free up memory", glyph: "♻", action: "freeMemory"},
            {title: editMode ? "Done editing" : "Edit apps & inputs", glyph: "✎", action: "edit"},
            {title: "Launcher settings", glyph: "≡", action: "settings"}
        ];
    }

    function openApp(entry) {
        if (!entry) return;
        if (editMode && entry.lp) { editMenu(entry.lp); return; }
        if (editMode && entry.input) { inputMenu(entry); return; }
        if (entry.action === "freeMemory") { freeMemory(); return; }
        if (entry.action === "edit") { setEdit(!editMode); focusRow(appsRow, 0); return; }
        if (entry.action === "settings") { setEdit(false); settingsPanel.open(systemRow); return; }
        var id = entry.lp ? entry.lp.id : entry.id;
        var params = entry.lp ? entry.lp.params : {};
        if (id) luna.launch(id, params);
    }

    function editMenu(lp) {
        var hidden = apps.isHidden(lp.launchPointId);
        sheet.open(lp.title, [
            {label: "Move", run: function () { grabbed = lp.launchPointId; }},
            {label: hidden ? "Show" : "Hide", run: function () { apps.toggleHidden(lp.launchPointId); }},
            {label: "Cancel", run: function () {}}
        ], appsRow);
    }

    // Hidden inputs share the apps' hidden list, keyed by the input's app id.
    function inputMenu(entry) {
        sheet.open(entry.title, [
            {label: apps.isHidden(entry.id) ? "Show" : "Hide", run: function () { apps.toggleHidden(entry.id); }},
            {label: "Cancel", run: function () {}}
        ], inputsRow);
    }

    function freeMemory() {
        var list = config.freeMemoryApps || [];
        var before = memory.availableMb, left = list.length, closed = 0;
        if (!left) { toast.show("No apps configured to close"); return; }
        for (var i = 0; i < list.length; i++) {
            (function (id) {
                var wasRunning = false;
                for (var j = 0; j < running.items.length; j++) if (running.items[j].id === id) wasRunning = true;
                luna.call("com.webos.applicationManager", "closeByAppId", {"id": id}, function (ok) {
                    if (ok && wasRunning) closed++;
                    if (--left === 0) settle.start();
                });
            })(list[i]);
        }
        settle.before = before;
        settle.closedCount = function () { return closed; };
    }
    Timer {
        id: settle
        property int before: 0
        property var closedCount
        interval: 2500
        onTriggered: memory.read(function (now) {
            var n = closedCount ? closedCount() : 0;
            var gain = now - before;
            toast.show((n ? "Closed " + n + " app" + (n === 1 ? "" : "s") : "Nothing to close")
                       + (gain > 0 ? ", +" + gain + " MB free" : ""));
        })
    }

    // ----- settings -----
    // Settings are config.json keys; a change made here is kept by the host on this TV
    // and overrides the file. A missing on/off key counts as on.
    function flag(key) { return config[key] !== false; }
    function set(key, value) { if (store) store.set(key, value); }

    readonly property var opacitySteps: [1, 0.95, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5]

    function toggleItem(label, hint, key) {
        var on = flag(key);
        return {label: label, hint: hint, value: on ? "On" : "Off", on: on, run: function () { home.set(key, !on); }};
    }
    function opacityItem() {
        var steps = opacitySteps, at = 0;
        for (var i = 0; i < steps.length; i++) if (Math.abs(steps[i] - backdropOpacity) < Math.abs(steps[at] - backdropOpacity)) at = i;
        var pct = Math.round((1 - backdropOpacity) * 100);
        return {label: "See-through background", hint: "How much of the app behind Home shows through the background.",
                value: pct ? pct + "%" : "Off", run: function () { home.set("backgroundOpacity", steps[(at + 1) % steps.length]); }};
    }
    function accentItem() {
        var list = accents, at = -1, now = String(baseAccent).toLowerCase();
        for (var i = 0; i < list.length; i++) if (list[i].color === now) at = i;
        return {label: "Accent colour", hint: "The colour of the focus ring, bars and highlights.",
                value: at < 0 ? now : list[at].name, swatch: now,
                run: function () { home.set("accent", list[(at + 1) % list.length].color); }};
    }
    function closeListItems() {
        var list = config.freeMemoryApps || [], a = [], seen = {};
        a.push({label: "Free up memory now", hint: "Closes the apps switched on below that are running.", value: "Run",
                run: function () { home.freeMemory(); }});
        for (var i = 0; i < apps.all.length; i++) {
            (function (app) {
                if (seen[app.id]) return;
                seen[app.id] = true;
                var on = list.indexOf(app.id) >= 0;
                a.push({label: app.title, hint: "Closed by Free up memory when it is running.", value: on ? "Close" : "Keep", on: on,
                        run: function () {
                            var l = list.slice(), j = l.indexOf(app.id);
                            if (j >= 0) l.splice(j, 1); else l.push(app.id);
                            home.set("freeMemoryApps", l);
                        }});
            })(apps.all[i]);
        }
        // Apps on the list that have no tile, such as LG's Home Dashboard.
        var names = {"com.webos.app.homeconnect": "Home Dashboard"};
        for (var k = 0; k < list.length; k++) {
            (function (id) {
                if (seen[id]) return;
                a.push({label: names[id] || id, hint: "Closed by Free up memory when it is running.", value: "Close", on: true,
                        run: function () { var l = list.slice(); l.splice(l.indexOf(id), 1); home.set("freeMemoryApps", l); }});
            })(list[k]);
        }
        return a;
    }
    function settingsSections() {
        var n = apps.hidden.length;
        var appItems = [toggleItem("Pause when Home opens", "Sends Pause to the app in front before Home appears; it stays paused until you press Play.", "pauseOnHome")];
        if (!overlayOnly)
            appItems.push(toggleItem("Put the app in the background", "Home takes over the screen instead of sitting on top of the app, which makes some apps reload.", "pauseUnderHome"));
        return [
            {title: "Look", items: [
                {label: "Theme", hint: "The colours of Home.",
                 value: tv.themeTitle(tv.theme), run: function () { tv.pickTheme(); }},
                opacityItem(),
                accentItem(),
                toggleItem("Clock", "Shows the time and date at the top of Home.", "showClock"),
                toggleItem("Free memory", "Shows how much memory the TV has free at the top of Home.", "showMemory")
            ]},
            {title: "Apps", items: appItems},
            {title: "Rows", items: [
                toggleItem("Running row", "Lists the apps that are open so you can switch back to them.", "showRunning"),
                {label: "Edit apps and inputs", hint: "Move or hide the tiles in the Apps and Inputs rows.", value: "Open",
                 run: function () { settingsPanel.close(); home.setEdit(true); home.focusRow(appsRow, 0); }},
                {label: "Show everything hidden", hint: "Brings back every app and input that has been hidden.",
                 value: n ? n + " hidden" : "None hidden",
                 run: function () { if (!n) return; apps.hidden = []; apps.refilter(); apps.hiddenEdited([]); toast.show("All apps and inputs shown"); }}
            ]},
            {title: "Free memory", items: closeListItems()},
            {title: "TV", items: [
                {label: "TV settings", hint: "Opens LG's own settings for picture, sound and network.", value: "Open",
                 run: function () { luna.launch(home.settingsId(), {}); }},
                {label: "Reset launcher settings", hint: "Puts every setting in this menu back to the value in config.json.", value: "Reset",
                 run: function () { if (home.store) home.store.reset(); toast.show("Launcher settings reset"); }}
            ]}
        ];
    }

    // ----- view -----
    // Below 1 the app under Home shows through the background (config backgroundOpacity).
    readonly property real backdropOpacity: Math.max(0, Math.min(1, config.backgroundOpacity === undefined ? 1 : Number(config.backgroundOpacity)))
    Image {
        id: backdrop
        anchors.fill: parent
        source: home.backgroundSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: home.backdropOpacity
    }
    Rectangle {
        anchors.fill: parent
        visible: backdrop.status !== Image.Ready
        opacity: home.backdropOpacity
        gradient: Gradient {
            GradientStop { position: 0.0; color: home.palette.top || "#0f172a" }
            GradientStop { position: 1.0; color: home.palette.bottom || "#1e293b" }
        }
    }

    // top bar
    Row {
        id: topBar
        x: 96; y: 56
        spacing: 24
        GlassCard {
            visible: home.flag("showClock")
            backdrop: backdrop; blurSource: home.blurSource; glass: home.glass
            width: 300; height: 120
            Text { id: clock; color: home.ink; font.pixelSize: 56; font.weight: Font.Light; text: Qt.formatTime(home.tv.now, "h:mm") }
            Text { anchors.top: clock.bottom; color: home.ink; opacity: 0.75; font.pixelSize: 20; text: Qt.formatDate(home.tv.now, "dddd d MMMM") }
        }
        GlassCard {
            visible: home.flag("showMemory")
            backdrop: backdrop; blurSource: home.blurSource; glass: home.glass
            width: 300; height: 120
            Text { id: memLabel; color: home.ink; opacity: 0.75; font.pixelSize: 20; text: "Free memory" }
            Text {
                anchors.top: memLabel.bottom
                color: home.ink; font.pixelSize: 40
                text: memory.totalMb ? (memory.availableMb >= 1024 ? (memory.availableMb / 1024).toFixed(1) + " GB" : memory.availableMb + " MB") : "–"
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 6; color: "#33ffffff"
                Rectangle { height: parent.height; width: parent.width * memory.freeRatio; color: home.accent }
            }
        }
    }

    Flickable {
        id: scroller
        anchors { left: parent.left; right: parent.right; top: topBar.bottom; topMargin: 20; bottom: parent.bottom }
        contentWidth: width
        contentHeight: rows.height + 40
        interactive: false
        clip: true
        Behavior on contentY { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        onContentYChanged: home.resampleRows()

    Column {
        id: rows
        width: parent.width
        topPadding: 20
        spacing: 14

        TileRow {
            id: appsRow
            onActiveFocusChanged: if (activeFocus) home.reveal(appsRow)
            label: home.editMode ? "Apps  ·  editing" : "Apps"
            entries: home.appEntries()
            backdrop: backdrop; blurSource: home.blurSource; accent: home.accent; ink: home.ink; glass: home.glass
            lifted: home.grabbed !== ""
            focus: true
            onActivated: {
                if (home.grabbed !== "") { home.grabbed = ""; return; }
                home.openApp(entry);
            }
            KeyNavigation.down: runningRow.visible ? runningRow : inputsRow.visible ? inputsRow : systemRow
            onMoveRequested: {
                var at = appsRow.currentIndex + dir;
                apps.step(home.grabbed, dir, home.editMode ? apps.all : apps.shown, function (ok) { if (ok) appsRow.setIndex(at); });
            }
        }
        TileRow {
            id: runningRow
            onActiveFocusChanged: if (activeFocus) home.reveal(runningRow)
            visible: running.items.length > 0 && !home.editMode && home.flag("showRunning")
            label: "Running"
            entries: running.items
            backdrop: backdrop; blurSource: home.blurSource; accent: home.accent; ink: home.ink; glass: home.glass
            onActivated: home.openApp(entry)
            KeyNavigation.up: appsRow
            KeyNavigation.down: inputsRow.visible ? inputsRow : systemRow
        }
        TileRow {
            id: inputsRow
            onActiveFocusChanged: if (activeFocus) home.reveal(inputsRow)
            visible: entries.length > 0             // every input can be hidden in edit mode
            label: home.editMode ? "Inputs  ·  editing" : "Inputs"
            entries: home.inputEntries()
            backdrop: backdrop; blurSource: home.blurSource; accent: home.accent; ink: home.ink; glass: home.glass
            onActivated: home.openApp(entry)
            KeyNavigation.up: runningRow.visible ? runningRow : appsRow
            KeyNavigation.down: systemRow
        }
        TileRow {
            id: systemRow
            onActiveFocusChanged: if (activeFocus) home.reveal(systemRow)
            label: "TV"
            entries: home.systemEntries()
            backdrop: backdrop; blurSource: home.blurSource; accent: home.accent; ink: home.ink; glass: home.glass
            onActivated: home.openApp(entry)
            KeyNavigation.up: inputsRow.visible ? inputsRow : runningRow.visible ? runningRow : appsRow
        }
    }
    }

    SettingsPanel {
        id: settingsPanel
        backdrop: backdrop; blurSource: home.blurSource; accent: home.accent; ink: home.ink; panelColor: home.panel
        sections: settingsPanel.visible ? home.settingsSections() : []
    }
    Sheet { id: sheet; backdrop: backdrop; blurSource: home.blurSource; accent: home.accent; ink: home.ink; panel: home.panel }
    Toast { id: toast; ink: home.ink; panel: home.panel }

    // Back closes the innermost thing; at the top level the frame hides Home.
    function back() {
        if (sheet.visible) { sheet.close(); return true; }
        if (settingsPanel.shown) { settingsPanel.close(); return true; }
        if (grabbed !== "") { grabbed = ""; return true; }
        if (editMode) { setEdit(false); focusRow(appsRow, 0); return true; }
        return false;
    }
}
