# Farmer Joe

**A gold farming guide for WoW Classic Era / WoW Forever.** Farmer Joe shows the best gold farms for your level and prices them from your own Auctionator scans. It can also track your farming sessions and tell you which loot to vendor and which to auction.

> **Status: beta.** Farmer Joe has only been tested against a mocked game client, so expect rough edges in game. Bug reports are welcome under [Issues](../../issues).

---

## Features

### Farm guide by level bracket
- Covers levels 1 to 60 in 5-level brackets and opens on your own bracket.
- Each farm shows gold per hour, difficulty (1 to 5), the zone and the mob levels.
- Farms are ranked by gold per hour weighed against difficulty.
- **Filters:** *Only farms I can do* checks your professions and class. *Hide thin/crashing* hides farms whose market is weak.
- **Detail panel for each farm:**
  - Numbered how-to steps.
  - Required and bonus professions, shown green if you have them and red if you don't.
  - The full loot table with drop chances, amounts per hour and item tooltips. Shift-click an item to link it in chat.
  - Fishing farms also list their containers and pools.

### Live prices from Auctionator *(optional)*
- With [Auctionator](https://www.curseforge.com/wow/addons/auctionator) installed, gold per hour is worked out from **your** latest scans, so it matches your server and faction.
- **THIN** warns when the main item had few listings in your last scan. **CRASHING** warns when its price fell 40% or more over about a week.
- When the auction house is open, a scan button prices a farm's items, or a whole bracket, in one go.
- Without Auctionator, farms show their bundled gold-per-hour estimates instead.

### Live farm finder
- Farmer Joe checks every tradeable mob drop against your Auctionator prices. The most profitable mobs in each bracket are added to the list, tagged **LIVE**.
- Farms whose items are selling 50% or more above their 14-day average are tagged **HOT**.
- The list changes as prices move, so you can spot a spike before everyone else does.

### World map pins
- One click opens the world map on the farm's zone. It drops a pin on the main spot, adds dots at the other spawn points and sets a waypoint.
- Right-click a pin to clear the pins. The Farmer Joe window comes back when you close the map.

### Farming session tracker
- Start a session from any farm, or a free session from the tracker. It then records every item you loot and every coin you pick up.
- **Live stats:**
  - Time farmed.
  - Total value.
  - Gold per hour, compared with the farm's estimate.
  - A breakdown into coin, vendor value and auction value.
- **Sell advice for each item:**
  - **Auction** when the auction price minus a 20% house cut still beats the vendor price.
  - **Vendor** otherwise. Soulbound items always get Vendor.
  - **Keep** for quest items and items with no price.
- Grey items count as vendor trash unless they auction for 5g or more.
- Hover an item to see its vendor price, its auction price, the price after the cut, and why it got its badge.
- Pause and resume whenever you like. Sessions survive `/reload` and logging out, and time spent offline doesn't count.
- Stopping a session prints a summary to chat.

---

## Install

1. Download the latest `FarmerJoe-x.y.z.zip` from [Releases](../../releases).
2. Extract it into your game's AddOns folder so you get:
   ```
   World of Warcraft/_classic_era_/Interface/AddOns/Farmer Joe/Farmer Joe.toc
   ```
   Use your client's folder in place of `_classic_era_` if it's different.
3. **Restart the game fully.** `/reload` doesn't pick up new texture files.
4. *(Optional)* Install Auctionator and run a full scan at the auction house to get live prices.

Supported client: Classic Era, `## Interface: 16001`.

---

## Usage

| Action | How |
|---|---|
| Open / close the guide | `/fj`, or left-click the minimap button |
| Session tracker | `/fj session`, or right-click the minimap button |
| Start a free session | `/fj start` |
| Pause / resume a session | `/fj pause` |
| Stop a session | `/fj stop` |
| Scan your bracket's items (at the AH) | `/fj scan` |
| Show / hide live finds | `/fj live` |
| Clear map pins | `/fj clearpins` |
| Show / hide the minimap button | `/fj minimap` |
| Recentre the window | `/fj reset` |
| Data and Auctionator status | `/fj info` |
| Client build and TOC version | `/fj build` |
| All commands | `/fj help` |

Drag either window by its title bar. The minimap button can be dragged around the minimap.

### Tuning the sell advice
The thresholds are at the top of `Session.lua`:
```lua
ns.AH_CUT = 0.20       -- share of the auction price lost to the house
ns.GREY_AH_MIN = 50000 -- copper (5g): greys below this auction price are always vendored
```

---

## How the numbers work

- **Gold per hour** is the sum of each item's price × its expected amount per hour, plus fixed extras such as fishing containers. Items that need a profession you don't have (for example, Skinning) are left out.
- **Difficulty** is an editorial 1 to 5 rating: Easy, Steady, Tricky, Hard, Brutal.
- **Drop chances** come from CMaNGOS classic-db and Wowhead data. Chances that had to be estimated are marked in game.
- **Kills per hour** assumes one player at a steady pace, about 80 kills an hour for normal mobs and 40 for elites. Your results will vary, which is what the session tracker is for.
- **Session gold per hour** = (coin + what your loot sells for) ÷ time farmed. Each item is valued at its vendor price or its auction price after the cut, whichever its badge says.

---

## Repository layout

```
Farmer Joe.toc      addon manifest
Core.lua            player state, filters, formatting, slash commands
Data.lua            farm list by bracket (generated)
Loot.lua            per-farm loot tables (generated)
DropIndex.lua       mob drop index for the live farm finder (generated)
Prices.lua          Auctionator pricing, thin/crashing/HOT flags, ranking
Dynamic.lua         live farm finder
MapPins.lua         world map pins and waypoints
Session.lua         farming session tracking and sell advice
UI.lua              main window
SessionUI.lua       session tracker window
Minimap.lua         minimap button
Media/              textures (generated by tools/make_textures.py)
tools/              Python scripts that build the data and texture files
```

### Rebuilding the data (developers)
The generated Lua files are built with the Python scripts in `tools/`. Python 3 and Pillow are needed (Pillow only for the textures). The data scripts read item, NPC and drop data from other installed addons' databases (ForeverPath, ForeverPath_ClassicDB and QuestieDB). `tools/classicdb.py` lists the paths it expects.

```bash
python tools/build_data.py      # Data.lua
python tools/build_loot.py      # Loot.lua (farm loot specs live in tools/farm_specs.py)
python tools/build_drops.py     # DropIndex.lua
python tools/make_textures.py   # Media/*.tga
```

---

## Credits

- Drop data: CMaNGOS classic-db and Wowhead (via QuestieDB).
- Live pricing: [Auctionator](https://www.curseforge.com/wow/addons/auctionator)'s public API.
- Design: the "Coffee" palette and window design from the `WoW Forever Addon UI Mockups` handoff in this repository.
