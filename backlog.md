# Backlog

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
