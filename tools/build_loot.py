"""Build Loot.lua: per-farm sellable loot with item IDs and expected amounts per hour.

Usage:
    python tools/build_loot.py

Reads tools/farm_specs.py, tools/farms_seed.json, pools.csv and other addons' databases
(see classicdb.py). Every item name must resolve to a tradeable item in the WoW Forever client
tables, so item IDs are never typed by hand. The addon prices these items live from your
Auctionator scans.
"""
import csv
import json
import os
import re
import sys

from classicdb import ClassicDB
from farm_specs import FARMS, FISH_BY_POOL

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
OUT = os.path.join(ADDON, "Loot.lua")

CLASSES = {"Warrior": "WARRIOR", "Paladin": "PALADIN", "Hunter": "HUNTER", "Rogue": "ROGUE", "Priest": "PRIEST",
           "Shaman": "SHAMAN", "Mage": "MAGE", "Warlock": "WARLOCK", "Druid": "DRUID"}


def lua(v, ind=0):
    pad = "  " * ind
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else repr(round(v, 3))
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(lua(x) for x in v) + " }"
        return "{\n" + "".join(pad + "  " + lua(x, ind + 1) + ",\n" for x in v) + pad + "}"
    if isinstance(v, dict):
        parts = [(k if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", k) else "[" + lua(k) + "]", x)
                 for k, x in v.items() if x is not None and x != [] and x != ""]
        if not parts:
            return "{}"
        inline = all(not isinstance(x, dict) and (not isinstance(x, list) or all(not isinstance(y, (dict, list)) for y in x))
                     for _, x in parts) and len(parts) <= 8
        if inline:
            return "{ " + ", ".join(f"{k} = {lua(x)}" for k, x in parts) + " }"
        return "{\n" + "".join(f"{pad}  {k} = {lua(x, ind + 1)},\n" for k, x in parts) + pad + "}"
    raise TypeError(type(v))


def main():
    db = ClassicDB()
    seed = {(f["bracket"], f["name"]): f for f in json.load(open(os.path.join(HERE, "farms_seed.json"), encoding="utf-8"))}
    pools = list(csv.DictReader(open(os.path.join(ADDON, "pools.csv"), encoding="utf-8-sig")))

    errors, out, report = [], {}, []

    def resolve(name, farm):
        it = db.item(name)
        if not it:
            errors.append(f"{farm}: item not found: {name}")
            return None
        if it.get("src") != "client" or it["bind"] not in (0, 2):
            errors.append(f"{farm}: not tradeable on the AH: {name} ({it['id']}, bind {it['bind']}, {it.get('src')})")
            return None
        return it

    for spec in FARMS:
        key = (spec["bracket"], spec["name"])
        label = f"{spec['bracket']} {spec['name']}"
        if key not in seed:
            errors.append(f"{label}: no farm with this bracket/name in farms_seed.json")
            continue
        rec = {"difficulty": spec.get("diff") or (1 if spec.get("fishing") else None), "kph": spec.get("kph"),
               "profReq": [p.lower() for p in spec.get("prof", [])],
               "profOpt": [p.lower() for p in spec.get("opt", [])],
               "howTo": spec.get("how"), "notes": spec.get("notes")}
        if spec.get("class_"):
            rec["classText"] = spec["class_"]
            rec["classes"] = [CLASSES[spec["class_"]]]
        items, n_db, n_est = [], 0, 0

        mobs = spec.get("mobs", [])
        rec["mobs"] = mobs
        npcs = [db.npcs[i] for m in mobs for i in db.npc_ids(m)]
        for m in mobs:
            if not db.npc_ids(m):
                errors.append(f"{label}: mob not found: {m}")
        if npcs:
            mp, pts = db.spawn_points([n["id"] for n in npcs])
            if mp and mp > 0:
                rec["map"] = {"id": mp, "zone": db.zones.get(mp), "points": [c for pt in pts[:15] for c in pt]}
            lo, hi = min(n["min"] for n in npcs), max(n["max"] for n in npcs)
            rec["mobLevels"] = f"{lo}-{hi}" if lo != hi else str(lo)
            if any(n["rank"] in (1, 2) for n in npcs):
                rec["elite"] = True

        for spec_item in spec.get("items", []):
            it = resolve(spec_item["name"], label)
            if not it:
                continue
            pct, src = None, "est"
            if not spec_item.get("skin"):
                pct, found = db.drop_pct(it["id"], mobs)
                if pct is not None:
                    src = "db"
            if pct is None:
                pct = spec_item["est"]
            n_db += src == "db"
            n_est += src == "est"
            per_hour = spec["kph"] * pct / 100.0 * spec_item.get("qty", 1)
            items.append({"id": it["id"], "name": it["name"], "quality": it["quality"], "chance": round(pct, 2),
                          "perHour": round(per_hour, 2), "src": src, "prof": (spec_item.get("prof") or "").lower() or None})

        fishing = spec.get("fishing")
        if fishing:
            rows = [r for r in pools if r["tier"] == fishing["tier"]]
            share = fishing["pools_per_hour"] / len(rows)
            static, pool_list = 0.0, []
            for r in rows:
                static += share * (float(r["container_value_g"]) + float(r["other_value_g"]))
                fish = FISH_BY_POOL.get(r["pool"])
                if fish and float(r["avg_fish"]) > 0:
                    it = resolve(fish, label)
                    if it:
                        items.append({"id": it["id"], "name": it["name"], "quality": it["quality"],
                                      "perHour": round(share * float(r["avg_fish"]), 2), "src": "pools", "prof": "fishing"})
                pool_list.append({"name": r["pool"], "value": float(r["pool_value_g"])})
            for ex in fishing.get("extra", []):
                it = resolve(ex["name"], label)
                if it:
                    items.append({"id": it["id"], "name": it["name"], "quality": it["quality"],
                                  "perHour": fishing["extra_per_hour"], "src": "est", "prof": "fishing"})
                    n_est += 1
            rec["staticGold"] = round(static, 3)  # containers + other catch, gold per hour (pools.csv)
            rec["staticGoldLabel"] = f"{rows[0]['container']}s and other catch (pools.csv estimate)"
            rec["pools"] = pool_list
            rec["kph"] = None
            rec["poolsPerHour"] = fishing["pools_per_hour"]
            n_db += 1

        # merge duplicate items (e.g. Light Leather from drops and skinning)
        merged = {}
        for x in items:
            k = (x["id"], x.get("prof"))
            if k in merged:
                merged[k]["perHour"] = round(merged[k]["perHour"] + x["perHour"], 2)
            else:
                merged[k] = x
        rec["items"] = sorted(merged.values(), key=lambda x: (x.get("prof") is not None, -x["perHour"]))
        rec["mainItem"] = rec["items"][0]["id"] if rec["items"] else None
        out[f"{spec['bracket']}|{spec['name']}"] = rec
        report.append(f"{label[:60]:60} items {len(rec['items']):2}  db {n_db:2}  est {n_est:2}")

    missing = [f"{b} {n}" for (b, n) in seed if f"{b}|{n}" not in out]
    for m in missing:
        errors.append(f"no spec for farm: {m}")

    print("\n".join(report))
    if errors:
        print("\nERRORS:\n  " + "\n  ".join(errors))
        sys.exit(1)

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Generated by tools/build_loot.py from tools/farm_specs.py. Do not edit by hand.\n")
        f.write("-- Item IDs come from the WoW Forever client tables (via ForeverPath); drop rates from\n")
        f.write("-- CMaNGOS classic-db and Wowhead (via ForeverPath_ClassicDB and QuestieDB) where available.\n")
        f.write("local _, ns = ...\n")
        f.write("ns.loot = " + lua(out) + "\n")
    print(f"\nWrote {OUT}: {len(out)} farms")


if __name__ == "__main__":
    main()
