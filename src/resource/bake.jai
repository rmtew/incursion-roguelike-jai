// Resource Baking - Compile-time .irh to runtime tables
//
// Uses #run to parse resource files at compile time and embed
// the results as constant arrays in the binary.
//
// Note: File and Sort are imported in main.jai

// ============================================================================
// Compile-time Resource Baking
// ============================================================================

// Parse a single .irh file and collect resources
parse_resource_file :: (path: string, monsters: *[..] RMonster, items: *[..] RItem,
                        terrains: *[..] RuntimeTerrain, regions: *[..] RuntimeRegion) -> bool {
    content, success := read_entire_file(path);
    if !success {
        print("Failed to read resource file: %\n", path);
        return false;
    }
    defer free(content);

    // Initialize lexer and parser
    lexer := lexer_init(content);
    tokens := lexer_tokenize_all(*lexer);
    parser := parser_init(tokens);

    // Parse all resources in the file
    ok := parser_parse(*parser);
    if !ok {
        print("Parse errors in %:\n", path);
        for err: parser.errors {
            print("  Line %: %\n", err.line, err.message);
        }
        // Continue anyway to get partial results
    }

    // Convert parsed results to runtime format (only valid entries)
    for mon: parser.monsters {
        if mon.name.count > 0 {  // Skip entries with empty names
            array_add(monsters, convert_monster(mon));
        }
    }

    for item: parser.items {
        if item.name.count > 0 {
            array_add(items, convert_item(item));
        }
    }

    for terrain: parser.terrains {
        if terrain.name.count > 0 {
            array_add(terrains, convert_terrain(terrain));
        }
    }

    for region: parser.regions {
        if region.name.count > 0 {
            array_add(regions, convert_region(region));
        }
    }

    return true;
}

// Convert ParsedMonster to RMonster
convert_monster :: (pm: ParsedMonster) -> RMonster {
    rm: RMonster;
    rm.name = copy_string(pm.name);  // Copy string data since parser strings reference freed memory

    // Extract glyph and color from image
    if pm.has_image {
        rm.glyph = cast(u16) pm.image.char_code;
        rm.fg_color = color_to_ansi(cast(s64) pm.image.color.base);
    } else {
        rm.glyph = #char "?";
        rm.fg_color = 7;
    }

    // Basic stats
    rm.cr = cast(s16) ifx pm.has_cr then pm.cr else 1;
    rm.hd = cast(s16) ifx pm.has_hd then pm.hd else 1;
    rm.size = cast(u8) ifx pm.has_size then pm.size else 2;  // SZ_MEDIUM
    rm.speed = cast(u8) ifx pm.has_mov then pm.mov else 30;

    // Ability scores (default to 10)
    rm.str_val = cast(s8) ifx pm.has_str then pm.str_val else 10;
    rm.dex_val = cast(s8) ifx pm.has_dex then pm.dex_val else 10;
    rm.con_val = cast(s8) ifx pm.has_con then pm.con_val else 10;
    rm.int_val = cast(s8) ifx pm.has_int then pm.int_val else 10;
    rm.wis_val = cast(s8) ifx pm.has_wis then pm.wis_val else 10;
    rm.cha_val = cast(s8) ifx pm.has_cha then pm.cha_val else 10;

    // Combat stats
    rm.ac = cast(s16) ifx pm.has_arm then pm.arm else 10;
    rm.hit_bonus = cast(s16) ifx pm.has_hit then pm.hit else 0;

    // Pack monster type flags
    rm.mtypes = 0;
    for mt: pm.mtypes {
        if mt >= 0 && mt < 64 {
            rm.mtypes |= (cast(u64)1) << cast(u64)mt;
        }
    }

    // Pack common flags
    rm.flags = 0;
    for flag: pm.flags {
        if flag >= 0 && flag < 64 {
            rm.flags |= (cast(u64)1) << cast(u64)flag;
        }
    }

    return rm;
}

// Convert ParsedItem to RItem
convert_item :: (pi: ParsedItem) -> RItem {
    ri: RItem;
    ri.name = copy_string(pi.name);  // Copy string data

    // Extract glyph and color
    if pi.has_image {
        ri.glyph = cast(u16) pi.image.char_code;
        ri.fg_color = color_to_ansi(cast(s64) pi.image.color.base);
    } else {
        ri.glyph = #char "?";
        ri.fg_color = 7;
    }

    ri.itype = cast(u16) pi.itype;
    ri.material = cast(u16) ifx pi.has_material then pi.material else 0;
    ri.weight = cast(u16) ifx pi.has_weight then pi.weight else 10;
    ri.cost = cast(u32) ifx pi.has_cost then pi.cost else 0;
    ri.level = cast(u8) ifx pi.has_level then pi.level else 1;
    ri.size = cast(u8) ifx pi.has_size then pi.size else 2;

    // Weapon properties
    if pi.has_small_dmg {
        ri.dmg_small = cast(u16)((pi.small_dmg.num << 8) | pi.small_dmg.sides);
    }
    if pi.has_large_dmg {
        ri.dmg_large = cast(u16)((pi.large_dmg.num << 8) | pi.large_dmg.sides);
    }
    ri.crit_range = cast(u8) ifx pi.has_threat then pi.threat else 1;
    ri.crit_mult = cast(u8) ifx pi.has_crit then pi.crit else 2;

    // Armor properties
    ri.armor_bonus = cast(s8) ifx pi.has_arm then pi.arm else 0;
    ri.max_dex = cast(s8) ifx pi.has_def then pi.def else 127;
    ri.armor_penalty = cast(s8) ifx pi.has_penalty then pi.penalty else 0;

    // Pack flags
    ri.flags = 0;
    for flag: pi.flags {
        if flag >= 0 && flag < 32 {
            ri.flags |= (cast(u32)1) << cast(u32)flag;
        }
    }

    return ri;
}

// Convert ParsedColor to ANSI color index (0-15)
// Accounts for color modifiers (BRIGHT, LIGHT, DARK)
parsed_color_to_ansi :: (color: ParsedColor) -> s64 {
    // Base color mapping to ANSI index
    // ANSI: 0=black, 1=darkblue, 2=darkgreen, 3=darkcyan, 4=darkred, 5=darkmagenta, 6=brown, 7=grey
    // Bright versions: 8=darkgrey, 9=lightblue, 10=lightgreen, 11=lightcyan, 12=lightred, 13=lightmagenta, 14=yellow, 15=white
    base: s64;
    if color.base == {
        case .NONE;    base = 7;   // Default to grey
        case .BLACK;   base = 0;
        case .WHITE;   base = 15;
        case .RED;     base = 4;
        case .BLUE;    base = 1;
        case .GREEN;   base = 2;
        case .YELLOW;  base = 6;   // Dark yellow = brown
        case .PURPLE;  base = 5;   // Magenta
        case .CYAN;    base = 3;
        case .GREY;    base = 7;
        case .BROWN;   base = 6;
        case .PINK;    base = 13;  // Bright magenta
        case .MAGENTA; base = 5;
        case .SHADOW;  base = 8;   // Dark grey
        case .SKY;     base = 11;  // Bright cyan
        case .AZURE;   base = 9;   // Bright blue
        case .EMERALD; base = 10;  // Bright green
        case;          base = 7;   // Default to grey
    }

    // Apply modifier
    if color.modifier == .BRIGHT || color.modifier == .LIGHT {
        // Add 8 to get bright version (if not already bright)
        if base < 8 && base != 0 {  // Don't brighten black
            base += 8;
        }
    } else if color.modifier == .DARK {
        // Remove brightness (if bright)
        if base >= 8 {
            base -= 8;
        }
    }

    return base;
}

// Convert ParsedTerrain to RuntimeTerrain
convert_terrain :: (pt: ParsedTerrain) -> RuntimeTerrain {
    rt: RuntimeTerrain;
    rt.name = copy_string(pt.name);  // Copy string data

    if pt.has_image {
        rt.glyph = cast(u16) pt.image.char_code;
        rt.fg_color = parsed_color_to_ansi(pt.image.color);
    } else {
        rt.glyph = #char "?";
        rt.fg_color = 7;
    }

    if pt.has_material {
        rt.material = pt.material;
    }

    // Check for solid/opaque flags
    rt.is_solid = false;
    rt.is_opaque = false;
    for flag: pt.flags {
        if flag == TF_SOLID rt.is_solid = true;
        if flag == TF_OPAQUE rt.is_opaque = true;
    }

    return rt;
}

// Convert ParsedRegion to RuntimeRegion
convert_region :: (pr: ParsedRegion) -> RuntimeRegion {
    rr: RuntimeRegion;
    rr.name = copy_string(pr.name);  // Copy string data
    rr.index = 0;  // Will be set during sorting

    // Build room types bitmask
    rr.room_types = 0;
    if pr.has_room_types {
        for rt: pr.room_types {
            if rt >= 0 && rt < 32 {
                rr.room_types |= (cast(u32)1) << cast(u32)rt;
            }
        }
    }

    rr.depth = cast(s32) ifx pr.has_depth then pr.depth else 0;

    // Pack flags: RF_* constants are indices (1-28), convert to bitmask (1 << index)
    // Original Incursion stores flags as a bitfield where bit N = flag index N
    rr.flags = 0;
    if pr.rtype > 0 && pr.rtype < 32 {
        rr.flags |= (cast(u32)1) << cast(u32) pr.rtype;
    }
    // Additional flags from "Flags:" line
    for flag: pr.flags {
        if flag > 0 && flag < 32 {
            rr.flags |= (cast(u32)1) << cast(u32) flag;
        }
    }

    // Terrain references - copy strings
    rr.floor_ref = ifx pr.has_floor then copy_string(pr.floor) else "";
    rr.wall_ref = ifx pr.has_walls then copy_string(pr.walls) else "";
    rr.door_ref = ifx pr.has_door then copy_string(pr.door) else "";

    // Grid data - copy string
    rr.has_grid = pr.has_grid;
    if pr.has_grid {
        rr.grid = copy_string(pr.grid);
        rr.grid_width = cast(s32) pr.grid_width;
        rr.grid_height = cast(s32) pr.grid_height;
    }

    rr.size = cast(s32) ifx pr.has_size then pr.size else 0;

    return rr;
}

// ============================================================================
// Bake All Resources
// ============================================================================

BakedResources :: struct {
    monsters: [..] RMonster;
    items: [..] RItem;
    terrains: [..] RuntimeTerrain;
    regions: [..] RuntimeRegion;

    // Sorted name arrays for binary search
    monster_names: [..] string;
    item_names: [..] string;
    terrain_names: [..] string;
}

bake_all_resources :: () -> BakedResources {
    result: BakedResources;

    // List of resource files to parse
    files :: string.[
        "lib/mon1.irh",
        "lib/mon2.irh",
        "lib/mon3.irh",
        "lib/mon4.irh",
        "lib/mundane.irh",
        "lib/dungeon.irh",
        "lib/weapons.irh",
    ];

    for file: files {
        parse_resource_file(file, *result.monsters, *result.items,
                           *result.terrains, *result.regions);
    }

    // Sort by name for binary search
    sort_by_name(*result.monsters);
    sort_by_name(*result.items);
    sort_by_name(*result.terrains);

    // Build name lookup arrays
    for mon: result.monsters {
        array_add(*result.monster_names, mon.name);
    }
    for item: result.items {
        array_add(*result.item_names, item.name);
    }
    for terrain: result.terrains {
        array_add(*result.terrain_names, terrain.name);
    }

    // Assign indices to regions
    for i: 0..result.regions.count-1 {
        result.regions[i].index = cast(s32) i;
    }

    return result;
}

// Sort resources by name
sort_by_name :: (arr: *[..] $T) {
    quick_sort(arr.*, (a: T, b: T) -> s64 {
        // Safe comparison handling null/empty names
        if a.name.data == null && b.name.data == null return 0;
        if a.name.data == null return -1;
        if b.name.data == null return 1;
        return cast(s64) cmp_str_for_search(a.name, b.name);
    });
}

// ============================================================================
// Compile-time Baking (Deferred)
// ============================================================================

// TODO: Add #run block for true compile-time baking once runtime parsing is stable.
// For now, we bake at runtime via init_resource_db().
//
// True compile-time baking would use:
// #run {
//     baked := bake_all_resources();
//     // Use #insert to generate constant arrays
// }

// ============================================================================
// Runtime Access to Baked Data
// ============================================================================

// Global baked resource database (populated at compile time)
// Note: In production, this would be generated via #insert
BAKED_DB: ResourceDB;

// Initialize the resource database (call once at startup)
init_resource_db :: () {
    // For now, bake at runtime since #insert codegen is complex
    baked := bake_all_resources();

    BAKED_DB.monsters = baked.monsters;
    BAKED_DB.items = baked.items;
    BAKED_DB.terrains = baked.terrains;
    BAKED_DB.regions = baked.regions;
    BAKED_DB.monster_names = baked.monster_names;
    BAKED_DB.item_names = baked.item_names;
    BAKED_DB.terrain_names = baked.terrain_names;
}

// Get the global resource database
get_resource_db :: () -> *ResourceDB {
    return *BAKED_DB;
}

// Get baked regions array (for dungeon generation)
get_baked_regions :: () -> [] RuntimeRegion {
    return BAKED_DB.regions;
}
