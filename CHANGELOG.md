# Changelog

## Unreleased

- Launcher for LG CX (webOS 5.6.2): app, open-app, input and TV rows; edit mode (move and hide apps, hide inputs); Free up memory; Pause when Home opens (twice for apps that need it); launcher settings panel kept per TV.
- Boot hook for the CX with a snapshot of the launcher, a 45 s failsafe and a health check of inputs and sound output.
- LG C5 (webOS 25) support: Home's id run under `qml-runner`; boot hook with failsafe and fault-restart guard; uninstall script.
- Frame and dashboards split: `qml/Shell.qml` plus `qml/dashboards/<name>/`, with a written contract for new dashboards.
- Colour schemes of the glass dashboard, `nord` and `gruvbox`, and a theme picker on the TV.
- `demo` config key: stand-in app names and no icons in the Apps row, for screenshots.
- `deploy.sh` installs only on the tested model and webOS pairs; `FORCE=1` overrides. The boot hooks do nothing on any other webOS version unless the install was forced.
