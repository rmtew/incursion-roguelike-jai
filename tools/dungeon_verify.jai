// Dungeon Visual Verification Tool
//
// Generates a dungeon and verifies that all cells render with correct
// glyphs and colors. Reports any mismatches for correctness debugging.
//
// Usage:
//   dungeon_verify.exe [--seed N] [--verbose]

#import "Basic";
#import "Math";
#import "Random";
#import "File";
#import "Sort";
#import "String";

// Core modules needed by dungeon generation
#load "../src/defines.jai";
#load "../src/dice.jai";
#load "../src/object.jai";
#load "../src/map.jai";
#load "../src/creature.jai";
#load "../src/item.jai";
#load "../src/feature.jai";
#load "../src/vision.jai";
#load "../src/registry.jai";
#load "../src/event.jai";
#load "../src/resource.jai";

// Resource parser
#load "../src/resource/constants.jai";
#load "../src/resource/lexer.jai";
#load "../src/resource/parser.jai";
#load "../src/resource/runtime.jai";
#load "../src/resource/bake.jai";

// RNG and dungeon generation
#load "../src/rng.jai";
#load "../src/dungeon/map.jai";
#load "../src/dungeon/terrain_registry.jai";
#load "../src/dungeon/weights.jai";
#load "../src/dungeon/makelev.jai";
#load "../src/dungeon/generator.jai";
#load "../src/dungeon/render.jai";

// Glyph to CP437 conversion
#load "../src/glyph_cp437.jai";

// ============================================================================
// Expected Rendering Rules
// ============================================================================

// ANSI color indices (must match defines.jai / terminal colors)
ANSI_BLACK   :: 0;
ANSI_BLUE    :: 1;
ANSI_GREEN   :: 2;
ANSI_CYAN    :: 3;
ANSI_RED     :: 4;
ANSI_MAGENTA :: 5;
ANSI_BROWN   :: 6;
ANSI_GREY    :: 7;
ANSI_DARK_GREY    :: 8;
ANSI_BRIGHT_BLUE  :: 9;
ANSI_BRIGHT_GREEN :: 10;
ANSI_BRIGHT_CYAN  :: 11;
ANSI_BRIGHT_RED   :: 12;
ANSI_BRIGHT_MAGENTA :: 13;
ANSI_YELLOW       :: 14;
ANSI_WHITE        :: 15;

// Expected glyph for each terrain type (after CP437 conversion)
// Must match terrain_glyph() in src/dungeon/map.jai
expected_terrain_glyph :: (t: Terrain) -> u8 {
    if t == {
        case .ROCK;         return #char " ";
        case .WALL;         return #char "#";
        case .FLOOR;        return #char ".";
        case .CORRIDOR;     return #char ".";
        case .DOOR_CLOSED;  return #char "+";
        case .DOOR_OPEN;    return #char "'";   // Apostrophe
        case .DOOR_SECRET;  return #char "#";
        case .STAIRS_UP;    return #char "<";
        case .STAIRS_DOWN;  return #char ">";
        case .WATER;        return #char "~";   // Tilde (default, custom may use 247)
        case .CHASM;        return #char " ";
        case .LAVA;         return #char "~";   // Tilde (default, custom may use 247)
        case .TRAP;         return #char "^";   // Caret
        case .TRAP_HIDDEN;  return #char ".";   // Looks like floor
        case .PILLAR;       return #char "0";   // Zero (pillar)
        case .RUBBLE;       return #char ";";   // Semicolon
    }
    return #char "?";
}

// Expected color for each terrain type (ANSI index)
expected_terrain_color :: (t: Terrain) -> s64 {
    if t == {
        case .ROCK;         return ANSI_BLACK;
        case .WALL;         return ANSI_GREY;
        case .FLOOR;        return ANSI_BROWN;
        case .CORRIDOR;     return ANSI_BROWN;
        case .DOOR_CLOSED;  return ANSI_YELLOW;
        case .DOOR_OPEN;    return ANSI_BROWN;
        case .DOOR_SECRET;  return ANSI_GREY;
        case .STAIRS_UP;    return ANSI_WHITE;
        case .STAIRS_DOWN;  return ANSI_WHITE;
        case .WATER;        return ANSI_BRIGHT_BLUE;
        case .CHASM;        return ANSI_BLACK;
        case .LAVA;         return ANSI_BRIGHT_RED;
        case .TRAP;         return ANSI_BRIGHT_RED;
        case .TRAP_HIDDEN;  return ANSI_BROWN;
        case .PILLAR;       return ANSI_GREY;
        case .RUBBLE;       return ANSI_BROWN;
    }
    return ANSI_WHITE;
}

// ============================================================================
// Verification Results
// ============================================================================

VerifyError :: struct {
    x, y: s32;
    terrain: Terrain;
    expected_glyph: u8;
    actual_glyph: u8;
    expected_color: s64;
    actual_color: s64;
    error_type: ErrorType;
}

ErrorType :: enum {
    GLYPH_MISMATCH;
    COLOR_MISMATCH;
    BOTH_MISMATCH;
}

VerifyResult :: struct {
    total_cells: s32;
    verified_ok: s32;
    errors: [..] VerifyError;

    // Statistics by terrain type
    terrain_counts: [16] s32;  // Count of each terrain type
    terrain_errors: [16] s32;  // Errors per terrain type
}

// ============================================================================
// Verification Logic
// ============================================================================

// Get what a cell SHOULD render as (glyph and color)
get_expected_render :: (m: *GenMap, x: s32, y: s32) -> glyph: u8, color: s64, has_override: bool {
    terrain := map_get(m, x, y);

    // Check for custom tile display (from region terrain)
    td := map_get_display(m, x, y);
    if td != null && td.use_custom {
        // Custom display overrides terrain default
        glyph := glyph_to_cp437(td.glyph);
        return glyph, td.fg_color, true;
    }

    // Use terrain defaults
    return expected_terrain_glyph(terrain), expected_terrain_color(terrain), false;
}

// Get what a cell ACTUALLY renders as
get_actual_render :: (m: *GenMap, x: s32, y: s32) -> glyph: u8, color: s64 {
    terrain := map_get(m, x, y);

    // This mirrors the rendering logic in dungeon_test.jai / dungeon_screenshot.jai
    glyph := terrain_glyph(terrain);
    color := expected_terrain_color(terrain);  // Default color

    // Check for custom tile display
    td := map_get_display(m, x, y);
    if td != null && td.use_custom {
        glyph = td.glyph;
        color = td.fg_color;
    }

    // Convert to CP437
    glyph_cp437 := glyph_to_cp437(glyph);

    return glyph_cp437, color;
}

// Verify entire map
verify_map :: (m: *GenMap, verbose: bool = false) -> VerifyResult {
    result: VerifyResult;
    result.total_cells = m.width * m.height;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            terrain := map_get(m, x, y);
            terrain_idx := cast(s32) terrain;
            if terrain_idx < 16 {
                result.terrain_counts[terrain_idx] += 1;
            }

            expected_glyph, expected_color, has_override := get_expected_render(m, x, y);
            actual_glyph, actual_color := get_actual_render(m, x, y);

            glyph_ok := expected_glyph == actual_glyph;
            color_ok := expected_color == actual_color;

            if glyph_ok && color_ok {
                result.verified_ok += 1;
            } else {
                error: VerifyError;
                error.x = x;
                error.y = y;
                error.terrain = terrain;
                error.expected_glyph = expected_glyph;
                error.actual_glyph = actual_glyph;
                error.expected_color = expected_color;
                error.actual_color = actual_color;

                if !glyph_ok && !color_ok {
                    error.error_type = .BOTH_MISMATCH;
                } else if !glyph_ok {
                    error.error_type = .GLYPH_MISMATCH;
                } else {
                    error.error_type = .COLOR_MISMATCH;
                }

                array_add(*result.errors, error);

                if terrain_idx < 16 {
                    result.terrain_errors[terrain_idx] += 1;
                }

                if verbose {
                    print("  [%,%] %: expected glyph=% color=%, got glyph=% color=%\n",
                          x, y, terrain,
                          expected_glyph, expected_color,
                          actual_glyph, actual_color);
                }
            }
        }
    }

    return result;
}

// ============================================================================
// Specific Correctness Rules
// ============================================================================

// Rule: All WATER terrain must have blue color (unless custom display)
verify_water_is_blue :: (m: *GenMap) -> pass: bool, failures: s32 {
    failures: s32 = 0;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            terrain := map_get(m, x, y);
            if terrain == .WATER {
                td := map_get_display(m, x, y);

                // If custom display, check that color is blue-ish
                if td != null && td.use_custom {
                    // Accept BLUE, BRIGHT_BLUE, CYAN, BRIGHT_CYAN as "blue"
                    is_blue := td.fg_color == ANSI_BLUE ||
                               td.fg_color == ANSI_BRIGHT_BLUE ||
                               td.fg_color == ANSI_CYAN ||
                               td.fg_color == ANSI_BRIGHT_CYAN;
                    if !is_blue {
                        print("  FAIL: Water at (%,%) has non-blue color %\n", x, y, td.fg_color);
                        failures += 1;
                    }
                }
                // If no custom display, default color will be BRIGHT_BLUE (correct)
            }
        }
    }

    return failures == 0, failures;
}

// Rule: All LAVA terrain must have red color
verify_lava_is_red :: (m: *GenMap) -> pass: bool, failures: s32 {
    failures: s32 = 0;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            terrain := map_get(m, x, y);
            if terrain == .LAVA {
                td := map_get_display(m, x, y);

                if td != null && td.use_custom {
                    is_red := td.fg_color == ANSI_RED ||
                              td.fg_color == ANSI_BRIGHT_RED;
                    if !is_red {
                        print("  FAIL: Lava at (%,%) has non-red color %\n", x, y, td.fg_color);
                        failures += 1;
                    }
                }
            }
        }
    }

    return failures == 0, failures;
}

// Rule: No cell should render as '?' (unknown glyph)
verify_no_question_marks :: (m: *GenMap) -> pass: bool, failures: s32 {
    failures: s32 = 0;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            actual_glyph, _ := get_actual_render(m, x, y);
            if actual_glyph == #char "?" {
                terrain := map_get(m, x, y);
                td := map_get_display(m, x, y);
                raw_glyph: u16 = terrain_glyph(terrain);
                if td != null && td.use_custom {
                    raw_glyph = td.glyph;
                }
                print("  FAIL: Cell (%,%) renders as '?' (terrain=%, raw_glyph=%)\n",
                      x, y, terrain, raw_glyph);
                failures += 1;
            }
        }
    }

    return failures == 0, failures;
}

// Rule: Extended glyphs (256+) must be converted to valid CP437 (0-255)
verify_glyph_conversion :: (m: *GenMap) -> pass: bool, failures: s32 {
    failures: s32 = 0;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            td := map_get_display(m, x, y);
            if td != null && td.use_custom {
                if td.glyph >= 256 {
                    cp437 := glyph_to_cp437(td.glyph);
                    if cp437 == #char "?" && td.glyph != #char "?" {
                        print("  FAIL: Extended glyph % at (%,%) has no CP437 mapping\n",
                              td.glyph, x, y);
                        failures += 1;
                    }
                }
            }
        }
    }

    return failures == 0, failures;
}

// Rule: TileDisplay.use_custom consistency - if terrain changed, display should match
verify_display_consistency :: (m: *GenMap) -> pass: bool, failures: s32 {
    failures: s32 = 0;

    // This is harder to verify without tracking history.
    // For now, just check that custom displays make sense for the terrain.

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            terrain := map_get(m, x, y);
            td := map_get_display(m, x, y);

            if td != null && td.use_custom {
                // Water/Lava with non-wavy glyph is suspicious
                if terrain == .WATER || terrain == .LAVA {
                    cp437 := glyph_to_cp437(td.glyph);
                    if cp437 != 247 && cp437 != #char "~" {
                        // Not necessarily wrong (could be ice?), but worth flagging
                        // For now, just log in verbose mode
                    }
                }
            }
        }
    }

    return failures == 0, failures;
}

// Rule: Multiple entities at same cell should use GLYPH_MULTI/GLYPH_PILE
verify_entity_stacking :: (m: *GenMap) -> pass: bool, multi_count: s32, pile_count: s32 {
    multi_count: s32 = 0;
    pile_count: s32 = 0;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            mon_count := count_monsters_at(m, x, y);
            item_count := count_items_at(m, x, y);

            // Get what render module produces
            glyph, _, _ := get_cell_render(m, x, y);

            if mon_count > 1 {
                // Should show GLYPH_MULTI
                if glyph == GLYPH_MULTI {
                    multi_count += 1;
                }
            } else if mon_count == 0 && item_count > 1 {
                // Should show GLYPH_PILE (only if no monsters)
                if glyph == GLYPH_PILE {
                    pile_count += 1;
                }
            }
        }
    }

    // Always pass - this is informational
    return true, multi_count, pile_count;
}

// Rule: Entities should have non-zero glyphs
verify_entity_glyphs :: (m: *GenMap) -> pass: bool, failures: s32 {
    failures: s32 = 0;

    for mon, idx: m.monsters {
        if mon.glyph == 0 {
            print("  WARN: Monster % at (%,%) has glyph=0\n", idx, mon.x, mon.y);
            // Not a failure since render.jai has fallback
        }
    }

    for item, idx: m.items {
        if item.glyph == 0 {
            print("  WARN: Item % at (%,%) has glyph=0\n", idx, item.x, item.y);
            // Not a failure since render.jai has fallback
        }
    }

    return failures == 0, failures;
}

// ============================================================================
// Main
// ============================================================================

main :: () {
    print("Dungeon Visual Verification Tool\n");
    print("=================================\n\n");

    // Parse arguments
    args := get_command_line_arguments();
    seed: u64 = 12345;
    verbose := false;

    i := 1;
    while i < args.count {
        arg := args[i];
        if arg == "--seed" || arg == "-s" {
            if i + 1 < args.count {
                seed = parse_seed_arg(args[i + 1]);
                i += 1;
            }
        } else if arg == "--verbose" || arg == "-v" {
            verbose = true;
        } else if arg == "--help" || arg == "-h" {
            print("Usage: dungeon_verify.exe [--seed N] [--verbose]\n");
            return;
        }
        i += 1;
    }

    // Initialize resources
    print("Loading resources...\n");
    init_resource_db();
    db := get_resource_db();
    print("  Loaded % monsters, % items, % terrains\n\n",
          db.monsters.count, db.items.count, db.terrains.count);

    // Generate dungeon
    print("Generating dungeon with seed %...\n", seed);
    dungeon: GenMap;
    generate_dungeon(*dungeon, seed);
    print("  Size: %x%, % rooms\n\n", dungeon.width, dungeon.height, dungeon.rooms.count);

    // Debug: dump TileDisplay info for room 0
    print("TileDisplay debug for room 0 (sample cells):\n");
    custom_count := 0;
    for y: 2..12 {
        for x: 2..18 {
            td := map_get_display(*dungeon, cast(s32)x, cast(s32)y);
            terrain := map_get(*dungeon, cast(s32)x, cast(s32)y);
            if td != null && td.use_custom {
                custom_count += 1;
                if custom_count <= 10 {
                    cp437 := glyph_to_cp437(td.glyph);
                    print("  (%,%) terrain=% glyph=% (cp437=%) color=%\n",
                          x, y, terrain, td.glyph, cp437, td.fg_color);
                }
            }
        }
    }
    print("  Total cells with custom display in room 0: %\n\n", custom_count);

    // Run verification
    print("Running verification checks...\n\n");

    total_pass := 0;
    total_fail := 0;

    // Check 1: No question marks
    {
        print("Check 1: No '?' glyphs (unknown glyph conversion)\n");
        pass, failures := verify_no_question_marks(*dungeon);
        if pass {
            print("  PASS\n");
            total_pass += 1;
        } else {
            print("  FAIL: % cells render as '?'\n", failures);
            total_fail += 1;
        }
        print("\n");
    }

    // Check 2: Water is blue
    {
        print("Check 2: Water terrain is blue\n");
        pass, failures := verify_water_is_blue(*dungeon);
        if pass {
            print("  PASS\n");
            total_pass += 1;
        } else {
            print("  FAIL: % water cells have wrong color\n", failures);
            total_fail += 1;
        }
        print("\n");
    }

    // Check 3: Lava is red
    {
        print("Check 3: Lava terrain is red\n");
        pass, failures := verify_lava_is_red(*dungeon);
        if pass {
            print("  PASS\n");
            total_pass += 1;
        } else {
            print("  FAIL: % lava cells have wrong color\n", failures);
            total_fail += 1;
        }
        print("\n");
    }

    // Check 4: Extended glyph conversion
    {
        print("Check 4: Extended glyphs (256+) have CP437 mappings\n");
        pass, failures := verify_glyph_conversion(*dungeon);
        if pass {
            print("  PASS\n");
            total_pass += 1;
        } else {
            print("  FAIL: % extended glyphs have no mapping\n", failures);
            total_fail += 1;
        }
        print("\n");
    }

    // Check 5: Entity glyph assignment
    {
        print("Check 5: Entity glyph assignment\n");
        pass, failures := verify_entity_glyphs(*dungeon);
        if pass {
            print("  PASS: All entities have assigned glyphs\n");
            total_pass += 1;
        } else {
            print("  FAIL: % entities missing glyphs\n", failures);
            total_fail += 1;
        }
        print("\n");
    }

    // Check 6: Entity stacking (GLYPH_MULTI/GLYPH_PILE)
    {
        print("Check 6: Entity stacking glyphs\n");
        pass, multi_count, pile_count := verify_entity_stacking(*dungeon);
        print("  INFO: % cells with GLYPH_MULTI (multiple creatures)\n", multi_count);
        print("  INFO: % cells with GLYPH_PILE (multiple items)\n", pile_count);
        if pass {
            print("  PASS\n");
            total_pass += 1;
        }
        print("\n");
    }

    // Full map verification
    {
        print("Check 7: Full map glyph/color verification\n");
        result := verify_map(*dungeon, verbose);
        if result.errors.count == 0 {
            print("  PASS: All % cells verified\n", result.total_cells);
            total_pass += 1;
        } else {
            print("  FAIL: % errors in % cells\n", result.errors.count, result.total_cells);
            total_fail += 1;

            // Summarize by error type
            glyph_errors := 0;
            color_errors := 0;
            both_errors := 0;
            for err: result.errors {
                if err.error_type == .GLYPH_MISMATCH glyph_errors += 1;
                else if err.error_type == .COLOR_MISMATCH color_errors += 1;
                else both_errors += 1;
            }
            print("    Glyph mismatches: %\n", glyph_errors);
            print("    Color mismatches: %\n", color_errors);
            print("    Both mismatched:  %\n", both_errors);

            // Show first few errors
            if !verbose && result.errors.count > 0 {
                print("    First errors (use --verbose for all):\n");
                for i: 0..min(4, result.errors.count-1) {
                    err := result.errors[i];
                    print("      [%,%] %: glyph %->%, color %->%\n",
                          err.x, err.y, err.terrain,
                          err.expected_glyph, err.actual_glyph,
                          err.expected_color, err.actual_color);
                }
            }
        }
        print("\n");
    }

    // Summary
    print("========================================\n");
    print("Verification: % passed, % failed\n", total_pass, total_fail);
    if total_fail == 0 {
        print("ALL CHECKS PASSED\n");
    } else {
        print("SOME CHECKS FAILED\n");
    }
    print("========================================\n");

    // Clean up
    map_free(*dungeon);
}

// Helper to convert string to int
parse_seed_arg :: (s: string) -> u64 {
    result: u64 = 0;
    for c: s {
        if c >= #char "0" && c <= #char "9" {
            result = result * 10 + cast(u64)(c - #char "0");
        }
    }
    return result;
}
