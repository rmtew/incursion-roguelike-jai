# Scripting Architecture

This folder documents the exploration of how to handle event handlers and resource scripts in the Incursion port.

## Files

| File | Purpose |
|------|---------|
| `context.md` | Background, problem statement, relevant codebase files |
| `options.md` | Comparison of implementation approaches (compile-time vs runtime) |
| `format-approaches.md` | Spectrum of format options (designer-friendly to pure Jai) |
| `syntax-mapping.md` | Translation rules from .irh C-like code to Jai |
| `journal.md` | Decision log and progress tracking |

## Quick Summary

**Problem**: .irh files contain C-like event handler code. How do we execute it?

**Decision**: Use Jai as the scripting language. Either:
- **Option 1**: Transpile .irh → Jai, maintain Jai going forward
- **Option 3**: Transpile .irh → Jai as build step, keep .irh as source

Both avoid inventing a new language. Jai code is type-checked, debuggable, native performance.

**Status**: Architecture documented, awaiting implementation.

## To Resume This Work

1. Read `context.md` for background
2. Read `options.md` for the approaches
3. Read `syntax-mapping.md` for translation rules
4. Check `journal.md` for current status and next steps

## Key Insight

Event handlers become Jai procedures:

```jai
// Generated from .irh
goblin_on_death :: (e: *Event) -> EventResult {
    if has_stati(e.actor, .SUMMONED) return .NOTHING;
    gain_xp(e.actor, 100);
    return .DONE;
}
```

Resources become Jai struct constants:

```jai
goblin :: RMonster.{
    name = "goblin",
    cr = 1,
    on_death = goblin_on_death,
};
```
