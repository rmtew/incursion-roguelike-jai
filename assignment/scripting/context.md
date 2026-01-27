# Scripting Architecture Context

## Problem Statement

The Incursion port needs to handle game logic defined in `.irh` resource files. These files contain:
1. **Resource data** - monster stats, item properties, terrain definitions
2. **Event handlers** - C-like code that runs when game events occur

The parser (now complete) extracts the data. The question is: what do we do with the event handler code?

## Original Incursion Architecture

From studying the original C++ codebase:

- `.irh` files are compiled into binary modules at runtime
- Modules can be loaded/unloaded dynamically
- Event handler code is interpreted or JIT'd
- Debugger can step through script code
- Modules are versioned for save file compatibility

Location: `C:\Data\R\roguelike - incursion\repo-work\`

Key files:
- `lib/*.irh` - Resource definition files
- `lang/Grammar.acc` - Parser grammar
- `lang/Tokens.lex` - Lexer specification
- `inc/Res.h` - Resource structures

## Current Parser State

The parser successfully handles all test `.irh` files:

| File | Resources |
|------|-----------|
| flavors.irh | 883 |
| mundane.irh | 73 |
| domains.irh | 44 |
| weapons.irh | 118 |
| enclist.irh | 87 |
| dungeon.irh | 184 |

**Event handlers are currently skipped** - `skip_event_handler()` in parser.jai consumes the code block without parsing it.

## Relevant Codebase Files

### Parser
- `src/resource/parser.jai` - Main parser, `skip_event_handler()` function
- `src/resource/lexer.jai` - Tokenizer
- `src/resource/constants.jai` - 3572 constants from Defines.h

### Parsed Structures
In `src/resource/parser.jai`:
- `ParsedMonster`
- `ParsedItem`
- `ParsedEffect`
- `ParsedTerrain`
- `ParsedFeature`
- `ParsedRegion`
- etc.

### Documentation
- `CLAUDE.md` - Project guide
- `PLAN-MVP.md` - MVP roadmap
- `journal.md` - Development journal
- `backlog.md` - Task tracking
- `RECONSTRUCTION-PARSER.md` - Parser implementation details

## Jai Language Reference

Location: `C:\Data\R\git\jai\jai-language.md`

Key features for this work:
- Procedure types: `#type (args) -> ReturnType`
- Struct literals: `Type.{ field = value }`
- Compile-time execution: `#run`
- Code generation: `#insert`
- No custom character literals - use `#char "x"`

## Constraints

1. **No new scripting language** - Don't want to maintain a custom parser
2. **Correctness verification** - Need to compare behavior against original
3. **Save file compatibility** - Resources may need versioning
4. **Designer accessibility** - Format should be editable

## Design Goals

1. Use Jai as the "scripting language" (Option 1 or 3)
2. Transpile .irh event handlers to Jai procedures
3. Resources become Jai struct constants
4. Everything compiles together - type-checked, debuggable
5. Consider runtime module loading later for mods/saves

## Related Decisions

### mmap Save Files
Discussed using Jai's `Relative_Pointers` module for save files that survive mmap. If resources change between versions, saves need to bundle or reference their module version.

### Module Bundling
Original Incursion bundled compiled modules with saves. We may want similar:
- Save file references specific resource module version
- Or save includes the module data
- Ensures save can load correctly even if game resources change

## Next Actions

See `journal.md` for current status and next steps.
