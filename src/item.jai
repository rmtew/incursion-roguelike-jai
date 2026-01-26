// Incursion Port - Item System
// Reconstructed from RECONSTRUCTION-CORE.md

Item :: struct {
    using thing: Thing;
    itype:      u8;
    plus:       s8;
    material:   u8;
    known:      u8;
    qualities:  u32;  // Bit flags for qualities
    quantity:   s16;
    weight:     s16;
    cost:       s32;
}

item_init :: (i: *Item) {
    thing_init(*i.thing);
    i.itype = 0;
    i.plus = 0;
    i.material = 0;
    i.known = 0;
    i.qualities = 0;
    i.quantity = 1;
    i.weight = 0;
    i.cost = 0;
}

item_is_masterwork :: (i: *Item) -> bool {
    return i.plus >= 1;
}

item_is_magic :: (i: *Item) -> bool {
    return i.plus >= 2;
}

item_has_quality :: (i: *Item, q: u32) -> bool {
    mask := cast(u32) 1 << q;
    return (i.qualities & mask) != 0;
}

item_add_quality :: (i: *Item, q: u32) {
    mask := cast(u32) 1 << q;
    i.qualities |= mask;
}

item_remove_quality :: (i: *Item, q: u32) {
    mask := cast(u32) 1 << q;
    i.qualities &= ~mask;
}

// Weapon
Weapon :: struct {
    using item: Item;
    damage:  Dice;
    threat:  s8;
    crit:    s8;
    range:   s8;
    speed:   s8;
}

weapon_init :: (w: *Weapon) {
    item_init(*w.item);
    w.damage = make_dice(1, 6);
    w.threat = 20;
    w.crit = 2;
    w.range = 0;
    w.speed = 0;
}

// Armour
Armour :: struct {
    using item: Item;
    ac:       s8;
    penalty:  s8;
    coverage: u8;
    max_dex:  s8;
}

armour_init :: (a: *Armour) {
    item_init(*a.item);
    a.ac = 0;
    a.penalty = 0;
    a.coverage = 0;
    a.max_dex = 127;
}

// Container
Container :: struct {
    using item: Item;
    contents: [..] hObj;
    capacity: s32;
}

container_init :: (c: *Container) {
    item_init(*c.item);
    c.capacity = 100;
}

container_is_full :: (c: *Container) -> bool {
    return c.contents.count >= c.capacity;
}

container_add :: (c: *Container, obj: hObj) -> bool {
    if container_is_full(c) return false;
    array_add(*c.contents, obj);
    return true;
}

container_remove :: (c: *Container, obj: hObj) -> bool {
    for i: 0..c.contents.count-1 {
        if c.contents[i] == obj {
            array_ordered_remove_by_index(*c.contents, i);
            return true;
        }
    }
    return false;
}

// Material properties
material_is_metallic :: (mat: u8) -> bool {
    return mat == MAT_IRON || mat == MAT_GOLD || mat == MAT_SILVER || mat == MAT_COPPER;
}

material_is_organic :: (mat: u8) -> bool {
    return mat == MAT_WOOD || mat == MAT_LEATHER || mat == MAT_BONE || mat == MAT_CLOTH;
}

material_hardness :: (mat: u8) -> s8 {
    if mat == MAT_IRON   return 10;
    if mat == MAT_STONE  return 8;
    if mat == MAT_WOOD   return 5;
    if mat == MAT_BONE   return 6;
    if mat == MAT_GOLD   return 3;
    if mat == MAT_SILVER return 3;
    if mat == MAT_GLASS  return 1;
    return 5;
}
