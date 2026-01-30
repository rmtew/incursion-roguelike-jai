// Inspect - CLI tool for dungeon inspection and Claude-driven testing
//
// Generates dungeons and provides text-based query interface.
// Designed for programmatic interaction via stdin/stdout.
//
// Usage:
//   inspect.exe                         # Interactive mode
//   inspect.exe --seed 12345            # Start with specific seed
//   inspect.exe --depth 5               # Start at dungeon depth 5
//   inspect.exe --quiet --batch "dump"  # Run command silently and exit
//
// CLI Flags:
//   --seed N, -s N      Set RNG seed (default: 12345)
//   --depth N, -d N     Set dungeon depth (default: 1)
//   --batch CMD, -b     Run single command and exit
//   --quiet, -q         Suppress generation messages (for clean output)
//   --help, -h          Show help
//
// Commands (interactive or batch):
//   dump              ASCII map view
//   dump json         JSON map with terrain strings
//   query X,Y         Get cell contents at coordinates
//   stats [json]      Dungeon statistics
//   rooms             List all rooms
//   room N            Show details about room N
//   monsters          List monster positions
//   items             List item positions
//   find TYPE         Find terrain (stairs, doors, water, lava, traps, chasm)
//   random TYPE       Get random position (floor, stairs, passable, etc.)
//   path X1,Y1 X2,Y2  Check walkable path exists
//   los X1,Y1 X2,Y2   Check line of sight
//   distance X1,Y1 X2,Y2  Calculate distances (chebyshev, manhattan, euclidean)
//   neighbors X,Y     Show 3x3 grid around a cell
//   area X,Y          Measure connected walkable area
//   rect X1,Y1 X2,Y2  Dump rectangular region
//   fov X,Y [R]       Field of view from point (default radius 8)
//   walk X,Y DIR N    Simulate walking N steps in direction
//   seed [N]          Get/set RNG seed
//   depth [N]         Get/set dungeon depth
//   generate          Regenerate dungeon
//   help              Show commands
//   quit              Exit

#import "Basic";
#import "File";
Str :: #import "String";
#import "Math";
#import "Random";
#import "Sort";

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

// Game state and hash (needed by debug infrastructure)
#load "../src/game/state.jai";
#load "../src/game/hash.jai";

// Debug infrastructure
#load "../src/debug/crash_handler.jai";
#load "../src/debug/validator.jai";

// Glyph to CP437 conversion
#load "../src/glyph_cp437.jai";

// Global state
InspectState :: struct {
    dungeon: GenMap;
    seed: u64 = 12345;
    depth: s32 = 1;
    mode: GeneratorMode = .ORIGINAL;
    generated: bool = false;
    quiet: bool = false;
}

state: InspectState;

main :: () {
    // Parse command line
    args := get_command_line_arguments();
    batch_command: string;

    i := 1;  // Skip program name
    while i < args.count {
        arg := args[i];
        if arg == "--seed" || arg == "-s" {
            i += 1;
            if i < args.count {
                val, ok := Str.parse_int(*args[i]);
                if ok state.seed = cast(u64)val;
            }
        } else if arg == "--batch" || arg == "-b" {
            i += 1;
            if i < args.count {
                batch_command = args[i];
            }
        } else if arg == "--depth" || arg == "-d" {
            i += 1;
            if i < args.count {
                val, ok := Str.parse_int(*args[i]);
                if ok state.depth = cast(s32)val;
            }
        } else if arg == "--mode" || arg == "-m" {
            // Mode option kept for compatibility but only ORIGINAL is supported
            i += 1;
            state.mode = .ORIGINAL;
        } else if arg == "--quiet" || arg == "-q" {
            state.quiet = true;
            makelev_quiet = true;
        } else if arg == "--help" || arg == "-h" {
            print_help();
            return;
        }
        i += 1;
    }

    // Initialize resource database (loads baked terrains and regions)
    init_resource_db();

    // Generate initial dungeon
    do_generate();

    // Batch mode: run single command and exit
    if batch_command.count > 0 {
        if !state.quiet print("---BEGIN OUTPUT---\n");
        execute_command(batch_command);
        if !state.quiet print("---END OUTPUT---\n");
        return;
    }

    // Interactive mode
    print("Incursion Dungeon Inspector\n");
    print("Type 'help' for commands, 'quit' to exit.\n");
    print("> ");

    while true {
        line := read_line();
        if line.count == 0 continue;

        trimmed := Str.trim(line);
        if trimmed.count == 0 {
            print("> ");
            continue;
        }

        if trimmed == "quit" || trimmed == "exit" || trimmed == "q" {
            break;
        }

        execute_command(trimmed);
        print("> ");
    }

    map_free(*state.dungeon);
}

read_line :: () -> string {
    builder: String_Builder;
    builder.allocator = temp;

    while true {
        c: u8;
        bytes_read := read_from_stdin(*c, 1);
        if bytes_read <= 0 break;
        if c == #char "\n" break;
        if c == #char "\r" continue;  // Handle Windows line endings
        append(*builder, c);
    }

    return builder_to_string(*builder);
}

read_from_stdin :: (buffer: *u8, count: s64) -> s64 {
    #if OS == .WINDOWS {
        kernel32 :: #system_library "kernel32";
        GetStdHandle :: (handle: s32) -> *void #foreign kernel32;
        ReadFile :: (file: *void, buffer: *void, to_read: u32, bytes_read: *u32, overlapped: *void) -> s32 #foreign kernel32;

        STD_INPUT_HANDLE :: -10;
        stdin := GetStdHandle(STD_INPUT_HANDLE);
        bytes_read: u32;
        ok := ReadFile(stdin, buffer, cast(u32)count, *bytes_read, null);
        if ok == 0 return -1;
        return cast(s64)bytes_read;
    } else {
        libc :: #system_library "libc";
        read :: (fd: s32, buf: *void, count: u64) -> s64 #foreign libc;
        return read(0, buffer, cast(u64)count);
    }
}

execute_command :: (line: string) {
    parts := Str.split(line, " ");
    if parts.count == 0 return;

    cmd := parts[0];

    if cmd == {
        case "help";
            print_help();

        case "dump";
            json_mode := parts.count > 1 && parts[1] == "json";
            if json_mode {
                dump_json();
            } else {
                dump_ascii();
            }

        case "query";
            if parts.count < 2 {
                print("Usage: query X,Y [json]\n");
                return;
            }
            coords := Str.split(parts[1], ",");
            if coords.count < 2 {
                print("Usage: query X,Y [json]\n");
                return;
            }
            x, ok_x := Str.parse_int(*coords[0]);
            y, ok_y := Str.parse_int(*coords[1]);
            if !ok_x || !ok_y {
                print("Invalid coordinates\n");
                return;
            }
            json_mode := parts.count > 2 && parts[2] == "json";
            query_cell(cast(s32)x, cast(s32)y, json_mode);

        case "stats";
            json_mode := parts.count > 1 && parts[1] == "json";
            print_stats(json_mode);

        case "seed";
            if parts.count < 2 {
                print("Current seed: %\n", state.seed);
                return;
            }
            val, ok := Str.parse_int(*parts[1]);
            if ok {
                state.seed = cast(u64)val;
                print("Seed set to %\n", state.seed);
            } else {
                print("Invalid seed value\n");
            }

        case "depth";
            if parts.count < 2 {
                print("Current depth: %\n", state.depth);
                return;
            }
            val, ok := Str.parse_int(*parts[1]);
            if ok {
                state.depth = cast(s32)val;
                print("Depth set to %\n", state.depth);
            } else {
                print("Invalid depth value\n");
            }

        case "mode";
            // Only ORIGINAL mode is supported
            print("Current mode: original\n");

        case "generate"; #through;
        case "gen"; #through;
        case "regen";
            do_generate();
            print("Generated dungeon: seed=% depth=% rooms=%\n",
                  state.seed, state.depth, state.dungeon.rooms.count);

        case "rooms";
            list_rooms();

        case "monsters";
            list_monsters();

        case "items";
            list_items();

        case "find";
            if parts.count < 2 {
                print("Usage: find <terrain_type>\n");
                print("Types: stairs, doors, water, lava, traps, chasm\n");
                return;
            }
            find_terrain(parts[1]);

        case "path";
            if parts.count < 3 {
                print("Usage: path X1,Y1 X2,Y2\n");
                return;
            }
            c1 := Str.split(parts[1], ",");
            c2 := Str.split(parts[2], ",");
            if c1.count < 2 || c2.count < 2 {
                print("Usage: path X1,Y1 X2,Y2\n");
                return;
            }
            x1, ok1 := Str.parse_int(*c1[0]);
            y1, ok2 := Str.parse_int(*c1[1]);
            x2, ok3 := Str.parse_int(*c2[0]);
            y2, ok4 := Str.parse_int(*c2[1]);
            if !ok1 || !ok2 || !ok3 || !ok4 {
                print("Invalid coordinates\n");
                return;
            }
            check_path(cast(s32)x1, cast(s32)y1, cast(s32)x2, cast(s32)y2);

        case "neighbors";
            if parts.count < 2 {
                print("Usage: neighbors X,Y\n");
                return;
            }
            coords := Str.split(parts[1], ",");
            if coords.count < 2 {
                print("Usage: neighbors X,Y\n");
                return;
            }
            x, ok_x := Str.parse_int(*coords[0]);
            y, ok_y := Str.parse_int(*coords[1]);
            if !ok_x || !ok_y {
                print("Invalid coordinates\n");
                return;
            }
            show_neighbors(cast(s32)x, cast(s32)y);

        case "area";
            if parts.count < 2 {
                print("Usage: area X,Y\n");
                return;
            }
            coords := Str.split(parts[1], ",");
            if coords.count < 2 {
                print("Usage: area X,Y\n");
                return;
            }
            x, ok_x := Str.parse_int(*coords[0]);
            y, ok_y := Str.parse_int(*coords[1]);
            if !ok_x || !ok_y {
                print("Invalid coordinates\n");
                return;
            }
            measure_connected_area(cast(s32)x, cast(s32)y);

        case "rect";
            if parts.count < 3 {
                print("Usage: rect X1,Y1 X2,Y2\n");
                return;
            }
            c1 := Str.split(parts[1], ",");
            c2 := Str.split(parts[2], ",");
            if c1.count < 2 || c2.count < 2 {
                print("Usage: rect X1,Y1 X2,Y2\n");
                return;
            }
            x1, ok1 := Str.parse_int(*c1[0]);
            y1, ok2 := Str.parse_int(*c1[1]);
            x2, ok3 := Str.parse_int(*c2[0]);
            y2, ok4 := Str.parse_int(*c2[1]);
            if !ok1 || !ok2 || !ok3 || !ok4 {
                print("Invalid coordinates\n");
                return;
            }
            dump_rect(cast(s32)x1, cast(s32)y1, cast(s32)x2, cast(s32)y2);

        case "room";
            if parts.count < 2 {
                print("Usage: room N\n");
                return;
            }
            n, ok := Str.parse_int(*parts[1]);
            if !ok {
                print("Invalid room number\n");
                return;
            }
            show_room(cast(s32)n);

        case "los";
            if parts.count < 3 {
                print("Usage: los X1,Y1 X2,Y2\n");
                return;
            }
            c1 := Str.split(parts[1], ",");
            c2 := Str.split(parts[2], ",");
            if c1.count < 2 || c2.count < 2 {
                print("Usage: los X1,Y1 X2,Y2\n");
                return;
            }
            x1, ok1 := Str.parse_int(*c1[0]);
            y1, ok2 := Str.parse_int(*c1[1]);
            x2, ok3 := Str.parse_int(*c2[0]);
            y2, ok4 := Str.parse_int(*c2[1]);
            if !ok1 || !ok2 || !ok3 || !ok4 {
                print("Invalid coordinates\n");
                return;
            }
            check_los(cast(s32)x1, cast(s32)y1, cast(s32)x2, cast(s32)y2);

        case "distance"; #through;
        case "dist";
            if parts.count < 3 {
                print("Usage: distance X1,Y1 X2,Y2\n");
                return;
            }
            c1 := Str.split(parts[1], ",");
            c2 := Str.split(parts[2], ",");
            if c1.count < 2 || c2.count < 2 {
                print("Usage: distance X1,Y1 X2,Y2\n");
                return;
            }
            x1, ok1 := Str.parse_int(*c1[0]);
            y1, ok2 := Str.parse_int(*c1[1]);
            x2, ok3 := Str.parse_int(*c2[0]);
            y2, ok4 := Str.parse_int(*c2[1]);
            if !ok1 || !ok2 || !ok3 || !ok4 {
                print("Invalid coordinates\n");
                return;
            }
            calc_distance(cast(s32)x1, cast(s32)y1, cast(s32)x2, cast(s32)y2);

        case "fov";
            if parts.count < 2 {
                print("Usage: fov X,Y [radius]\n");
                return;
            }
            coords := Str.split(parts[1], ",");
            if coords.count < 2 {
                print("Usage: fov X,Y [radius]\n");
                return;
            }
            x, ok_x := Str.parse_int(*coords[0]);
            y, ok_y := Str.parse_int(*coords[1]);
            if !ok_x || !ok_y {
                print("Invalid coordinates\n");
                return;
            }
            radius: s32 = 8;
            if parts.count > 2 {
                r, ok := Str.parse_int(*parts[2]);
                if ok radius = cast(s32)r;
            }
            show_fov(cast(s32)x, cast(s32)y, radius);

        case "random";
            if parts.count < 2 {
                print("Usage: random <terrain_type>\n");
                return;
            }
            find_random(parts[1]);

        case "walk";
            if parts.count < 4 {
                print("Usage: walk X,Y DIR STEPS\n");
                print("DIR: n, s, e, w, ne, nw, se, sw\n");
                return;
            }
            coords := Str.split(parts[1], ",");
            if coords.count < 2 {
                print("Usage: walk X,Y DIR STEPS\n");
                return;
            }
            x, ok_x := Str.parse_int(*coords[0]);
            y, ok_y := Str.parse_int(*coords[1]);
            steps, ok_s := Str.parse_int(*parts[3]);
            if !ok_x || !ok_y || !ok_s {
                print("Invalid coordinates or steps\n");
                return;
            }
            simulate_walk(cast(s32)x, cast(s32)y, parts[2], cast(s32)steps);

        case "validate";
            validate_dungeon();

        case "shortest";
            if parts.count < 3 {
                print("Usage: shortest X1,Y1 X2,Y2\n");
                return;
            }
            c1 := Str.split(parts[1], ",");
            c2 := Str.split(parts[2], ",");
            if c1.count < 2 || c2.count < 2 {
                print("Usage: shortest X1,Y1 X2,Y2\n");
                return;
            }
            x1, ok1 := Str.parse_int(*c1[0]);
            y1, ok2 := Str.parse_int(*c1[1]);
            x2, ok3 := Str.parse_int(*c2[0]);
            y2, ok4 := Str.parse_int(*c2[1]);
            if !ok1 || !ok2 || !ok3 || !ok4 {
                print("Invalid coordinates\n");
                return;
            }
            find_shortest_path(cast(s32)x1, cast(s32)y1, cast(s32)x2, cast(s32)y2);

        case "bottlenecks";
            find_bottlenecks();

        case "script";
            if parts.count < 2 {
                print("Usage: script FILENAME\n");
                return;
            }
            run_script(parts[1]);

        case "compare";
            if parts.count < 3 {
                print("Usage: compare SEED1 SEED2\n");
                return;
            }
            s1, ok1 := Str.parse_int(*parts[1]);
            s2, ok2 := Str.parse_int(*parts[2]);
            if !ok1 || !ok2 {
                print("Invalid seed values\n");
                return;
            }
            compare_dungeons(cast(u64)s1, cast(u64)s2);

        case "search";
            if parts.count < 2 {
                print("Usage: search CRITERIA\n");
                print("Criteria: empty, monsters, items, water, large, small\n");
                return;
            }
            search_rooms(parts[1]);

        case "export";
            if parts.count < 2 {
                print("Usage: export FILENAME\n");
                return;
            }
            export_state(parts[1]);

        case "heatmap";
            show_heatmap();

        case "density";
            show_density();

        case;
            print("Unknown command: %\n", cmd);
            print("Type 'help' for available commands.\n");
    }
}

do_generate :: () {
    if state.generated {
        map_free(*state.dungeon);
    }
    generate_dungeon(*state.dungeon, state.seed, state.mode, state.depth);
    state.generated = true;
}

print_help :: () {
    help :: #string END
Commands:
  dump            - ASCII map view
  dump json       - JSON map representation
  query X,Y       - Get cell contents at coordinates
  stats           - Dungeon statistics
  rooms           - List all rooms
  room N          - Show details about room N
  monsters        - List monster positions
  items           - List item positions

Spatial queries:
  find TYPE       - Find terrain (stairs, doors, water, lava, traps, chasm)
  random TYPE     - Random position of type (floor, stairs, passable)
  path X1,Y1 X2,Y2   - Check walkable path exists
  shortest X1,Y1 X2,Y2 - Find and show shortest path
  los X1,Y1 X2,Y2   - Check line of sight
  distance X1,Y1 X2,Y2 - Calculate distances
  neighbors X,Y   - Show 3x3 grid around cell
  area X,Y        - Measure connected area
  rect X1,Y1 X2,Y2  - Dump rectangular region
  fov X,Y [R]     - Field of view (default radius 8)
  walk X,Y DIR N  - Simulate N steps in direction

Analysis:
  validate        - Check dungeon validity
  bottlenecks     - Find chokepoint tiles
  heatmap         - Distance from stairs visualization
  density         - Monster/item density per room
  search CRITERIA - Find rooms (empty, monsters, items, water, large, small)
  compare S1 S2   - Compare two seeds

Automation:
  script FILE     - Run commands from file
  export FILE     - Export state to JSON file

Settings:
  seed [N]        - Get/set RNG seed
  depth [N]     - Get/set dungeon depth
  mode [ext|ori] - Get/set generator mode
  generate      - Generate new dungeon
  help          - Show this help
  quit          - Exit
END
    print(help);
}

dump_ascii :: () {
    m := *state.dungeon;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            c := get_cell_char(m, x, y);
            print("%", to_string(*c, 1));
        }
        print("\n");
    }
}

get_cell_char :: (m: *GenMap, x: s32, y: s32) -> u8 {
    // Check for monster first
    for mon: m.monsters {
        if mon.x == x && mon.y == y return #char "M";
    }

    // Check for item
    for item: m.items {
        if item.x == x && item.y == y return #char "*";
    }

    // Return terrain glyph (includes stairs)
    // Convert extended glyphs (256+) to CP437 for ASCII output
    terrain := map_get(m, x, y);
    glyph := terrain_glyph(terrain);
    return glyph_to_cp437(glyph);
}

// Count stairs in the map
count_stairs :: (m: *GenMap) -> up: s32, down: s32 {
    up_count: s32 = 0;
    down_count: s32 = 0;
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            if t == .STAIRS_UP up_count += 1;
            else if t == .STAIRS_DOWN down_count += 1;
        }
    }
    return up_count, down_count;
}

dump_json :: () {
    m := *state.dungeon;
    up_stairs, down_stairs := count_stairs(m);

    print("{\n");
    print("  \"width\": %,\n", m.width);
    print("  \"height\": %,\n", m.height);
    print("  \"depth\": %,\n", m.depth);
    print("  \"seed\": %,\n", state.seed);
    print("  \"mode\": \"%\",\n", "original");
    print("  \"rooms\": %,\n", m.rooms.count);
    print("  \"monsters\": %,\n", m.monsters.count);
    print("  \"items\": %,\n", m.items.count);
    print("  \"up_stairs\": %,\n", up_stairs);
    print("  \"down_stairs\": %,\n", down_stairs);

    // Terrain as array of strings (one per row)
    print("  \"map\": [\n");
    for y: 0..m.height-1 {
        print("    \"");
        for x: 0..m.width-1 {
            c := get_cell_char(m, x, y);
            // Escape special JSON characters
            if c == #char "\"" {
                print("\\\"");
            } else if c == #char "\\" {
                print("\\\\");
            } else {
                print("%", to_string(*c, 1));
            }
        }
        if y < m.height - 1 {
            print("\",\n");
        } else {
            print("\"\n");
        }
    }
    print("  ]\n");
    print("}\n");
}

query_cell :: (x: s32, y: s32, json_mode: bool) {
    m := *state.dungeon;

    if x < 0 || x >= m.width || y < 0 || y >= m.height {
        if json_mode {
            print("{\"error\": \"out of bounds\"}\n");
        } else {
            print("Coordinates out of bounds (map is %x%)\n", m.width, m.height);
        }
        return;
    }

    terrain := map_get(m, x, y);
    terrain_name := terrain_to_string(terrain);

    // Check for entities
    has_monster := false;
    has_item := false;
    has_up_stair := terrain == .STAIRS_UP;
    has_down_stair := terrain == .STAIRS_DOWN;
    room_id: s32 = -1;

    for mon: m.monsters {
        if mon.x == x && mon.y == y { has_monster = true; break; }
    }
    for item: m.items {
        if item.x == x && item.y == y { has_item = true; break; }
    }

    // Find which room this cell is in (if any)
    for room, i: m.rooms {
        if rect_contains(room.bounds, x, y) {
            room_id = cast(s32)i;
            break;
        }
    }

    // Convert glyph to displayable character (extended glyphs -> CP437)
    glyph := terrain_glyph(terrain);
    glyph_char := glyph_to_cp437(glyph);

    if json_mode {
        print("{\n");
        print("  \"x\": %,\n", x);
        print("  \"y\": %,\n", y);
        print("  \"terrain\": \"%\",\n", terrain_name);
        print("  \"glyph\": \"%\",\n", to_string(*glyph_char, 1));
        print("  \"passable\": %,\n", ifx is_passable(terrain) then "true" else "false");
        print("  \"monster\": %,\n", ifx has_monster then "true" else "false");
        print("  \"item\": %,\n", ifx has_item then "true" else "false");
        print("  \"up_stair\": %,\n", ifx has_up_stair then "true" else "false");
        print("  \"down_stair\": %,\n", ifx has_down_stair then "true" else "false");
        print("  \"room_id\": %\n", room_id);
        print("}\n");
    } else {
        print("Location (%,%)\n", x, y);
        print("  Terrain: % ('%')\n", terrain_name, to_string(*glyph_char, 1));
        print("  Passable: %\n", ifx is_passable(terrain) then "yes" else "no");
        if has_monster print("  Monster: yes\n");
        if has_item print("  Item: yes\n");
        if has_up_stair print("  Up stair: yes\n");
        if has_down_stair print("  Down stair: yes\n");
        if room_id >= 0 print("  Room: %\n", room_id);
    }
}

terrain_to_string :: (t: Terrain) -> string {
    if t == {
        case .ROCK;         return "rock";
        case .WALL;         return "wall";
        case .FLOOR;        return "floor";
        case .CORRIDOR;     return "corridor";
        case .DOOR_CLOSED;  return "door_closed";
        case .DOOR_OPEN;    return "door_open";
        case .DOOR_SECRET;  return "door_secret";
        case .STAIRS_UP;    return "stairs_up";
        case .STAIRS_DOWN;  return "stairs_down";
        case .WATER;        return "water";
        case .CHASM;        return "chasm";
        case .LAVA;         return "lava";
        case .TRAP;         return "trap";
        case .TRAP_HIDDEN;  return "trap_hidden";
    }
    return "unknown";
}

is_passable :: (t: Terrain) -> bool {
    return t != .ROCK && t != .WALL && t != .CHASM;
}

print_stats :: (json_mode: bool) {
    m := *state.dungeon;

    // Count terrain types
    floor_count: s32 = 0;
    wall_count: s32 = 0;
    corridor_count: s32 = 0;
    water_count: s32 = 0;
    door_count: s32 = 0;
    trap_count: s32 = 0;
    up_stairs: s32 = 0;
    down_stairs: s32 = 0;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            if t == {
                case .FLOOR;        floor_count += 1;
                case .WALL;         wall_count += 1;
                case .CORRIDOR;     corridor_count += 1;
                case .WATER;        water_count += 1;
                case .DOOR_CLOSED;  door_count += 1;
                case .DOOR_OPEN;    door_count += 1;
                case .DOOR_SECRET;  door_count += 1;
                case .TRAP;         trap_count += 1;
                case .TRAP_HIDDEN;  trap_count += 1;
                case .STAIRS_UP;    up_stairs += 1;
                case .STAIRS_DOWN;  down_stairs += 1;
            }
        }
    }

    if json_mode {
        print("{\n");
        print("  \"seed\": %,\n", state.seed);
        print("  \"depth\": %,\n", state.depth);
        print("  \"mode\": \"%\",\n", "original");
        print("  \"width\": %,\n", m.width);
        print("  \"height\": %,\n", m.height);
        print("  \"rooms\": %,\n", m.rooms.count);
        print("  \"monsters\": %,\n", m.monsters.count);
        print("  \"items\": %,\n", m.items.count);
        print("  \"up_stairs\": %,\n", up_stairs);
        print("  \"down_stairs\": %,\n", down_stairs);
        print("  \"terrain\": {\n");
        print("    \"floor\": %,\n", floor_count);
        print("    \"wall\": %,\n", wall_count);
        print("    \"corridor\": %,\n", corridor_count);
        print("    \"water\": %,\n", water_count);
        print("    \"doors\": %,\n", door_count);
        print("    \"traps\": %\n", trap_count);
        print("  }\n");
        print("}\n");
    } else {
        print("Dungeon Statistics\n");
        print("==================\n");
        print("Seed: %\n", state.seed);
        print("Depth: %\n", state.depth);
        print("Mode: %\n", "original");
        print("Size: %x%\n", m.width, m.height);
        print("Rooms: %\n", m.rooms.count);
        print("Monsters: %\n", m.monsters.count);
        print("Items: %\n", m.items.count);
        print("Up stairs: %\n", up_stairs);
        print("Down stairs: %\n", down_stairs);
        print("\nTerrain counts:\n");
        print("  Floor: %\n", floor_count);
        print("  Wall: %\n", wall_count);
        print("  Corridor: %\n", corridor_count);
        print("  Water: %\n", water_count);
        print("  Doors: %\n", door_count);
        print("  Traps: %\n", trap_count);
    }
}

list_rooms :: () {
    m := *state.dungeon;

    print("Rooms (%)\n", m.rooms.count);
    print("=========\n");
    for room, i: m.rooms {
        w := room.bounds.x2 - room.bounds.x1 + 1;
        h := room.bounds.y2 - room.bounds.y1 + 1;
        print("  [%] at (%,%) size %x%\n", i, room.bounds.x1, room.bounds.y1, w, h);
    }
}

list_monsters :: () {
    m := *state.dungeon;

    print("Monsters (%)\n", m.monsters.count);
    print("============\n");
    for mon, i: m.monsters {
        print("  [%] at (%,%)\n", i, mon.x, mon.y);
    }
}

list_items :: () {
    m := *state.dungeon;

    print("Items (%)\n", m.items.count);
    print("=========\n");
    for item, i: m.items {
        print("  [%] at (%,%)\n", i, item.x, item.y);
    }
}

// Find all instances of a terrain type
find_terrain :: (type_str: string) {
    m := *state.dungeon;

    // Map type string to terrain(s)
    targets: [..] Terrain;
    targets.allocator = temp;

    if type_str == "stairs" {
        array_add(*targets, .STAIRS_UP);
        array_add(*targets, .STAIRS_DOWN);
    } else if type_str == "doors" {
        array_add(*targets, .DOOR_CLOSED);
        array_add(*targets, .DOOR_OPEN);
        array_add(*targets, .DOOR_SECRET);
    } else if type_str == "water" {
        array_add(*targets, .WATER);
    } else if type_str == "lava" {
        array_add(*targets, .LAVA);
    } else if type_str == "traps" {
        array_add(*targets, .TRAP);
        array_add(*targets, .TRAP_HIDDEN);
    } else if type_str == "chasm" {
        array_add(*targets, .CHASM);
    } else if type_str == "floor" {
        array_add(*targets, .FLOOR);
    } else if type_str == "wall" {
        array_add(*targets, .WALL);
    } else if type_str == "corridor" {
        array_add(*targets, .CORRIDOR);
    } else {
        print("Unknown terrain type: %\n", type_str);
        print("Types: stairs, doors, water, lava, traps, chasm, floor, wall, corridor\n");
        return;
    }

    print("Finding: %\n", type_str);
    count := 0;
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            for target: targets {
                if t == target {
                    print("  (%,%) - %\n", x, y, terrain_to_string(t));
                    count += 1;
                    break;
                }
            }
        }
    }
    print("Found % instances\n", count);
}

// Check if a path exists between two points (flood fill)
check_path :: (x1: s32, y1: s32, x2: s32, y2: s32) {
    m := *state.dungeon;

    // Bounds check
    if x1 < 0 || x1 >= m.width || y1 < 0 || y1 >= m.height {
        print("Start point out of bounds\n");
        return;
    }
    if x2 < 0 || x2 >= m.width || y2 < 0 || y2 >= m.height {
        print("End point out of bounds\n");
        return;
    }

    // Check if start/end are passable
    t1 := map_get(m, x1, y1);
    t2 := map_get(m, x2, y2);
    if !is_passable(t1) {
        print("Start point (%,%) is not passable (%)\n", x1, y1, terrain_to_string(t1));
        return;
    }
    if !is_passable(t2) {
        print("End point (%,%) is not passable (%)\n", x2, y2, terrain_to_string(t2));
        return;
    }

    // Flood fill from start to see if we reach end
    visited: [MAP_WIDTH * MAP_HEIGHT] bool;
    stack: [..] struct { x: s32; y: s32; };
    stack.allocator = temp;

    array_add(*stack, .{x1, y1});
    visited[y1 * m.width + x1] = true;

    while stack.count > 0 {
        p := pop(*stack);

        // Check if we reached the target
        if p.x == x2 && p.y == y2 {
            print("Path EXISTS from (%,%) to (%,%)\n", x1, y1, x2, y2);
            return;
        }

        // Check all 8 neighbors
        for dy: -1..1 {
            for dx: -1..1 {
                if dx == 0 && dy == 0 continue;
                nx := p.x + cast(s32)dx;
                ny := p.y + cast(s32)dy;

                if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height continue;

                idx := ny * m.width + nx;
                if visited[idx] continue;

                t := map_get(m, nx, ny);
                if !is_passable(t) continue;

                visited[idx] = true;
                array_add(*stack, .{nx, ny});
            }
        }
    }

    print("NO PATH from (%,%) to (%,%)\n", x1, y1, x2, y2);
}

// Show the 8 neighbors around a cell
show_neighbors :: (x: s32, y: s32) {
    m := *state.dungeon;

    if x < 0 || x >= m.width || y < 0 || y >= m.height {
        print("Coordinates out of bounds\n");
        return;
    }

    print("Neighbors of (%,%):\n", x, y);
    print("  +---+---+---+\n");

    for dy: -1..1 {
        print("  |");
        for dx: -1..1 {
            nx := x + cast(s32)dx;
            ny := y + cast(s32)dy;

            if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height {
                print(" # |");
            } else {
                c := get_cell_char(m, nx, ny);
                if dx == 0 && dy == 0 {
                    print("[%]|", to_string(*c, 1));
                } else {
                    print(" % |", to_string(*c, 1));
                }
            }
        }
        print("\n  +---+---+---+\n");
    }

    // Also list the terrain types
    print("\nDetails:\n");
    for dy: -1..1 {
        for dx: -1..1 {
            nx := x + cast(s32)dx;
            ny := y + cast(s32)dy;
            dir := get_direction_name(cast(s32)dx, cast(s32)dy);

            if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height {
                print("  %: (out of bounds)\n", dir);
            } else {
                t := map_get(m, nx, ny);
                print("  %: % at (%,%)\n", dir, terrain_to_string(t), nx, ny);
            }
        }
    }
}

get_direction_name :: (dx: s32, dy: s32) -> string {
    if dx == 0 && dy == -1 return "N ";
    if dx == 1 && dy == -1 return "NE";
    if dx == 1 && dy == 0  return "E ";
    if dx == 1 && dy == 1  return "SE";
    if dx == 0 && dy == 1  return "S ";
    if dx == -1 && dy == 1 return "SW";
    if dx == -1 && dy == 0 return "W ";
    if dx == -1 && dy == -1 return "NW";
    return "@ ";  // Center
}

// Measure the connected area from a starting point
measure_connected_area :: (x: s32, y: s32) {
    m := *state.dungeon;

    if x < 0 || x >= m.width || y < 0 || y >= m.height {
        print("Coordinates out of bounds\n");
        return;
    }

    t := map_get(m, x, y);
    if !is_passable(t) {
        print("Starting point (%,%) is not passable (%)\n", x, y, terrain_to_string(t));
        return;
    }

    // Flood fill and count
    visited: [MAP_WIDTH * MAP_HEIGHT] bool;
    stack: [..] struct { x: s32; y: s32; };
    stack.allocator = temp;

    array_add(*stack, .{x, y});
    visited[y * m.width + x] = true;

    count := 0;
    min_x := x; max_x := x;
    min_y := y; max_y := y;

    while stack.count > 0 {
        p := pop(*stack);
        count += 1;

        if p.x < min_x min_x = p.x;
        if p.x > max_x max_x = p.x;
        if p.y < min_y min_y = p.y;
        if p.y > max_y max_y = p.y;

        // Check all 8 neighbors
        for dy: -1..1 {
            for dx: -1..1 {
                if dx == 0 && dy == 0 continue;
                nx := p.x + cast(s32)dx;
                ny := p.y + cast(s32)dy;

                if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height continue;

                idx := ny * m.width + nx;
                if visited[idx] continue;

                t := map_get(m, nx, ny);
                if !is_passable(t) continue;

                visited[idx] = true;
                array_add(*stack, .{nx, ny});
            }
        }
    }

    print("Connected area from (%,%):\n", x, y);
    print("  Tiles: %\n", count);
    print("  Bounds: (%,%) to (%,%)\n", min_x, min_y, max_x, max_y);
    print("  Size: %x%\n", max_x - min_x + 1, max_y - min_y + 1);
}

// Dump a rectangular region of the map
dump_rect :: (x1: s32, y1: s32, x2: s32, y2: s32) {
    m := *state.dungeon;

    // Clamp to map bounds
    rx1: s32 = cast(s32) max(0, min(x1, x2));
    ry1: s32 = cast(s32) max(0, min(y1, y2));
    rx2: s32 = cast(s32) min(m.width - 1, max(x1, x2));
    ry2: s32 = cast(s32) min(m.height - 1, max(y1, y2));

    print("Region (%,%) to (%,%):\n", rx1, ry1, rx2, ry2);

    for y: ry1..ry2 {
        for x: rx1..rx2 {
            c := get_cell_char(m, x, y);
            print("%", to_string(*c, 1));
        }
        print("\n");
    }
}

// Show details about a specific room
show_room :: (n: s32) {
    m := *state.dungeon;

    if n < 0 || n >= cast(s32)m.rooms.count {
        print("Invalid room number (0-%)\n", m.rooms.count - 1);
        return;
    }

    room := m.rooms[n];
    x1 := room.bounds.x1;
    y1 := room.bounds.y1;
    x2 := room.bounds.x2;
    y2 := room.bounds.y2;
    w := x2 - x1 + 1;
    h := y2 - y1 + 1;

    print("Room %:\n", n);
    print("  Bounds: (%,%) to (%,%)\n", x1, y1, x2, y2);
    print("  Size: %x% (% tiles)\n", w, h, w * h);
    print("  Connected: %\n", ifx room.connected then "yes" else "no");

    // Count contents
    floor_count: s32 = 0;
    monster_count: s32 = 0;
    item_count: s32 = 0;
    door_count: s32 = 0;

    for y: y1..y2 {
        for x: x1..x2 {
            t := map_get(m, x, y);
            if t == .FLOOR floor_count += 1;
            if t == .DOOR_CLOSED || t == .DOOR_OPEN || t == .DOOR_SECRET door_count += 1;
        }
    }

    for mon: m.monsters {
        if mon.x >= x1 && mon.x <= x2 && mon.y >= y1 && mon.y <= y2 {
            monster_count += 1;
        }
    }

    for item: m.items {
        if item.x >= x1 && item.x <= x2 && item.y >= y1 && item.y <= y2 {
            item_count += 1;
        }
    }

    print("  Floor tiles: %\n", floor_count);
    print("  Doors: %\n", door_count);
    print("  Monsters: %\n", monster_count);
    print("  Items: %\n", item_count);

    // Show the room
    print("\n");
    dump_rect(x1 - 1, y1 - 1, x2 + 1, y2 + 1);
}

// Check line of sight between two points (Bresenham's line)
check_los :: (x1: s32, y1: s32, x2: s32, y2: s32) {
    m := *state.dungeon;

    // Bounds check
    if x1 < 0 || x1 >= m.width || y1 < 0 || y1 >= m.height {
        print("Start point out of bounds\n");
        return;
    }
    if x2 < 0 || x2 >= m.width || y2 < 0 || y2 >= m.height {
        print("End point out of bounds\n");
        return;
    }

    // Bresenham's line algorithm
    dx := abs(x2 - x1);
    dy := abs(y2 - y1);
    sx: s32 = cast(s32) ifx x1 < x2 then 1 else -1;
    sy: s32 = cast(s32) ifx y1 < y2 then 1 else -1;
    err := dx - dy;

    x := x1;
    y := y1;

    path: [..] struct { x: s32; y: s32; };
    path.allocator = temp;

    while true {
        array_add(*path, .{x, y});

        // Check if this tile blocks LOS (skip start and end)
        if (x != x1 || y != y1) && (x != x2 || y != y2) {
            t := map_get(m, x, y);
            if blocks_los(t) {
                print("NO LOS from (%,%) to (%,%)\n", x1, y1, x2, y2);
                print("  Blocked by % at (%,%)\n", terrain_to_string(t), x, y);
                print("  Path: ");
                for p, i: path {
                    if i > 0 print(" -> ");
                    print("(%,%)", p.x, p.y);
                }
                print("\n");
                return;
            }
        }

        if x == x2 && y == y2 break;

        e2 := 2 * err;
        if e2 > -dy {
            err -= dy;
            x += sx;
        }
        if e2 < dx {
            err += dx;
            y += sy;
        }
    }

    print("LOS EXISTS from (%,%) to (%,%)\n", x1, y1, x2, y2);
    print("  Distance: % tiles\n", path.count - 1);
}

blocks_los :: (t: Terrain) -> bool {
    return t == .ROCK || t == .WALL || t == .DOOR_CLOSED || t == .DOOR_SECRET;
}

// Calculate various distances between two points
calc_distance :: (x1: s32, y1: s32, x2: s32, y2: s32) {
    dx := abs(x2 - x1);
    dy := abs(y2 - y1);

    chebyshev := max(dx, dy);
    manhattan := dx + dy;
    euclidean := sqrt(cast(float)(dx * dx + dy * dy));

    print("Distance from (%,%) to (%,%):\n", x1, y1, x2, y2);
    print("  Chebyshev (8-way): %\n", chebyshev);
    print("  Manhattan (4-way): %\n", manhattan);
    print("  Euclidean: %\n", formatFloat(euclidean, trailing_width=2));
}

// Show field of view from a point
show_fov :: (cx: s32, cy: s32, radius: s32) {
    m := *state.dungeon;

    if cx < 0 || cx >= m.width || cy < 0 || cy >= m.height {
        print("Center point out of bounds\n");
        return;
    }

    print("FOV from (%,%) radius %:\n", cx, cy, radius);

    // Simple shadowcasting approximation - just check LOS to each cell
    visible: [MAP_WIDTH * MAP_HEIGHT] bool;

    for dy: -radius..radius {
        for dx: -radius..radius {
            x := cx + cast(s32)dx;
            y := cy + cast(s32)dy;

            if x < 0 || x >= m.width || y < 0 || y >= m.height continue;

            // Check if within radius (Chebyshev)
            if max(abs(cast(s32)dx), abs(cast(s32)dy)) > radius continue;

            // Check LOS using simple ray
            if has_los(m, cx, cy, x, y) {
                visible[y * m.width + x] = true;
            }
        }
    }

    // Display
    y1: s32 = cast(s32) max(0, cy - radius);
    y2: s32 = cast(s32) min(m.height - 1, cy + radius);
    x1: s32 = cast(s32) max(0, cx - radius);
    x2: s32 = cast(s32) min(m.width - 1, cx + radius);

    visible_count := 0;
    for y: y1..y2 {
        for x: x1..x2 {
            idx := y * m.width + x;
            if visible[idx] {
                visible_count += 1;
                if x == cx && y == cy {
                    print("@");
                } else {
                    c := get_cell_char(m, x, y);
                    print("%", to_string(*c, 1));
                }
            } else {
                print(" ");
            }
        }
        print("\n");
    }

    print("\nVisible tiles: %\n", visible_count);
}

// Simple LOS check for FOV
has_los :: (m: *GenMap, x1: s32, y1: s32, x2: s32, y2: s32) -> bool {
    dx := abs(x2 - x1);
    dy := abs(y2 - y1);
    sx: s32 = cast(s32) ifx x1 < x2 then 1 else -1;
    sy: s32 = cast(s32) ifx y1 < y2 then 1 else -1;
    err := dx - dy;

    x := x1;
    y := y1;

    while true {
        if (x != x1 || y != y1) && (x != x2 || y != y2) {
            t := map_get(m, x, y);
            if blocks_los(t) return false;
        }

        if x == x2 && y == y2 return true;

        e2 := 2 * err;
        if e2 > -dy {
            err -= dy;
            x += sx;
        }
        if e2 < dx {
            err += dx;
            y += sy;
        }
    }

    return true;
}

// Find a random position of a terrain type
find_random :: (type_str: string) {
    m := *state.dungeon;

    // Build list of matching positions
    positions: [..] struct { x: s32; y: s32; };
    positions.allocator = temp;

    targets: [..] Terrain;
    targets.allocator = temp;

    if type_str == "floor" {
        array_add(*targets, .FLOOR);
    } else if type_str == "stairs" {
        array_add(*targets, .STAIRS_UP);
        array_add(*targets, .STAIRS_DOWN);
    } else if type_str == "doors" {
        array_add(*targets, .DOOR_CLOSED);
        array_add(*targets, .DOOR_OPEN);
        array_add(*targets, .DOOR_SECRET);
    } else if type_str == "water" {
        array_add(*targets, .WATER);
    } else if type_str == "corridor" {
        array_add(*targets, .CORRIDOR);
    } else if type_str == "passable" {
        array_add(*targets, .FLOOR);
        array_add(*targets, .CORRIDOR);
        array_add(*targets, .DOOR_OPEN);
        array_add(*targets, .STAIRS_UP);
        array_add(*targets, .STAIRS_DOWN);
        array_add(*targets, .WATER);
        array_add(*targets, .TRAP);
        array_add(*targets, .TRAP_HIDDEN);
    } else {
        print("Unknown type: %\n", type_str);
        print("Types: floor, stairs, doors, water, corridor, passable\n");
        return;
    }

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            for target: targets {
                if t == target {
                    array_add(*positions, .{x, y});
                    break;
                }
            }
        }
    }

    if positions.count == 0 {
        print("No % found\n", type_str);
        return;
    }

    // Pick random one using current seed
    idx := cast(s64)(state.seed % cast(u64)positions.count);
    p := positions[idx];
    t := map_get(m, p.x, p.y);

    print("Random %: (%,%) - %\n", type_str, p.x, p.y, terrain_to_string(t));
    print("  (% total %s)\n", positions.count, type_str);
}

// Simulate walking from a point
simulate_walk :: (x: s32, y: s32, dir_str: string, steps: s32) {
    m := *state.dungeon;

    // Parse direction
    dx: s32 = 0;
    dy: s32 = 0;

    if dir_str == "n" || dir_str == "north" { dy = -1; }
    else if dir_str == "s" || dir_str == "south" { dy = 1; }
    else if dir_str == "e" || dir_str == "east" { dx = 1; }
    else if dir_str == "w" || dir_str == "west" { dx = -1; }
    else if dir_str == "ne" { dx = 1; dy = -1; }
    else if dir_str == "nw" { dx = -1; dy = -1; }
    else if dir_str == "se" { dx = 1; dy = 1; }
    else if dir_str == "sw" { dx = -1; dy = 1; }
    else {
        print("Unknown direction: %\n", dir_str);
        print("Use: n, s, e, w, ne, nw, se, sw\n");
        return;
    }

    print("Walking % from (%,%) for % steps:\n", dir_str, x, y, steps);

    cx := x;
    cy := y;

    for i: 0..steps-1 {
        nx := cx + dx;
        ny := cy + dy;

        // Bounds check
        if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height {
            print("  Step %: Hit map boundary at (%,%)\n", i + 1, cx, cy);
            break;
        }

        t := map_get(m, nx, ny);

        if !is_passable(t) {
            print("  Step %: Blocked by % at (%,%)\n", i + 1, terrain_to_string(t), nx, ny);
            break;
        }

        cx = nx;
        cy = ny;
        print("  Step %: (%,%) - %\n", i + 1, cx, cy, terrain_to_string(t));
    }

    print("Final position: (%,%)\n", cx, cy);
}

// ============================================================================
// Advanced Analysis Commands
// ============================================================================

// Validate dungeon structure
validate_dungeon :: () {
    m := *state.dungeon;
    errors: s32 = 0;
    warnings: s32 = 0;

    print("Validating dungeon (seed=%, depth=%)...\n", state.seed, state.depth);

    // Check 1: At least one room
    if m.rooms.count == 0 {
        print("  ERROR: No rooms found\n");
        errors += 1;
    } else {
        print("  OK: % rooms\n", m.rooms.count);
    }

    // Check 2: Stairs exist
    up_count: s32 = 0;
    down_count: s32 = 0;
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            if t == .STAIRS_UP up_count += 1;
            if t == .STAIRS_DOWN down_count += 1;
        }
    }

    if state.depth > 1 && up_count == 0 {
        print("  ERROR: No up stairs (depth > 1)\n");
        errors += 1;
    } else if up_count > 0 {
        print("  OK: % up stairs\n", up_count);
    }

    if down_count == 0 {
        print("  WARNING: No down stairs\n");
        warnings += 1;
    } else {
        print("  OK: % down stairs\n", down_count);
    }

    // Check 3: All passable areas connected
    // Find first passable tile
    start_x: s32 = -1;
    start_y: s32 = -1;
    total_passable: s32 = 0;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            if is_passable(map_get(m, x, y)) {
                total_passable += 1;
                if start_x < 0 {
                    start_x = x;
                    start_y = y;
                }
            }
        }
    }

    if start_x >= 0 {
        // Flood fill from start
        visited: [MAP_WIDTH * MAP_HEIGHT] bool;
        stack: [..] struct { x: s32; y: s32; };
        stack.allocator = temp;

        array_add(*stack, .{start_x, start_y});
        visited[start_y * m.width + start_x] = true;
        reachable: s32 = 0;

        while stack.count > 0 {
            p := pop(*stack);
            reachable += 1;

            for dy: -1..1 {
                for dx: -1..1 {
                    if dx == 0 && dy == 0 continue;
                    nx := p.x + cast(s32)dx;
                    ny := p.y + cast(s32)dy;
                    if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height continue;
                    idx := ny * m.width + nx;
                    if visited[idx] continue;
                    if !is_passable(map_get(m, nx, ny)) continue;
                    visited[idx] = true;
                    array_add(*stack, .{nx, ny});
                }
            }
        }

        if reachable == total_passable {
            print("  OK: All % passable tiles connected\n", total_passable);
        } else {
            print("  ERROR: Only %/% tiles reachable (% isolated)\n",
                  reachable, total_passable, total_passable - reachable);
            errors += 1;
        }
    }

    // Check 4: Stairs are reachable from each other
    if up_count > 0 && down_count > 0 {
        // Find an up stair and down stair
        up_x: s32 = -1; up_y: s32 = -1;
        down_x: s32 = -1; down_y: s32 = -1;

        for y: 0..m.height-1 {
            for x: 0..m.width-1 {
                t := map_get(m, x, y);
                if t == .STAIRS_UP && up_x < 0 { up_x = x; up_y = y; }
                if t == .STAIRS_DOWN && down_x < 0 { down_x = x; down_y = y; }
            }
        }

        if up_x >= 0 && down_x >= 0 {
            // Check path exists (reuse flood fill logic)
            visited: [MAP_WIDTH * MAP_HEIGHT] bool;
            stack: [..] struct { x: s32; y: s32; };
            stack.allocator = temp;

            array_add(*stack, .{up_x, up_y});
            visited[up_y * m.width + up_x] = true;
            found := false;

            while stack.count > 0 && !found {
                p := pop(*stack);
                if p.x == down_x && p.y == down_y {
                    found = true;
                    break;
                }

                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        nx := p.x + cast(s32)dx;
                        ny := p.y + cast(s32)dy;
                        if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height continue;
                        idx := ny * m.width + nx;
                        if visited[idx] continue;
                        if !is_passable(map_get(m, nx, ny)) continue;
                        visited[idx] = true;
                        array_add(*stack, .{nx, ny});
                    }
                }
            }

            if found {
                print("  OK: Stairs are connected\n");
            } else {
                print("  ERROR: Stairs not connected!\n");
                errors += 1;
            }
        }
    }

    // Summary
    print("\nValidation complete: % errors, % warnings\n", errors, warnings);
    if errors == 0 {
        print("VALID\n");
    } else {
        print("INVALID\n");
    }
}

// Find shortest path using BFS
find_shortest_path :: (x1: s32, y1: s32, x2: s32, y2: s32) {
    m := *state.dungeon;

    // Bounds check
    if x1 < 0 || x1 >= m.width || y1 < 0 || y1 >= m.height {
        print("Start point out of bounds\n");
        return;
    }
    if x2 < 0 || x2 >= m.width || y2 < 0 || y2 >= m.height {
        print("End point out of bounds\n");
        return;
    }

    if !is_passable(map_get(m, x1, y1)) {
        print("Start point not passable\n");
        return;
    }
    if !is_passable(map_get(m, x2, y2)) {
        print("End point not passable\n");
        return;
    }

    // BFS with parent tracking
    Parent :: struct { x: s32; y: s32; valid: bool; }
    parents: [MAP_WIDTH * MAP_HEIGHT] Parent;

    Queue_Item :: struct { x: s32; y: s32; }
    queue: [..] Queue_Item;
    queue.allocator = temp;

    array_add(*queue, .{x1, y1});
    parents[y1 * m.width + x1] = .{-1, -1, true};

    found := false;
    head: s64 = 0;

    while head < queue.count {
        p := queue[head];
        head += 1;

        if p.x == x2 && p.y == y2 {
            found = true;
            break;
        }

        // Check 8 neighbors
        for dy: -1..1 {
            for dx: -1..1 {
                if dx == 0 && dy == 0 continue;
                nx := p.x + cast(s32)dx;
                ny := p.y + cast(s32)dy;
                if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height continue;

                idx := ny * m.width + nx;
                if parents[idx].valid continue;
                if !is_passable(map_get(m, nx, ny)) continue;

                parents[idx] = .{p.x, p.y, true};
                array_add(*queue, .{nx, ny});
            }
        }
    }

    if !found {
        print("No path from (%,%) to (%,%)\n", x1, y1, x2, y2);
        return;
    }

    // Reconstruct path
    path: [..] Queue_Item;
    path.allocator = temp;

    cx := x2;
    cy := y2;
    while cx != x1 || cy != y1 {
        array_add(*path, .{cx, cy});
        p := parents[cy * m.width + cx];
        cx = p.x;
        cy = p.y;
    }
    array_add(*path, .{x1, y1});

    // Print path (reversed)
    print("Shortest path from (%,%) to (%,%): % steps\n", x1, y1, x2, y2, path.count - 1);
    print("Path: ");
    for < i: path.count-1..0 {
        p := path[i];
        print("(%,%)", p.x, p.y);
        if i > 0 print(" -> ");
    }
    print("\n");

    // Show on mini-map if path is short enough
    if path.count <= 50 {
        // Find bounds
        min_x := x1; max_x := x1;
        min_y := y1; max_y := y1;
        for p: path {
            if p.x < min_x min_x = p.x;
            if p.x > max_x max_x = p.x;
            if p.y < min_y min_y = p.y;
            if p.y > max_y max_y = p.y;
        }

        // Add margin
        min_x = cast(s32) max(0, min_x - 2);
        min_y = cast(s32) max(0, min_y - 2);
        max_x = cast(s32) min(m.width - 1, max_x + 2);
        max_y = cast(s32) min(m.height - 1, max_y + 2);

        // Mark path tiles
        on_path: [MAP_WIDTH * MAP_HEIGHT] bool;
        for p: path {
            on_path[p.y * m.width + p.x] = true;
        }

        print("\nPath visualization:\n");
        for y: min_y..max_y {
            for x: min_x..max_x {
                if x == x1 && y == y1 {
                    print("S");
                } else if x == x2 && y == y2 {
                    print("E");
                } else if on_path[y * m.width + x] {
                    print("*");
                } else {
                    c := get_cell_char(m, x, y);
                    print("%", to_string(*c, 1));
                }
            }
            print("\n");
        }
    }
}

// Find bottleneck tiles (chokepoints)
find_bottlenecks :: () {
    m := *state.dungeon;

    print("Finding bottlenecks...\n");

    // A bottleneck is a passable tile where removing it would disconnect regions
    // We check each passable tile to see if it's critical

    bottlenecks: [..] struct { x: s32; y: s32; };
    bottlenecks.allocator = temp;

    // First, count total connected area
    total_passable := count_passable(m);

    // For each passable tile, temporarily "remove" it and check connectivity
    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            t := map_get(m, x, y);
            if !is_passable(t) continue;

            // Count passable neighbors
            neighbor_count: s32 = 0;
            for dy: -1..1 {
                for dx: -1..1 {
                    if dx == 0 && dy == 0 continue;
                    nx := x + cast(s32)dx;
                    ny := y + cast(s32)dy;
                    if is_passable(map_get(m, nx, ny)) {
                        neighbor_count += 1;
                    }
                }
            }

            // Only tiles with 2+ neighbors can be bottlenecks
            if neighbor_count < 2 continue;

            // Check if removing this tile disconnects the map
            // Start flood from a neighbor, see if we can reach all other neighbors
            first_neighbor_x: s32 = -1;
            first_neighbor_y: s32 = -1;
            other_neighbors: [..] struct { x: s32; y: s32; };
            other_neighbors.allocator = temp;

            for dy: -1..1 {
                for dx: -1..1 {
                    if dx == 0 && dy == 0 continue;
                    nx := x + cast(s32)dx;
                    ny := y + cast(s32)dy;
                    if is_passable(map_get(m, nx, ny)) {
                        if first_neighbor_x < 0 {
                            first_neighbor_x = nx;
                            first_neighbor_y = ny;
                        } else {
                            array_add(*other_neighbors, .{nx, ny});
                        }
                    }
                }
            }

            if first_neighbor_x < 0 || other_neighbors.count == 0 continue;

            // Flood fill from first neighbor, avoiding the test tile
            visited: [MAP_WIDTH * MAP_HEIGHT] bool;
            stack: [..] struct { x: s32; y: s32; };
            stack.allocator = temp;

            array_add(*stack, .{first_neighbor_x, first_neighbor_y});
            visited[first_neighbor_y * m.width + first_neighbor_x] = true;
            visited[y * m.width + x] = true;  // Block the test tile

            while stack.count > 0 {
                p := pop(*stack);
                for ddy: -1..1 {
                    for ddx: -1..1 {
                        if ddx == 0 && ddy == 0 continue;
                        nnx := p.x + cast(s32)ddx;
                        nny := p.y + cast(s32)ddy;
                        if nnx < 0 || nnx >= m.width || nny < 0 || nny >= m.height continue;
                        idx := nny * m.width + nnx;
                        if visited[idx] continue;
                        if !is_passable(map_get(m, nnx, nny)) continue;
                        visited[idx] = true;
                        array_add(*stack, .{nnx, nny});
                    }
                }
            }

            // Check if all other neighbors were reached
            is_bottleneck := false;
            for n: other_neighbors {
                if !visited[n.y * m.width + n.x] {
                    is_bottleneck = true;
                    break;
                }
            }

            if is_bottleneck {
                array_add(*bottlenecks, .{x, y});
            }

            array_reset(*other_neighbors);
            array_reset(*stack);
        }
    }

    print("Found % bottlenecks:\n", bottlenecks.count);
    for b, i: bottlenecks {
        t := map_get(m, b.x, b.y);
        print("  [%] (%,%) - %\n", i, b.x, b.y, terrain_to_string(t));
    }

    if bottlenecks.count > 0 && bottlenecks.count <= 20 {
        print("\nBottleneck locations marked with 'X':\n");
        // Find bounds
        min_x := bottlenecks[0].x; max_x := bottlenecks[0].x;
        min_y := bottlenecks[0].y; max_y := bottlenecks[0].y;
        for b: bottlenecks {
            if b.x < min_x min_x = b.x;
            if b.x > max_x max_x = b.x;
            if b.y < min_y min_y = b.y;
            if b.y > max_y max_y = b.y;
        }
        min_x = cast(s32) max(0, min_x - 5);
        min_y = cast(s32) max(0, min_y - 5);
        max_x = cast(s32) min(m.width - 1, max_x + 5);
        max_y = cast(s32) min(m.height - 1, max_y + 5);

        is_bottleneck: [MAP_WIDTH * MAP_HEIGHT] bool;
        for b: bottlenecks {
            is_bottleneck[b.y * m.width + b.x] = true;
        }

        for y: min_y..max_y {
            for x: min_x..max_x {
                if is_bottleneck[y * m.width + x] {
                    print("X");
                } else {
                    c := get_cell_char(m, x, y);
                    print("%", to_string(*c, 1));
                }
            }
            print("\n");
        }
    }
}

count_passable :: (m: *GenMap) -> s32 {
    count: s32 = 0;
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            if is_passable(map_get(m, x, y)) count += 1;
        }
    }
    return count;
}

// Run commands from a script file
run_script :: (filename: string) {
    content, ok := read_entire_file(filename);
    if !ok {
        print("Failed to read script file: %\n", filename);
        return;
    }
    defer free(content.data);

    lines := Str.split(content, "\n");
    print("Running script: % (% lines)\n", filename, lines.count);

    for line, i: lines {
        trimmed := Str.trim(line);
        if trimmed.count == 0 continue;
        if trimmed[0] == #char "#" continue;  // Skip comments

        print("[%] > %\n", i + 1, trimmed);
        execute_command(trimmed);
        print("\n");
    }

    print("Script complete.\n");
}

// Compare two dungeons
compare_dungeons :: (seed1: u64, seed2: u64) {
    // Save current state
    saved_seed := state.seed;
    saved_dungeon := state.dungeon;
    saved_generated := state.generated;

    // Generate first dungeon
    d1: GenMap;
    state.seed = seed1;
    state.dungeon = d1;
    state.generated = false;
    do_generate();
    d1 = state.dungeon;

    // Generate second dungeon
    d2: GenMap;
    state.seed = seed2;
    state.dungeon = d2;
    state.generated = false;
    do_generate();
    d2 = state.dungeon;

    print("Comparing seed % vs seed %:\n", seed1, seed2);
    print("=====================================\n");

    // Compare basic stats
    print("\nRooms: % vs %", d1.rooms.count, d2.rooms.count);
    if d1.rooms.count != d2.rooms.count print(" (DIFF)");
    print("\n");

    print("Monsters: % vs %", d1.monsters.count, d2.monsters.count);
    if d1.monsters.count != d2.monsters.count print(" (DIFF)");
    print("\n");

    print("Items: % vs %", d1.items.count, d2.items.count);
    if d1.items.count != d2.items.count print(" (DIFF)");
    print("\n");

    // Count terrain differences
    terrain_diffs: s32 = 0;
    for y: 0..d1.height-1 {
        for x: 0..d1.width-1 {
            t1 := map_get(*d1, x, y);
            t2 := map_get(*d2, x, y);
            if t1 != t2 terrain_diffs += 1;
        }
    }

    pct := cast(float)terrain_diffs / cast(float)(d1.width * d1.height) * 100.0;
    print("Terrain differences: % tiles (% pct)\n", terrain_diffs, formatFloat(pct, trailing_width=1));

    // Count specific terrain types
    print("\nTerrain counts:\n");
    print("           Seed1       Seed2\n");

    floor1, floor2: s32;
    wall1, wall2: s32;
    water1, water2: s32;
    door1, door2: s32;

    for y: 0..d1.height-1 {
        for x: 0..d1.width-1 {
            t := map_get(*d1, x, y);
            if t == .FLOOR floor1 += 1;
            if t == .WALL wall1 += 1;
            if t == .WATER water1 += 1;
            if t == .DOOR_CLOSED || t == .DOOR_OPEN || t == .DOOR_SECRET door1 += 1;

            t = map_get(*d2, x, y);
            if t == .FLOOR floor2 += 1;
            if t == .WALL wall2 += 1;
            if t == .WATER water2 += 1;
            if t == .DOOR_CLOSED || t == .DOOR_OPEN || t == .DOOR_SECRET door2 += 1;
        }
    }

    print("  Floor:   %  vs  %\n", floor1, floor2);
    print("  Wall:    %  vs  %\n", wall1, wall2);
    print("  Water:   %  vs  %\n", water1, water2);
    print("  Doors:   %  vs  %\n", door1, door2);

    // Cleanup
    map_free(*d1);
    map_free(*d2);

    // Restore original state
    state.seed = saved_seed;
    state.dungeon = saved_dungeon;
    state.generated = saved_generated;
}

// Search for rooms matching criteria
search_rooms :: (criteria: string) {
    m := *state.dungeon;

    print("Searching rooms for: %\n", criteria);

    for room, i: m.rooms {
        x1 := room.bounds.x1;
        y1 := room.bounds.y1;
        x2 := room.bounds.x2;
        y2 := room.bounds.y2;
        w := x2 - x1 + 1;
        h := y2 - y1 + 1;
        area := w * h;

        // Count contents
        monster_count: s32 = 0;
        item_count: s32 = 0;
        water_count: s32 = 0;
        floor_count: s32 = 0;

        for mon: m.monsters {
            if mon.x >= x1 && mon.x <= x2 && mon.y >= y1 && mon.y <= y2 {
                monster_count += 1;
            }
        }

        for item: m.items {
            if item.x >= x1 && item.x <= x2 && item.y >= y1 && item.y <= y2 {
                item_count += 1;
            }
        }

        for y: y1..y2 {
            for x: x1..x2 {
                t := map_get(m, x, y);
                if t == .WATER water_count += 1;
                if t == .FLOOR floor_count += 1;
            }
        }

        matches := false;

        if criteria == "empty" {
            matches = monster_count == 0 && item_count == 0;
        } else if criteria == "monsters" {
            matches = monster_count > 0;
        } else if criteria == "items" {
            matches = item_count > 0;
        } else if criteria == "water" {
            matches = water_count > 0;
        } else if criteria == "large" {
            matches = area >= 100;
        } else if criteria == "small" {
            matches = area <= 25;
        } else if criteria == "crowded" {
            matches = monster_count >= 2 || item_count >= 3;
        } else {
            print("Unknown criteria: %\n", criteria);
            print("Valid: empty, monsters, items, water, large, small, crowded\n");
            return;
        }

        if matches {
            print("  Room %: (%,%) %x% - % monsters, % items",
                  i, x1, y1, w, h, monster_count, item_count);
            if water_count > 0 print(", % water", water_count);
            print("\n");
        }
    }
}

// Export full state to JSON file
export_state :: (filename: string) {
    m := *state.dungeon;

    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, "{\n");
    print_to_builder(*builder, "  \"seed\": %,\n", state.seed);
    print_to_builder(*builder, "  \"depth\": %,\n", state.depth);
    print_to_builder(*builder, "  \"mode\": \"%\",\n", "original");
    print_to_builder(*builder, "  \"width\": %,\n", m.width);
    print_to_builder(*builder, "  \"height\": %,\n", m.height);

    // Rooms
    append(*builder, "  \"rooms\": [\n");
    for room, i: m.rooms {
        print_to_builder(*builder, "    {\"x1\": %, \"y1\": %, \"x2\": %, \"y2\": %}",
                         room.bounds.x1, room.bounds.y1, room.bounds.x2, room.bounds.y2);
        if i < m.rooms.count - 1 append(*builder, ",");
        append(*builder, "\n");
    }
    append(*builder, "  ],\n");

    // Monsters
    append(*builder, "  \"monsters\": [\n");
    for mon, i: m.monsters {
        print_to_builder(*builder, "    {\"x\": %, \"y\": %}", mon.x, mon.y);
        if i < m.monsters.count - 1 append(*builder, ",");
        append(*builder, "\n");
    }
    append(*builder, "  ],\n");

    // Items
    append(*builder, "  \"items\": [\n");
    for item, i: m.items {
        print_to_builder(*builder, "    {\"x\": %, \"y\": %}", item.x, item.y);
        if i < m.items.count - 1 append(*builder, ",");
        append(*builder, "\n");
    }
    append(*builder, "  ],\n");

    // Map as array of strings
    append(*builder, "  \"map\": [\n");
    for y: 0..m.height-1 {
        append(*builder, "    \"");
        for x: 0..m.width-1 {
            c := get_cell_char(m, x, y);
            if c == #char "\"" {
                append(*builder, "\\\"");
            } else if c == #char "\\" {
                append(*builder, "\\\\");
            } else {
                append(*builder, c);
            }
        }
        append(*builder, "\"");
        if y < m.height - 1 append(*builder, ",");
        append(*builder, "\n");
    }
    append(*builder, "  ]\n");

    append(*builder, "}\n");

    content := builder_to_string(*builder);
    ok := write_entire_file(filename, content);

    if ok {
        print("Exported to %\n", filename);
    } else {
        print("Failed to write file: %\n", filename);
    }
}

// Show distance heatmap from stairs
show_heatmap :: () {
    m := *state.dungeon;

    // Find all stairs
    stairs: [..] struct { x: s32; y: s32; };
    stairs.allocator = temp;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            if t == .STAIRS_UP || t == .STAIRS_DOWN {
                array_add(*stairs, .{x, y});
            }
        }
    }

    if stairs.count == 0 {
        print("No stairs found\n");
        return;
    }

    // BFS from all stairs to get distance map
    distance: [MAP_WIDTH * MAP_HEIGHT] s32;
    for i: 0..MAP_WIDTH * MAP_HEIGHT - 1 {
        distance[i] = -1;
    }

    Queue_Item :: struct { x: s32; y: s32; }
    queue: [..] Queue_Item;
    queue.allocator = temp;

    for s: stairs {
        distance[s.y * m.width + s.x] = 0;
        array_add(*queue, .{s.x, s.y});
    }

    head: s64 = 0;
    max_dist: s32 = 0;

    while head < queue.count {
        p := queue[head];
        head += 1;
        d := distance[p.y * m.width + p.x];

        for dy: -1..1 {
            for dx: -1..1 {
                if dx == 0 && dy == 0 continue;
                nx := p.x + cast(s32)dx;
                ny := p.y + cast(s32)dy;
                if nx < 0 || nx >= m.width || ny < 0 || ny >= m.height continue;

                idx := ny * m.width + nx;
                if distance[idx] >= 0 continue;
                if !is_passable(map_get(m, nx, ny)) continue;

                distance[idx] = d + 1;
                if d + 1 > max_dist max_dist = d + 1;
                array_add(*queue, .{nx, ny});
            }
        }
    }

    print("Distance heatmap from stairs (max distance: %):\n", max_dist);
    print("Legend: 0-9 = distance, * = far (10+), # = wall, . = unreachable\n\n");

    // Display using digits for distance
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            d := distance[y * m.width + x];

            if t == .STAIRS_UP || t == .STAIRS_DOWN {
                print("@");
            } else if !is_passable(t) {
                print("#");
            } else if d < 0 {
                print(".");
            } else if d < 10 {
                print("%", d);
            } else {
                print("*");
            }
        }
        print("\n");
    }

    // Summary stats
    print("\nDistance distribution:\n");
    buckets: [11] s32;  // 0-9 and 10+
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            d := distance[y * m.width + x];
            if d >= 0 {
                if d >= 10 {
                    buckets[10] += 1;
                } else {
                    buckets[d] += 1;
                }
            }
        }
    }

    for i: 0..9 {
        if buckets[i] > 0 print("  Distance %: % tiles\n", i, buckets[i]);
    }
    if buckets[10] > 0 print("  Distance 10+: % tiles\n", buckets[10]);
}

// Show monster/item density per room
show_density :: () {
    m := *state.dungeon;

    print("Room density analysis:\n");
    print("======================\n\n");

    total_monsters: s32 = 0;
    total_items: s32 = 0;
    total_area: s32 = 0;

    print("Room  Size    Area  Monsters  Items  M/100  I/100\n");
    print("----  ------  ----  --------  -----  -----  -----\n");

    for room, i: m.rooms {
        x1 := room.bounds.x1;
        y1 := room.bounds.y1;
        x2 := room.bounds.x2;
        y2 := room.bounds.y2;
        w := x2 - x1 + 1;
        h := y2 - y1 + 1;
        area := w * h;

        monster_count: s32 = 0;
        item_count: s32 = 0;

        for mon: m.monsters {
            if mon.x >= x1 && mon.x <= x2 && mon.y >= y1 && mon.y <= y2 {
                monster_count += 1;
            }
        }

        for item: m.items {
            if item.x >= x1 && item.x <= x2 && item.y >= y1 && item.y <= y2 {
                item_count += 1;
            }
        }

        m_per_100 := cast(float)monster_count / cast(float)area * 100.0;
        i_per_100 := cast(float)item_count / cast(float)area * 100.0;

        print("%  %x%  %  %  %  %  %\n",
              i, w, h, area, monster_count, item_count,
              formatFloat(m_per_100, trailing_width=1),
              formatFloat(i_per_100, trailing_width=1));

        total_monsters += monster_count;
        total_items += item_count;
        total_area += area;
    }

    print("\n");
    print("Total area: % tiles across % rooms\n", total_area, m.rooms.count);
    m_density := cast(float)total_monsters / cast(float)total_area * 100.0;
    i_density := cast(float)total_items / cast(float)total_area * 100.0;
    print("Total monsters: % (% per 100 tiles)\n", total_monsters, formatFloat(m_density, trailing_width=1));
    print("Total items: % (% per 100 tiles)\n", total_items, formatFloat(i_density, trailing_width=1));

    // Monsters outside rooms
    outside_monsters: s32 = 0;
    for mon: m.monsters {
        in_room := false;
        for room: m.rooms {
            if mon.x >= room.bounds.x1 && mon.x <= room.bounds.x2 &&
               mon.y >= room.bounds.y1 && mon.y <= room.bounds.y2 {
                in_room = true;
                break;
            }
        }
        if !in_room outside_monsters += 1;
    }

    if outside_monsters > 0 {
        print("\nMonsters outside rooms: %\n", outside_monsters);
    }
}
