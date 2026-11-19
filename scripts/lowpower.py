# Low-power graphics for World of Warplanes: apply for one launch, restore afterwards.
# Usage: lowpower.py apply|restore <preferences.xml> <backup.json>
import json, os, re, sys
# 0 = highest quality, bigger = lower.
LOW = {
    "BACKBUFER_QUALITY": 1,   # render quality: medium
    "SHADOWS_QUALITY": 4,     # off
    "TREES": 4,               # lowest
    "VOLUMETRICCLOUDS": 2,    # lowest
    "WATER_QUALITY": 3,       # lowest
    "POSTFX": 4,              # lowest
    "PARTICLES_QUALITY": 1,   # lowest
    "MOTIONBLUR": 3,          # off
    "OBJECT_CLIP": 2,         # draw distance: one step above shortest
    "OBJECT_LOD": 2,          # lowest
}
def pat(label):
    return re.compile(r"(<label>\s*" + re.escape(label) + r"\s*</label>\s*<activeOption>\s*)(-?\d+)(\s*</activeOption>)")
def read(p):
    return open(p, "rb").read().decode("latin-1")
def write(p, t):
    open(p + ".tmp", "wb").write(t.encode("latin-1")); os.replace(p + ".tmp", p)
cmd, prefs, backup = sys.argv[1:4]
text = read(prefs)
if cmd == "apply":
    saved = {}
    for label, low in LOW.items():
        m = pat(label).search(text)
        if m:
            saved[label] = int(m.group(2))
            text = pat(label).sub(lambda m: m.group(1) + str(low) + m.group(3), text, count=1)
    json.dump(saved, open(backup, "w"))
    write(prefs, text)
elif cmd == "restore" and os.path.exists(backup):
    for label, value in json.load(open(backup)).items():
        text = pat(label).sub(lambda m: m.group(1) + str(value) + m.group(3), text, count=1)
    write(prefs, text)
    os.remove(backup)
