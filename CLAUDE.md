# Incursion Port - Claude Code Project Guide

## Directives for Future Sessions

1. **Document discoveries** - Add learnings about the Incursion codebase to this file
2. **Link to detail files** - For extensive details, create separate files (e.g., RECONSTRUCTION*.md) and link from here
3. **Keep this file scannable** - Use headers and bullet points; move large content to linked files

## Environment

- **Shell**: Git Bash on Windows (cmd/terminal)
- **Python**: Use `py` command (not `python`)
- **Jai Compiler**: `C:/Data/R/jai/bin/jai.exe`

## Project Structure

```
incursion-port/
  CLAUDE.md              - This file (project guide)
  RECONSTRUCTION.md      - Master reconstruction guide with struct definitions
  RECONSTRUCTION-CORE.md - Core module details (defines, dice, object, etc.)
  RECONSTRUCTION-LEXER.md - Lexer implementation details
  RECONSTRUCTION-PARSER.md - Parser implementation details
  extract_constants.py   - Script to extract constants from Defines.h
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
```

## Original Incursion Source

**Location**: `C:\Data\R\roguelike - incursion\repo-work\`

### Key Files
| File | Purpose |
|------|---------|
| `inc/Defines.h` | 4700 lines of #define constants |
| `inc/Res.h` | Resource template structures |
| `lib/*.irh` | Resource definition files (monsters, items, spells, etc.) |
| `modaccent/Grammar.acc` | Original parser grammar |

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

### Next Steps
- God/Domain parsing
- Event handler translation (currently skipped)
- Resource file loading and linking
- Game loop integration

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

## Jai Language Notes

See `/jai-language.md` in parent directory for full reference.

Key patterns used in this project:
- `using` for struct composition: `Monster :: struct { using creature: Creature; }`
- `[..]` for dynamic arrays
- `*[..] T` for mutable array pointers
- `#string` for multiline strings (test data)
- `#import "Module"` for module imports
