// Headless Test Harness
//
// Loads game modules without any GUI/terminal. Initializes a game,
// performs a sequence of actions, prints state and hash, writes a command log.
//
// Usage: jai.exe tools/headless.jai && ./headless.exe
//
// Claude writes test scenarios by modifying the action sequence below,
// compiles, runs, and reads output.

#import "Basic";
#import "Math";
#import "Random";
#import "File";
#import "Sort";

// Core modules
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
#load "../src/dungeon/visibility.jai";

// Glyph conversion
#load "../src/glyph_cp437.jai";

// Game loop
#load "../src/game/state.jai";
#load "../src/game/hash.jai";
#load "../src/game/loop.jai";
#load "../src/game/log.jai";

// Debug infrastructure
#load "../src/debug/crash_handler.jai";
#load "../src/debug/validator.jai";

main :: () {
    debug_init();

    print("=== Headless Test Harness ===\n\n");

    // Initialize resources
    init_resource_db();

    // Initialize game
    SEED :: 42;
    gs := New(GameState);
    defer { free_game(gs); free(gs); }

    init_game(gs, SEED);
    print("Seed: %\n", gs.seed);
    print("Depth: %\n", gs.depth);
    print("Player start: %,%\n", gs.player_x, gs.player_y);
    print("Rooms: %\n", gs.dungeon.rooms.count);
    print("Initial hash: %\n", format_hash(hash_state(gs)));

    // Command log
    log_builder: String_Builder;
    write_log_header(*log_builder, gs.seed, gs.depth);

    // ================================================================
    // Test scenario: move in each cardinal direction, then wait
    // ================================================================
    actions :: Action.[
        .MOVE_N, .MOVE_N, .MOVE_N,
        .MOVE_E, .MOVE_E, .MOVE_E,
        .MOVE_S, .MOVE_S, .MOVE_S,
        .MOVE_W, .MOVE_W, .MOVE_W,
        .WAIT,
    ];

    print("\n--- Actions ---\n");
    for a: actions {
        result := do_action(gs, a);
        action_str := action_to_string(a);

        if result.success {
            print("Turn %: % -> OK pos=%,% hash=%\n",
                  gs.turn, action_str,
                  gs.player_x, gs.player_y,
                  format_hash(hash_state(gs)));
            write_log_action(*log_builder, gs.turn, a);
        } else {
            reason := ifx result.blocked_reason.count > 0 then result.blocked_reason else "failed";
            print("Turn %: % -> BLOCKED (%)\n", gs.turn, action_str, reason);
        }
    }

    // Write checkpoint at end
    final_hash := hash_state(gs);
    write_log_checkpoint(*log_builder, gs.player_x, gs.player_y, gs.turn, final_hash);

    print("\n--- Final State ---\n");
    print("Turn: %\n", gs.turn);
    print("Position: %,%\n", gs.player_x, gs.player_y);
    print("Hash: %\n", format_hash(final_hash));

    // Save log
    log_text := builder_to_string(*log_builder);
    write_entire_file("headless.log", log_text);
    print("\nLog written to headless.log\n");

    // Determinism check: run same seed + actions again
    print("\n--- Determinism Check ---\n");
    gs2 := New(GameState);
    defer { free_game(gs2); free(gs2); }

    init_game(gs2, SEED);
    for a: actions {
        do_action(gs2, a);
    }
    hash2 := hash_state(gs2);
    if final_hash == hash2 {
        print("PASS: Deterministic (hash matches)\n");
    } else {
        print("FAIL: Non-deterministic!\n");
        print("  Run 1: %\n", format_hash(final_hash));
        print("  Run 2: %\n", format_hash(hash2));
    }

    print("\n=== Done ===\n");
}
