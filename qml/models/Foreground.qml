// The app in front on the TV, and the last one that was not Home.
import QtQuick 2.7

Item {
    id: foreground
    property var luna
    property string appId: ""          // "" when nothing is in front
    property string lastApp: ""        // what to go back to when Home is dismissed
    property string lastInput: ""      // the last external input that was in front
    property var sub: null

    function isInput(id) { return /^com\.webos\.app\.(hdmi|externalinput)/.test(id); }

    function start() {
        if (sub) { luna.cancel(sub); sub = null; }    // restartable: a restored snapshot has dead subscriptions
        sub = luna.call("com.webos.applicationManager", "getForegroundAppInfo", {"subscribe": true}, function (ok, r) {
            if (!ok) return;
            appId = r.appId || "";
            if (appId && appId !== luna.appId) lastApp = appId;
            if (isInput(appId)) lastInput = appId;
        });
    }
}
