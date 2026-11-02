// Remote hints: hints = [["OK", "Open"], ["Back", "Close"]]. Each key is drawn as a key cap.
import QtQuick 2.7

Row {
    id: bar
    property var hints: []
    property color ink: "white"
    property color glass: "white"
    spacing: 28
    Repeater {
        model: bar.hints
        Row {
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(44, cap.implicitWidth + 18); height: 32; radius: 8
                color: Qt.rgba(bar.glass.r, bar.glass.g, bar.glass.b, 0.1)
                border.width: 1; border.color: Qt.rgba(bar.glass.r, bar.glass.g, bar.glass.b, 0.35)
                Text { id: cap; anchors.centerIn: parent; text: modelData[0]; color: bar.ink; opacity: 0.85; font.pixelSize: 17; font.weight: Font.DemiBold }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: bar.ink; opacity: 0.7; font.pixelSize: 21 }
        }
    }
}
