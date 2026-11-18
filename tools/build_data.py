"""Regenerate Farmer Joe's Data.lua from the farm research files.

Usage:
    python tools/build_data.py [input_dir]

input_dir defaults to the addon folder. It looks for:
    farms.json  (or farms.csv)          -- required for full data
    containers.json (or containers.csv) -- optional, fished container loot tables
    pools.csv                           -- optional, fishing pool values
If no farms file is found it falls back to tools/farms_seed.json (names/ranks only).

Run this after build.py -> update.py -> fish.py have refreshed the source files.
"""
import csv
import datetime
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON_DIR = os.path.dirname(HERE)
OUT = os.path.join(ADDON_DIR, "Data.lua")

BRACKETS = ["1-5", "6-10", "11-15", "16-20", "21-25", "26-30",
            "31-35", "36-40", "41-45", "46-50", "51-55", "56-60"]

CLASSES = {
    "warrior": "WARRIOR", "paladin": "PALADIN", "hunter": "HUNTER", "rogue": "ROGUE",
    "priest": "PRIEST", "shaman": "SHAMAN", "mage": "MAGE", "warlock": "WARLOCK",
    "druid": "DRUID",
}

PROFESSIONS = ["alchemy", "blacksmithing", "enchanting", "engineering", "herbalism",
               "leatherworking", "mining", "skinning", "tailoring", "fishing",
               "cooking", "first aid", "lockpicking"]


# ---------------------------------------------------------------- helpers
def norm_key(k):
    return re.sub(r"[^a-z0-9]+", "_", str(k).strip().lower()).strip("_")


def normalise_row(row):
    return {norm_key(k): v for k, v in row.items()}


def pick(row, *names):
    for n in names:
        v = row.get(n)
        if v is not None and not (isinstance(v, str) and v.strip() == ""):
            return v
    return None


def num(v):
    """Parse 12, '12', '12.5g', '-45%', '1,200' -> float; None if not numeric."""
    if v is None:
        return None
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return None if (isinstance(v, float) and math.isnan(v)) else float(v)
    m = re.search(r"-?\d[\d,]*\.?\d*", str(v))
    if not m:
        return None
    return float(m.group(0).replace(",", ""))


def pct(v):
    """7-day change as a percentage number (-45 means down 45%)."""
    if v is None:
        return None
    f = num(v)
    if f is None:
        return None
    if isinstance(v, str) and "%" in v:
        return f
    if -1 <= f <= 1:  # stored as a fraction
        return f * 100
    return f


def split_professions(v):
    if v is None:
        return [], "all"
    if isinstance(v, list):
        items, mode = [str(x) for x in v], "all"
    else:
        s = str(v)
        mode = "any" if re.search(r"\bor\b", s, re.I) else "all"
        items = re.split(r"[,;/+&|]|\band\b|\bor\b", s, flags=re.I)
    out = []
    for it in items:
        t = it.strip().lower()
        t = re.sub(r"\(.*?\)", "", t).strip()
        if not t or t in ("none", "-", "n/a", "no", "any"):
            continue
        for p in PROFESSIONS:
            if p in t and p not in out:
                out.append(p)
    return out, mode


def parse_classes(v):
    if v is None:
        return []
    s = " ".join(v) if isinstance(v, list) else str(v)
    s = s.lower()
    if s.strip() in ("", "any", "all", "none", "-"):
        return []
    return [tok for name, tok in CLASSES.items() if re.search(r"\b" + name + r"\b", s)]


def flag_text(v):
    s = str(v or "").lower()
    return ("thin" in s), ("crash" in s)


def bracket_index(b):
    try:
        return BRACKETS.index(str(b).strip())
    except ValueError:
        return 999


# ---------------------------------------------------------------- loaders
def load_rows(path):
    if path.endswith(".json"):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            for key in ("farms", "containers", "data", "rows", "items"):
                if isinstance(data.get(key), list):
                    data = data[key]
                    break
            else:
                # dict keyed by name
                data = [dict(v, name=k) if isinstance(v, dict) else {"name": k, "value": v}
                        for k, v in data.items()]
        return data
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def find(input_dir, *names):
    for n in names:
        p = os.path.join(input_dir, n)
        if os.path.exists(p):
            return p
    return None


def build_farm(raw):
    r = normalise_row(raw)
    low = num(pick(r, "gold_per_hour_low", "gph_low", "gold_hr_low"))
    high = num(pick(r, "gold_per_hour_high", "gph_high", "gold_hr_high"))
    diff = num(pick(r, "difficulty"))
    req, req_mode = split_professions(pick(r, "professions_required", "profession_required"))
    opt, _ = split_professions(pick(r, "professions_optional", "profession_optional"))
    listed = num(pick(r, "listed_qty", "listed", "listed_quantity", "main_item_listed", "qty_listed"))
    change = pct(pick(r, "main_item_7d_change", "7d_change", "change_7d"))
    thin, crashing = flag_text(pick(r, "thin_crashing_flag", "flag", "flags", "liquidity_flag"))
    if listed is not None and listed < 100:
        thin = True
    if change is not None and change <= -40:
        crashing = True

    score = None
    if (low is not None or high is not None) and diff:
        mid = ((low or 0) + (high or 0)) / 2  # "up to X" -> X/2
        score = round(mid / diff, 2)
    given_score = num(pick(r, "score"))
    if score is None and given_score is not None:
        score = given_score

    farm = {
        "bracket": str(pick(r, "bracket") or "").strip(),
        "givenRank": num(pick(r, "rank")),
        "name": pick(r, "name", "farm"),
        "zone": pick(r, "zone"),
        "mobLevels": pick(r, "mob_levels", "mob_level"),
        "difficulty": int(diff) if diff else None,
        "profReq": req,
        "profReqMode": req_mode,
        "profOpt": opt,
        "classes": parse_classes(pick(r, "class", "classes")),
        "classText": pick(r, "class", "classes"),
        "gphLow": low,
        "gphHigh": high,
        "score": score,
        "method": pick(r, "gold_per_hour_method"),
        "sourceType": pick(r, "gold_source_type"),
        "sourceUrl": pick(r, "gold_source_url"),
        "howTo": pick(r, "how_to", "howto"),
        "notes": pick(r, "notes"),
        "priceSource": pick(r, "price_source"),
        "priceTime": pick(r, "price_snapshot_time"),
        "volume": num(pick(r, "main_item_daily_volume", "daily_volume")),
        "change7d": change,
        "listed": listed,
        "thin": thin,
        "crashing": crashing,
        "itemId": num(pick(r, "main_item_id", "item_id", "itemid")),
        "itemName": pick(r, "main_item", "main_item_name"),
        "container": pick(r, "container_name", "container"),
        "containerEV": num(pick(r, "container_ev")),
        "containerChance": pct(pick(r, "container_chance")),
        "containersPerHour": num(pick(r, "containers_per_hour")),
    }
    if farm["itemId"] is not None:
        farm["itemId"] = int(farm["itemId"])
    return farm


def rank_farms(farms):
    """Score desc; unscored last, easiest first; ties fall back to the source rank."""
    def key(f):
        has = f["score"] is not None
        return (bracket_index(f["bracket"]),
                0 if has else 1,
                -(f["score"] or 0),
                f["difficulty"] if f["difficulty"] is not None else 99,
                f["givenRank"] if f["givenRank"] is not None else 99)
    farms.sort(key=key)
    counter = {}
    for f in farms:
        counter[f["bracket"]] = counter.get(f["bracket"], 0) + 1
        f["rank"] = counter[f["bracket"]]
        del f["givenRank"]
    return farms


def build_containers(rows):
    """Accepts either one row per container (with an items list) or one row per drop."""
    out = {}
    for raw in rows:
        r = normalise_row(raw)
        cname = pick(r, "container_name", "container", "name")
        if not cname:
            continue
        c = out.setdefault(cname, {"items": []})
        ev = num(pick(r, "container_ev", "ev", "expected_value", "expected_value_g"))
        if ev is not None:
            c["ev"] = ev
        items = r.get("items") or r.get("loot")
        if isinstance(items, list):
            for it in items:
                it = normalise_row(it)
                c["items"].append(drop_entry(it))
        elif pick(r, "item_id", "itemid", "item_name", "item"):
            c["items"].append(drop_entry(r))
    for c in out.values():
        c["items"] = [i for i in c["items"] if i.get("id") or i.get("name")]
    return out


def drop_entry(r):
    qty = pick(r, "qty", "quantity", "avg_qty")
    q = num(qty)
    qmax = None
    if isinstance(qty, str):
        m = re.match(r"\s*(\d+)\s*-\s*(\d+)", qty)
        if m:
            q, qmax = float(m.group(1)), float(m.group(2))
    entry = {
        "id": int(num(pick(r, "item_id", "itemid", "id")) or 0) or None,
        "name": pick(r, "item_name", "item", "name"),
        "chance": pct(pick(r, "drop_pct", "drop", "drop_rate", "chance", "drop_chance")),
        "qty": ((q + qmax) / 2) if (q is not None and qmax is not None) else (q or 1),
        "price": num(pick(r, "price_g", "price", "value_g")),
    }
    return entry


def build_pools(path):
    out = []
    for raw in load_rows(path):
        r = normalise_row(raw)
        out.append({
            "tier": pick(r, "tier"),
            "area": pick(r, "area"),
            "pool": pick(r, "pool"),
            "container": pick(r, "container"),
            "chance": pct(pick(r, "container_chance_per_catch")),
            "avgContainers": num(pick(r, "avg_containers")),
            "value": num(pick(r, "pool_value_g")),
        })
    return out


# ---------------------------------------------------------------- Lua writer
def lua_str(s):
    s = str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\r", "").replace("\n", "\\n")
    return '"' + s + '"'


def to_lua(v, indent=0):
    pad = "  " * indent
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else repr(round(v, 4))
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(to_lua(x) for x in v) + " }"
        inner = ",\n".join(pad + "  " + to_lua(x, indent + 1) for x in v)
        return "{\n" + inner + ",\n" + pad + "}"
    if isinstance(v, dict):
        parts = []
        for k, val in v.items():
            if val is None or val == [] or val == "":
                continue
            key = k if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", str(k)) else "[" + lua_str(k) + "]"
            parts.append(pad + "  " + key + " = " + to_lua(val, indent + 1))
        if not parts:
            return "{}"
        return "{\n" + ",\n".join(parts) + ",\n" + pad + "}"
    raise TypeError(type(v))


# ---------------------------------------------------------------- main
def main():
    input_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else ADDON_DIR
    farms_path = find(input_dir, "farms.json", "farms.csv")
    seed = False
    if not farms_path:
        farms_path = os.path.join(HERE, "farms_seed.json")
        seed = True
        print("farms.json/csv not found in", input_dir, "- using seed data (names and ranks only)")

    farms = rank_farms([build_farm(r) for r in load_rows(farms_path)])
    snapshot = next((f["priceTime"] for f in farms if f.get("priceTime")), None)

    containers = {}
    cpath = find(input_dir, "containers.json", "containers.csv")
    if cpath:
        containers = build_containers(load_rows(cpath))

    pools = []
    ppath = find(input_dir, "pools.csv")
    if ppath:
        pools = build_pools(ppath)

    data = {
        "meta": {
            "generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
            "priceSnapshot": snapshot or "17 Nov 2026 10:17 AEST",
            "market": "US Normal Alliance",
            "seed": seed,
            "farmCount": len(farms),
        },
        "brackets": BRACKETS,
        "farms": farms,
        "containers": containers,
        "pools": pools,
    }

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Generated by tools/build_data.py. Do not edit by hand; rerun the script instead.\n")
        f.write("local _, ns = ...\n")
        f.write("ns.data = " + to_lua(data) + "\n")

    scored = sum(1 for f in farms if f["score"] is not None)
    print(f"Wrote {OUT}: {len(farms)} farms ({scored} scored), "
          f"{len(containers)} containers, {len(pools)} pools")


if __name__ == "__main__":
    main()
