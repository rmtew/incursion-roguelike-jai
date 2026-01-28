# Incursion Port - Claude Code Project Guide

## Directives for Future Sessions

1. **Document discoveries** - Add learnings about the Incursion codebase to this file
2. **Link to detail files** - For extensive details, create separate files (e.g., RECONSTRUCTION*.md) and link from here
3. **Keep this file scannable** - Use headers and bullet points; move large content to linked files
4. **Lexer/Parser: Implement from grammar spec, test against .irh files** - The authoritative reference for lexer/parser implementation is in `lang/Tokens.lex` and `lang/Grammar.acc`. Implement to match these specifications, then validate against actual `.irh` resource files.
5. **Maintain JOURNAL.md** - Record summaries of changes made in each session by appending new entries. Include what was changed, why, and test results.
6. **Maintain backlog.md** - Track workarounds, deferred work, and ideas for future improvements. Update when adding workarounds or identifying issues to revisit later.

## Environment

- **Shell**: Git Bash on Windows (cmd/terminal)
- **Python**: Use `py` command (not `python`)
- **Jai Compiler**: `C:/Data/R/jai/bin/jai.exe`
- **Jai Version**: `beta 0.2.025` (released 2026-01-19, last verified: 2026-01-28)

## Project Structure

```
incursion-port/
  README.md              - Project overview for GitHub
  LICENSE                - MIT license (our code) + note about upstream licenses
  LICENSE-INCURSION      - Upstream Incursion licenses (BSD/Apache/Expat + OGL)
  CLAUDE.md              - This file (project guide)
  PLAN-MVP.md            - MVP roadmap: dungeon generation with terminal view
  JOURNAL.md             - Development journal with change summaries
  backlog.md             - Workarounds, deferred work, and future ideas
  src/
    main.jai             - Entry point, imports all modules, runs tests
    defines.jai          - Core types: Dir, Glyph, hObj, rID, colors
    dice.jai             - Dice struct, roll, parse_dice
    object.jai           - Object/Thing base with Stati linked list
    map.jai              - Map, LocationInfo, LF_* flags
    creature.jai         - Creature, Character, Player, Monster
    item.jai             - Item, Weapon, Armour, Container
    feature.jai          - Feature, Door, Trap, Portal, F_* flags
    vision.jai           - LOS, distance functions (chebyshev, manhattan)
    registry.jai         - Handle-based object registry
    event.jai            - Event system with EventType enum
    resource.jai         - Resource templates (TMonster, TItem, etc.)
    tests.jai            - Test framework and all tests
    resource/
      constants.jai      - 3572 constants from Defines.h (binary search)
      lexer.jai          - Tokenizer with 130+ token types
      parser.jai         - Recursive descent parser
    dungeon/
      map.jai            - GenMap, Terrain enum, room carving
      terrain_registry.jai - Runtime terrain lookup by name
      weights.jai        - Region/weight system for procedural selection
      makelev.jai        - MakeLev room types (original Incursion algorithm)
      generator.jai      - High-level dungeon generation
    terminal/
      window.jai         - Simp-based glyph terminal rendering
  tools/
    inspect.jai          - CLI inspection tool for programmatic testing
    dungeon_test.jai     - Interactive dungeon viewer (windowed)
    dungeon_screenshot.jai - Headless screenshot generator
    terminal_test.jai    - Terminal rendering test
  docs/
    screenshot.png       - Dungeon generation screenshot for README
  fonts/
    8x8.png, 12x16.png, etc. - Bitmap fonts for terminal rendering
```

## Original Incursion Source

**Location**: `C:\Data\R\roguelike - incursion\repo-work\`

### Key Files
| File | Purpose |
|------|---------|
| `inc/Defines.h` | 4700 lines of #define constants |
| `inc/Res.h` | Resource template structures |
| `lib/*.irh` | Resource definition files (monsters, items, spells, etc.) |
| `lang/Tokens.lex` | **Authoritative** lexer spec (FLex format) - Keywords1, Keywords2, AttrWords, ColourWords, DirWords |
| `lang/Grammar.acc` | **Authoritative** parser grammar (ACCENT format) - BNF+ with semantic actions |

### Resource File Format (.irh/.irc)

Resources are defined in a custom DSL. See RECONSTRUCTION-PARSER.md for full details.

```
Monster "goblin": MA_GOBLIN, MA_EVIL {
    Image: green 'g';
    CR: 1;
    HD: 1;
    Size: SZ_SMALL;
    Flags: M_HUMANOID;
}

Race "dwarf" {
    STR +2, CON +2, CHA -2;
    Grants: Feat[FT_DARKVISION] at 1st level;
}
```

## Build & Test

```bash
# Compile
C:/Data/R/jai/bin/jai.exe src/main.jai

# Run tests
./main.exe

# Regenerate constants from Defines.h
py extract_constants.py
```

## Implementation Status

### Completed
- Core types: Dir, Glyph, hObj, rID, Dice
- Object hierarchy: Thing -> Creature/Item/Feature
- Map system with LocationInfo
- Handle-based registry
- Lexer with context-sensitive tokenization
- Parser for: Flavor, Item, Monster, Effect, Feature, Terrain, Race, Class

### Next Steps - MVP (see PLAN-MVP.md)

1. Resource baking (compile-time .irh → runtime tables)
2. Dungeon generator (rooms, corridors, terrain)
3. Population system (monsters, items, features)
4. Terminal renderer (Simp-based glyph display)
5. Inspection interface (Claude-queryable state)

### Key Jai Modules for MVP

| Module | Purpose | Location |
|--------|---------|----------|
| Simp | 2D rendering, fonts, colors | `modules/Simp.md` |
| Window_Creation | Window management | `modules/Window_Creation.md` |
| Input | Keyboard/mouse events | `modules/Input.md` |
| GUI_Test | Screenshot capture, synthetic input | `tools/GUI_Test/` |
| Bucket_Array | Stable-handle storage for Registry | `modules/Bucket_Array.md` |
| Pool | Block allocator with reset | `modules/Pool.md` |
| Bit_Array | Memory-efficient FOV/explored maps | `modules/Bit_Array.md` |
| Hash_Table | Resource lookup by name/ID | `modules/Hash_Table.md` |
| PCG | Deterministic RNG | `modules/PCG.md` |
| Relative_Pointers | Save files that survive mmap | `modules/Relative_Pointers.md` |
| Command_Line | CLI args from struct | `modules/Command_Line.md` |
| Iprof | Profiling plugin | `modules/Iprof.md` |

### Grammar Alignment (Tokens.lex / Grammar.acc)

**Completed (2026-01-27):**
- ✓ Token types: ATTRIBUTE, COLOR, DIRECTION, WEP_TYPE, STYPE, MAPAREA (with values)
- ✓ Keywords1: Type keywords (`void`, `bool`, `int8`, etc.) and special words (`abs`, `true`, `false`, `null`, etc.)
- ✓ Keywords2: ~60 property keywords (`Glyph`, `Value`, `Colour`, `Material`, etc.)
- ✓ Direction words with values (North, South, etc.)
- ✓ Weapon types (slash/slashing, pierce/piercing, blunt) with values
- ✓ Save types (fort, ref, will) with values
- ✓ Missing operators: `%=`, `~=`, `...`
- ✓ `mval` parsing for template attribute modifiers (percentage and min syntax)
- ✓ Fractional CR support (1/2, 1/4, etc.)
- ✓ Effect properties: sval, dval, aval, lval, tval, rval, Base Chance, Purpose
- ✓ Item properties: Lifespan, Fuel, Capacity, WeightLim, WeightMod, MaxSize, Timeout, CType, Fires
- ✓ British spelling "Colour" for flavor resources
- ✓ Map grid syntax `{:...:}` with MAPAREA token (grid_mode in lexer)
- ✓ Full `gear_entry` syntax: `IF (cond)`, `N%` chance, dice quantity, `CURSED`/`BLESSED`, `WITH [qualities]`, `OF effect`, `AT (x,y)`
- ✓ `Artifact` resource type with power system (`Equip FOR`, `Wield FOR`, `Hit FOR`, `Invoke FOR`)
- ✓ Module header: `Module "name";`, `Slot N;`, `File "path";`
- ✓ `abil_level` variations: `every level`, `every N level` (optional starting at)

**Parser is now aligned with Grammar.acc for all major resource types.**

## Key Technical Decisions

### Constants System
- 3572 constants extracted from Defines.h
- Stored as sorted parallel arrays (names, values)
- Binary search lookup: O(log n)
- Values stored as s64 to handle both negative sentinels and large flags

### Lexer Context-Sensitivity
- `brace_level` tracks nesting depth
- Control flow keywords only recognized in code blocks (brace_level >= 2)
- Special handling for dice notation ('d' followed by digit)
- Critical multipliers: x2, x3, x4

### Parser Patterns
- Recursive descent with error recovery
- Expression parsing with precedence (parse_cexpr -> parse_cexpr2 -> parse_cexpr3)
- Grant parsing shared between Race and Class via `*[..] ParsedGrant` parameter
- Generic parse_flags_list works for any flag array

## Known Issues & Fixes

| Issue | Fix |
|-------|-----|
| MALE_NAMES/FEMALE_NAMES/FAMILY_NAMES tokenized as .CONSTANT | Added `is_names_constant()` helper |
| Grant parsing only worked for Race | Changed parameter from `*ParsedRace` to `*[..] ParsedGrant` |
| Ordinal suffixes (1st, 2nd, 3rd, 4th) | Added `skip_ordinal_suffix()` to consume them |

## Git Safety

**CRITICAL**: Files were lost on 2026-01-26 due to `git clean -fd` on uncommitted work.

- **Always commit** before running destructive git commands
- **Never run** `git clean -fd` without checking `git status` first
- Consider using `git stash` instead of clean

## Jai Language Reference

**CONSTRAINT**: No access to official Jai distribution except the compiler executable at `C:/Data/R/jai/bin/jai.exe`. All language documentation comes from the local reverse-engineered reference repo.

**Local Reference Repo**: `C:\Data\R\git\jai\` - Contains reverse-engineered Jai documentation including:
- `jai-language.md` - Core language reference with syntax and semantics
- `modules/*.md` - Module documentation for standard library

### Key Patterns Used in This Project
- `using` for struct composition: `Monster :: struct { using creature: Creature; }`
- `[..]` for dynamic arrays
- `*[..] T` for mutable array pointers
- `#string` for multiline strings (test data)
- `#import "Module"` for module imports
- `#load "file.jai"` for splitting code into files (merges into current scope)
- `temp` / `temporary_allocator` for per-frame scratch allocations (auto-reset)
- `push_allocator(temp)` to use temporary allocator in a scope

### Useful Modules (see `C:\Data\R\git\jai\modules\*.md`)
| Module | Purpose |
|--------|---------|
| Basic | Core utilities: print, arrays, strings, memory |
| String | String manipulation, comparison, parsing |
| Math | Math constants, trig, min/max/clamp |
| File | File I/O operations |
| Hash_Table | Hash map implementation |
| Pool | Arena allocator for efficient memory |

## Code Improvement Opportunities

### Use Standard Library Functions
The codebase defines custom helpers that duplicate standard library functionality:

| Current | Replace With | Module |
|---------|-------------|--------|
| `my_abs()` | `abs()` | Math |
| `my_max()`, `my_min()` | `max()`, `min()` | Basic |
| `clamp()` | `clamp()` | Basic (already exists) |
| `strings_equal()` | `==` or `equal()` | String module |
| `slice()` | `to_string(ptr, count)` | Basic |

### Module Import Redundancy
- `#import "Random"` appears in both `main.jai` and `dice.jai`
- Jai's `#load` merges into the same scope, so imports in `main.jai` are available to loaded files
- Consider removing redundant imports from loaded files

### Global State
- `registry: Registry` is a global variable
- Could be passed as a parameter for better testability and multiple registry support

### Test Framework Enhancement
- Could use `@Test` annotations with compile-time discovery via `#run` metaprogramming
- See Jai's built-in test patterns in the modules

### Memory Management
- Consider using `Pool` allocator for Stati linked list allocations
- Current code uses individual `New()` / `free()` calls which fragment memory

### Potential Type Improvements
- `hObj` and `rID` are both `s32` - could use distinct types to prevent mixing
- Jai supports this via: `hObj :: #type,distinct s32;`
