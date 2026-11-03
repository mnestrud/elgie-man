# Changelog

## Unreleased

- Launcher for LG CX (webOS 5.6.2): app, open-app, input and TV rows; edit mode (move and hide apps, hide inputs); Free up memory; Pause when Home opens (twice for apps that need it); launcher settings panel kept per TV.
- Boot hook for the CX with a snapshot of the launcher, a 45 s failsafe and a health check of inputs and sound output.
- LG C5 (webOS 25) support: Home's id run under `qml-runner`; boot hook with failsafe and fault-restart guard; uninstall script.
- Frame and dashboards split: `qml/Shell.qml` plus `qml/dashboards/<name>/`, with a written contract for new dashboards.
- Color schemes of the glass dashboard, `nord` and `gruvbox`, and a theme picker on the TV.
- `demo` config key: stand-in app names and no app icons, for screenshots.
- Pointer support: the tile or menu line under the remote's pointer takes the focus, a click is OK, the wheel steps along a row.
- C5: Home no longer comes back over the screensaver when the TV relaunches it as the last app.
- Bands flow like text: tiles fill each row across the width (eight on a 1080p screen), then the next row, as many rows as needed, in place of two fixed rows filled column by column that left the right of the screen empty. Moving a lifted tile is one reorder call for any distance, and the focus follows the moved tile.
- CX: `deploy.sh` over a running launcher left the old files mounted (the unmount was busy); it now detaches the mount lazily and reports whether the new files are mounted. The hook's failsafe unmounts the same way.
- CX hook: the start check waits up to 10 s for the ended Home process to be gone before it watches for the new one.
- The health check baseline is recorded at every install, not only the first.
- C5: the host keeps its event log in the settings file only with `debug` on; its app status subscription, which never delivered an update, is removed.
- `deploy.sh` installs only on the tested model and webOS pairs; `FORCE=1` overrides. The boot hooks do nothing on any other webOS version unless the install was forced.
- New look for the glass theme: rounded square tiles, all on one dark gray, with the app's name underneath, a bar at the top with the clock and the weather, a bottom bar with the remote's keys, a settings page with the sections down the left. The blurred background is no longer used.
- Apps flow across the width into rows, so fewer need scrolling to. A lifted tile moves one place with Left and Right and a row with Up and Down.
- The TV row is gone: LG's settings and edit mode are on the settings page; Free up memory is a button at the bottom, a recycling icon with the share of the memory for apps that is free, in place of the figure at the top (`showMemory` is no longer read). The share is LG's "usable" figure from `com.webos.memorymanager/getCurrentMemState` over the most it has reported on this TV (`memoryPeakMb` in the store).
- Weather from Home Assistant in the bar at the top (`weather` in `config.json`): the conditions now and three days of high, low and chance of rain.
- `lab/preview.sh` runs the launcher on the PC with made-up apps and takes screenshots.
- Hold OK on an app or input for its menu: Open, Force stop, Hide or Show, Move, Move to System apps. Edit mode opens the same menu.
- A System apps band under Apps (`systemApps`), filled from the menu, that folds away to its name (`systemAppsCollapsed`).
- The Running row is gone; an open app shows a clock badge on its tile instead, and the long press of Home lands on the first open app. `showRunning` is no longer read.
