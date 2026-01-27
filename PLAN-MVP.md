# MVP Plan: Dungeon Generation with Terminal View

## Target
A working dungeon generator that produces fully populated dungeons (terrain, features, monsters, items) rendered in a glyph terminal window, with an inspection interface that Claude can use for automated testing.

## Key Jai Modules

| Module | Use Case |
|--------|----------|
| **Bucket_Array** | Registry storage - stable handles across growth |
| **Pool** | Game state arena with reset capability |
| **Bit_Array** | FOV, explored tiles (8x memory savings) |
| **Hash_Table** | Resource lookup by name/ID |
| **PCG** | Deterministic RNG for reproducible dungeons |
| **Hash** | Coordinate hashing for procedural content |
| **Relative_Pointers** | Save files that survive mmap |
| **Simp** | Glyph rendering |
| **Command_Line** | CLI args from struct reflection |
| **Iprof** | Performance profiling (`-plug Iprof`) |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        COMPILE TIME                              │
├─────────────────────────────────────────────────────────────────┤
│  .irh files → Lexer/Parser → Baked Resource Tables              │
│  (TMonster[], TItem[], TTerrain[], TFeature[], etc.)            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                         RUNTIME                                  │
├─────────────────────────────────────────────────────────────────┤
│  Dungeon Generator                                               │
│    ├── Map Layout (rooms, corridors, special areas)             │
│    ├── Terrain Placement (floors, walls, doors)                 │
│    ├── Feature Placement (traps, altars, fountains)             │
│    ├── Monster Spawning (encounter tables, CR scaling)          │
│    └── Item Placement (loot tables, treasure)                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      GAME STATE                                  │
├─────────────────────────────────────────────────────────────────┤
│  Map (terrain grid, LocationInfo per cell)                      │
│  Registry (handle-based object storage)                         │
│  Object Lists (monsters, items, features by location)           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    TERMINAL RENDERER                             │
├─────────────────────────────────────────────────────────────────┤
│  Game State → Glyph Buffer (char + fg color + bg color)         │
│  Glyph Buffer → Simp font rendering → Window                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   INSPECTION INTERFACE                           │
├─────────────────────────────────────────────────────────────────┤
│  Commands: dump, query, seed, regenerate, quit                  │
│  Output: Text dumps, JSON state, screenshot triggers            │
│  For Claude: Parseable output format for verification           │
└─────────────────────────────────────────────────────────────────┘
```

## Phase 1: Resource Baking (Compile-Time)

**Goal:** Convert parsed .irh data into efficient runtime lookup tables.

### Tasks
1. Define runtime resource structs (leaner than ParsedX versions)
   - `RMonster` - runtime monster template
   - `RItem` - runtime item template
   - `RTerrain` - runtime terrain type
   - `RFeature` - runtime feature type
   - `REncounter` - encounter spawn table

2. Create resource compiler (`#run` block)
   - Parse all .irh files at compile time
   - Validate and link cross-references
   - Generate static arrays of resources
   - Build lookup tables (by name, by ID)

3. Export baked data
   - Constant arrays embedded in binary
   - Fast O(1) lookup by resource ID

### Files to Create
- `src/resource/bake.jai` - Compile-time resource processing
- `src/resource/runtime.jai` - Runtime resource structs

## Phase 2: Dungeon Generator Core

**Goal:** Generate dungeon layouts with rooms, corridors, and terrain.

### Tasks
1. Study original Incursion dungeon generation
   - Find relevant source files in original C++ code
   - Understand room placement algorithms
   - Understand corridor connection logic

2. Implement map generation
   - Room generation (various sizes/shapes)
   - Corridor carving (A* or simple pathfinding)
   - Door placement at room entries
   - Stair placement (up/down connections)

3. Terrain application
   - Floor types based on dungeon theme
   - Wall types
   - Special terrain (water, lava, etc.)

### Files to Create/Modify
- `src/dungeon/generator.jai` - Main generation logic
- `src/dungeon/rooms.jai` - Room templates and placement
- `src/dungeon/corridors.jai` - Corridor algorithms
- `src/map.jai` - Extend with generation support

## Phase 3: Population System

**Goal:** Place monsters, items, and features in the dungeon.

### Tasks
1. Encounter system
   - Parse encounter tables from enclist.irh
   - CR-based monster selection
   - Group spawning logic

2. Monster placement
   - Room-based spawning
   - Patrol routes (optional for MVP)
   - Lair placement for bosses

3. Item placement
   - Treasure generation
   - Equipment distribution
   - Consumables in appropriate locations

4. Feature placement
   - Traps (based on dungeon depth)
   - Altars, fountains, etc.
   - Interactive objects

### Files to Create
- `src/dungeon/populate.jai` - Population orchestration
- `src/dungeon/encounters.jai` - Encounter table logic
- `src/dungeon/loot.jai` - Item generation

## Phase 4: Terminal Renderer

**Goal:** Render the dungeon as colored glyphs in a window.

### Memory Strategy

Use Jai's temporary allocator for per-frame work:

```jai
// Persistent (game state, lives across frames)
game_state: *GameState;  // Pool-allocated objects

// Temporary (rebuilt each frame, auto-reset)
render_frame :: () {
    // All allocations here use temporary_allocator
    push_allocator(temp);

    glyph_buffer := build_glyph_buffer(game_state.map);
    render_glyphs(glyph_buffer);

    // temp allocator reset at frame end - no cleanup needed
}
```

### Tasks
1. Glyph buffer system (temporary allocation)
   ```jai
   GlyphCell :: struct {
       char: u32;        // Unicode codepoint
       fg: Color;        // Foreground color
       bg: Color;        // Background color
   }

   // Built fresh each frame into temporary memory
   build_glyph_buffer :: (map: *Map) -> [] GlyphCell {
       cells := NewArray(map.width * map.height, GlyphCell, allocator=temp);
       // ... populate from game state
       return cells;
   }
   ```

2. Map-to-glyph conversion
   - Terrain → base glyph
   - Features overlay
   - Monsters overlay
   - Items overlay (if no monster)
   - Visibility/fog of war (optional for MVP)

3. Simp integration
   - Load a monospace font (or use original Incursion font)
   - Render glyph grid with colors
   - Handle window resize

4. Color system
   - Map Incursion's color constants to RGB
   - Support bright/dim variants
   - Background colors for special terrain

### Files to Create
- `src/terminal/buffer.jai` - Glyph buffer management
- `src/terminal/render.jai` - Simp rendering
- `src/terminal/colors.jai` - Color definitions
- `src/terminal/window.jai` - Window management

## Phase 5: Inspection Interface

**Goal:** Enable Claude to query and verify dungeon state.

### Tasks
1. Text dump command
   ```
   > dump
   ################################
   #.......#......#...............#
   #.......+......#.g.............#
   #.......#......#...............#
   #####+###......######+##########
       #.................#
       #........@........#
       ###################
   ```

2. Query commands
   ```
   > query 10,5
   Location (10,5):
     Terrain: FLOOR (T_FLOOR)
     Feature: none
     Monster: goblin (CR 1, HP 4/4)
     Items: none

   > stats
   Map: 80x25
   Monsters: 12
   Items: 8
   Features: 3
   Seed: 12345
   ```

3. Control commands
   ```
   > seed 12345      # Set RNG seed
   > regenerate      # Generate new dungeon
   > screenshot      # Trigger GUI_Test capture
   > quit            # Exit
   ```

4. Parseable output format
   - JSON mode for structured queries
   - Consistent format Claude can parse
   - Deterministic output for verification

### Files to Create
- `src/terminal/inspect.jai` - Command parsing and execution
- `src/terminal/dump.jai` - Text dump generation

## Phase 6: Integration & Testing

**Goal:** Wire everything together and verify correctness.

### Tasks
1. Main loop
   - Initialize window
   - Generate dungeon with seed
   - Render loop
   - Input handling (inspection commands)

2. Deterministic verification
   - Same seed → same dungeon
   - Screenshot comparison
   - State dumps for regression testing

3. Claude testing protocol
   - Generate dungeon with known seed
   - Capture screenshot via GUI_Test
   - Verify expected glyphs at positions
   - Report any discrepancies

### Files to Create/Modify
- `src/main.jai` - Main loop integration
- `src/tests_visual.jai` - Visual verification tests

## Original Source Files to Study

From `C:\Data\R\roguelike - incursion\repo-work\`:

| Area | Files to Study |
|------|----------------|
| Dungeon Gen | `src/Map.cpp`, `src/Dungeon.cpp` |
| Rooms | Look for room generation code |
| Monsters | `src/Monster.cpp`, `src/Combat.cpp` |
| Items | `src/Item.cpp` |
| Rendering | `src/Term.cpp`, `src/Screen.cpp` |

## Memory Architecture

Jai's allocator system gives us clean separation:

```
┌─────────────────────────────────────────────────────────────────┐
│                    STATIC (compile-time)                         │
├─────────────────────────────────────────────────────────────────┤
│  Baked resource tables (RMonster[], RItem[], etc.)              │
│  Constant data embedded in binary                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 PERSISTENT (session lifetime)                    │
├─────────────────────────────────────────────────────────────────┤
│  Game State Arena                                                │
│    ├── Map grid (terrain, flags per cell)                       │
│    ├── Object Registry (handle → object mapping)                │
│    └── Object Pools (Monster, Item, Feature instances)          │
│                                                                  │
│  Allocated once per dungeon, freed on regenerate                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 TEMPORARY (per-frame, auto-reset)                │
├─────────────────────────────────────────────────────────────────┤
│  Glyph buffer for rendering                                      │
│  Command parsing / inspection output strings                     │
│  Pathfinding scratch buffers                                     │
│  Any intermediate computation                                    │
│                                                                  │
│  Reset automatically at end of each frame                        │
└─────────────────────────────────────────────────────────────────┘
```

**Benefits:**
- No per-frame allocator churn for rendering
- Game state is contiguous, cache-friendly
- Generation scratch work is free (just reset temp)
- Clear ownership: persistent state vs throwaway work

## Dependencies Between Phases

```
Phase 1 (Baking) ──────┬──→ Phase 2 (Generator)
                       │
                       ├──→ Phase 3 (Population)
                       │
                       └──→ Phase 4 (Renderer)
                                    │
Phase 5 (Inspection) ←─────────────┘
                                    │
Phase 6 (Integration) ←────────────┘
```

Phases 2, 3, 4 can be worked on somewhat in parallel once Phase 1 is complete.

## Success Criteria for MVP

1. **Deterministic Generation**: Same seed always produces identical dungeon
2. **Visual Output**: Colored glyph terminal showing map, monsters, items
3. **Inspection**: Claude can query any cell and get structured data
4. **Screenshot Verification**: GUI_Test can capture and verify pixels
5. **No Gameplay Yet**: No player movement, combat, or game loop - just view and inspect

## Estimated Complexity

| Phase | Effort | Notes |
|-------|--------|-------|
| 1. Baking | Medium | Need to finalize parser, design runtime structs |
| 2. Generator | High | Core algorithm work, study original code |
| 3. Population | Medium | Uses encounter tables, straightforward |
| 4. Renderer | Medium | Simp is well-documented |
| 5. Inspection | Low | Text processing, simple commands |
| 6. Integration | Low | Wiring existing pieces |

## Next Immediate Steps

1. Study original Incursion dungeon generation code
2. Design runtime resource structs (RMonster, etc.)
3. Create the compile-time baking system
4. Prototype terminal renderer with Simp
