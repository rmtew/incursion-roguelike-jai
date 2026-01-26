# Core Module Reconstruction Details

## defines.jai

```jai
VERSION_STRING :: "0.6.9Y19-jai";

// Direction enum
Dir :: enum u8 {
    NORTH; SOUTH; EAST; WEST;
    NORTHEAST; NORTHWEST; SOUTHEAST; SOUTHWEST;
    UP; DOWN; CENTER;
}

DirX :: (d: Dir) -> s8 { ... }  // Returns -1, 0, or 1
DirY :: (d: Dir) -> s8 { ... }

// Glyph - packed character + colors
Glyph :: struct {
    value: u32;  // Packed: char (8) + fg (8) + bg (8) + flags (8)
}

make_glyph :: (char: u8, fg: u8, bg: u8) -> Glyph { ... }
glyph_char :: (g: Glyph) -> u8 { ... }
glyph_fg :: (g: Glyph) -> u8 { ... }
glyph_bg :: (g: Glyph) -> u8 { ... }

// Common type aliases
hObj :: s32;    // Object handle
rID :: s32;     // Resource ID
NULL_OBJ :: -1;
NULL_ID :: -1;

// Size constants
SZ_TINY :: 0; SZ_SMALL :: 1; SZ_MEDIUM :: 2;
SZ_LARGE :: 3; SZ_HUGE :: 4; SZ_GARGANTUAN :: 5;

// Material types
MAT_IRON :: 1; MAT_WOOD :: 2; MAT_LEATHER :: 3;
// ... etc
```

## dice.jai

```jai
Dice :: struct {
    number: s8;
    sides:  s8;
    bonus:  s8;
}

make_dice :: (num: s8, sides: s8, bonus: s8 = 0) -> Dice { ... }
roll :: (d: Dice) -> s32 { ... }
average :: (d: Dice) -> s32 { return d.number * (d.sides + 1) / 2 + d.bonus; }
minimum :: (d: Dice) -> s32 { return d.number + d.bonus; }
maximum :: (d: Dice) -> s32 { return d.number * d.sides + d.bonus; }
to_string :: (d: Dice) -> string { ... }  // "2d6+3"
parse_dice :: (s: string) -> Dice, bool { ... }
```

## object.jai

```jai
// Status effect
Stati :: struct {
    type:   s16;
    val:    s16;
    mag:    s16;
    source: hObj;
    eID:    rID;
    duration: s32;
    next:   *Stati;
}

// Base object
Object :: struct {
    myHandle: hObj;
    type:     u8;
    // ... other base fields
}

// Thing - anything that can exist on the map
Thing :: struct {
    using base: Object;
    x, y:       s16;
    image:      Glyph;
    stati:      *Stati;  // Linked list of status effects
    m:          *void;   // Map pointer (*void due to circular dep)
    // ... other fields
}

thing_has_stati :: (t: *Thing, type: s16) -> bool { ... }
thing_get_stati :: (t: *Thing, type: s16) -> *Stati { ... }
thing_add_stati :: (t: *Thing, type: s16, val: s16, mag: s16) { ... }
thing_remove_stati :: (t: *Thing, type: s16) { ... }
```

## map.jai

```jai
LocationInfo :: struct {
    terrain:    rID;
    feature:    hObj;
    contents:   [..] hObj;
    flags:      u32;
}

Map :: struct {
    width, height: s32;
    cells:         [] LocationInfo;
    depth:         s32;
    // ... other fields
}

map_init :: (m: *Map, w: s32, h: s32) { ... }
map_free :: (m: *Map) { ... }
map_in_bounds :: (m: *Map, x: s32, y: s32) -> bool { ... }
map_at :: (m: *Map, x: s32, y: s32) -> *LocationInfo { ... }
map_is_solid :: (m: *Map, x: s32, y: s32) -> bool { ... }
map_is_opaque :: (m: *Map, x: s32, y: s32) -> bool { ... }
```

## creature.jai

```jai
Creature :: struct {
    using thing: Thing;
    hp, max_hp:  s16;
    mana, max_mana: s16;
    attrs:       [7] s8;  // STR, DEX, CON, INT, WIS, CHA, LUC
    // ... other fields
}

A_STR :: 0; A_DEX :: 1; A_CON :: 2;
A_INT :: 3; A_WIS :: 4; A_CHA :: 5; A_LUC :: 6;

creature_get_attr :: (c: *Creature, attr: s32) -> s8 { ... }

Character :: struct {
    using creature: Creature;
    level:      s16;
    xp:         s32;
    gender:     u8;  // 0=male, 1=female
    // ... other fields
}

Player :: struct {
    using character: Character;
    // player-specific fields
}

Monster :: struct {
    using creature: Creature;
    template:   rID;
    // monster-specific fields
}

get_pronoun :: (c: *Character) -> string {
    if c.gender == 1 return "she";
    return "he";
}
```

## item.jai

```jai
Item :: struct {
    using thing: Thing;
    itype:      u8;
    plus:       s8;
    material:   u8;
    known:      u8;
    qualities:  u32;  // Bit flags for qualities
    // ... other fields
}

item_is_masterwork :: (i: *Item) -> bool { return i.plus >= 1; }
item_is_magic :: (i: *Item) -> bool { return i.plus >= 2; }
item_has_quality :: (i: *Item, q: u32) -> bool { return (i.qualities & (1 << q)) != 0; }

Weapon :: struct {
    using item: Item;
    damage:     Dice;
    threat:     s8;
    crit:       s8;
    // ... weapon fields
}

Armour :: struct {
    using item: Item;
    ac:         s8;
    penalty:    s8;
    coverage:   u8;
    // ... armor fields
}

Container :: struct {
    using item: Item;
    contents:   [..] hObj;
    capacity:   s32;
}

// Material properties
material_is_metallic :: (mat: u8) -> bool { ... }
material_is_organic :: (mat: u8) -> bool { ... }
material_hardness :: (mat: u8) -> s8 { ... }
```

## feature.jai

```jai
Feature :: struct {
    using thing: Thing;
    ftype:      u8;
    flags:      u32;
}

F_SOLID :: 0x0001;
F_OPAQUE :: 0x0002;
F_LOCKED :: 0x0004;
F_OPEN :: 0x0008;
F_HIDDEN :: 0x0010;
F_DISARMED :: 0x0020;
F_TRIGGERED :: 0x0040;

Door :: struct {
    using feature: Feature;
    key_id:     rID;
}

door_init :: (d: *Door) { d.flags = F_SOLID | F_OPAQUE; }
door_is_open :: (d: *Door) -> bool { return (d.flags & F_OPEN) != 0; }
door_is_locked :: (d: *Door) -> bool { return (d.flags & F_LOCKED) != 0; }
door_open :: (d: *Door) { d.flags |= F_OPEN; d.flags &= ~F_SOLID; }
door_close :: (d: *Door) { d.flags &= ~F_OPEN; d.flags |= F_SOLID; }
door_lock :: (d: *Door) { d.flags |= F_LOCKED; }
door_unlock :: (d: *Door) { d.flags &= ~F_LOCKED; }

Trap :: struct {
    using feature: Feature;
    dc:         s8;
    damage:     Dice;
}

trap_is_hidden :: (t: *Trap) -> bool { return (t.flags & F_HIDDEN) != 0; }
trap_is_disarmed :: (t: *Trap) -> bool { return (t.flags & F_DISARMED) != 0; }
trap_reveal :: (t: *Trap) { t.flags &= ~F_HIDDEN; }
trap_disarm :: (t: *Trap) { t.flags |= F_DISARMED; }
trap_trigger :: (t: *Trap) -> bool {
    if t.flags & F_DISARMED return false;
    t.flags |= F_TRIGGERED;
    return true;
}

Portal :: struct {
    using feature: Feature;
    dest_map:   rID;
    dest_x, dest_y: s16;
    portal_type: u8;  // POR_UP_STAIR, POR_DOWN_STAIR, etc.
}

portal_is_stairs :: (p: *Portal) -> bool { ... }
portal_is_down :: (p: *Portal) -> bool { ... }
portal_is_up :: (p: *Portal) -> bool { ... }
```

## registry.jai

```jai
Registry :: struct {
    objects:    [..] *Thing;
    free_slots: [..] s32;
    next_handle: hObj;
}

registry: Registry;

registry_register :: (t: *Thing) -> hObj { ... }
registry_get :: (h: hObj) -> *Thing { ... }
registry_remove :: (h: hObj) { ... }
```

## vision.jai

```jai
// Line of sight using Bresenham-like algorithm
has_los :: (m: *Map, x1: s32, y1: s32, x2: s32, y2: s32) -> bool { ... }

// Distance functions
chebyshev_distance :: (x1: s32, y1: s32, x2: s32, y2: s32) -> s32 {
    dx := abs(x2 - x1);
    dy := abs(y2 - y1);
    return max(dx, dy);
}

euclidean_dist_squared :: (x1: s32, y1: s32, x2: s32, y2: s32) -> s32 {
    dx := x2 - x1;
    dy := y2 - y1;
    return dx*dx + dy*dy;
}
```

## event.jai

```jai
EventType :: enum u16 {
    EV_NONE;
    EV_HIT;
    EV_DAMAGE;
    EV_DEATH;
    // ... many more
}

Event :: struct {
    etype:      EventType;
    actor:      hObj;
    target:     hObj;
    victim:     hObj;
    item:       hObj;
    damage:     s32;
    is_hit:     bool;
    // ... other fields
}

event_clear :: (e: *Event) { ... }
```

## resource.jai (Template structures)

```jai
TMonster :: struct {
    name:       string;
    image:      Glyph;
    size:       u8;
    cr:         s8;
    hd:         s8;
    flags:      u64;
    // ... many more fields
}

TItem :: struct {
    name:       string;
    image:      Glyph;
    level:      s8;
    damage:     Dice;
    // ... many more fields
}

// Resource ID manipulation
rID_module :: (id: rID) -> s32 { return (id >> 16) & 0xFFFF; }
rID_index :: (id: rID) -> s32 { return id & 0xFFFF; }
make_rID :: (module: s32, index: s32) -> rID { return (module << 16) | index; }
```

## Key Patterns

### Using for Composition
```jai
Monster :: struct {
    using creature: Creature;  // Inherit all fields
    template: rID;
}
```

### Function Pointers (for virtual methods)
```jai
ThingVTable :: struct {
    describe: (*Thing) -> string;
    // ... other virtual functions
}
```

### Error Handling
- Functions return `value, bool` for fallible operations
- `ok` pattern: `result, ok := some_function(); if !ok return ...;`

### Test Pattern
```jai
test_foo :: () {
    test_section("Foo Tests");

    // Test case
    {
        // setup
        result := some_function();
        test_assert(result > 0, "result is positive");
        test_assert_eq(result, 42, "result is 42");
    }
}
```
