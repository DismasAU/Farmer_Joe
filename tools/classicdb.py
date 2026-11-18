"""Read item, NPC and drop data from other installed addons' generated databases.

Sources (all under Interface/AddOns):
  ForeverPath/Data/ItemIndex.lua           items from the WoW Forever client: name, quality, bind, class
  ForeverPath/Data/RecipeCatalogue.lua     crafting reagents from the same client extract (cloth, leather, meat...)
  ForeverPath_ClassicDB/Npcs.lua           NPC names, levels, elite rank (CMaNGOS classic-db)
  ForeverPath_ClassicDB/Loot.lua           drops[item] = top-5 sources with chances (CMaNGOS classic-db)
  QuestieDB/support/Forever/DropTables/classicItemDrops.lua
                                           Wowhead drop percentages per NPC for ~2000 items
"""
import os
import re
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.dirname(os.path.dirname(HERE))

ITEM_FILE = os.path.join(ADDONS, "ForeverPath", "Data", "ItemIndex.lua")
RECIPE_FILE = os.path.join(ADDONS, "ForeverPath", "Data", "RecipeCatalogue.lua")
NPC_FILE = os.path.join(ADDONS, "ForeverPath_ClassicDB", "Npcs.lua")
LOOT_FILE = os.path.join(ADDONS, "ForeverPath_ClassicDB", "Loot.lua")
MAPS_FILE = os.path.join(ADDONS, "ForeverPath_ClassicDB", "Maps.lua")
WOWHEAD_FILE = os.path.join(ADDONS, "QuestieDB", "support", "Forever", "DropTables", "classicItemDrops.lua")


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def _unescape(s):
    return s.replace('\\"', '"').replace("\\\\", "\\")


class ClassicDB:
    def __init__(self):
        self.items = {}            # id -> dict(name, quality, bind, cls, sub)
        self.items_by_name = defaultdict(list)
        self.npcs = {}             # id -> dict(name, min, max, rank)
        self.npcs_by_name = defaultdict(list)
        self.drops = defaultdict(dict)   # item -> {npc: pct}   (merged, wowhead preferred)
        self.npc_loot = defaultdict(dict)  # npc -> {item: pct}
        self._load_items()
        self._load_npcs()
        self._load_drops()
        self._load_maps()

    def _load_maps(self):
        text = _read(MAPS_FILE)
        self.zones, self.instances = {}, {}
        for table, target in (("zones", self.zones), ("instances", self.instances)):
            block = re.search(r"FP\.ClassicData\." + table + r" = \{(.*?)\n\}", text, re.S)
            if block:
                for m in re.finditer(r'\[(-?\d+)\]="((?:[^"\\]|\\.)*)"', block.group(1)):
                    target[int(m.group(1))] = _unescape(m.group(2))

    def spawn_points(self, nids):
        """Main map for a set of NPCs: (uiMapID, [(x, y), ...] in 0.1% units). uiMapID < 0 = instance.

        Zone maps overlap at their edges, so a point within 10% of a map's edge usually belongs to
        the neighbouring zone; interior points are counted when there are any."""
        spawns = [s for nid in nids for s in self.npcs[nid]["spawns"]]
        if not spawns:
            return None, []
        interior = [s for s in spawns if s[0] < 0 or (100 <= s[1] <= 900 and 100 <= s[2] <= 900)]
        spawns = interior or spawns
        counts = defaultdict(int)
        for mp, _, _ in spawns:
            counts[mp] += 1
        mp = max(counts, key=counts.get)
        pts = [(x, y) for m2, x, y in spawns if m2 == mp]
        return mp, pts

    def npc_location(self, nid):
        """(zone or instance name, x, y, is_instance) at the median spawn point of the main map."""
        mp, pts = self.spawn_points([nid])
        if mp is None:
            return None, None, None, False
        if mp < 0:
            return self.instances.get(-mp), None, None, True
        x = sorted(p[0] for p in pts)[len(pts) // 2]
        y = sorted(p[1] for p in pts)[len(pts) // 2]
        return self.zones.get(mp), round(x / 10), round(y / 10), False

    # ------------------------------------------------------------ loaders
    def _add_item(self, iid, name, quality=1, bind=0, cls=None, sub=None, source=""):
        if iid in self.items:
            return
        self.items[iid] = {"id": iid, "name": name, "quality": quality, "bind": bind, "cls": cls, "sub": sub, "src": source}
        self.items_by_name[name.lower()].append(iid)

    def _load_items(self):
        # client item tables: { name, quality, bind, classID, subclassID, ... }
        rx = re.compile(r'^\s*\[(\d+)\] = \{ "((?:[^"\\]|\\.)*)", (\d+), (\d+), (\d+), (\d+)(?:, [^}]*)? \},\s*$', re.M)
        for path in (ITEM_FILE, RECIPE_FILE):
            for m in rx.finditer(_read(path)):
                self._add_item(int(m.group(1)), _unescape(m.group(2)), int(m.group(3)), int(m.group(4)),
                               int(m.group(5)), int(m.group(6)), "client")
        # fallback: names from the Wowhead drop table comments (bind unknown -> assume tradeable)
        for m in re.finditer(r"^\s*\[(\d+)\] = \{ -- (.+?)\s*$", _read(WOWHEAD_FILE), re.M):
            self._add_item(int(m.group(1)), m.group(2), source="wowhead")

    def _load_npcs(self):
        rx = re.compile(r'^\[(\d+)\]=\{"((?:[^"\\]|\\.)*)",(?:nil|"(?:[^"\\]|\\.)*"),(\d+),(\d+),\d+,(.*)\},?\s*$', re.M)
        for m in rx.finditer(_read(NPC_FILE)):
            nid = int(m.group(1))
            tail = m.group(5)
            # tail: {spawns},side[,rank]
            rank, side, spawns = 0, None, []
            t = re.search(r"\}(?:,(\w+))?(?:,(\d+))?$", tail)
            if t and t.group(2):
                rank = int(t.group(2))
            if t and t.group(1) and t.group(1) != "nil":
                side = int(t.group(1))
            s = re.match(r"\{([-\d,]*)\}", tail)
            if s and s.group(1):
                nums = [int(x) for x in s.group(1).split(",") if x]
                spawns = [tuple(nums[i:i + 3]) for i in range(0, len(nums) - 2, 3)]
            n = {"id": nid, "name": _unescape(m.group(2)), "min": int(m.group(3)), "max": int(m.group(4)),
                 "rank": rank, "side": side, "spawns": spawns}
            self.npcs[nid] = n
            self.npcs_by_name[n["name"].lower()].append(nid)

    def _load_drops(self):
        # CMaNGOS: chances in 1/100 of a percent; negative = quest-only
        for m in re.finditer(r"^\[(\d+)\]=\{([-\d,]+)\},?\s*$", _read(LOOT_FILE), re.M):
            item = int(m.group(1))
            nums = [int(x) for x in m.group(2).split(",") if x]
            for i in range(1, len(nums) - 1, 2):
                npc, ch = nums[i], nums[i + 1]
                if ch > 0:
                    self.drops[item][npc] = ch / 100.0
        # Wowhead (percent) overrides when present
        text = _read(WOWHEAD_FILE)
        for block in re.finditer(r"\[(\d+)\] = \{ --[^\n]*\n(.*?)\n\s*\},", text, re.S):
            item = int(block.group(1))
            for nm in re.finditer(r"\[(\d+)\] = ([\d.]+),", block.group(2)):
                self.drops[item][int(nm.group(1))] = float(nm.group(2))
        for item, srcs in self.drops.items():
            for npc, pct in srcs.items():
                self.npc_loot[npc][item] = pct

    # ------------------------------------------------------------ queries
    def item(self, name):
        """Exact (case-insensitive) item name -> item dict, preferring tradeable entries."""
        ids = self.items_by_name.get(name.lower(), [])
        if not ids:
            return None
        ids = sorted(ids, key=lambda i: (self.items[i]["bind"] in (1, 4), i))
        return self.items[ids[0]]

    def npc_ids(self, name):
        return self.npcs_by_name.get(name.lower(), [])

    def drop_pct(self, item_id, npc_names):
        """Average drop % of item across the named mobs (only mobs with data). Returns (pct, n_found)."""
        vals = []
        for nm in npc_names:
            best = None
            for nid in self.npc_ids(nm):
                p = self.drops.get(item_id, {}).get(nid)
                if p is not None:
                    best = p if best is None else max(best, p)
            if best is not None:
                vals.append(best)
        if not vals:
            return None, 0
        return sum(vals) / len(vals), len(vals)

    def tradeable(self, item_id):
        it = self.items.get(item_id)
        return bool(it) and it["bind"] in (0, 2)
