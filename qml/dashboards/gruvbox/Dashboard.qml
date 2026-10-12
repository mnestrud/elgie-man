// The glass dashboard in the Gruvbox dark colours: warm browns with a cream text
// and bright accents. Colour values from the Gruvbox palette (MIT licence; see
// THIRD_PARTY.md).
import QtQuick 2.7
import "../glass" as Glass

Glass.Dashboard {
    palette: ({
        top: "#282828", bottom: "#504945", panel: "#1d2021", ink: "#ebdbb2", glass: "#fabd2f",
        accents: [
            {name: "Yellow", color: "#fabd2f"}, {name: "Orange", color: "#fe8019"}, {name: "Aqua", color: "#8ec07c"},
            {name: "Green", color: "#b8bb26"}, {name: "Blue", color: "#83a598"}, {name: "Purple", color: "#d3869b"}
        ]
    })
}
