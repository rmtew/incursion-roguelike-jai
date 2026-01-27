// Incursion Port - Main Entry Point
// Reconstructed from RECONSTRUCTION.md

#import "Basic";
#import "Math";
#import "Random";
#import "File";

// Load core modules
#load "defines.jai";
#load "dice.jai";
#load "object.jai";
#load "map.jai";
#load "creature.jai";
#load "item.jai";
#load "feature.jai";
#load "vision.jai";
#load "registry.jai";
#load "event.jai";
#load "resource.jai";

// Load resource parser
#load "resource/constants.jai";
#load "resource/lexer.jai";
#load "resource/parser.jai";

// Load RNG and dungeon generation
#load "rng.jai";
#load "dungeon/map.jai";
#load "dungeon/weights.jai";
#load "dungeon/makelev.jai";
#load "dungeon/generator.jai";

// Load tests
#load "tests.jai";

main :: () {
    print("Incursion Port - %\n", VERSION_STRING);
    print("Running tests...\n");

    random_seed(cast(u64) 12345);
    run_all_tests();
}
