"""Shared rules for how many kills an hour a farm gets and which drops are random world drops.

Kills per hour
  A solo player keeps up roughly 100 kills an hour where there are plenty of spawns, but a small
  camp runs dry: each spawn point comes back every five minutes or so, and with travel you get
  about five kills an hour out of each one. So:
      kills/hour = 5 x spawn points, rounded to 5, between 10 and 100
  Elites take about twice as long to kill, so they're capped at 50.
  Spawn points are counted from QuestieDB (complete lists), falling back to ForeverPath_ClassicDB
  (at most 10 per NPC) when QuestieDB has none.

World-drop gear
  Green-or-better weapons and armour that drop from many different mobs at low rates are random
  world drops. In the game a mob makes one roll for these and gets at most one, so the per-item
  rates (often small-sample Wowhead numbers) must not be added up per kill.
"""

KILLS_PER_SPAWN = 5
MAX_KPH = 100
MAX_KPH_ELITE = 50
MIN_KPH = 10

WORLD_SOURCES = 6      # dropped by this many mobs or more ...
WORLD_MAX_PCT = 3.0    # ... or never above this rate anywhere: a world drop, not a mob's own item


def spawn_count(db, nids, spawns):
    total = 0
    for nid in nids:
        q = spawns.get(nid)
        n = sum(len(p) for p in q.values()) if q else 0
        if n == 0 and nid in db.npcs:
            n = len(db.npcs[nid]["spawns"])
        total += n
    return total


def kills_per_hour(db, nids, spawns, elite=None):
    n = spawn_count(db, nids, spawns)
    if elite is None:
        elite = any(db.npcs[i]["rank"] == 1 for i in nids if i in db.npcs)
    kph = int(round(n * KILLS_PER_SPAWN / 5.0)) * 5
    kph = max(MIN_KPH, min(MAX_KPH_ELITE if elite else MAX_KPH, kph))
    return kph


def world_drop_gear(db, iid):
    it = db.items.get(iid)
    if not it or it["quality"] < 2 or it.get("cls") not in (2, 4):
        return False
    srcs = db.drops.get(iid, {})
    if not srcs:
        return False
    return len(srcs) >= WORLD_SOURCES or max(srcs.values()) < WORLD_MAX_PCT
