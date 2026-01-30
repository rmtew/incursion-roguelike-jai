// Incursion Port - Main Game Entry Point

#import "Basic";
#import "Math";
#import "Random";
#import "File";
#import "Sort";

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
#load "resource/runtime.jai";
#load "resource/bake.jai";

// Load glyph constants (needed by render.jai and makelev.jai)
#load "glyph_cp437.jai";

// Load RNG and dungeon generation
#load "rng.jai";
#load "dungeon/map.jai";
#load "dungeon/terrain_registry.jai";
#load "dungeon/weights.jai";
#load "dungeon/makelev.jai";
#load "dungeon/generator.jai";
#load "dungeon/render.jai";
#load "dungeon/visibility.jai";

// Load game loop
#load "game/state.jai";
#load "game/hash.jai";
#load "game/loop.jai";
#load "game/log.jai";

main :: () {
    print("Incursion Port - %\n", VERSION_STRING);

    init_resource_db();
    db := get_resource_db();
    print("Resources loaded: % monsters, % items, % terrains\n",
          db.monsters.count, db.items.count, db.terrains.count);

    print("Game is not yet playable as a standalone executable.\n");
    print("Use tools/headless.jai or tools/inspect.jai for testing.\n");
}
