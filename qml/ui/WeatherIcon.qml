// A Home Assistant weather condition as an icon. Some conditions are two glyphs: a
// cloud with a small sun, drop or flake beside it.
import QtQuick 2.7

Item {
    id: wi
    property string condition: ""
    property int size: 48
    property color color: "white"

    readonly property var table: ({
        "clear-night": ["nights_stay", ""],
        "cloudy": ["cloud", ""],
        "exceptional": ["storm", ""],
        "fog": ["foggy", ""],
        "hail": ["cloud", "grain"],
        "lightning": ["flash_on", ""],
        "lightning-rainy": ["thunderstorm", ""],
        "partlycloudy": ["cloud", "wb_sunny"],
        "pouring": ["cloud", "water_drop"],
        "rainy": ["cloud", "water_drop"],
        "snowy": ["cloud", "ac_unit"],
        "snowy-rainy": ["cloud", "ac_unit"],
        "sunny": ["wb_sunny", ""],
        "windy": ["air", ""],
        "windy-variant": ["air", ""]
    })
    readonly property var pair: table[condition] || ["cloud", ""]
    // The sun peeks out above the cloud; a drop or flake hangs under it.
    readonly property bool sunBadge: pair[1] === "wb_sunny"

    width: size; height: size

    Icon {
        name: wi.pair[0]; color: wi.color
        size: wi.pair[1] ? Math.round(wi.size * 0.8) : wi.size
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: wi.pair[1] ? (wi.sunBadge ? -wi.size * 0.06 : 0) : 0
        anchors.verticalCenterOffset: wi.pair[1] ? (wi.sunBadge ? wi.size * 0.08 : -wi.size * 0.1) : 0
    }
    Icon {
        visible: wi.pair[1] !== ""
        name: wi.pair[1]; color: wi.color
        size: Math.round(wi.size * 0.42)
        x: wi.sunBadge ? wi.size - width : wi.size - width - wi.size * 0.1
        y: wi.sunBadge ? 0 : wi.size - height
    }
}
