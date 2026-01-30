// Replay Frontend
//
// Reads a command log file and replays actions through do_action().
//
// Modes:
//   Default:   Print final hash
//   --verify:  Validate checkpoint hashes
//   --verbose: Print each turn
//
// Usage:
//   jai.exe tools/replay.jai && ./replay.exe headless.log
//   ./replay.exe --verbose headless.log
//   ./replay.exe --verify headless.log

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

main :: () {
    args := get_command_line_arguments();

    // Parse flags
    verbose := false;
    verify := false;
    log_file := "";

    for i: 1..args.count-1 {
        if args[i] == "--verbose" {
            verbose = true;
        } else if args[i] == "--verify" {
            verify = true;
        } else {
            log_file = args[i];
        }
    }

    if log_file.count == 0 {
        print("Usage: replay.exe [--verbose] [--verify] <logfile>\n");
        return;
    }

    // Read log file
    content, ok := read_entire_file(log_file);
    if !ok {
        print("Error: Could not read '%'\n", log_file);
        return;
    }

    // Parse log
    log, parse_ok := parse_command_log(content);
    if !parse_ok {
        print("Error: Failed to parse log file\n");
        return;
    }
    defer free_command_log(*log);

    print("=== Replay ===\n");
    print("Log: %\n", log_file);
    print("Seed: %\n", log.seed);
    print("Depth: %\n", log.depth);
    print("Entries: %\n", log.entries.count);

    // Initialize resources and game
    init_resource_db();

    gs := New(GameState);
    defer { free_game(gs); free(gs); }

    init_game(gs, log.seed, log.depth);
    print("Player start: %,%\n", gs.player_x, gs.player_y);

    if verbose {
        print("\n--- Replaying ---\n");
    }

    // Replay entries
    actions_replayed := 0;
    checkpoints_checked := 0;
    checkpoints_passed := 0;

    for entry: log.entries {
        if entry.type == .ACTION {
            result := do_action(gs, entry.action, entry.dir);
            actions_replayed += 1;

            if verbose {
                action_str := action_to_string(entry.action);
                if result.success {
                    print("Turn %: % -> OK pos=%,%\n",
                          gs.turn, action_str, gs.player_x, gs.player_y);
                } else {
                    reason := ifx result.blocked_reason.count > 0 then result.blocked_reason else "failed";
                    print("Turn %: % -> BLOCKED (%)\n", gs.turn, action_str, reason);
                }
            }
        } else if entry.type == .CHECKPOINT {
            checkpoints_checked += 1;
            current_hash := hash_state(gs);

            if verify {
                pos_match := gs.player_x == entry.check_x && gs.player_y == entry.check_y;
                turn_match := gs.turn == entry.check_turn;
                hash_match := current_hash == entry.check_hash;

                if pos_match && turn_match && hash_match {
                    checkpoints_passed += 1;
                    print("CHECK at turn %: PASS\n", entry.check_turn);
                } else {
                    print("CHECK at turn %: FAIL\n", entry.check_turn);
                    if !pos_match {
                        print("  pos: expected %,% got %,%\n",
                              entry.check_x, entry.check_y, gs.player_x, gs.player_y);
                    }
                    if !turn_match {
                        print("  turn: expected % got %\n", entry.check_turn, gs.turn);
                    }
                    if !hash_match {
                        print("  hash: expected % got %\n",
                              format_hash(entry.check_hash), format_hash(current_hash));
                    }
                }
            }
        }
    }

    // Final output
    final_hash := hash_state(gs);
    print("\n--- Result ---\n");
    print("Actions replayed: %\n", actions_replayed);
    print("Final turn: %\n", gs.turn);
    print("Final position: %,%\n", gs.player_x, gs.player_y);
    print("Final hash: %\n", format_hash(final_hash));

    if verify && checkpoints_checked > 0 {
        print("Checkpoints: %/% passed\n", checkpoints_passed, checkpoints_checked);
        if checkpoints_passed == checkpoints_checked {
            print("REPLAY VERIFIED\n");
        } else {
            print("REPLAY VERIFICATION FAILED\n");
        }
    }

    print("\n=== Done ===\n");
}
