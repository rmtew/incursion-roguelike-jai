// Command Log - Write/Read/Parse
//
// Format:
//   SEED 12345
//   VERSION 1
//   DEPTH 1
//   ---
//   TURN 1 MOVE_N
//   TURN 2 MOVE_E
//   TURN 3 WAIT
//   TURN 4 OPEN_DOOR E
//   CHECK pos=6,3 turn=4 hash=00000a83f2c01234
//
// Uses String_Builder for output. Parser uses string splitting.

LOG_VERSION :: 1;

// ============================================================================
// Log Entry Types
// ============================================================================

LogEntryType :: enum {
    ACTION;
    CHECKPOINT;
}

LogEntry :: struct {
    type: LogEntryType;

    // ACTION fields
    turn: s32;
    action: Action;
    dir: Dir;           // For OPEN_DOOR/CLOSE_DOOR

    // CHECKPOINT fields
    check_x: s32;
    check_y: s32;
    check_turn: s32;
    check_hash: u64;
}

// Parsed command log
CommandLog :: struct {
    seed: u64;
    version: s32;
    depth: s32;
    entries: [..] LogEntry;
}

// ============================================================================
// Writing
// ============================================================================

write_log_header :: (builder: *String_Builder, seed: u64, depth: s32) {
    print_to_builder(builder, "SEED %\n", seed);
    print_to_builder(builder, "VERSION %\n", LOG_VERSION);
    print_to_builder(builder, "DEPTH %\n", depth);
    print_to_builder(builder, "---\n");
}

write_log_action :: (builder: *String_Builder, turn: s32, action: Action, dir: Dir = .CENTER) {
    action_str := action_to_string(action);
    if action == .OPEN_DOOR || action == .CLOSE_DOOR {
        dir_str := dir_to_string(dir);
        print_to_builder(builder, "TURN % % %\n", turn, action_str, dir_str);
    } else {
        print_to_builder(builder, "TURN % %\n", turn, action_str);
    }
}

write_log_checkpoint :: (builder: *String_Builder, x: s32, y: s32, turn: s32, hash: u64) {
    print_to_builder(builder, "CHECK pos=%,% turn=% hash=%\n", x, y, turn, format_hash(hash));
}

// ============================================================================
// Parsing
// ============================================================================

parse_command_log :: (text: string) -> CommandLog, bool {
    log: CommandLog;
    log.version = -1;

    in_header := true;
    line_start := 0;

    while line_start < text.count {
        // Find end of line
        line_end := line_start;
        while line_end < text.count && text[line_end] != #char "\n" {
            line_end += 1;
        }

        line: string;
        line.data = text.data + line_start;
        line.count = line_end - line_start;

        // Strip trailing \r
        if line.count > 0 && line[line.count - 1] == #char "\r" {
            line.count -= 1;
        }

        // Skip empty lines
        if line.count > 0 {
            if in_header {
                if log_starts_with(line, "---") {
                    in_header = false;
                } else if log_starts_with(line, "SEED ") {
                    seed_str := advance_past(line, "SEED ");
                    log.seed = string_to_u64(seed_str);
                } else if log_starts_with(line, "VERSION ") {
                    ver_str := advance_past(line, "VERSION ");
                    log.version = string_to_s32(ver_str);
                } else if log_starts_with(line, "DEPTH ") {
                    dep_str := advance_past(line, "DEPTH ");
                    log.depth = string_to_s32(dep_str);
                }
            } else {
                // Body: TURN or CHECK lines
                if log_starts_with(line, "TURN ") {
                    entry: LogEntry;
                    entry.type = .ACTION;
                    ok := parse_turn_line(advance_past(line, "TURN "), *entry);
                    if ok {
                        array_add(*log.entries, entry);
                    }
                } else if log_starts_with(line, "CHECK ") {
                    entry: LogEntry;
                    entry.type = .CHECKPOINT;
                    ok := parse_check_line(advance_past(line, "CHECK "), *entry);
                    if ok {
                        array_add(*log.entries, entry);
                    }
                }
            }
        }

        line_start = line_end + 1;
    }

    success := log.version >= 0 && log.seed != 0;
    return log, success;
}

free_command_log :: (log: *CommandLog) {
    array_free(log.entries);
}

// ============================================================================
// Internal Parsing Helpers
// ============================================================================

// Parse "1 MOVE_N" or "4 OPEN_DOOR E"
parse_turn_line :: (rest: string, entry: *LogEntry) -> bool {
    // Find first space (separates turn number from action)
    space1 := find_char(rest, #char " ");
    if space1 < 0 return false;

    turn_str: string;
    turn_str.data = rest.data;
    turn_str.count = space1;
    entry.turn = string_to_s32(turn_str);

    after_turn: string;
    after_turn.data = rest.data + space1 + 1;
    after_turn.count = rest.count - space1 - 1;

    // Check for direction parameter (second space)
    space2 := find_char(after_turn, #char " ");
    if space2 >= 0 {
        action_str: string;
        action_str.data = after_turn.data;
        action_str.count = space2;

        dir_str: string;
        dir_str.data = after_turn.data + space2 + 1;
        dir_str.count = after_turn.count - space2 - 1;

        action, ok := string_to_action(action_str);
        if !ok return false;
        entry.action = action;

        dir, dir_ok := string_to_dir(dir_str);
        if dir_ok entry.dir = dir;
    } else {
        action, ok := string_to_action(after_turn);
        if !ok return false;
        entry.action = action;
    }

    return true;
}

// Parse "pos=6,3 turn=4 hash=00000a83f2c01234"
parse_check_line :: (rest: string, entry: *LogEntry) -> bool {
    // Simple key=value parsing
    pos := 0;
    while pos < rest.count {
        // Find key
        eq := find_char_from(rest, #char "=", pos);
        if eq < 0 break;

        key: string;
        key.data = rest.data + pos;
        key.count = eq - pos;

        // Find value end (next space or end of string)
        val_start := eq + 1;
        val_end := find_char_from(rest, #char " ", val_start);
        if val_end < 0 val_end = rest.count;

        val: string;
        val.data = rest.data + val_start;
        val.count = val_end - val_start;

        if key == "pos" {
            // Parse "x,y"
            comma := find_char(val, #char ",");
            if comma >= 0 {
                x_str: string;
                x_str.data = val.data;
                x_str.count = comma;

                y_str: string;
                y_str.data = val.data + comma + 1;
                y_str.count = val.count - comma - 1;

                entry.check_x = string_to_s32(x_str);
                entry.check_y = string_to_s32(y_str);
            }
        } else if key == "turn" {
            entry.check_turn = string_to_s32(val);
        } else if key == "hash" {
            entry.check_hash = hex_string_to_u64(val);
        }

        pos = val_end + 1;
    }

    return true;
}

// ============================================================================
// String Helpers
// ============================================================================

log_starts_with :: (s: string, prefix: string) -> bool {
    if s.count < prefix.count return false;
    for i: 0..prefix.count-1 {
        if s[i] != prefix[i] return false;
    }
    return true;
}

advance_past :: (s: string, prefix: string) -> string {
    result: string;
    result.data = s.data + prefix.count;
    result.count = s.count - prefix.count;
    return result;
}

find_char :: (s: string, c: u8) -> s64 {
    for i: 0..s.count-1 {
        if s[i] == c return i;
    }
    return -1;
}

find_char_from :: (s: string, c: u8, start: s64) -> s64 {
    for i: start..s.count-1 {
        if s[i] == c return i;
    }
    return -1;
}

string_to_s32 :: (s: string) -> s32 {
    result: s32 = 0;
    negative := false;
    i: s64 = 0;
    if s.count > 0 && s[0] == #char "-" {
        negative = true;
        i = 1;
    }
    while i < s.count {
        c := s[i];
        if c >= #char "0" && c <= #char "9" {
            result = result * 10 + cast(s32)(c - #char "0");
        } else {
            break;
        }
        i += 1;
    }
    return ifx negative then -result else result;
}

string_to_u64 :: (s: string) -> u64 {
    result: u64 = 0;
    for i: 0..s.count-1 {
        c := s[i];
        if c >= #char "0" && c <= #char "9" {
            result = result * 10 + cast(u64)(c - #char "0");
        } else {
            break;
        }
    }
    return result;
}

hex_string_to_u64 :: (s: string) -> u64 {
    result: u64 = 0;
    for i: 0..s.count-1 {
        c := s[i];
        if c >= #char "0" && c <= #char "9" {
            result = (result << 4) | cast(u64)(c - #char "0");
        } else if c >= #char "a" && c <= #char "f" {
            result = (result << 4) | cast(u64)(c - #char "a" + 10);
        } else if c >= #char "A" && c <= #char "F" {
            result = (result << 4) | cast(u64)(c - #char "A" + 10);
        } else {
            break;
        }
    }
    return result;
}

format_hash :: (h: u64) -> string {
    return tprint("%", formatInt(h, base=16, minimum_digits=16));
}

dir_to_string :: (d: Dir) -> string {
    if d == {
        case .NORTH;     return "N";
        case .SOUTH;     return "S";
        case .EAST;      return "E";
        case .WEST;      return "W";
        case .NORTHEAST; return "NE";
        case .NORTHWEST; return "NW";
        case .SOUTHEAST; return "SE";
        case .SOUTHWEST; return "SW";
    }
    return "";
}

string_to_dir :: (s: string) -> Dir, bool {
    if s == {
        case "N";  return .NORTH, true;
        case "S";  return .SOUTH, true;
        case "E";  return .EAST, true;
        case "W";  return .WEST, true;
        case "NE"; return .NORTHEAST, true;
        case "NW"; return .NORTHWEST, true;
        case "SE"; return .SOUTHEAST, true;
        case "SW"; return .SOUTHWEST, true;
    }
    return .CENTER, false;
}
