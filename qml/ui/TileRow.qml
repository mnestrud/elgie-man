// A labelled horizontal row of glass tiles. The model is a JS array of objects with
// title, icon, glyph, color and dim; activated(index, entry) fires on OK or a click.
import QtQuick 2.7

FocusScope {
    id: row
    property string label: ""
    property var entries: []
    property Item backdrop
    property url blurSource
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color glass: "white"
    property bool lifted: false
    property alias currentIndex: list.currentIndex
    readonly property var currentEntry: list.currentIndex >= 0 && list.currentIndex < entries.length ? entries[list.currentIndex] : null
    signal activated(int index, var entry)
    signal moveRequested(int dir)            // left/right while a tile is lifted

    // The list resets its position when the entries change; keep the user's place.
    property int wanted: 0
    property bool restoring: false
    function setIndex(i) { wanted = i; list.currentIndex = Math.max(0, Math.min(i, entries.length - 1)); }
    onEntriesChanged: {
        restoring = true;
        Qt.callLater(function () {
            list.currentIndex = Math.max(0, Math.min(row.wanted, row.entries.length - 1));
            row.restoring = false;
        });
    }

    // Pointer: the tile under the moving pointer takes the focus and the wheel steps
    // along the row. A tile that slides under a still pointer is left alone, so a
    // scroll the pointer started does not run on by itself.
    property point pointer: Qt.point(-1, -1)
    Timer { id: settle; interval: 250 }
    function pick(i) {
        if (!row.activeFocus) row.forceActiveFocus();
        if (list.currentIndex !== i) { list.currentIndex = i; settle.restart(); }
    }
    function pointed(i, p) {
        if (p.x === pointer.x && p.y === pointer.y) return;
        pointer = p;
        if (!row.lifted && !settle.running) pick(i);
    }
    function wheeled(delta) {
        if (row.lifted || !delta) return;
        if (!row.activeFocus) row.forceActiveFocus();
        setIndex(list.currentIndex + (delta < 0 ? 1 : -1));
        settle.restart();
    }

    implicitHeight: 52 + 156 + 24
    height: visible ? implicitHeight : 0
    width: parent ? parent.width : 1920

    Text {
        id: caption
        x: 96
        text: row.label
        color: row.ink
        opacity: row.activeFocus ? 1.0 : 0.7
        font.pixelSize: 26
        font.weight: Font.DemiBold
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: caption.bottom; topMargin: 16 }
        height: 156 + 16
        orientation: ListView.Horizontal
        spacing: 22
        leftMargin: 96; rightMargin: 96
        focus: true
        clip: false
        model: row.entries
        keyNavigationWraps: false
        highlightMoveDuration: 160
        preferredHighlightBegin: 96
        preferredHighlightEnd: row.width - 96 - 248
        highlightRangeMode: ListView.ApplyRange
        boundsBehavior: Flickable.StopAtBounds
        onContentXChanged: row.resampleAll()
        onCurrentIndexChanged: if (!row.restoring) row.wanted = currentIndex

        delegate: GlassTile {
            backdrop: row.backdrop
            blurSource: row.blurSource
            title: modelData.title || ""
            glyph: modelData.glyph || ""
            icon: modelData.icon || ""
            tint: modelData.color && /^#[0-9a-fA-F]{6}$/.test(modelData.color) ? modelData.color : "transparent"
            dim: !!modelData.dim
            accent: row.accent
            ink: row.ink
            glass: row.glass
            current: row.activeFocus && ListView.isCurrentItem
            lifted: current && row.lifted
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: row.pointed(index, mapToItem(null, mouse.x, mouse.y))
                onClicked: {
                    if (!row.lifted) row.pick(index);
                    row.activated(list.currentIndex, row.entries[list.currentIndex]);
                }
                onWheel: row.wheeled(wheel.angleDelta.y || wheel.angleDelta.x)
            }
        }

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: {
            if (!row.lifted) return;
            if (event.key === Qt.Key_Left) { row.moveRequested(-1); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { row.moveRequested(1); event.accepted = true; }
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) event.accepted = true;
        }
        Keys.onReturnPressed: row.activated(currentIndex, row.entries[currentIndex])
        Keys.onEnterPressed: row.activated(currentIndex, row.entries[currentIndex])
    }

    function resampleAll() {
        for (var i = 0; i < list.contentItem.children.length; i++) {
            var c = list.contentItem.children[i];
            if (c.resample) c.resample();
        }
    }
    onYChanged: resampleAll()
}
