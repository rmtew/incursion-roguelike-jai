# Backlog

## MVP Progress

### Completed
- [x] Phase 4: Terminal Renderer - Bitmap font rendering working
- [x] Phase 2: Dungeon Generator (basic) - BSP rooms + corridors
- [x] Phase 2: Dungeon Generator (enhanced) - Room shapes, water pools, rougher corridors

### In Progress

### Not Started
- [ ] Phase 1: Resource Baking - Compile-time .irh to runtime tables
- [ ] Phase 3: Population System - Monsters, items from encounter tables
- [ ] Phase 5: Inspection Interface - Claude-queryable state dumps
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

### mundane.irh (15 errors)
- Line 659: "Expected resource definition" - Need to investigate
- Line 916: "Expected ':'" - Syntax issue to investigate

### weapons.irh (15 errors)
- Line 345: "Expected ':'" - `Group WG_SIMPLE` missing colon (may be source file typo)
- Cascade errors from line 345

## Workarounds in Place

### Event Handler Skipping
- Event handlers (`On Event ... { code }`) are currently skipped entirely
- Handler code translation is deferred - this is where most game logic lives
- See `skip_event_handler()` in parser.jai

### Preprocessor Handling
- `#if 0` / `#endif` blocks are skipped in lexer
- Other preprocessor directives are not handled
- Function-like macros (e.g., `OPT_COST(a,b)`) are parsed but return last arg value

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

## Technical Debt

### Terminal Renderer
- Font path fallback is hacky (tries both `fonts/` and `../fonts/`)
- Could use Jai's `#run` to embed font at compile time

### Dungeon Generator
- BSP tree nodes are individually allocated (could use pool)
- Room array uses dynamic allocation (could be fixed size for MVP)
- No validation that all rooms are connected
