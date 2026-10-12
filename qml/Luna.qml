// Luna bus access for the launcher. Every call runs under Home's app id, so it keeps
// Home's service permissions. Swap this file for a mock to run the UI off the TV.
import QtQuick 2.7

Item {
    id: luna
    property string appId: "com.webos.app.home"

    // call(service, method, params, cb): one-shot call; cb(ok, response).
    // With params.subscribe = true, cb fires on every update and the returned
    // object stays alive; pass it to cancel() to end the subscription.
    function call(service, method, params, cb) {
        var svc;
        try {
            svc = Qt.createQmlObject('import WebOSServices 1.0; Service {}', luna, "luna");
        } catch (e) {
            console.warn("[elgie] luna unavailable: " + e);
            if (cb) cb(false, {errorText: String(e)});
            return null;
        }
        var keep = params && params.subscribe === true;
        svc.appId = appId;
        svc.service = service;
        svc.method = method;
        svc.callSuccess.connect(function (r) { if (cb) cb(true, r); if (!keep) svc.destroy(); });
        svc.callFailure.connect(function (r) { if (cb) cb(false, r); svc.destroy(); });
        svc.error.connect(function (code, text) {
            if (cb) cb(false, {errorCode: code, errorText: text});
            svc.destroy();
        });
        svc.callService(params || {});
        return svc;
    }

    function cancel(handle) {
        if (handle) { try { handle.cancel(); } catch (e) {} handle.destroy(); }
    }

    function launch(id, params) {
        call("com.webos.applicationManager", "launch", {"id": id, "params": params || {}}, function (ok, r) {
            if (!ok) console.warn("[elgie] launch " + id + " failed: " + JSON.stringify(r));
        });
    }
}
