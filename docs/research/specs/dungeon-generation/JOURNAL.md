# Dungeon Generation Specification - Journal

## 2026-01-28: Initial Setup

### Session Goals
- Create specification folder structure
- Identify source files for dungeon generation
- Begin code survey

### Created Files
- `plan.md` - Specification plan and document list
- `journal.md` - This file

### Next Steps
- Survey original source to find dungeon generation code
- Identify main entry points and data structures
- Begin `overview.md` document

---

## 2026-01-28: Algorithm Survey Complete

### Source Files Identified

| File | Lines | Purpose |
|------|-------|---------|
| `src/MakeLev.cpp` | 3842 | Main generation (Map::Generate) |
| `lib/dungeon.irh` | Large | Dungeon definitions, regions, doors, portals |

### Generation Phases Documented

Created `overview.md` with the 6-step algorithm:

1. **Initialize** - Load constants, allocate grid, fill with rock
2. **Streamers** - Rivers, chasms spanning the map
3. **Special Rooms** - Predefined vaults, entry chambers
4. **Draw Panels** - Generate room in each grid cell
5. **Connect Panels** - Tunnel between adjacent panels
5b. **Fix-Up** - Flood-fill connectivity check, add tunnels
6. **Stairs & Content** - Up/down stairs, special monsters/items

### Key Concepts Discovered

- **Panel system**: Level divided into grid of panels (e.g., 4x4)
- **Weighted selection**: Room types, corridors, streamers use weight lists
- **Chasm propagation**: Chasms continue from level above
- **Connectivity guarantee**: Flood-fill ensures all areas reachable
- **Specials system**: Predefined content at specific depths

### Constants from dungeon.irh

The "Goblin Caves" dungeon defines:
- `ROOM_MAXX/Y` = 16 (max room size)
- `TURN_CHANCE` = 20 (corridor turn probability)
- `DUN_DEPTH` = 10 (number of levels)
- Various special rooms at specific depths (entry chamber, sanctuary, armoury, etc.)

### Open Questions

1. What does `DrawPanel()` do exactly? (Need to read that function)
2. How does `WriteStreamer()` work?
3. What room types exist and how are they selected?
4. How are doors placed?

### Next Session Tasks

- Read `DrawPanel()` function to understand room generation
- Document room types in `room-placement.md`
- Read `Tunnel()` function for corridor generation
- Document the weight list format

---

## 2026-01-28: Room Placement Documented

### DrawPanel() Analysis Complete

Read `DrawPanel()` function (lines 2316-2899). Key findings:

**Room Selection Process:**
1. Sum weights from `RM_WEIGHTS` list
2. Random selection based on cumulative weights
3. Find compatible region from `ROOM_WEIGHTS`
4. Each region used only once per level
5. If no compatible regions, disable that room type and retry

**24 Room Types Identified:**

| Type | Shape |
|------|-------|
| RM_NOROOM | Empty (solid rock) |
| RM_NORMAL | Standard rectangle |
| RM_CIRCLE | Circle |
| RM_LCIRCLE | Large circle |
| RM_LARGE | Large rectangle |
| RM_MAZE | Maze pattern |
| RM_ADJACENT | 4 adjacent rectangles |
| RM_AD_ROUND | 4 adjacent circles |
| RM_AD_MIXED | 4 adjacent mixed |
| RM_OVERLAP | 2-4 overlapping rooms |
| RM_OCTAGON | 8-sided room |
| RM_DIAMONDS | Chain of diamonds |
| RM_BUILDING | Subdivided building |
| RM_CASTLE | Castle structure |
| RM_CHECKER | Checkerboard pillars |
| RM_PILLARS | Regular pillar grid |
| RM_GRID | Furnishing grid |
| RM_CROSS | Cross shape |
| RM_RCAVERN | Random cavern |
| RM_LIFECAVE | Cellular automata cave |
| RM_DOUBLE | Room within room |
| RM_SHAPED | Predefined grid |
| RM_RANDTOWN | (Falls to NORMAL) |
| RM_DESTROYED | (Falls to NORMAL) |

**Created `room-placement.md`** with:
- Selection algorithm
- All 24 room types with code snippets
- Region flags affecting rooms
- Post-processing steps
- Write function reference

### Still To Document

- `Tunnel()` function for corridors
- Streamer generation
- Feature placement (doors, traps)
- Population system

---

## 2026-01-28: Verification Discipline Established

### Critical Correction

**Original room type table was WRONG.** I had inferred values from switch case order instead of checking actual `#define` values in `inc/Defines.h`.

Example errors:
- Listed RM_CIRCLE as 2, actual value is 8
- Listed RM_MAZE as 5, actual value is 23
- Listed RM_LCIRCLE as 3, actual value is 19

### Lesson Learned

**Never infer values - always verify from source.**

The specs must document what the original code actually does, not what seems logical. This applies to:
- Constant values (check Defines.h)
- Algorithm behavior (check actual code)
- Default values (check initialization)

### Changes Made

1. Added verification status tables to specs
2. Added source line references for all claims
3. Corrected room type values from `inc/Defines.h:869-895`
4. Added VERIFIED/PARTIAL/UNVERIFIED markers
5. Updated plan.md with verification principle

### Verification Markers

Specs now use:
- **VERIFIED**: Directly confirmed from source with line reference
- **PARTIAL**: Some aspects confirmed, others need checking
- **UNVERIFIED**: Inferred, must be confirmed before use

---

## 2026-01-28: Corridor Generation Documented

### Tunnel() Function Analysis

Read `Map::Tunnel()` (lines 3395-3609) and related code.

**Key source locations verified:**
- TT_* flags: MakeLev.cpp:76-82
- PRIO_* constants: Defines.h:4307-4320
- Corridor constants: Defines.h:3593-3596, 3619, 4331
- CorrectDir helper: MakeLev.cpp:3611-3639

### Algorithm Summary

1. **Region Selection**: If distance > 5, select from CorridorWeights (one-time use unless RF_STAPLE)
2. **Direction Init**: Auto-select based on greater axis distance
3. **Main Loop**:
   - Track rooms touched via bitmap
   - Create doors at corridor/room intersections
   - Force turn at edges, vaults, walls, segment max
   - Turn decision: forced OR (segment > min AND random < turn_chance)
   - Direct mode: turn toward destination
   - Stubborn mode: random direction
4. **Write Corridor**: Floor at PRIO_ROOM_FLOOR (70), walls at PRIO_CORRIDOR_WALL (10)

### Flags Used in Practice

From Generate():
```cpp
Tunnel(sx, sy, dx, dy, TT_DIRECT | TT_WANDER, -1, 0);
```

Primary combination is TT_DIRECT | TT_WANDER.

### Created `corridor-generation.md`

All code snippets taken directly from source with line references.

---

## 2026-01-28: Feature Placement Documented

### Functions Analyzed

| Function | Source | Purpose |
|----------|--------|---------|
| `MakeDoor` | MakeLev.cpp:1270-1288 | Standard door placement |
| `MakeSecretDoor` | MakeLev.cpp:1290-1302 | Secret door placement |
| `Door::Door` | Feature.cpp:310-337 | Constructor with randomization |
| `Door::SetImage` | Feature.cpp:342-397 | Orientation detection |

### Door Placement Details

**From constructor (default path):**
- 10% open
- ~45% closed+locked
- ~45% closed+unlocked
- ~14% secret (overrides open)

**Early game protection:**
- Depth 1-3: Forces wood doors regardless of region setting
- Reason: "some character types can't get through the other kinds"

**Orientation detection:**
- Checks adjacent solid tiles
- Vertical: walls above+below
- Horizontal: walls left+right
- Broken: neither pattern

### Stairs Placement

**Up-stairs:**
- Placed at same coordinates as down-stairs on level above
- If in solid rock, carves 3x3 area (floor + walls)

**Down-stairs:**
- Count: MIN_STAIRS to MAX_STAIRS
- Avoids: solid, high-priority tiles, water, fall terrain
- Avoids regions that already have stairs

### Trap Placement

Two patterns:
1. **At doors**: `random(TRAP_CHANCE) <= DepthCR + 10`
2. **At bottlenecks**: `random(TRAP_CHANCE) <= (DepthCR + 2) / 3`

Bottleneck = corridor with walls on opposite sides (N-S or E-W).

### Treasure Deposits

- Count: `1d4 + Depth`
- Location: Fully surrounded by solid rock
- Prefers non-base rock terrain

### Created `feature-placement.md`

All code snippets verbatim from source with line references.

---

## 2026-01-28: Terrain Assignment Documented

### Functions Analyzed

| Function | Source | Purpose |
|----------|--------|---------|
| `WriteAt` | MakeLev.cpp:232-330 | Core terrain write with priority |
| `WriteRoom` | MakeLev.cpp:332-353 | Rectangular room (walls+floor) |
| `WriteBox` | MakeLev.cpp:355-365 | Floor only rectangle |
| `WriteCircle` | MakeLev.cpp:368-401 | Circular floor |
| `WriteWalls` | MakeLev.cpp:403-417 | Add walls around floor |
| `WriteLifeCave` | MakeLev.cpp:419-468 | Cellular automata caves |
| `WriteStreamer` | MakeLev.cpp:841-911 | Rivers, chasms, rock types |

### Key Findings

**WriteAt priority system:**
- Lower priority terrain doesn't overwrite higher
- `Force` parameter bypasses priority check
- Map edges protected unless `Force` or `PRIO_MAX`
- Tracks open tiles in `OpenX[]`/`OpenY[]` for corridor endpoints

**Cellular automata (WriteLifeCave):**
- `LIFE_PERCENT` controls initial fill density
- 20 iterations of rules
- 5+ neighbors → solid, 3 or fewer → floor, 4 → unchanged
- 3-tile buffer around edges always solid

**Streamer behavior:**
- Rivers: Fixed width (2-5), start at edge
- Non-rivers: Variable width, start anywhere
- Chasms: Minimum width 4
- Priority: Rivers/chasms use `PRIO_RIVER_STREAMER` (90)

**Region structure:**
- `Walls`, `Floor`, `Door` - terrain/feature references
- `RoomTypes` - bitmask of allowed RM_* types
- `Furnishings[6]` - terrain for decoration

### Created `terrain-assignment.md`

Documented:
- All Write* functions with source references
- TF_* terrain flags (Defines.h:677-703)
- Priority system with full table
- Region and terrain structure definitions
- Example terrain and region definitions from dungeon.irh

---

## 2026-01-28: Population System Documented

### Functions Analyzed

| Function | Source | Purpose |
|----------|--------|---------|
| `PopulatePanel` | MakeLev.cpp:3269-3301 | Trigger encounter generation for a panel |
| `enGenerate` | Encounter.cpp:514-1125 | Main encounter generation (7 stages) |
| `enBuildMon` | Encounter.cpp:2372-2620 | Create and place individual monsters |
| `FindOpenAreas` | MakeLev.cpp:3303-3383 | Find valid placement locations |
| `FurnishArea` | MakeLev.cpp:2951-3266 | Place furniture, items, decorations |
| `PopulateChest` | MakeLev.cpp:2911-2949 | Fill chest with items |
| `maxAmtByCR` | Encounter.cpp:500-512 | Monster count cap by CR |

### Key Findings

**Challenge Rating Calculation:**
```cpp
DepthCR = INITIAL_CR + (Depth * DUN_SPEED) / 100 - 1
```

**Monster Density by Depth:**
- Depth > 2: 1 monster per 30 open tiles
- Depth 2: 1 monster per 50 open tiles
- Depth 1: 1 monster per 75 open tiles

**Monster Count Caps by CR:**
- CR 1: 5 max
- CR 2: 7 max
- CR 3: 10 max
- CR 4: 12 max
- CR 5: 15 max
- CR > 5: 50 max

**Out-of-Depth Monsters:**
- Chance: `random(100) < 22 - mLuck`
- CR increase: 1-5 levels above normal
- Always single monster

**Chest Contents:**
- Item count: MIN to MAX + luck modifier
- TREASURE_CHANCE% at CR+3 with IG_GOOD
- Lock chance: `random(Depth) && random(Depth)` (quadratic)
- 50% chance of 1d5 identify scrolls

**Placement Rules:**
- Aquatic monsters in water only
- Non-aquatic avoid water (except amphibians)
- Spiders only on sticky terrain
- Aerial creatures only over fall terrain
- 50 placement attempts before failure

### Created `population.md`

Documented:
- PopulatePanel and encounter generation
- 7-stage encounter algorithm
- EN_* flags (26 documented)
- IG_* flags for item generation
- FU_* furnishing patterns (16 types)
- FOA_* open area filters
- Chest population algorithm
- Monster placement terrain rules

---

## 2026-01-28: Region System Documented

### Source Files Analyzed

| File | Lines | Purpose |
|------|-------|---------|
| `Res.h` | 630-643 | TRegion class definition |
| `Defines.h` | 705-732 | RF_* region flags |
| `Annot.cpp` | 289-426 | Weight list generation |
| `MakeLev.cpp` | 953-1102 | WriteMap (grid processing) |
| `MakeLev.cpp` | 2396-2422 | Room region selection |
| `MakeLev.cpp` | 2820-2842 | Color list application |
| `dungeon.irh` | ~5000 | Region definitions |

### Key Findings

**TRegion Structure:**
- `Depth, Size` - Placement constraints
- `Walls, Floor, Door` - Terrain/feature references
- `RoomTypes` - Bitmask of compatible RM_* types
- `sx, sy, Grid` - Grid dimensions and text handle

**Region Categories:**
- RF_ROOM - Main dungeon rooms (selected in DrawPanel)
- RF_CORRIDOR - Tunnel regions (selected in Tunnel)
- RF_RIVER, RF_ROCKTYPE, RF_CHASM - Streamer types
- RF_VAULT - Special protected areas

**Weight List Generation:**
- ROOM_WEIGHTS: All RF_ROOM regions, weight 1
- CORRIDOR_WEIGHTS: RF_STAPLE=16, others=1
- STREAMER_WEIGHTS: All streamer types, weight 1

**Region Selection Rules:**
- RoomTypes must include chosen RM_* type
- Depth must be <= current DepthCR
- Each region used only once (unless RF_STAPLE)
- Vaults require MIN_VAULT_DEPTH

**Grid Processing (RM_SHAPED):**
- 50% horizontal flip, 50% vertical flip
- Default tile meanings ('#' wall, '.' floor, '+' door, etc.)
- Custom tiles via Tiles: block
- Tile flags: TILE_START, TILE_ITEM, TILE_MONSTER, etc.

### Region Lists Documented

| List | Purpose |
|------|---------|
| FURNISHINGS | FU_* patterns + resources |
| WALL_COLOURS | Random color selection |
| FLOOR_COLOURS | Random color selection |
| ENCOUNTER_LIST | Weighted encounters |

### Example Count from dungeon.irh

- ~70 RF_ROOM regions
- ~10 RF_CORRIDOR regions
- ~8 RF_RIVER/ROCKTYPE/CHASM regions

### Created `regions.md`

Documented:
- TRegion structure and fields
- 27 RF_* flags with meanings
- Region selection algorithms
- Default weight list generation
- Grid format and tile definitions
- List types (furnishings, colors, encounters)
- Region constants and events
- Example region definitions

---

## 2026-01-28: Verification Pass #1

### Methodology

Systematic review of each spec document against original source code:
1. Cross-reference line numbers
2. Verify constant values and flags
3. Check for missing information
4. Confirm algorithm descriptions

### Issues Found & Fixed

| Spec | Issue | Fix |
|------|-------|-----|
| `overview.md` | Missing Step 7 (Deallocation & Return at line 2262) | Added Step 7 section |
| `feature-placement.md` | Door flags incomplete (missing DF_TRAPPED, DF_BROKEN, DF_SEARCHED, DF_PICKED) | Updated flags table with all values |

### Verified Correct

| Spec | Item Verified |
|------|--------------|
| `overview.md` | Generate() signature at line 1330 |
| `overview.md` | Step comments match source lines (1349, 1419, 1494, 1607, 1616, 1745, 1876) |
| `overview.md` | Fix-up tunneling uses 26 trials (line 1779) |
| `room-placement.md` | All 25 RM_* constants match Defines.h:869-895 |
| `corridor-generation.md` | PRIO_* constants match Defines.h:4307-4320 |
| `corridor-generation.md` | Corridor constants at correct lines (3593-3596, 3619, 4331) |
| `terrain-assignment.md` | WriteAt at line 232, TF_* flags at 677-703 |
| `population.md` | maxAmtByCR function matches Encounter.cpp:500-512 |
| `population.md` | OpenC division ratios (30/50/75) match lines 545-549 |
| `regions.md` | RF_STAPLE weight=16 confirmed at Annot.cpp:390 |

### Verification Status Update

All 7 specs now pass verification:
- Line references validated against source
- Constant values confirmed from Defines.h
- Algorithm descriptions match implementation

### Remaining Work

For future verification passes:
- [ ] Run mental test scenarios against specs
- [ ] Check edge cases (empty panels, max depth, etc.)
- [ ] Verify interaction between subsystems

---

## 2026-01-28: Verification Pass #2 - Edge Cases

### Methodology

Systematic review of error handling, boundary conditions, and failure recovery:
1. Search for Fatal(), Error() calls
2. Identify retry loops and their limits
3. Document graceful degradation patterns
4. Map resource limits

### Edge Cases Documented

| Category | Behavior | Source |
|----------|----------|--------|
| Region exhaustion (first) | Reset usedInThisLevel[], retry | MakeLev.cpp:2364-2377 |
| Region exhaustion (second) | Fatal error | MakeLev.cpp:2364-2377 |
| Room type exhaustion | Disable type, retry | MakeLev.cpp:2412-2416 |
| 200 room tries | Log error, continue | MakeLev.cpp:2353 |
| Stair placement (500 tries) | Skip stair | MakeLev.cpp:1882-1887 |
| Connectivity (26 trials) | Accept disconnected | MakeLev.cpp:1779, 1865 |
| Map edge write | Silent skip | MakeLev.cpp:255-257 |
| Corridor at edge | Force turn/clamp | MakeLev.cpp:3489-3541 |
| Too many terrains (255) | Fatal error | MakeLev.cpp:282 |
| Too many regions (255) | Fatal error | MakeLev.cpp:297, 1260 |
| Panel overflow (32x32) | Fatal error | MakeLev.cpp:1378 |
| Size mismatch | Fatal error | MakeLev.cpp:1368-1371 |

### Key Findings

**Graceful Degradation:**
- Stair placement failure: Dungeon may have fewer stairs than intended
- Connectivity failure: Dungeon may have isolated areas (26 trial limit)
- Room generation failure: Logs error but continues

**Fatal Conditions:**
- Complete region exhaustion (no regions ever worked)
- Resource limits exceeded (terrains, regions, panels)
- Level/panel size mismatch

**Boundary Protection:**
- Map edges protected from most writes (unless Force or PRIO_MAX)
- Corridors force turn within 4 tiles of edge
- Corridors hard-clamp direction within 2-3 tiles of edge

### Created Files

- `edge-cases.md` - Comprehensive edge case specification with code snippets

### Verification Status Update

All edge cases now documented with source references. The "Edge cases are covered" verification item is complete.

---

## 2026-01-28: Implementation Review

### Files Analyzed

| File | Lines | Purpose |
|------|-------|---------|
| `src/dungeon/generator.jai` | 310 | BSP-based EXTENDED mode (not original) |
| `src/dungeon/makelev.jai` | 2474 | Original-style panel-based generation |
| `src/dungeon/map.jai` | 583 | Terrain types, map operations |
| `src/dungeon/weights.jai` | 399 | Room type and region weighted selection |

### Implementation Structure

The code has two generation modes:
- **EXTENDED**: BSP-based generation (not matching original)
- **ORIGINAL**: Panel-based generation via `generate_makelev()`

The ORIGINAL mode follows the correct 7-step structure from the spec.

### Key Findings

**What Matches the Spec:**
- 7-step generation structure (init, streamers, specials, panels, connect, fix-up, stairs)
- Fix-up tunneling with 26 trials
- Room type weighted selection algorithm
- Region selection with constraint filtering
- Cellular automata caves (WriteLifeCave)
- Most basic room types (RM_NORMAL, RM_CIRCLE, RM_CROSS, etc.)

**Critical Gaps:**
1. **Population system not implemented** - No monsters, items, or features
2. **RM_SHAPED rooms missing** - Can't render predefined room layouts
3. **Region terrain not applied** - All rooms use same floor/wall
4. **Traps not implemented** - Missing hazards
5. **Stairs oversimplified** - Single stair per room vs MIN/MAX_STAIRS

**Medium Priority Gaps:**
- Priority values differ from spec
- Corridor regions not used
- Door states incomplete (no locked/trapped)
- Some room types missing (RM_DESTROYED, RM_RANDTOWN, etc.)

### Created Files

- `implementation-review.md` - Comprehensive comparison table

### Next Steps

1. ~~Fix priority values to match spec exactly~~ **DONE**
2. Implement population system (basic monster placement first)
3. Add RM_SHAPED room type
4. Apply region terrain to rooms

---

## 2026-01-28: Priority Values Fixed

### Changes Made

Updated `src/dungeon/makelev.jai` priority constants to match Defines.h:4307-4320:

| Constant | Before | After |
|----------|--------|-------|
| PRIO_ROCK_STREAMER | 10 | 5 |
| PRIO_CORRIDOR_WALL | 20 | 10 |
| PRIO_ROOM_FLOOR | 50 | 70 |
| PRIO_VAULT | 80 | 90 |
| PRIO_FEATURE_FLOOR | 90 | 100 |
| PRIO_MAX | 100 | 120 |

Also added:
- PRIO_DEPOSIT = 110 (for treasure deposits)
- PRIO_RIVER_STREAMER moved to 90 (same as PRIO_VAULT, rivers cut through rooms)

### Verification

Code compiles successfully.

---

## 2026-01-28: Stair Placement Fixed

### Changes Made

Updated `src/dungeon/makelev.jai` to implement proper stair placement per MakeLev.cpp:1706-1743 and 1879-1900.

**Added structures and functions:**
- `StairPos` struct - tracks stair x, y, and room_index
- `find_room_at()` - find which room contains a position
- `place_up_stairs()` - place up-stairs at positions from level above
- `is_valid_stair_pos()` - check if position valid for down-stairs
- `place_down_stairs()` - place MIN_STAIRS to MAX_STAIRS down-stairs

**Updated `generate_makelev()` signature:**
```jai
generate_makelev :: (m: *GenMap, seed: u32,
                    above_down_stairs: [] StairPos = .[],
                    depth: s32 = 1,
                    max_depth: s32 = 10) -> down_stairs: [..] StairPos
```

**Behavior now matches spec:**
- Up-stairs placed at same coordinates as down-stairs from level above
- If up-stair position is in solid rock, carves 3x3 area (floor + walls)
- Down-stairs: MIN_STAIRS to MAX_STAIRS count (default 1-3)
- Valid down-stair location must be:
  - Not solid
  - Priority <= PRIO_ROOM_FLOOR
  - Not water, chasm, or lava
  - Not in a room that already has a stair
- 500 tries per stair, skip if can't place (graceful degradation)
- No down-stairs on last level (depth >= max_depth)

### Verification

Code compiles and tests pass.

---

## 2026-01-28: Trap Placement Implemented

### Changes Made

**Added to `src/dungeon/map.jai`:**
- `TRAP` terrain type (visible trap, glyph '^')
- `TRAP_HIDDEN` terrain type (hidden trap, looks like floor '.')

**Added to `src/dungeon/makelev.jai`:**
- `TRAP_CHANCE :: 73` constant (from Defines.h:3643)
- `is_door()` helper function
- `is_solid_not_door()` helper function
- `place_traps()` function implementing MakeLev.cpp:2155-2192

**Trap placement algorithm (per spec):**

1. **At doors:** `random(TRAP_CHANCE) <= DepthCR + 10`
   - Higher chance at deeper levels
   - In full implementation would set DF_TRAPPED flag

2. **At corridor bottlenecks:** `random(TRAP_CHANCE) <= (DepthCR + 2) / 3`
   - Bottleneck = walls on two opposite sides, open on other two
   - Places TRAP_HIDDEN terrain
   - Much lower chance than door traps (~1/3 base CR contribution)

**Called in generate_makelev as Step 6b** (after doors, before stairs).

### Notes

- DepthCR calculation simplified to just `depth` for now
- Full version uses: `INITIAL_CR + (Depth * DUN_SPEED) / 100 - 1`
- Door traps currently just counted (would need door flags support)
- Bottleneck traps place TRAP_HIDDEN terrain

### Verification

Code compiles and tests pass.

---

## 2026-01-28: Population System Implemented

### Changes Made

**Added to `src/dungeon/map.jai`:**
- `EntityPos` struct - tracks entity x, y, cr, and type_id
- `monsters: [..] EntityPos` array in GenMap
- `items: [..] EntityPos` array in GenMap
- Updated `map_init()` to reset new arrays
- Updated `map_free()` to free new arrays

**Added to `src/dungeon/makelev.jai`:**
- `max_monsters_by_cr()` - CR-based monster count caps (from Encounter.cpp:500-512)
- `monster_density_divisor()` - density calculation (from Encounter.cpp:545-549)
- `is_valid_entity_pos()` - validate placement position
- `has_monster_at()` / `has_item_at()` - check for existing entities
- `count_open_tiles()` - count walkable tiles
- `populate_dungeon()` - main population function

**Monster density formula (per spec):**
| Depth | Divisor | Monsters per N tiles |
|-------|---------|---------------------|
| 1 | 75 | 1 per 75 tiles |
| 2 | 50 | 1 per 50 tiles |
| 3+ | 30 | 1 per 30 tiles |

**Monster count caps by CR (maxAmtByCR):**
| CR | Max |
|----|-----|
| 1 | 5 |
| 2 | 7 |
| 3 | 10 |
| 4 | 12 |
| 5 | 15 |
| >5 | 50 |

**Out-of-depth monsters:** 22% chance, CR +1 to +3 above normal

**Item placement:**
- Base: 1 item per 100 open tiles (minimum 2)
- Rooms: 30% chance for 1-3 additional items per room

**Called in generate_makelev as Step 8** (after stairs).

### Verification

Code compiles and all 166 tests pass.

---

## Entry 17: Dungeon Test Demo (2026-01-28)

### Summary

Updated `src/dungeon_test.jai` to display the population system (monsters and items).

### Changes

**Color constant collision fix:**
- `src/terminal/window.jai` and `src/defines.jai` both defined color constants (BLACK, WHITE, etc.)
- Renamed terminal colors to use `TC_` prefix (TC_BLACK, TC_WHITE, TC_BRIGHT_RED, etc.)
- Removed redundant `#import` statements from window.jai (now provided by parent file)

**Display updates in dungeon_test.jai:**
- Added `monster_at()` and `item_at()` helper functions
- Monsters displayed as `M` in bright red
- Items displayed as `*` in bright yellow
- Added TRAP and LAVA terrain colors
- Status bar shows room/monster/item counts

### Test Results

```
Incursion Dungeon Test
======================
Loaded font: ../fonts/8x8.png (8x8 glyphs)
  Placed 12 traps on level 1
  Populated level 1: 5 monsters, 32 items (3003 open tiles)
Generated dungeon (ORIGINAL MakeLev) depth 1 with 8 rooms, 0 up-stairs, 1 down-stairs, 5 monsters, 32 items
Terminal: 80x25 cells
Dungeon: 80x50 tiles
```

**Phase 1 Complete:** Dungeons now have stairs, traps, monsters, and items.

---

*Future entries should be appended below*
