// A glass panel for the top bar (clock, memory). Same pre-blurred
// technique as GlassTile, without focus.
import QtQuick 2.7

Item {
    id: card
    property Item backdrop
    property url blurSource
    property color tint: "transparent"
    property color glass: "white"
    default property alias content: inner.data

    function resample() {
        if (!backdrop) return;
        var p = card.mapToItem(backdrop, 0, 0);
        glass.x = -p.x; glass.y = -p.y;
    }
    onXChanged: resample()
    onYChanged: resample()
    onWidthChanged: resample()
    Component.onCompleted: resample()

    Item {
        anchors.fill: parent
        clip: true
        Image {
            id: glass
            source: card.blurSource
            width: card.backdrop ? card.backdrop.width : 1920
            height: card.backdrop ? card.backdrop.height : 1080
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            color: card.tint.a > 0 ? card.tint : card.glass
            opacity: card.tint.a > 0 ? 0.35 : 0.10
        }
    }
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: "#44ffffff" }
    Item { id: inner; anchors.fill: parent; anchors.margins: 18 }
}
