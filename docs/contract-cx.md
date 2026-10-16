# CX (webOS 5.6.2) Home host contract

Observed on an LG CX on 2026-10-09. This file covers names and behavior only.

## Loading

- Home's native binary loads `qml/main.qml` from its app folder into a view. A bind mount over that `qml/` folder replaces the UI.
- Home is a snapshot (CRIU) app, listed in `CRIUSupportApps` in `/etc/palm/sam-conf-tv.json`. That file is on the read-only system image and is read once when sam starts; there is no API or configd key for it.
- On each start, sam asks libcriu for the app's image:
  - It looks in `/tmp/checkpoint/<app>`, which is refreshed from the stored copy `/mnt/lg/cmn_data/checkpoint/<app>` after an MD5 check.
  - If an image exists and `/tmp/criu_enable` is present, the app is restored from it: LG's UI comes back and our folder is ignored.
  - If there is no image in either place, the app starts fresh, and sam snapshots the fresh process about 0.25 s later. Later starts restore that snapshot.
- So the launcher hides LG's stored image behind its own folder (a bind mount, nothing written to LG's copy) and removes the temp copy. It starts fresh once; the snapshot the TV then takes is restored on every later start, including after reboots.
- A restore does not need the saved process id: if it is taken, the image is restored under a new id (seen with a forced and a natural collision; no fault).
- A `launch` of Home from a shell is not treated as a hidden preload, even with `launchHidden` and `preload`: the window becomes visible and no `relaunch` is sent. Only preload-manager's own launch is hidden.
- A reboot while in Active Standby comes back in Active Standby, where the Home key is ignored and preload-manager does not relaunch Home.
- If no Home process exists when the TV is turned on from Active Standby, the TV launches Home about 9 s after the power key. That launch is not a preload (`appLaunched` has no preload marker), so Home shows itself on `registered`.
- The snapshot is taken after the QML has loaded and before `appLaunched` is called. `appLaunched(params, true)` is called after every restore. Nothing may connect to the bus at load time: such a connection is dead after a restore, and calls on it are denied.
- Removing `/tmp/criu_enable` instead switches restore off for every app (fallback).
- Home is `keepAlive`. If the process exits, preload-manager relaunches it about 8 s later, but not while the TV is in Active Standby. `closeByAppId` on Home does not stop the process.

## Root object

The root is a `FocusScope`, 1920×1080, with these members.

- Properties: `appId` (the binary sets it to `com.webos.app.home`), `videoSize`, `cursorVisible`, `active`.
- Signals the binary listens to:
  - `showWindow()`, `hideWindow()`, `invokeExit()`;
  - `printLog(var)`, `printLS(var)`, `enableLog()`, `setDebugLevel(string)`;
  - `appClosing()`, `activateWindow(var)`, `setWindowProperty(var, var)`;
  - `createCache()`, `clearCache()`, `changeCacheDirectory(var)`, `saveCache(var, var, var)`.
- Functions the binary calls:
  - `appLaunched(params, restored)`: the launch message as JSON text, and whether the process came back from a snapshot;
  - `windowIsVisible()`, `windowIsInvisible()`;
  - `focusIn()`, `focusOut()`;
  - `remoteCursorOn()`, `remoteCursorOff()`;
  - `cacheDirectoryChanged(url)`, `keyPressEvent(keyCode)`.

## Call order on a fresh start

1. `appLaunched(params, false)`. On a preload, `params` has `reason: "preload"` and `preload: "full"`. The CRIU boot launch has `parameters.snapshot: true`.
2. `remoteCursorOff()`.
3. The UI subscribes to `com.webos.applicationManager/registerApp {subscribe: true}` and receives `registered` (no parameters).

## Lifecycle events (registerApp subscription)

| Event | When | Required response |
|---|---|---|
| `registered` | after subscribing | show only if `appLaunched` was not a preload |
| `relaunch`, `parameters.launchType: "homeKey"` | Home key | `showWindow()` |
| `relaunch`, `parameters.activateType: "recent"` | Home key held | `showWindow()` and focus the running row |
| `pause`, `reason: "keepAlive"` | another app launched, or `closeByAppId` on Home | `hideWindow()`. The compositor does not hide Home cleanly by itself, and Home won't re-show later if this is skipped. |

- No `close` event was seen.
- Showing triggers `windowIsVisible()` then `focusIn()`; hiding triggers `windowIsInvisible()` then `focusOut()`.

## Window type and what plays under Home

- Home's manifest makes it an overlay (`defaultWindowType: home`). An overlay is not the foreground app: the app under it stays in front and keeps playing, picture and sound.
- `setWindowProperty("_WEBOS_WINDOW_TYPE", "_WEBOS_WINDOW_TYPE_CARD")` before `showWindow()` makes Home an ordinary full-screen app. It becomes the foreground app, and the app it covers gets `background` and releases its media pipelines, as in any app switch.
- As a card, Home behaves differently:
  - No `pause` arrives when another app is launched over it. The window stays shown behind that app, and the next Home key does not raise it unless Home has hidden itself. Home watches `getForegroundAppInfo` and calls `hideWindow()` when another app is in front.
  - The Home key while Home is in front arrives as `relaunch` (`launchType: homeKey`) as well.
  - Powering off sends `pause`.
  - Hiding the window does not bring anything else to the front. To dismiss, launch the app to go back to; Home hides when it is in front.
  - That launch must wait for the Back key's release. If the release lands on the app just brought forward, the surface manager launches Home again (`relaunch` with no parameters).
- `applicationManager/pause {id}` is not a substitute: the app stops playing but stays the foreground app, and YouTube did not recover on relaunch.
- `com.webos.audio/setMuted` does not mute the TV. `com.webos.service.apiadapter/audio/setMute {mute}` does, and shows the mute icon for as long as it is set.

## Keys

- Keys arrive as both `keyPressEvent(code)` and QML `Keys` events.
- Back is `WebOS.Key_webOS_Back` (`0x1200003`), and the UI hides itself on it.
- While Home is in the foreground, the Home key arrives only as a key event (`Qt.Key_Super_L`), with no `relaunch`.

## Services available under Home's identity

All of these were verified from QML via `WebOSServices.Service`:

- `listLaunchPoints`, `running`, `launch`, `closeByAppId`;
- `setOrder {type: "custom", order: [launchPointId…]}`. **`{type: "default"}` resets the user's order.**
- `moveLaunchPoint {launchPointId, position}`;
- `com.webos.service.eim/getAllInputStatus` (`devices[].label/connected/appId`).

XHR can:

- read `file:///proc/meminfo` and root-only files;
- HTTP requests by IP work from QML. Hostnames from the LAN do not resolve on the TV.

`Qt.labs.settings` with no organization set persists to `/home/root/.config/Unknown Organization/com.webos.app.home.conf`.

## Pausing an app from outside

`luna://com.webos.service.networkinput/controls/pause` and `/controls/play` send the remote's discrete Pause and Play to the app in front. On YouTube TV, pause sent repeatedly never resumes and play sent repeatedly never pauses. `com.webos.media/pause` on the app's pipeline is refused (the pipeline is unmanaged).

YouTube TV reloads when it has been in the background (another card app in front, the Home Dashboard, or TV power-off, which puts the last input in front) and is opened again: it returns to the point where that viewing was joined or last seeked, not where it stopped. The stock Home bar and Recents are overlays and do not background it.

Checked on: YouTube TV, YouTube, Netflix, Apple TV and Peacock pause and stay paused. Paramount+ takes the first Pause only to show its player bar and pauses on a second one, so the launcher sends two to the apps in config `pauseTwiceApps`. With config `pauseOnHome` (default on) the launcher sends pause when Home is opened over an app and shows its window after the reply; it never sends play.
