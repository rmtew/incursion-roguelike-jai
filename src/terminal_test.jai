// Terminal Test - Verify glyph rendering works
//
// Creates a window and displays a simple dungeon-like pattern.

#load "terminal/window.jai";

main :: () {
    print("Incursion Terminal Test\n");
    print("=======================\n\n");

    term, ok := terminal_init();
    if !ok {
        print("Failed to initialize terminal\n");
        return;
    }
    defer terminal_shutdown(term);

    print("Terminal initialized: %x% cells\n", TERM_WIDTH, TERM_HEIGHT);

    // Draw a simple dungeon room
    draw_test_dungeon(term);

    print("\nPress ESC to exit...\n");

    // Main loop
    while terminal_update(term) {
        terminal_render(term);
        sleep_milliseconds(16);  // ~60 FPS
    }

    // Dump final state
    print("\nFinal terminal state:\n");
    print("%\n", terminal_dump(term));
}

draw_test_dungeon :: (term: *Terminal) {
    terminal_clear(term);

    // Draw a room with walls
    room_x :: 10;
    room_y :: 5;
    room_w :: 20;
    room_h :: 10;

    // Walls
    for x: room_x..room_x+room_w {
        terminal_set(term, cast(s32)x, room_y, #char "#", GREY, BLACK);
        terminal_set(term, cast(s32)x, room_y + room_h, #char "#", GREY, BLACK);
    }
    for y: room_y..room_y+room_h {
        terminal_set(term, room_x, cast(s32)y, #char "#", GREY, BLACK);
        terminal_set(term, room_x + room_w, cast(s32)y, #char "#", GREY, BLACK);
    }

    // Floor
    for y: room_y+1..room_y+room_h-1 {
        for x: room_x+1..room_x+room_w-1 {
            terminal_set(term, cast(s32)x, cast(s32)y, #char ".", BROWN, BLACK);
        }
    }

    // Door
    terminal_set(term, room_x + room_w/2, room_y, #char "+", BROWN, BLACK);

    // Player
    terminal_set(term, room_x + room_w/2, room_y + room_h/2, #char "@", BRIGHT_WHITE, BLACK);

    // Some monsters
    terminal_set(term, room_x + 3, room_y + 3, #char "g", BRIGHT_GREEN, BLACK);  // goblin
    terminal_set(term, room_x + room_w - 3, room_y + 3, #char "o", BRIGHT_RED, BLACK);  // orc
    terminal_set(term, room_x + 5, room_y + room_h - 2, #char "r", GREY, BLACK);  // rat

    // Some items
    terminal_set(term, room_x + 2, room_y + room_h - 2, #char "!", BRIGHT_BLUE, BLACK);  // potion
    terminal_set(term, room_x + room_w - 2, room_y + room_h - 2, #char ")", BRIGHT_CYAN, BLACK);  // weapon

    // Corridor leading out
    for y: 1..room_y-1 {
        terminal_set(term, room_x + room_w/2, cast(s32)y, #char "#", GREY, BLACK);
        terminal_set(term, room_x + room_w/2 + 1, cast(s32)y, #char ".", BROWN, BLACK);
        terminal_set(term, room_x + room_w/2 + 2, cast(s32)y, #char "#", GREY, BLACK);
    }

    // Title
    title := "Incursion Port - Terminal Test";
    for i: 0..title.count-1 {
        terminal_set(term, cast(s32)i + 2, 0, title[i], BRIGHT_YELLOW, BLACK);
    }

    // Status line
    status := "HP: 42/42  MP: 15/20  Depth: 1";
    for i: 0..status.count-1 {
        terminal_set(term, cast(s32)i + 2, TERM_HEIGHT - 1, status[i], WHITE, BLACK);
    }
}
