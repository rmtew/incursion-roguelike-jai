// Incursion Port - Handle-based Object Registry
// Reconstructed from RECONSTRUCTION-CORE.md

Registry :: struct {
    objects:     [..] *Thing;
    free_slots:  [..] s32;
    next_handle: hObj;
}

// Global registry instance (convenient for game use)
// For testing, create a local Registry and use the *_with functions
global_registry: Registry;

// Initialize a registry
registry_init_with :: (reg: *Registry) {
    reg.objects.count = 0;
    reg.free_slots.count = 0;
    reg.next_handle = cast,no_check(hObj) 1;
}

// Register an object with a specific registry
registry_register_with :: (reg: *Registry, t: *Thing) -> hObj {
    handle: hObj;

    if reg.free_slots.count > 0 {
        // Reuse a free slot
        index := reg.free_slots[reg.free_slots.count - 1];
        reg.free_slots.count -= 1;
        reg.objects[index] = t;
        handle = cast,no_check(hObj) index;
    } else {
        // Add new slot
        handle = cast,no_check(hObj) reg.objects.count;
        array_add(*reg.objects, t);
    }

    t.myHandle = handle;
    return handle;
}

// Get an object from a specific registry
registry_get_with :: (reg: *Registry, h: hObj) -> *Thing {
    raw := cast,no_check(s32) h;
    if raw < 0 || raw >= cast(s32) reg.objects.count {
        return null;
    }
    return reg.objects[raw];
}

// Remove an object from a specific registry
registry_remove_with :: (reg: *Registry, h: hObj) {
    raw := cast,no_check(s32) h;
    if raw < 0 || raw >= cast(s32) reg.objects.count {
        return;
    }

    reg.objects[raw] = null;
    array_add(*reg.free_slots, raw);
}

// Clear a specific registry
registry_clear_with :: (reg: *Registry) {
    array_reset(*reg.objects);
    array_reset(*reg.free_slots);
    reg.next_handle = cast,no_check(hObj) 1;
}

// === Convenience wrappers using global registry ===

registry_init :: () {
    registry_init_with(*global_registry);
}

registry_register :: (t: *Thing) -> hObj {
    return registry_register_with(*global_registry, t);
}

registry_get :: (h: hObj) -> *Thing {
    return registry_get_with(*global_registry, h);
}

registry_remove :: (h: hObj) {
    registry_remove_with(*global_registry, h);
}

registry_clear :: () {
    registry_clear_with(*global_registry);
}
