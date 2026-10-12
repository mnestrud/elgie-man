// A small dashboard to copy: the time and one row of app names. Left/Right move,
// OK opens the app, Back closes Home. It uses nothing but QtQuick and the "tv"
// object (qml/dashboards/README.md).
import QtQuick 2.7

FocusScope {
    id: board
    property var tv

    // Called each time Home is shown.
    function activate(params) { list.currentIndex = 0; list.forceActiveFocus(); }

    Rectangle { anchors.fill: parent; color: "#0f172a"; opacity: 0.92 }

    Text {
        x: 96; y: 72
        color: "white"; font.pixelSize: 72; font.weight: Font.Light
        text: Qt.formatTime(board.tv.now, "h:mm")
    }

    ListView {
        id: list
        x: 96; y: 420
        width: parent.width - 96; height: 200
        orientation: ListView.Horizontal
        spacing: 24
        focus: true
        model: board.tv.apps.shown
        highlightMoveDuration: 120
        delegate: Rectangle {
            width: 320; height: 180
            color: ListView.isCurrentItem ? "#7dd3fc" : "#22ffffff"
            Text {
                anchors { fill: parent; margins: 20 }
                verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: parent.ListView.isCurrentItem ? "#0b1220" : "white"; font.pixelSize: 30
                text: modelData.title
            }
        }
        Keys.onReturnPressed: open()
        Keys.onEnterPressed: open()
        function open() {
            var app = board.tv.apps.shown[currentIndex];
            if (app) board.tv.launch(app.id, app.params);
        }
    }
}
