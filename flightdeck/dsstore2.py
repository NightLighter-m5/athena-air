# Writes a Finder .DS_Store for a DMG window: layout, icon size, background.
# Usage: python3 dsstore.py <volume mount point> <bookmark file> <out .DS_Store>
import os, sys, struct, plistlib

vol, bookmark_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
volname = os.path.basename(vol)
bg_rel = ".background/background.tiff"
bg = os.path.join(vol, bg_rel)
MAC_EPOCH = 2082844800  # seconds between 1904-01-01 and 1970-01-01

# ---- legacy alias record (version 2) ----
def pstr(b, n):
    b = b[:n - 1]
    return bytes([len(b)]) + b + b"\0" * (n - 1 - len(b))

def make_alias():
    st_vol, st_dir, st_file = os.stat(vol), os.stat(os.path.dirname(bg)), os.stat(bg)
    voldate = int(st_vol.st_birthtime) + MAC_EPOCH
    crdate = int(st_file.st_birthtime) + MAC_EPOCH
    vname = volname.encode("mac_roman", "replace").replace(b":", b"/")
    fname = b"background.tiff"
    body = struct.pack(">h", 0)                       # kind: file
    body += pstr(vname, 28) + struct.pack(">I", voldate)
    body += b"H+" + struct.pack(">h", 5)              # fs type, ejectable disk
    body += struct.pack(">I", st_dir.st_ino)          # parent folder CNID
    body += pstr(fname, 64) + struct.pack(">II", st_file.st_ino, crdate)
    body += b"\0\0\0\0" * 2                           # type, creator
    body += struct.pack(">hhIH", -1, -1, 0, 0) + b"\0" * 10
    def tag(t, data):
        r = struct.pack(">hH", t, len(data)) + data
        return r + (b"\0" if len(data) & 1 else b"")
    body += tag(0, b".background")
    body += struct.pack(">hHQhHQ", 16, 8, voldate * 65536, 17, 8, crdate * 65536)
    body += tag(1, struct.pack(">I", st_dir.st_ino))
    body += tag(2, vname + b":.background:" + fname)
    u = "background.tiff".encode("utf-16-be"); body += tag(14, struct.pack(">H", len(u) // 2) + u)
    u = volname.encode("utf-16-be");          body += tag(15, struct.pack(">H", len(u) // 2) + u)
    body += tag(18, ("/" + bg_rel).encode())
    body += tag(19, vol.encode())
    body += struct.pack(">hH", -1, 0)
    head = b"\0\0\0\0" + struct.pack(">hh", 6 + 2 + len(body), 2)
    return head + body

# ---- records ----
def rec(name, code, typ, data):
    u = name.encode("utf-16-be")
    r = struct.pack(">I", len(u) // 2) + u + code + typ
    if typ == b"blob": r += struct.pack(">I", len(data)) + data
    elif typ == b"long": r += struct.pack(">I", data)
    elif typ == b"bool": r += bytes([1 if data else 0])
    return (name.lower(), code, r)

def iloc(x, y):
    return struct.pack(">II", x, y) + b"\xff\xff\xff\xff\xff\xff\x00\x00"

bwsp = plistlib.dumps({
    "ContainerShowSidebar": False, "ShowPathbar": False, "ShowSidebar": False,
    "ShowStatusBar": False, "ShowTabView": False, "ShowToolbar": False,
    "SidebarWidth": 0, "WindowBounds": "{{200, 100}, {660, 498}}",
}, fmt=plistlib.FMT_BINARY)
icvp = plistlib.dumps({
    "arrangeBy": "none", "backgroundColorBlue": 1.0, "backgroundColorGreen": 1.0,
    "backgroundColorRed": 1.0, "backgroundImageAlias": make_alias(), "backgroundType": 2,
    "gridOffsetX": 0.0, "gridOffsetY": 0.0, "gridSpacing": 100.0, "iconSize": 96.0,
    "labelOnBottom": True, "showIconPreview": True, "showItemInfo": False,
    "textSize": 13.0, "viewOptionsVersion": 1,
}, fmt=plistlib.FMT_BINARY)

records = [
    rec(".", b"bwsp", b"blob", bwsp),
    rec(".", b"icvp", b"blob", icvp),
    # (no pBBk bookmark: it would embed the build path)
    rec(".", b"vSrn", b"long", 1),
    rec("Applications", b"Iloc", b"blob", iloc(490, 190)),
    rec("Pilot's Manual.html", b"Iloc", b"blob", iloc(410, 375)),
    rec("Flight Deck.app", b"Iloc", b"blob", iloc(250, 375)),
    rec("World of Warplanes.app", b"Iloc", b"blob", iloc(170, 190)),
]
records.sort(key=lambda r: (r[0], r[1]))

# ---- buddy allocator layout ----
NODE_OFF, NODE_LOG = 8192, 13          # leaf node block (8 KB)
ROOT_OFF, ROOT_LOG = 2048, 11          # allocator info block
DSDB_OFF, DSDB_LOG = 32, 5             # B-tree header block

node = struct.pack(">II", 0, len(records)) + b"".join(r[2] for r in records)
assert len(node) <= (1 << NODE_LOG), "records don't fit in one node"
dsdb = struct.pack(">IIIII", 2, 0, len(records), 1, 0x1000)

offsets = [ROOT_OFF | ROOT_LOG, DSDB_OFF | DSDB_LOG, NODE_OFF | NODE_LOG]
root = struct.pack(">II", len(offsets), 0)
root += b"".join(struct.pack(">I", o) for o in offsets) + b"\0" * 4 * (256 - len(offsets))
root += struct.pack(">I", 1) + bytes([4]) + b"DSDB" + struct.pack(">I", 1)
free = {i: [] for i in range(32)}
for i, o in [(6, 64), (7, 128), (8, 256), (9, 512), (10, 1024), (12, 4096)] + [(i, 1 << i) for i in range(14, 31)]:
    free[i].append(o)
for i in range(32):
    root += struct.pack(">I", len(free[i])) + b"".join(struct.pack(">I", o) for o in free[i])
assert len(root) <= (1 << ROOT_LOG)

size = NODE_OFF + (1 << NODE_LOG)
buf = bytearray(size)
buf[0:36] = struct.pack(">4sIII16s", b"Bud1", ROOT_OFF, 1 << ROOT_LOG, ROOT_OFF, b"\0" * 16)
buf[DSDB_OFF:DSDB_OFF + len(dsdb)] = dsdb
buf[ROOT_OFF:ROOT_OFF + len(root)] = root
buf[NODE_OFF:NODE_OFF + len(node)] = node
open(out, "wb").write(struct.pack(">I", 1) + bytes(buf))
print("wrote", out, len(records), "records")
