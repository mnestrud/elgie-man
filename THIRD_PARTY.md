# Third-party material

## Shipped in this repo

Every file here was written for this project and is under Apache-2.0 (`LICENSE`). Three sets of colour values come from published palettes:

| Source | Licence | Used for |
|---|---|---|
| Nord (nordtheme.com) | MIT | The colour values in `qml/dashboards/nord/Dashboard.qml`. |
| Gruvbox (github.com/morhetz/gruvbox) | MIT | The colour values in `qml/dashboards/gruvbox/Dashboard.qml`. |
| Tailwind CSS (tailwindcss.com) | MIT | The default accent colour, the six accent choices and the two colours of the plain background in `qml/dashboards/glass/Dashboard.qml`, and the same values where other files repeat them. |

## Read, not copied

| Source | Licence | Used for |
|---|---|---|
| webOS OSE, `webosose/qml-webos-framework` (`tools/runner/`, `src/common/webosquickwindow.cpp`) | Apache-2.0 | How `qml-runner` handles launch, relaunch and close. Recorded as behaviour in `docs/contract-c5.md`. |
| Qt documentation (QtQuick 2.7, Qt.labs.settings) | GFDL | The QML language and types. |
| LG's software on the TVs it was tested on | proprietary | Observed to learn names and behaviour only (`docs/contract-cx.md`, `docs/contract-c5.md`). |

## Used on the TV at run time, never shipped

- Qt and its QML modules, including LG's `WebOSServices`, `WebOS.Global` and `Eos.Window` modules.
- LG's Home program (CX) and `qml-runner` (C5), which load the launcher.
- `luna-send`, `node` and busybox tools, called by the boot hooks.
- Fonts already installed on the TV.
- App names and icons, read from the TV's own list of installed apps when Home is drawn.
