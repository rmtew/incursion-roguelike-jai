// Runtime Resource Structs
//
// Lean versions of Parsed* structs for runtime use.
// These are populated at compile-time by bake.jai.

// ============================================================================
// Runtime Monster
// ============================================================================

RMonster :: struct {
    name: string;
    glyph: u16;         // Character code or GLYPH_* constant (256+)
    fg_color: u8;       // ANSI color index (0-15)
    cr: s16;            // Challenge Rating
    hd: s16;            // Hit Dice
    size: u8;           // SZ_* constant
    speed: u8;          // Movement speed

    // Ability scores
    str_val, dex_val, con_val: s8;
    int_val, wis_val, cha_val: s8;

    // Combat stats
    ac: s16;            // Armor Class
    hit_bonus: s16;     // Attack bonus

    // Flags packed into u64 for common checks
    flags: u64;

    // Monster types (MA_GOBLIN, MA_UNDEAD, etc.) as bitmask
    mtypes: u64;
}

// ============================================================================
// Runtime Item
// ============================================================================

RItem :: struct {
    name: string;
    glyph: u16;         // Character code or GLYPH_* constant (256+)
    fg_color: u8;
    itype: u16;         // T_WEAPON, T_ARMOR, etc.
    material: u16;
    weight: u16;        // In 1/10 lbs
    cost: u32;          // In copper pieces
    level: u8;          // Item level for generation
    size: u8;           // SZ_* constant

    // Weapon properties (if applicable)
    dmg_small: u16;     // Packed dice: (count << 8) | sides
    dmg_large: u16;
    crit_range: u8;     // Threat range (e.g., 19-20 = 2)
    crit_mult: u8;      // Critical multiplier (e.g., x2 = 2)

    // Armor properties (if applicable)
    armor_bonus: s8;
    max_dex: s8;
    armor_penalty: s8;

    flags: u32;
}

// ============================================================================
// Runtime Terrain (matches existing RuntimeTerrain in terrain_registry.jai)
// ============================================================================

// Note: RuntimeTerrain is defined in terrain_registry.jai
// We keep it there to avoid circular dependencies

// ============================================================================
// Runtime Region (matches existing RuntimeRegion in weights.jai)
// ============================================================================

// Note: RuntimeRegion is defined in weights.jai
// We keep it there to avoid circular dependencies

// ============================================================================
// Runtime Encounter
// ============================================================================

REncounter :: struct {
    name: string;
    weight: u16;        // Selection weight
    cr_min: s16;        // Minimum CR for this encounter
    cr_max: s16;        // Maximum CR (-1 = no max)
    terrain: u16;       // Terrain type restriction (0 = any)
    align: u8;          // Alignment restriction
    flags: u32;
}

// ============================================================================
// Resource Database
// ============================================================================

ResourceDB :: struct {
    // Core resources
    monsters: [] RMonster;
    items: [] RItem;
    terrains: [] RuntimeTerrain;
    regions: [] RuntimeRegion;
    encounters: [] REncounter;

    // Lookup tables (name -> index)
    // These would be hash tables, but for compile-time we use sorted arrays
    monster_names: [] string;
    item_names: [] string;
    terrain_names: [] string;
}

// ============================================================================
// Lookup Functions
// ============================================================================

// Binary search for monster by name
find_monster :: (db: *ResourceDB, name: string) -> *RMonster {
    // Binary search in sorted monster_names
    lo := 0;
    hi := db.monster_names.count - 1;

    while lo <= hi {
        mid := (lo + hi) / 2;
        cmp := cmp_str_for_search(db.monster_names[mid], name);
        if cmp == 0 {
            return *db.monsters[mid];
        } else if cmp < 0 {
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return null;
}

// Binary search for item by name
find_item :: (db: *ResourceDB, name: string) -> *RItem {
    lo := 0;
    hi := db.item_names.count - 1;

    while lo <= hi {
        mid := (lo + hi) / 2;
        cmp := cmp_str_for_search(db.item_names[mid], name);
        if cmp == 0 {
            return *db.items[mid];
        } else if cmp < 0 {
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return null;
}

// Simple string comparison for binary search
cmp_str_for_search :: (a: string, b: string) -> s32 {
    min_len := min(a.count, b.count);
    for i: 0..min_len-1 {
        if a[i] < b[i] return -1;
        if a[i] > b[i] return 1;
    }
    if a.count < b.count return -1;
    if a.count > b.count return 1;
    return 0;
}

// ============================================================================
// Color constant to ANSI index mapping
// ============================================================================

// Map Incursion color constants to 0-15 ANSI indices
color_to_ansi :: (color_const: s64) -> u8 {
    // These are the common color constants from Defines.h
    // RED, GREEN, BLUE, YELLOW, PURPLE, CYAN, GREY, WHITE, etc.
    // Values typically range 0-15 for standard colors
    if color_const >= 0 && color_const <= 15 {
        return cast(u8) color_const;
    }

    // Extended colors map to closest ANSI equivalent
    // This is a simplified mapping
    return 7;  // Default to grey
}

// ============================================================================
// CR-Based Lookup Functions
// ============================================================================

// Find a random monster with CR in range [cr_min, cr_max]
// Returns null if no matching monster found
find_monster_by_cr :: (db: *ResourceDB, cr_min: s32, cr_max: s32, rng_seed: u64) -> *RMonster {
    // Count matching monsters first
    count: s32 = 0;
    for mon: db.monsters {
        if mon.cr >= cr_min && mon.cr <= cr_max {
            count += 1;
        }
    }

    if count == 0 return null;

    // Pick a random one
    target := cast(s32)(rng_seed % cast(u64)count);
    idx: s32 = 0;
    for *mon: db.monsters {
        if mon.cr >= cr_min && mon.cr <= cr_max {
            if idx == target {
                return mon;
            }
            idx += 1;
        }
    }

    return null;
}

// Find a random monster with exact CR (or closest available)
// If exact CR not found, searches within +/- tolerance
find_monster_by_cr_fuzzy :: (db: *ResourceDB, target_cr: s32, tolerance: s32, rng_seed: u64) -> *RMonster {
    // Try exact CR first
    result := find_monster_by_cr(db, target_cr, target_cr, rng_seed);
    if result != null return result;

    // Expand search range
    for offset: 1..tolerance {
        result = find_monster_by_cr(db, target_cr - offset, target_cr + offset, rng_seed);
        if result != null return result;
    }

    // Last resort: any monster
    if db.monsters.count > 0 {
        idx := rng_seed % cast(u64)db.monsters.count;
        return *db.monsters[idx];
    }

    return null;
}

// Find a random item with level in range [level_min, level_max]
// Returns null if no matching item found
find_item_by_level :: (db: *ResourceDB, level_min: s32, level_max: s32, rng_seed: u64) -> *RItem {
    // Count matching items first
    count: s32 = 0;
    for item: db.items {
        item_level := cast(s32) item.level;
        if item_level >= level_min && item_level <= level_max {
            count += 1;
        }
    }

    if count == 0 return null;

    // Pick a random one
    target := cast(s32)(rng_seed % cast(u64)count);
    idx: s32 = 0;
    for *item: db.items {
        item_level := cast(s32) item.level;
        if item_level >= level_min && item_level <= level_max {
            if idx == target {
                return item;
            }
            idx += 1;
        }
    }

    return null;
}

// Find a random item with level close to target
find_item_by_level_fuzzy :: (db: *ResourceDB, target_level: s32, tolerance: s32, rng_seed: u64) -> *RItem {
    // Try exact level first
    result := find_item_by_level(db, target_level, target_level, rng_seed);
    if result != null return result;

    // Expand search range
    for offset: 1..tolerance {
        min_level := cast(s32) max(0, target_level - offset);
        result = find_item_by_level(db, min_level, target_level + cast(s32)offset, rng_seed);
        if result != null return result;
    }

    // Last resort: any item
    if db.items.count > 0 {
        idx := rng_seed % cast(u64)db.items.count;
        return *db.items[idx];
    }

    return null;
}
