// Focus outline drawn just outside an item. Dashed-looking double ring while lifted.
import QtQuick 2.7

Item {
    id: ring
    property color color: "#7dd3fc"
    property bool lifted: false

    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        color: "transparent"
        border.width: 4
        border.color: ring.color
    }
    Rectangle {
        visible: ring.lifted
        anchors.fill: parent
        anchors.margins: -12
        color: "transparent"
        border.width: 2
        border.color: "white"
        SequentialAnimation on opacity {
            running: ring.lifted; loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.2; duration: 500 }
            NumberAnimation { from: 0.2; to: 1; duration: 500 }
        }
    }
}
