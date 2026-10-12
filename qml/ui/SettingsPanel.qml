// The launcher's settings: a panel that drops in from the top with one tab per
// section. sections = [{title, items: [{label, hint, value, on, swatch, run}]}].
// Left/Right change the tab, Up/Down the setting, OK calls the setting's run().
import QtQuick 2.7

FocusScope {
    id: panel
    property Item backdrop
    property url blurSource
    property color accent: "#7dd3fc"
    property color ink: "white"
    property color panelColor: "#0b1220"    // the panel itself, and text on the accent colour
    property var sections: []
    property int tab: 0
    property bool shown: false
    property Item returnFocus
    readonly property var items: sections.length ? sections[Math.min(tab, sections.length - 1)].items : []

    anchors.fill: parent
    z: 40
    visible: shown || card.y > -card.height

    function open(back) {
        returnFocus = back || null;
        wanted = 0; tab = 0; shown = true;
        list.currentIndex = 0; list.forceActiveFocus();
    }
    function close() {
        shown = false;
        if (returnFocus) returnFocus.forceActiveFocus();
    }
    function setTab(t) {
        if (t < 0 || t >= sections.length || t === tab) return;
        wanted = 0; tab = t; list.currentIndex = 0;
    }

    // The list resets its position when a setting changes; keep the user's place.
    property int wanted: 0
    property bool restoring: false
    onItemsChanged: {
        restoring = true;
        Qt.callLater(function () {
            list.currentIndex = Math.max(0, Math.min(panel.wanted, panel.items.length - 1));
            panel.restoring = false;
        });
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: panel.shown ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
    }

    GlassCard {
        id: card
        backdrop: panel.backdrop; blurSource: panel.blurSource
        width: parent.width; height: 740
        y: panel.shown ? 0 : -height
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Rectangle { anchors.fill: parent; anchors.margins: -18; color: Qt.rgba(panel.panelColor.r, panel.panelColor.g, panel.panelColor.b, panel.blurSource == "" ? 0.96 : 0.72) }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: -18 } height: 4; color: panel.accent }

        Text { id: head; x: 78; y: 20; text: "Launcher settings"; color: panel.ink; font.pixelSize: 34; font.weight: Font.DemiBold }

        Row {
            id: tabs
            x: 78
            anchors { top: head.bottom; topMargin: 18 }
            spacing: 12
            Repeater {
                model: panel.sections
                Rectangle {
                    width: tabLabel.implicitWidth + 56; height: 56
                    color: index === panel.tab ? panel.accent : "#22ffffff"
                    Text { id: tabLabel; anchors.centerIn: parent; text: modelData.title; font.pixelSize: 26
                           color: index === panel.tab ? panel.panelColor : panel.ink }
                }
            }
        }

        ListView {
            id: list
            anchors { top: tabs.bottom; topMargin: 22; left: parent.left; right: parent.right; leftMargin: 78; rightMargin: 78
                      bottom: keys.top; bottomMargin: 16 }
            model: panel.items
            spacing: 8
            clip: true
            focus: true
            interactive: false
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            onCurrentIndexChanged: if (!panel.restoring) panel.wanted = currentIndex

            delegate: Rectangle {
                width: list.width; height: 84
                color: ListView.isCurrentItem ? "#38ffffff" : "#14ffffff"
                border.width: ListView.isCurrentItem ? 2 : 0
                border.color: panel.accent
                Text {
                    x: 28; width: 440
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label; color: panel.ink; font.pixelSize: 28; elide: Text.ElideRight
                }
                Text {
                    anchors { left: parent.left; leftMargin: 496; right: value.left; rightMargin: 28; verticalCenter: parent.verticalCenter }
                    text: modelData.hint || ""; color: panel.ink; opacity: 0.75; font.pixelSize: 22
                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                }
                Row {
                    id: value
                    anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                    spacing: 14
                    Rectangle {
                        visible: !!modelData.swatch
                        width: 32; height: 32; radius: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.swatch || "transparent"
                    }
                    Text {
                        width: Math.max(implicitWidth, 150)
                        horizontalAlignment: Text.AlignRight
                        text: modelData.value || ""; font.pixelSize: 26
                        font.weight: modelData.on === true ? Font.DemiBold : Font.Normal
                        color: modelData.on === true ? panel.accent : panel.ink
                        opacity: modelData.on === false ? 0.6 : 1
                    }
                }
            }

            Keys.onLeftPressed: panel.setTab(panel.tab - 1)
            Keys.onRightPressed: panel.setTab(panel.tab + 1)
            Keys.onReturnPressed: panel.run()
            Keys.onEnterPressed: panel.run()
        }

        Text {
            id: keys
            x: 78
            anchors { bottom: parent.bottom; bottomMargin: 6 }
            text: "Left / Right: section    Up / Down: setting    OK: change    Back: close"
            color: panel.ink; opacity: 0.6; font.pixelSize: 20
        }
    }

    function run() {
        var it = items[list.currentIndex];
        if (it && it.run) it.run();
    }
}
