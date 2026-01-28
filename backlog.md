# Backlog

## MVP Progress

### Completed
- [x] Phase 4: Terminal Renderer - Bitmap font rendering working
- [x] Phase 2: Dungeon Generator (basic) - BSP rooms + corridors
- [x] Phase 2: Dungeon Generator (enhanced) - Room shapes, water pools, rougher corridors
- [x] Parser: All test .irh files parse successfully (2026-01-28)
  - flavors.irh (883), mundane.irh (73), domains.irh (44), weapons.irh (118), enclist.irh (87), dungeon.irh (184)

### In Progress

### Not Started
- [ ] Phase 1: Resource Baking - Compile-time .irh to runtime tables
- [x] Phase 3: Population System - Per-panel population, item distribution, furnishing (2026-01-28)
- [x] Phase 5: Inspection Interface - `tools/inspect.jai` CLI tool (2026-01-28)
- [ ] Phase 6: Integration & Testing - Wire everything together

## Dungeon Generator Improvements Needed

### Room Variety
- [x] Circular rooms
- [x] Octagonal rooms
- [x] Cross-shaped rooms
- [x] Diamond-shaped rooms
- [ ] Irregular caverns (WriteRCavern, WriteLifeCave style)
- [ ] Castle-style subdivided rooms (WriteCastle)

### Terrain Features
- [x] Water pools
- [ ] Rivers/streamers (linear water features)
- [ ] Chasms
- [ ] Special terrain from region definitions

### Structural Features
- Doors at room entrances (currently basic detection)
- Secret doors
- Traps
- Altars, fountains, etc.

### Connection Improvements
- More natural corridor shapes
- Occasional dead ends
- Room connection verification (flood fill)

## Current Parsing Issues

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
- Game loop integration
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

### Terminal Renderer
- Font path fallback is hacky (tries both `fonts/` and `../fonts/`)
- Could use Jai's `#run` to embed font at compile time

### Dungeon Generator
- BSP tree nodes are individually allocated (could use pool)
- Room array uses dynamic allocation (could be fixed size for MVP)
- No validation that all rooms are connected
