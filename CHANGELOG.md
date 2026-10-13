# Changelog

## Unreleased

- Launcher for LG CX (webOS 5.6.2): app, open-app, input and TV rows; edit mode (move and hide apps, hide inputs); Free up memory; Pause when Home opens (twice for apps that need it); launcher settings panel kept per TV.
- Boot hook for the CX with a snapshot of the launcher, a 45 s failsafe and a health check of inputs and sound output.
- LG C5 (webOS 25) support: Home's id run under `qml-runner`; boot hook with failsafe and fault-restart guard; uninstall script.
- Frame and dashboards split: `qml/Shell.qml` plus `qml/dashboards/<name>/`, with a written contract for new dashboards.
- Colour schemes of the glass dashboard, `nord` and `gruvbox`, and a theme picker on the TV.
- `demo` config key: stand-in app names and no app icons, for screenshots.
- Pointer support: the tile or menu line under the remote's pointer takes the focus, a click is OK, the wheel steps along a row.
- C5: Home no longer comes back over the screensaver when the TV relaunches it as the last app.
- CX hook: the start check waits up to 10 s for the ended Home process to be gone before it watches for the new one.
- The health check baseline is recorded at every install, not only the first.
- C5: the host keeps its event log in the settings file only with `debug` on; its app status subscription, which never delivered an update, is removed.
- `deploy.sh` installs only on the tested model and webOS pairs; `FORCE=1` overrides. The boot hooks do nothing on any other webOS version unless the install was forced.
