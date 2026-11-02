// A rounded square tile with its name underneath: an app icon or a Material icon on the
// same dark surface for every tile. Focus draws the accent outline and lifts the tile.
import QtQuick 2.7

Item {
    id: tile
    property string title: ""
    property url icon
    property string iconName: ""           // Material icon when there is no app icon
    property bool dim: false
    property bool running: false           // shows a small clock badge
    property bool current: false
    property bool lifted: false            // being moved in edit mode
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color glass: "white"          // the border tint
    property color surface: "#2b2f38"      // the tile itself
    property int tileWidth: 176
    property int tileHeight: 176
    property int captionHeight: 32

    width: tileWidth; height: tileHeight + captionHeight
    z: current ? 2 : 1
    opacity: dim ? 0.4 : 1.0

    // The name sits inside the tile when it has no picture to show.
    readonly property bool titleInside: !iconImage.visible && iconName === ""

    Rectangle {
        id: card
        width: tile.tileWidth; height: tile.tileHeight
        radius: 16
        color: Qt.rgba(tile.surface.r, tile.surface.g, tile.surface.b, tile.current ? 0.96 : 0.86)
        border.width: tile.current ? 4 : 1
        border.color: tile.current ? tile.accent : Qt.rgba(tile.glass.r, tile.glass.g, tile.glass.b, 0.2)
        scale: tile.current ? 1.06 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Image {
            id: iconImage
            visible: tile.icon != "" && status === Image.Ready
            source: tile.icon
            anchors.centerIn: parent
            width: parent.width * 0.64
            height: parent.height * 0.64
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
        Icon {
            visible: !iconImage.visible && tile.iconName !== ""
            anchors.centerIn: parent
            name: tile.iconName; size: 52; color: tile.ink
            opacity: tile.current ? 1 : 0.85
        }
        Text {
            visible: tile.titleInside
            anchors.centerIn: parent
            width: parent.width - 28
            horizontalAlignment: Text.AlignHCenter
            text: tile.title
            color: tile.ink
            font.pixelSize: 26
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        // The app is open: a clock in the corner.
        Rectangle {
            visible: tile.running
            anchors { top: parent.top; right: parent.right; margins: 8 }
            width: 30; height: 30; radius: 15
            color: "#c0101624"
            border.width: 1; border.color: Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.35)
            Icon { anchors.centerIn: parent; name: "schedule"; size: 20; color: tile.ink }
        }
        // Dashed-looking outer ring while the tile is being moved.
        Rectangle {
            visible: tile.lifted
            anchors.fill: parent
            anchors.margins: -10
            radius: parent.radius + 8
            color: "transparent"
            border.width: 2
            border.color: tile.ink
            SequentialAnimation on opacity {
                running: tile.lifted; loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.2; duration: 500 }
                NumberAnimation { from: 0.2; to: 1; duration: 500 }
            }
        }
    }

    Text {
        visible: !tile.titleInside
        anchors { top: card.bottom; topMargin: 10; horizontalCenter: card.horizontalCenter }
        width: card.width
        horizontalAlignment: Text.AlignHCenter
        text: tile.title
        color: tile.ink
        opacity: tile.current ? 1.0 : 0.72
        font.pixelSize: 21
        font.weight: tile.current ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
    }
}
