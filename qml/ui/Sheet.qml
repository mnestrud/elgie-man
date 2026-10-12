// A small modal action list. open(title, actions) with actions = [{label, run}].
import QtQuick 2.7

FocusScope {
    id: sheet
    property Item backdrop
    property url blurSource
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color panel: "#0b1220"         // text on the accent colour
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
    }
    function close() {
        visible = false;
        if (returnFocus) returnFocus.forceActiveFocus();
    }

    Rectangle { anchors.fill: parent; color: "#99000000" }

    GlassCard {
        id: card
        backdrop: sheet.backdrop; blurSource: sheet.blurSource
        width: 560; height: 120 + sheet.actions.length * 76
        anchors.centerIn: parent

        // Without a blurred picture behind it the card needs a body of its own.
        Rectangle { anchors.fill: parent; anchors.margins: -18; visible: sheet.blurSource == ""; color: sheet.panel }
        Text { id: head; text: sheet.title; color: sheet.ink; font.pixelSize: 30; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
        ListView {
            id: list
            anchors { top: head.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom }
            model: sheet.actions
            spacing: 8
            interactive: false
            keyNavigationEnabled: true
            delegate: Rectangle {
                width: list.width; height: 68
                color: ListView.isCurrentItem ? sheet.accent : "#22ffffff"
                Text { anchors.centerIn: parent; text: modelData.label; color: parent.ListView.isCurrentItem ? sheet.panel : sheet.ink; font.pixelSize: 26 }
            }
            Keys.onReturnPressed: { var a = sheet.actions[currentIndex]; sheet.close(); if (a && a.run) a.run(); }
            Keys.onEnterPressed: { var a = sheet.actions[currentIndex]; sheet.close(); if (a && a.run) a.run(); }
        }
    }
}
