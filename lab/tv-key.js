// Injects a key press into an evdev device on the TV: node tv-key.js <code> [holdMs] [device]
// Writes press, SYN, (hold), release, SYN as 32-bit ARM struct input_event records.
var fs = require('fs');
var code = parseInt(process.argv[2], 10);
var hold = parseInt(process.argv[3] || '80', 10);
var dev = process.argv[4] || '/dev/input/event1';
function ev(type, c, value) {
  var b = Buffer.alloc(16), now = Date.now();
  b.writeInt32LE(Math.floor(now / 1000), 0);
  b.writeInt32LE((now % 1000) * 1000, 4);
  b.writeUInt16LE(type, 8); b.writeUInt16LE(c, 10); b.writeInt32LE(value, 12);
  return b;
}
var fd = fs.openSync(dev, 'w');
fs.writeSync(fd, Buffer.concat([ev(1, code, 1), ev(0, 0, 0)]));
setTimeout(function () {
  fs.writeSync(fd, Buffer.concat([ev(1, code, 0), ev(0, 0, 0)]));
  fs.closeSync(fd);
  console.log('key ' + code + ' held ' + hold + 'ms on ' + dev);
}, hold);
