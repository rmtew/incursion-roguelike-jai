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
