// Dungeon Test - Generate and display a dungeon
//
// Creates a dungeon using BSP and renders it in the terminal.

#load "terminal/window.jai";
#load "dungeon/generator.jai";

// Color mapping for terrain
get_terrain_color :: (t: Terrain) -> Color {
    if t == {
        case .ROCK;         return BLACK;
        case .WALL;         return GREY;
        case .FLOOR;        return BROWN;
        case .CORRIDOR;     return Color.{0.4, 0.25, 0.1};  // Darker brown
        case .DOOR_CLOSED;  return YELLOW;
        case .DOOR_OPEN;    return BROWN;
        case .DOOR_SECRET;  return GREY;
        case .STAIRS_UP;    return BRIGHT_WHITE;
        case .STAIRS_DOWN;  return BRIGHT_WHITE;
        case .WATER;        return BRIGHT_BLUE;
        case .CHASM;        return BLACK;
    }
    return WHITE;
}

main :: () {
    print("Incursion Dungeon Test\n");
    print("======================\n\n");

    // Initialize terminal (use smaller font for bigger map)
    term, ok := terminal_init(.F8x8);
    if !ok {
        print("Failed to initialize terminal\n");
        return;
    }
    defer terminal_shutdown(term);

    // Generate dungeon
    dungeon: Map;
    seed: u64 = 12345;  // Fixed seed for reproducibility
    mode := GeneratorMode.ORIGINAL;  // Start in ORIGINAL to test MakeLev rooms
    generate_dungeon(*dungeon, seed, mode);

    print("Terminal: %x% cells\n", TERM_WIDTH, TERM_HEIGHT);
    print("Dungeon: %x% tiles\n", dungeon.width, dungeon.height);

    // Viewport offset (for scrolling if map is larger than terminal)
    view_x: s32 = 0;
    view_y: s32 = 0;

    print("\nControls:\n");
    print("  Arrow keys - scroll viewport\n");
    print("  R - regenerate dungeon\n");
    print("  M - toggle mode (EXTENDED/ORIGINAL)\n");
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
                if event.key_code == {
                    case .ESCAPE;
                        return;
                    case .ARROW_UP;
                        if view_y > 0 view_y -= 1;
                    case .ARROW_DOWN;
                        if view_y < dungeon.height - TERM_HEIGHT view_y += 1;
                    case .ARROW_LEFT;
                        if view_x > 0 view_x -= 1;
                    case .ARROW_RIGHT;
                        if view_x < dungeon.width - TERM_WIDTH view_x += 1;
                    case #char "R";
                        regenerate = true;
                    case #char "M";
                        // Toggle mode
                        if mode == .EXTENDED {
                            mode = .ORIGINAL;
                            print("Switched to ORIGINAL mode\n");
                        } else {
                            mode = .EXTENDED;
                            print("Switched to EXTENDED mode\n");
                        }
                        regenerate = true;
                }
            }
        }

        // Regenerate if requested
        if regenerate {
            seed += 1;
            map_free(*dungeon);
            generate_dungeon(*dungeon, seed, mode);
            view_x = 0;
            view_y = 0;
            regenerate = false;
        }

        // Render dungeon to terminal
        render_dungeon_to_terminal(term, *dungeon, view_x, view_y, mode);
        terminal_render(term);

        sleep_milliseconds(16);  // ~60 FPS
    }
}

render_dungeon_to_terminal :: (term: *Terminal, m: *Map, view_x: s32, view_y: s32, mode: GeneratorMode) {
    terminal_clear(term);

    // Draw visible portion of map
    for ty: 0..TERM_HEIGHT-1 {
        for tx: 0..TERM_WIDTH-1 {
            mx := view_x + cast(s32)tx;
            my := view_y + cast(s32)ty;

            terrain := map_get(m, mx, my);
            glyph := terrain_glyph(terrain);
            fg := get_terrain_color(terrain);
            bg := BLACK;

            // Special background for water/chasm
            if terrain == .WATER {
                bg = BLUE;
            } else if terrain == .CHASM {
                bg = Color.{0.1, 0.1, 0.1};
            }

            terminal_set(term, cast(s32)tx, cast(s32)ty, glyph, fg, bg);
        }
    }

    // Draw status line
    mode_str := ifx mode == .EXTENDED then "EXT" else "ORI";
    status := tprint("Mode:% Rooms:% [Arrows:scroll R:regen M:mode ESC:quit]",
                     mode_str, m.rooms.count);
    for i: 0..min(status.count-1, TERM_WIDTH-1) {
        terminal_set(term, cast(s32)i, TERM_HEIGHT - 1, status[i], BRIGHT_WHITE, Color.{0.2, 0.2, 0.2});
    }
}
