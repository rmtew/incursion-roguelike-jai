# Visibility/Memory System Specification

How Incursion tracks what the player can see and remembers.

## Data Structures

### LocationInfo Fields (from `inc/Map.h` lines 25-49)

```c
struct LocationInfo {
    uint32 Glyph;          // Terrain's base glyph + color
    unsigned int Visibility :16;  // Per-player visibility flags
    uint32 Memory;         // What player remembers seeing (Glyph value)
    // ... other fields
};
```

### Visibility Flags (from `inc/Map.h` lines 53-56)

| Flag | Value | Meaning |
|------|-------|---------|
| `VI_VISIBLE` | 1 | Currently in player's FOV |
| `VI_DEFINED` | 2 | Has been seen at least once |
| `VI_EXTERIOR` | 4 | Exterior/outdoor cell |
| `VI_TORCHED` | 8 | Lit by mobile light source |

**Note:** Flags are shifted by `player_number * 4` for multiplayer support. For single player, just use bits 0-3.

## Rendering Decision Logic

**Source:** `src/Term.cpp` lines 838-846 (`Map::Update`)

```c
if (!((At(x, y).Visibility & VI_VISIBLE) || Vis)) {
    // Cell is not visible AND no creature perceived
    g = (Glyph)At(x, y).Memory;
    if (g)
        PutGlyph(x, y, g);      // Show remembered terrain
    else
        PutGlyph(x, y, GLYPH_UNSEEN);  // Never seen = blank
} else {
    // Cell is visible - show current contents
    // (handled by priority system)
}
```

### Display Rules

| Condition | Display |
|-----------|---------|
| `VI_VISIBLE` set | Current contents (terrain/items/creatures) |
| `VI_DEFINED` set, `VI_VISIBLE` clear | Memory glyph |
| Neither set | `GLYPH_UNSEEN` (space character) |

## Memory Assignment

**Source:** `src/Vision.cpp` line 62 (`MarkAsSeen`)

When a cell becomes visible:
```c
Here.Visibility |= (VI_VISIBLE | VI_DEFINED);
Here.Memory = Here.Glyph;  // Store terrain's current appearance
```

### What Gets Stored in Memory

1. **Terrain glyph** - always stored when cell becomes visible
2. **Feature glyphs** - features (doors, traps, chests, fountains) update Memory
3. **NOT creatures** - monsters/player positions are not remembered
4. **NOT items** - loose items on ground are not remembered (except chests)

**Source:** `src/Vision.cpp` lines 359-368

```c
// Features and special items update memory
if (t->isFeature() || (t->isItem() && t->isType(T_CHEST)))
    if (At(t->x,t->y).Memory != 0)
        At(t->x,t->y).Memory = (Memory & GLYPH_BACK_MASK) |
                               (t->Image & ~GLYPH_BACK_MASK);
```

## FOV Calculation

**Source:** `src/Vision.cpp` lines 256-370 (`CalcVision`, `VisionThing`)

### Algorithm Overview

1. **Clear visibility flags** in viewport area
2. **Cast rays** from player to edges of visible area
3. **Mark cells as seen** along each ray until blocked

### Ray Casting

```c
// For each edge cell of viewport, cast ray from player
for (cx = x1; cx <= x2; cx++) {
    VisionPath(player, sx, sy, cx, y1);  // Top edge
    VisionPath(player, sx, sy, cx, y2);  // Bottom edge
}
for (cy = y1; cy <= y2; cy++) {
    VisionPath(player, sx, sy, x1, cy);  // Left edge
    VisionPath(player, sx, sy, x2, cy);  // Right edge
}
```

### Vision Blocking

A cell blocks vision if:
- `Opaque` flag is set (from terrain)
- Magical darkness (`Dark` flag)
- Obscuring terrain (fog, etc.)

### Vision Range Checks

| Range Type | Purpose | Typical Value |
|------------|---------|---------------|
| `SightRange` | Maximum vision distance | 15 |
| `LightRange` | Torch/light radius | 4 |
| `ShadowRange` | Dim light perception | 8 |
| `BlindRange` | Blindsight (sees without light) | varies |

**Visibility determination:**
```c
if (dist > SightRange)
    return;  // Beyond maximum range
if (dist > LightRange && !cell.Lit)
    Mask = VI_DEFINED;  // Seen but shadowy
else
    Mask = VI_VISIBLE | VI_DEFINED;  // Fully visible
```

## Implementation Plan for Jai Port

### Phase 1: Data Structures

Add to `GenMap` or create new `VisibilityMap`:
```jai
VisibilityInfo :: struct {
    visibility: u8;    // VI_* flags
    memory: u32;       // Remembered glyph (terrain + color)
}

// In GenMap:
visibility: [MAP_WIDTH * MAP_HEIGHT] VisibilityInfo;
```

### Phase 2: Memory Assignment

When a cell is marked visible:
```jai
mark_cell_visible :: (m: *GenMap, x: s32, y: s32) {
    idx := y * m.width + x;
    m.visibility[idx].visibility |= VI_VISIBLE | VI_DEFINED;

    // Store terrain glyph in memory
    glyph, fg, bg := get_terrain_render(m, x, y);
    m.visibility[idx].memory = make_glyph(glyph, fg, bg);
}
```

### Phase 3: Rendering Integration

Update `get_cell_render()` to check visibility:
```jai
get_cell_render :: (m: *GenMap, x: s32, y: s32, player_x: s32, player_y: s32) -> u16, u8, u8 {
    vis := m.visibility[y * m.width + x];

    if !(vis.visibility & VI_VISIBLE) {
        // Not currently visible
        if vis.memory != 0 {
            // Show remembered terrain
            return glyph_id(vis.memory), glyph_fg(vis.memory), glyph_bg(vis.memory);
        } else {
            // Never seen
            return GLYPH_UNSEEN, 0, 0;
        }
    }

    // Currently visible - use normal priority rendering
    // ... existing logic ...
}
```

### Phase 4: FOV Algorithm

Implement shadowcasting or ray-based FOV:
```jai
calculate_fov :: (m: *GenMap, player_x: s32, player_y: s32, sight_range: s32) {
    // Clear VI_VISIBLE for viewport
    clear_visible_flags(m);

    // Mark player's cell
    mark_cell_visible(m, player_x, player_y);

    // Cast rays to edges
    for edge cells {
        cast_vision_ray(m, player_x, player_y, edge_x, edge_y, sight_range);
    }
}
```

## Verification Checklist

- [ ] Unseen cells display as `GLYPH_UNSEEN` (space)
- [ ] Visible cells show current contents
- [ ] Previously-seen cells show Memory glyph when out of FOV
- [ ] Memory stores terrain, not creatures
- [ ] Features (doors, chests) update Memory
- [ ] Opaque terrain blocks vision
- [ ] Vision range limits work correctly

## Key Source Files

| File | Lines | Content |
|------|-------|---------|
| `inc/Map.h` | 25-56 | LocationInfo struct, VI_* flags |
| `src/Vision.cpp` | 34-122 | MarkAsSeen function |
| `src/Vision.cpp` | 256-370 | CalcVision, VisionThing |
| `src/Term.cpp` | 701-868 | Map::Update rendering logic |
