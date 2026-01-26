// Incursion Port - Object System
// Reconstructed from RECONSTRUCTION-CORE.md

// Status effect
Stati :: struct {
    type:     s16;
    val:      s16;
    mag:      s16;
    source:   hObj;
    eID:      rID;
    duration: s32;
    next:     *Stati;
}

// Base object
Object :: struct {
    myHandle: hObj;
    type:     u8;
}

// Thing - anything that can exist on the map
Thing :: struct {
    using base: Object;
    x, y:    s16;
    image:   Glyph;
    stati:   *Stati;  // Linked list of status effects
    m:       *void;   // Map pointer (*void due to circular dep)
    name:    string;
    flags:   u32;
}

thing_init :: (t: *Thing) {
    t.myHandle = NULL_OBJ;
    t.type = 0;
    t.x = 0;
    t.y = 0;
    t.image = .{};
    t.stati = null;
    t.m = null;
}

thing_has_stati :: (t: *Thing, type: s16) -> bool {
    s := t.stati;
    while s != null {
        if s.type == type return true;
        s = s.next;
    }
    return false;
}

thing_get_stati :: (t: *Thing, type: s16) -> *Stati {
    s := t.stati;
    while s != null {
        if s.type == type return s;
        s = s.next;
    }
    return null;
}

thing_add_stati :: (t: *Thing, type: s16, val: s16, mag: s16) {
    s := New(Stati);
    s.type = type;
    s.val = val;
    s.mag = mag;
    s.source = NULL_OBJ;
    s.eID = NULL_ID;
    s.duration = -1;  // Permanent
    s.next = t.stati;
    t.stati = s;
}

thing_remove_stati :: (t: *Thing, type: s16) {
    prev: *Stati = null;
    s := t.stati;
    while s != null {
        if s.type == type {
            if prev == null {
                t.stati = s.next;
            } else {
                prev.next = s.next;
            }
            free(s);
            return;
        }
        prev = s;
        s = s.next;
    }
}

thing_free_stati :: (t: *Thing) {
    s := t.stati;
    while s != null {
        next := s.next;
        free(s);
        s = next;
    }
    t.stati = null;
}
