// The USB headset route: the TV's sound sent to a USB headset by /var/lib/elgie-man/headset.sh
// (tv/headset.sh in the repo), run as root through the Homebrew Channel's exec. The script
// checks that a headset is plugged in, switches the sound output to Wired Headphones and pipes
// the TV's mix into the headset; "off" undoes it and puts the sound output back. The TV never
// does this itself. Nothing here polls: the status is read when Home is shown, and the TV's
// power state is a subscription so a resume from standby puts the sound back to normal.
import QtQuick 2.7

Item {
    id: headset
    property var luna
    property string script: "/var/lib/elgie-man/headset.sh"
    property bool present: false         // a USB audio device is plugged in
    property bool on: false              // the route is running
    property string soundOutput: ""
    property bool busy: false
    property bool available: true        // false once exec is found missing (no Homebrew Channel)
    signal message(string text)

    function exec(args, cb) {
        luna.call("org.webosbrew.hbchannel.service", "exec", {"command": script + " " + args}, function (ok, r) {
            // The script prints JSON either way; a failed step exits 1, which exec reports as
            // not ok with the JSON still in stdoutString.
            var s = null;
            try { s = JSON.parse((r && r.stdoutString) || ""); } catch (e) { s = null; }
            // No Homebrew Channel, or no script on this TV: the pill is not shown.
            if (!ok && r && /not exist|unknown service|not permitted|not found|No such file/i.test(String(r.errorText || "") + String(r.stderrString || "")))
                available = false;
            cb(!!s, s, r);
        });
    }
    function apply(s) { present = !!s.present; on = !!s.on; soundOutput = s.soundOutput || ""; }
    function refresh() { exec("status", function (ok, s) { if (ok) apply(s); }); }
    function toggle() {
        if (busy) return;
        busy = true;
        var want = !on;
        exec(want ? "on" : "off", function (ok, s, r) {
            busy = false;
            if (ok && s.error) { message("Headset: " + s.error); refresh(); return; }
            if (ok) { apply(s); message(s.message || (on ? "Headset on" : "Headset off")); refresh(); return; }
            var why = r ? (r.stderrString || r.stdoutString || r.errorText || "") : "";
            message(want ? "Headset: " + (String(why).trim() || "no reply from the TV") : "Headset: could not turn off");
            refresh();
        });
    }

    // A resume from standby puts the sound back to normal: "reset" is "off" when a route was on.
    // The sound output setting is a subscription too: when the script ends the route by itself
    // (headset switched off, dongle unplugged), or the output is changed in the TV's menu, the
    // settings service pushes the change and the pill is read again.
    property var powerSub: null
    property var outputSub: null
    property string powerState: ""
    function start() {
        if (powerSub) { luna.cancel(powerSub); powerSub = null; }
        if (outputSub) { luna.cancel(outputSub); outputSub = null; }
        outputSub = luna.call("com.webos.settingsservice", "getSystemSettings",
                              {"category": "sound", "keys": ["soundOutput"], "subscribe": true}, function (ok, r) {
            if (!ok || !r.settings) return;
            var out = r.settings.soundOutput || "";
            if (out !== soundOutput) { soundOutput = out; refresh(); }
        });
        powerState = "";
        powerSub = luna.call("com.webos.service.tvpower", "power/getPowerState", {"subscribe": true}, function (ok, r) {
            if (!ok || !r.state) return;
            var was = powerState;
            powerState = r.state;
            if (r.state === "Active" && was !== "" && was !== "Active" && was !== "Screen Off" && was !== "Screen Saver")
                exec("reset", function (ok2, s) { if (ok2) apply(s); });
        });
        refresh();
    }
}
