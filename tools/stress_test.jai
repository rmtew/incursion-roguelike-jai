// Stress Test Tool - Headless dungeon generation across many seeds
//
// Generates dungeons across seed ranges, catching crashes and validation
// failures. Optionally tests the free+regenerate cycle (R key flow) and
// validates map invariants after generation.
//
// Usage:
//   stress_test.exe                     # Seeds 1..1000, depth 1
//   stress_test.exe --count 5000        # Seeds 1..5000
//   stress_test.exe --seed 12345        # Single seed reproduction
//   stress_test.exe --regen             # Test free+regenerate cycle
//   stress_test.exe --validate          # Run validator after each generation
//   stress_test.exe --all-depths        # Test depths 1..20 per seed

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

// ============================================================================
// Stress Test Configuration
// ============================================================================

StressConfig :: struct {
    start_seed: u64;
    count: s64;
    single_seed: bool;       // --seed mode: test just one seed
    do_regen: bool;          // --regen: test free+regenerate cycle
    do_validate: bool;       // --validate: run validators after generation
    all_depths: bool;        // --all-depths: test depths 1..20
    max_depth: s32;          // Maximum depth to test (default 20)
    determinism_check: bool; // Check determinism (generate twice, compare hashes)
}

DEFAULT_CONFIG :: StressConfig.{
    start_seed = 1,
    count = 1000,
    single_seed = false,
    do_regen = false,
    do_validate = false,
    all_depths = false,
    max_depth = 20,
    determinism_check = true,
};

// ============================================================================
// Test Results
// ============================================================================

FailureRecord :: struct {
    seed: u64;
    depth: s32;
    phase: string;      // "generate", "validate", "regen", "determinism"
    message: string;
}

MAX_FAILURES :: 256;

StressResults :: struct {
    total_tests: s64;
    passed: s64;
    failed: s64;
    failures: [MAX_FAILURES] FailureRecord;
    failure_count: s32;
    validation_issues_total: s64;
}

add_failure :: (results: *StressResults, seed: u64, depth: s32, phase: string, message: string) {
    results.failed += 1;
    if results.failure_count < MAX_FAILURES {
        f := *results.failures[results.failure_count];
        f.seed = seed;
        f.depth = depth;
        f.phase = phase;
        f.message = message;
        results.failure_count += 1;
    }
}

// ============================================================================
// Core Test Functions
// ============================================================================

// Test generation of a single dungeon at a given seed and depth.
// Returns true if passed.
test_generate :: (config: *StressConfig, results: *StressResults, seed: u64, depth: s32) -> bool {
    gs := New(GameState);
    defer { free_game(gs); free(gs); }

    debug_set_game_state(seed, depth, 0, 0, 0);
    init_game(gs, seed, depth);

    // Validation
    if config.do_validate {
        vr := validate_map(*gs.dungeon, .COMPLETE);
        if vr.issue_count > 0 {
            results.validation_issues_total += vr.issue_count;
            text := format_validation_result(*vr);
            add_failure(results, seed, depth, "validate", tprint("% issue(s)", vr.issue_count));
            return false;
        }
    }

    // Determinism check: generate again with same seed, compare hashes
    if config.determinism_check {
        hash1 := hash_state(gs);

        gs2 := New(GameState);
        defer { free_game(gs2); free(gs2); }
        init_game(gs2, seed, depth);
        hash2 := hash_state(gs2);

        if hash1 != hash2 {
            add_failure(results, seed, depth, "determinism",
                tprint("hash mismatch: % vs %", format_hash(hash1), format_hash(hash2)));
            return false;
        }
    }

    // Regen test: free and regenerate with next seed
    if config.do_regen {
        free_game(gs);
        init_game(gs, seed + 1, depth);

        if config.do_validate {
            vr := validate_map(*gs.dungeon, .COMPLETE);
            if vr.issue_count > 0 {
                results.validation_issues_total += vr.issue_count;
                add_failure(results, seed + 1, depth, "regen-validate",
                    tprint("% issue(s) after regen", vr.issue_count));
                return false;
            }
        }
    }

    return true;
}

// ============================================================================
// Results Writer
// ============================================================================

write_results_file :: (results: *StressResults, config: *StressConfig) {
    builder: String_Builder;

    print_to_builder(*builder, "=== STRESS TEST RESULTS ===\n");
    print_to_builder(*builder, "total: %\n", results.total_tests);
    print_to_builder(*builder, "passed: %\n", results.passed);
    print_to_builder(*builder, "failed: %\n", results.failed);
    if config.do_validate {
        print_to_builder(*builder, "validation_issues_total: %\n", results.validation_issues_total);
    }
    print_to_builder(*builder, "seed_range: %..%\n", config.start_seed, config.start_seed + cast(u64)config.count - 1);
    print_to_builder(*builder, "regen: %\n", config.do_regen);
    print_to_builder(*builder, "validate: %\n", config.do_validate);
    print_to_builder(*builder, "all_depths: %\n", config.all_depths);
    print_to_builder(*builder, "determinism: %\n", config.determinism_check);

    if results.failure_count > 0 {
        print_to_builder(*builder, "\n=== FAILURES ===\n");
        for i: 0..results.failure_count-1 {
            f := results.failures[i];
            print_to_builder(*builder, "seed=% depth=% phase=%: %\n",
                             f.seed, f.depth, f.phase, f.message);
        }
        if results.failed > cast(s64)results.failure_count {
            print_to_builder(*builder, "... and % more failures (truncated)\n",
                             results.failed - cast(s64)results.failure_count);
        }
    }

    print_to_builder(*builder, "\n=== END ===\n");
    text := builder_to_string(*builder);
    write_entire_file("stress-results.txt", text);
}

// ============================================================================
// Argument Parsing
// ============================================================================

parse_int_arg :: (s: string) -> s64 {
    result: s64 = 0;
    for c: s {
        if c >= #char "0" && c <= #char "9" {
            result = result * 10 + cast(s64)(c - #char "0");
        }
    }
    return result;
}

parse_config :: (args: [] string) -> StressConfig, bool {
    config := DEFAULT_CONFIG;
    show_help := false;

    i := 1;
    while i < args.count {
        arg := args[i];
        if arg == "--count" || arg == "-n" {
            if i + 1 < args.count {
                config.count = parse_int_arg(args[i + 1]);
                i += 1;
            }
        } else if arg == "--seed" || arg == "-s" {
            if i + 1 < args.count {
                config.start_seed = cast(u64)parse_int_arg(args[i + 1]);
                config.count = 1;
                config.single_seed = true;
                i += 1;
            }
        } else if arg == "--regen" {
            config.do_regen = true;
        } else if arg == "--validate" {
            config.do_validate = true;
        } else if arg == "--all-depths" {
            config.all_depths = true;
        } else if arg == "--max-depth" {
            if i + 1 < args.count {
                config.max_depth = cast(s32)parse_int_arg(args[i + 1]);
                i += 1;
            }
        } else if arg == "--no-determinism" {
            config.determinism_check = false;
        } else if arg == "--help" || arg == "-h" {
            show_help = true;
        }
        i += 1;
    }

    if show_help {
        print("Usage: stress_test.exe [OPTIONS]\n\n");
        print("Options:\n");
        print("  --count N, -n N       Number of seeds to test (default: 1000)\n");
        print("  --seed N, -s N        Test a single seed\n");
        print("  --regen               Test free+regenerate cycle\n");
        print("  --validate            Run map validators after generation\n");
        print("  --all-depths          Test depths 1..20 per seed\n");
        print("  --max-depth N         Maximum depth (default: 20)\n");
        print("  --no-determinism      Skip determinism check\n");
        print("  --help, -h            Show this help\n");
        return config, false;
    }

    return config, true;
}

// ============================================================================
// Main
// ============================================================================

main :: () {
    debug_init();

    // Suppress dungeon generation messages during stress testing
    makelev_quiet = true;

    args := get_command_line_arguments();
    config, ok := parse_config(args);
    if !ok return;

    // Print configuration
    print("=== Stress Test ===\n");
    if config.single_seed {
        print("Seed: %\n", config.start_seed);
    } else {
        print("Seeds: %..%\n", config.start_seed, config.start_seed + cast(u64)config.count - 1);
    }
    print("Regen: %\n", config.do_regen);
    print("Validate: %\n", config.do_validate);
    print("All depths: %\n", config.all_depths);
    print("Determinism: %\n", config.determinism_check);
    print("\n");

    // Enable validation flag if requested
    if config.do_validate {
        g_debug_validate = true;
    }

    // Initialize resources
    print("Loading resources...\n");
    init_resource_db();

    // Run tests
    results: StressResults;

    max_d: s32 = 1;
    if config.all_depths max_d = config.max_depth;

    for seed_offset: 0..config.count-1 {
        seed := config.start_seed + cast(u64)seed_offset;

        for depth: 1..max_d {
            results.total_tests += 1;

            passed := test_generate(*config, *results, seed, depth);
            if passed {
                results.passed += 1;
            }

            // Progress update every 100 tests
            if results.total_tests % 100 == 0 {
                print("  Progress: %/% tests (%/% passed)\n",
                      results.total_tests,
                      config.count * cast(s64)max_d,
                      results.passed,
                      results.total_tests);
            }
        }
    }

    // Summary
    print("\n=== Results ===\n");
    print("Total: %\n", results.total_tests);
    print("Passed: %\n", results.passed);
    print("Failed: %\n", results.failed);
    if config.do_validate {
        print("Validation issues: %\n", results.validation_issues_total);
    }

    // Print failures
    if results.failure_count > 0 {
        print("\nFailing seeds:\n");
        for i: 0..results.failure_count-1 {
            f := results.failures[i];
            print("  seed=% depth=% [%]: %\n", f.seed, f.depth, f.phase, f.message);
        }
    }

    // Write results file
    write_results_file(*results, *config);
    print("\nResults written to stress-results.txt\n");

    if results.failed > 0 {
        print("\nFAILED\n");
    } else {
        print("\nPASSED\n");
    }
}
