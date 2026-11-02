// The launcher's settings: a page with the sections down the left and the settings of
// the chosen one on the right. sections = [{title, items: [{label, hint, value, on, swatch, run}]}].
// Left/Right change the section, Up/Down the setting, OK calls the setting's run().
// With the pointer: a click on a section or a setting does the same.
import QtQuick 2.7

FocusScope {
    id: panel
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color panelColor: "#0b1220"    // the page, and text on the accent color
    property color glass: "white"
    property var sections: []
    property int tab: 0
    property bool shown: false
    property Item returnFocus
    readonly property var items: sections.length ? sections[Math.min(tab, sections.length - 1)].items : []
    readonly property var currentItem: items.length ? items[Math.max(0, Math.min(list.currentIndex, items.length - 1))] : null

    anchors.fill: parent
    z: 40
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    function open(back) {
        returnFocus = back || null;
        wanted = 0; tab = 0; shown = true;
        list.currentIndex = 0; list.forceActiveFocus();
        armed = false; arm.restart();
    }
    // OK counts only after the key that opened the page has been let go, so a held OK
    // on the Settings button does not run the first setting with its repeats.
    property bool armed: false
    Timer { id: arm; interval: 700; onTriggered: panel.armed = true }
    function okPressed(event) { event.accepted = true; if (armed && !event.isAutoRepeat) run(); }
    function close() {
        shown = false;
        if (returnFocus) returnFocus.forceActiveFocus();
    }
    function setTab(t) {
        if (t < 0 || t >= sections.length || t === tab) return;
        wanted = 0; tab = t; list.currentIndex = 0;
    }
    function run() {
        var it = items[list.currentIndex];
        if (it && it.run) it.run();
    }
    function tint(a) { return Qt.rgba(glass.r, glass.g, glass.b, a); }

    // The list resets its position when a setting changes; keep the user's place.
    property int wanted: 0
    property bool restoring: false
    onItemsChanged: {
        restoring = true;
        Qt.callLater(function () {
            list.currentIndex = Math.max(0, Math.min(panel.wanted, panel.items.length - 1));
            panel.restoring = false;
        });
    }

    // The dashboard fades its own bands out while the page is open, so the page sits on the picture alone.
    Rectangle { anchors.fill: parent; color: Qt.rgba(panel.panelColor.r, panel.panelColor.g, panel.panelColor.b, 0.82) }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: wheel.accepted = true }

    Text {
        id: head
        x: 96; y: 52
        text: "Settings"; color: panel.ink
        font.pixelSize: 44; font.weight: Font.Bold
    }

    Column {
        id: tabs
        x: 96; y: 140
        width: 352
        spacing: 10
        Repeater {
            model: panel.sections
            Rectangle {
                width: tabs.width; height: 64; radius: 32
                color: index === panel.tab ? panel.accent : panel.tint(0.08)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    x: 28; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title; font.pixelSize: 26
                    font.weight: index === panel.tab ? Font.DemiBold : Font.Normal
                    color: index === panel.tab ? panel.panelColor : panel.ink
                }
                MouseArea { anchors.fill: parent; onClicked: panel.setTab(index) }
            }
        }
    }

    ListView {
        id: list
        x: 496; y: 140
        width: 1824 - x
        height: Math.min(contentHeight, 764)
        model: panel.items
        spacing: 8
        clip: true
        focus: true
        interactive: false
        keyNavigationEnabled: true
        highlightMoveDuration: 0
        onCurrentIndexChanged: if (!panel.restoring) panel.wanted = currentIndex

        delegate: Rectangle {
            width: list.width; height: 80; radius: 16
            color: ListView.isCurrentItem ? panel.tint(0.2) : panel.tint(0.08)
            border.width: ListView.isCurrentItem ? 3 : 0
            border.color: panel.accent
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors { left: parent.left; leftMargin: 28; right: value.left; rightMargin: 24; verticalCenter: parent.verticalCenter }
                text: modelData.label; color: panel.ink; font.pixelSize: 27; elide: Text.ElideRight
            }
            Row {
                id: value
                anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                spacing: 14
                Rectangle {
                    visible: !!modelData.swatch
                    width: 30; height: 30; radius: 15
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData.swatch || "transparent"
                    border.width: 1; border.color: panel.tint(0.4)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.value || ""; font.pixelSize: 25
                    font.weight: modelData.on === true ? Font.DemiBold : Font.Normal
                    color: modelData.on === true ? panel.accent : panel.ink
                    opacity: modelData.on === false ? 0.55 : 0.9
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: list.currentIndex = index
                onClicked: { list.currentIndex = index; panel.run(); }
            }
        }

        Keys.onLeftPressed: panel.setTab(panel.tab - 1)
        Keys.onRightPressed: panel.setTab(panel.tab + 1)
        Keys.onReturnPressed: panel.okPressed(event)
        Keys.onEnterPressed: panel.okPressed(event)
        Keys.onReleased: if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { panel.armed = true; event.accepted = true; }
    }

    // What the chosen setting does.
    Text {
        id: hint
        x: list.x + 28; y: list.y + list.height + 20
        width: list.width - 56
        text: panel.currentItem && panel.currentItem.hint ? panel.currentItem.hint : ""
        color: panel.ink; opacity: 0.65; font.pixelSize: 22
        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
    }

    HintBar {
        anchors { right: parent.right; rightMargin: 96; bottom: parent.bottom; bottomMargin: 40 }
        ink: panel.ink; glass: panel.glass
        hints: [["Left / Right", "Section"], ["Up / Down", "Setting"], ["OK", "Change"], ["Back", "Close"]]
    }
}
