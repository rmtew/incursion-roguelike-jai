# Scripting Architecture Options

## Background

Original Incursion uses `.irh` resource files with embedded C-like event handler code:

```c
Monster "goblin" : MA_GOBLIN, MA_EVIL {
    Image: green 'g';
    CR: 1;
    HD: 1d8;

    On Event EV_DEATH {
        if (EActor->HasStati(SUMMONED))
            return NOTHING;
        GainXP(EActor, 100);
        return DONE;
    };
}
```

The question: how do we represent this in the Jai port?

---

## Option 1: Jai as Source of Truth

### Concept
Convert .irh files to Jai source files. Resources become struct constants, event handlers become Jai procedures. Jai IS the scripting language.

### Example Output
```jai
goblin_on_death :: (e: *Event) -> EventResult {
    if has_stati(e.actor, .SUMMONED) return .NOTHING;
    gain_xp(e.actor, 100);
    return .DONE;
}

goblin :: RMonster.{
    name = "goblin",
    glyph = .{ char = #char "g", color = .GREEN },
    cr = 1,
    hd = .{ count = 1, sides = 8 },
    on_death = goblin_on_death,
};
```

### Pros
- Native performance (no interpreter)
- Full debugger support
- Type-checked at compile time
- Jai metaprogramming available
- No language to maintain

### Cons
- Requires recompile for any resource change
- Designers need to write Jai (or use conversion tool)
- Harder to support runtime mods

### Workflow
```
Original .irh → [Transpiler] → .jai files → maintain Jai going forward
```

---

## Option 3: Transpiler (Build Step)

### Concept
Keep .irh as source, transpile to Jai as a build step. Similar to Option 1 but .irh remains authoritative.

### Workflow
```
.irh files (source) → [Transpiler] → generated .jai → compile with game
```

### Pros
- Original files remain source of truth
- Easier to verify correctness against original
- Can diff generated output to catch translation bugs
- Designers edit familiar .irh format

### Cons
- Two representations to keep in sync
- Generated code may be less readable
- Still requires recompile for changes

---

## Option 2: Runtime Module Loading (Deferred)

### Concept
Compile resources to a binary module format that can be mmap'd at runtime. Enables:
- Save files bundling their module version
- Runtime modding without recompile
- Hot reloading during development

### Would Require
- Binary serialization format for resources
- Runtime interpreter or JIT for event handlers (unless pre-compiled)
- Module versioning system

### Status
Deferred for later consideration. More complex, but may be needed for:
- Mod support
- Save file compatibility across versions
- Development iteration speed

---

## Recommendation

**Start with Option 1 or 3** (they're similar):

1. Build the transpiler (.irh → Jai)
2. Generate Jai code from original resources
3. Verify correctness by comparing game behavior
4. Decide later whether to maintain .irh or .jai as source

This gets us working code fastest. Runtime module loading can be added later if needed for mods or save compatibility.

---

## Key Implementation Pieces

### 1. Event Handler Transpiler
Converts C-like code to Jai. See `syntax-mapping.md`.

### 2. Runtime API
Functions event handlers can call:
- `has_stati(creature, stati) -> bool`
- `gain_xp(creature, amount)`
- `roll(dice) -> int`
- `res_id(name) -> rID`
- etc.

### 3. Resource Structs
Lean runtime structs (not ParsedX versions):
- `RMonster`
- `RItem`
- `RTerrain`
- `RFeature`
- `REffect`

### 4. Resource Registry
Lookup by ID or name:
```jai
monsters: [] RMonster;  // or [N] RMonster for fixed size
get_monster :: (id: rID) -> *RMonster;
find_monster :: (name: string) -> *RMonster;
```
