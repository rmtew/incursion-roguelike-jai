// Rendering Priority System
//
// Priority: Creatures > Items > Terrain
// Multiple creatures at same cell: GLYPH_MULTI (Æ, CP437 146)
// Multiple items at same cell: GLYPH_PILE (*, CP437 42)
//
// This module provides functions to determine what should be rendered
// at each map cell, handling entity stacking and priority.

// ============================================================================
// Entity Counting
// ============================================================================

// Count monsters at position (returns 0, 1, or actual count)
count_monsters_at :: (m: *GenMap, x: s32, y: s32) -> s32 {
    count: s32 = 0;
    for mon: m.monsters {
        if mon.x == x && mon.y == y {
            count += 1;
        }
    }
    return count;
}

// Count items at position (returns 0, 1, or actual count)
count_items_at :: (m: *GenMap, x: s32, y: s32) -> s32 {
    count: s32 = 0;
    for item: m.items {
        if item.x == x && item.y == y {
            count += 1;
        }
    }
    return count;
}

// ============================================================================
// Entity Access
// ============================================================================

// Get first monster at position (or null if none)
first_monster_at :: (m: *GenMap, x: s32, y: s32) -> *EntityPos {
    for *mon: m.monsters {
        if mon.x == x && mon.y == y {
            return mon;
        }
    }
    return null;
}

// Get first item at position (or null if none)
first_item_at :: (m: *GenMap, x: s32, y: s32) -> *EntityPos {
    for *item: m.items {
        if item.x == x && item.y == y {
            return item;
        }
    }
    return null;
}

// Count features at position
count_features_at :: (m: *GenMap, x: s32, y: s32) -> s32 {
    count: s32 = 0;
    for feat: m.features {
        if feat.x == x && feat.y == y {
            count += 1;
        }
    }
    return count;
}

// Get first feature at position (or null if none)
first_feature_at :: (m: *GenMap, x: s32, y: s32) -> *EntityPos {
    for *feat: m.features {
        if feat.x == x && feat.y == y {
            return feat;
        }
    }
    return null;
}

// ============================================================================
// Terrain Colors
// ============================================================================

// Get foreground color for terrain (ANSI index 0-15)
get_terrain_fg_color :: (t: Terrain) -> u8 {
    if t == {
        case .ROCK;         return 0;   // BLACK
        case .WALL;         return 7;   // GREY
        case .FLOOR;        return 6;   // BROWN
        case .CORRIDOR;     return 6;   // BROWN
        case .DOOR_CLOSED;  return 14;  // YELLOW
        case .DOOR_OPEN;    return 6;   // BROWN
        case .DOOR_SECRET;  return 7;   // GREY
        case .STAIRS_UP;    return 15;  // WHITE
        case .STAIRS_DOWN;  return 15;  // WHITE
        case .WATER;        return 9;   // BRIGHT_BLUE (shallow)
        case .DEEP_WATER;   return 1;   // BLUE (deep - darker)
        case .CHASM;        return 0;   // BLACK
        case .LAVA;         return 12;  // BRIGHT_RED (shallow)
        case .DEEP_LAVA;    return 4;   // RED (deep - darker)
        case .TRAP;         return 12;  // BRIGHT_RED
        case .TRAP_HIDDEN;  return 6;   // BROWN
        case .PILLAR;       return 7;   // GREY
        case .RUBBLE;       return 6;   // BROWN
    }
    return 15;  // WHITE
}

// Get background color for terrain (ANSI index 0-15)
get_terrain_bg_color :: (t: Terrain) -> u8 {
    if t == {
        case .WATER;       return 1;   // BLUE
        case .DEEP_WATER;  return 1;   // BLUE
        case .CHASM;       return 0;   // BLACK (dark)
        case .LAVA;        return 4;   // RED
        case .DEEP_LAVA;   return 4;   // RED
    }
    return 0;  // BLACK (default)
}

// ============================================================================
// Main Render Function
// ============================================================================

// Get what should be rendered at a cell
// Returns: glyph (u16), fg_color (u8), bg_color (u8)
//
// Priority: Creatures > Items > Terrain
// Multiple creatures: GLYPH_MULTI (Æ)
// Multiple items: GLYPH_PILE (*)
//
// If use_visibility is true, applies visibility filtering:
// - Not visible and not defined: show blank space
// - Defined but not visible: show remembered terrain (dimmed)
// - Visible: show full contents
get_cell_render :: (m: *GenMap, x: s32, y: s32, use_visibility: bool = false) -> u16, u8, u8 {
    // Check visibility first if enabled
    if use_visibility {
        vis := get_visibility(m, x, y);
        if vis == null {
            // Out of bounds - show blank
            return GLYPH_UNSEEN, 0, 0;
        }

        // Not visible
        if !(vis.flags & VI_VISIBLE) {
            if vis.flags & VI_DEFINED {
                // Previously seen - show memory (dimmed)
                return vis.memory_glyph, dim_color(vis.memory_fg), 0;
            } else {
                // Never seen - blank
                return GLYPH_UNSEEN, 0, 0;
            }
        }
        // Cell is visible - continue to full render below
    }

    terrain := map_get(m, x, y);

    // Start with terrain defaults
    glyph := terrain_glyph(terrain);
    fg_color := get_terrain_fg_color(terrain);
    bg_color := get_terrain_bg_color(terrain);

    // Check for custom tile display (from region terrain)
    td := map_get_display(m, x, y);
    if td != null && td.use_custom {
        glyph = td.glyph;
        fg_color = cast(u8) td.fg_color;
    }

    // Check for skylight (tile below chasm on level above - cyan tint, always lit)
    if td != null && td.is_skylight {
        fg_color = 11;  // BRIGHT_CYAN
    }

    // Check for features (higher priority than terrain, lower than items)
    feat := first_feature_at(m, x, y);
    if feat != null && feat.glyph != 0 {
        glyph = feat.glyph;
        fg_color = feat.fg_color;
    }

    // Check for items (lower priority than creatures)
    item_count := count_items_at(m, x, y);
    if item_count > 0 {
        if item_count > 1 {
            // Multiple items: show pile glyph
            glyph = GLYPH_PILE;
            fg_color = 14;  // YELLOW
        } else {
            // Single item: use its glyph/color
            item := first_item_at(m, x, y);
            if item != null {
                if item.glyph != 0 {
                    glyph = item.glyph;
                    fg_color = item.fg_color;
                } else {
                    // Fallback if glyph not set
                    glyph = #char "*";
                    fg_color = 14;  // YELLOW
                }
            }
        }
    }

    // Check for creatures (highest priority)
    mon_count := count_monsters_at(m, x, y);
    if mon_count > 0 {
        if mon_count > 1 {
            // Multiple creatures: show multi glyph
            glyph = GLYPH_MULTI;
            fg_color = 12;  // BRIGHT_RED
        } else {
            // Single creature: use its glyph/color
            mon := first_monster_at(m, x, y);
            if mon != null {
                if mon.glyph != 0 {
                    glyph = mon.glyph;
                    fg_color = mon.fg_color;
                } else {
                    // Fallback if glyph not set
                    glyph = #char "M";
                    fg_color = 12;  // BRIGHT_RED
                }
            }
        }
    }

    return glyph, fg_color, bg_color;
}

// ============================================================================
// Color Dimming for Memory Display
// ============================================================================

// Dim a color for displaying remembered (but not currently visible) cells
// Converts bright colors to their dim equivalents
dim_color :: (color: u8) -> u8 {
    if color == {
        // Bright colors -> dim equivalents
        case 9;  return 1;   // BRIGHT_BLUE -> BLUE
        case 10; return 2;   // BRIGHT_GREEN -> GREEN
        case 11; return 3;   // BRIGHT_CYAN -> CYAN
        case 12; return 4;   // BRIGHT_RED -> RED
        case 13; return 5;   // BRIGHT_MAGENTA -> MAGENTA
        case 14; return 6;   // YELLOW -> BROWN
        case 15; return 7;   // WHITE -> GREY

        // Normal colors -> darker versions (shadow/dark grey)
        case 1;  return 8;   // BLUE -> DARK_GREY
        case 2;  return 8;   // GREEN -> DARK_GREY
        case 3;  return 8;   // CYAN -> DARK_GREY
        case 4;  return 8;   // RED -> DARK_GREY
        case 5;  return 8;   // MAGENTA -> DARK_GREY
        case 6;  return 8;   // BROWN -> DARK_GREY
        case 7;  return 8;   // GREY -> DARK_GREY
    }
    // BLACK and DARK_GREY stay as is
    return color;
}

// ============================================================================
// ANSI Color to RGB Conversion
// ============================================================================

// Convert ANSI color index (0-15) to RGB values (0.0-1.0)
// This matches the standard 16-color ANSI palette
// Returns: r, g, b as float32
ansi_to_rgb :: (ansi: u8) -> float32, float32, float32 {
    if ansi == {
        case 0;  return 0.0, 0.0, 0.0;          // BLACK
        case 1;  return 0.0, 0.0, 0.67;         // BLUE
        case 2;  return 0.0, 0.67, 0.0;         // GREEN
        case 3;  return 0.0, 0.67, 0.67;        // CYAN
        case 4;  return 0.67, 0.0, 0.0;         // RED
        case 5;  return 0.67, 0.0, 0.67;        // MAGENTA
        case 6;  return 0.67, 0.33, 0.0;        // BROWN
        case 7;  return 0.67, 0.67, 0.67;       // GREY
        case 8;  return 0.33, 0.33, 0.33;       // DARK_GREY
        case 9;  return 0.33, 0.33, 1.0;        // BRIGHT_BLUE
        case 10; return 0.33, 1.0, 0.33;        // BRIGHT_GREEN
        case 11; return 0.33, 1.0, 1.0;         // BRIGHT_CYAN
        case 12; return 1.0, 0.33, 0.33;        // BRIGHT_RED
        case 13; return 1.0, 0.33, 1.0;         // BRIGHT_MAGENTA
        case 14; return 1.0, 1.0, 0.33;         // YELLOW
        case 15; return 1.0, 1.0, 1.0;          // WHITE
    }
    return 1.0, 1.0, 1.0;  // Default white
}
