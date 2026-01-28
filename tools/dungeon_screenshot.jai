// Headless Dungeon Screenshot Generator
//
// Generates a dungeon and saves it to docs/screenshot.png without opening a window.

#import "Basic";
#import "Math";
#import "Random";
#import "File";
#import "Sort";

stbi_write :: #import "stb_image_write";
stbi :: #import "stb_image";

// Simple Color struct for headless rendering
Color :: struct {
    r, g, b, a: float32;
}

// Terminal colors (same as window.jai but without Simp dependency)
TC_BLACK        :: Color.{0.0, 0.0, 0.0, 1.0};
TC_BLUE         :: Color.{0.0, 0.0, 0.67, 1.0};
TC_GREEN        :: Color.{0.0, 0.67, 0.0, 1.0};
TC_CYAN         :: Color.{0.0, 0.67, 0.67, 1.0};
TC_RED          :: Color.{0.67, 0.0, 0.0, 1.0};
TC_MAGENTA      :: Color.{0.67, 0.0, 0.67, 1.0};
TC_BROWN        :: Color.{0.67, 0.33, 0.0, 1.0};
TC_GREY         :: Color.{0.67, 0.67, 0.67, 1.0};
TC_DARK_GREY    :: Color.{0.33, 0.33, 0.33, 1.0};
TC_BRIGHT_BLUE  :: Color.{0.33, 0.33, 1.0, 1.0};
TC_BRIGHT_GREEN :: Color.{0.33, 1.0, 0.33, 1.0};
TC_BRIGHT_CYAN  :: Color.{0.33, 1.0, 1.0, 1.0};
TC_BRIGHT_RED   :: Color.{1.0, 0.33, 0.33, 1.0};
TC_BRIGHT_MAGENTA :: Color.{1.0, 0.33, 1.0, 1.0};
TC_YELLOW       :: Color.{1.0, 1.0, 0.33, 1.0};
TC_BRIGHT_YELLOW :: Color.{1.0, 1.0, 0.33, 1.0};  // Same as YELLOW (already bright)
TC_BRIGHT_WHITE :: Color.{1.0, 1.0, 1.0, 1.0};
TC_WHITE        :: Color.{0.75, 0.75, 0.75, 1.0};

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

// Convert ANSI color index (0-15) to RGB Color
ansi_to_rgb :: (ansi: s64) -> Color {
    // Standard 16-color ANSI palette
    if ansi == {
        case 0;  return TC_BLACK;
        case 1;  return TC_BLUE;
        case 2;  return TC_GREEN;
        case 3;  return TC_CYAN;
        case 4;  return TC_RED;
        case 5;  return TC_MAGENTA;
        case 6;  return TC_BROWN;
        case 7;  return TC_GREY;
        case 8;  return TC_DARK_GREY;
        case 9;  return TC_BRIGHT_BLUE;
        case 10; return TC_BRIGHT_GREEN;
        case 11; return TC_BRIGHT_CYAN;
        case 12; return TC_BRIGHT_RED;
        case 13; return TC_BRIGHT_MAGENTA;
        case 14; return TC_YELLOW;
        case 15; return TC_BRIGHT_WHITE;
    }
    return TC_GREY;  // Default
}

// Color mapping for terrain
get_terrain_color :: (t: Terrain) -> Color {
    if t == {
        case .ROCK;         return TC_BLACK;
        case .WALL;         return TC_GREY;
        case .FLOOR;        return TC_BROWN;
        case .CORRIDOR;     return Color.{0.4, 0.25, 0.1, 1.0};
        case .DOOR_CLOSED;  return TC_YELLOW;
        case .DOOR_OPEN;    return TC_BROWN;
        case .DOOR_SECRET;  return TC_GREY;
        case .STAIRS_UP;    return TC_BRIGHT_WHITE;
        case .STAIRS_DOWN;  return TC_BRIGHT_WHITE;
        case .WATER;        return TC_BRIGHT_BLUE;
        case .CHASM;        return TC_BLACK;
        case .LAVA;         return TC_BRIGHT_RED;
        case .TRAP;         return TC_BRIGHT_RED;
        case .TRAP_HIDDEN;  return TC_BROWN;
        case .PILLAR;       return TC_GREY;
        case .RUBBLE;       return TC_BROWN;
    }
    return TC_WHITE;
}

monster_at :: (m: *GenMap, x: s32, y: s32) -> bool {
    for mon: m.monsters {
        if mon.x == x && mon.y == y return true;
    }
    return false;
}

item_at :: (m: *GenMap, x: s32, y: s32) -> bool {
    for item: m.items {
        if item.x == x && item.y == y return true;
    }
    return false;
}

ScreenshotFont :: struct {
    pixels: *u8;
    width: s32;
    height: s32;
    glyph_width: s32;
    glyph_height: s32;
}

load_screenshot_font :: () -> ScreenshotFont, bool {
    font: ScreenshotFont;
    font.glyph_width = 8;
    font.glyph_height = 8;

    paths :: string.["fonts/8x8.png", "../fonts/8x8.png", "tools/../fonts/8x8.png"];

    channels: s32;
    for p: paths {
        c_path := to_c_string(p);
        defer free(c_path);
        font.pixels = stbi.stbi_load(c_path, *font.width, *font.height, *channels, 4);
        if font.pixels != null {
            return font, true;
        }
    }

    print("Failed to load font for screenshot\n");
    return font, false;
}

free_screenshot_font :: (font: *ScreenshotFont) {
    if font.pixels != null {
        stbi.stbi_image_free(font.pixels);
        font.pixels = null;
    }
}

draw_glyph_to_buffer :: (pixels: *u8, img_width: s32, img_height: s32, font: *ScreenshotFont,
                          char: u8, x: s32, y: s32, fg: Color, bg: Color) {
    glyph_col := cast(s32)(char % 16);
    glyph_row := cast(s32)(char / 16);

    src_x := glyph_col * font.glyph_width;
    src_y := glyph_row * font.glyph_height;

    bg_r := cast(u8)(bg.r * 255);
    bg_g := cast(u8)(bg.g * 255);
    bg_b := cast(u8)(bg.b * 255);

    fg_r := fg.r;
    fg_g := fg.g;
    fg_b := fg.b;

    for gy: 0..font.glyph_height-1 {
        for gx: 0..font.glyph_width-1 {
            dst_x := x + gx;
            dst_y := y + gy;
            if dst_x < 0 || dst_x >= img_width || dst_y < 0 || dst_y >= img_height continue;

            font_idx := ((src_y + gy) * font.width + (src_x + gx)) * 4;
            font_lum := (cast(s32)font.pixels[font_idx] + cast(s32)font.pixels[font_idx+1] + cast(s32)font.pixels[font_idx+2]) / 3;

            dst_idx := (dst_y * img_width + dst_x) * 4;
            if font_lum > 10 {
                alpha := cast(float32)font_lum / 255.0;
                pixels[dst_idx + 0] = cast(u8)(fg_r * alpha * 255 + bg_r * (1.0 - alpha));
                pixels[dst_idx + 1] = cast(u8)(fg_g * alpha * 255 + bg_g * (1.0 - alpha));
                pixels[dst_idx + 2] = cast(u8)(fg_b * alpha * 255 + bg_b * (1.0 - alpha));
                pixels[dst_idx + 3] = 255;
            } else {
                pixels[dst_idx + 0] = bg_r;
                pixels[dst_idx + 1] = bg_g;
                pixels[dst_idx + 2] = bg_b;
                pixels[dst_idx + 3] = 255;
            }
        }
    }
}

save_screenshot :: (m: *GenMap) -> bool {
    font, ok := load_screenshot_font();
    if !ok return false;
    defer free_screenshot_font(*font);

    img_width := m.width * font.glyph_width;
    img_height := m.height * font.glyph_height;

    print("Rendering full map: %x% tiles -> %x% pixels\n", m.width, m.height, img_width, img_height);


    pixels := NewArray(img_width * img_height * 4, u8);
    defer array_free(pixels);

    for my: 0..m.height-1 {
        for mx: 0..m.width-1 {
            terrain := map_get(m, mx, my);
            glyph := terrain_glyph(terrain);
            fg := get_terrain_color(terrain);
            bg := TC_BLACK;

            // Check for custom tile display
            td := map_get_display(m, mx, my);
            if td != null && td.use_custom {
                glyph = td.glyph;
                tc := terrain_color_to_rgb(td.fg_color);
                fg = Color.{tc.r, tc.g, tc.b, 1.0};
            }

            // Special backgrounds
            if terrain == .WATER {
                bg = TC_BLUE;
            } else if terrain == .CHASM {
                bg = Color.{0.1, 0.1, 0.1, 1.0};
            } else if terrain == .LAVA {
                bg = TC_RED;
            }

            // Check for monsters/items
            if monster_at(m, mx, my) {
                glyph = #char "M";
                fg = TC_BRIGHT_RED;
            } else if item_at(m, mx, my) {
                glyph = #char "*";
                fg = TC_BRIGHT_YELLOW;
            }

            glyph_u8: u8 = ifx glyph > 255 then #char "?" else cast(u8)glyph;
            draw_glyph_to_buffer(pixels.data, img_width, img_height, *font,
                                 glyph_u8, mx * font.glyph_width, my * font.glyph_height, fg, bg);
        }
    }

    save_paths :: string.["docs/screenshot.png", "../docs/screenshot.png", "tools/../docs/screenshot.png"];

    for p: save_paths {
        c_path := to_c_string(p);
        defer free(c_path);
        result := stbi_write.stbi_write_png(c_path, img_width, img_height, 4, pixels.data, img_width * 4);
        if result != 0 {
            print("Screenshot saved to %\n", p);
            return true;
        }
    }

    print("Failed to save screenshot\n");
    return false;
}

main :: () {
    print("Headless Dungeon Screenshot Generator\n");
    print("=====================================\n\n");

    // Initialize resource database
    print("Loading resources...\n");
    init_resource_db();
    db := get_resource_db();
    print("  Loaded % monsters, % items, % terrains\n", db.monsters.count, db.items.count, db.terrains.count);


    // Generate dungeon with same seed as dungeon_test
    dungeon: GenMap;
    seed: u64 = 12345;
    generate_dungeon(*dungeon, seed);

    print("Dungeon: %x% tiles, % rooms\n", dungeon.width, dungeon.height, dungeon.rooms.count);

    // Save screenshot
    save_screenshot(*dungeon);

    map_free(*dungeon);
    print("Done.\n");
}
