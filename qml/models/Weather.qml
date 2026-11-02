// Weather from Home Assistant: the current conditions of one weather entity and the
// first three days of its daily forecast. config.weather = {url, token, entity}; the
// url is an address, not a name, because the TVs do not resolve hostnames. The frame
// calls refreshIfStale() when Home is shown and refresh() every 15 minutes while it is.
import QtQuick 2.7

Item {
    id: weather
    property var config: ({})
    property bool shown: false           // Home is on screen (the frame binds tv.shown)
    readonly property bool configured: !!(config && config.url && config.token && config.entity)
    // The C5 shows Home before config.json has been read: fetch as soon as both are there.
    onConfiguredChanged: if (configured && shown) refreshIfStale()
    property bool ready: false
    property string condition: ""        // Home Assistant's condition word: sunny, rainy, partlycloudy ...
    property string temperature: ""      // rounded, without the unit
    property string unit: ""             // "°F" or "°C"
    property string apparent: ""
    property string humidity: ""
    property string windSpeed: ""
    property string windUnit: ""
    property var forecast: []            // [{day, condition, high, low, chance, amount}], today first
    property double updatedAt: 0
    property string error: ""

    function stale() { return !ready || Date.now() - updatedAt > 10 * 60 * 1000; }
    function refreshIfStale() { if (configured && stale()) refresh(); }

    function num(v) { return v === undefined || v === null || isNaN(v) ? "" : String(Math.round(v)); }

    // "2026-11-02T12:00:00+00:00" as a Date; the TVs' JS parses no offsets.
    function parseIso(s) {
        var m = /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(?:\.\d+)?(Z|[+-]\d\d:?\d\d)?/.exec(String(s));
        if (!m) return new Date(s);
        var t = Date.UTC(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +m[6]);
        if (m[7] && m[7] !== "Z") {
            var o = /([+-])(\d\d):?(\d\d)/.exec(m[7]);
            t -= (o[1] === "-" ? -1 : 1) * (o[2] * 60 + +o[3]) * 60000;
        }
        return new Date(t);
    }

    function request(method, path, body, cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status !== 200) { cb(false, "HTTP " + x.status); return; }
            var r;
            try { r = JSON.parse(x.responseText); } catch (e) { cb(false, String(e)); return; }
            cb(true, r);
        };
        x.open(method, String(config.url).replace(/\/+$/, "") + path);
        x.setRequestHeader("Authorization", "Bearer " + config.token);
        x.setRequestHeader("Content-Type", "application/json");
        x.send(body ? JSON.stringify(body) : null);
    }

    function refresh() {
        if (!configured) return;
        request("GET", "/api/states/" + config.entity, null, function (ok, r) {
            if (!ok) { error = String(r); console.warn("[elgie] weather state: " + r); return; }
            var a = r.attributes || {};
            condition = r.state || "";
            temperature = num(a.temperature);
            unit = a.temperature_unit || "";
            apparent = num(a.apparent_temperature);
            humidity = num(a.humidity);
            windSpeed = num(a.wind_speed);
            windUnit = a.wind_speed_unit || "";
            error = "";
            ready = true;
            updatedAt = Date.now();
        });
        request("POST", "/api/services/weather/get_forecasts?return_response",
                {"entity_id": config.entity, "type": "daily"}, function (ok, r) {
            if (!ok) { console.warn("[elgie] weather forecast: " + r); return; }
            var e = r.service_response && r.service_response[config.entity];
            var list = (e && e.forecast) || [], f = [], today = new Date();
            for (var i = 0; i < list.length && f.length < 3; i++) {
                var d = parseIso(list[i].datetime), p = list[i].precipitation_probability;
                var sameDay = d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate();
                if (d < today && !sameDay) continue;
                f.push({day: sameDay ? "Today" : Qt.formatDate(d, "ddd"),
                        condition: list[i].condition || "",
                        high: num(list[i].temperature), low: num(list[i].templow),
                        chance: p === undefined || p === null ? "" : Math.round(p) + "%",
                        amount: list[i].precipitation === undefined ? "" : String(list[i].precipitation)});
            }
            forecast = f;
        });
    }
}
