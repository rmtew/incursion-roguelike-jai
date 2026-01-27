# Resource Format Approaches

This document explores the spectrum of format options, from preserving designer-friendly .irh syntax to full Jai conversion.

## Design Priorities

1. **Designer accessibility** - D&D designers should recognize the format (dice notation, familiar terms)
2. **No custom runtime interpreter** - Event logic compiles to native code
3. **Correctness verifiable** - Can compare behavior against original Incursion
4. **Maintainable** - Don't invent complex parsing we have to maintain

---

## Approach A: Adapted .irh with Jai Event Blocks

Keep the .irh data format (designer-friendly), but event handlers are Jai code blocks.

### Example
```
Monster "goblin" : MA_GOBLIN, MA_EVIL {
    Image: green 'g';
    CR: 1;
    HD: 1d8;
    Size: SZ_SMALL;
    Flags: M_HUMANOID;

    On Event EV_DEATH #jai {
        if has_stati(e.actor, .SUMMONED) return .NOTHING;
        gain_xp(e.actor, 100);
        return .DONE;
    }
}
```

### Conversion Pipeline
```
Original .irh → [Event Transpiler] → Adapted .irh (Jai events) → [Compiler] → Binary
                                            ↑
                                    Designer edits here
```

### Pros
- Data remains in familiar D&D format (`1d8`, `CR: 1`)
- Designers can edit resource stats without knowing Jai
- Event code is real Jai - type-checked, debuggable
- One-time conversion of event handlers

### Cons
- Two syntaxes in one file (data DSL + Jai)
- Still need parser for data portion
- Hybrid might be confusing

### Parser Changes Needed
- Keep existing data parser
- Event blocks marked with `#jai` pass through to Jai compiler
- Or: extract Jai blocks during build, generate combined .jai file

---

## ~~Approach B: .irh Data + Separate Jai Handlers~~ (Ruled Out)

Split resources across files - adds complexity without clear benefit.

---

## ~~Approach C: Full Jai with Designer Helpers~~ (Ruled Out)

Loses too much of the D&D-friendly syntax. `d(1,8)` is not `1d8`.

---

## Approach D: Jai with Embedded DSL Strings

Use Jai's `#string` for data blocks, parsed at compile time.

### Example
```jai
goblin_data :: #string END
Monster "goblin" : MA_GOBLIN, MA_EVIL {
    Image: green 'g';
    CR: 1;
    HD: 1d8;
    Size: SZ_SMALL;
    Flags: M_HUMANOID;
}
END

goblin :: #run parse_monster(goblin_data, goblin_events);

goblin_events :: EventHandlers.{
    on_death = goblin_on_death,
};

goblin_on_death :: (e: *Event) -> EventResult {
    if has_stati(e.actor, .SUMMONED) return .NOTHING;
    gain_xp(e.actor, 100);
    return .DONE;
}
```

### Pros
- Data in familiar format (inside string)
- Parsed at compile time
- Events are real Jai
- All in one .jai file

### Cons
- String content not syntax highlighted
- Errors in DSL harder to locate
- Still maintaining a parser (runs at compile time)

---

## Approach E: Transpile Once, Maintain Jai

One-time conversion from .irh to .jai. The Jai files become the source of truth.

### Pipeline
```
Original .irh → [One-Time Transpiler] → .jai files → maintain forever
```

### Example Output
```jai
// AUTO-GENERATED then hand-maintained
// Original: lib/monsters.irh, line 245

goblin :: RMonster.{
    name = "goblin",
    flags = MA_GOBLIN | MA_EVIL,
    image = .{ color = .GREEN, char = #char "g" },
    cr = 1,
    hd = .{ count = 1, sides = 8 },
    size = .SZ_SMALL,
    monster_flags = .M_HUMANOID,

    on_death = (e: *Event) -> EventResult {
        if has_stati(e.actor, .SUMMONED) return .NOTHING;
        gain_xp(e.actor, 100);
        return .DONE;
    },
};
```

### Pros
- Simplest long-term: just Jai
- No parser to maintain after conversion
- Full IDE support

### Cons
- Loses D&D-friendly syntax
- Can't easily diff against original
- Designers must learn Jai

---

## Comparison Matrix

| Approach | Designer Friendly | Single Language | No Parser Maintenance | Debuggable Events |
|----------|------------------|-----------------|----------------------|-------------------|
| **A: Adapted .irh + Jai events** | ✓ Data | ✗ | ✗ | ✓ |
| ~~B: Split data/events~~ | — | — | — | — |
| ~~C: Full Jai + helpers~~ | — | — | — | — |
| **D: Jai + DSL strings** | ✓ Data | ✓ | ✗ | ✓ |
| **E: One-time transpile** | ✗ | ✓ | ✓ | ✓ |

---

## Remaining Options

### Approach A: Adapted .irh + Jai Events
- Keep D&D-native syntax for data (`1d8`, `CR: 1`)
- Event handlers become Jai code blocks within the .irh-like format
- Existing parser handles data, events extracted for Jai compilation
- Best if: designers actively edit resources, want familiar format

**Variant A1: Marked blocks**
```
On Event EV_DEATH #jai {
    if has_stati(e.actor, .SUMMONED) return .NOTHING;
    ...
}
```

**Variant A2: Inline Jai (preferred)** - Just replace C++ with Jai, no marker:
```
On Event EV_DEATH {
    if has_stati(e.actor, .SUMMONED) return .NOTHING;
    gain_xp(e.actor, 100);
    return .DONE;
}
```

Same structure as original .irh, mechanical syntax swap. Parser already knows event blocks contain code.

### Approach D: Jai + Embedded DSL Strings
- Data in familiar format inside `#string` blocks
- Parsed at compile time by existing parser (run via `#run`)
- Events are normal Jai procedures
- Best if: want single .jai files but preserve D&D syntax for data

### Approach E: One-Time Transpile to Jai
- Convert everything to pure Jai once
- Maintain .jai files going forward
- Simplest long-term (no parser maintenance)
- Best if: only programmers edit resources, want simplicity

---

## Open Questions

1. Who will edit resources? Programmers only, or also game designers?
2. How often do resources change? Rarely (Approach E ok) or frequently (A better)?
3. Should original .irh remain as reference/test oracle?

## Future Exploration: Cleaning Up C++-isms

The inline Jai approach (A2) does mechanical translation, but there may be opportunities to make the event syntax even cleaner. Areas to explore:

- **Implicit `e` parameter** - Could the event context be implicit?
- **Method syntax** - `e.actor.has_stati(.X)` vs `has_stati(e.actor, .X)` vs something else?
- **Return values** - `.NOTHING`, `.DONE`, `.ABORT` - could these be cleaner?
- **Resource references** - `$"goblin"` syntax - keep, change, or compile-time lookup?
- **String formatting** - `IPrint` with format args - Jai's `print` style?
- **Common patterns** - Are there recurring idioms that could be simplified?

Need to survey actual event handler code to catalog what patterns exist before deciding.
