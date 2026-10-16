// The glass dashboard in the Nord colors: cool blue-greys with frost accents.
// Color values from the Nord palette (MIT license; see THIRD_PARTY.md).
import QtQuick 2.7
import "../glass" as Glass

Glass.Dashboard {
    palette: ({
        top: "#2e3440", bottom: "#434c5e", panel: "#2e3440", ink: "#eceff4", glass: "#88c0d0",
        accents: [
            {name: "Frost", color: "#88c0d0"}, {name: "Teal", color: "#8fbcbb"}, {name: "Blue", color: "#81a1c1"},
            {name: "Green", color: "#a3be8c"}, {name: "Yellow", color: "#ebcb8b"}, {name: "Purple", color: "#b48ead"}
        ]
    })
}
