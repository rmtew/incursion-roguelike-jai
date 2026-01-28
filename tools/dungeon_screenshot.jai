// Dungeon Screenshot - Headless dungeon image generator
//
// Generates a dungeon and saves it as a PNG without opening a window.

#import "Basic";
#import "Math";
#import "Random";
#import "File";

stbi :: #import "stb_image";
stbi_write :: #import "stb_image_write";

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

// Resource parser (needed for WeightListEntry in weights.jai)
#load "../src/resource/constants.jai";
#load "../src/resource/lexer.jai";
#load "../src/resource/parser.jai";

// RNG and dungeon generation
#load "../src/rng.jai";
#load "../src/dungeon/map.jai";
#load "../src/dungeon/terrain_registry.jai";
#load "../src/dungeon/weights.jai";
#load "../src/dungeon/makelev.jai";
#load "../src/dungeon/generator.jai";

// Color struct for rendering
Color :: struct {
    r, g, b: float32;
}

// Standard roguelike colors
TC_BLACK   :: Color.{0.0, 0.0, 0.0};
TC_WHITE   :: Color.{0.75, 0.75, 0.75};
TC_GREY    :: Color.{0.5, 0.5, 0.5};
TC_RED     :: Color.{0.8, 0.0, 0.0};
TC_GREEN   :: Color.{0.0, 0.8, 0.0};
TC_BLUE    :: Color.{0.0, 0.0, 0.8};
TC_YELLOW  :: Color.{0.8, 0.8, 0.0};
TC_CYAN    :: Color.{0.0, 0.8, 0.8};
TC_MAGENTA :: Color.{0.8, 0.0, 0.8};
TC_BROWN   :: Color.{0.6, 0.3, 0.0};

TC_BRIGHT_WHITE   :: Color.{1.0, 1.0, 1.0};
TC_BRIGHT_RED     :: Color.{1.0, 0.2, 0.2};
TC_BRIGHT_GREEN   :: Color.{0.2, 1.0, 0.2};
TC_BRIGHT_BLUE    :: Color.{0.4, 0.4, 1.0};
TC_BRIGHT_YELLOW  :: Color.{1.0, 1.0, 0.2};
TC_BRIGHT_CYAN    :: Color.{0.2, 1.0, 1.0};
TC_BRIGHT_MAGENTA :: Color.{1.0, 0.2, 1.0};

// Color mapping for terrain
get_terrain_color :: (t: Terrain) -> Color {
    if t == {
        case .ROCK;         return TC_BLACK;
        case .WALL;         return TC_GREY;
        case .FLOOR;        return TC_BROWN;
        case .CORRIDOR;     return Color.{0.4, 0.25, 0.1};
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
    }
    return TC_WHITE;
}

// Check for monster/item at position
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

// Font data
Font :: struct {
    pixels: *u8;
    width: s32;
    height: s32;
    channels: s32;
    glyph_width: s32;
    glyph_height: s32;
}

load_font :: (path: string, glyph_w: s32, glyph_h: s32) -> Font, bool {
    font: Font;
    font.glyph_width = glyph_w;
    font.glyph_height = glyph_h;

    // stbi_load needs null-terminated string
    c_path := to_c_string(path);
    defer free(c_path);

    font.pixels = stbi.stbi_load(c_path, *font.width, *font.height, *font.channels, 4);
    if font.pixels == null {
        print("ERROR: Failed to load font '%'\n", path);
        return font, false;
    }

    font.channels = 4;  // We requested RGBA
    print("Loaded font: % (%x%, % channels)\n", path, font.width, font.height, font.channels);
    return font, true;
}

free_font :: (font: *Font) {
    if font.pixels != null {
        stbi.stbi_image_free(font.pixels);
        font.pixels = null;
    }
}

// Output image buffer
Image :: struct {
    pixels: []u8;
    width: s32;
    height: s32;
}

create_image :: (width: s32, height: s32) -> Image {
    img: Image;
    img.width = width;
    img.height = height;
    img.pixels = NewArray(width * height * 4, u8);
    return img;
}

free_image :: (img: *Image) {
    array_free(img.pixels);
}

// Set a pixel in the image (RGBA)
set_pixel :: (img: *Image, x: s32, y: s32, r: u8, g: u8, b: u8, a: u8 = 255) {
    if x < 0 || x >= img.width || y < 0 || y >= img.height return;
    idx := (y * img.width + x) * 4;
    img.pixels[idx + 0] = r;
    img.pixels[idx + 1] = g;
    img.pixels[idx + 2] = b;
    img.pixels[idx + 3] = a;
}

// Fill a rectangle with a color
fill_rect :: (img: *Image, x: s32, y: s32, w: s32, h: s32, color: Color) {
    r := cast(u8)(color.r * 255);
    g := cast(u8)(color.g * 255);
    b := cast(u8)(color.b * 255);

    for py: y..y+h-1 {
        for px: x..x+w-1 {
            set_pixel(img, px, py, r, g, b);
        }
    }
}

// Draw a glyph from the font to the image
draw_glyph :: (img: *Image, font: *Font, char: u8, x: s32, y: s32, fg: Color, bg: Color) {
    // Fill background first
    fill_rect(img, x, y, font.glyph_width, font.glyph_height, bg);

    // Font is 16x16 grid of glyphs
    glyph_col := cast(s32)(char % 16);
    glyph_row := cast(s32)(char / 16);

    src_x := glyph_col * font.glyph_width;
    src_y := glyph_row * font.glyph_height;

    // Copy glyph pixels, tinting with foreground color
    for gy: 0..font.glyph_height-1 {
        for gx: 0..font.glyph_width-1 {
            src_idx := ((src_y + gy) * font.width + (src_x + gx)) * 4;

            // Get source pixel (font is white on transparent/black)
            font_r := font.pixels[src_idx + 0];
            font_g := font.pixels[src_idx + 1];
            font_b := font.pixels[src_idx + 2];
            font_a := font.pixels[src_idx + 3];

            // Use font luminance as alpha for tinting
            luminance := (cast(s32)font_r + cast(s32)font_g + cast(s32)font_b) / 3;

            if luminance > 10 {  // Threshold to avoid background noise
                // Blend foreground color based on font brightness
                alpha := cast(float32)luminance / 255.0;

                // Get background that's already there
                dst_x := x + gx;
                dst_y := y + gy;

                r := cast(u8)(fg.r * alpha * 255 + bg.r * (1.0 - alpha) * 255);
                g := cast(u8)(fg.g * alpha * 255 + bg.g * (1.0 - alpha) * 255);
                b := cast(u8)(fg.b * alpha * 255 + bg.b * (1.0 - alpha) * 255);

                set_pixel(img, dst_x, dst_y, r, g, b);
            }
        }
    }
}

// Render the entire dungeon to an image
render_dungeon :: (m: *GenMap, font: *Font) -> Image {
    img_width := m.width * font.glyph_width;
    img_height := m.height * font.glyph_height;

    img := create_image(img_width, img_height);

    for my: 0..m.height-1 {
        for mx: 0..m.width-1 {
            terrain := map_get(m, mx, my);
            glyph := terrain_glyph(terrain);
            fg := get_terrain_color(terrain);
            bg := TC_BLACK;

            // Check for custom tile display (from region terrain)
            td := map_get_display(m, mx, my);
            if td != null && td.use_custom {
                glyph = td.glyph;
                fg = color_index_to_color(td.fg_color);
            }

            // Special backgrounds
            if terrain == .WATER {
                bg = TC_BLUE;
            } else if terrain == .CHASM {
                bg = Color.{0.1, 0.1, 0.1};
            } else if terrain == .LAVA {
                bg = TC_RED;
            }

            // Monsters override terrain
            if monster_at(m, mx, my) {
                glyph = #char "M";
                fg = TC_BRIGHT_RED;
            } else if item_at(m, mx, my) {
                glyph = #char "*";
                fg = TC_BRIGHT_YELLOW;
            }

            px := mx * font.glyph_width;
            py := my * font.glyph_height;
            draw_glyph(*img, font, glyph, px, py, fg, bg);
        }
    }

    return img;
}

// Convert color index to Color struct
color_index_to_color :: (color_index: s64) -> Color {
    // Map ANSI color indices to RGB
    if color_index == {
        case 0;  return TC_BLACK;
        case 1;  return TC_RED;
        case 2;  return TC_GREEN;
        case 3;  return TC_YELLOW;
        case 4;  return TC_BLUE;
        case 5;  return TC_MAGENTA;
        case 6;  return TC_CYAN;
        case 7;  return TC_WHITE;
        case 8;  return TC_GREY;
        case 9;  return TC_BRIGHT_RED;
        case 10; return TC_BRIGHT_GREEN;
        case 11; return TC_BRIGHT_YELLOW;
        case 12; return TC_BRIGHT_BLUE;
        case 13; return TC_BRIGHT_MAGENTA;
        case 14; return TC_BRIGHT_CYAN;
        case 15; return TC_BRIGHT_WHITE;
    }
    return TC_WHITE;
}

main :: () {
    print("Dungeon Screenshot Generator\n");
    print("=============================\n\n");

    // Load font
    font, ok := load_font("../fonts/8x8.png", 8, 8);
    if !ok {
        // Try alternate path (running from project root)
        font, ok = load_font("fonts/8x8.png", 8, 8);
        if !ok {
            print("Could not load font\n");
            return;
        }
    }
    defer free_font(*font);

    // Generate dungeon
    dungeon: GenMap;
    seed: u64 = 42;  // Use seed that produces nice river
    mode := GeneratorMode.ORIGINAL;
    generate_dungeon(*dungeon, seed, mode);
    defer map_free(*dungeon);

    print("Generated dungeon: %x% tiles, % rooms\n", dungeon.width, dungeon.height, dungeon.rooms.count);

    // Render to image
    img := render_dungeon(*dungeon, *font);
    defer free_image(*img);

    print("Rendered image: %x% pixels\n", img.width, img.height);

    // Save PNG
    output_path := "../docs/screenshot.png";
    c_output := to_c_string(output_path);
    defer free(c_output);

    result := stbi_write.stbi_write_png(c_output, img.width, img.height, 4, img.pixels.data, img.width * 4);

    if result != 0 {
        print("Saved: %\n", output_path);
    } else {
        print("ERROR: Failed to save PNG\n");
    }
}
