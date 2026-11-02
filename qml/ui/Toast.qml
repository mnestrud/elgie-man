// A short message at the bottom of the screen.
import QtQuick 2.7

Rectangle {
    id: toast
    property alias text: label.text
    property color ink: "white"
    property color panel: "#0b1220"
    property color glass: "white"
    function show(t) { label.text = t; opacity = 1; hideTimer.restart(); }

    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 108 }   // clear of the bottom bar
    width: label.implicitWidth + 56; height: 56
    radius: height / 2
    color: Qt.rgba(panel.r, panel.g, panel.b, 0.92)
    border.width: 1; border.color: Qt.rgba(glass.r, glass.g, glass.b, 0.25)
    opacity: 0
    z: 60
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Text { id: label; anchors.centerIn: parent; color: toast.ink; font.pixelSize: 23 }
    Timer { id: hideTimer; interval: 3000; onTriggered: toast.opacity = 0 }
}
