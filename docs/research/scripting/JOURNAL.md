# Scripting Architecture Journal

## 2026-01-28: Initial Exploration

### Context
With the .irh parser now working for all test files, we discussed next steps. The conversation evolved from "resource baking" to a deeper architectural question: how should scripts/event handlers be represented in the port?

### Key Insights

1. **Original Incursion compiled scripts into modules** that could be loaded and debugged. This suggests a runtime-loadable module system, not just compile-time baking.

2. **Save file compatibility** - If resources can change between versions, save files need to bundle or reference their compatible module version.

3. **Conversion pipeline** - We want to use original .irh scripts for correctness verification, but potentially convert them to a cleaner format not tied to the legacy C++ engine.

4. **No new scripting language** - User preference to avoid inventing and maintaining a custom language parser. Jai itself should be the "scripting language."

### Options Identified

See `options.md` for detailed comparison of:
- **Option 1**: Jai as the source of truth (resources + handlers as Jai code)
- **Option 3**: Transpiler (one-time conversion from .irh to Jai)

Both avoid inventing a new language. The difference is whether .irh remains the source or becomes a bootstrap.

### Technical Work Done

- Reviewed Jai language specification for correct syntax
- Documented syntax mapping from .irh C-like code to Jai (see `syntax-mapping.md`)
- Confirmed procedure types work for event handler storage in structs

### Open Questions

1. What is the full API surface event handlers need? (EActor, EItem, e.*, etc.)
2. How complex are the most complex event handlers?
3. Should module loading be mmap-based for save file bundling?
4. Runtime vs compile-time resource lookup for `$"name"` references?

### Designer-Friendly Syntax Discussion

Important consideration raised: the original .irh syntax uses D&D conventions like `1d8` for dice that are immediately meaningful to game designers. Pure Jai conversion loses this:

- `1d8` → `roll(.{1, 8})` or `d(1,8)` - less intuitive

Documented five format approaches in `format-approaches.md`:
- **A**: Adapted .irh with Jai event blocks
- ~~**B**: Split files (data in DSL, events in Jai)~~ - Ruled out (unnecessary complexity)
- ~~**C**: Full Jai with helper functions like `d(1,8)`~~ - Ruled out (loses D&D syntax)
- **D**: Jai with embedded DSL strings parsed at compile-time
- **E**: One-time transpile to pure Jai

**Remaining options: A, D, E**

Key question: who edits resources? If designers, preserve D&D syntax for data (A or D). If only programmers, pure Jai is simpler (E).

### Format Discussion Continued

Explored concrete examples of remaining approaches:

**Approach D**: Jai files with `#string` blocks containing D&D syntax data, parsed at compile-time via `#run`. Handlers as separate Jai procedures combined with `make_monster()`.

**Approach A**: Adapted .irh with Jai event blocks. Two variants:
- Marked blocks: `On Event EV_DEATH #jai { ... }`
- Inline replacement: Just use Jai syntax directly in event blocks, no marker

**Inline Jai variant** (simplest adaptation):
```
On Event EV_DEATH {
    if has_stati(e.actor, .SUMMONED) return .NOTHING;
    gain_xp(e.actor, 100);
    return .DONE;
}
```

This keeps the .irh structure intact, just swaps C++ event syntax for Jai. Mechanical translation:
- `EActor->Method()` → `e.actor.method()` or `method(e.actor)`
- `CONSTANT` → `.CONSTANT`
- Remove `if ()` parens
- `->` → `.` (auto-deref)

### Next Steps (when resumed)

1. **Explore C++ to Jai translation further** - What other C++-isms exist in event handlers? Can we make the syntax even cleaner?
2. Survey actual event handler code in .irh files to catalog patterns
3. Define the Event struct and EventResult enum
4. Prototype one complete monster with handler
5. Decide on final format approach
6. Build the transpiler for event handler conversion
