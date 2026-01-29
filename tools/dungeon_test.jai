// Dungeon Test - Generate and display a dungeon
//
// Creates a dungeon using BSP and renders it in the terminal.

#import "Basic";
#import "Math";
#import "Random";
#import "File";
#import "Sort";
#import "Window_Creation";

Input :: #import "Input";
Simp  :: #import "Simp";
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
#load "../src/dungeon/visibility.jai";

// Glyph to CP437 conversion (must be before terminal/window.jai)
#load "../src/glyph_cp437.jai";

// Terminal rendering
#load "../src/terminal/window.jai";

// Color mapping for terrain (fallback)
get_terrain_color :: (t: Terrain) -> Color {
    if t == {
        case .ROCK;         return TC_BLACK;
        case .WALL;         return TC_GREY;
        case .FLOOR;        return TC_BROWN;
        case .CORRIDOR;     return Color.{0.4, 0.25, 0.1};  // Darker brown
        case .DOOR_CLOSED;  return TC_YELLOW;
        case .DOOR_OPEN;    return TC_BROWN;
        case .DOOR_SECRET;  return TC_GREY;
        case .STAIRS_UP;    return TC_BRIGHT_WHITE;
        case .STAIRS_DOWN;  return TC_BRIGHT_WHITE;
        case .WATER;        return TC_BRIGHT_BLUE;
        case .CHASM;        return TC_BLACK;
        case .LAVA;         return TC_BRIGHT_RED;
        case .TRAP;         return TC_BRIGHT_RED;
        case .TRAP_HIDDEN;  return TC_BROWN;  // Looks like floor
        case .PILLAR;       return TC_GREY;   // Stone pillar
        case .RUBBLE;       return TC_BROWN;  // Rubble/debris
    }
    return TC_WHITE;
}

// Convert ANSI color index to Color struct
ansi_to_color :: (ansi: u8) -> Color {
    r, g, b := ansi_to_rgb(ansi);
    return Color.{r, g, b};
}

// Font data for software rendering
ScreenshotFont :: struct {
    pixels: *u8;
    width: s32;
    height: s32;
    glyph_width: s32;
    glyph_height: s32;
}

stbi :: #import "stb_image";

load_screenshot_font :: () -> ScreenshotFont, bool {
    font: ScreenshotFont;
    font.glyph_width = 8;
    font.glyph_height = 8;

    // Try multiple paths depending on CWD
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

    print("Failed to load font for screenshot (tried: fonts/8x8.png, ../fonts/8x8.png)\n");
    return font, false;
}

free_screenshot_font :: (font: *ScreenshotFont) {
    if font.pixels != null {
        stbi.stbi_image_free(font.pixels);
        font.pixels = null;
    }
}

// Render full map to PNG file
save_screenshot :: (m: *GenMap) -> bool {
    font, ok := load_screenshot_font();
    if !ok return false;
    defer free_screenshot_font(*font);

    img_width := m.width * font.glyph_width;
    img_height := m.height * font.glyph_height;

    print("Rendering full map: %x% tiles -> %x% pixels\n", m.width, m.height, img_width, img_height);

    pixels := NewArray(img_width * img_height * 4, u8);
    defer array_free(pixels);

    // Render each tile
    for my: 0..m.height-1 {
        for mx: 0..m.width-1 {
            // Use the render module to get proper priority-based rendering
            glyph, fg_ansi, bg_ansi := get_cell_render(m, mx, my);
            fg := ansi_to_color(fg_ansi);
            bg := ansi_to_color(bg_ansi);

            // Convert extended glyphs (256+) to CP437 for font atlas lookup
            glyph_cp437 := glyph_to_cp437(glyph);
            draw_glyph_to_buffer(pixels.data, img_width, img_height, *font,
                                 glyph_cp437, mx * font.glyph_width, my * font.glyph_height, fg, bg);
        }
    }

    // Try multiple paths depending on CWD
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

    print("Failed to save screenshot. Tried:\n");
    for p: save_paths {
        print("  %\n", p);
    }
    return false;
}

// Draw a glyph from font to pixel buffer
draw_glyph_to_buffer :: (pixels: *u8, img_width: s32, img_height: s32, font: *ScreenshotFont,
                          char: u8, x: s32, y: s32, fg: Color, bg: Color) {
    // Font is 16x16 grid of glyphs
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

            // Get font pixel
            font_idx := ((src_y + gy) * font.width + (src_x + gx)) * 4;
            font_lum := (cast(s32)font.pixels[font_idx] + cast(s32)font.pixels[font_idx+1] + cast(s32)font.pixels[font_idx+2]) / 3;

            // Blend based on font luminance
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

main :: () {
    print("Incursion Dungeon Test\n");
    print("======================\n\n");

    // Initialize resource database (parses .irh files)
    print("Loading resources...\n");
    init_resource_db();
    db := get_resource_db();
    print("  Loaded % monsters, % items, % terrains\n", db.monsters.count, db.items.count, db.terrains.count);

    // Initialize terminal (use smaller font for bigger map)
    term, ok := terminal_init(.F8x8);
    if !ok {
        print("Failed to initialize terminal\n");
        return;
    }
    defer terminal_shutdown(term);

    // Generate dungeon
    dungeon: GenMap;
    seed: u64 = 12345;  // Fixed seed for reproducibility
    generate_dungeon(*dungeon, seed);

    print("Terminal: %x% cells\n", TERM_WIDTH, TERM_HEIGHT);
    print("Dungeon: %x% tiles\n", dungeon.width, dungeon.height);

    // Player position
    player_x: s32 = 0;
    player_y: s32 = 0;

    // Initialize player at first room center
    init_player_position(*dungeon, *player_x, *player_y);

    // Calculate initial lighting and FOV
    calculate_lighting(*dungeon);
    calculate_fov(*dungeon, player_x, player_y);

    // Viewport offset (for scrolling if map is larger than terminal)
    view_x: s32 = 0;
    view_y: s32 = 0;

    // Center viewport on player
    center_viewport_on_player(*view_x, *view_y, player_x, player_y, dungeon.width, dungeon.height);

    // Visibility toggle (V key)
    use_visibility := true;

    print("\nControls:\n");
    print("  WASD / Arrow keys - move player / scroll viewport\n");
    print("  V - toggle visibility (FOV) mode\n");
    print("  R - regenerate dungeon\n");
    print("  S - save screenshot to docs/screenshot.png\n");
    print("  ESC - exit\n\n");

    regenerate := false;

    // Main loop
    while true {
        // Handle input
        Input.update_window_events();

        for Input.get_window_resizes() {
            if it.window == term.window {
                Simp.update_window(it.window);
            }
        }

        for event: Input.events_this_frame {
            if event.type == .QUIT {
                return;
            }

            if event.type == .KEYBOARD && event.key_pressed {
                moved := false;
                new_x := player_x;
                new_y := player_y;

                if event.key_code == {
                    case .ESCAPE;
                        return;

                    // Player movement (WASD)
                    case #char "W";
                        new_y = player_y - 1;
                        moved = true;
                    case #char "S";
                        new_y = player_y + 1;
                        moved = true;
                    case #char "A";
                        new_x = player_x - 1;
                        moved = true;
                    case #char "D";
                        new_x = player_x + 1;
                        moved = true;

                    // Viewport scrolling (arrow keys)
                    case .ARROW_UP;
                        if view_y > 0 view_y -= 1;
                    case .ARROW_DOWN;
                        if view_y < dungeon.height - TERM_HEIGHT view_y += 1;
                    case .ARROW_LEFT;
                        if view_x > 0 view_x -= 1;
                    case .ARROW_RIGHT;
                        if view_x < dungeon.width - TERM_WIDTH view_x += 1;

                    // Toggle visibility
                    case #char "V";
                        use_visibility = !use_visibility;
                        if use_visibility {
                            print("Visibility ON\n");
                        } else {
                            print("Visibility OFF (full map)\n");
                        }

                    case #char "R";
                        regenerate = true;
                    case #char "F";
                        // Save screenshot of full map (moved from S to avoid conflict)
                        save_screenshot(*dungeon);
                }

                // Handle player movement
                if moved {
                    if can_move_to(*dungeon, new_x, new_y) {
                        player_x = new_x;
                        player_y = new_y;
                        // Recalculate FOV after movement
                        calculate_fov(*dungeon, player_x, player_y);
                        // Auto-center viewport on player
                        center_viewport_on_player(*view_x, *view_y, player_x, player_y, dungeon.width, dungeon.height);
                    }
                }
            }
        }

        // Regenerate if requested
        if regenerate {
            seed += 1;
            map_free(*dungeon);
            generate_dungeon(*dungeon, seed);

            // Reset player position
            init_player_position(*dungeon, *player_x, *player_y);

            // Recalculate lighting and FOV
            calculate_lighting(*dungeon);
            calculate_fov(*dungeon, player_x, player_y);

            // Center viewport on player
            center_viewport_on_player(*view_x, *view_y, player_x, player_y, dungeon.width, dungeon.height);

            regenerate = false;
        }

        // Render dungeon to terminal
        render_dungeon_to_terminal(term, *dungeon, view_x, view_y, player_x, player_y, use_visibility);
        terminal_render(term);

        sleep_milliseconds(16);  // ~60 FPS
    }
}

render_dungeon_to_terminal :: (term: *Terminal, m: *GenMap, view_x: s32, view_y: s32,
                                player_x: s32, player_y: s32, use_visibility: bool) {
    terminal_clear(term);

    // Draw visible portion of map
    for ty: 0..TERM_HEIGHT-2 {  // Leave room for status line
        for tx: 0..TERM_WIDTH-1 {
            mx := view_x + cast(s32)tx;
            my := view_y + cast(s32)ty;

            // Use the render module to get proper priority-based rendering
            glyph, fg_ansi, bg_ansi := get_cell_render(m, mx, my, use_visibility);
            fg := ansi_to_color(fg_ansi);
            bg := ansi_to_color(bg_ansi);

            // Draw player at their position
            if mx == player_x && my == player_y {
                glyph = #char "@";
                fg = TC_BRIGHT_WHITE;
            }

            terminal_set(term, cast(s32)tx, cast(s32)ty, glyph, fg, bg);
        }
    }

    // Draw status line
    vis_mode := ifx use_visibility then "FOV" else "ALL";
    status := tprint("D:% @:%,% [WASD:move V:vis(%) R:regen F:screenshot ESC:quit]",
                     m.depth, player_x, player_y, vis_mode);
    for i: 0..min(status.count-1, TERM_WIDTH-1) {
        terminal_set(term, cast(s32)i, TERM_HEIGHT - 1, status[i], TC_BRIGHT_WHITE, Color.{0.2, 0.2, 0.2});
    }
}

// ============================================================================
// Player Movement Helpers
// ============================================================================

// Initialize player at first room center
init_player_position :: (m: *GenMap, px: *s32, py: *s32) {
    if m.rooms.count > 0 {
        cx, cy := rect_center(m.rooms[0].bounds);
        px.* = cx;
        py.* = cy;
    } else {
        // Fallback: find any floor tile
        for y: 0..m.height-1 {
            for x: 0..m.width-1 {
                t := map_get(m, x, y);
                if t == .FLOOR || t == .CORRIDOR {
                    px.* = x;
                    py.* = y;
                    return;
                }
            }
        }
        // Ultimate fallback: center of map
        px.* = m.width / 2;
        py.* = m.height / 2;
    }
}

// Check if player can move to a position
can_move_to :: (m: *GenMap, x: s32, y: s32) -> bool {
    if !map_in_bounds(m, x, y) return false;

    t := map_get(m, x, y);

    // Can move to passable terrain
    if terrain_passable(t) return true;

    // Can also move through water (swimming)
    if t == .WATER return true;

    // Can pass through open doors
    if t == .DOOR_OPEN return true;

    // Can open closed doors (treat as passable for simple demo)
    if t == .DOOR_CLOSED return true;

    return false;
}

// Center viewport on player position
center_viewport_on_player :: (vx: *s32, vy: *s32, px: s32, py: s32, map_w: s32, map_h: s32) {
    // Center viewport on player
    target_vx := px - TERM_WIDTH / 2;
    target_vy := py - TERM_HEIGHT / 2;

    // Clamp to map bounds
    if target_vx < 0 target_vx = 0;
    if target_vy < 0 target_vy = 0;
    if target_vx > map_w - TERM_WIDTH target_vx = map_w - TERM_WIDTH;
    if target_vy > map_h - TERM_HEIGHT target_vy = map_h - TERM_HEIGHT;

    // Ensure non-negative
    if target_vx < 0 target_vx = 0;
    if target_vy < 0 target_vy = 0;

    vx.* = target_vx;
    vy.* = target_vy;
}
