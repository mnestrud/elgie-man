// A rounded translucent surface, for the bar at the top of Home.
import QtQuick 2.7

Rectangle {
    id: card
    property color glass: "white"
    property real strength: 0.12
    default property alias content: inner.data

    radius: 20
    color: Qt.rgba(glass.r, glass.g, glass.b, strength)
    border.width: 1
    border.color: Qt.rgba(glass.r, glass.g, glass.b, 0.18)
    Item { id: inner; anchors.fill: parent; anchors.margins: 20 }
}
