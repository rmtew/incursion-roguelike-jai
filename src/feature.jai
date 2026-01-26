// Incursion Port - Feature System
// Reconstructed from RECONSTRUCTION-CORE.md

Feature :: struct {
    using thing: Thing;
    ftype: u8;
    fflags: u32;
}

// Feature flags
F_SOLID     : u32 : 0x0001;
F_OPAQUE    : u32 : 0x0002;
F_LOCKED    : u32 : 0x0004;
F_OPEN      : u32 : 0x0008;
F_HIDDEN    : u32 : 0x0010;
F_DISARMED  : u32 : 0x0020;
F_TRIGGERED : u32 : 0x0040;

feature_init :: (f: *Feature) {
    thing_init(*f.thing);
    f.ftype = 0;
    f.fflags = 0;
}

feature_is_solid :: (f: *Feature) -> bool {
    return (f.fflags & F_SOLID) != 0;
}

feature_is_opaque :: (f: *Feature) -> bool {
    return (f.fflags & F_OPAQUE) != 0;
}

// Door
Door :: struct {
    using feature: Feature;
    key_id: rID;
}

door_init :: (d: *Door) {
    feature_init(*d.feature);
    d.fflags = F_SOLID | F_OPAQUE;
    d.key_id = NULL_ID;
}

door_is_open :: (d: *Door) -> bool {
    return (d.fflags & F_OPEN) != 0;
}

door_is_locked :: (d: *Door) -> bool {
    return (d.fflags & F_LOCKED) != 0;
}

door_open :: (d: *Door) {
    d.fflags |= F_OPEN;
    d.fflags &= ~(F_SOLID | F_OPAQUE);
}

door_close :: (d: *Door) {
    d.fflags &= ~F_OPEN;
    d.fflags |= F_SOLID | F_OPAQUE;
}

door_lock :: (d: *Door) {
    d.fflags |= F_LOCKED;
}

door_unlock :: (d: *Door) {
    d.fflags &= ~F_LOCKED;
}

// Trap
Trap :: struct {
    using feature: Feature;
    dc:     s8;
    damage: Dice;
}

trap_init :: (t: *Trap) {
    feature_init(*t.feature);
    t.fflags = F_HIDDEN;
    t.dc = 15;
    t.damage = make_dice(2, 6);
}

trap_is_hidden :: (t: *Trap) -> bool {
    return (t.fflags & F_HIDDEN) != 0;
}

trap_is_disarmed :: (t: *Trap) -> bool {
    return (t.fflags & F_DISARMED) != 0;
}

trap_reveal :: (t: *Trap) {
    t.fflags &= ~F_HIDDEN;
}

trap_disarm :: (t: *Trap) {
    t.fflags |= F_DISARMED;
}

trap_trigger :: (t: *Trap) -> bool {
    if (t.fflags & F_DISARMED) != 0 return false;
    t.fflags |= F_TRIGGERED;
    return true;
}

// Portal
Portal :: struct {
    using feature: Feature;
    dest_map:       rID;
    dest_x, dest_y: s16;
    portal_type:    u8;
}

// Portal types
POR_UP_STAIR   :: 1;
POR_DOWN_STAIR :: 2;
POR_GATE       :: 3;
POR_TELEPORT   :: 4;

portal_init :: (p: *Portal) {
    feature_init(*p.feature);
    p.dest_map = NULL_ID;
    p.dest_x = 0;
    p.dest_y = 0;
    p.portal_type = 0;
}

portal_is_stairs :: (p: *Portal) -> bool {
    return p.portal_type == POR_UP_STAIR || p.portal_type == POR_DOWN_STAIR;
}

portal_is_down :: (p: *Portal) -> bool {
    return p.portal_type == POR_DOWN_STAIR;
}

portal_is_up :: (p: *Portal) -> bool {
    return p.portal_type == POR_UP_STAIR;
}
