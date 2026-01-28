// Inspect - CLI tool for dungeon inspection and Claude-driven testing
//
// Generates dungeons and provides text-based query interface.
// Designed for programmatic interaction via stdin/stdout.
//
// Usage:
//   inspect.exe                         # Interactive mode
//   inspect.exe --seed 12345            # Start with specific seed
//   inspect.exe --depth 5               # Start at dungeon depth 5
//   inspect.exe --mode ext              # Use extended generator mode
//   inspect.exe --quiet --batch "dump"  # Run command silently and exit
//
// CLI Flags:
//   --seed N, -s N      Set RNG seed (default: 12345)
//   --depth N, -d N     Set dungeon depth (default: 1)
//   --mode MODE, -m     Set generator mode: ext/extended or ori/original
//   --batch CMD, -b     Run single command and exit
//   --quiet, -q         Suppress generation messages (for clean output)
//   --help, -h          Show help
//
// Commands (interactive or batch):
//   dump              ASCII map view
//   dump json         JSON map with terrain strings
//   query X,Y         Get cell contents at coordinates
//   query X,Y json    JSON cell info
//   stats             Summary of dungeon state
//   stats json        JSON statistics
//   rooms             List all rooms with bounds
//   monsters          List monster positions
//   items             List item positions
//   seed [N]          Get/set RNG seed
//   depth [N]         Get/set dungeon depth
//   mode [ext|ori]    Get/set generator mode
//   generate          Regenerate dungeon with current settings
//   help              Show command help
//   quit              Exit

#import "Basic";
Str :: #import "String";
#import "Math";
#import "Random";

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

// RNG and dungeon generation
#load "../src/rng.jai";
#load "../src/dungeon/map.jai";
#load "../src/dungeon/terrain_registry.jai";
#load "../src/dungeon/weights.jai";
#load "../src/dungeon/makelev.jai";
#load "../src/dungeon/generator.jai";

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
            i += 1;
            if i < args.count {
                if args[i] == "ext" || args[i] == "extended" {
                    state.mode = .EXTENDED;
                } else {
                    state.mode = .ORIGINAL;
                }
            }
        } else if arg == "--quiet" || arg == "-q" {
            state.quiet = true;
            makelev_quiet = true;
        } else if arg == "--help" || arg == "-h" {
            print_help();
            return;
        }
        i += 1;
    }

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
            if parts.count < 2 {
                mode_str := ifx state.mode == .EXTENDED then "extended" else "original";
                print("Current mode: %\n", mode_str);
                return;
            }
            if parts[1] == "ext" || parts[1] == "extended" {
                state.mode = .EXTENDED;
                print("Mode set to extended\n");
            } else if parts[1] == "ori" || parts[1] == "original" {
                state.mode = .ORIGINAL;
                print("Mode set to original\n");
            } else {
                print("Invalid mode (use 'ext' or 'ori')\n");
            }

        case "generate"; #through;
        case "gen"; #through;
        case "regen";
            do_generate();
            print("Generated dungeon: seed=% depth=% mode=% rooms=%\n",
                  state.seed, state.depth,
                  ifx state.mode == .EXTENDED then "extended" else "original",
                  state.dungeon.rooms.count);

        case "rooms";
            list_rooms();

        case "monsters";
            list_monsters();

        case "items";
            list_items();

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
  dump          - ASCII map view
  dump json     - JSON map representation
  query X,Y     - Get cell contents at coordinates
  query X,Y json - JSON cell info
  stats         - Summary of dungeon state
  stats json    - JSON statistics
  rooms         - List all rooms
  monsters      - List all monster positions
  items         - List all item positions
  seed [N]      - Get/set RNG seed
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
    terrain := map_get(m, x, y);
    return terrain_glyph(terrain);
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
    print("  \"mode\": \"%\",\n", ifx state.mode == .EXTENDED then "extended" else "original");
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

    if json_mode {
        print("{\n");
        print("  \"x\": %,\n", x);
        print("  \"y\": %,\n", y);
        print("  \"terrain\": \"%\",\n", terrain_name);
        print("  \"glyph\": \"%\",\n", to_string(*terrain_glyph(terrain), 1));
        print("  \"passable\": %,\n", ifx is_passable(terrain) then "true" else "false");
        print("  \"monster\": %,\n", ifx has_monster then "true" else "false");
        print("  \"item\": %,\n", ifx has_item then "true" else "false");
        print("  \"up_stair\": %,\n", ifx has_up_stair then "true" else "false");
        print("  \"down_stair\": %,\n", ifx has_down_stair then "true" else "false");
        print("  \"room_id\": %\n", room_id);
        print("}\n");
    } else {
        print("Location (%,%)\n", x, y);
        print("  Terrain: % ('%')\n", terrain_name, to_string(*terrain_glyph(terrain), 1));
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
        print("  \"mode\": \"%\",\n", ifx state.mode == .EXTENDED then "extended" else "original");
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
        print("Mode: %\n", ifx state.mode == .EXTENDED then "extended" else "original");
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
