"""Read NPC spawn points from QuestieDB's baked database (QuestieDB_Forever.toc).

QuestieDB stores each entity field as base64-encoded CBOR in the TOC's "## X-Npc-<id>-<field>"
metadata lines. Field 7 is spawns: { [zoneID] = { {x, y}, ... } } with x, y in percent of the
zone map. Unlike ForeverPath_ClassicDB (which keeps at most 10 points per NPC) these are complete,
so they show how big a mob's spawn area really is.
"""
import base64
import os
import re
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.dirname(os.path.dirname(HERE))
TOC = os.path.join(ADDONS, "QuestieDB", "QuestieDB_Forever.toc")


def cbor(data):
    """Minimal CBOR decoder (ints, floats, strings, arrays, maps); returns the first value."""
    pos = 0

    def item():
        nonlocal pos
        b = data[pos]
        pos += 1
        major, info = b >> 5, b & 31
        if major == 7:
            if info == 25:
                v = struct.unpack(">e", data[pos:pos + 2])[0]; pos += 2; return v
            if info == 26:
                v = struct.unpack(">f", data[pos:pos + 4])[0]; pos += 4; return v
            if info == 27:
                v = struct.unpack(">d", data[pos:pos + 8])[0]; pos += 8; return v
            return {20: False, 21: True, 22: None, 23: None}.get(info)
        if info < 24:
            n = info
        else:
            size = {24: 1, 25: 2, 26: 4, 27: 8}[info]
            n = int.from_bytes(data[pos:pos + size], "big"); pos += size
        if major == 0:
            return n
        if major == 1:
            return -1 - n
        if major in (2, 3):
            s = data[pos:pos + n]; pos += n
            return s.decode("utf-8", "replace") if major == 3 else s
        if major == 4:
            return [item() for _ in range(n)]
        if major == 5:
            d = {}
            for _ in range(n):
                k = item(); d[k] = item()
            return d
        if major == 6:
            return item()  # tag: ignore
        raise ValueError(f"CBOR major {major}")

    return item()


def load_spawns():
    """npcID -> { zoneID: [(x, y), ...] } for every NPC with spawn data."""
    out = {}
    meta = {}
    with open(TOC, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"^## X-Npc-(\d+)-7(-\d+)?: (\S+)", line)
            if m:
                meta[(int(m.group(1)), m.group(2))] = m.group(3)
    for (nid, part), value in meta.items():
        if part:
            continue
        m = re.match(r"^~(\d+)~$", value)
        if m:  # chunked: the value is split over "-7-1" ... "-7-n"
            value = "".join(meta.get((nid, f"-{i}"), "") for i in range(1, int(m.group(1)) + 1))
        try:
            v = cbor(base64.b64decode(value))
        except Exception:
            continue
        if isinstance(v, list):  # CBOR arrays for 1-based Lua tables keyed 1..n
            v = {i + 1: x for i, x in enumerate(v)}
        if not isinstance(v, dict):
            continue
        zones = {}
        for zone, pts in v.items():
            if isinstance(pts, dict):
                pts = list(pts.values())
            zones[zone] = [(p[0], p[1]) for p in pts if isinstance(p, (list, tuple)) and len(p) >= 2]
        out[nid] = zones
    return out


if __name__ == "__main__":
    s = load_spawns()
    print(len(s), "NPCs with spawns")
    for nid in (1130, 503, 1505, 565):
        print(nid, {z: len(p) for z, p in s.get(nid, {}).items()})
