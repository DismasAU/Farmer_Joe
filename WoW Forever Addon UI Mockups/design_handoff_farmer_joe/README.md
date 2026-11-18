# Handoff: Farmer Joe – Gold Farms addon UI

## Overview
Farmer Joe is a World of Warcraft addon for **WoW Forever** (a Classic-style realm, level cap 60). It shows players where to farm gold at their level. The game is split into 12 level brackets (1-5, 6-10 … 56-60), and each bracket has 4–6 farms ranked best-first. The player opens the window, sees the farms for their level, picks one and reads how to run it. It is a glance-between-fights reference panel, so it must read like a native game window.

This package covers the **minimap button** and the **main window** in every required state.

**Chosen direction: option 4a** on the mockup board. This is the classic Blizzard layout (option 1a) in the user's palette, with the Farmer Joe emblem as the window portrait.
Alternate kept for reference: **4b**, which is identical except for a light "Vanilla Custard" detail panel.

## About the design files
The files in this bundle are **design references built in HTML**. They are prototypes that show the intended look and behaviour; they are not code to ship. The task is to **rebuild them in WoW's own interface system** (Lua + FrameXML/XML templates), using flat textures, backdrops, gradients, font strings and Blizzard templates. Every visual in the mock was deliberately kept to things the client can draw: solid or gradient fills, 1px borders and circular textures. Nothing depends on CSS-only effects.

Open `Farmer Joe Mockups.dc.html` in a browser to see the board. The newest round is at the top. Section 4 is the chosen direction, and section 3 shows every state in the same layout. The windows are clickable: you can select rows, toggle the filters and change bracket.

## Fidelity
**High fidelity.** Colours, sizes, spacing, copy and states are final, except for the items listed under "Open questions". Match the measurements below. Fonts must be the game's own: Friz Quadrata and Arial Narrow. The mock substitutes Marcellus and Archivo Narrow only because browsers don't have the game fonts.

---

## Screens / views

### 1. Minimap button
- **Size:** 31×31, sitting on the minimap edge. The default position is the lower left (about 215°).
- **Build:** use **LibDBIcon-1.0** with a LibDataBroker launcher if it's available for the client. It handles dragging around the minimap edge, saved position and hiding. Otherwise use the standard 31px minimap-button recipe: the `MiniMap-TrackingBorder` overlay, a 20–24px icon and `UI-Minimap-ZoomButton-Highlight` for the highlight.
- **Icon:** a circular crop of the emblem showing the pitchfork and coin stack, with the "Farmer Joe" banner removed because it can't be read at this size. See **4g** on the board for the crop at 4×. Export it as a 64×64 TGA with the circular mask baked into the alpha.
- **Ring at rest:** Golden Bronze `#AF9B46` (2px), with a Coffee Bean `#1F1300` inner line.
- **On hover:** the ring turns Mustard `#F7CE5B` with a soft gold glow; the standard highlight texture is fine. Show the tooltip.
- **Tooltip** (GameTooltip, anchored to the button):
  - Line 1 (title, white): `Farmer Joe`
  - `Click to open/close`
  - `Drag to move`
  - `/fj minimap to hide`
- **Click:** toggles the main window. **Drag:** moves the button around the minimap edge, and the angle is saved.

### 2. Main window: `FarmerJoeFrame`
- **Size:** 760×470. Movable, dragged by the title bar. Clamp it to the screen.
- **Esc closes it:** `tinsert(UISpecialFrames, "FarmerJoeFrame")`.
- **Frame:**
  - Background: a vertical gradient from `#2B1C03` (top) to `#1F1300` (bottom).
  - Border, from the outside in: 1px `#000000`, 2px Golden Bronze `#AF9B46`, 1px `#1F1300`, 1px `#000000`.
  - Build it as a backdrop with a 1px edge file plus inner texture lines, or use 8-slice textures.

#### 2a. Emblem portrait
- A 66×66 circle with the emblem image cropped to a circle (about 106% zoom, so the emblem's own gold ring fills the circle).
- Its top-left corner sits at x −16, y −18 relative to the frame, so it overhangs the corner the way the character and spellbook portraits do.
- It draws above the frame border, with a 1px black outline.
- Export it as a 128×128 TGA with the circular alpha baked in.

#### 2b. Title bar
- **Position:** inset 4px from the frame edges; 24px tall.
- **Background:** a vertical gradient from `#3D2A08` to `#1F1300`, with a 1px bottom line in `#AF9B46`.
- **Title:** `Farmer Joe - Gold Farms` in Friz Quadrata 13px, Mustard `#F7CE5B`, with a 1px black shadow. Centred; the left padding of 64px keeps it clear of the portrait.
- **Close button:** the standard `UIPanelCloseButton`, 18×18, 7px from the top and 8px from the right.

#### 2c. Header row
- **Size:** 30px tall, with 6px above and below. Left inset 58px (to clear the portrait), right inset 14px. Items are spaced 6px apart, left to right:
  1. **`<` button:** 22×22. Fill: a gradient from Sunlit Clay `#F7B05B` to `#C27A2C`, a 1px top highlight in `#FBD29A` and a 1px inner edge in `#5A3006`. Glyph in Coffee Bean `#1F1300`, Friz Quadrata 13px. Steps to the previous bracket, stopping at 1-5.
  2. **Bracket label:** at least 156px wide, centred. Friz Quadrata 13px, Mustard `#F7CE5B`. The text is `Levels 21-25`, plus ` (you: 23)` in green `#1EFF00`. The "(you: N)" part appears **only** when the bracket on screen is the player's own.
  3. **`>` button:** the same style as `<`; steps to the next bracket, stopping at 56-60.
  4. **`My level` button:** 22px tall with 10px horizontal padding and the same Sunlit Clay fill. Text in Friz Quadrata 11px, Coffee Bean `#1F1300`. Jumps to the player's bracket.
  5. A flexible spacer.
  6. **Checkbox `Only farms I can do`:** a 15×15 box with a black fill and a 1px `#8A7A4A` border. The check mark is gold. The label is Arial Narrow 12px, Vanilla Custard `#DFD6A7`, and doesn't wrap. `UICheckButtonTemplate` scaled down is acceptable.
  7. **Checkbox `Hide thin/crashing`:** 8px left margin, same style.

#### 2d. Farm list (left pane)
- **Size and position:** 420px wide; fills the space between the header row and the footer. The body area has 14px left/right padding and a 10px gap between the list and the detail panel.
- **Background:** black at 32% opacity, with a 1px `#5E4F22` border.
- **Column header row:** 20px tall. Background: a gradient from `#36260A` to `#1F1300`, with a 1px bottom line in `#5E4F22`. Text in Friz Quadrata 10px, Mustard.
- **Columns:** 6px horizontal padding, 6px between columns.

  | Column  | Width | Alignment / content |
  |---------|-------|---------------------|
  | #       | 16px  | right-aligned rank  |
  | Farm    | flex  | ellipsis truncation |
  | Gold/hr | 64px  | text                |
  | Diff    | 34px  | text `N/5`          |
  | Flags   | 58px  | text                |

- **Rows:** 21px tall, 14 visible; the list scrolls with `FauxScrollFrameTemplate` or a hybrid scroll frame. The farm name is Arial Narrow 13px; other cells are 12px.
- **Row styling:**
  - Zebra striping on odd rows: Vanilla Custard at 3.5% opacity.
  - Hover: white at 8% opacity.
  - **Selected:** a horizontal green gradient from `rgba(30,255,0,0.30)` to `rgba(30,255,0,0.07)`, with 1px top and bottom lines in `rgba(30,255,0,0.45)`.
- **Cell colours:**
  - Rank: Golden Bronze `#AF9B46`.
  - Name and gold/hr: Vanilla Custard `#DFD6A7`. An unknown gold/hr (`?`) is Golden Bronze.
  - Difficulty colour by value: 1 `#1EFF00`, 2 `#9ACD32`, 3 `#FFD100`, 4 `#FF8000`, 5 `#FF2020`. An unknown difficulty (`?`) is Golden Bronze.
  - Flags: `thin` in Sunlit Clay `#F7B05B` (few listed on the AH); `crashing` in `#FF2020` (price falling fast). Both can appear.
- **Farms the player can't do:** the whole row is `#7D7457` (the difficulty too); the rank is `#5A5A5A`. Flags keep their colours.
- **Row hover tooltip** (GameTooltip, anchored to the row):
  - Farm name (white, header size).
  - Zone and mob levels, e.g. `Ashenvale · mobs 20-24` (light grey).
  - If the player can't do the farm, a red `#FF2020` line with the reason, e.g. `Needs Skinning` or `Mage only`.
- **Rank numbers keep their original values when filters hide rows**, so gaps such as 1, 4, 5, 6 are expected.

#### 2e. Empty list state
Show this centred in the list area when no rows are visible:
- **Heading:** Friz Quadrata 14px, Mustard.
- **Body:** Arial Narrow 13px, Vanilla Custard, line height 1.4, with 48px side padding.
- **Case A, filters hid everything:**
  - Heading: `No farms match your filters`
  - Body: `All {n} farms for Levels {bracket} are hidden: {a} need a class or profession you don't have, {b} are thin or crashing.` Leave out a clause when its count is 0. Use "needs"/"is" when the count is 1.
  - Button `Show all farms`, in the same style as `My level`. It clears both filters.
- **Case B, the bracket has no data:**
  - Heading: `No farms listed yet`
  - Body: `Nobody has reported a farm for Levels {bracket} yet. Try a nearby bracket.`
  - No button.
- In both cases the detail panel shows a centred Golden Bronze line: `Pick a farm on the left to see how to run it.`

#### 2f. Detail panel (right pane)
- **Size and position:** fills the remaining width (about 292px). Scrolls vertically with `UIPanelScrollFrameTemplate`; never scrolls horizontally. Padding: 10px top, 12px sides and bottom.
- **Background:** a vertical gradient from `#170E00` to `#100900`, with a 1px `#5E4F22` border and a 1px inner black line.
- **Body text:** Arial Narrow 12px, Vanilla Custard `#DFD6A7`, line height about 1.35. Secondary text is Golden Bronze `#AF9B46`.

Contents, from top to bottom (each section is left out when it has no data):
1. **Farm name:** Friz Quadrata 15px, Mustard `#F7CE5B`.
2. **Zone line:** `{zone} · mobs {min}-{max}` in Golden Bronze. Leave out the mob part for farms with no mobs, such as fishing.
3. **Stat line:** 13px, 8px top margin.
   - Layout: `Gold/hr 18-30g · Difficulty 2/5 · Score 12.0`.
   - Labels are Golden Bronze and values are Vanilla Custard. The difficulty value uses the difficulty colours.
   - Missing data reads `Gold/hr ?`, `Difficulty ?` and `Score: none`, with those values in Golden Bronze.
4. **Source line:** 11px, Golden Bronze, explaining where the gold/hr figure comes from, e.g. `From 14 player reports, Oct-Nov 2026`.
5. **Can't-do line:** 7px top margin, red `#FF2020`, only when the player can't run the farm. Format: `You can't run this yet: needs Skinning`. Join multiple reasons with ", ".
6. **Requirements:** one line each.
   - `Requires: Fishing`. The value is red if the player lacks the profession.
   - `Bonus with: Skinning`.
   - `Class: Mage`. The value is red if the class doesn't match.
   - The label is Golden Bronze; the value is Vanilla Custard (or red as above).
7. **Section headings** (`How to`, `Notes`, `Market`, `Container`):
   - Friz Quadrata 12px, Mustard, 12px top margin.
   - A 1px rule underneath in `rgba(175,155,70,0.4)`.
   - Content starts 5px below the rule.
8. **How to:** one paragraph per step, 5px apart.
9. **Notes:** free text.
10. **Market:**
    - Item name (13px, Mustard), followed by flag badges. Badges are 14px tall with a 1px outline in the flag colour and uppercase 10px semibold text.
    - A 3-column grid. Each column has a small Golden Bronze label (11px) above a value: `Listed`, `Sold per day`, `7-day change`.
    - The change value is green `#1EFF00` when rising, red when crashing, and Vanilla Custard otherwise.
    - Optional green `#1EFF00` line: `Your Auctionator scan: 1.2g`.
    - Footnote (11px, Golden Bronze): `Community AH snapshot, US Normal Alliance. Your own scan is used when it's newer.`
    - With no market data, show `No market data for this farm yet.` in Golden Bronze.
11. **Container** (fishing farms only):
    - Container name (13px, Mustard).
    - `Expected value ≈ 38s · ~5 per hour`. Labels are Golden Bronze and values are Vanilla Custard.
    - **Loot table:** 3 columns (item / 44px chance, right-aligned / 30px quantity, right-aligned) under a header row of 11px Golden Bronze labels.
    - Item names use quality colours: poor `#9D9D9D`, common = body text colour, uncommon `#1EFF00`.
    - **Pools:** a subheading in Friz Quadrata 11px, Mustard, followed by two columns: pool name and value (Golden Bronze, right-aligned).
    - **Caveat** (11px, Golden Bronze): `Drop chances use Classic Era data and may differ on WoW Forever.`
12. **Source URL:** 11px, Golden Bronze, 12px top margin. Not clickable; the game can't open links. Consider a copy-to-chat-box popup.

#### 2g. Footer
- **Size:** 24px tall, with a 1px top line in `#5E4F22`. Margins: 4px above, 6px below, 14px at the sides.
- **Text:** Arial Narrow 12px, Golden Bronze.
- **Left:** the count in Vanilla Custard, then the price source in Golden Bronze:
  - `{shown} shown` plus `, {hidden} hidden by filters` when anything is hidden.
  - Then ` · Prices: US Normal Alliance, 17 Nov 2026 10:17 AEST`, using the data snapshot's realm and timestamp.
- **Right-aligned:** `Seed data: names only` in Sunlit Clay `#F7B05B`, shown when any farm in the bracket is seed data (names only, no stats).

---

## States to build (board references)
| State | Reference |
|---|---|
| Normal: full data, farm selected | **4a** / 3a |
| Farm the player can't do: grey row, hover tooltip, red reason in the detail panel | **4c** / 3b |
| Fishing farm with the Container section | 4d (custard variant) / 3c |
| Missing data: `?` values, `Score: none`, seed warning | 3d |
| Filters hiding farms (footer count) | 3e |
| Empty after filtering (new message + reset) | 3f |
| Minimap button at rest / on hover | **4e / 4f** (crop shown in 4g) |

Section 3 uses the original grey-and-red classic colours. Build those states with the 4a colours above; the layout is identical.

## Interactions and behaviour
- **On open:** show the player's bracket (`floor((UnitLevel("player") - 1) / 5)`) and select its first visible farm.
- **`<` / `>`:** change bracket, reset the selection to the first visible farm and scroll both panes to the top.
- **`My level`:** jump to the player's bracket.
- **Checkboxes:** take effect immediately and are saved between sessions.
  - **Only farms I can do** hides farms whose required professions the player lacks or whose class requirement doesn't match.
  - **Hide thin/crashing** hides farms with any flag.
  - If the selected farm becomes hidden, select the first visible farm.
- **Row click:** select the farm and scroll the detail panel to the top.
- **Row hover:** highlight the row and show the tooltip.
- **Window:** drag by the title bar; Esc or the close button closes it.
- **Slash commands:**
  - `/fj` toggles the window.
  - `/fj minimap` hides or shows the minimap button.
- There are no animations, beyond the standard tooltip and highlight behaviour.

## State and data

### Saved variables (`FarmerJoeDB`, per account)
```lua
FarmerJoeDB = {
  minimap = { hide = false, minimapPos = 215 },          -- LibDBIcon format
  filters = { onlyCanDo = false, hideFlagged = false },
  window  = { point = "CENTER", x = 0, y = 0 },
}
```
Runtime state: `bracketIndex` (1–12), `selectedFarmId`, `hoverRow`.

### Player capability
- Level from `UnitLevel("player")`.
- Class from `UnitClass("player")`, using the second (English) return value.
- Professions from `GetSkillLineInfo` (loop through `GetNumSkillLines()`).
- Refresh on `SKILL_LINES_CHANGED` and `PLAYER_LEVEL_UP`.

### Farm record (the data the UI expects)
```lua
{
  id = "duskwood_green_recluses", rank = 1, bracket = "21-25",
  name = "Green Recluses", zone = "Duskwood", mobs = "21-22",   -- mobs optional
  goldLo = 18, goldHi = 30, goldUpTo = false,                   -- nil = unknown ("?"); upTo → "up to 40g"
  difficulty = 2,                                                -- 1-5 or nil
  score = 12.0,                                                  -- nil → "Score: none"
  goldSource = "From 14 player reports, Oct-Nov 2026",
  requires = { "Fishing" }, bonusWith = { "Cooking" }, class = nil,
  flags = { thin = false, crashing = false },
  howTo = { "step 1", "step 2" }, notes = "…",
  market = { itemId = 0, item = "Gooey Spider Leg", listed = 214, soldPerDay = 180, change7d = 0.04 },
  container = { name = "Battered Chest", ev = 3800, perHour = 5,
                loot = { { itemId = 0, name = "Wool Cloth", chance = 0.42, qty = "1-3", quality = 1 } },
                pools = { { name = "Oily Blackmouth School", value = "~6s per fish" } },
                caveat = "…" },
  sourceUrl = "…", seed = false,
}
```
The sample data in `FJWindow.dc.html` (the `FARMS` constant) covers every state and can be used as test fixtures. **All farm data, prices and URLs in the mock are placeholders.**

**Auctionator** is an optional dependency. When it's loaded, read the player's own scanned price for `market.itemId` and show the green "Your Auctionator scan" line. Confirm which Auctionator API version is available on this client.

## Design tokens

### Palette (user-supplied)
| Token | Hex | Use |
|---|---|---|
| Vanilla Custard | `#DFD6A7` | body text, counts |
| Mustard | `#F7CE5B` | headings, title, labels, farm name in the detail panel |
| Sunlit Clay | `#F7B05B` | buttons, `thin` flag, seed warning |
| Golden Bronze | `#AF9B46` | frame trim, secondary text, rank |
| Coffee Bean | `#1F1300` | frame base, button text |

### Derived values
| Colour | Use |
|---|---|
| `#2B1C03` | top of the frame gradient |
| `#3D2A08` | top of the title bar gradient |
| `#36260A` | top of the column header gradient |
| `#5E4F22` | pane borders |
| `#170E00` → `#100900` | detail panel gradient |
| `#7D7457` | rows the player can't do |
| `#C27A2C` / `#FBD29A` / `#5A3006` | button shading |

### Game colours (kept from the brief)
| Colour | Use |
|---|---|
| `#1EFF00` | selection, "(you: N)", Auctionator line, uncommon items |
| `#FF2020` | `crashing` flag, can't-do reasons |
| Difficulty 1–5 | `#1EFF00`, `#9ACD32`, `#FFD100`, `#FF8000`, `#FF2020` |

### Type
| Font | Uses |
|---|---|
| Friz Quadrata (`Fonts\FRIZQT__.TTF`) | 10 column headers; 11 buttons and subheads; 12 section headings; 13 title, bracket label and arrows; 14 empty-state heading; 15 farm name |
| Arial Narrow (`Fonts\ARIALN.TTF`) | 11 footnotes; 12 body; 13 list names and empty-state body |

All text has a 1px black shadow (`SetShadowOffset(1, -1)`).

### Spacing
- Outer padding: 14px.
- Pane gap: 10px.
- Row height: 21px.
- Section gap: 12px.
- No rounded corners, except the circular emblem and minimap textures.
- No drop shadows, except the minimap hover glow (a texture).

## Assets
| File | Notes |
|---|---|
| `assets/fj-emblem.png` | 1254×1254, user-supplied "Farmer Joe Golden Harvest Emblem", no alpha (black background). The source for both textures below. |
| `assets/fj-emblem-320.png` | A downscaled copy used in the mockups only. |

Textures to produce (power-of-two TGA or BLP, with the circular alpha baked in):
- `Interface\AddOns\FarmerJoe\Media\Emblem128.tga`: the full emblem, for the window portrait.
- `Interface\AddOns\FarmerJoe\Media\MinimapIcon64.tga`: the pitchfork and coins crop, for the minimap button.

Everything else uses stock textures: `UIPanelCloseButton`, the checkbox templates, the tooltip backdrop, the minimap tracking border and highlight, and the scroll bar templates.

## Scope
**In scope**
- Minimap button.
- Main window with every state above.
- Filters, bracket navigation and saved settings.
- Detecting the player's level, class and professions.
- Displaying the bundled farm data.
- Optional Auctionator price line.

**Out of scope for this handoff**
- The farm-data pipeline: collecting reports, computing gold/hr and score, and the AH snapshot source and update cadence.
- A settings panel.
- Localisation.
- Horde data.

## Open questions for the build
1. **Client version.** Which client and Lua API does WoW Forever use? If it's a 1.12-era client, use `SetBackdrop` and `SetGradientAlpha` directly; on newer Classic Era clients, use `BackdropTemplate` and `SetGradient` with `CreateColor`. This also decides whether LibDBIcon and Auctionator are available.
2. **Thresholds.** What counts as `thin` (how many listings) and `crashing` (how large a 7-day drop)? They should come with the data, not be hard-coded in the UI.
3. **Score formula.** It is shown as given in the data.
4. **Detail panel variant.** 4a (dark) is the default; 4b (custard) is available if the team prefers it.

## Files in this bundle
| File | What it is |
|---|---|
| `Farmer Joe Mockups.dc.html` | The full mockup board. Open it in a browser; it needs `support.js` and `FJWindow.dc.html` alongside it. |
| `FJWindow.dc.html` | The window component. The `FARMS` constant holds sample data covering every state, and the `THEMES.farmhouse` and `DETAILS.coffee` constants hold the exact 4a colour values. Its `look` and `state` settings switch between styles and states. |
| `support.js` | The runtime the mockups need. Not part of the addon. |
| `assets/` | Emblem source and the mockup copy. |
