#!/bin/bash
# Keeps World of Warplanes' window/fullscreen size matched to the current main display,
# so switching between the laptop screen and an external monitor never causes
# "Unable to set appropriate display mode". Run by prelaunch.sh before each game launch.
# Usage: display-sync.sh <preferences.xml>
PREFS="$1"
LOG="$(cd "$(dirname "$0")" && pwd)/display-sync.log"
[ -f "$PREFS" ] || exit 0
pgrep -f 'WorldOfWarplanes\.exe' >/dev/null && exit 0   # never edit while the game is open

# Size of the main display in points ("looks like" resolution)
SIZE=$(/usr/bin/osascript -l JavaScript -e 'ObjC.import("AppKit"); var f=$.NSScreen.screens.objectAtIndex(0).frame; Math.round(f.size.width)+" "+Math.round(f.size.height)' 2>/dev/null)
read -r W H <<<"$SIZE"
[[ "$W" =~ ^[0-9]+$ && "$H" =~ ^[0-9]+$ && "$W" -gt 0 ]] || exit 0

/usr/bin/python3 -I - "$PREFS" "$W" "$H" "$LOG" <<'PY'
import os, re, sys, time
prefs, w, h, log = sys.argv[1:5]
text = open(prefs, "rb").read().decode("latin-1")
want = {"windowedWidth": w, "windowedHeight": h, "fullscreenWidth": w, "fullscreenHeight": h,
        "windowedPosX": "0", "windowedPosY": "0"}
changed = []
for key, val in want.items():
    pat = re.compile(r"(<" + key + r">\s*)(-?\d+)(\s*</" + key + r">)")
    m = pat.search(text)
    if m and m.group(2) != val:
        changed.append("%s %s->%s" % (key, m.group(2), val))
        text = pat.sub(lambda m: m.group(1) + val + m.group(3), text, count=1)
if changed:
    open(prefs + ".tmp", "wb").write(text.encode("latin-1"))
    os.replace(prefs + ".tmp", prefs)
    with open(log, "a") as f:
        f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + "display %sx%s: " % (w, h) + ", ".join(changed) + "\n")
PY
