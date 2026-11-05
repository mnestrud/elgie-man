// A pill button: an icon, a label and an optional trailing figure. Filled with the
// accent color while it has the focus; tinted with it while "active" (a switch that is on).
import QtQuick 2.7

Rectangle {
    id: pill
    property string icon: ""
    property string text: ""
    property string trailing: ""
    property bool current: false
    property bool active: false
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color glass: "white"
    property color panel: "#0b1220"     // text on the accent color
    readonly property color fg: current ? panel : ink
    signal clicked()
    signal hovered()

    height: 56
    radius: height / 2
    width: row.width + (icon !== "" ? 44 : 56)
    color: current ? accent : active ? Qt.rgba(accent.r, accent.g, accent.b, 0.3) : Qt.rgba(glass.r, glass.g, glass.b, 0.14)
    border.width: current ? 0 : 1
    border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.8) : Qt.rgba(glass.r, glass.g, glass.b, 0.2)
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Icon { visible: pill.icon !== ""; name: pill.icon; size: 28; color: pill.fg; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: pill.text; color: pill.fg
            font.pixelSize: 23; font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: pill.trailing !== ""
            text: "·  " + pill.trailing; color: pill.fg
            opacity: pill.current ? 0.8 : 0.7
            font.pixelSize: 23
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: if (!pressed) pill.hovered(); onClicked: pill.clicked() }
}
