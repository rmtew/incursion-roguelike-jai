// Terminal Window - Glyph-based display using Simp
//
// Renders a grid of colored characters using bitmap fonts.
// Extended glyphs (GLYPH_* constants 256+) are converted to CP437 for font lookup.
//
// Note: Simp and Input are imported by the main file that #loads this.
// Note: glyph_cp437.jai must be loaded before this file.

// Terminal dimensions (in cells)
TERM_WIDTH  :: 80;
TERM_HEIGHT :: 25;

// Font options - dimensions in pixels per glyph
FontSize :: enum {
    F8x8;    // 8x8 pixels per glyph
    F12x16;  // 12x16 pixels per glyph
    F16x12;  // 16x12 pixels per glyph
    F16x16;  // 16x16 pixels per glyph
}

// Get glyph dimensions for a font size
get_font_dimensions :: (size: FontSize) -> s32, s32 {
    if size == {
        case .F8x8;   return 8, 8;
        case .F12x16; return 12, 16;
        case .F16x12; return 16, 12;
        case .F16x16; return 16, 16;
    }
    return 8, 8;
}

// Color definitions (Incursion palette)
Color :: struct {
    r, g, b: float32;
}

// Standard roguelike colors (TC_ prefix to avoid collision with defines.jai)
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

// Bright variants
TC_BRIGHT_WHITE   :: Color.{1.0, 1.0, 1.0};
TC_BRIGHT_RED     :: Color.{1.0, 0.2, 0.2};
TC_BRIGHT_GREEN   :: Color.{0.2, 1.0, 0.2};
TC_BRIGHT_BLUE    :: Color.{0.4, 0.4, 1.0};
TC_BRIGHT_YELLOW  :: Color.{1.0, 1.0, 0.2};
TC_BRIGHT_CYAN    :: Color.{0.2, 1.0, 1.0};
TC_BRIGHT_MAGENTA :: Color.{1.0, 0.2, 1.0};

// A single cell in the terminal
TermCell :: struct {
    char: u16;      // Character code (u16 to support extended glyph codes 256+)
    fg: Color;      // Foreground color
    bg: Color;      // Background color
}

// Terminal state
Terminal :: struct {
    window: *void;
    font_texture: Simp.Texture;
    font_loaded: bool;
    glyph_width: s32;
    glyph_height: s32;
    window_width: s32;
    window_height: s32;
    cells: [TERM_WIDTH * TERM_HEIGHT] TermCell;
    running: bool;
}

terminal_init :: (font_size: FontSize = .F12x16) -> *Terminal, bool {
    term := New(Terminal);

    // Get glyph dimensions
    term.glyph_width, term.glyph_height = get_font_dimensions(font_size);
    term.window_width = TERM_WIDTH * term.glyph_width;
    term.window_height = TERM_HEIGHT * term.glyph_height;

    // Create window
    term.window = create_window(term.window_width, term.window_height, "Incursion");
    if !term.window {
        print("ERROR: Could not create window\n");
        free(term);
        return null, false;
    }

    // Initialize Simp
    Simp.set_render_target(term.window);

    // Load bitmap font
    // Try both relative paths (for running from src/ or project root)
    font_path: string;
    alt_font_path: string;
    if font_size == {
        case .F8x8;   font_path = "fonts/8x8.png";   alt_font_path = "../fonts/8x8.png";
        case .F12x16; font_path = "fonts/12x16.png"; alt_font_path = "../fonts/12x16.png";
        case .F16x12; font_path = "fonts/16x12.png"; alt_font_path = "../fonts/16x12.png";
        case .F16x16; font_path = "fonts/16x16.png"; alt_font_path = "../fonts/16x16.png";
    }

    term.font_loaded = Simp.texture_load_from_file(*term.font_texture, font_path);
    if !term.font_loaded {
        term.font_loaded = Simp.texture_load_from_file(*term.font_texture, alt_font_path);
        if term.font_loaded font_path = alt_font_path;
    }

    if !term.font_loaded {
        print("WARNING: Could not load font '%', text rendering disabled\n", font_path);
    } else {
        print("Loaded font: % (%x% glyphs)\n", font_path, term.glyph_width, term.glyph_height);
    }

    // Initialize cells to empty
    for *cell: term.cells {
        cell.char = #char " ";
        cell.fg = TC_WHITE;
        cell.bg = TC_BLACK;
    }

    term.running = true;
    return term, true;
}

terminal_shutdown :: (term: *Terminal) {
    if term.font_loaded {
        Simp.texture_destroy(*term.font_texture);
    }
    free(term);
}

// Set a cell's content
terminal_set :: (term: *Terminal, x: s32, y: s32, char: u16, fg: Color, bg: Color) {
    if x < 0 || x >= TERM_WIDTH || y < 0 || y >= TERM_HEIGHT return;
    idx := y * TERM_WIDTH + x;
    term.cells[idx].char = char;
    term.cells[idx].fg = fg;
    term.cells[idx].bg = bg;
}

// Clear the terminal
terminal_clear :: (term: *Terminal, bg: Color = TC_BLACK) {
    for *cell: term.cells {
        cell.char = #char " ";
        cell.fg = TC_WHITE;
        cell.bg = bg;
    }
}

// Render the terminal to the window
terminal_render :: (term: *Terminal) {
    Simp.clear_render_target(0.0, 0.0, 0.0, 1.0);

    gw := cast(float32) term.glyph_width;
    gh := cast(float32) term.glyph_height;

    // The font texture is 16x16 glyphs
    // UV coordinates: each glyph is 1/16 of the texture
    uv_step := 1.0 / 16.0;

    // Draw background quads first
    Simp.set_shader_for_color();

    for y: 0..TERM_HEIGHT-1 {
        for x: 0..TERM_WIDTH-1 {
            idx := y * TERM_WIDTH + x;
            cell := term.cells[idx];

            // Calculate pixel position (Simp has origin at bottom-left)
            px0 := cast(float32)(x) * gw;
            py0 := cast(float32)(TERM_HEIGHT - 1 - y) * gh;
            px1 := px0 + gw;
            py1 := py0 + gh;

            // Draw background
            bg_color := Vector4.{cell.bg.r, cell.bg.g, cell.bg.b, 1.0};
            Simp.immediate_quad(px0, py0, px1, py1, bg_color);
        }
    }

    // Draw glyphs if font is loaded
    if term.font_loaded {
        Simp.set_shader_for_images(*term.font_texture);

        for y: 0..TERM_HEIGHT-1 {
            for x: 0..TERM_WIDTH-1 {
                idx := y * TERM_WIDTH + x;
                cell := term.cells[idx];

                if cell.char == #char " " continue;  // Skip spaces

                // Calculate pixel position
                px0 := cast(float32)(x) * gw;
                py0 := cast(float32)(TERM_HEIGHT - 1 - y) * gh;
                px1 := px0 + gw;
                py1 := py0 + gh;

                // Convert extended glyphs (256+) to CP437 codes for font atlas
                cp437_char := glyph_to_cp437(cell.char);

                // Calculate UV coordinates for this glyph
                // Font is arranged in 16x16 grid, CP437 order
                // PNG has row 0 at top, OpenGL has V=0 at bottom, so flip V
                glyph_col := cast(u16)cp437_char % 16;
                glyph_row := cast(u16)cp437_char / 16;

                u0 := cast(float32)(glyph_col) / 16.0;
                u1 := cast(float32)(glyph_col + 1) / 16.0;

                // Flip V: row 0 in PNG is at V=1 in OpenGL
                v_top    := (16.0 - cast(float32)glyph_row) / 16.0;
                v_bottom := (16.0 - cast(float32)glyph_row - 1.0) / 16.0;

                // Draw the glyph with foreground color tint
                fg_color := Vector4.{cell.fg.r, cell.fg.g, cell.fg.b, 1.0};

                // immediate_quad vertices: BL, BR, TR, TL (counter-clockwise)
                // UVs match: bottom gets v_bottom, top gets v_top
                Simp.immediate_quad(
                    .{px0, py0}, .{px1, py0}, .{px1, py1}, .{px0, py1},
                    fg_color,
                    .{u0, v_bottom}, .{u1, v_bottom}, .{u1, v_top}, .{u0, v_top}
                );
            }
        }
    }

    Simp.swap_buffers(term.window);
}

// Process input events, return false if window should close
terminal_update :: (term: *Terminal) -> bool {
    Input.update_window_events();

    for Input.get_window_resizes() {
        if it.window == term.window {
            Simp.update_window(it.window);
        }
    }

    for event: Input.events_this_frame {
        if event.type == .QUIT {
            term.running = false;
            return false;
        }

        if event.type == .KEYBOARD && event.key_pressed {
            if event.key_code == .ESCAPE {
                term.running = false;
                return false;
            }
        }
    }

    return term.running;
}

// Get a text dump of the current terminal state (for Claude inspection)
terminal_dump :: (term: *Terminal) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    for y: 0..TERM_HEIGHT-1 {
        for x: 0..TERM_WIDTH-1 {
            idx := y * TERM_WIDTH + x;
            ch := term.cells[idx].char;
            // Convert extended glyphs to CP437, then output
            cp437 := glyph_to_cp437(ch);
            append(*builder, cp437);
        }
        append(*builder, "\n");
    }

    return builder_to_string(*builder);
}
