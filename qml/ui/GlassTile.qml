// A pre-blurred glass tile: it shows the slice of the blurred background that sits
// behind it, a light tint, a hairline border, and an icon or a large label.
// No runtime blur: the blur was baked into the image by scripts/set-background.sh.
import QtQuick 2.7

Item {
    id: tile
    property Item backdrop                 // full-screen item the blurred image is aligned to
    property url blurSource
    property string title: ""
    property string glyph: ""              // large text when there is no icon
    property url icon
    property color tint: "transparent"
    property bool dim: false
    property bool current: false
    property bool lifted: false            // being moved in edit mode
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color glass: "white"          // the color of the tile's own tint

    width: 248; height: 156
    z: current ? 2 : 1
    scale: current ? 1.08 : 1.0
    opacity: dim ? 0.45 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    function resample() {
        if (!backdrop) return;
        var p = tile.mapToItem(backdrop, 0, 0);
        glass.x = -p.x; glass.y = -p.y;
    }
    onXChanged: resample()
    onYChanged: resample()
    Component.onCompleted: resample()

    Item {
        anchors.fill: parent
        clip: true
        Image {
            id: glass
            source: tile.blurSource
            width: tile.backdrop ? tile.backdrop.width : 1920
            height: tile.backdrop ? tile.backdrop.height : 1080
            asynchronous: true
            cache: true
        }
        Rectangle {
            anchors.fill: parent
            color: tile.tint.a > 0 ? tile.tint : tile.glass
            opacity: tile.tint.a > 0 ? 0.55 : (tile.current ? 0.22 : 0.12)
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: parent.height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#26ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }
    }

    Image {
        id: iconImage
        visible: tile.icon != "" && status === Image.Ready
        source: tile.icon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -12
        width: Math.min(parent.width * 0.62, sourceSize.width > 0 ? sourceSize.width : parent.width)
        height: parent.height * 0.56
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }

    Text {
        visible: !iconImage.visible
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -12
        width: parent.width - 24
        horizontalAlignment: Text.AlignHCenter
        text: tile.glyph !== "" ? tile.glyph : tile.title
        color: tile.ink
        font.pixelSize: tile.glyph !== "" ? 44 : 30
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
        width: parent.width - 20
        horizontalAlignment: Text.AlignHCenter
        visible: iconImage.visible || tile.glyph !== ""
        text: tile.title
        color: tile.ink
        opacity: 0.9
        font.pixelSize: 20
        elide: Text.ElideRight
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: "#55ffffff"
    }

    FocusRing { anchors.fill: parent; visible: tile.current; color: tile.accent; lifted: tile.lifted }
}
