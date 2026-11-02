// A captioned band of tiles, one or two rows high, that scrolls sideways. The model is a
// JS array of objects with title, icon, iconName, color and dim; with rows = 2 the
// entries fill each column top to bottom, then the next column; running marks an open app. activated(index, entry)
// fires on OK or a click, longPressed(index, entry) when OK is held or the pointer
// pressed and held; index is the position in entries. A collapsible band has a header
// that takes the focus (Up from the top row), and OK on it folds the tiles away.
import QtQuick 2.7

FocusScope {
    id: row
    property string label: ""
    property var entries: []
    property int rows: 1
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color glass: "white"
    property bool lifted: false
    property bool collapsible: false
    property bool collapsed: false
    property int tileWidth: 176
    property int tileHeight: 176
    property color surface: "#2b2f38"
    property int currentIndex: 0             // position in entries
    readonly property int columns: Math.ceil(entries.length / rows)
    readonly property var currentEntry: currentIndex >= 0 && currentIndex < entries.length ? entries[currentIndex] : null
    signal activated(int index, var entry)
    signal longPressed(int index, var entry)
    signal moveRequested(int delta)          // arrows while a tile is lifted: ±1 up or down, ±rows left or right
    signal toggled()                         // OK on the header of a collapsible band

    readonly property int captionHeight: 32
    readonly property int tilePitch: tileHeight + 32 + 8
    readonly property bool folded: collapsible && collapsed
    implicitHeight: captionHeight + (folded ? 8 : 12 + rows * tilePitch)
    height: visible ? implicitHeight : 0
    width: parent ? parent.width : 1920

    // The header has the focus while the band is folded, or after Up from the top row.
    property bool onHeader: false
    readonly property bool headerFocus: collapsible && (collapsed || onHeader)
    onActiveFocusChanged: if (!activeFocus) onHeader = false

    function clamp(i) { return Math.max(0, Math.min(i, entries.length - 1)); }
    function setIndex(i) { wanted = i; currentIndex = clamp(i); }
    onCurrentIndexChanged: {
        list.currentIndex = Math.max(0, Math.floor(currentIndex / rows));
        if (!restoring) wanted = currentIndex;
    }
    // The list resets its position when the entries change; keep the user's place.
    property int wanted: 0
    property bool restoring: false
    onEntriesChanged: {
        restoring = true;
        Qt.callLater(function () {
            row.currentIndex = row.clamp(row.wanted);
            list.currentIndex = Math.max(0, Math.floor(row.currentIndex / row.rows));
            row.restoring = false;
        });
    }

    // Pointer: the tile under the moving pointer takes the focus and the wheel steps
    // along the band. A tile that slides under a still pointer is left alone, so a
    // scroll the pointer started does not run on by itself.
    property point pointer: Qt.point(-1, -1)
    Timer { id: settle; interval: 250 }
    function pick(i) {
        onHeader = false;
        if (!row.activeFocus) row.forceActiveFocus();
        if (currentIndex !== i) { setIndex(i); settle.restart(); }
    }
    // While OK or the pointer's button is held, the pointer's jitter must not pull the
    // focus back from a menu the hold has opened.
    function pointed(i, p) {
        if (p.x === pointer.x && p.y === pointer.y) return;
        pointer = p;
        if (!row.lifted && !settle.running && !row.held) pick(i);
    }
    Timer { id: holdClear; interval: 400; onTriggered: row.held = false }
    function wheeled(delta) {
        if (row.lifted || !delta) return;
        if (!row.activeFocus) row.forceActiveFocus();
        var next = currentIndex + (delta < 0 ? rows : -rows);
        if (next >= entries.length && Math.floor(currentIndex / rows) < columns - 1) next = entries.length - 1;
        setIndex(next);
        settle.restart();
    }

    // OK held for a moment is a long press; a short one activates on release.
    Timer {
        id: hold
        interval: 600
        onTriggered: { row.held = true; row.longPressed(row.currentIndex, row.entries[row.currentIndex]); }
    }
    property bool held: false
    function okPressed(event) {
        if (!event.isAutoRepeat && !hold.running && !held) hold.restart();
        event.accepted = true;
    }
    function okReleased(event) {
        if (event.isAutoRepeat) { event.accepted = true; return; }
        if (hold.running) { hold.stop(); row.activated(row.currentIndex, row.entries[row.currentIndex]); held = false; }
        else if (held) holdClear.restart();
        event.accepted = true;
    }
    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter; }

    Item {
        id: header
        x: 96; width: caption.implicitWidth + (row.collapsible ? 36 : 0); height: row.captionHeight
        focus: row.headerFocus
        Text {
            id: caption
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: row.label
            color: header.activeFocus ? row.accent : row.ink
            opacity: row.activeFocus ? 1.0 : 0.65
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }
        Icon {
            visible: row.collapsible
            anchors { left: caption.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
            name: row.collapsed ? "chevron_right" : "expand_more"
            size: 30
            color: header.activeFocus ? row.accent : row.ink
            opacity: row.activeFocus ? 1.0 : 0.65
        }
        MouseArea {
            visible: row.collapsible
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: { if (!row.activeFocus) row.forceActiveFocus(); row.onHeader = true; }
            onClicked: { row.onHeader = true; row.toggled(); }
        }
        // The header keeps the focus through a fold or unfold.
        Keys.onPressed: {
            var k = event.key;
            if (row.isOk(k)) { if (!event.isAutoRepeat) { row.onHeader = true; row.toggled(); } event.accepted = true; }
            else if (k === Qt.Key_Down && !row.collapsed) { row.onHeader = false; event.accepted = true; }
            else if (k === Qt.Key_Left || k === Qt.Key_Right) event.accepted = true;
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: 12 }
        height: row.rows * row.tilePitch
        visible: !row.folded
        orientation: ListView.Horizontal
        spacing: 20
        leftMargin: 96; rightMargin: 96
        focus: !row.headerFocus
        clip: false
        interactive: false
        keyNavigationEnabled: false          // the keys are handled below, so two rows work
        model: row.columns
        highlightMoveDuration: 160
        preferredHighlightBegin: 96
        preferredHighlightEnd: row.width - 96 - row.tileWidth
        highlightRangeMode: ListView.ApplyRange
        boundsBehavior: Flickable.StopAtBounds

        delegate: Column {
            property int column: index
            spacing: 8
            Repeater {
                model: Math.max(0, Math.min(row.rows, row.entries.length - column * row.rows))
                Tile {
                    readonly property int flat: column * row.rows + index
                    readonly property var entry: row.entries[flat] || ({})
                    tileWidth: row.tileWidth; tileHeight: row.tileHeight
                    title: entry.title || ""
                    icon: entry.icon || ""
                    iconName: entry.iconName || ""
                    dim: !!entry.dim
                    running: !!entry.running
                    accent: row.accent; ink: row.ink; glass: row.glass; surface: row.surface
                    current: list.activeFocus && flat === row.currentIndex
                    lifted: current && row.lifted
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: if (!pressed) row.pointed(flat, mapToItem(null, mouse.x, mouse.y))
                        onClicked: {
                            if (!row.lifted) row.pick(flat);
                            row.activated(row.currentIndex, row.entries[row.currentIndex]);
                        }
                        onPressAndHold: {
                            if (row.lifted) return;
                            row.pick(flat);
                            row.held = true;
                            row.longPressed(row.currentIndex, row.entries[row.currentIndex]);
                        }
                        onReleased: if (row.held) holdClear.restart()
                        onWheel: row.wheeled(wheel.angleDelta.y || wheel.angleDelta.x)
                    }
                }
            }
        }

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: {
            var i = row.currentIndex, n = row.entries.length, r = row.rows, k = event.key;
            if (row.isOk(k)) { row.okPressed(event); return; }
            if (k !== Qt.Key_Left && k !== Qt.Key_Right && k !== Qt.Key_Up && k !== Qt.Key_Down) return;
            if (row.lifted) {
                if (k === Qt.Key_Left && i - r >= 0) row.moveRequested(-r);
                else if (k === Qt.Key_Right && i + r < n) row.moveRequested(r);
                else if (k === Qt.Key_Up && i % r > 0) row.moveRequested(-1);
                else if (k === Qt.Key_Down && i % r < r - 1 && i + 1 < n) row.moveRequested(1);
                event.accepted = true;           // a lifted tile does not leave its band
                return;
            }
            if (k === Qt.Key_Left) { if (i - r >= 0) row.setIndex(i - r); event.accepted = true; }
            else if (k === Qt.Key_Right) {
                if (i + r < n) row.setIndex(i + r);
                else if (Math.floor(i / r) < row.columns - 1) row.setIndex(n - 1);
                event.accepted = true;
            }
            // Up at the top row goes to the band's header if it has one, else to the band
            // above; Down at the bottom row goes to the band below.
            else if (k === Qt.Key_Up && i % r > 0) { row.setIndex(i - 1); event.accepted = true; }
            else if (k === Qt.Key_Up && row.collapsible) { row.onHeader = true; event.accepted = true; }
            else if (k === Qt.Key_Down && i % r < r - 1 && i + 1 < n) { row.setIndex(i + 1); event.accepted = true; }
        }
        Keys.onReleased: if (row.isOk(event.key)) row.okReleased(event)
    }
}
