# Backlog

## MVP Progress

### Completed
- [x] Phase 4: Terminal Renderer - Bitmap font rendering working
- [x] Phase 2: Dungeon Generator (basic) - BSP rooms + corridors
- [x] Phase 2: Dungeon Generator (enhanced) - Room shapes, water pools, rougher corridors
- [x] Parser: All test .irh files parse successfully (2026-01-28)
  - flavors.irh (883), mundane.irh (73), domains.irh (44), weapons.irh (118), enclist.irh (87), dungeon.irh (184)
- [x] Phase 3: Population System - Per-panel population, item distribution, furnishing (2026-01-28)
- [x] Phase 5: Inspection Interface - `tools/inspect.jai` CLI tool (2026-01-28)
- [x] Phase 1: Resource Baking - Runtime .irh parsing to embedded tables (2026-01-28)
  - 429 monsters, 201 items, 53 terrains, 91 regions baked
  - Binary search lookups working
  - Extended glyph codes (256+) preserved
  - Baked terrains/regions flow through to dungeon generation

### In Progress
- [ ] Phase 6: Integration & Testing - Wire everything together
  - [x] Baked resources integrated with dungeon viewer (2026-01-28)
  - [ ] Full end-to-end gameplay test

- [x] Game Loop - GameState, Actions, Log, Hash, headless/replay tools (2026-01-30)

### Not Started

## Dungeon Generator Improvements Needed

### Room Variety
- [x] Circular rooms
- [x] Octagonal rooms
- [x] Cross-shaped rooms
- [x] Diamond-shaped rooms
- [x] Irregular caverns (write_rcavern, write_lifecave)
- [x] Castle-style subdivided rooms (write_castle)

### Terrain Features
- [x] Water pools
- [x] Rivers/streamers (write_streamer)
- [x] Chasms (CHASM terrain type)
- [x] Special terrain from region definitions (53 terrains from dungeon.irh)

### Structural Features
- [x] Doors at room entrances (place_doors_makelev)
- [x] Secret doors (DOOR_SECRET terrain, 5% chance)
- [x] Traps (place_traps with TRAP_CHANCE)
- [x] Treasure deposits in walls (place_deposits)
- [ ] Altars, fountains, etc. (need region terrain)

### Connection Improvements
- [x] More natural corridor shapes (roughen_corridor)
- [x] Corridor edge clamping (prevent hitting map edge)
- [x] Room connection verification (fixup_tunneling with flood fill)
- [ ] Occasional dead ends

## Current Parsing Issues

### Monster Files (mon1-4.irh) - PARTIAL
- Files partially parse (425 of ~600 monsters recovered)
- **Unsupported syntax:**
  - SC_WEA bare constants (need context-sensitive tokenization)
  - ABILITY() macro calls (function-like macros with complex args)
  - Multi-line Desc blocks (string continuation handling)
- Parser continues after errors to recover partial data
- Not critical for MVP - enough monsters for testing

### mundane.irh - FIXED (2026-01-28)
- ~~Line 659: `Potion Effect "flask of oil"` - Fixed with preprocessor alias + compound effect parsing~~
- ~~Line 916: "Expected ':'" - Fixed with optional colon support~~

### weapons.irh - FIXED (2026-01-28)
- ~~Line 345: "Expected ':'" - Fixed with optional colon for `Group` property~~

### dungeon.irh - FIXED (2026-01-28)
- ~~Line 5: Global variable declarations - Fixed with type keyword detection and skip~~
- ~~Line 14+: `$"ref"` resource references - Fixed with RES_REF token handling in constants~~
- ~~KW_MOV vs KW_MOVE mismatch - Fixed terrain/feature parsing~~
- ~~Effect `and` continuation blocks - Fixed with while loop after effect body~~
- ~~Color alias "skyblue" - Fixed lexer to recognize as KW_SKY~~
- ~~Flags separator `|` - Fixed parse_flags_list to accept pipe~~
- ~~Multi-line #define macros - Fixed lexer preprocessor handling~~
- ~~Bare numbers in Image specs - Fixed parse_glyph_image to accept NUMBER~~

## Workarounds in Place

### Event Handler Skipping
- Event handlers (`On Event ... { code }`) are currently skipped entirely
- Handler code translation is deferred - this is where most game logic lives
- See `skip_event_handler()` in parser.jai

### Preprocessor Handling
- `#if 0` / `#endif` blocks are skipped in lexer
- Multi-line `#define` macros with backslash continuation are skipped
- Function-like macros (e.g., `OPT_COST(a,b)`) are parsed but return last arg value
- Preprocessor aliases (Potion, Scroll, etc.) are recognized via `lookup_preprocessor_alias()`

## Ideas for Later

### Parser Improvements
- **Compound resource types**: `Potion Effect "..."` syntax not supported
- **Error recovery**: Could improve to skip to next resource on error
- **Line number tracking**: Some error positions seem off (may be due to multiline strings)

### Grammar Alignment
- Compare remaining resource types against Grammar.acc
- Template parsing may have edge cases
- Region parsing may have edge cases

### Testing Improvements
- Add more targeted unit tests for edge cases
- Consider fuzzing with random valid inputs
- Test against all .irh files in the original source

### Future Work
- Event handler code translation (major effort)
- Resource linking (references between resources)
- ~~Game loop integration~~ (done 2026-01-30)
- Actual game functionality
- **Design annotation pass** - Late in development, review original Incursion source code and annotate our code with design-related comments explaining *why* things work the way they do. Future developers would find these historical/architectural insights valuable.

## Claude-Driven GUI Testing (Brainstorm)

Ideas for enabling Claude Code to drive and test the GUI:

### Simulated Input Approaches
1. **GUI_Test module** - Jai has built-in `GUI_Test` module for synthetic input
   - Can send keyboard events, mouse clicks, mouse movement
   - Can capture screenshots for verification
   - Designed for automated testing workflows

2. **Input injection** - Direct keyboard/mouse event injection
   - Send synthetic keypresses via Window_Creation module
   - Useful for testing player movement, menu navigation

3. **Replay files** - Record and playback input sequences
   - Store input streams as files (timestamp, event)
   - Deterministic replay for regression testing

### State Access Approaches
4. **Inspection interface** - Text-based queries (Phase 5)
   - `dump` - ASCII map view
   - `query x,y` - Get cell contents
   - `stats` - Game state summary
   - Machine-parseable JSON output mode

5. **Debug IPC** - Inter-process communication
   - Named pipe or socket for debug commands
   - Query game state from external process
   - Claude could run alongside game and query state

6. **Shared memory** - Direct memory access
   - Map game state to shared memory region
   - External tools can read game state in real-time
   - Fast, zero-copy access

7. **Debug console** - In-game command line
   - Execute game commands (teleport, spawn, modify)
   - Query state with structured output
   - Useful for both testing and debugging

### Screenshot Verification
8. **Expected output comparison**
   - Capture reference screenshots with known seeds
   - Diff against current output
   - Pixel-level or glyph-level comparison

9. **OCR-based verification**
   - Read glyphs from screenshots
   - Verify expected characters at positions
   - Works without internal state access

### Hybrid Approaches
10. **Test harness mode** - Special build for testing
    - Expose all game state via API
    - Hook input at application level
    - Combined read/write access for full control

## Technical Debt

### Glyph Rendering (HIGH PRIORITY)

**Current Problem**: Extended glyphs (GLYPH_FLOOR = 323, GLYPH_WALL = 264, etc.) render as "?" in screenshots because the bitmap font only has 256 characters.

**Root Cause Understanding** (corrected 2026-01-28):
- **Fonts are the PRIMARY display** - the original Incursion used CP437 bitmap fonts (256 chars in 16x16 grid)
- Unicode/ASCII in `Wcurses.cpp` is a **fallback** for pure text terminals, not the main rendering path
- GLYPH_* constants are **aliases** that map to CP437 character codes via lookup table
- **Color is applied separately** from glyphs - lava (red) and water (blue) share the same glyph image (CP437 code 247)

**Solution Required**:
1. Implement GLYPH_* to CP437 lookup table based on `Wlibtcod.cpp` lines 448-600
2. Key mappings from original source:
   - `GLYPH_FLOOR (323)` → CP437 code 250 (middle dot ·)
   - `GLYPH_FLOOR2 (324)` → CP437 code 249 (small square)
   - `GLYPH_WALL (264)` → CP437 code 177 (medium shade ▒)
   - `GLYPH_ROCK (265)` → CP437 code 176 (light shade ░)
   - `GLYPH_WATER` → CP437 code 247 (almost equal ≈)
   - `GLYPH_LAVA` → CP437 code 247 (same glyph, different color)
3. For glyphs 256+, use lookup table to get CP437 code (0-255)
4. For glyphs 0-255, use directly as CP437 code
5. Our 8x8.png font is already CP437 layout, so this should "just work" once mapping is added

**Reference Files**:
- `C:/Data/R/roguelike - incursion/repo-work/src/Wlibtcod.cpp` - Primary glyph→CP437 lookup table
- `C:/Data/R/roguelike - incursion/repo-work/src/Wcurses.cpp` - Unicode fallback (NOT primary)
- `C:/Data/R/roguelike - incursion/repo-work/inc/Defines.h` - GLYPH_* constant definitions

### Terminal Renderer
- Font path fallback is hacky (tries both `fonts/` and `../fonts/`)
- Could use Jai's `#run` to embed font at compile time

### Dungeon Generator
- BSP tree nodes are individually allocated (could use pool)
- Room array uses dynamic allocation (could be fixed size for MVP)
