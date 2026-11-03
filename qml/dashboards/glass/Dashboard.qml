// The glass dashboard: a bar with the clock and the weather, two rows of apps, a
// band of system apps that folds away, the inputs, and a bottom bar with
// Free up memory and Settings; a menu on a held OK; plus edit mode and the settings page. What the frame gives a dashboard and calls on it is
// described in qml/dashboards/README.md.
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
    readonly property var weather: tv.weather
    readonly property bool shown: tv.shown
    readonly property bool overlayOnly: tv.overlayOnly
    // Colors. A color variant (qml/dashboards/nord/, gruvbox/) is this dashboard with
    // a palette: {top, bottom, panel, ink, glass, surface, accents: [{name, color}]}. With a palette the
    // background is its two colors instead of the picture.
    property var palette: ({})
    readonly property bool plain: !!palette.top
    readonly property color ink: palette.ink || "white"
    readonly property color panel: palette.panel || "#0b1220"
    readonly property color glass: palette.glass || "white"
    readonly property color surface: palette.surface || "#2b2f38"   // every tile's own color
    readonly property var accents: palette.accents || [
        {name: "Sky", color: "#7dd3fc"}, {name: "Mint", color: "#6ee7b7"}, {name: "Amber", color: "#fcd34d"},
        {name: "Rose", color: "#fda4af"}, {name: "Violet", color: "#c4b5fd"}, {name: "White", color: "#f8fafc"}
    ]
    property url backgroundSource: plain ? "" : tv.dataDir + "bg.jpg"
    // A palette keeps to its own accents: a color set for another look gives way to its first.
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

    function settingsId() { return config.settingsId || "com.palm.app.settings"; }

    // Shown by the Home key, the long press (recent) or the menu key (myapps).
    function activate(params) {
        var p = params || {};
        var type = p.activateType || "home";
        sheet.visible = false; settingsPanel.shown = false;
        if (type === "myapps" || type === "editMode") { setEdit(true); focusRow(appsRow, 0); }
        else {
            setEdit(false);
            focusRow(appsRow, type === "recent" ? firstRunning() : 0);
            if (type !== "home" && type !== "powerOn") console.warn("[elgie] activateType " + type + " shown as home");
        }
    }

    function deactivate() { grabbed = ""; grabbedRow = null; sheet.visible = false; settingsPanel.shown = false; }

    function focusRow(r, index) {
        if (!r.visible) r = appsRow;
        r.forceActiveFocus();
        if (index !== undefined) r.setIndex(index);
    }
    function lastRow() { return inputsRow.visible ? inputsRow : systemRow.visible ? systemRow : appsRow; }
    function belowApps() { return systemRow.visible ? systemRow : inputsRow.visible ? inputsRow : bottomBar; }
    // The long press of Home ("recent") lands on the first open app.
    function firstRunning() {
        var e = appEntries();
        for (var i = 0; i < e.length; i++) if (e[i].running) return i;
        return 0;
    }

    // Keeps the focused band on screen.
    function reveal(r) {
        var top = r.y, bottom = r.y + r.height, view = scroller.height;
        if (view <= 0) return;
        if (top < scroller.contentY) scroller.contentY = top;
        else if (bottom > scroller.contentY + view) scroller.contentY = Math.max(0, bottom - view);
    }

    function setEdit(on) { editMode = on; grabbed = ""; grabbedRow = null; if (on) toast.show("Edit: OK on an app or input for its options, Back when done"); }
    function openSettings() { setEdit(false); settingsPanel.open(bottomBar); }

    // ----- bands -----
    // System apps are the launch points the user moved to the band under Apps (config
    // systemApps, kept per TV like the hidden list).
    readonly property var systemApps: config.systemApps || []
    function isSystem(lpId) { return systemApps.indexOf(lpId) >= 0; }
    function toggleSystem(lpId) {
        var l = systemApps.slice(), i = l.indexOf(lpId);
        if (i >= 0) l.splice(i, 1); else l.push(lpId);
        set("systemApps", l);
    }
    // The launch points of one band, in the TV's order: all of them while editing.
    function bandLps(system) {
        var src = editMode ? apps.all : apps.shown, a = [];
        for (var i = 0; i < src.length; i++) if (isSystem(src[i].launchPointId) === system) a.push(src[i]);
        return a;
    }
    function entriesOf(lps) {
        var a = [];
        for (var i = 0; i < lps.length; i++)
            a.push({title: lps[i].title, icon: lps[i].icon, color: lps[i].color, dim: editMode && apps.isHidden(lps[i].launchPointId),
                    running: isRunning(lps[i].id), lp: lps[i]});
        return a;
    }
    function appEntries() { return entriesOf(bandLps(false)); }
    function systemEntries() { return entriesOf(bandLps(true)); }
    readonly property bool systemCollapsed: config.systemAppsCollapsed === true
    function inputEntries() {
        var a = [];
        for (var i = 0; i < inputs.items.length; i++) {
            var d = inputs.items[i], hidden = apps.isHidden(d.id);
            if (hidden && !editMode) continue;
            // While editing, dim marks a hidden input; otherwise one with nothing connected.
            a.push({title: d.label, iconName: "settings_input_hdmi", dim: editMode ? hidden : !d.connected,
                    id: d.id, input: true});
        }
        return a;
    }

    function openApp(entry) {
        if (!entry) return;
        if (editMode) { menu(entry); return; }
        launch(entry);
    }
    function launch(entry) {
        var id = entry.lp ? entry.lp.id : entry.id;
        var params = entry.lp ? entry.lp.params : {};
        if (id) luna.launch(id, params);
    }
    function isRunning(id) {
        for (var j = 0; j < running.items.length; j++) if (running.items[j].id === id) return true;
        return false;
    }

    // The menu on a held OK (and on OK in edit mode): for an app, Open, Force stop while it
    // runs, Hide or Show, Move, and a move between the Apps and System apps bands; for an
    // input, Open and Hide or Show. Hidden inputs share the apps' hidden list, keyed by the
    // input's app id.
    function menu(entry) {
        if (!entry || !(entry.lp || entry.input)) return;
        var items = [{label: "Open", run: function () { home.launch(entry); }}];
        if (entry.lp) {
            var lp = entry.lp, lpId = lp.launchPointId, band = isSystem(lpId) ? systemRow : appsRow;
            if (isRunning(lp.id))
                items.push({label: "Force stop", run: function () {
                    luna.call("com.webos.applicationManager", "closeByAppId", {"id": lp.id}, function (ok) {
                        toast.show(ok ? "Stopped " + lp.title : "Could not stop " + lp.title);
                        running.refresh();
                    });
                }});
            items.push({label: apps.isHidden(lpId) ? "Show" : "Hide", run: function () { apps.toggleHidden(lpId); }});
            items.push({label: "Move", run: function () { grabbed = lpId; grabbedRow = band; band.forceActiveFocus(); }});
            items.push({label: isSystem(lpId) ? "Move to Apps" : "Move to System apps", run: function () { home.toggleSystem(lpId); }});
            items.push({label: "Cancel", run: function () {}});
            sheet.open(lp.title, items, band);
        } else {
            items.push({label: apps.isHidden(entry.id) ? "Show" : "Hide", run: function () { apps.toggleHidden(entry.id); }});
            items.push({label: "Cancel", run: function () {}});
            sheet.open(entry.title, items, inputsRow);
        }
    }

    // The lifted tile takes the place of the tile delta positions along its band (a row
    // up or down is a whole row of positions); the focus then follows the moved tile.
    property var grabbedRow: null            // the band the lifted tile is in
    function moveGrabbed(delta) {
        var band = grabbedRow || appsRow, system = band === systemRow, id = grabbed;
        apps.step(id, delta, bandLps(system), function (ok) {
            var lps = bandLps(system);
            for (var i = 0; i < lps.length; i++) if (lps[i].launchPointId === id) { band.setIndex(i); return; }
        });
    }

    function freeMemory() {
        var list = config.freeMemoryApps || [];
        var before = memory.usableMb, left = list.length, closed = 0;
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
    // The button's label: LG's usable-for-apps figure over the most this TV has reported.
    function freeText() {
        if (!memory.poolMb) return "";
        return Math.round(memory.usableRatio * 100) + "% free";
    }

    // ----- settings -----
    // Settings are config.json keys; a change made here is kept by the host on this TV
    // and overrides the file. A missing on/off key counts as on.
    function flag(key) { return config[key] !== false; }
    function set(key, value) { if (store) store.set(key, value); }

    readonly property var opacitySteps: [1, 0.95, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5]

    // offByDefault: a missing key counts as off instead.
    function toggleItem(label, hint, key, offByDefault) {
        var on = offByDefault ? config[key] === true : flag(key);
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
        return {label: "Accent color", hint: "The color of the focus ring and highlights.",
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
                {label: "Theme", hint: "The colors of Home.",
                 value: tv.themeTitle(tv.theme), run: function () { tv.pickTheme(); }},
                opacityItem(),
                accentItem(),
                toggleItem("Clock", "Shows the time and date in the bar at the top of Home.", "showClock"),
                toggleItem("Weather", weather.configured ? "Shows the conditions now and the next three days in the bar at the top of Home."
                                                         : "Needs a weather entry in config.json (Home Assistant address, token and weather entity).", "showWeather")
            ]},
            {title: "Apps", items: appItems},
            {title: "Rows", items: [
                {label: "System apps", hint: "The band under Apps for the apps you moved there (hold OK on an app). Folded, only its name shows; OK on it unfolds it.",
                 value: systemCollapsed ? "Folded" : "Open", run: function () { home.set("systemAppsCollapsed", !systemCollapsed); }},
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
                toggleItem("Send TV sound to Music Assistant", "Streams what the TV plays to Music Assistant as a live input; the TV's own speakers and ARC are unchanged. Needs elgie-sendspin on this TV.", "sendspin", true),
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
    // Shade over the picture, so text reads at the top and the bottom.
    Rectangle {
        anchors.fill: parent
        visible: backdrop.status === Image.Ready
        opacity: home.backdropOpacity
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#a6000000" }
            GradientStop { position: 0.3; color: "#40000000" }
            GradientStop { position: 0.65; color: "#59000000" }
            GradientStop { position: 1.0; color: "#c0000000" }
        }
    }

    // The bars and bands fade out under the settings page.
    readonly property real chromeOpacity: settingsPanel.shown ? 0 : 1

    // ----- the bar at the top: clock and weather -----
    Card {
        id: topBar
        x: 96; y: 48; width: 1728; height: 112
        glass: home.glass
        visible: home.flag("showClock") || weatherBlock.visible
        opacity: home.chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Column {
            id: clockBlock
            visible: home.flag("showClock")
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                color: home.ink; font.pixelSize: 54; font.weight: Font.Light
                text: Qt.formatTime(home.tv.now, "h:mm AP")
            }
            Text {
                color: home.ink; opacity: 0.7
                font.pixelSize: 18; font.letterSpacing: 2; font.capitalization: Font.AllUppercase
                text: Qt.formatDate(home.tv.now, "dddd, MMMM d")
            }
        }

        Row {
            id: weatherBlock
            visible: home.flag("showWeather") && weather.configured && weather.ready
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 32

            // Now.
            Row {
                spacing: 16
                anchors.verticalCenter: parent.verticalCenter
                WeatherIcon { condition: weather.condition; size: 60; color: home.ink; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: home.ink; font.pixelSize: 54; font.weight: Font.Light
                    text: weather.temperature !== "" ? weather.temperature + "°" : "–"
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { color: home.ink; font.pixelSize: 24; font.weight: Font.DemiBold; text: home.conditionName(weather.condition) }
                    Text {
                        color: home.ink; opacity: 0.7; font.pixelSize: 19
                        text: (weather.apparent !== "" ? "Feels " + weather.apparent + "°" : "")
                              + (weather.humidity !== "" ? "   " + weather.humidity + "% humidity" : "")
                              + (weather.windSpeed !== "" ? "   " + weather.windSpeed + " " + weather.windUnit : "")
                    }
                }
            }
            Rectangle { width: 1; height: 64; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(home.glass.r, home.glass.g, home.glass.b, 0.25) }
            // The next three days.
            Row {
                spacing: 12
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: weather.forecast
                    Item {
                        width: 150; height: 84
                        Text {
                            x: 0; y: 0
                            color: home.ink; opacity: index === 0 ? 0.9 : 0.7
                            font.pixelSize: 18; font.letterSpacing: 1.5; font.capitalization: Font.AllUppercase
                            font.weight: index === 0 ? Font.DemiBold : Font.Normal
                            text: modelData.day
                        }
                        WeatherIcon { x: 0; y: 30; condition: modelData.condition; size: 44; color: home.ink }
                        Text {
                            x: 56; y: 26
                            color: home.ink; font.pixelSize: 23
                            text: (modelData.high !== "" ? modelData.high + "°" : "–")
                                  + "  <font color='" + Qt.rgba(home.ink.r, home.ink.g, home.ink.b, 0.6) + "'>" + (modelData.low !== "" ? modelData.low + "°" : "–") + "</font>"
                            textFormat: Text.RichText
                        }
                        Row {
                            x: 56; y: 56
                            spacing: 4
                            visible: modelData.chance !== "" || modelData.amount !== ""
                            Icon { name: "water_drop"; size: 17; color: home.ink; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                color: home.ink; opacity: 0.7; font.pixelSize: 19
                                text: modelData.chance !== "" ? modelData.chance : modelData.amount + " in"
                            }
                        }
                    }
                }
            }
        }
    }
    function conditionName(c) {
        var names = {"clear-night": "Clear", "cloudy": "Cloudy", "exceptional": "Severe weather", "fog": "Fog", "hail": "Hail",
                     "lightning": "Lightning", "lightning-rainy": "Thunderstorms", "partlycloudy": "Partly cloudy",
                     "pouring": "Heavy rain", "rainy": "Rain", "snowy": "Snow", "snowy-rainy": "Sleet", "sunny": "Sunny",
                     "windy": "Windy", "windy-variant": "Windy"};
        if (names[c]) return names[c];
        c = String(c || "").replace(/-/g, " ");
        return c.charAt(0).toUpperCase() + c.slice(1);
    }

    // ----- the bands -----
    Flickable {
        id: scroller
        anchors { left: parent.left; right: parent.right; top: topBar.visible ? topBar.bottom : parent.top; topMargin: topBar.visible ? 20 : 48
                  bottom: bottomBar.top; bottomMargin: 8 }
        contentWidth: width
        contentHeight: bands.height + 8
        interactive: false
        clip: true
        opacity: home.chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on contentY { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

        Column {
            id: bands
            width: parent.width
            topPadding: 8
            spacing: 12

            TileRow {
                id: appsRow
                onActiveFocusChanged: if (activeFocus) home.reveal(appsRow)
                label: home.editMode ? "Apps  ·  editing" : "Apps"
                entries: home.appEntries()
                accent: home.accent; ink: home.ink; glass: home.glass; surface: home.surface
                lifted: home.grabbed !== "" && home.grabbedRow !== systemRow
                focus: true
                onActivated: {
                    if (home.grabbed !== "") { home.grabbed = ""; home.grabbedRow = null; return; }
                    home.openApp(entry);
                }
                onLongPressed: if (home.grabbed === "") home.menu(entry)
                KeyNavigation.down: home.belowApps()
                onMoveRequested: home.moveGrabbed(delta)
            }
            TileRow {
                id: systemRow
                onActiveFocusChanged: if (activeFocus) home.reveal(systemRow)
                visible: entries.length > 0
                label: home.editMode ? "System apps  ·  editing" : "System apps"
                entries: home.systemEntries()
                collapsible: true
                collapsed: home.systemCollapsed
                onToggled: home.set("systemAppsCollapsed", !home.systemCollapsed)
                accent: home.accent; ink: home.ink; glass: home.glass; surface: home.surface
                lifted: home.grabbed !== "" && home.grabbedRow === systemRow
                onActivated: {
                    if (home.grabbed !== "") { home.grabbed = ""; home.grabbedRow = null; return; }
                    home.openApp(entry);
                }
                onLongPressed: if (home.grabbed === "") home.menu(entry)
                KeyNavigation.up: appsRow
                KeyNavigation.down: inputsRow.visible ? inputsRow : bottomBar
                onMoveRequested: home.moveGrabbed(delta)
            }
            TileRow {
                id: inputsRow
                onActiveFocusChanged: if (activeFocus) home.reveal(inputsRow)
                visible: entries.length > 0             // every input can be hidden in edit mode
                label: home.editMode ? "Inputs  ·  editing" : "Inputs"
                entries: home.inputEntries()
                accent: home.accent; ink: home.ink; glass: home.glass; surface: home.surface
                onActivated: home.openApp(entry)
                onLongPressed: home.menu(entry)
                KeyNavigation.up: systemRow.visible ? systemRow : appsRow
                KeyNavigation.down: bottomBar
            }
        }
    }

    // ----- the bar at the bottom, centered: Free up memory (an icon and the free share) and Settings -----
    FocusScope {
        id: bottomBar
        x: 96; y: 1080 - 32 - 56; width: 1728; height: 56
        opacity: home.chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 200 } }
        property int at: 0
        function setIndex(i) { at = Math.max(0, Math.min(i, 1)); }
        KeyNavigation.up: home.lastRow()
        Keys.onLeftPressed: setIndex(at - 1)
        Keys.onRightPressed: setIndex(at + 1)
        Keys.onReturnPressed: if (!event.isAutoRepeat) run()
        Keys.onEnterPressed: if (!event.isAutoRepeat) run()
        function run() { if (at === 0) home.freeMemory(); else home.openSettings(); }
        function pick(i) { if (!bottomBar.activeFocus) bottomBar.forceActiveFocus(); setIndex(i); }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Pill {
                icon: "recycling"; text: home.freeText()
                current: bottomBar.activeFocus && bottomBar.at === 0
                accent: home.accent; ink: home.ink; glass: home.glass; panel: home.panel
                onHovered: bottomBar.pick(0)
                onClicked: { bottomBar.pick(0); bottomBar.run(); }
            }
            Pill {
                icon: "settings"; text: "Settings"
                current: bottomBar.activeFocus && bottomBar.at === 1
                accent: home.accent; ink: home.ink; glass: home.glass; panel: home.panel
                onHovered: bottomBar.pick(1)
                onClicked: { bottomBar.pick(1); bottomBar.run(); }
            }
        }
    }

    SettingsPanel {
        id: settingsPanel
        accent: home.accent; ink: home.ink; panelColor: home.panel; glass: home.glass
        sections: settingsPanel.visible ? home.settingsSections() : []
    }
    Sheet { id: sheet; accent: home.accent; ink: home.ink; panel: home.panel; glass: home.glass }
    Toast { id: toast; ink: home.ink; panel: home.panel; glass: home.glass }

    // Back closes the innermost thing; at the top level the frame hides Home.
    function back() {
        if (sheet.visible) { sheet.close(); return true; }
        if (settingsPanel.shown) { settingsPanel.close(); return true; }
        if (grabbed !== "") { grabbed = ""; grabbedRow = null; return true; }
        if (editMode) { setEdit(false); focusRow(appsRow, 0); return true; }
        return false;
    }
}
