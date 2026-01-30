# Development Journal

## 2026-01-27: MVP Planning Session

### Direction Discussion
- Goal: Faithful port of Incursion with glyph terminal rendering
- MVP: Full dungeon generation with terminal view, inspectable by Claude
- Translation approach: Same logic, Jai idioms (no C++ baggage)

### Explored Jai Graphics Infrastructure
Found comprehensive support in `C:/Data/R/git/jai/modules/`:
- **Simp** - Immediate mode 2D rendering with font support
- **Window_Creation** - Cross-platform window management
- **Input** - Keyboard, mouse, gamepad events
- **GUI_Test** - Screenshot capture + synthetic input (for Claude testing)

### Created MVP Plan
See `PLAN-MVP.md` for detailed 6-phase plan:
1. Resource Baking (compile-time)
2. Dungeon Generator Core
3. Population System (monsters, items, features)
4. Terminal Renderer (Simp-based glyph display)
5. Inspection Interface (Claude-queryable)
6. Integration & Testing

### Memory Architecture Decision
Three-tier allocation strategy:
- **Static**: Baked resource tables (compile-time, in binary)
- **Persistent**: Game state arena (Map, Registry, object pools) - lives per dungeon
- **Temporary**: Per-frame work (glyph buffer, strings, scratch) - auto-reset

Key insight: Glyph buffer rebuilt each frame into temp memory. No persistent render state needed. Inspection output also temporary - consumed and discarded.

### Deep Dive: Useful Jai Modules Discovered

**Data Structures:**
- **Bucket_Array** - Stable handles even when growing. Perfect for Registry.
- **Hash_Table** - O(1) lookup for resource caching
- **Bit_Array** - 8x memory savings for FOV/explored maps

**Memory:**
- **Pool** - Block allocator with `reset()` for game-state lifetime
- **Flat_Pool** - Virtual memory backed, single pointer bump
- **Relative_Pointers** - Offsets instead of pointers, survives save/load

**RNG:**
- **PCG** - Better statistical properties than xorshift, good for reproducible generation
- **Hash** - `get_hash(seed, x, y)` for coordinate-based procedural content

**Dev Tools:**
- **Command_Line** - Struct → CLI args automatically
- **Iprof** - Profiling plugin, no manual instrumentation
- **Print_Vars** - `print_vars(x, y)` prints names + values
- **Debug** - Backtraces, crash dumps

**Save System Insight:**
Relative_Pointers allow save files to be mmap'd directly - pointers stored as offsets from themselves, valid at any load address. No serialization/deserialization pass needed.

---

## 2026-01-27: Parser Fixes for Real IRH Files

### Changes Made

1. **Added KW_PVAL handling to parse_effect** (parser.jai)
   - Effect properties like `pval: (LEVEL_1PER1)d8` are now parsed correctly
   - pval values are parsed as dice values using `parse_dice_value`

2. **Enhanced parse_dice_value for parenthesized expressions** (parser.jai)
   - Now handles dice count expressions like `(LEVEL_1PER1)d8`
   - Parenthesized expressions are evaluated via `parse_cexpr`

3. **Fixed parse_grant_ability for resource references** (parser.jai)
   - Added handling for `$"reference"` syntax in ability parameters
   - e.g., `Ability[CA_INNATE_SPELL,$"death touch"]`
   - Added `ability_ref` and `has_ability_ref` fields to ParsedGrant

4. **Fixed binary operator issue in grant parsing** (parser.jai)
   - Changed `parse_cexpr2` to `parse_cexpr3` in grant parsers
   - This prevents `CA_COMMAND_AUTHORITY,+1` from being parsed as addition
   - Affected: parse_grant_feat, parse_grant_ability, parse_grant_stati

5. **Added parameter support to parse_grant_feat** (parser.jai)
   - Now handles `Feat[FT_SCHOOL_FOCUS,SC_ENC]` syntax
   - Added `feat_param` and `has_feat_param` fields to ParsedGrant

6. **Made "level" keyword optional in grant level conditions** (parser.jai)
   - `at 10th` now works the same as `at 10th level`

### Test Results After Changes

- flavors.irh: **PASSED** (883 Flavors)
- enclist.irh: **PASSED** (87 Encounters)
- domains.irh: **PASSED** (43 Domains, 1 Effect)
- mundane.irh: FAILED (15 errors remaining)
- weapons.irh: FAILED (15 errors remaining)

### Files Modified

- `src/resource/parser.jai` - Grant parsing, effect parsing, dice parsing
- `src/tests.jai` - Added domain grant test case

---

## 2026-01-27: Terminal Renderer Implementation (Phase 4)

### Bitmap Font Rendering

Successfully implemented glyph-based terminal rendering using Incursion's original bitmap fonts.

**Key decisions:**
- Used original Incursion fonts from `repo-work/fonts/` (8x8, 12x16, 16x12, 16x16 PNG files)
- Bitmap fonts are simpler than TrueType for this use case
- Font files are 16x16 grids of glyphs in ASCII/CP437 order

**Simp module usage:**
- `Simp :: #import "Simp"` creates namespace binding (required pattern)
- `Input :: #import "Input"` for keyboard/window events
- `texture_load_from_file` to load PNG font atlas
- `set_shader_for_images` + `immediate_quad` with UV coords for glyph rendering
- `set_shader_for_color` + `immediate_quad` for background colors

**UV coordinate fix:**
- PNG has origin at top-left, OpenGL has V=0 at bottom
- Required flipping V coordinates: `v_top = (16 - row) / 16`, `v_bottom = (16 - row - 1) / 16`

### Files Created

- `src/terminal/window.jai` - Terminal struct, colors, cell management, rendering
- `src/terminal_test.jai` - Test program with dungeon room display
- `fonts/` - Copied bitmap fonts from original Incursion

### Test Result

Terminal test displays correctly with colored glyphs showing a test dungeon room.

---

## 2026-01-27: Dungeon Generator Implementation (Phase 2)

### BSP Dungeon Generation

Implemented Binary Space Partitioning (BSP) dungeon generator.

**Algorithm:**
1. Start with full map area as root BSP node
2. Recursively split nodes (prefer splitting longer dimension)
3. Create rooms in leaf nodes with random size/position
4. Connect rooms by finding rooms in left/right subtrees and carving corridors
5. Place doors where corridors meet room walls
6. Place stairs in first and last rooms

**Terrain types:**
- ROCK (solid, default fill)
- WALL (constructed walls around rooms)
- FLOOR (room interiors)
- CORRIDOR (passages between rooms)
- DOOR_CLOSED, DOOR_OPEN, DOOR_SECRET
- STAIRS_UP, STAIRS_DOWN
- WATER, CHASM (for future use)

**Original Incursion comparison:**
- Studied `MakeLev.cpp` - much more complex with panels, streamers, vaults
- Original uses weighted room/corridor types from dungeon definitions
- Our MVP uses simpler BSP but same core concept of rooms + corridors

### Files Created

- `src/dungeon/map.jai` - Map struct, Terrain enum, Rect, Room, map operations
- `src/dungeon/generator.jai` - BSP tree, room creation, corridor carving
- `src/dungeon_test.jai` - Interactive test with scrolling and regeneration

### Test Features

- Arrow keys to scroll viewport
- R to regenerate with new seed
- ESC to exit
- Status line shows depth, room count, controls

---

## 2026-01-27: Dungeon Generator Enhancements

### Room Shape Variety

Added multiple room shapes with weighted random selection:
- **Rectangle** (50%) - Standard rectangular rooms
- **Circle** (20%) - Circular rooms using distance formula
- **Octagon** (10%) - Rectangles with cut corners
- **Cross** (10%) - Cross-shaped rooms (needs 7x7 minimum)
- **Diamond** (10%) - Diamond using manhattan distance

### Terrain Features

- **Water pools** - 20% of rooms get small circular water pools
- **Rougher corridors** - 20% chance per corridor tile to expand into adjacent rock

### Files Modified

- `src/dungeon/map.jai` - Added RoomShape enum, shape-specific carving functions, water pools, corridor roughening
- `src/dungeon/generator.jai` - Weighted room shape selection, pool placement in generation loop

---

## 2026-01-27: RNG and Generator Mode Architecture

### Critical Decision: Original Compatibility

User raised important point: for faithful port, same RNG seed must produce identical dungeons.

**Original Incursion uses:**
- **MT19937 (Mersenne Twister)** - Full implementation in Base.cpp
- `random(max)` wrapper: `genrand_int32() % max`
- Global RNG state seeded with `init_genrand(seed)`

**Solution: Dual Generator Modes**

```jai
GeneratorMode :: enum {
    ORIGINAL;   // Exact Incursion replication (MT19937, same algorithm)
    EXTENDED;   // Enhanced version with more variety
}
```

- **EXTENDED** (default): Our enhanced BSP generator with room variety
- **ORIGINAL**: Uses MT19937, will eventually replicate MakeLev.cpp exactly

### MT19937 Implementation

Created `src/rng.jai` with exact MT19937 matching Incursion's Base.cpp:
- Same constants (N=624, M=397, MATRIX_A, etc.)
- Same initialization (`init_genrand` → `mt_seed`)
- Same generation (`genrand_int32` → `mt_genrand_u32`)
- Same random wrapper (`random(max)` → `mt_random`)

### Current Status

- EXTENDED mode: Full-featured with room shapes, water, corridors
- ORIGINAL mode: Placeholder using MT19937 (needs exact MakeLev.cpp translation)

### Files Created/Modified

- `src/rng.jai` - MT19937 implementation matching original Incursion
- `src/dungeon/generator.jai` - Added GeneratorMode, dual generate functions
- `src/dungeon_test.jai` - M key toggles between modes

### Next Steps for ORIGINAL Mode

To achieve identical dungeons given same seed:
1. Study MakeLev.cpp panel/room system in detail
2. Translate room weight selection exactly
3. Match tunnel/corridor algorithm
4. Match door/stair placement order
5. Match all random() call sequences

---

## 2026-01-27: MakeLev Translation Progress

### Room Types Implemented

Created `src/dungeon/makelev.jai` with panel-based dungeon generation:

**Room drawing functions:**
- `write_room` - Rectangular room with walls (RM_NORMAL, RM_LARGE)
- `write_circle` - Circular room (RM_CIRCLE, RM_LCIRCLE)
- `write_octagon` - Octagonal room with cut corners (RM_OCTAGON)
- `write_cross` - Cross-shaped room (RM_CROSS)
- `write_lifecave` - Cellular automata cave generation (RM_LIFECAVE)
- `write_overlap` - 2-4 overlapping rectangles (RM_OVERLAP)

**Cellular Automata (RM_LIFECAVE):**
- Translated from original WriteLifeCave()
- 45% initial rock probability
- 20 iterations of Game-of-Life variant rules
- 5+ wall neighbors = become wall
- 3 or fewer wall neighbors = become open

**Generation structure:**
- `DungeonConstants` - Level/panel/room size parameters
- `GenState` - Generation state (panels_drawn, rooms_touched, etc.)
- `draw_panel` - Draws a room in a panel based on random type selection
- `connect_panels` - L-shaped corridors between adjacent panels
- `generate_makelev` - Main entry point

### Room Type Distribution (ORIGINAL mode)

| Roll | Room Type |
|------|-----------|
| 0-21 | RM_NORMAL (22%) |
| 22-33 | RM_CIRCLE (12%) |
| 34-41 | RM_OCTAGON (8%) |
| 42-49 | RM_CROSS (8%) |
| 50-57 | RM_LARGE (8%) |
| 58-64 | RM_OVERLAP (7%) |
| 65-71 | RM_ADJACENT/AD_ROUND/AD_MIXED (7%) |
| 72-77 | RM_PILLARS (6%) |
| 78-83 | RM_DOUBLE (6%) |
| 84-89 | RM_MAZE (6%) |
| 90-99 | RM_LIFECAVE (10%) |

### Features Implemented

**Room Types (16 total):**
- [x] RM_NORMAL - Basic rectangular room
- [x] RM_CIRCLE - Circular room
- [x] RM_OCTAGON - Room with cut corners
- [x] RM_CROSS - Cross-shaped room
- [x] RM_LARGE - Larger rectangular room
- [x] RM_OVERLAP - 2-4 overlapping rectangles
- [x] RM_ADJACENT/RM_AD_ROUND/RM_AD_MIXED - Four-quadrant rooms
- [x] RM_PILLARS - Room with pillar grid
- [x] RM_DOUBLE - Room within room with interior doors
- [x] RM_MAZE - Recursive backtracker maze
- [x] RM_CHECKER - Checkerboard pattern
- [x] RM_DIAMONDS - Grid of diamond shapes
- [x] RM_CASTLE/RM_BUILDING - Recursively subdivided with internal walls
- [x] RM_RCAVERN - Repeated L-shapes rough caverns
- [x] RM_LIFECAVE - Cellular automata caverns

**Corridor Algorithm:**
- [x] Advanced tunnel with segment lengths (SEGMENT_MIN_LEN, SEGMENT_MAX_LEN)
- [x] Turn chance after minimum segment (TURN_CHANCE = 25%)
- [x] Direction correction toward destination
- [x] Stubborn corridor chance (random turns instead of direct)
- [x] Force turn near map edges
- [x] Wall generation around corridor path

**Other Features:**
- [x] Streamers (water rivers, chasms - 30% chance per level)
- [x] Door placement (70% closed, 20% open, 10% secret)
- [x] Stair placement (up in first room, down in last room)

### Room Type Distribution (Final)

| Roll | Room Type |
|------|-----------|
| 0-17 | RM_NORMAL (18%) |
| 18-25 | RM_CIRCLE (8%) |
| 26-32 | RM_OCTAGON (7%) |
| 33-39 | RM_CROSS (7%) |
| 40-46 | RM_LARGE (7%) |
| 47-52 | RM_OVERLAP (6%) |
| 53-58 | RM_ADJACENT variants (6%) |
| 59-63 | RM_PILLARS (5%) |
| 64-68 | RM_DOUBLE (5%) |
| 69-73 | RM_MAZE (5%) |
| 74-77 | RM_CHECKER (4%) |
| 78-81 | RM_DIAMONDS (4%) |
| 82-87 | RM_CASTLE (6%) |
| 88-93 | RM_RCAVERN (6%) |
| 94-99 | RM_LIFECAVE (6%) |

### Still TODO for Full MakeLev Compatibility

- [ ] Weighted room selection from dungeon definition resources
- [x] TT_CONNECT flag for corridor termination
- [x] Room touching detection during tunnel
- [ ] More streamer types based on region definitions
- [ ] Vault placement (special pre-designed rooms)

---

## 2026-01-27: Flood-Fill Connectivity and Tunnel Flags

### Problem: Disconnected Dungeon Regions

The dungeon generator was creating rooms that could be completely isolated from each other.
The original Incursion uses a flood-fill connectivity algorithm to ensure all passable areas
are reachable.

### Changes Made

1. **Added Tunnel Termination Flags (TT_*)**
   ```
   TT_CONNECT   :: 0x01  // Terminate when Connected flag differs from start
   TT_DIRECT    :: 0x02  // Always take most direct route
   TT_LENGTH    :: 0x04  // Terminate if length exceeds value
   TT_NOTOUCH   :: 0x08  // Don't "touch" rooms
   TT_EXACT     :: 0x10  // Go to exact destination
   TT_WANDER    :: 0x20  // Chance to end after touching 2+ rooms
   TT_NATURAL   :: 0x40  // Curved, natural tunnels
   ```

2. **Added Priority System for Terrain Writing**
   - `PRIO_EMPTY` (0) through `PRIO_MAX` (100)
   - Higher priority terrain overwrites lower (unless forced)
   - Matches original's Memory-based priority tracking

3. **Added Per-Cell Generation Info (CellInfo)**
   - `priority: u8` - What wrote this cell
   - `connected: bool` - Part of main dungeon?
   - `solid: bool` - Is cell impassable?

4. **Implemented Flood-Fill Connectivity (flood_connect)**
   - Stack-based iterative flood fill (avoids recursion limits)
   - Marks all tiles reachable from a starting point
   - Treats doors as passable for connectivity

5. **Implemented Fix-Up Tunneling (fixup_tunneling)**
   - Finds edge tiles of connected and unconnected regions
   - Repeatedly tunnels from connected to nearest unconnected
   - Re-floods after each tunnel to update connectivity
   - Maximum 26 trials (same as original)

6. **Enhanced carve_tunnel to Support TT_FLAGS**
   - TT_CONNECT: Stop when reaching connected/unconnected boundary
   - TT_WANDER: Probabilistic stop after touching 2+ rooms
   - TT_DIRECT: Always correct toward destination
   - TT_NOTOUCH: Don't track room touching during traversal
   - TT_EXACT: Go to precise coordinates

### Test Results

- Dungeon generator compiles and runs successfully
- All rooms are now connected (verified by fix-up tunneling)
- Typical output: "Generated dungeon (ORIGINAL MakeLev) with 8 rooms, 8 panels"

### Files Modified

- `src/dungeon/makelev.jai` - All changes in this file:
  - Added TT_* flags and PRIO_* constants
  - Added CellInfo, MapGenInfo, Point structs
  - Added flood_connect, clear_connected, find_disconnected_regions, fixup_tunneling
  - Enhanced carve_tunnel with tflags parameter
  - Added get_cell, is_solid, dist helper functions
  - Updated write_at to support priority checking
  - Updated generate_makelev to call fixup_tunneling

### Architecture Notes

The flood-fill connectivity algorithm works as follows:
1. After initial room placement and basic corridor connection
2. Clear all connected flags
3. Find first open tile, flood fill from there to mark "connected" region
4. Find edge tiles (open tiles adjacent to solid) in both connected and unconnected areas
5. Find closest pair of connected-to-unconnected edge tiles
6. Carve a tunnel between them with TT_DIRECT | TT_WANDER flags
7. Re-flood to update connectivity
8. Repeat until no unconnected regions remain (or 26 trials)

---

## 2026-01-27: Enhanced Streamers and Vault System

### Streamer Type System

Added proper typed streamers matching the original's region-based system:

**StreamerType enum:**
- `WATER_RIVER` - Wide water crossing from edge (is_river=true)
- `WATER_STREAM` - Narrower water feature
- `CHASM` - Bottomless pit with minimum width 4
- `LAVA_RIVER` - Uses CHASM terrain for now (depth 5+)
- `RUBBLE` - Collapsed area (placeholder)

**StreamerInfo struct:**
- `terrain` - What terrain type to place
- `is_river` - Rivers start from edge with constant width
- `min_width` / `max_width` - Width range
- `priority` - PRIO_RIVER_STREAMER for rivers/chasms, PRIO_ROCK_STREAMER for others

**Distribution (when streamer placed):**
| Roll | Type |
|------|------|
| 0-34 | WATER_RIVER (35%) |
| 35-54 | CHASM (20%) |
| 55-74 | WATER_STREAM (20%) |
| 75-89 | LAVA_RIVER (15%, depth 5+) |
| 90-99 | RUBBLE (10%) |

### Vault System (Pre-Designed Rooms)

Added basic vault (special room) placement system:

**VaultDef struct:**
- `name` - Identifier
- `width` / `height` - Dimensions
- `map_data` - ASCII art map string
- `min_depth` - Minimum dungeon depth

**Vault characters:**
- `#` = wall, `.` = floor, `+` = door
- `~` = water, `>` = stairs down, `<` = stairs up

**Initial vaults:**
1. `treasure_room` (7x5) - Small room with stairs, depth 3+
2. `water_shrine` (9x7) - Room with water pool, depth 2+
3. `guard_post` (9x9) - Four-quadrant guard post, depth 1+

**Placement:**
- 20% base chance + 5% per dungeon depth
- Tries 50 random positions, must fit and not overlap existing rooms
- Vaults use PRIO_VAULT (80) - higher than rooms, lower than map edges

### Files Modified

- `src/dungeon/makelev.jai`:
  - Added PRIO_RIVER_STREAMER constant
  - Added StreamerType enum and STREAMER_INFO array
  - Added VaultDef struct and VAULTS array
  - Enhanced write_streamer() to use StreamerType
  - Added write_vault() and try_place_vault() functions
  - Updated generate_makelev() to use new systems

### Updated TODO

- [x] TT_CONNECT flag for corridor termination
- [x] Room touching detection during tunnel
- [x] More streamer types based on region definitions
- [x] Vault placement (basic system)
- [ ] Weighted room selection from dungeon definition resources (requires full resource system)
- [x] More vault designs
- [x] Lava terrain type for proper lava rivers

---

## 2026-01-27: LAVA Terrain and Expanded Vaults

### LAVA Terrain Type

Added proper LAVA terrain type to support lava rivers:

**Changes to `src/dungeon/map.jai`:**
- Added `LAVA` to Terrain enum
- Added glyph `~` for lava (same as water, will be colored differently by renderer)

**Changes to `src/dungeon/makelev.jai`:**
- Updated STREAMER_INFO to use `.LAVA` instead of `.CHASM` for lava rivers
- Made lava rivers behave like water rivers (`is_river=true`) starting from map edge
- Added vault character support: `^` = lava, `_` = chasm

### Expanded Vault System

Added 9 new vault designs (12 total):

| Vault | Size | Min Depth | Description |
|-------|------|-----------|-------------|
| treasure_room | 7x5 | 3 | Small room with stairs down |
| water_shrine | 9x7 | 2 | Room with central water pool |
| guard_post | 9x9 | 1 | Four-quadrant room with doors |
| arena | 11x9 | 2 | Open fighting area with central pillar |
| library | 11x9 | 3 | Shelves represented by wall columns |
| throne_room | 11x7 | 4 | Throne area with decorative walls |
| prison | 11x7 | 3 | Row of cells with doors |
| lava_chamber | 9x7 | 5 | Diamond-shaped lava pool with walkway |
| chasm_bridge | 11x7 | 4 | Bridge over chasms |
| altar_room | 9x9 | 2 | Altar with water corners |
| pillared_hall | 13x9 | 2 | Large hall with support columns |
| crossroads | 9x9 | 1 | Four-way intersection room |

### Files Modified

- `src/dungeon/map.jai` - Added LAVA terrain type and glyph
- `src/dungeon/makelev.jai` - Updated streamer info, added vault characters, expanded VAULTS array

### Remaining TODO

- [x] Weighted room selection from dungeon definition resources

---

## 2026-01-27: Weighted Room Selection Implementation

### Overview

Implemented Incursion-compatible weighted room and region selection for exact dungeon replication - same RNG seed should produce identical dungeons to original Incursion.

### Two-Tier Selection System

The original uses:
1. **Room Type Selection**: Cumulative weight algorithm picks room shape (RM_NORMAL, RM_CAVE, etc.)
2. **Region Selection**: Constraint filtering picks appearance (walls, floors, monsters)

### Parser Extensions

**New structures in `src/resource/parser.jai`:**
- `WeightListEntry` - Entry in a weight list (weight, value, is_ref, ref_name, macro support)
- `ParsedWeightList` - List with type (RM_WEIGHTS, WALL_COLOURS, ENCOUNTER_LIST, etc.)

**Extended `ParsedRegion`:**
- `has_walls`, `walls` - Wall terrain reference ($"Dungeon Wall")
- `has_door`, `door` - Door feature reference ($"oak door")
- `has_room_types`, `room_types` - RM_* bitmask for supported room types
- `has_size`, `size` - Size constraint (SZ_* constant)
- `flags` - Region flags (RF_VAULT, RF_CORRIDOR, RF_STAPLE, etc.)
- `lists` changed from `ParsedList` to `ParsedWeightList`
- `constants` - Constants section

**Extended `ParsedDungeon`:**
- `lists` - Weight lists for dungeon-level configuration

**New `parse_lists_section` function:**
- Parses `Lists:` sections with `*` markers for each list
- Handles weight-value pairs (numbers set weight, constants/refs are entries)
- Supports macro calls like `CONSTRAINED_ENC($"name", MA_AQUATIC)`
- Handles color words, RM_* constants, and resource references

### Runtime Selection System

**New file `src/dungeon/weights.jai`:**

**RuntimeRegion struct:**
- Resolved region with room_types bitmask, depth, flags, terrain references

**DungeonWeights container:**
- `rm_types`/`rm_weights` - Room type weights (from RM_WEIGHTS list or defaults)
- `room_regions`, `corridor_regions`, `vault_regions` - Categorized regions

**SelectionState (per-level):**
- Mutable copy of weights (modified during level)
- `used_regions` - Track regions used this level (prevent repeats unless RF_STAPLE)
- `depth_cr`, `min_vault_depth` - Dungeon depth info

**Selection Algorithms:**
- `select_room_type()` - Cumulative weight selection, resets weights when all exhausted
- `select_region()` - Constraint filtering (RoomTypes, Depth, RF_VAULT, RF_NOGEN, uniqueness)
- `select_corridor()` - Frequency expansion for corridor regions

**Default room type weights (from original MakeLev.cpp):**
```
RM_NORMAL: 10, RM_NOROOM: 1, RM_LARGE: 1, RM_CROSS: 1, RM_OVERLAP: 1,
RM_ADJACENT: 1, RM_AD_ROUND: 2, RM_AD_MIXED: 2, RM_CIRCLE: 4, RM_OCTAGON: 5,
RM_DIAMONDS: 4, RM_DOUBLE: 2, RM_PILLARS: 3, RM_CHECKER: 1, RM_BUILDING: 3,
RM_GRID: 1, RM_LIFECAVE: 10, RM_RCAVERN: 4, RM_MAZE: 2, RM_LCIRCLE: 1, RM_SHAPED: 2
```

### Generator Integration

**Extended `GenState` in `src/dungeon/makelev.jai`:**
- `dungeon_weights` - Weight configuration for current dungeon
- `selection` - Per-level selection state
- `current_region` - Currently selected region for room appearance

**Modified `gen_state_init()`:**
- Takes optional `depth` parameter
- Initializes dungeon weights and selection state

**Modified `draw_panel()`:**
- Replaced hardcoded probability table with weighted selection
- Tries up to 200 times to find valid room type + region combination
- Falls back gracefully when no regions defined

### Code Cleanup

- Renamed dungeon's `Map` to `GenMap` to avoid conflict with core `Map` struct
- Removed duplicate `Dir` enum and `DirX`/`DirY` arrays from makelev.jai (use defines.jai versions)
- Removed redundant `#import` statements from loaded files
- Fixed `Random.` namespacing issues in dungeon module

### Test Results

- All existing tests pass (163/165, 2 pre-existing failures in mundane.irh and weapons.irh)
- Added dungeon.irh to test suite (has errors due to other unimplemented features, not weighted selection)

### Files Created/Modified

- `src/dungeon/weights.jai` - **NEW** - RuntimeRegion, DungeonWeights, SelectionState, selection algorithms
- `src/resource/parser.jai` - Added WeightListEntry, ParsedWeightList, extended ParsedRegion/ParsedDungeon, implemented parse_lists_section
- `src/dungeon/makelev.jai` - Added weight fields to GenState, replaced hardcoded selection
- `src/dungeon/map.jai` - Renamed Map to GenMap
- `src/dungeon/generator.jai` - Updated for GenMap, removed redundant loads
- `src/main.jai` - Added loads for rng.jai and dungeon modules
- `src/rng.jai` - Removed redundant import
- `src/tests.jai` - Added dungeon.irh test

---

## 2026-01-28: Parser Fixes for mundane.irh and weapons.irh

### Issues Fixed

1. **Optional colons for properties** (Grammar alignment)
   - Grammar shows `(':')? ` (optional colon) for many properties
   - Our parser was requiring colons, causing failures
   - Fixed `Level`, `Group`, and `Mat` properties to use `optional_colon(p)`
   - weapons.irh now passes (was failing on `Group WG_SIMPLE | ...`)

2. **Preprocessor alias macros** (main.irc #define support)
   - Original uses `#define Potion AI_POTION` etc. in main.irc
   - Added `lookup_preprocessor_alias()` in constants.jai
   - Aliases: Potion (1), Scroll (2), Wizard (50), Priest (52), Witch (55), Druid (53), Sorcerer (51)
   - Lexer now tokenizes these as CONSTANT tokens with correct values

3. **Compound resource types** (effect sources)
   - Grammar: `effect_def: ( cexpr3<n> ('/')? )* (SPELL | EFFECT ...) LITERAL ...`
   - Added `parse_effect_with_sources()` for syntax like `Potion Effect "flask of oil"`
   - Parser dispatch now checks if CONSTANT token is followed by EFFECT/SPELL keyword
   - mundane.irh now passes (was failing on `Potion Effect "flask of oil"`)

### Test Results After Fixes

| File | Status | Resources |
|------|--------|-----------|
| flavors.irh | PASS | 883 Flavors |
| mundane.irh | PASS | 72 Items, 1 Effect |
| domains.irh | PASS | 43 Domains, 1 Effect |
| weapons.irh | PASS | 118 Items |
| enclist.irh | PASS | 87 Encounters |
| dungeon.irh | FAIL | Global vars + refs in Constants |

**Result: 165/166 tests pass (1 remaining failure: dungeon.irh)**

### Files Modified

- `src/resource/parser.jai`:
  - Added `optional_colon()` helper function
  - Made colons optional for Level, Group, Mat in item parsing
  - Added `parse_effect_with_sources()` for compound effect syntax
  - Updated main parse dispatch to detect CONSTANT + EFFECT patterns

- `src/resource/lexer.jai`:
  - Added call to `lookup_preprocessor_alias()` before returning plain IDENTIFIER

- `src/resource/constants.jai`:
  - Added `lookup_preprocessor_alias()` function with 7 aliases
  - Added `strings_equal()` helper for exact string matching

### Remaining Issue: dungeon.irh

dungeon.irh fails due to:
1. Line 5: Global variable declarations (`int16 murgash_killed;`)
2. Line 14+: `$"ref"` resource references in Constants section expressions

---

## 2026-01-28: dungeon.irh Parsing Complete

### Issues Fixed (continued from earlier session)

1. **KW_MOV vs KW_MOVE mismatch**
   - Lexer tokenized "mov" as KW_MOV (243), "move" as KW_MOVE (524)
   - Terrain/Feature parsers only checked for KW_MOVE
   - Fixed by checking `tok.type == .KW_MOVE || tok.type == .KW_MOV`

2. **Effect `and` continuation blocks**
   - Grammar: `edef_body : abil_def | edef_body 'and' abil_def`
   - Effects can have multiple ability blocks: `Effect ... : EA_GENERIC { ... } and EA_TERRAFORM { ... }`
   - Added while loop after effect body to handle `and EA_*` continuations

3. **Color alias "skyblue"**
   - Lexer had "sky" but not "skyblue" as KW_SKY
   - Fixed: `if lower_str == "sky" || lower_str == "skyblue" return .KW_SKY;`

4. **Flags separator: pipe support**
   - Some files use `|` instead of `,` for flag separation
   - Fixed parse_flags_list: `if !match(p, .COMMA) && !match(p, .PIPE) break;`

5. **Multi-line #define macros**
   - WATER_COMBAT macro spans 40+ lines with backslash continuations
   - Lexer only skipped to newline, treating macro body as code
   - Fixed preprocessor skip to track backslash continuations and skip entire macro

6. **Bare numbers in Image specs**
   - `Image: red 8;` uses bare `8` instead of `'8'` character constant
   - Added NUMBER token support in parse_glyph_image

### Test Results After Fixes

| File | Status | Resources |
|------|--------|-----------|
| flavors.irh | PASS | 883 Flavors |
| mundane.irh | PASS | 72 Items, 1 Effect |
| domains.irh | PASS | 43 Domains, 1 Effect |
| weapons.irh | PASS | 118 Items |
| enclist.irh | PASS | 87 Encounters |
| dungeon.irh | PASS | 5 Items, 4 Monsters, 3 Effects, 27 Features, 51 Terrains, 91 Regions, 3 Dungeons |

**Result: 166/166 tests pass!**

### Files Modified

- `src/resource/parser.jai`:
  - Fixed KW_MOVE/KW_MOV check in terrain/feature parsing
  - Added `and` continuation block handling for effects
  - Added pipe `|` support in parse_flags_list
  - Added NUMBER token support in parse_glyph_image

- `src/resource/lexer.jai`:
  - Added "skyblue" alias for KW_SKY
  - Fixed preprocessor handling for multi-line macros with backslash continuation

---

## Session: 2026-01-28 (Dungeon Generation Phase 1 Complete)

### Summary

Implemented missing dungeon generation features and got the dungeon test demo working.

### Changes

**Priority values (makelev.jai):**
- Fixed PRIO_ROCK_STREAMER: 10 → 5
- Fixed PRIO_CORRIDOR_WALL: 20 → 10
- Fixed PRIO_ROOM_FLOOR: 50 → 70
- Added PRIO_DEPOSIT: 110

**Stair placement (makelev.jai):**
- Added StairPos struct for tracking stair positions
- Added place_up_stairs() - carves up-stairs at previous level's down-stair positions
- Added place_down_stairs() - places MIN_STAIRS to MAX_STAIRS down-stairs
- Updated generate_makelev signature to accept/return stair positions

**Trap placement (makelev.jai, map.jai):**
- Added TRAP and TRAP_HIDDEN terrain types
- Added place_traps() - places traps at doors and corridor bottlenecks
- Door trap chance: random(73) <= DepthCR + 10
- Bottleneck trap chance: random(73) <= (DepthCR + 2) / 3

**Population system (makelev.jai, map.jai):**
- Added EntityPos struct and monsters/items arrays to GenMap
- Monster density: OpenC/30 (depth>2), OpenC/50 (depth=2), OpenC/75 (depth=1)
- Monster count caps by CR: 5/7/10/12/15/50
- Item placement: 1 per 100 tiles + room bonus
- 22% out-of-depth monster chance

**Dungeon test demo (dungeon_test.jai, window.jai):**
- Fixed color constant collision (TC_ prefix for terminal colors)
- Monsters displayed as 'M' (bright red)
- Items displayed as '*' (bright yellow)
- Status bar shows room/monster/item counts

### Test Results

```
Placed 12 traps on level 1
Populated level 1: 5 monsters, 32 items (3003 open tiles)
Generated dungeon (ORIGINAL MakeLev) depth 1 with 8 rooms, 0 up-stairs, 1 down-stairs
```

All 166 tests pass. Dungeon test executable runs and displays populated dungeon.

## 2026-01-28: Phase 2 - Region Terrain Visual Variety

### Goal
Rooms use terrain from their region instead of hardcoded defaults, producing correct visual variety.

### Implementation

**New file: `src/dungeon/terrain_registry.jai`**
- `RuntimeTerrain` struct: name, glyph, fg_color, is_solid, is_opaque
- `TerrainRegistry` with `Table(string, *RuntimeTerrain)` for lookup by name
- `create_default_terrains()` - creates 14 default terrain types (floor, wall, shallow water, ice wall, etc.)
- `terrain_color_to_rgb()` - converts ANSI color constants to RGB Color

**Modified `src/dungeon/weights.jai`**
- Added `floor_terrain` and `wall_terrain` pointers to `RuntimeRegion`
- Added `resolve_region_terrains()` to resolve terrain name references to pointers
- Added `get_region_floor()` and `get_region_wall()` helpers with fallback to default
- Added `add_test_regions()` with 6 test regions for variety demonstration:
  - Stone Room (default)
  - Icy Chamber (ice floor + ice wall)
  - Flooded Chamber (shallow water + stone wall)
  - Overgrown Chamber (moss-covered floor + granite wall)
  - Marble Hall (marble floor + granite wall)
  - Dirt Cavern (dirt floor + stone wall)

**Modified `src/dungeon/map.jai`**
- Added `TileDisplay` struct: glyph, fg_color, use_custom flag
- Added `tile_display` array to `GenMap` (parallel to tiles)
- Added `map_set_with_display()` and `map_get_display()` functions

**Modified `src/dungeon/makelev.jai`**
- Added `terrain_registry`, `default_floor`, `default_wall` to `GenState`
- Added `write_at_with_terrain()` function
- Updated all write_* functions (write_room, write_circle, write_octagon, etc.) to use region terrain
- Call `resolve_region_terrains()` in `gen_state_init()`

**Modified `src/dungeon_test.jai`**
- Added `#load "dungeon/terrain_registry.jai"`
- Rendering now checks `tile_display.use_custom` and uses custom glyph/color when set

### Verification

Test output shows different regions being selected for each panel:
```
Panel (0,0) uses region: Overgrown Chamber
Panel (1,0) uses region: Marble Hall
Panel (2,0) uses region: Icy Chamber
Panel (3,0) uses region: Dirt Cavern
Panel (0,1) uses region: Overgrown Chamber
Panel (1,1) uses region: Stone Room
Panel (2,1) uses region: Flooded Chamber
Panel (3,1) uses region: Icy Chamber
```

Each room now renders with the correct terrain appearance based on its selected region.

---

## 2026-01-28: GitHub Publishing Preparation

### README and Screenshot

Created `README.md` for GitHub with:
- Project overview: porting Incursion from C++ to Jai
- Motivation: moving away from modaccent (1980's code generator), 32-bit assumptions, vendored deps
- Development approach: Claude Code with no access to official Jai docs (only compiler executable)
- Links to PLAN-MVP.md and JOURNAL.md for status tracking
- License clarification: upstream BSD/Apache/Expat + OGL applies, our code MIT

Created headless screenshot tool `tools/dungeon_screenshot.jai`:
- Uses stb_image to load font PNG
- Renders dungeon directly to pixel buffer (no window/OpenGL)
- Uses stb_image_write to save PNG
- Generated 10 variations with different seeds
- Selected one with water river for visual interest

### Tools Reorganization

Moved development tools from `src/` to `tools/`:
- `dungeon_test.jai` - Interactive windowed dungeon viewer
- `dungeon_screenshot.jai` - Headless screenshot generator
- `terminal_test.jai` - Terminal rendering test

Updated all `#load` paths to use `../src/` prefix.
Updated font/output paths for new directory structure.
Build artifacts (`.build/`, `*.exe`, `*.pdb`) already gitignored.

### Code Fixes

**terrain_registry.jai Color dependency:**
- Added `TerrainColor` struct to make module self-contained
- Changed `terrain_color_to_rgb()` to return `TerrainColor` instead of `Color`
- Updated `dungeon_test.jai` to convert `TerrainColor` to `Color`

**main.jai missing load:**
- Added `#load "dungeon/terrain_registry.jai"` to fix build

### Files Created

- `README.md` - GitHub project overview with screenshot
- `LICENSE` - MIT license with note about upstream licenses
- `docs/screenshot.png` - Dungeon generation screenshot
- `tools/dungeon_screenshot.jai` - Headless screenshot tool

### Files Modified

- `CLAUDE.md` - Updated project structure with tools/, docs/, dungeon/ subdirs
- `.gitignore` - Added `build/` directory
- `src/main.jai` - Added terrain_registry.jai load
- `src/dungeon/terrain_registry.jai` - Added TerrainColor struct, self-contained
- `tools/dungeon_test.jai` - Updated paths, TerrainColor conversion
- `tools/terminal_test.jai` - Updated paths

### Verification

All builds pass:
- `src/main.jai` - 166 tests pass
- `tools/dungeon_test.jai` - Builds and runs
- `tools/dungeon_screenshot.jai` - Generates screenshot correctly

### Repository Cleanup

**License files restructured:**
- `LICENSE` - Explains dual licensing, contains MIT for our contributions
- `LICENSE-INCURSION` - Copied from upstream repo (BSD/Apache/Expat + OGL)

**Files deleted:**
- `RECONSTRUCTION*.md` (4 files) - Recovery docs now obsolete, code is source of truth
- `extract_constants.py` - One-time generator, constants.jai already exists

**Files moved:**
- `assignment/` → `docs/research/` - Research notes under clearer path

**Documentation updates:**
- Added Jai compiler version (`beta 0.2.025`) to README.md and CLAUDE.md
- Added directive #7 to CLAUDE.md: check compiler version at session start, ask about language changes if different

---

## 2026-01-28: Phase 5 - Inspection Interface (CLI Tool)

### Overview

Implemented `tools/inspect.jai` - a CLI tool for programmatic dungeon inspection and Claude-driven testing.

### Features

**CLI Flags:**
- `--seed N, -s N` - Set RNG seed (default: 12345)
- `--depth N, -d N` - Set dungeon depth (default: 1)
- `--mode MODE, -m` - Generator mode: ext/extended or ori/original
- `--batch CMD, -b` - Run single command and exit
- `--quiet, -q` - Suppress generation messages for clean output
- `--help, -h` - Show help

**Interactive Commands:**
- `dump` / `dump json` - ASCII or JSON map output
- `query X,Y` / `query X,Y json` - Cell contents at coordinates
- `stats` / `stats json` - Dungeon statistics
- `rooms` / `monsters` / `items` - List entities
- `seed [N]` / `depth [N]` / `mode [ext|ori]` - Get/set parameters
- `generate` - Regenerate with current settings
- `help` / `quit` - Help and exit

**JSON Output:**
All commands support JSON mode for programmatic parsing:
```json
{
  "seed": 12345,
  "depth": 1,
  "mode": "original",
  "width": 80,
  "height": 50,
  "rooms": 8,
  "monsters": 5,
  "items": 15,
  ...
}
```

### Changes

**Files Created:**
- `tools/inspect.jai` - Main inspection tool

**Files Modified:**
- `src/dungeon/generator.jai` - Added depth parameter to `generate_dungeon`
- `src/dungeon/makelev.jai` - Added `makelev_quiet` flag for silent generation
- `CLAUDE.md` - Removed directive #7 (Jai version check)

### Usage Examples

```bash
# Quick stats in JSON
./inspect.exe --quiet --batch "stats json"

# Dump map with specific seed
./inspect.exe --quiet --seed 99999 --batch "dump"

# Query a specific cell
./inspect.exe --quiet --batch "query 10,10 json"

# Interactive mode
./inspect.exe
> stats
> query 5,5
> generate
> dump
> quit
```

### Test Results

All 166 existing tests pass. Inspect tool builds and runs correctly.

---

## 2026-01-28: Dungeon Generation Enhancements (Correctness Research Implementation)

### Overview

Implemented all outstanding dungeon enhancements identified in `docs/research/correctness-research/` and `docs/research/specs/`.

### Room Types Added

**RM_SHAPED (`write_shaped`):**
- Uses predefined vault definitions with ASCII art maps
- Supports horizontal and vertical flip for variety
- Vault characters: `#`=wall, `.`=floor, `+`=door, `~`=water, `^`=lava, `_`=chasm

**RM_DESTROYED (`write_destroyed`):**
- Post-apocalyptic room appearance
- 10% rock, 30% rubble terrain, rest floor
- Creates partially collapsed room effect

**RM_GRID (`write_grid`):**
- Furnishing grid pattern
- 2x2 pillar blocks with 3-tile spacing
- 5% chance each pillar is missing (variation)

**RM_LIFELINK (`write_lifelink`):**
- Linked caves using cellular automata
- Similar to RM_LIFECAVE but fills entire panel
- Creates organic cavern appearance

### Corridor Edge Clamping

Implemented in `carve_tunnel()`:
- 4-tile lookahead before map edge forces turn
- 2-3 tile hard clamp at map boundaries
- Prevents corridors from hitting map edges

### Treasure Deposits

**`place_treasure_deposits()`:**
- Places hidden treasure in fully-enclosed rock areas
- Scans for rock tiles completely surrounded by rock
- Depth-based chance calculation
- Creates discoverable secrets via mining/detection

### Door State System

**New DoorInfo struct in `map.jai`:**
```jai
DF_VERTICAL :: 0x01;  // Door orientation
DF_OPEN     :: 0x02;  // Door is open
DF_STUCK    :: 0x04;  // Door is stuck
DF_LOCKED   :: 0x08;  // Door is locked
DF_TRAPPED  :: 0x10;  // Door is trapped
DF_SECRET   :: 0x20;  // Secret door
DF_BROKEN   :: 0x40;  // Door is broken
DF_SEARCHED :: 0x80;  // Door has been searched
```

**Door state distribution (per original spec):**
- 10% open
- 14% secret
- Of remaining: 50% locked, 50% unlocked
- Lock DC scales with depth (10 + depth*2 + random)

### Files Modified

**`src/dungeon/makelev.jai`:**
- Added `write_destroyed()`, `write_grid()`, `write_lifelink()`, `write_shaped()`
- Updated `draw_panel()` with new room type cases
- Enhanced `carve_tunnel()` with edge clamping
- Added `place_treasure_deposits()`
- Enhanced `place_doors_makelev()` with door states and DoorInfo tracking

**`src/dungeon/map.jai`:**
- Added `DF_*` door flag constants
- Added `DoorInfo` struct
- Added `doors: [..] DoorInfo` array to GenMap

### Test Results

All 166 tests pass. Dungeon generation now includes all researched features.

---

## 2026-01-28: Phase 3 - Population System Enhancements

### Overview

Implemented proper per-panel population system following the original MakeLev.cpp specifications.

### Per-Panel Population

Changed from global random placement to per-room population:
- Each room is populated independently with appropriate monster/item density
- Party IDs assigned per room (creatures in same room don't fight)
- Monster count based on room's open tile count with density divisor (30/50/75)

**Source:** MakeLev.cpp:3269-3301 (PopulatePanel), MakeLev.cpp:2900-2908 (party assignment)

### Item Distribution System

Proper item generation with original chances:
- `CHEST_CHANCE` (15%): Chests placed in rooms
- `TREASURE_CHANCE` (25%): Good treasure items at CR+3
- `CURSED_CHANCE` (10%): Treasure may be cursed
- `STAPLE_CHANCE` (20%): Essential consumables
- Poor items (50% if no chest/treasure) at lower CR tier

**Source:** population.md lines 366-394

### Furnishing System

Room decoration patterns from FurnishArea:
- `FU_SPLATTER`: Random scatter (~1/5 room volume)
- `FU_GRID`: Regular 2x2 grid pattern
- `FU_COLUMNS`: Alternating rows/columns (50% each)
- `FU_CORNERS`: Four corner positions
- `FU_CENTER`: Single center placement
- `FU_SPACED_COLUMNS`: Widely spaced columns
- `FU_INNER_COLUMNS`: Columns with 2-tile border

Added PILLAR and RUBBLE terrain types for furnishing.

**Source:** MakeLev.cpp:2951-3266, Defines.h:3828-3843

### Aquatic and Terrain Placement Rules

Monster placement follows terrain rules:
- Aquatic monsters (20% chance in water rooms) placed in water
- Non-aquatic cannot be in water
- Aerial monsters (5% chance) can be in chasm/lava
- 50 tries max per placement

**Source:** Encounter.cpp:2537-2620

### EntityPos Extensions

Added fields to EntityPos struct:
- `party_id`: Creatures in same party don't fight
- `room_index`: Which room entity belongs to
- `is_aquatic`, `is_aerial`, `is_sleeping`: Monster flags
- `is_cursed`, `is_good`, `is_staple`, `is_chest`: Item flags

### Files Modified

**`src/dungeon/map.jai`:**
- Added PILLAR and RUBBLE terrain types
- Extended EntityPos with party_id, room_index, and flags

**`src/dungeon/makelev.jai`:**
- Added FurnishType enum and furnish_area()/furnish_room() functions
- Added find_open_for_item() for item placement
- Rewrote populate_dungeon() to use per-panel populate_panel()
- Added aquatic/aerial monster placement logic
- Added proper item distribution chances

**`tools/dungeon_test.jai`:**
- Added color mapping for PILLAR and RUBBLE terrain

### Test Results

All 166 tests pass. Dungeons now have:
- Per-room population with party assignment
- Proper item distribution (chests, treasure, cursed, staples)
- Furnishing patterns (pillars, columns, etc.)
- Terrain-appropriate monster placement

---

## 2026-01-28: Phase 1 - Resource Baking System

### Overview

Implemented compile-time resource baking to parse .irh files and embed the results in the binary.

### Resource Files

Copied all .irh files from Incursion source to local `lib/` directory:
- mon1.irh through mon4.irh (monsters)
- mundane.irh (basic items)
- weapons.irh (weapon items)
- dungeon.irh (terrains, regions)
- Additional support files

### Runtime Structs

Created lean runtime structs in `src/resource/runtime.jai`:

**RMonster:**
- name, glyph (u16), fg_color
- cr, hd, size, speed
- Ability scores (str_val, dex_val, etc.)
- Combat stats (ac, hit_bonus)
- Packed flags (u64) and mtypes (u64) bitmasks

**RItem:**
- name, glyph (u16), fg_color
- itype, material, weight, cost, level, size
- Weapon properties (dmg_small, dmg_large, crit_range, crit_mult)
- Armor properties (armor_bonus, max_dex, armor_penalty)
- Packed flags (u32)

**ResourceDB:**
- Arrays of monsters, items, terrains, encounters
- Sorted name arrays for binary search lookup
- `find_monster()` and `find_item()` functions

### Baking Implementation

Created `src/resource/bake.jai`:

**Parsing:**
- `parse_resource_file()` - Parse single .irh file into runtime structs
- `bake_all_resources()` - Parse all resource files
- `init_resource_db()` - Initialize global BAKED_DB

**Conversion functions:**
- `convert_monster()` - ParsedMonster → RMonster
- `convert_item()` - ParsedItem → RItem
- `convert_terrain()` - ParsedTerrain → RuntimeTerrain
- `convert_region()` - ParsedRegion → RuntimeRegion

**Key fixes:**
- String ownership: copy_string() used during conversion since parser strings reference freed file content
- Glyph storage: u16 to preserve extended glyph codes (GLYPH_* values 256+)
- Null checks in sorting to handle partial parse results

### Integration

Updated dungeon viewer (`tools/dungeon_test.jai`):
- Loads baked resources on startup
- Displays resource counts

Updated terminal system (`src/terminal/window.jai`):
- TermCell.char changed to u16
- terminal_set() accepts u16 glyph

Updated map system (`src/dungeon/map.jai`):
- terrain_glyph() returns u16
- TileDisplay.glyph is u16

### Test Results

| Resource | Count |
|----------|-------|
| Monsters | 429 |
| Items | 201 |
| Terrains | 53 |

Tests verify:
- Binary search lookups work (find_monster, find_item)
- Names are properly sorted
- Extended glyph codes (256+) are preserved
- Goblin lookup returns valid data

### Parser Limitations

4 test failures from mon1-4.irh due to unsupported syntax:
- SC_WEA bare constants
- ABILITY() macro calls
- Multi-line Desc blocks

These files partially parse (425 monsters recovered).

### Files Created/Modified

**Created:**
- `src/resource/runtime.jai` - Runtime resource structs
- `src/resource/bake.jai` - Baking logic
- `lib/*.irh` - Copied from Incursion source

**Modified:**
- `src/tests.jai` - Added resource baking tests
- `src/resource/constants.jai` - Renamed compare_strings to cmp_strings_const
- `src/dungeon/terrain_registry.jai` - glyph u8→u16
- `src/dungeon/map.jai` - terrain_glyph returns u16, TileDisplay.glyph u16
- `src/terminal/window.jai` - TermCell.char u16, terminal_set param
- `tools/dungeon_test.jai` - Loads resources, Sort import
- `tools/inspect.jai` - Loads resources, Sort import, fixed u16 glyph handling

---

## 2026-01-28: Baked Resources Integration

### Overview

Wired baked resources from dungeon.irh through to actual dungeon generation, so rooms display with varied terrain colors.

### Changes

**`src/resource/runtime.jai`:**
- Added `regions: [] RuntimeRegion` to ResourceDB

**`src/resource/bake.jai`:**
- Store baked regions in BAKED_DB
- Added `get_baked_regions()` accessor

**`src/dungeon/terrain_registry.jai`:**
- Added `build_terrain_registry_from_baked()` to load from RuntimeTerrain[]

**`src/dungeon/weights.jai`:**
- Added `load_baked_regions()` to populate room/corridor/vault regions from baked data
- `init_dungeon_weights()` now tries baked regions first, falls back to hardcoded test regions

**`src/dungeon/makelev.jai`:**
- `gen_state_init()` now loads terrain registry from baked data when available

### Results

When running `dungeon_test.exe` from project root:
- **53 terrains** loaded from dungeon.irh
- **59 room regions** with varied terrain (ice floor, shallow water, slime, fog, etc.)
- **30 corridor regions**
- **1 vault region**

Rooms now display with the correct terrain colors based on their selected region from the original Incursion definitions.

---

## 2026-01-28: Wall Placement Bug Fix and EXTENDED Mode Removal

### Wall Placement Bug

**Problem:** Some room types (lifecave, lifelink) had floor tiles at panel edges with no walls around them. Monsters could appear in these "floating" floor areas with rock (void) directly adjacent.

**Root Cause:** In `write_lifecave` and `write_lifelink`, the wall placement loops used `1..h-2` and `1..w-2` bounds, which skipped the first and last row/column. Floor tiles at panel edges never got walls placed around them.

**Fix:** Changed both functions to use `0..h-1` and `0..w-1` for wall placement loops:
- `src/dungeon/makelev.jai` line 834: `for gy: 0..h-1`
- `src/dungeon/makelev.jai` line 1788: `for gy: 0..h-1`

**Testing:** Used `inspect.exe` to analyze seed 12349 which had floor tiles at position (40,30) directly adjacent to rock. After fix, walls properly enclose all floor areas.

### EXTENDED Mode Removal

**Motivation:** Simplified codebase by removing unused BSP-based generator mode. Only ORIGINAL (MakeLev panel-based) mode is now supported.

**Changes:**
- `src/rng.jai`: Removed `EXTENDED` from `GeneratorMode` enum
- `src/dungeon/generator.jai`: Simplified `generate_dungeon()` to always use ORIGINAL mode
- `tools/dungeon_test.jai`: Removed mode toggle (M key), mode parameter from functions
- `tools/inspect.jai`: Removed mode CLI flag processing, simplified output

### Test Results

- 177/181 tests passing (same as before - 4 failures are known monster file parsing issues)
- Dungeons now properly walled at all panel boundaries

---

## 2026-01-28: Color Mapping and Terrain Visibility Fixes

### Problem: Black Room Interiors in Screenshots

The dungeon screenshot showed large black areas where rooms should have visible floor tiles. Investigation revealed multiple issues:

1. **Color enum mismatch**: `BaseColor` enum ordinal values didn't match ANSI color indices (e.g., `BaseColor.BROWN = 10` but ANSI brown = 6)
2. **Case-sensitive terrain lookup**: Regions referenced `$"floor"` but terrain was named `"Floor"`, causing lookup failures
3. **Grey too dim**: ANSI grey (0.7, 0.7, 0.7) was nearly invisible on black background

### Fixes Applied

**1. Color Conversion Function** (`src/resource/bake.jai`):
Added `parsed_color_to_ansi()` to properly map `BaseColor` enum values to ANSI color indices:
- `.GREY` -> 7, `.BROWN` -> 6, `.SHADOW` -> 8, etc.
- Handles modifiers (BRIGHT, LIGHT, DARK) for color variants

**2. Case-Insensitive Terrain Lookup** (`src/dungeon/terrain_registry.jai`):
- Added `#import "String"` for `to_lower_copy()`
- Modified `terrain_registry_add()` to store lowercase keys
- Modified `terrain_registry_get()` to normalize lookup keys to lowercase

**3. Lexer Function Rename** (`src/resource/lexer.jai`):
- Renamed local `slice()` to `substr()` to avoid conflict with `String.slice`
- Updated all 11 call sites

**4. Brighter Grey** (`src/dungeon/terrain_registry.jai`):
- Changed `terrain_color_to_rgb(7)` from 0.7 to 0.85 for better visibility

**5. Headless Screenshot Tool** (`tools/dungeon_screenshot.jai`):
- Created standalone tool for generating screenshots without window
- Defines own Color struct and TC_* constants (no Simp dependency)

### Test Results

- 177/181 tests passing (unchanged)
- Screenshot now shows visible floor tiles in all rooms
- Grey floor glyphs clearly distinguishable from black background

---

## 2026-01-28: Glyph Rendering Understanding Correction

### Problem: Extended Glyphs Render as "?"

Screenshots show "?" characters where terrain glyphs should appear. Extended glyphs (GLYPH_FLOOR = 323, GLYPH_WALL = 264, etc.) exceed the 256-character range of the bitmap font.

### Corrected Understanding

Initial research incorrectly treated Unicode mappings in `Wcurses.cpp` as the primary rendering path. User correction:

**Fonts are the PRIMARY display.** The original Incursion used:
- CP437 bitmap fonts (256 chars in 16x16 grid) - the main rendering mode
- Unicode/ASCII in `Wcurses.cpp` is a **fallback** for pure curses/text terminals

**GLYPH_* constants are aliases** that map to CP437 character codes via a lookup table in `Wlibtcod.cpp`:
- `GLYPH_FLOOR (323)` → CP437 code 250 (middle dot ·)
- `GLYPH_FLOOR2 (324)` → CP437 code 249 (small square)
- `GLYPH_WALL (264)` → CP437 code 177 (medium shade ▒)
- `GLYPH_ROCK (265)` → CP437 code 176 (light shade ░)
- `GLYPH_WATER` / `GLYPH_LAVA` → CP437 code 247 (almost equal ≈)

**Color is applied separately** from glyphs. This is why lava (red) and water (blue) can share the same glyph image (CP437 code 247) - the glyph defines shape, color is applied on top.

### Action Taken

Added detailed backlog entry under "Technical Debt > Glyph Rendering (HIGH PRIORITY)" documenting:
- The correct understanding of the rendering architecture
- The specific GLYPH_* to CP437 mappings needed
- Reference to the authoritative source file (`Wlibtcod.cpp` lines 448-600)

### Impact

Our 8x8.png font is already in CP437 layout. Once the lookup table is implemented, extended glyphs will render correctly with no font changes needed.

---

## 2026-01-29: Correctness Research Restructuring

Aligned `docs/research/correctness-research/` with preferred subproject structure. See subproject JOURNAL.md for details.

**Changes:** Split monolithic `notes.md` into `README.md` (overview), `NOTES.md` (technical reference), and `BACKLOG.md` (open questions/deferred work).

---

## 2026-01-29: Rendering Pipeline Investigation

Investigated original source to understand how glyph rendering decisions are made. Created `docs/research/specs/rendering-pipeline.md`.

**Key findings:**
- Glyph is u32 bitfield: bits 0-11 character ID, bits 12-15 FG color, bits 16-19 BG color
- GLYPH_* constants (256+) are semantic aliases requiring CP437 lookup at render time
- Authoritative lookup table in `src/Wlibtcod.cpp` lines 448-606
- Water and lava share same glyph (247), color distinguishes them

This explains the "?" rendering bug - extended glyph IDs weren't being converted to CP437 codes.

---

## 2026-01-29: Rendering Priority System Implementation

Implemented proper entity rendering with priority system and stacking support.

### Changes

**EntityPos extended** (`src/dungeon/map.jai`):
- Added `glyph: u16` and `fg_color: u8` fields
- Set at entity spawn time rather than queried at render time

**New render module** (`src/dungeon/render.jai`):
- `count_monsters_at()`, `count_items_at()` - entity counting per cell
- `first_monster_at()`, `first_item_at()` - entity lookup
- `get_terrain_fg_color()`, `get_terrain_bg_color()` - ANSI color indices
- `get_cell_render()` - main render function with priority: Creatures > Items > Terrain
- `ansi_to_rgb()` - convert ANSI indices to RGB floats
- GLYPH_MULTI (Æ) for multiple creatures at same cell
- GLYPH_PILE (*) for multiple items at same cell

**Glyph selection** (`src/dungeon/makelev.jai`):
- `select_monster_glyph()` - varied glyphs by CR and environment (aquatic, aerial)
- `select_item_glyph()` - varied glyphs by type (chest, staple, treasure tier)
- All entity creation points now set glyph/color

**Tools updated**:
- `dungeon_test.jai` - uses `get_cell_render()` instead of hardcoded M/*
- `dungeon_verify.jai` - new checks for entity glyph assignment and stacking

### Verification

All 7 checks pass in dungeon_verify:
1. No '?' glyphs
2. Water terrain is blue
3. Lava terrain is red
4. Extended glyphs have CP437 mappings
5. Entity glyph assignment (no warnings now)
6. Entity stacking glyphs (GLYPH_MULTI/GLYPH_PILE)
7. Full map glyph/color verification

### Visual Result

Monsters now display varied letters (r, g, o, T, D, etc.) with appropriate colors instead of all 'M'. Items show proper glyphs (potions, scrolls, weapons) instead of all '*'. Multiple entities at same cell show Æ or * as appropriate.

---

## 2026-01-29: Resource Database Glyph Lookup

Replaced random glyph generation with actual lookups from the parsed resource database.

### Changes

**CR-based lookup functions** (`src/resource/runtime.jai`):
- `find_monster_by_cr(db, cr_min, cr_max, rng_seed)` - find monsters in CR range
- `find_monster_by_cr_fuzzy(db, target_cr, tolerance, rng_seed)` - fuzzy CR matching
- `find_item_by_level(db, level_min, level_max, rng_seed)` - find items by level
- `find_item_by_level_fuzzy(db, target_level, tolerance, rng_seed)` - fuzzy level matching

**Entity creation updated** (`src/dungeon/makelev.jai`):
- Monster creation now looks up from `db.monsters` by CR
- Item creation uses `assign_item_from_db()` helper
- `type_id` field stores index into resource database
- Fallback to `select_monster_glyph`/`select_item_glyph` if no match found

### Result

Monsters and items now display their actual glyphs as defined in the .irh resource files:
- A goblin (CR 1/2) shows 'g' in green
- A kobold shows 'k'
- Items show their proper equipment glyphs (armor Σ, weapons, etc.)

The `type_id` field can be used for future lookups (name, stats, etc.).

---

## 2026-01-29: Visibility/Memory System Specification

Researched and documented the original Incursion visibility system for correctness alignment.

### Research Findings

**Data Structures** (from `inc/Map.h` lines 25-56):
- `LocationInfo.Visibility` - u16 bitmask of visibility flags per player
- `LocationInfo.Memory` - u32 stored glyph (what player remembers seeing)
- Flags: `VI_VISIBLE` (in FOV), `VI_DEFINED` (ever seen), `VI_EXTERIOR`, `VI_TORCHED`

**Rendering Logic** (from `src/Term.cpp` lines 838-846):
- If cell visible: show current contents with priority system
- If defined but not visible: show `Memory` glyph (remembered terrain)
- If never seen: show `GLYPH_UNSEEN` (space character)

**Memory Assignment** (from `src/Vision.cpp` line 62):
- When cell becomes visible: `Memory = Glyph` (stores terrain appearance)
- Features (doors, chests, fountains) update Memory when discovered
- Creatures and loose items are NOT remembered (only visible in FOV)

**FOV Algorithm** (from `src/Vision.cpp` lines 256-370):
- Ray casting from player position to edges of viewport
- Cells block vision if `Opaque` flag set, magical darkness, or obscuring terrain
- Multiple range checks: `SightRange`, `LightRange`, `ShadowRange`, `BlindRange`

### Specification Created

Full spec at `docs/research/specs/visibility-system.md` including:
- Data structure definitions
- Rendering decision flowchart
- Memory assignment rules
- FOV algorithm overview
- 4-phase implementation plan for Jai port
- Verification checklist

### Next Steps

Implementation deferred pending user direction. The spec outlines:
1. Phase 1: Add VisibilityInfo struct to GenMap
2. Phase 2: Implement `mark_cell_visible()` for memory assignment
3. Phase 3: Update `get_cell_render()` with visibility checks
4. Phase 4: Implement ray-based FOV calculation

---

## 2026-01-29: Lighting System Specification

Researched the lighting system that interacts with visibility.

### Research Findings

**Cell Lighting Flags** (from `inc/Map.h`):
- `Lit` - Cell is illuminated by terrain or torch
- `Bright` - Brightly lit (near torch center, gets yellow color)
- `Shade` - Floor can have light-level coloring applied
- `Dark` - Magical darkness (blocks vision)
- `mLight` - Magical light (overrides darkness)

**Creature Vision Ranges** (from `inc/Creature.h`, `src/Values.cpp`):
- `SightRange` - Maximum visual distance (base 12-15 + WIS modifier)
- `LightRange` - Personal light source radius (equipped torch/lantern)
- `ShadowRange` - Distance for dim shape perception (LightRange * 2)
- `InfraRange` - Infravision/darkvision range (from CA_INFRAVISION)
- `BlindRange` - Blindsight (echolocation, reduced by metal helm/large weapons)

**Torch System** (from `src/MakeLev.cpp`):
- Torch terrain (TF_TORCH flag) placed on walls
- Room lit chance: 50% - 4% per depth (ROOM_LIT_CHANCE - LIT_CHANCE_DEPTH_MOD)
- Torch density: 1 in TORCH_DENSITY (10) wall tiles
- Light radius: 8 tiles with LOS check
- Light levels: 3=bright (yellow), 2=medium (brown), 1=dim

**Visibility Integration** (from `src/Vision.cpp`):
- `dist > SightRange`: Can't see at all
- `dist > ShadowRange && !Lit`: Can't see (too far in darkness)
- `dist > LightRange && !Lit`: VI_DEFINED only (shadow, see shape not details)
- Otherwise: VI_VISIBLE | VI_DEFINED (full visibility)

**Shadow Rendering** (from `src/Term.cpp`):
- Creatures perceived only via PER_SHADOW show as GLYPH_UNKNOWN (?) in SHADOW color

### Relationship with Visibility System

Lighting and visibility are tightly coupled:
1. Dungeon generation places torches and calculates `Lit` flags
2. FOV calculation uses creature's vision ranges + cell `Lit` status
3. Rendering shows full detail, shadow, or memory based on visibility state

### Specification Created

Full spec at `docs/research/specs/lighting-system.md` including:
- Cell lighting data structures
- Vision range calculations with all modifiers
- Torch placement algorithm
- Light level effects on glyph colors
- Integration with FOV visibility decisions
- 4-phase implementation plan

---

## 2026-01-29: Visibility and Lighting System Implementation

### Overview

Implemented field of view (FOV) visibility with torch-based lighting integration, allowing:
- Unseen cells show as blank space
- Previously seen cells show remembered terrain (memory) in dimmed colors
- Currently visible cells show full contents with entity rendering
- Lit rooms (via torches) extend visibility beyond personal light range

### Data Structures Added

**VisibilityInfo** (`src/dungeon/map.jai`):
```jai
VisibilityInfo :: struct {
    flags: u8;         // VI_VISIBLE, VI_DEFINED
    memory_glyph: u16; // Remembered glyph
    memory_fg: u8;     // Remembered color
    lit: bool;         // Cell is illuminated
}
```

**GenMap extensions**:
- `visibility: [MAP_WIDTH * MAP_HEIGHT] VisibilityInfo` - per-cell visibility state
- `torch_positions: [..] TorchPos` - torch locations for lighting calculation

### Visibility Module (`src/dungeon/visibility.jai`)

**Core functions**:
- `calculate_lighting()` - marks cells within TORCH_RADIUS (7) of torches as lit
- `calculate_fov()` - ray-casts from player position, marks VI_VISIBLE | VI_DEFINED
- `has_line_of_sight()` - Bresenham line algorithm checking for opaque terrain
- `mark_visible()` - sets flags and stores terrain in memory

**Vision ranges**:
- `SIGHT_RANGE` (15) - maximum vision in lit areas
- `LIGHT_RANGE` (4) - personal torch radius
- `SHADOW_RANGE` (8) - dim perception (see shapes but not details)

### Torch Placement (`src/dungeon/makelev.jai`)

**`place_room_lights()`**:
- Called after room furnishing (Step 5.7 in generation)
- Lit room chance: 50% - 4% per depth (min 5%)
- Torch density: 1 in 10 wall tiles adjacent to floor
- Torch glyph shown on walls (GLYPH_TORCH in bright yellow)

### Rendering Integration (`src/dungeon/render.jai`)

**`get_cell_render()` updated**:
- Added `use_visibility: bool = false` parameter for backwards compatibility
- If not visible and not defined: returns GLYPH_UNSEEN (blank)
- If defined but not visible: returns memory_glyph with `dim_color()` applied
- If visible: full entity priority rendering (creatures > items > terrain)

**`dim_color()`**:
- Bright colors (9-15) → dim equivalents (1-7)
- Normal colors (1-7) → dark grey (8)
- Creates visual distinction for remembered areas

### Dungeon Test Updates (`tools/dungeon_test.jai`)

**Player movement**:
- `init_player_position()` - starts at first room center
- WASD keys for movement, arrow keys for viewport scrolling
- `can_move_to()` - checks passability (floor, corridor, water, doors)
- Player rendered as '@' in bright white

**Visibility toggle**:
- V key toggles between FOV mode and full map
- Automatic FOV recalculation on player movement
- Viewport auto-centers on player

**Controls updated**:
- WASD: move player
- Arrow keys: scroll viewport
- V: toggle visibility mode
- R: regenerate dungeon
- F: save screenshot (moved from S to avoid conflict)
- ESC: exit

### Files Modified

| File | Change |
|------|--------|
| `src/dungeon/map.jai` | Added VisibilityInfo, VI_* flags, torch_positions to GenMap |
| `src/dungeon/visibility.jai` | **NEW** - FOV and lighting calculations |
| `src/dungeon/makelev.jai` | Added place_room_lights(), torch placement |
| `src/dungeon/render.jai` | Updated get_cell_render() with visibility filtering, dim_color() |
| `src/main.jai` | Added #load for visibility.jai |
| `tools/dungeon_test.jai` | Added player position, movement, FOV updates, visibility toggle |

### Test Results

- All 177/181 tests pass (4 pre-existing monster parsing failures)
- Dungeon test compiles and runs
- FOV reveals map as player explores
- Torches illuminate rooms
- Memory shows previously seen areas in dim colors

## 2026-01-30: Comprehensive Source Architecture Research

### Objective

Systematically research the entire original Incursion C++ source code to document all subsystems, data structures, and algorithms needed for a faithful port.

### Approach

1. Explored existing research directory (27 files across 4 subdirectories)
2. Inventoried all original source files (47 .cpp, 23 .h headers)
3. Read all key headers in depth (Base.h, Map.h, Res.h, Creature.h, Events.h, Defines.h)
4. Created master research index linking all subsystem areas
5. Wrote 17 detailed research documents covering every major subsystem
6. Updated master index with completion status

### Key Findings

**Class Hierarchy**: Object > Thing > {Creature, Feature, Item}
- Creature splits into Character (Player) and Monster
- Item hierarchy: Item > QItem > {Food/Corpse, Container, Weapon, Armour, Coin}
- Feature hierarchy: Feature > {Door, Trap, Portal}
- 21 Resource template types (TMonster, TItem, TEffect, TClass, TRace, etc.)

**Event System**: Central dispatch for ALL game actions
- EventInfo struct with ~200 fields (combat, encounter, chargen, naming)
- 190+ event types (EV_MOVE through EV_TERMS)
- Dispatch via ReThrow() to resource script handlers
- Macros: PEVENT, DAMAGE, THROW, XTHROW, RXTHROW

**Defines.h**: 45 constant categories, ~4700 lines
- Major categories: A_* (114 attack types), M_* (114 monster flags), FT_* (200+ feats), CA_* (143 class abilities), SK_* (49 skills), EF_* (105 effect flags)

**Map System**: LocationInfo per-cell has 16 bitfield flags + Visibility + Memory + Glyph + Contents
- Field effects for area spells
- Magical terrain system
- Overlay for animated effects

### Research Documents Created

| File | Subsystem |
|------|-----------|
| `master-index.md` | Comprehensive index with priorities |
| `01-object-registry.md` | Object, Registry, String, Dice, MVal, Array |
| `02-resource-system.md` | 21 Resource types, rID encoding, Module |
| `03-event-system.md` | EventInfo, 190+ events, dispatch macros |
| `04-creature-system.md` | Creature/Character/Player/Monster |
| `05-combat-system.md` | d20 combat, attack flow, maneuvers |
| `06-item-system.md` | Item hierarchy, qualities, equipment slots |
| `07-magic-system.md` | Spells, effects, metamagic, prayer |
| `08-status-effects.md` | Stati, StatiCollection, fields |
| `09-map-system.md` | LocationInfo, Map class, LOS |
| `10-feature-system.md` | Door, Trap, Portal |
| `11-vision-perception.md` | FOV, 9 perception types, pathfinding |
| `12-encounter-generation.md` | CR-balanced encounters |
| `13-skills-feats.md` | Skills, feats, abilities, chargen |
| `14-social-quest.md` | NPC interaction, companions, quests |
| `15-ui-display.md` | Terminal, managers, messages |
| `16-data-tables.md` | Tables, annotations, targeting, debug |
| `17-values-calcvalues.md` | CalcValues, bonus stacking, d20 rules |

### Research Coverage

**Architecture level (DONE)**: All 26 subsystems documented with class hierarchies, field definitions, method signatures, and porting considerations.

**Implementation level (deferred)**: Function bodies in .cpp files contain exact algorithms and formulas. These should be researched per-system when actively porting each area. Key systems needing implementation reads:
- Values.cpp: CalcValues() formulas and bonus stacking
- Fight.cpp: Combat sequence and damage formulas
- Monster.cpp: AI decision loop
- Effects.cpp: Individual effect archetype implementations

**Only gap**: Overland system (OverGen.cpp, Overland.cpp) marked as STUB - lower priority for initial dungeon-focused port.

### Porting Architecture Decisions Identified

1. **No inheritance in Jai**: Need tagged unions or composition for Thing/Creature/Item hierarchies
2. **Virtual dispatch**: Procedure tables or type-switch patterns
3. **EventInfo**: Massive struct; consider sub-structs by category
4. **Handle system (hObj)**: Integer indices into flat arrays
5. **Status effects**: Dynamic array with nesting support
6. **Bonus stacking**: 39 bonus types with d20 stacking rules - critical for correctness

## 2026-01-30: Research Review Pass & Supplementary Detail

### Context

Continued from previous session where comprehensive source architecture research was completed. A late-arriving background agent had returned detailed analysis of Base.h/Globals.h/Target.h that wasn't incorporated into the committed research docs. This session re-read those source headers and incorporated the missing detail.

### Work Done

**Re-read source headers** (Base.h, Globals.h, Res.h, Target.h) to capture detail lost from expired background agents. Three parallel research agents returned comprehensive results:

1. **Base.h agent**: String internals (tmpstr pool of 64000, canary guards, color codes via negative chars), Registry hash table (65536 entries, RegNode collision chaining, handle allocation from 128), VMachine (all 63 opcodes with semantics, VCode 32-bit instruction format, system objects 1-10, execution model), Array growth strategy, Dice roll semantics (negative Number handling), MVal two-phase Adjust algorithm.

2. **Globals.h/Res.h agent**: All 75 TextVal lookup arrays (45 display name + 30 CONSTNAMES), 30+ calculation breakdown variables (spell power/DC/skill check), 13 event Throw variants, game state globals, all 21 resource subclass fields with complete method signatures, Module class with cache and XOR-obfuscated text segments.

3. **Target.h agent**: HostilityWhyType (23 reason codes), three-tier hostility evaluation (SpecificHostility → LowPriorityStatiHostility → RacialHostility with full evaluation order), TargetSystem (32-target fixed array), TargetType enum (creatures, areas, items, 15 order types, 5 memory flags), RateAsTarget/Retarget algorithms, ItHitMe damage thresholds (ally 5+CHA*2, leader 10+CHA*2), racial feud table, MonMem/ItemMem/EffMem/RegMem bitfield structures.

**Updated 4 research documents** with supplementary detail:
- `01-object-registry.md`: Expanded from 127 to ~350 lines. Added String method signatures, Registry algorithms (Get/RegisterObject/Remove), VMachine complete opcode table, Array concrete instantiations, Dice roll semantics, MVal Adjust phases.
- `02-resource-system.md`: Expanded from 193 to ~300 lines. Added full Resource base class methods, all 21 resource subclass field listings, Module cache/segment details, Game class fields and methods, supporting structures (TAttack, EffectValues, Status bitfield, Annotation union, EncPart, Tile, DebugInfo).
- `04-creature-system.md`: Expanded from 207 to ~320 lines. Added entire Target System section covering HostilityWhyType, three-tier evaluation with full ordering, TargetType enum, Target struct, TargetSystem methods, Retarget algorithm, ItHitMe thresholds, player memory structures.
- `16-data-tables.md`: Expanded from 166 to ~360 lines. Added game state globals, 75 TextVal arrays (complete list), calculation breakdown variables, static data tables, event dispatch functions, global free functions, print system.

**Updated master-index.md** with improved cross-references:
- Section 1.1: Now references VMachine, Registry hash size, String pool
- Section 11.1: Now includes Globals.h scope (75 TextVal arrays, print system, event dispatch)
- Section 11.3: Now cross-references doc 04 for detailed TargetSystem, mentions three-tier evaluation

**Review pass** across all 18 research documents confirmed:
- All docs structurally consistent
- Status labels accurate for scope (architecture-level vs fully-researched)
- Cross-references between docs valid
- No gaps in subsystem coverage (only Overland remains STUB, intentionally)
- The 4 updated docs now have implementation-level detail for their covered structures

### Summary

Total research docs: 18 files covering 26 subsystems. Four key docs expanded with ~600 additional lines of detail from re-reading original source headers. Master index updated. All research complete at architecture level; implementation-level .cpp algorithms remain deferred to per-system porting as planned.

## 2026-01-30: Final Research Incorporation (Map, Event, Feature)

### Context
Late-arriving background agent from the previous session had detailed Map.h, Events.h, and Feature.h field-level data. Incorporated this data into the remaining three research documents.

### Changes

**`03-event-system.md`**: Added implementation-level EventInfo fields:
- Positional/directional fields (x, y, z, sp, EvFlags, EParam, EParam2)
- Additional combat fields (vRange, vRadius, vOpp1/2, vRideCheck, chain tracking, vPenetrateBonus, remainingAmmo, MM metamagic flags)
- Expanded string fields with full naming system for EV_PRINT_NAME (nPrefix through enDump)
- Encounter generation fields (encounter-level and per-part, ~40 fields)
- Dungeon generation fields (Rect cPanel/cMap/cRoom, vDepth/vLevel, terrain mutation keys)
- Resource selection fields (chType, chList, chMaximize, chBestOfTwo, chResult, chSource, chCriteria callback)
- Illusion fields (illFlags, illType, ill_eID)

**`09-map-system.md`**: Major expansion with implementation-level detail:
- Field struct full definition (eID, FType, Image, cx/cy/rad, Dur, Creator, Next, Color)
- MTerrain struct (x, y, old, pri, key) and TerraRecord struct (key, Duration, SaveDC, DType, pval, eID, Creator)
- EncMember struct (14 fields: mID through padding)
- Overlay class with MAX_OVERLAY_GLYPHS=250, hObj m, IsGlyphAt
- All Map private fields: nextAvailableTerraKey, inGenerate, SpecialDepths, CurrThing, static Fraction vision helpers
- Complete static generation arrays: weights (4x 1024-entry), open positions (2048), corners/centers, Con[143], RM/RC weights, flood arrays
- Static encounter generation: EncMem[100], uniform arrays
- Additional public fields: PercentSI, inDaysPassed, SpecialsLevels[64], Day, FieldCount, BreedCount, PreviousAuguries
- Additional query methods: spatial queries, container queries, FirstThing/NextThing
- 16 room shape writers (WriteCircle through WriteWalls)
- Full pathfinding API with PQ operations and parameter detail
- Complete encounter generation API (9 thEnGen variants + internal pipeline)
- Message queue, noise, and miscellaneous methods
- Supporting types: Thing base class, StatiCollection, Status struct, StatiIter macros
- Constants and globals (MAX_OVERLAY_GLYPHS, MAX_ENC_MEMBERS, LAST_DUNCONST, etc.)
- DF_* naming collision note (door flags vs damage flags vs danger flags)

**`10-feature-system.md`**: Added constant values and constructor detail:
- Door flags with exact hex values (DF_VERTICAL 0x01 through DF_PICKED 0x80)
- Trap state flags (TS_FOUND through TS_NORESET)
- Portal type constants (POR_UP_STAIR 1 through POR_RETURN 10)
- Terrain feature flags (TF_SOLID through TF_LAST=28, bit indices not bitmasks)
- Thing flags (F_SOLID through F_ALTAR, hex bitmasks)
- Feature type constants (T_PORTAL 10 through T_BARRIER 15)
- Feature constructor logic (both variants)
- Complete method signatures for all four classes
- Trap constructor detail
- DF_* naming collision warning

**`04-creature-system.md`**: Further expanded with late-arriving Creature.h agent data:
- Creature static members: AttrAdj[41][39] bonus matrix, weapon cache (5 static Item pointers)
- Character: full field listing expanded with skill points (SpentSP/BonusSP/TotalSP), turning (TurnTypes/TurnLevels), favored enemies (FavTypes/FavLevels), study/focus, HP/mana roll arrays, save bonuses, attribute gain tracking, alignment/misc fields, full religion arrays (TempFavour, Anger, FavPenalty, PrayerTimeout, AngerThisTurn, lastPulse, godFlags), spell detail (slots, recent, tattoos)
- Player: expanded with MMArray[2048], SpellKeys, MapMemoryMask, GallerySlot, MapSP, GraveText, seeds, counters, UI state flags
- State flags (MS_*) with exact hex values (16 flags)
- Perception flags (PER_*) with exact hex values (11 flags)
- Supporting data structures: ActionInfo, EffectInfo, FeatInfoStruct with FeatPrereq/FeatConjunct, SkillInfoStruct
- Feat prerequisite types (FP_*, 13 values)
- Key size constants table (15 entries)

### Summary
All 18 research documents now have implementation-level detail where available. Seven key docs (01, 02, 03, 04, 09, 10, 16) expanded with field-level detail from original headers. Research phase complete.

**`06-item-system.md`**: Further expanded with late-arriving Item.h agent data:
- IFlags constants with exact hex values (11 flags)
- KN_* knowledge flags with hex values (9 flags)
- Weapon group constants (WG_*, 22 entries with hex bitmask values)
- Weapon/armor quality constants organized by category with numeric IDs
- TItem resource template with union detail (weapon/armor/container/light stats)
- ItemGen struct for item generation with 6 extern generation tables
- Material utility free functions
- Additional weapon methods (bane management, grapple, wield/unwield)

**`07-magic-system.md`**: Major expansion with late-arriving Magic.h agent data:
- Magic class section: globals (ZapX/ZapY/ZapMap/ZapImage), area delivery methods (ABallBeamBolt unified handler, PredictVictims AI helper, ATouch/AGlobe/AField/ABarrier), core processing pipeline (isTarget/CalcEffect/MagicEvent/MagicStrike/MagicHit/MagicXY)
- Area range constants (AR_*, 18 types from AR_NONE through AR_CONE)
- Complete effect archetype table with EA_ codes and method names (33 entries + 8 additional methods)
- EffectValues with proper field types (not generic ints)
- EF_* flags organized by 9 categories (duration, frequency, targeting, damage, level caps, generation, naming, alignment, misc)
- Magic school constants (SC_*, 8 schools with hex bitmask values)
- Saving throw types (SN_*, 22 types)
- Damage type constants (AD_*, 94+ types in 7 categories: physical, elemental, status, drain, special attack, alignment, other)

**`08-status-effects.md`**: Major expansion with late-arriving Status.cpp agent data:
- Promoted from architecture to fully-researched status
- Detailed GainTempStati 6-step application process (validation, enchantment stacking, memory allocation with lazy growth, initialization, back-references, post-application with callbacks and events)
- _FixupStati consolidation process (merge, sort, rebuild index, compact)
- Five removal strategies with full signatures and behavior (RemoveStati, RemoveOnceStati, RemoveEffStati with event handling, RemoveStatiFrom, RemoveStatiSource)
- CleanupRefedStati genericization logic (SS_ATTK sources persist without source object)
- Complete stacking rules: enchantment stacking, attack-based genericization, 5 conflict pairs
- Full StatiOn callback table (25+ status types with specific behaviors)
- Full StatiOff callback table (20+ status types with specific behaviors including STONING petrification, HUNGER starvation, SINGING cascade, SLIP_MIND auto-save)
- Item StatiOn/StatiOff (DISPELLED/BOOST_PLUS/SUMMONED/ILLUSION)
- 15 status types with special handling (PERIODIC skip, SLOW_POISON, HUNGER, ACTING, TRAP_EVENT, etc.)
- Field type flags (FI_*, 10 types)
- Complete field lifecycle (creation, movement with SIZE field fitting, removal, enter/leave callbacks)
- PTerrainAt illusory terrain perception
- UpdateStati per-turn processing with 7-step logic
- Field duration semantics

**`05-combat-system.md`**: Major expansion with late-arriving Values.cpp agent data:
- Promoted from architecture to fully-researched status
- CalcValues() central engine: full attribute list (35+ attributes, perception ranges, derived stats), 10-step flow
- Bonus stacking system: AttrAdj[41][39] matrix, AddBonus vs StackBonus dual system, WESMAX macro, concentration burn, percentage attribute multiplicative stacking, magic resistance diminishing returns
- Known stacking issues (penalty deduplication bug, planned fix not implemented)
- Saving throw calculation: monster (MonGoodSaves + GoodSave/PoorSave tables) and character (per-class flags + ability mods + feat bonuses)
- Attack bonus calculation: full formula, BAB sources, weapon finesse, weapon skill bonus table (7 levels with hit/damage/speed/AC)
- Weapon damage by grip (two-handed 1.5×, one-handed, off-hand, ranged, thrown)
- AC/Defense calculation with size modifier table and special cases
- Damage resistance: ResistLevel() with 7 source types, immunity check, stacking formula (diminishing returns)
- HP calculation: character (base 20 + per-class rolls + feats + size multipliers + death check) and monster (CalcHP with options + CON + summoned bonus)
- Encumbrance penalties (4 load levels × 5 attributes)
- Fatigue penalties (fatigued vs exhausted)
- Hunger penalties (4 states × 4 attributes)
- Rage bonuses (small race variant)
- Skill point calculation

Eleven key docs (01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 16) now have implementation-level detail.

**Feature.cpp incorporation (agent ae71b8a)** - Expanded `10-feature-system.md` with full implementation detail from Feature.cpp. Promoted to fully-researched. Added:
- Door initialization (normal: 10% open, 90% closed, 50% of closed locked, ~14% secret; Weimer: all locked/solid)
- EV_OPEN lock picking flow (DC = 14 + depth, +10 wizard-locked, retry bonus via BoostRetry, XP formula)
- EV_CLOSE validation, SetImage() orientation/state logic
- TriggerTrap process (DC = 15 + level, +5 if not found, FT_FEATHERFOOT auto-avoid, XP to placer)
- Portal::Enter() level transitions (down/up stairs, dungeon entry, return portal)
- PRE_ENTER Dwarven Focus validation
- Feature HP/damage system (material hardness, sunder ×2, door-specific 1/3 piercing, destruction messages)
- Level transition/limbo system (LimboEntry struct, MoveDepth flow, GetDungeonMap caching)
- Status types used by features (9 types)

**Vision.cpp incorporation (agent a97fa74)** - Expanded `11-vision-perception.md` with full implementation detail from Vision.cpp. Promoted to fully-researched. Added:
- HUGE_PATH_MACRO Bresenham-like line algorithm (straight, diagonal, slope comparison)
- LineOfVisualSight (opaque + dark + obscure checks, NatureSight bypass)
- LineOfFire (solid + wall checks only, more permissive)
- VisionPath/BlindsightVisionPath cone tracing
- VisionThing main FOV function (5 sense passes: visual, blindsight, perception, tremor, wizard sight)
- MarkAsSeen three-tier visibility logic (visible/shadow/unseen with distance + light checks)
- Player::CalcVision() with companion perception pooling (HAS_ANIMAL)
- Full Perceives() 735-line flow (early returns, distance checks, 12 perception types, companion recursion, hiding/invisibility/far darkness)
- Edge cases (cross-map, engulfed, mounted, illusion, sleeping, SILENCE, plane differences)

Twelve docs (01-11, 16) now have implementation-level detail.

**Inv.cpp incorporation (agent add9af4)** - Expanded `06-item-system.md` with full inventory management detail from Inv.cpp (1631 lines). Promoted to fully-researched. Added:
- Character slot array vs monster linked list architecture
- Full equipment slot table (20+ SL_* slots with purposes)
- 11 wielding constraints (form, reach, magical clothing, armor, fiendish, planar, size, exotic, two-handed, alignment)
- Weapon exchange system (melee/ranged switching with defaults)
- PickUp flow with stacking priority
- Stacking rules and stack splitting
- Inventory operation timeouts (DEX-modified, feat-reducible)
- Container system (Insert validation, capacity checks, weight calculation, access time, lock picking DC, dump/pour)
- Packrat feat effects (2× capacity/weight, +1 max size, ½ access time)

**Move.cpp incorporation (agent ac94b1e)** - Expanded `05-combat-system.md` movement section from 24 lines to comprehensive coverage of Move.cpp (1259+ lines). Added:
- Walking validation, mount delegation, encumbrance abort
- Movement cost (terrain MoveMod, monster banking system with 5-unit bank and 12-segment floor)
- Immobilization states (STUCK escape DC, PRONE standing, CONFUSED random walk, AFRAID movement restriction)
- Passability checks (creatures, doors, illusions, bump penalties)
- Flying/swimming/phasing (aquatic, amphibious, aerial, plane-based)
- Jump mechanics (mounted/unmounted, DC formulas, max range, failure recovery, FT_MANTIS_LEAP)
- Push/pull (grapple breaking, displacement, friendly vs hostile)
- AoO from movement (reach weapon closing DC with size modifier, disengage BAB check, flee auto-AoO)
- Trap interaction (discovery, auto-disarm, trigger conditions, FT_FEATHERFOOT)
- Field interaction (sticky terrain balance DC, blocker fields, illusory terrain)
- Terrain entry/leave events and region transitions
- TerrainEffects (fall, sticky, elevation)
- Passive detection (move silently vs listen, secret door detection, mining, close identification)

**Creature.cpp incorporation (agent afb27f3)** - Expanded `04-creature-system.md` with Creature.cpp core mechanics (3356 lines). Added:
- DoTurn() 20-step per-turn processing (paralysis escape, terrain damage, resilience, engulfment, grappling, hunger/exercise, divine intervention, flat-footed, fatigue regen, combat readiness, mana recovery, status update, field effects, poison, disease, bleeding, natural/inherent regen, periodic effects)
- Mana recovery quadratic formula (ManaPulse, Concentration skill threshold 35-80%)
- Creature constructor initialization (7 steps)
- AddTemplate and Multiply (breeding/offspring)
- Hunger system (9 states from STARVED to BLOATED, Fasting ability, size scaling)
- Encumbrance system (strength-based with size multipliers, 5 EN_* levels)
- Fatigue system (LoseFatigue, unconsciousness threshold, Essiah favor)
- Challenge Rating calculation (template adjustments, character total levels)
- Flanking mechanics (adjacent ally opposite, Uncanny Dodge prevention)
- Saving throw bonus sources and exercise gains
- Planes of existence (6 PHASE_* types)
- Illusion system (isRealTo, disbelief, spectral/improved flags)
- Attribute death (7 cause strings)
- canMoveThrough collision detection (6-step check order)
- MoveAttr movement speed modifier (9 factors)

**Monster.cpp incorporation (agent a6415be)** - Expanded `04-creature-system.md` Monster class section with full AI system from Monster.cpp (~1100-line ChooseAction). Added:
- ChooseAction() two-stage decision loop (19-step action collation + weighted probability selection)
- Spell casting AI (ListEffects from 4 sources, AddEffect rating formula, friendly fire prevention via PredictVictimsOfBallBeamBolt)
- PreBuff() initialization buffs (duration-filtered, direct MagicEvent bypass)
- Gravity-based Movement() (target gravity, bad field repulsion, obstacle avoidance, stuck detection)
- SmartDirTo() three pathfinding modes (Dijkstra/pets-only/direct)
- RateAsTarget() (item evaluation with multipliers, creature evaluation with 12 racial antagonism pairs, player +25 priority, distance bonus)
- Monster Initialize() 12-step startup (initiative, peace flag, HP, targeting, elevation/hiding/phasing, item purification, weapon skills, size fields, prebuff)
- Equipment optimization (slot priority, weapon/armor rating formulas, M_MAGE armor restriction)
- Group behavior (AlertNew 12-square radius, emergent pack tactics, charm/compel override)

**Item.cpp incorporation (agent acab84f)** - Expanded `06-item-system.md` with Item.cpp implementation detail (2933 lines). Added:
- Armor value formulas (ArmVal with material bonuses, CovVal shield size comparison, DefVal, PenaltyVal with 6 quality modifiers + Armor Optimization feat)
- Mithril weight category shift (Heavy→Medium, Medium→Light)
- Corpse system (freshness, disease DC formula, weight by size, eating nutrition by size, cannibalism)
- Food mechanics (incremental eating, satiation, Slow Metabolism)
- Item creation (constructor, factory routing to 6 subclasses, Initialize with effect/quality/bane application, SetFlavors)
- Stacking rules (operator== with 8 checks, TryStack merging, poison merge by relative quantity)
- Item identification (MakeKnown with effect memory, IdentByTrial with INT exercise, VisibleID auto-ID)
- Item damage system (6-step processing, 9 destruction message types, container spill, Spellbreaker XP)
- Weight system (base formula, QItem quality modifiers, Psychometric Might)
- Material hardness (40+ materials, QItem modifiers: Dwarven +10, Adamant ×2, Mithril ×1.5, cursed +50)
- Item level calculations (weapon QPlus, armor QPlus×1.5)
- Weapon-specific (DamageType optimization, bane system, ParryVal formula with skill cap)

## 2026-01-30: Completing Correctness Research - All Docs Fully Researched

### Batch Expansion Session
Completed the review pass to expand all 18 correctness-research documents to implementation-level detail. This session processed the remaining docs that were still at "Architecture researched from headers" status.

**Documents expanded this session:**
- `14-social-quest.md` - Social.cpp: all 12 interaction modes, hostility system, companion PHD pools, shop pricing tables
- `15-ui-display.md` - Message.cpp grammar engine (XPrint format tags, article detection, name pipelines), Display.cpp rendering pipeline, Player.cpp input/rest systems
- `03-event-system.md` - Event.cpp: 128-entry EventStack, three-phase dispatch, 10-level handler priority chain, resource script interception
- `07-magic-system.md` - Magic.cpp/Effects.cpp/Prayer.cpp: spellcasting flow, 27 metamagic flags, spell resistance, effect archetypes, divine prayer system
- `12-encounter-generation.md` - Encounter.cpp: 7-stage generation pipeline, XCR budget math, template application, alignment constraints
- `13-skills-feats.md` - Skills.cpp/Create.cpp: SkillCheck multi-roll system, 29-step character creation, crafting, turning, level advancement
- `17-values-calcvalues.md` - Values.cpp: 19-phase computation order, AttrAdj bonus stacking, all attribute formulas, HP/resistance/skill computation

**Final status:** 17 of 18 docs fully researched. Doc 09 (map-system) notes "dungeon generation DONE (see specs/dungeon-generation/)" - detailed map generation specs exist in separate spec files.

---

## 2026-01-30: Social.cpp Correctness Research

Expanded `docs/research/correctness-research/14-social-quest.md` from a brief summary into a comprehensive implementation-level reference covering all of Social.cpp (2565 lines).

### Key Areas Documented
- **doSocialSanity()** - 11-step validation chain (speaker ability, line of fire, target response, silence, hiding, sleep, rage, paralysis, telepathy fallback, stun/confuse, ENEMY_TO)
- **Hostility system** - HostilityQual enum (Neutral/Enemy/Ally), HostilityQuant levels, HostilityWhy reasons (24 types), delegation pattern (Player checks defer to Monster perspective)
- **Social modifier (getSocialMod)** - 30+ racial solidarity/enmity pairs, alignment modifiers, Alluring feat, charm bonus, SOCIAL_MOD stati, comparative strength integration
- **Comparative strength** - XCR cubic aggregation formula, asymmetric visibility (actor's visible team vs target's full team), Adamant Facade HP-hiding, XCR/XCRtoCR conversion tables
- **Cow (Intimidation)** - DC = 10 + CR*3 (group: +10 + BestCR*3 + fear save), three result tiers (permanent/semi/temporary fear), gear drop mechanics
- **Offer Terms** - DC = 5 + CR*2, natural fear requirement, gear tribute on high margins
- **Quell** - DC = 15 + CR*3, damage penalty formula, evil creature tribute discount (-7 DC), Bluff vs Appraise to avoid payment, exploitation vs resolution alignment branching
- **Enlist** - DC 15/20/25 by creature type + CR*3, Perform/Appraise skill reductions, PHD budget check, alignment refusal logic, rejoin after amicable dismissal
- **PHD companion system** - 6 pool types, MaxGroupCR formulas per type, cubic XCR aggregation for group CR, pool overflow rules, FixSummonCR budget fitting
- **MakeCompanion()** - PHD check with per-type overflow failure, heroic quality bonus (+20 HP for adventurer party members), ally spell cleanup, auto-identification
- **Barter/Shop pricing** - base cost by item type, 41-entry price tables for shops (120-5000%) and barter (30-500%), diplomacy+social mod index, companion discount (+10 index)
- **Fast Talk** - DC = 10 + CR + max(Appraise, Concentration), success wastes target turns
- **Distract** - DC = 10/15 + resistance, retry penalty +5/+2, DISTRACTED stati for 2 turns
- **Taunt** - DC = 15 + Will*2, ENRAGED for Bluff-level turns
- **Greet** - random bonus by 300/diplomacy roll (magic mapping, danger warning, item hint, FP restore)
- **Request** - 6 request types with base DCs 10-20, skill choice (Diplomacy/Intimidate/Bluff), +3 retry penalty, failed non-diplomacy turns target hostile
- **Surrender** - DC 10 adjusted by comparative strength and lawful bonus, conditional vs unconditional (gold lein vs all treasures), chaotic betrayal 1/3 chance
- **canTalk()** - sapience check, plant exception for nature skill 10+, M_TALKABLE/M_NOTTALKABLE overrides, MA_ADVENTURER default, M_NOHEAD block, non-talkable type list
- **isPMType()** - Bluff conceals alignment, disguise penetration (Spot+Appraise, Sharp Senses, Scent, True Sight vs illusion)

**UI/Display system incorporation (agents aa0f7d1, ade1591)** - Expanded `15-ui-display.md` from 136 lines to comprehensive reference covering Message.cpp, Display.cpp, and Player.cpp. Added:
- XPrint format tag system (parameter tags, event-bound tags, pronoun/gender tags, special block tags)
- Buffer management (5-level recursive nesting, 130K+4K buffer sizes)
- Article/determiner look-behind detection (rewinding output buffer to inject NA_A/NA_THE flags)
- Numeric color codes (negative byte encoding, LITERAL_CHAR glyph mechanism)
- Name flags (15 NA_* flags controlling article, capitalization, identification, shadow, status prefixes)
- Message dispatch (6 modes: DPrint, APrint, VPrint, TPrint, Hear, SinglePrintXY)
- IPrint/IDPrint (POV-based formatting, message queue integration)
- Message queue system (stack-based, 8 slots, Set/Unset/Print/Empty)
- Creature name status prefix system (gender, HP ratio 7 tiers, 13 condition stati, hostility, awareness)
- Item name pipeline (14-field assembly: article through append, color rules for blessed/cursed)
- Glyph architecture (32-bit packing: 12-bit ID + 5-bit fore + 5-bit back)
- Thing::PlaceAt (9-step flow with field preservation, creature-first ordering, same-map optimization)
- PlaceNear (expanding-ring search up to r=40 for players, big creature handling, retry with displacement)
- Thing::Move (field interaction, engulfed carry, mount sync)
- Map::Update rendering pipeline (8-step: base glyph, size field, contents iteration with priority, shadow fallback, same-colour fix, visibility check with memory, multi-display indicators, overlay)
- Overlay system (per-map, activate/deactivate/add/remove glyph operations)
- Engulfed rendering (ASCII border in engulfer's colour)
- Player initialization (RecentVerbs, FFCount, default macros)
- ChooseAction input loop (pre-action checks, arrow key handling, auto-save every 200 actions)
- Rest system (pre-checks, encounter calculation with flood-fill, watch system, recovery for all creatures on all levels, encounter resolution with sleep/forewarning)
- REST flags (11 flags controlling rest behavior)
- SpendHours (awake time limit formula, hostile sight prevention)
- DaysPassed dungeon regeneration (7-step: strip timed stati, restore traps, repopulate to equilibrium, anti-scumming item stripping, staple item generation)
- Options system (900-slot byte array, 7 categories by 100-range, file I/O to Options.Dat)

## 2026-01-30: Encounter Generation Correctness Research

### Full Implementation Analysis of Encounter.cpp
Performed deep-dive analysis of the original `Encounter.cpp` (3346 lines) covering:

**XCR Budget Math**: The XCR formula is cubic `(CR+3)^3`, not exponential as earlier notes suggested. CR1=64, CR5=512, CR10=2197. Sub-zero CRs use a hardcoded lookup table.

**7-Stage Generation Pipeline**: Stage 0 (init), Stage 1 (region encounter list), Stage 2 (global encounter scan), Stage 3 (weighted selection), Stage 4 (part filtering: percentile, EP_ELSE, EP_OR), Stage 5 (XCR budget division with sleep/room-size scaling), Stage 6 (part generation), Stage 7 (build + party composition).

**Key Algorithms Documented**:
- Deviance testing (>50% triggers retry, max 5 attempts)
- Skew formulas for amount vs CR tradeoff (3:1 or 1:4 weighting)
- Template application priority (9 steps: explicit, universal, class, mount, freaky, skill, dragon age)
- Alignment constraint tightening (UpdateAlignRestrict progressive narrowing)
- Adaptive filling (dynamic count adjustment during generation)
- Monster selection filtering (CR, depth, aquatic, alignment, type, script criteria)
- Uniform selection cache (50-slot key-value cache for NF_UNIFORM encounters)
- Mount generation with undead rider auto-conversion
- Item generation with luck-based level adjustment and quality distribution

**HACKFIX noted**: Hard cap of 5 creatures per encounter (`cEncMem = min(cEncMem, 5)`).

Updated `docs/research/correctness-research/12-encounter-generation.md` with complete implementation-level detail.

## 2026-01-30: Event System Implementation Research

### Scope
Deep-dive into `Event.cpp` and related handler files to document implementation-level event dispatch mechanics. Extended `docs/research/correctness-research/03-event-system.md` from header-level research to full implementation detail.

### Key Findings

**Event Stack**: Fixed 128-entry `EventStack` array with stack pointer for recursive event dispatch. Originally 32, overflowed during gameplay.

**Three-Phase Dispatch (RealThrow)**: Every event fires in three phases -- `PRE(ev)`, `ev`, `POST(ev)` -- using arithmetic offsets (+500, +1000). PRE can abort/complete to prevent main; POST always fires unless ABORT.

**ThrowEvent Handler Priority Chain (10 levels)**:
1. Region at subject position
2. Terrain (if TF_SPECIAL)
3. Illusionary terrain
4. Dungeon resource
5. Field/effect resource
6. God conduct evaluation (actor, GODWATCH)
7. God conduct evaluation (victim, GODWATCH+EVICTIM)
8. Map object
9. TRAP_EVENT stati on parameter objects
10. Parameter objects via ThrowTo (p[3] down to p[0])

**ThrowTo Type Hierarchy**: Uses HIER macro to walk C++ inheritance chain. For a Player: `Player::Event -> Character::Event -> Creature::Event -> Thing::Event`. Each level can handle or pass to next.

**Resource Script Interception**: Resources use annotations with AN_EVENT type. Each annotation holds up to 5 event handlers. Positive event code = VM bytecode handler, negative = message string. EventMask (16-bit hash) provides fast rejection.

**ReThrow Bidirectional Propagation**: Changes to EventInfo during sub-events propagate back to caller (except Terse flag). RedirectEff is the one-way variant for triggering secondary effects.

**Event Code Arithmetic**: PRE(+500), POST(+1000), EVICTIM(+2000), EITEM(+4000), META(+10000), GODWATCH(+20000).

**Attack Flow Traced**: EV_ATTK -> EV_WATTACK -> EV_STRIKE (with PRE/POST) -> EV_HIT or EV_MISS -> EV_DAMAGE -> EV_DEATH. Each step goes through full handler chain.

**Bug Found**: PEVENT and DAMAGE macros set `e.EXVal = actor->y` instead of `e.EYVal = actor->y`.

## 2026-01-30: Magic/Effects/Prayer System Research

### Source Files Analyzed
- `Magic.cpp` (~3800 lines) - Core spellcasting, targeting, area-of-effect, spell rating, mana, metamagic, counterspelling, item magic
- `Effects.cpp` (~2350 lines) - Effect archetype implementations (Blast, Grant, Inflict, Healing, Summon, Polymorph, Terraform, Travel, Dispel, Reveal, Illusion, Creation)
- `Prayer.cpp` (~2000 lines) - Divine system: prayer, sacrifice, favour, transgression, divine intervention, altar conversion

### Specification Created
Full implementation-level spec written to `docs/research/specs/magic-effects-system.md` covering all three subsystems with formulas, constants, and control flow extracted directly from the original source code.

## 2026-01-30: CalcValues System Deep Research

### Source Files Analyzed
- `Values.cpp` (2620 lines) - Main CalcValues system, bonus stacking, resistance, HP, breakdown display
- `Creature.cpp` - Mod/Mod2/KMod/KMod2 modifier functions
- `Create.cpp` - SkillLevel, IAttr, CasterLev, GetBAB
- `Monster.cpp` - BestHDType
- `Tables.cpp` - GoodSave, PoorSave, ManaMultiplier, BonusSpells, FaceRadius lookup tables
- `Defines.h` - All 41 attribute indices, 39 bonus types, percent_attr/bonus_is_mult macros

### Document Updated
Fully rewrote `docs/research/correctness-research/17-values-calcvalues.md` with complete implementation details extracted from the original source. The document now covers:

- **Architecture**: Static AttrAdj[41][39] array, shared weapon pointers, recursion guard
- **Bonus stacking**: AddBonus/StackBonus with WESMAX macro, dodge/circ always stack, penalties always stack, MR uses diminishing returns
- **19-phase computation order**: From pre-calculation setup through post-calculation fixup, each phase documented with exact formulas
- **All attribute formulas**: Hit (5 modes), damage (5 modes), speed (5 modes), saves (3), defense, movement, armour, casting (5 types)
- **HP calculation**: Separate formulas for characters (roll-based + level + CON) and monsters (HD * HDType), size multipliers, template adjustments
- **Resistance system**: Diminishing returns stacking (100% + 50% + 33% each), immunity checks, armour integration
- **Skill computation**: ranks + Mod2(attr) + training + feats + synergy + armour penalty + size + many bonus categories
- **KnownOnly parameter**: Gates equipment enhancement bonuses behind identification, stores to KAttr[], Character always calculates both modes
- **Percent attributes**: Multiplicative composition for speed/movement with specific bonus types
- **Known bugs**: Penalty stacking from same source, WESMAX ordering dependency, possible archery BAB bug in speed calc
- **All lookup tables**: GoodSave, PoorSave, ManaMultiplier, BonusSpells, FaceRadius, MonHDType, MonGoodSaves, weapon skill bonuses, encumbrance penalties, size modifiers

## 2026-01-30: Magic System Correctness Research Update

Updated `docs/research/correctness-research/07-magic-system.md` from header-level research (290 lines) to full implementation-level detail (580+ lines). Incorporated all findings from the spec at `docs/research/specs/magic-effects-system.md` including:

- **Spellcasting flow**: Complete Creature::Cast with all pre-checks, component requirements, two-weapon penalty, timeout formula, staff fatigue, metamagic fatigue, bard spellbreak, mana check, success/failure roll with damage penalty and concentration buffer
- **Spell Rating**: Full formulas for both monster (Creature::SpellRating) and character (Character::SpellRating) versions with all modifiers
- **Spell Save DC**: Complete formula with all 10 components (base, level, attr, focus, will, beguile, trick, hard, height, affinity) plus item/trap/ability variants
- **Mana Cost**: Formula with metamagic multiplier, specialist school modifier, buff cost reduction, racial affinity
- **Metamagic**: Full table of 27 metamagic flags with feat mappings and effects
- **Spell Resistance**: d100 + CR*2 + penetration vs MR + CR*2 formula
- **Counterspelling**: Detection, counter selection, Spellcraft DC, mana cost reduction tiers, AI behavior options, reflective counterspell
- **Effect Calculation**: Caster level determination, range/radius/damage formulas, SpellDmgBonus
- **Duration**: All tiers with modifier stacking
- **Area-of-Effect**: All 12 area types with implementation details
- **Effect Archetypes**: Implementation details for Blast, Grant, Inflict, Drain, Healing, Polymorph, Summon, Dispel, Terraform, Travel, Illusion, Reveal, Vision, Creation
- **Item Magic**: Potion, scroll, wand, activation mechanics with formulas
- **Prayer System**: Complete divine flow including PrePray, Insight, IBlessing, Prayer, trouble priority, divine deflect, resurrection, altar conversion
- **Favour/Sacrifice**: calcFavour formula, sacrifice value calculation, impressive sacrifice thresholds, anger reduction
- **Transgression**: Anger accumulation, thresholds, forsake mechanics
- **Expanded porting considerations**: 12 items covering compound spells, spell rating variants, item magic flows, prayer system

## 2026-01-30: Skills, Feats & Character Creation Research

### Research Scope
Deep dive into two original Incursion C++ source files:
- `Skills.cpp` (5650 lines) - Skill system, class abilities, crafting, turning, devour, legend lore
- `Create.cpp` (4366 lines) - Character creation, attribute generation, level advancement, XP, feat prerequisites

### Document Updated
Fully rewrote `docs/research/correctness-research/13-skills-feats.md` with complete implementation-level details extracted from the original source. The document expanded from ~120 lines of header-only architecture notes to ~550 lines of implementation details including:

- **SkillCheck()**: Multi-roll system (2-3d20 for reliability skills), Skill Mastery minimum, Most Skilled Ally substitution, natural 20 restrictions, Suggestion clause for social skills, exercise on barely-succeeded checks
- **SkillLevel()**: 16+ bonus categories with stacking rules, feat-to-skill mappings (20 feat pairs), training bonus formula (+1 per source then +2 minimum), synergy system, armour check penalties, size modifier (Hide only), circumstance penalties (charging -20, singing -2)
- **MaxRanks table**: Progressive non-linear table allowing skill broadening at higher levels (not standard OGL)
- **Skill kit system**: Primary/secondary/rope/innate kit sources with short-circuit for kitless skills
- **Individual skills**: Listen (active with sound types and distance), Hide, Search, Handle Device, Animal Empathy, Heal, Disguise (race similarity DCs), Balance, Tumble, Jump
- **Class abilities**: Berserk Rage (armour-based fatigue, level-scaled bonus), Lay on Hands (heal/harm formula), Soothing Word, Tracking, Manifestation, Protective Ward, Feat of Strength, Unbind
- **Crafting system**: 7 crafting modes, XP cost table (21 entries), tempering mechanics, repair/augment paths
- **Legend Lore**: 7-tier progressive identification by `(10 + level + INT) - itemlevel`, Decipher for runic items
- **Turning undead**: `(check * 750) / (resist * 100)` ratio formula, 5 effect tiers, Command variant, divine feat integration
- **Devour system**: Resistance gains, attribute gains, dragon mana, theological consequences with deity-specific transgressions
- **Feat prerequisites**: DNF boolean evaluation (OR of ANDs), 12 condition types, IAttr() prevents item-boosted stat abuse
- **Character creation**: 29-step sequential flow, 3 attribute generation methods, point buy cost table, perk system with weighted types
- **Level advancement**: Full flow with alignment validation, HP/mana rolling options, feat granting schedule (every 3rd level + bonus at 1st)
- **XP system**: Base XP by CR table, 20-element CR-difference scale, slow advancement table, multiclass penalty rules, kill sharing
- **Studies system**: 8 study types mapping feats to class ability progression

## 2026-01-30: Game Loop Implementation

### Overview
Added a minimal game loop layer between the dungeon subsystem and frontends. This enables AI-driven headless testing, human GUI play, and deterministic command logs for replay/regression testing.

### Architecture
New `src/game/` module with four files:
- **`state.jai`** — `GameState`, `Action` enum (NONE, MOVE_N/S/E/W/NE/NW/SE/SW, WAIT, OPEN_DOOR, CLOSE_DOOR), `ActionResult`, conversion helpers
- **`hash.jai`** — FNV-1a 64-bit state hashing for determinism verification. Hashes seed, turn, depth, player position, all tiles, door states, monster/item positions.
- **`loop.jai`** — `init_game()`, `free_game()`, `do_action()`, movement with auto-open door (matching Incursion behavior), turn advancement with FOV recalculation
- **`log.jai`** — Command log write/read/parse. Text format with SEED/VERSION/DEPTH header, TURN action lines, CHECK checkpoint lines with hash.

### Key Design Decisions
- **GameState owns its own MT19937** — Isolated from the global dungeon generation RNG to preserve determinism
- **Heap allocation required** — GameState contains GenMap (~300KB fixed arrays), causes stack overflow if stack-allocated. All test code uses `New(GameState)`.
- **Player placement searches outward** — Room center may have a pillar (castle rooms), so `game_init_player_position` searches outward from center for nearest passable tile
- **Auto-open doors on walk** — Walking into a closed door opens it in one action (one logged MOVE_N, not two actions), matching Incursion. Locked doors block with message.
- **`game_can_move_to` vs `terrain_passable`** — New function allows floor, corridor, open doors, water, stairs, rubble. Closed doors handled separately in `do_move` (auto-open).

### Frontend Changes
- **`tools/dungeon_test.jai`** — Rewritten to use `GameState` + `do_action()`. Status line shows turn count. L key toggles command log recording.
- **`tools/headless.jai`** — New headless test harness. Runs action sequence, prints state/hash per turn, writes log file, verifies determinism.
- **`tools/replay.jai`** — New replay frontend. Reads command log, replays actions, supports `--verify` (checkpoint hash validation) and `--verbose` flags.

### Tests
Added `test_game_loop()` to `src/tests.jai` (8 test blocks):
- Init with seed, verify player in bounds and on passable terrain
- Movement succeeds from room center
- Same seed → same hash (determinism)
- Same seed + same actions → same final hash
- Wait advances turn
- `action_to_string`/`string_to_action` roundtrip for all 12 actions
- Hash changes when state changes
- Different seeds → different hashes
- Log write/parse roundtrip with checkpoint

### Verification Results
- **Unit tests**: 217 total, 213 passed, 4 failed (pre-existing mon1-4 parsing). All new game loop tests pass.
- **Headless**: Runs 13 actions, determinism check passes (hash matches across runs)
- **Replay**: Reads headless.log, replays all 13 actions, checkpoint verification passes
- **dungeon_test.jai**: Compiles and builds successfully with GameState integration

### Bug Fixes During Implementation
- **`starts_with` name collision** — Jai's Basic module exports `starts_with`, conflicting with local helper. Renamed to `log_starts_with`.
- **Bitmask negation** — `~DF_OPEN` produces a large s64 constant that doesn't fit in u8. Fixed with `xx,no_check ~DF_OPEN`.
- **Pillar at room center** — Seed 42 places a castle room whose center has a pillar. Fixed `game_init_player_position` to search outward from center.

## 2026-01-30: Correctness Gaps 1-3 Runtime Verification

### Context
A correctness analysis had flagged three potential gaps in the dungeon generation system: (1) region terrain not flowing to rooms, (2) room lighting not scaling with depth, (3) door states not being randomized. A plan-mode investigation determined all three were already implemented, and this session verified them at runtime.

### Verification Results

**All three features confirmed working via code review and test execution (217 tests, 213 passed, 4 pre-existing mon1-4 parse failures).**

**Region Terrain Pipeline** — Full end-to-end chain verified:
- `load_baked_regions()` populates `room_regions` from baked data (91 regions from dungeon.irh), with hardcoded test region fallback ensuring the array is never empty
- `resolve_region_terrains()` resolves string refs (e.g. "ice floor") to `*RuntimeTerrain` pointers via case-insensitive terrain registry lookup
- `get_region_floor()`/`get_region_wall()` (weights.jai:555-568) return resolved terrain or default — never null
- All 15+ room-drawing functions (`write_room`, `write_circle`, `write_octagon`, etc.) call these functions and pass results to `write_at_with_terrain()` → `map_set_with_display()` which sets custom glyph/color per tile

**Room Lighting** — `place_room_lights()` (makelev.jai:2824-2879):
- `lit_chance = 50 - 4*depth`, minimum 5%
- Torches placed on walls with 1-in-10 density
- Called in main generation loop at line 3913

**Door States** — `place_doors_makelev()` (makelev.jai:2725-2792):
- 14% secret, ~9% open, ~41% closed+locked, ~36% closed+unlocked
- Lock DC = `10 + depth*2 + random(5)`
- DoorInfo entries pushed to `m.doors` with appropriate DF_* flags

### Conclusion
No code changes needed. The earlier correctness analysis incorrectly identified these as gaps — all three features were already implemented and are functioning at runtime.

## 2026-01-30: Implement RM_RANDTOWN (Correctness Gap 4)

### Background
`RM_RANDTOWN` (constant 22) was defined in original Incursion but never implemented — it fell through to basic room generation. The Jai port had the same placeholder at the `draw_panel()` dispatch (`case RM_RANDTOWN; write_room(m, gs, r);`).

### Implementation
Added two new functions in `src/dungeon/makelev.jai` after `write_grid`:

**`write_town_building()`** — helper that draws one building within a grid cell:
- Wall perimeter at `PRIO_ROOM_FURNITURE` (75), overwriting street floor (70)
- Random size shrinkage within cell for visual variety (minimum 3×3)
- One door gap (floor at priority 75) placed on a random wall side

**`write_randtown()`** — main room writer following the standard pattern:
- Gets region floor/wall terrain via `get_region_floor`/`get_region_wall`
- Falls back to `write_room()` if panel too small (< 14 in either dimension)
- Grid calculation: `cols = max(2, min(3, w/7))`, `rows = max(2, min(4, h/7))`
- **Phase 1**: Floor-fill entire rect (creates streets between buildings)
- **Phase 2**: Place buildings in grid cells (~75% occupancy, guaranteed at least half)
- **Phase 3**: Outer perimeter walls (same pattern as `write_room`)
- **Phase 4**: Register Room + centers/corners for corridor connection

Updated `draw_panel()` dispatch to call `write_randtown` with panel-inset rect (matching castle/building pattern).

### Jai Type Considerations
Required explicit `s32` type annotations for grid arithmetic variables (`cols`, `rows`, `cell_w`, `cell_h`, `shrink_x`, `shrink_y`, etc.) because Jai's `min`/`max` and integer literal `0` produce `s64`, which then propagated through arithmetic to the `Rect` struct literal and `write_at_with_terrain` calls expecting `s32`.

### Verification
- Compiles cleanly
- All 213 tests pass (4 pre-existing mon1-4.irh failures unchanged)

## 2026-01-30: Streamer System Upgrade (Correctness Gap 5)

### Background
The streamer generation system (rivers, chasms, lava, rubble) had a significant deviation from the original. The port generated 0-1 streamers per level (single 30% chance), while the original generates **2-4 streamers** per level with a more sophisticated algorithm.

### Original Algorithm (MakeLev.cpp:1419-1464)
From `Annot.cpp:GetConst` defaults:
- `MIN_STREAMERS = 2` — guaranteed minimum per level
- `MAX_STREAMERS = 4` — hard cap
- `STREAMER_CHANCE = 70%` — chance for each additional beyond minimum
- `MIN_RIVER_DEPTH = 3` — rivers only on depth 3+
- `MIN_CHASM_DEPTH = 5` — chasms only on depth 5+
- `MAX_STREAMER_WIDTH = 5` — non-river max width
- No chasms on last dungeon level (nowhere to fall)
- 50% chance to **reuse** previous streamer type (`goto SecondStreamerSame`)
- Up to 20 tries to find valid type that passes depth restrictions

### Changes

**`DungeonConstants` struct** — added 7 new constants: `MIN_STREAMERS`, `MAX_STREAMERS`, `STREAMER_CHANCE`, `MAX_STREAMER_WIDTH`, `MIN_RIVER_DEPTH`, `MIN_CHASM_DEPTH`, `DUN_DEPTH` with defaults matching original `Annot.cpp:GetConst`.

**Streamer generation loop** (Step 2 in `makelev`) — replaced single 30% chance with original algorithm:
- Loop generates MIN_STREAMERS guaranteed, then STREAMER_CHANCE% each additional up to MAX_STREAMERS
- 50% chance to reuse previous type (matches `random(10) > 5` / `goto SecondStreamerSame`)
- Depth restrictions: rivers require MIN_RIVER_DEPTH, chasms require MIN_CHASM_DEPTH
- No chasms on last level
- Up to 20 tries for valid type selection (breaks if none found)

**`write_streamer()` function** — updated to match original `WriteStreamer()` (MakeLev.cpp:841-911):
- **Starting position**: Non-rivers now start at random map coordinates (original passes `1+random(LEVEL_SIZEX-2)`) instead of corner-based positions
- **Non-river max width**: Now uses `2 + random(MAX_STREAMER_WIDTH)` instead of hardcoded info table values
- **Meander ratios**: Fixed to `2 + random(10)` (was `2 + random(8)`)
- **Movement probability**: Fixed to `random(rx+ry) + 1 <= rx` matching original (was `random(rx+ry) < rx`)
- **Drawing loop**: Changed from symmetric `-half..+half` to `0..width-1` offset from `(sx - width/2)`, matching original

### Verification
- Compiles cleanly
- All 213 tests pass (4 pre-existing mon1-4.irh failures unchanged)
- Generated dungeons now have 2-4 streamers per level instead of 0-1

## 2026-01-30: Per-Type Room Sizing (Correctness Gap 6)

### Background
The original `MakeLev.cpp:DrawPanel` calculates room dimensions differently for each `RM_*` type. The port used a single generic formula (`ROOM_MINX + random(ROOM_MAXX - ROOM_MINX)`) with only `RM_LARGE` getting special treatment. Several room types were undersized or had wrong dimensions.

### Original Per-Type Formulas (from MakeLev.cpp)
Large-filling rooms use `max(panel/2, panel - (random(range) + offset))`:
- **RM_LARGE**: `range=8, offset=2` → fills most of panel
- **RM_LCIRCLE**: `range=5, offset=5` → large circle, less variation
- **RM_CROSS**: `range=8, offset=5` → large cross shape
- **RM_MAZE**: `range=8, offset=2` → fills most of panel
- **RM_CASTLE/RM_BUILDING**: `range=6, offset=2` → large building

Boosted standard rooms:
- **RM_CHECKER**: standard + 2 → slightly larger for checkerboard pattern
- **RM_PILLARS/RM_GRID**: standard + 3 → larger for pillar spacing, even dims enforced
- **RM_DOUBLE**: standard + 3 → room-within-room needs space

### Changes

**`draw_panel()` size calculation** — replaced single generic formula with per-type sizing:
- Added `large_size_x`/`large_size_y` helpers using the `max(panel/2, panel-(random(range)+offset))` pattern
- Each room type now gets its own formula matching the original
- RM_PILLARS/RM_GRID enforce even dimensions after placement (`r.x2 -= 1` if odd width/height)

**Dispatch cleanup** — removed hardcoded panel-inset rects that were workarounds for undersized rooms:
- RM_PILLARS: was `panel+2` inset → now uses properly sized `r`
- RM_CHECKER: was `panel+2` inset → now uses properly sized `r`
- RM_MAZE: was `panel+1` inset → now uses properly sized `r`
- RM_CASTLE: was `panel+2` inset → now uses properly sized `r`
- RM_DESTROYED: was `panel+2` inset → now uses properly sized `r`
- RM_GRID: was `panel+2` inset → now uses properly sized `r`
- RM_RANDTOWN: was `panel+2` inset → now uses properly sized `r`
- RM_DOUBLE: was `max(sx+4,10)` re-placement → now uses properly sized `r`
- Types that legitimately use full panel (RM_LIFECAVE, RM_RCAVERN, RM_DIAMONDS, RM_OVERLAP, RM_ADJACENT variants, RM_LIFELINK, RM_SHAPED) still pass `panel` directly

### Key Fixes
- **RM_LCIRCLE**: was identical to RM_CIRCLE (NO size adjustment). Now gets proper large size.
- **RM_CROSS**: was using generic 4-12 size. Now fills most of panel.
- **RM_CHECKER**: was using panel-inset instead of proper `standard+2` size.
- **RM_PILLARS/RM_GRID**: now enforce even dimensions for proper pillar/grid alignment.

### Verification
- Compiles cleanly
- All 213 tests pass (4 pre-existing mon1-4.irh failures unchanged)

## 2026-01-30: Correctness Gap 7 — Corridor Generation

Rewrote corridor generation to match the original MakeLev.cpp algorithm in three areas: constants, panel connection, and direction correction.

### Corridor Constants → DungeonConstants

Moved hardcoded module-level tunnel constants into `DungeonConstants` struct with correct defaults from `Annot.cpp:GetConst`:

| Constant | Old Value | New Value (matches original) |
|----------|-----------|------------------------------|
| TURN_CHANCE | 25 | 10 |
| SEGMENT_MINLEN | 3 (was SEGMENT_MIN_LEN) | 4 |
| SEGMENT_MAXLEN | 12 (was SEGMENT_MAX_LEN) | 10 |
| STUBBORN_CORRIDOR | 30 | 30 (unchanged) |
| MAX_CORRIDOR_LEN | 500 | 500 (unchanged) |

Updated all `carve_tunnel()` references to use `gs.con.*` instead of module constants.

### connect_panels Rewrite

**Old algorithm**: Find any floor tile within ±10 of panel center, connect right and bottom neighbors center-to-center.

**New algorithm** (matching MakeLev.cpp:1616-1696):
1. **Edge tile detection**: For each panel, collect all floor tiles that have at least one solid cardinal neighbor (edge tiles)
2. **Connection pattern**: Only connect left, up, and diagonal-up-left neighbors (original pattern, not right/down)
3. **Closest-pair matching**: For each pair of adjacent panels, find the closest pair of edge points using Manhattan distance
4. **Tunnel carving**: Route corridors between the closest edge points

This produces more natural corridor placement — corridors start from room/cavern edges rather than arbitrary center tiles.

### correct_dir Diametric Fix

**Bug**: When on the same row or column as the target, the old code unconditionally returned the direct direction. The original checks `!DIAMETRIC(direct, curr)` first — if the direct direction is opposite to the current heading, it falls through to the two-option distance-biased logic instead.

Also extracted `is_diametric()` helper for clarity.

### Jai Quirk: `xx` Variable Name
Jai disallows `xx` as a variable name due to auto-cast syntax ambiguity (`xx` is the auto-cast operator). Renamed to `lx`/`ly`.

### Verification
- Compiles cleanly (one fix for `xx` variable name)
- All 213 tests pass (4 pre-existing mon1-4.irh failures unchanged)

## 2026-01-30: Correctness Gap 8 — Diamond Rooms & Cavern Theming

Two room type corrections: complete rewrite of RM_DIAMONDS and wall streamer pass for RM_RCAVERN.

### write_diamonds Rewrite

**Old algorithm**: Filled the panel with floor, then placed diamond-shaped wall outlines in a grid pattern. This produced a room with pillar-like diamond shapes inside — completely wrong.

**New algorithm** (matching MakeLev.cpp:2640-2677 + WriteDiamond:664-685):
1. Panel inset by 7 on each side (original sizing)
2. Random start point within bounds
3. Generate 1-7 diamonds in chain formation
4. Each diamond uses 41-entry coordinate lookup table — a filled diamond shape with radius 4
5. Each new diamond is placed 6 cells away in a random diagonal direction (NE/NW/SE/SW)
6. At midpoint between each pair of diamonds, a closed door is placed
7. After all diamonds, `write_walls()` adds wall perimeter
8. Each diamond's center recorded for corridor connection

Extracted `write_diamond()` helper that writes a single 41-cell filled diamond and records its center.

### write_rcavern Wall Streamer Pass

**Missing feature**: The original WriteRCavern (MakeLev.cpp:590-599) has a post-placement wall streamer pass. After placing L-shaped floor areas and standard walls, if the region has custom wall terrain (different from default), it scans all rock tiles in the rect and converts any rock adjacent to floor into the region's custom wall type at `PRIO_ROCK_STREAMER` (5).

This creates a visual "halo" of themed wall around cavern floors, extending the region's aesthetic into surrounding rock. Only triggers when the region actually has custom walls.

### Verification
- Compiles cleanly on first attempt
- All 213 tests pass (4 pre-existing mon1-4.irh failures unchanged)

## 2026-01-30: Correctness Gap 9 — Deep Terrain Conversion

Added deep terrain variant types and post-processing conversion matching MakeLev.cpp:2139-2153. Water pools and lava lakes now have shallow edges with deep interiors.

### New Terrain Types

Added `DEEP_WATER` and `DEEP_LAVA` to the Terrain enum in `map.jai`. These behave identically to their shallow counterparts for passability/solidity, but render with darker foreground colors (dark blue / dark red vs bright blue / bright red) to visually distinguish depth.

Also added `terrain_is_water()` and `terrain_is_lava()` helper functions that check for both shallow and deep variants. Updated all terrain checks across the codebase:
- `find_open_in_room()` — walkable terrain, aquatic/non-aquatic placement
- `populate_panel()` — water detection for aquatic monster chance
- `is_valid_stair_pos()` — hazard terrain exclusion
- `game/loop.jai` — passable terrain check

### Deep Conversion Algorithm

New `convert_deep_terrain()` function runs as Step 5.8 in the generation pipeline (after rooms/corridors/lights, before doors/traps/population).

For each WATER or LAVA tile, checks all 8 neighbors. If every neighbor is either the same shallow type, the deep variant, solid, or out of bounds — converts to the deep variant. This naturally creates:
- Shallow water at pool/river edges (adjacent to floor or rock)
- Deep water in pool/river interiors
- Same for lava

The original processes 3 pairs (water, brimstone/magma, igneous/obsidian). We implement 2 pairs (water, lava). The third pair (brimstone/magma) can be added when those terrain types are integrated from resource files.

### Verification
- Compiles cleanly on first attempt
- All 213 tests pass (4 pre-existing mon1-4.irh failures unchanged)
