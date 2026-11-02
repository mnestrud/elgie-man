// A Material icon by name, drawn from the font in ui/fonts/ (Apache-2.0; THIRD_PARTY.md).
// Codepoints rather than ligatures, so the glyph comes out the same on every TV.
import QtQuick 2.7

Text {
    id: icon
    property string name: ""
    property int size: 32
    readonly property var glyphs: ({
        "settings": "\ue8b8", "tune": "\ue429", "edit": "\ue3c9", "recycling": "\ue760", "memory": "\ue322",
        "settings_input_hdmi": "\ue8c2", "input": "\ue890", "tv": "\ue333", "cable": "\uefe6", "cast": "\ue307",
        "apps": "\ue5c3", "home": "\ue88a", "play_circle": "\ue1c4", "history": "\ue889", "schedule": "\ue8b5",
        "check": "\ue5ca", "chevron_right": "\ue5cc", "keyboard_return": "\ue31b", "palette": "\ue40a",
        "visibility_off": "\ue8f5", "restart_alt": "\uf053", "wallpaper": "\ue1bc", "opacity": "\ue91c",
        "videogame_asset": "\ue338", "desktop_windows": "\ue30c", "speaker": "\ue32d", "volume_up": "\ue050",
        "wb_sunny": "\ue430", "nights_stay": "\uea46", "cloud": "\ue2bd", "wb_cloudy": "\ue42d", "foggy": "\ue818",
        "grain": "\ue3ea", "flash_on": "\ue3e7", "thunderstorm": "\uebdb", "water_drop": "\ue798", "ac_unit": "\ueb3b",
        "air": "\uefd8", "storm": "\uf070", "umbrella": "\uf1ad", "dehaze": "\ue3c7",
        "expand_more": "\ue5cf", "expand_less": "\ue5ce", "stop_circle": "\uef71", "visibility": "\ue8f4",
        "drive_file_move": "\ue675", "swap_horiz": "\ue8d4"
    })
    FontLoader { id: iconFont; source: Qt.resolvedUrl("fonts/MaterialIcons-Regular.ttf") }

    text: glyphs[name] || ""
    font.family: iconFont.name
    font.pixelSize: size
    color: "white"
    width: size; height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
