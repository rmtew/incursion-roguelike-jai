// Incursion Port - Handle-based Object Registry
// Reconstructed from RECONSTRUCTION-CORE.md

Registry :: struct {
    objects:     [..] *Thing;
    free_slots:  [..] s32;
    next_handle: hObj;
}

registry: Registry;

registry_init :: () {
    registry.objects.count = 0;
    registry.free_slots.count = 0;
    registry.next_handle = 1;
}

registry_register :: (t: *Thing) -> hObj {
    handle: hObj;

    if registry.free_slots.count > 0 {
        // Reuse a free slot
        index := registry.free_slots[registry.free_slots.count - 1];
        registry.free_slots.count -= 1;
        registry.objects[index] = t;
        handle = cast(hObj) index;
    } else {
        // Add new slot
        handle = cast(hObj) registry.objects.count;
        array_add(*registry.objects, t);
    }

    t.myHandle = handle;
    return handle;
}

registry_get :: (h: hObj) -> *Thing {
    if h < 0 || h >= cast(hObj) registry.objects.count {
        return null;
    }
    return registry.objects[h];
}

registry_remove :: (h: hObj) {
    if h < 0 || h >= cast(hObj) registry.objects.count {
        return;
    }

    registry.objects[h] = null;
    array_add(*registry.free_slots, cast(s32) h);
}

registry_clear :: () {
    array_reset(*registry.objects);
    array_reset(*registry.free_slots);
    registry.next_handle = 1;
}
