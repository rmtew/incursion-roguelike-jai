// Incursion Port - Map System
// Reconstructed from RECONSTRUCTION-CORE.md

LocationInfo :: struct {
    terrain:  rID;
    feature:  hObj;
    contents: [..] hObj;
    flags:    u32;
}

Map :: struct {
    width, height: s32;
    cells:         [] LocationInfo;
    depth:         s32;
    name:          string;
}

// Location flags
LF_VISITED  :: 0x0001;
LF_MAPPED   :: 0x0002;
LF_LIT      :: 0x0004;
LF_IN_VIEW  :: 0x0008;
LF_BLOCKED  :: 0x0010;

map_init :: (m: *Map, w: s32, h: s32) {
    m.width = w;
    m.height = h;
    m.cells = NewArray(w * h, LocationInfo);
    for i: 0..m.cells.count-1 {
        m.cells[i].terrain = NULL_ID;
        m.cells[i].feature = NULL_OBJ;
        m.cells[i].flags = 0;
    }
    m.depth = 0;
}

map_free :: (m: *Map) {
    for *cell: m.cells {
        array_free(cell.contents);
    }
    array_free(m.cells);
    m.width = 0;
    m.height = 0;
}

map_in_bounds :: (m: *Map, x: s32, y: s32) -> bool {
    return x >= 0 && x < m.width && y >= 0 && y < m.height;
}

map_at :: (m: *Map, x: s32, y: s32) -> *LocationInfo {
    if !map_in_bounds(m, x, y) return null;
    return *m.cells[y * m.width + x];
}

map_is_solid :: (m: *Map, x: s32, y: s32) -> bool {
    loc := map_at(m, x, y);
    if loc == null return true;
    return (loc.flags & LF_BLOCKED) != 0;
}

map_is_opaque :: (m: *Map, x: s32, y: s32) -> bool {
    // For now, just check if solid
    return map_is_solid(m, x, y);
}

map_set_terrain :: (m: *Map, x: s32, y: s32, terrain: rID) {
    loc := map_at(m, x, y);
    if loc != null {
        loc.terrain = terrain;
    }
}

map_add_thing :: (m: *Map, x: s32, y: s32, obj: hObj) {
    loc := map_at(m, x, y);
    if loc != null {
        array_add(*loc.contents, obj);
    }
}

map_remove_thing :: (m: *Map, x: s32, y: s32, obj: hObj) {
    loc := map_at(m, x, y);
    if loc != null {
        for i: 0..loc.contents.count-1 {
            if loc.contents[i] == obj {
                array_ordered_remove_by_index(*loc.contents, i);
                return;
            }
        }
    }
}
