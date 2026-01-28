# Syntax Mapping: .irh to Jai

This document defines how to translate Incursion's C-like event handler code to valid Jai.

## Jai Language Reference

Source: `C:\Data\R\git\jai\jai-language.md`

Key syntax differences from C:
- Characters: `#char "g"` not `'g'`
- Pointers auto-dereference for member access: `p.field` not `p->field`
- Switch: `if x == { case 1; ... }` not `switch(x) { case 1: ... }`
- Enum values: `.ENUMVAL` shorthand when type is known
- No parentheses required around `if` conditions
- Procedure types: `Callback :: #type (args) -> ReturnType;`

---

## Literal Translations

| .irh | Jai | Notes |
|------|-----|-------|
| `'g'` | `#char "g"` | Character literals |
| `"string"` | `"string"` | Same |
| `123` | `123` | Same |
| `0xFF` | `0xFF` | Same |
| `true` / `false` | `true` / `false` | Same |
| `null` / `NULL` | `null` | Jai uses lowercase |
| `CONSTANT` | `.CONSTANT` or `CONSTANT` | Depends on context |

---

## Operators

| .irh | Jai | Notes |
|------|-----|-------|
| `+`, `-`, `*`, `/`, `%` | Same | Arithmetic |
| `==`, `!=`, `<`, `>`, `<=`, `>=` | Same | Comparison |
| `&&`, `\|\|`, `!` | Same | Logical |
| `&`, `\|`, `^`, `~` | Same | Bitwise |
| `<<`, `>>` | Same | Shift |
| `=` | `=` | Assignment |
| `+=`, `-=`, etc. | Same | Compound assignment |
| `++x`, `x++` | `x += 1` | Jai has no increment operator |
| `--x`, `x--` | `x -= 1` | Jai has no decrement operator |
| `(type)x` | `cast(type) x` | Explicit cast |

---

## Control Flow

### If Statements

```c
// .irh
if (condition) {
    body;
}
```

```jai
// Jai
if condition {
    body;
}
```

### If-Else

```c
// .irh
if (condition) {
    body1;
} else {
    body2;
}
```

```jai
// Jai
if condition {
    body1;
} else {
    body2;
}
```

### Switch/Case

```c
// .irh
switch (value) {
    case 1:
        do_something();
        break;
    case 2:
        do_other();
        break;
    default:
        do_default();
}
```

```jai
// Jai
if value == {
    case 1;
        do_something();
    case 2;
        do_other();
    case;
        do_default();
}
```

Note: Jai cases don't fall through by default. Use `#through` if needed.

### For Loops

```c
// .irh
for (i = 0; i < 10; i++) {
    body;
}
```

```jai
// Jai
for i: 0..9 {  // inclusive range
    body;
}
```

### While Loops

```c
// .irh
while (condition) {
    body;
}
```

```jai
// Jai
while condition {
    body;
}
```

---

## Pointer/Member Access

```c
// .irh - explicit arrow for pointer member access
EActor->HasStati(SUMMONED)
EActor->x
ptr->field
```

```jai
// Jai - auto-dereference, always use dot
e.actor.has_stati(.SUMMONED)
e.actor.x
ptr.field
```

---

## Event Handler Globals

The .irh event handlers use implicit globals. These map to Event struct fields:

| .irh Global | Jai Equivalent | Type |
|-------------|----------------|------|
| `EActor` | `e.actor` | `*Creature` |
| `EVictim` | `e.victim` | `*Creature` |
| `ETarget` | `e.target` | `*Thing` |
| `EItem` | `e.item` | `*Item` |
| `EItem2` | `e.item2` | `*Item` |
| `EMap` | `e.map` | `*Map` |
| `e` | `e` | `*Event` (the parameter) |
| `e.vDmg` | `e.damage` | `s32` |
| `e.vHit` | `e.hit_bonus` | `s32` |
| `e.DType` | `e.damage_type` | `DamageType` |
| `e.AType` | `e.attack_type` | `AttackType` |

---

## Return Values

```c
// .irh
return NOTHING;
return DONE;
return ABORT;
```

```jai
// Jai
return .NOTHING;
return .DONE;
return .ABORT;
```

EventResult enum:
```jai
EventResult :: enum {
    NOTHING;
    DONE;
    ABORT;
    // ... others as needed
}
```

---

## Resource References

```c
// .irh - runtime resource lookup
$"goblin"
$"short sword"
```

```jai
// Jai - compile-time or runtime lookup
res_id("goblin")      // returns rID
find_monster("goblin") // returns *RMonster
```

---

## Dice Notation

```c
// .irh
1d6
2d8+4
e.vDmg = 3d6;
```

```jai
// Jai - struct literal or helper
roll(.{1, 6})
roll(.{2, 8, 4})
e.damage = roll(.{3, 6});

// Or with named fields
roll(Dice.{count=1, sides=6})
```

---

## Method Calls

Common method translations:

| .irh | Jai |
|------|-----|
| `EActor->HasStati(X)` | `has_stati(e.actor, .X)` |
| `EActor->HasFeat(X)` | `has_feat(e.actor, .X)` |
| `EActor->HasAbility(X)` | `has_ability(e.actor, .X)` |
| `EActor->GainPermStati(...)` | `gain_perm_stati(e.actor, ...)` |
| `EActor->IPrint("msg")` | `iprint(e.actor, "msg")` |
| `EActor->IDPrint(...)` | `idprint(e.actor, ...)` |
| `EActor->isAerial()` | `is_aerial(e.actor)` |
| `EActor->isDead()` | `is_dead(e.actor)` |
| `EActor->ResistLevel(X)` | `resist_level(e.actor, .X)` |
| `EMap->WriteTerra(x,y,t)` | `write_terrain(e.map, x, y, t)` |
| `EMap->SolidAt(x,y)` | `solid_at(e.map, x, y)` |
| `EMap->InBounds(x,y)` | `in_bounds(e.map, x, y)` |

---

## Variable Declarations

```c
// .irh
int16 x, y;
hObj target;
rID effect_id;
```

```jai
// Jai
x, y: s16;
target: hObj;
effect_id: rID;
```

---

## Complete Example

### Original .irh
```c
On Event EV_HIT {
    int16 bonus;
    if (EActor->HasFeat(FT_POWER_ATTACK)) {
        bonus = 2;
        if (EActor->HasFeat(FT_GREATER_POWER_ATTACK))
            bonus = 4;
        e.vDmg += bonus;
    }
    return NOTHING;
}
```

### Translated Jai
```jai
example_on_hit :: (e: *Event) -> EventResult {
    bonus: s16;
    if has_feat(e.actor, .FT_POWER_ATTACK) {
        bonus = 2;
        if has_feat(e.actor, .FT_GREATER_POWER_ATTACK)
            bonus = 4;
        e.damage += bonus;
    }
    return .NOTHING;
}
```

---

## Unmapped / Complex Cases

These need special handling or investigation:

1. **Preprocessor macros** - `WATER_COMBAT` style macro invocations
2. **Complex switches** with fall-through
3. **Goto statements** (if any exist)
4. **Inline type casts** in expressions
5. **String formatting** in IPrint calls
6. **Object creation** - `CreateFeature()`, `CreateItem()`
7. **Event throwing** - `ThrowTerraDmg()`, `ThrowEvent()`

---

## Runtime API Surface (To Define)

The transpiled handlers call into these functions. Full API needs to be defined:

```jai
// Creature queries
has_stati :: (c: *Creature, stati: Stati) -> bool;
has_feat :: (c: *Creature, feat: Feat) -> bool;
has_ability :: (c: *Creature, ability: Ability) -> bool;
resist_level :: (c: *Creature, dtype: DamageType) -> s32;
is_aerial :: (c: *Creature) -> bool;
is_dead :: (c: *Creature) -> bool;

// Creature actions
gain_xp :: (c: *Creature, amount: s32);
gain_perm_stati :: (c: *Creature, stati: Stati, ...);
iprint :: (c: *Creature, msg: string, args: ..Any);

// Map operations
write_terrain :: (m: *Map, x: s32, y: s32, terrain: rID);
solid_at :: (m: *Map, x: s32, y: s32) -> bool;
in_bounds :: (m: *Map, x: s32, y: s32) -> bool;

// Dice
roll :: (d: Dice) -> s32;

// Resources
res_id :: (name: string) -> rID;
```
