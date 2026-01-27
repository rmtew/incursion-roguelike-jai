// Terrain Registry - Runtime terrain lookup for dungeon generation
//
// Stores parsed terrain data for lookup by name, enabling regions to
// reference specific terrain types (e.g., "shallow water", "ice wall").
//
// Note: This file is loaded by dungeon_test.jai which handles all imports.

#import "Hash_Table";

// Runtime terrain representation (resolved from ParsedTerrain)
RuntimeTerrain :: struct {
    name: string;
    glyph: u8;
    fg_color: s64;         // Color constant from resources
    bg_color: s64;         // Background color (usually 0)
    material: s64;         // Material constant
    flags: u32;            // TF_* flags for passability, etc.

    // Display helpers
    is_solid: bool;        // Blocks movement
    is_opaque: bool;       // Blocks LOS
}

// Terrain flags (from Defines.h)
TF_SOLID     :: 0x0001;   // Blocks movement
TF_OPAQUE    :: 0x0002;   // Blocks line of sight
TF_WATER     :: 0x0004;   // Is water terrain
TF_LAVA      :: 0x0008;   // Is lava terrain
TF_DEEP      :: 0x0010;   // Deep water/lava (dangerous)
TF_FALL      :: 0x0020;   // Causes falling (chasm, pit)

// Terrain registry for lookup by name
TerrainRegistry :: struct {
    by_name: Table(string, *RuntimeTerrain);
    terrains: [..] RuntimeTerrain;   // Storage for terrain data
}

// Initialize an empty terrain registry
terrain_registry_init :: (reg: *TerrainRegistry) {
    init(*reg.by_name);
    array_reset(*reg.terrains);
}

// Free terrain registry resources
terrain_registry_free :: (reg: *TerrainRegistry) {
    deinit(*reg.by_name);
    array_free(reg.terrains);
}

// Add a terrain to the registry
terrain_registry_add :: (reg: *TerrainRegistry, terrain: RuntimeTerrain) -> *RuntimeTerrain {
    // Add to storage array
    array_add(*reg.terrains, terrain);
    ptr := *reg.terrains[reg.terrains.count - 1];

    // Add to lookup table
    table_add(*reg.by_name, terrain.name, ptr);

    return ptr;
}

// Look up terrain by name
terrain_registry_get :: (reg: *TerrainRegistry, name: string) -> *RuntimeTerrain {
    ptr := table_find_pointer(*reg.by_name, name);
    if ptr != null return ptr.*;
    return null;
}

// Build terrain registry from parsed terrains
build_terrain_registry :: (reg: *TerrainRegistry, parsed: [] ParsedTerrain) {
    terrain_registry_init(reg);

    for pt: parsed {
        rt: RuntimeTerrain;
        rt.name = pt.name;

        // Extract glyph from image
        if pt.has_image {
            rt.glyph = cast(u8) pt.image.char_code;
            rt.fg_color = cast(s64) pt.image.color.base;
        } else {
            rt.glyph = #char "?";
            rt.fg_color = 7;  // White
        }

        // Extract material
        if pt.has_material {
            rt.material = pt.material;
        }

        // Determine solid/opaque from flags
        rt.is_solid = false;
        rt.is_opaque = false;
        for flag: pt.flags {
            if flag == TF_SOLID rt.is_solid = true;
            if flag == TF_OPAQUE rt.is_opaque = true;
        }

        terrain_registry_add(reg, rt);
    }
}

// Default terrains (used when no resources loaded)
// These match the hardcoded Terrain enum values
create_default_terrains :: (reg: *TerrainRegistry) {
    terrain_registry_init(reg);

    // Floor
    floor: RuntimeTerrain;
    floor.name = "floor";
    floor.glyph = #char ".";
    floor.fg_color = 6;  // Brown/yellow
    floor.is_solid = false;
    floor.is_opaque = false;
    terrain_registry_add(reg, floor);

    // Wall
    wall: RuntimeTerrain;
    wall.name = "wall";
    wall.glyph = #char "#";
    wall.fg_color = 7;  // Grey
    wall.is_solid = true;
    wall.is_opaque = true;
    terrain_registry_add(reg, wall);

    // Shallow water
    shallow_water: RuntimeTerrain;
    shallow_water.name = "shallow water";
    shallow_water.glyph = #char "~";
    shallow_water.fg_color = 9;  // Light blue
    shallow_water.is_solid = false;
    shallow_water.is_opaque = false;
    terrain_registry_add(reg, shallow_water);

    // Deep water
    deep_water: RuntimeTerrain;
    deep_water.name = "deep water";
    deep_water.glyph = #char "~";
    deep_water.fg_color = 1;  // Dark blue
    deep_water.is_solid = false;
    deep_water.is_opaque = false;
    terrain_registry_add(reg, deep_water);

    // Ice wall
    ice_wall: RuntimeTerrain;
    ice_wall.name = "ice wall";
    ice_wall.glyph = #char "#";
    ice_wall.fg_color = 11;  // Cyan
    ice_wall.is_solid = true;
    ice_wall.is_opaque = true;
    terrain_registry_add(reg, ice_wall);

    // Ice floor
    ice_floor: RuntimeTerrain;
    ice_floor.name = "ice floor";
    ice_floor.glyph = #char ".";
    ice_floor.fg_color = 11;  // Cyan
    ice_floor.is_solid = false;
    ice_floor.is_opaque = false;
    terrain_registry_add(reg, ice_floor);

    // Lava
    lava: RuntimeTerrain;
    lava.name = "lava";
    lava.glyph = #char "~";
    lava.fg_color = 12;  // Bright red
    lava.is_solid = false;
    lava.is_opaque = false;
    terrain_registry_add(reg, lava);

    // Chasm
    chasm: RuntimeTerrain;
    chasm.name = "chasm";
    chasm.glyph = #char " ";
    chasm.fg_color = 0;  // Black
    chasm.is_solid = false;
    chasm.is_opaque = false;
    terrain_registry_add(reg, chasm);

    // Stone wall (dungeon default)
    stone_wall: RuntimeTerrain;
    stone_wall.name = "stone wall";
    stone_wall.glyph = #char "#";
    stone_wall.fg_color = 8;  // Dark grey
    stone_wall.is_solid = true;
    stone_wall.is_opaque = true;
    terrain_registry_add(reg, stone_wall);

    // Granite wall
    granite_wall: RuntimeTerrain;
    granite_wall.name = "granite wall";
    granite_wall.glyph = #char "#";
    granite_wall.fg_color = 15;  // Bright white
    granite_wall.is_solid = true;
    granite_wall.is_opaque = true;
    terrain_registry_add(reg, granite_wall);

    // Moss-covered floor
    moss_floor: RuntimeTerrain;
    moss_floor.name = "moss-covered floor";
    moss_floor.glyph = #char ".";
    moss_floor.fg_color = 2;  // Green
    moss_floor.is_solid = false;
    moss_floor.is_opaque = false;
    terrain_registry_add(reg, moss_floor);

    // Dirt floor
    dirt_floor: RuntimeTerrain;
    dirt_floor.name = "dirt floor";
    dirt_floor.glyph = #char ".";
    dirt_floor.fg_color = 6;  // Brown
    dirt_floor.is_solid = false;
    dirt_floor.is_opaque = false;
    terrain_registry_add(reg, dirt_floor);

    // Marble floor
    marble_floor: RuntimeTerrain;
    marble_floor.name = "marble floor";
    marble_floor.glyph = #char ".";
    marble_floor.fg_color = 15;  // Bright white
    marble_floor.is_solid = false;
    marble_floor.is_opaque = false;
    terrain_registry_add(reg, marble_floor);

    // Cobblestone
    cobblestone: RuntimeTerrain;
    cobblestone.name = "cobblestone";
    cobblestone.glyph = #char ".";
    cobblestone.fg_color = 7;  // Grey
    cobblestone.is_solid = false;
    cobblestone.is_opaque = false;
    terrain_registry_add(reg, cobblestone);
}

// Convert color constant to RGB Color
terrain_color_to_rgb :: (color_const: s64) -> Color {
    // Map common ANSI color constants to RGB
    // These match the TC_* colors in terminal/window.jai
    if color_const == {
        case 0;  return Color.{0.0, 0.0, 0.0};        // Black
        case 1;  return Color.{0.0, 0.0, 0.5};        // Dark blue
        case 2;  return Color.{0.0, 0.5, 0.0};        // Dark green
        case 3;  return Color.{0.0, 0.5, 0.5};        // Dark cyan
        case 4;  return Color.{0.5, 0.0, 0.0};        // Dark red
        case 5;  return Color.{0.5, 0.0, 0.5};        // Dark magenta
        case 6;  return Color.{0.6, 0.4, 0.2};        // Brown
        case 7;  return Color.{0.7, 0.7, 0.7};        // Grey
        case 8;  return Color.{0.4, 0.4, 0.4};        // Dark grey
        case 9;  return Color.{0.3, 0.3, 1.0};        // Light blue
        case 10; return Color.{0.3, 1.0, 0.3};        // Light green
        case 11; return Color.{0.3, 1.0, 1.0};        // Light cyan
        case 12; return Color.{1.0, 0.3, 0.3};        // Light red
        case 13; return Color.{1.0, 0.3, 1.0};        // Light magenta
        case 14; return Color.{1.0, 1.0, 0.3};        // Yellow
        case 15; return Color.{1.0, 1.0, 1.0};        // White
    }
    return Color.{0.7, 0.7, 0.7};  // Default grey
}
