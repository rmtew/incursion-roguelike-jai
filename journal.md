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

- [x] RM_ADJACENT/RM_AD_ROUND/RM_AD_MIXED (four-quadrant rooms)
- [x] RM_PILLARS (room with pillar grid)
- [x] RM_DOUBLE (room within room)
- [x] RM_MAZE (recursive backtracker maze)
- [x] RM_CHECKER (checkerboard pattern)
- [x] RM_DIAMONDS (grid of diamond squares)
- [x] Streamers (water rivers, chasms - 30% chance per level)
- [x] Door placement (70% closed, 20% open, 10% secret)
- [x] Stair placement (up in first room, down in last room)

### Room Type Distribution (Updated)

| Roll | Room Type |
|------|-----------|
| 0-19 | RM_NORMAL (20%) |
| 20-29 | RM_CIRCLE (10%) |
| 30-37 | RM_OCTAGON (8%) |
| 38-45 | RM_CROSS (8%) |
| 46-53 | RM_LARGE (8%) |
| 54-59 | RM_OVERLAP (6%) |
| 60-65 | RM_ADJACENT/AD_ROUND/AD_MIXED (6%) |
| 66-71 | RM_PILLARS (6%) |
| 72-77 | RM_DOUBLE (6%) |
| 78-83 | RM_MAZE (6%) |
| 84-87 | RM_CHECKER (4%) |
| 88-91 | RM_DIAMONDS (4%) |
| 92-99 | RM_LIFECAVE (8%) |

### Still TODO for Full MakeLev Compatibility

- [ ] Weighted room selection from dungeon definition resources
- [ ] Full Tunnel() algorithm (original has direction preferences, window carving)
- [ ] RM_CASTLE/RM_BUILDING (subdivided rooms)
- [ ] RM_RCAVERN (repeated-L rough caverns)
- [ ] More streamer types based on region definitions
- [ ] Vault placement (special pre-designed rooms)
