// A small modal action list. open(title, actions) with actions = [{label, run}].
import QtQuick 2.7

FocusScope {
    id: sheet
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color panel: "#0b1220"         // the dialog, and text on the accent color
    property color glass: "white"
    property string title: ""
    property var actions: []
    property Item returnFocus
    readonly property bool shown: visible

    visible: false
    anchors.fill: parent
    z: 50

    function open(t, a, back) {
        title = t; actions = a; returnFocus = back || null;
        visible = true; list.currentIndex = 0; list.forceActiveFocus();
        armed = false; arm.restart();
    }
    // A sheet opened by holding OK must not take the repeats of that same hold as a
    // choice: OK counts only after the key has been let go (or a moment has passed).
    property bool armed: false
    Timer { id: arm; interval: 700; onTriggered: sheet.armed = true }
    function close() {
        visible = false;
        if (returnFocus) returnFocus.forceActiveFocus();
    }

    Rectangle { anchors.fill: parent; color: "#a6000000" }
    // Keeps the pointer off what is under the sheet; a click beside the dialog closes it.
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: sheet.close(); onWheel: wheel.accepted = true }

    Rectangle {
        id: card
        width: 640; height: body.height + 64
        anchors.centerIn: parent
        radius: 28
        color: Qt.rgba(sheet.panel.r, sheet.panel.g, sheet.panel.b, 0.96)
        border.width: 1; border.color: Qt.rgba(sheet.glass.r, sheet.glass.g, sheet.glass.b, 0.2)
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 32; y: 32; width: parent.width - 64
            spacing: 8
            Text { width: parent.width; text: sheet.title; color: sheet.ink; font.pixelSize: 30; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Item { width: 1; height: 8 }
            ListView {
                id: list
                width: parent.width; height: count * 72 + Math.max(0, count - 1) * 8
                model: sheet.actions
                spacing: 8
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                delegate: Rectangle {
                    width: list.width; height: 72; radius: 36
                    color: ListView.isCurrentItem ? sheet.accent : Qt.rgba(sheet.glass.r, sheet.glass.g, sheet.glass.b, 0.08)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        x: 32; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label; font.pixelSize: 26
                        color: parent.ListView.isCurrentItem ? sheet.panel : sheet.ink
                        font.weight: parent.ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: list.currentIndex = index
                        onClicked: { list.currentIndex = index; list.run(); }
                    }
                }
                function run() { var a = sheet.actions[currentIndex]; sheet.close(); if (a && a.run) a.run(); }
                function okPressed(event) { event.accepted = true; if (sheet.armed && !event.isAutoRepeat) run(); }
                Keys.onReturnPressed: okPressed(event)
                Keys.onEnterPressed: okPressed(event)
                Keys.onReleased: if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { sheet.armed = true; event.accepted = true; }
            }
        }
    }
}
