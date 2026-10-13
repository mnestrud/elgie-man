# C5 (webOS 10.3.1, "webOS 25") Home contract

Observed on an LG C5 from 2026-10-09 to 2026-10-13. Names and behaviour only.

## How Home is found

- The compositor's key filter sends Home, long-press Home and Menu to sam as `launchDefaultApp {category: "home", params: {activateType: "home" | "myapps", launchType: "homeKey"}}`. If a Home window is already in front, the key goes to that window instead.
- sam resolves the `home` category from settings `general.defaultApps.home` if present, otherwise from its built-in default (`com.webos.app.home`). `setDefaultApp {category, appId}` writes that key; there is no getter.

## Re-reading a system app's manifest without restarting sam

- `blockSystemApp {id}` followed by `releaseBlockSystemApp {id}` makes sam drop and re-read the app's `appinfo.json`.
- The block is recorded in `/var/preferences/com.webos.applicationManager/blockedSystemAppList/<country>.json`, and the release removes it again (byte-identical file afterwards).
- Blocking Home does not stop the running Home process; it must be ended separately, and preload-manager relaunches it under the new manifest.
- Keep the block→release window short: a reboot in between would leave the app blocked.

## Home under qml-runner

- A manifest override with `type: "qml"` and `main: "main.qml"` (all other keys kept) runs Home as `qml-runner` with Home's app id.
- Under that id, luna calls from QML (`WebOSServices.Service`, `appId: "com.webos.app.home"`) work:
  - sam `listLaunchPoints`, `running`, `launch`, `closeByAppId`, `getAppInfo`, `getForegroundAppInfo`, `moveLaunchPoint` (`getAppLifeStatus` accepts the subscription; see "`getAppLifeStatus` in QML" below);
  - eim `getAllInputStatus`;
  - networkinput `controls/pause`;
  - homelaunchpoints `listLaunchPoints`, `moveLaunchPoint`, `hideLaunchPoint`, `unhideLaunchPoint`. `unhideLaunchPoint` re-appends the tile at the end.
- sam's `moveLaunchPoint {launchPointId, position}` changes the order, and both sam's list and the homelaunchpoints list show it.
- The root is `Eos.Window`'s `WebOSWindow` with `windowType: "_WEBOS_WINDOW_TYPE_HOME"`. Home is an overlay: the app under it stays the foreground app.
- Memory: about 32 MB PSS with the full launcher, against 57–63 MB for the stock Flutter Home.

## Launch, show and hide (confirmed on the C5, 2026-10-11)

- **Launch message.** The runner's first argument is sam's launch message. Its `reason` is `preload` for a hidden preload, `boot` for the launch at power-on and `undefined` for an ordinary launch. QML reads it from `Qt.application.arguments`. The launch parameters are the context property `params` (an object).
- **First load.** The runner does not show a `Window` root. A launch that is not a preload has to show itself.
- **Relaunch (Home, long-press Home, Menu).** The runner replaces `params` with `{activateType: "home" | "myapps", launchType: "homeKey"}` and calls `showFullScreen()`. A binding on `params` signals on every relaunch, including one with the same values. Long-press Home sends `home`, not `recent`.
- **A window that has never been shown** still gets its first relaunch.
- **Hidden by the TV.** When another app or input comes forward the compositor takes Home's window off the screen. The window only loses `active`; `visible` stays true, and a later `showFullScreen()` from the runner then does nothing. The host hides the window itself when it loses `active`.
- **Back.** By default the compositor closes Home's window on Back and the key never reaches QML. Setting `windowProperties["_WEBOS_ACCESS_POLICY_KEYS_BACK"] = "true"` delivers Back to the window. `windowProperties` is a property map: assign to its keys, not to the property. There is no `setWindowProperty` method. `keyMask` does not change this.
- **Other keys.** A key pressed while Home's window has focus goes to Home only; the key mask does not pass playback keys to the app underneath.
- **Pause before Home.** The Pause from networkinput goes to the focused window. The runner shows Home's window at once on a relaunch, so the host takes the window off the screen again until the Pause call has returned, then shows it. Without that the key can land on Home.
- **Default Home app.** `launchDefaultApp {category: "home"}` fails with "no default app is set for the category" when `general.defaultApps.home` names an app that is not installed. `setDefaultApp {category: "home", appId: "com.webos.app.home"}` repairs it.
- **In standby after a restart** no Home process exists; sam launches Home at power-on with `reason: "boot"`.
- **When the foreground app's process ends** and Home was in front, sam launches Home itself as the last app (`reason: "undefined"`, empty parameters).
- **Idle.** After two minutes without a key the compositor closes Home's window (`closeWindow`, reason `windowPolicy`). An input under Home stays in front (seen with Live TV; not checked with an app). With nothing under it, sam launches the last app one second later: Home on the first two such launches, then the last input (seen once).
- **Screensaver.** tvpower launches `com.webos.app.screensaver` after three idle minutes when Home is the only app in front. The compositor closes Home's window, and sam then launches Home as the last app (empty parameters). A Home window shown at that point makes the compositor close the screensaver, so the host stays hidden on a launch without `launchType: "homeKey"` while the screensaver is up. It is not the app in the plain `getForegroundAppInfo` reply and no `getAppLifeStatus` update for it reached QML; `getForegroundAppInfo` with `extraInfo: true` lists it. After Back ended it, the last input was in front (seen once).
- **`getAppLifeStatus` in QML.** An update for Home arrived on the service's failure signal (seen once, 2026-10-13). `Luna.qml` drops a call that fails, so the host's status subscription ends there.

## Things that harm the TV

- **`ls-monitor` must not be run.** It makes the bus hub open a socket per service and overflow its 1024 file handles. The TV records a kernel fault and restarts at its next suspend (`rebootByFault`).

## Apps with their own id

- A dev-installed QML app gets only the `public` permission group, and qml-runner's role does not let it register its own bus name, so it cannot make luna calls at all.
- Such an app can still be made the default Home and gets the Home window type and key routing.

## qml-runner relaunch contract (webOS OSE source, compared with the C5's runner)

Source: webosose/qml-webos-framework, `tools/runner/` and `src/common/webosquickwindow.cpp` (Apache-2.0). The C5's runner was compared by its exported names and call order.

- Same on the C5: a relaunch replaces the context property `params` and calls `showFullScreen()`; a relaunch is dropped if the window has no native handle ("Got relaunch on closing"); `pause` is ignored; `close` quits the process; only `relaunch` and `close` are handled.
- Different on the C5: it subscribes with `registerNativeApp`; it does not set a `launchParams` window property; the window type has no `setWindowProperty` method.
- The host therefore: starts with `visible: false`, sets `keepAlive: true`, hides and never closes, reads the launch reason from the process arguments, and follows `params` and `active`.
