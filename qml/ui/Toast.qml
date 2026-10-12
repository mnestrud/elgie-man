// A short message at the bottom of the screen.
import QtQuick 2.7

Rectangle {
    id: toast
    property alias text: label.text
    property color ink: "white"
    property color panel: "#0b1220"
    function show(t) { label.text = t; opacity = 1; hideTimer.restart(); }

    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 64 }
    width: label.implicitWidth + 64; height: 72
    color: Qt.rgba(panel.r, panel.g, panel.b, 0.8)
    border.width: 1; border.color: "#55ffffff"
    opacity: 0
    z: 60
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Text { id: label; anchors.centerIn: parent; color: toast.ink; font.pixelSize: 26 }
    Timer { id: hideTimer; interval: 3000; onTriggered: toast.opacity = 0 }
}
