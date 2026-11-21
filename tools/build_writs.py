"""Build Writs.lua: every Craftsman's Writ, what it asks for, its tier and how the item is crafted.

Sources
  tools/writs_seed.json   writ item -> quest -> required item, as shipped in the WoW: Forever client
                          (1.60.1.70888). Writ items are 264011-264160.
  Wowhead (forever)       tooltip API: each writ's name and tier (Journeyman / Expert / Artisan), each
                          writ quest's requirements and each required item's name, used to check the seed.
  ForeverPath             Data/RecipeCatalogue.lua: the recipe that makes each required item
                          (profession, skill, reagents).

  python tools/build_writs.py           # uses the cached Wowhead answers in tools/.wh_cache when present
  python tools/build_writs.py --scan    # also scan item IDs 263800-264500 for writs missing from the seed
"""
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDONS = os.path.dirname(ROOT)
CACHE = os.path.join(HERE, ".wh_cache")
CATALOGUE = os.path.join(ADDONS, "ForeverPath", "Data", "RecipeCatalogue.lua")
TIERS = ["Journeyman", "Expert", "Artisan"]


def wowhead(kind, id_):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f"{kind}_{id_}.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    url = f"https://nether.wowhead.com/forever/tooltip/{kind}/{id_}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                data = json.loads(r.read().decode("utf-8"))
            break
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)
    return data


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def read_catalogue():
    """itemID -> (skillLine, minSkill, yellow, grey, [reagent id, count, ...]); skillLine -> name."""
    recipes, profs = {}, {}
    section = None
    with open(CATALOGUE, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"(?:Catalogue\.)?(\w+) = \{\s*$", line)
            if m:
                section = m.group(1)
                continue
            if section == "recipes":
                m = re.match(r'\s*\[(\d+)\] = \{ "((?:[^"\\]|\\.)*)", (\d+), (\d+), (\d+), (\d+), (\d+), (\d+), .*\{ ([\d, ]*) \} \},', line)
                if m:
                    item = int(m.group(4))
                    mats = [int(x) for x in m.group(9).replace(" ", "").split(",") if x]
                    rec = (int(m.group(3)), int(m.group(6)), int(m.group(7)), int(m.group(8)), mats, int(m.group(1)))
                    # keep the original (lowest spell ID) recipe; Season of Discovery copies come later
                    if item and (item not in recipes or rec[5] < recipes[item][5]):
                        recipes[item] = rec
            elif section == "professions":
                m = re.match(r'\s*\[(\d+)\] = \{ "([^"]+)"', line)
                if m:
                    profs[int(m.group(1))] = m.group(2)
    return recipes, profs


def main():
    with open(os.path.join(HERE, "writs_seed.json"), encoding="utf-8") as f:
        seed = json.load(f)
    by_writ = {r["writ"]: r for r in seed}

    if "--scan" in sys.argv:
        for id_ in range(263800, 264501):
            d = wowhead("item", id_)
            if "Craftsman's Writ:" in d.get("name", "") and id_ not in by_writ:
                print(f"WARNING: writ {id_} ({d['name']}) is not in writs_seed.json")

    recipes, profs = read_catalogue()
    out, problems, notes = [], [], []
    for r in seed:
        w = wowhead("item", r["writ"])
        q = wowhead("quest", r["quest"])
        it = wowhead("item", r["item"])
        name = w.get("name", "")
        want = name.split(": ", 1)[1] if ": " in name else ""
        title = None
        tier = re.search(r'color: #F5EB2E">([^<]+)<', w.get("tooltip", ""))
        tier = tier.group(1) if tier else None
        if tier not in TIERS:
            problems.append(f"{r['writ']}: unknown tier {tier!r}")
        if q.get("name") != name:
            problems.append(f"{r['writ']}: quest {r['quest']} is {q.get('name')!r}, writ is {name!r}")
        if it.get("name") != want:
            # a few writ titles spell the item differently ("Elixir of Ogre's Strength" for Elixir of
            # Ogre Strength); the quest still asks for the item, so the item's own name is used
            notes.append(f"{r['writ']}: writ says {want!r}, item {r['item']} is {it.get('name')!r}")
            title = want
            want = it.get("name") or want
        reqs = re.findall(r"<br />\s*-\s*([^<]+)", q.get("tooltip", ""))
        count = r["count"]
        for line in reqs:
            m = re.match(r"(.+?)\s+\((\d+)\)$", line.strip())
            if m and m.group(1) == want:
                count = int(m.group(2))
        rec = recipes.get(r["item"])
        out.append({
            "writ": r["writ"], "quest": r["quest"], "item": r["item"], "count": count, "name": want,
            "tier": TIERS.index(tier) + 1 if tier in TIERS else 0, "quality": it.get("quality", 1),
            "prof": profs.get(rec[0]) if rec else None, "skill": rec[1] if rec else None,
            "mats": rec[4] if rec else [], "title": title,
        })
        if not rec:
            problems.append(f"{r['writ']}: no recipe makes item {r['item']} ({want})")

    for n in notes:
        print("note:", n)
    for p in problems:
        print("WARNING:", p)

    lines = [
        "-- Farmer Joe: every Craftsman's Writ (generated by tools/build_writs.py; do not edit by hand).",
        "-- Writ item IDs, quests and required items from the WoW: Forever client (1.60.1.70888), checked",
        "-- against Wowhead; recipes from ForeverPath's client extract.",
        "-- { writ item, quest, required item, count, tier (1 Journeyman, 2 Expert, 3 Artisan), name, quality,",
        "--   profession, skill, { reagent item, count, ... }, writ title when it spells the item differently }",
        "local _, ns = ...",
        "",
        'ns.WRIT_TIERS = { "Journeyman", "Expert", "Artisan" }',
        "-- reputation per completed writ, by tier, with the Azeroth Commerce Authority or Durotar Supply and",
        "-- Logistics (community-reported; Wowhead had only seen Journeyman writs when this was built)",
        "ns.WRIT_REP = { 75, 125, 200 }",
        "ns.WRITS = {",
    ]
    for o in out:
        mats = ", ".join(str(x) for x in o["mats"])
        lines.append("  { %d, %d, %d, %d, %d, %s, %d, %s, %s, { %s }%s }," % (
            o["writ"], o["quest"], o["item"], o["count"], o["tier"], lua_str(o["name"]), o["quality"],
            lua_str(o["prof"]) if o["prof"] else "nil", o["skill"] if o["skill"] is not None else "nil", mats,
            (", " + lua_str(o["title"])) if o["title"] else ""))
    lines.append("}")
    with open(os.path.join(ROOT, "Writs.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    tiers = [sum(1 for o in out if o["tier"] == i + 1) for i in range(3)]
    print(f"Writs.lua: {len(out)} writs ({tiers[0]} Journeyman, {tiers[1]} Expert, {tiers[2]} Artisan), {len(problems)} warnings")


if __name__ == "__main__":
    main()
