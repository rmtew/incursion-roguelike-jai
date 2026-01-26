// Incursion Port - Event System
// Reconstructed from RECONSTRUCTION-CORE.md

EventType :: enum u16 {
    EV_NONE   :: 0;
    EV_HIT    :: 1;
    EV_DAMAGE :: 2;
    EV_DEATH  :: 3;
    EV_MOVE   :: 4;
    EV_PICKUP :: 5;
    EV_DROP   :: 6;
    EV_WIELD  :: 7;
    EV_REMOVE :: 8;
    EV_OPEN   :: 9;
    EV_CLOSE  :: 10;
    EV_LOCK   :: 11;
    EV_UNLOCK :: 12;
    EV_CAST   :: 13;
    EV_EFFECT :: 14;
    EV_ATTACK :: 15;
    EV_DEFEND :: 16;
}

Event :: struct {
    etype:   EventType;
    actor:   hObj;
    target:  hObj;
    victim:  hObj;
    item:    hObj;
    damage:  s32;
    is_hit:  bool;
    blocked: bool;
    eID:     rID;
    xval:    s32;
    yval:    s32;
}

event_init :: (e: *Event) {
    e.etype = .EV_NONE;
    e.actor = NULL_OBJ;
    e.target = NULL_OBJ;
    e.victim = NULL_OBJ;
    e.item = NULL_OBJ;
    e.damage = 0;
    e.is_hit = false;
    e.blocked = false;
    e.eID = NULL_ID;
    e.xval = 0;
    e.yval = 0;
}

event_clear :: (e: *Event) {
    event_init(e);
}

// Make an attack event
make_attack_event :: (actor: hObj, target: hObj) -> Event {
    e: Event;
    event_init(*e);
    e.etype = .EV_ATTACK;
    e.actor = actor;
    e.target = target;
    return e;
}

// Make a damage event
make_damage_event :: (actor: hObj, victim: hObj, damage: s32) -> Event {
    e: Event;
    event_init(*e);
    e.etype = .EV_DAMAGE;
    e.actor = actor;
    e.victim = victim;
    e.damage = damage;
    return e;
}

// Make a move event
make_move_event :: (actor: hObj, x: s32, y: s32) -> Event {
    e: Event;
    event_init(*e);
    e.etype = .EV_MOVE;
    e.actor = actor;
    e.xval = x;
    e.yval = y;
    return e;
}
