// Crash Handler - Structured crash reporting for debug diagnosis
//
// Provides a global DebugContext struct that is written at safe checkpoints
// during dungeon generation. On crash, writes everything to crash-report.txt
// and a minidump to crash-dumps/.
//
// Usage:
//   debug_init();                          // Install handlers at startup
//   debug_set_gen_step(.DRAW_PANELS, "panel 2,1");  // Called at each step
//   debug_set_game_state(gs);              // Called after init_game / do_action
//
// Near-zero cost: each breadcrumb is a single global struct write.

#import "Windows";

// ============================================================================
// Generation Step Enum
// ============================================================================

GenStep :: enum u8 {
    NONE;
    INIT;               // Step 1: Fill with rock, edges with mapedge
    STREAMERS;          // Step 2: Place streamers (rivers, chasms)
    CHASM_PROPAGATION;  // Step 2b: Multi-level chasm propagation
    DUNGEON_SPECIALS;   // Step 3: Place dungeon specials
    VAULTS;             // Step 3b: Place vaults
    DRAW_PANELS;        // Step 4: Draw each panel
    CONNECT_PANELS;     // Step 5: Connect panels with corridors
    FIXUP_TUNNELING;    // Step 5.5: Ensure all regions connected
    FURNISH_ROOMS;      // Step 5.6: Pillars, rubble, etc.
    PLACE_LIGHTS;       // Step 5.7: Torches and lighting
    DEEP_TERRAIN;       // Step 5.8: Convert shallow to deep terrain
    PLACE_DOORS;        // Step 6: Place doors
    VALIDATE_DOORS;     // Step 6a: Validate door placement
    PLACE_TRAPS;        // Step 6b: Place traps
    TREASURE_DEPOSITS;  // Step 6c: Place treasure deposits
    PLACE_STAIRS;       // Step 7: Place stairs
    DESECRET_STAIRS;    // Step 7b: Remove secret doors near stairs
    POPULATE;           // Step 8: Monsters and items
    SKYLIGHTS;          // Step 9: Skylight marking
    COMPLETE;           // Generation finished
}

gen_step_name :: (step: GenStep) -> string {
    if step == {
        case .NONE;               return "NONE";
        case .INIT;               return "INIT";
        case .STREAMERS;          return "STREAMERS";
        case .CHASM_PROPAGATION;  return "CHASM_PROPAGATION";
        case .DUNGEON_SPECIALS;   return "DUNGEON_SPECIALS";
        case .VAULTS;             return "VAULTS";
        case .DRAW_PANELS;        return "DRAW_PANELS";
        case .CONNECT_PANELS;     return "CONNECT_PANELS";
        case .FIXUP_TUNNELING;    return "FIXUP_TUNNELING";
        case .FURNISH_ROOMS;      return "FURNISH_ROOMS";
        case .PLACE_LIGHTS;       return "PLACE_LIGHTS";
        case .DEEP_TERRAIN;       return "DEEP_TERRAIN";
        case .PLACE_DOORS;        return "PLACE_DOORS";
        case .VALIDATE_DOORS;     return "VALIDATE_DOORS";
        case .PLACE_TRAPS;        return "PLACE_TRAPS";
        case .TREASURE_DEPOSITS;  return "TREASURE_DEPOSITS";
        case .PLACE_STAIRS;       return "PLACE_STAIRS";
        case .DESECRET_STAIRS;    return "DESECRET_STAIRS";
        case .POPULATE;           return "POPULATE";
        case .SKYLIGHTS;          return "SKYLIGHTS";
        case .COMPLETE;           return "COMPLETE";
    }
    return "UNKNOWN";
}

// ============================================================================
// Debug Context (global breadcrumb struct)
// ============================================================================

DebugContext :: struct {
    // Game identity
    seed: u64;
    depth: s32;
    turn: s32;
    player_x: s32;
    player_y: s32;

    // Generation progress
    gen_step: GenStep;
    gen_step_detail: [128] u8;  // Freeform detail string (fixed buffer)
    gen_step_detail_len: s32;

    // Map state hash at last checkpoint
    map_hash: u64;

    // Current room being processed
    current_room_index: s32;
    current_room_bounds: Rect;
    has_current_room: bool;

    // RNG state for reproduction
    rng_mti: s32;
    rng_calls: s64;

    // Handler installed flag
    initialized: bool;
}

// Global debug context
g_debug_context: DebugContext;

// Global flag: run validators after each generation step (off by default)
g_debug_validate := false;


// ============================================================================
// Breadcrumb Functions
// ============================================================================

// Set the current generation step and optional detail string.
// Called at each step in generate_makelev().
debug_set_gen_step :: (step: GenStep, detail: string = "") {
    g_debug_context.gen_step = step;
    g_debug_context.gen_step_detail_len = 0;

    // Copy detail into fixed buffer (truncate if needed)
    copy_len := min(detail.count, 127);
    for i: 0..cast(s32)copy_len-1 {
        g_debug_context.gen_step_detail[i] = detail[i];
    }
    g_debug_context.gen_step_detail_len = cast(s32)copy_len;

    // Snapshot RNG state
    g_debug_context.rng_mti = global_mt.mti;
    g_debug_context.rng_calls = global_rng_call_count;
}

// Set game state fields (called after init_game / free_game / do_action).
debug_set_game_state :: (seed: u64, depth: s32, turn: s32, px: s32, py: s32) {
    g_debug_context.seed = seed;
    g_debug_context.depth = depth;
    g_debug_context.turn = turn;
    g_debug_context.player_x = px;
    g_debug_context.player_y = py;
}

// Set current room being processed (for debugging room-specific crashes).
debug_set_current_room :: (index: s32, bounds: Rect) {
    g_debug_context.current_room_index = index;
    g_debug_context.current_room_bounds = bounds;
    g_debug_context.has_current_room = true;
}

// Clear current room (done processing).
debug_clear_current_room :: () {
    g_debug_context.has_current_room = false;
}

// Set map hash checkpoint.
debug_set_map_hash :: (h: u64) {
    g_debug_context.map_hash = h;
}

// ============================================================================
// Map Hash (standalone, doesn't need GameState)
// ============================================================================

// Hash just the tile data of a GenMap (for crash report / validation)
debug_hash_map :: (m: *GenMap) -> u64 {
    h := fnv1a_init();
    tile_count := m.width * m.height;
    for i: 0..tile_count-1 {
        h = fnv1a_byte(h, cast(u8) m.tiles[i]);
    }
    return h;
}

// ============================================================================
// Crash Report Writer
// ============================================================================

// Format a u64 as a 16-digit hex string (standalone, no dependency on game/log.jai)
debug_format_hex :: (v: u64) -> string {
    return tprint("%", formatInt(v, base=16, minimum_digits=16));
}

// Write a crash report to crash-report.txt.
// Uses tprint for formatting (temp allocator, safe from signal handler context
// since Jai's temp allocator uses a pre-allocated arena).
write_crash_report :: (message: string = "Unknown crash") {
    ctx := *g_debug_context;

    // Build the detail string from the fixed buffer
    detail_str: string;
    detail_str.data = ctx.gen_step_detail.data;
    detail_str.count = ctx.gen_step_detail_len;

    // Build report using tprint (temp allocator - pre-allocated, safe)
    report := tprint(#string END
=== CRASH REPORT ===
message: %
seed: %
depth: %
turn: %
player_x: %
player_y: %
map_hash: %
gen_step: %
gen_step_detail: %
rng_mti: %
rng_calls: %
current_room_index: %
current_room_bounds: %,%,%,%
has_current_room: %
=== END ===
END,
        message,
        ctx.seed,
        ctx.depth,
        ctx.turn,
        ctx.player_x,
        ctx.player_y,
        debug_format_hex(ctx.map_hash),
        gen_step_name(ctx.gen_step),
        detail_str,
        ctx.rng_mti,
        ctx.rng_calls,
        ctx.current_room_index,
        ctx.current_room_bounds.x1, ctx.current_room_bounds.y1,
        ctx.current_room_bounds.x2, ctx.current_room_bounds.y2,
        ctx.has_current_room
    );

    write_entire_file("crash-report.txt", report);
}

// ============================================================================
// Re-entry Guard
// ============================================================================

// Prevents double-fault when the crash IS allocator corruption.
// If the SEH handler itself faults, the re-entry check bails out immediately.
g_seh_in_progress := false;

// ============================================================================
// Allocator-Free Formatting Helpers
// ============================================================================

// These format directly into a fixed buffer with bounds checking.
// No allocator calls — safe to use from the SEH exception filter.

seh_append_str :: (buf: *[2048] u8, pos: *s32, s: string) #c_call {
    i: s32 = 0;
    while i < cast(s32) s.count {
        if pos.* >= 2048  return;
        buf.*[pos.*] = s.data[i];
        pos.* += 1;
        i += 1;
    }
}

seh_append_u64 :: (buf: *[2048] u8, pos: *s32, value: u64) #c_call {
    if value == 0 {
        seh_append_str(buf, pos, "0");
        return;
    }
    // Max u64 is 20 digits
    digits: [20] u8;
    count: s32 = 0;
    v := value;
    while v > 0 {
        digits[count] = cast(u8) (v % 10) + #char "0";
        count += 1;
        v /= 10;
    }
    // Reverse into buffer
    i := count - 1;
    while i >= 0 {
        if pos.* >= 2048  return;
        buf.*[pos.*] = digits[i];
        pos.* += 1;
        i -= 1;
    }
}

seh_append_s32 :: (buf: *[2048] u8, pos: *s32, value: s32) #c_call {
    if value < 0 {
        seh_append_str(buf, pos, "-");
        seh_append_u64(buf, pos, cast(u64) cast(s64) (-value));
    } else {
        seh_append_u64(buf, pos, cast(u64) value);
    }
}

seh_append_hex :: (buf: *[2048] u8, pos: *s32, value: u64, num_digits: s32) #c_call {
    HEX :: "0123456789abcdef";
    i := num_digits - 1;
    while i >= 0 {
        if pos.* >= 2048  return;
        nibble := (value >> (cast(u64) i * 4)) & 0xF;
        buf.*[pos.*] = HEX[nibble];
        pos.* += 1;
        i -= 1;
    }
}

seh_append_bool :: (buf: *[2048] u8, pos: *s32, value: bool) #c_call {
    if value  seh_append_str(buf, pos, "true");
    else      seh_append_str(buf, pos, "false");
}

seh_append_gen_step :: (buf: *[2048] u8, pos: *s32, step: GenStep) #c_call {
    if step == {
        case .NONE;               seh_append_str(buf, pos, "NONE");
        case .INIT;               seh_append_str(buf, pos, "INIT");
        case .STREAMERS;          seh_append_str(buf, pos, "STREAMERS");
        case .CHASM_PROPAGATION;  seh_append_str(buf, pos, "CHASM_PROPAGATION");
        case .DUNGEON_SPECIALS;   seh_append_str(buf, pos, "DUNGEON_SPECIALS");
        case .VAULTS;             seh_append_str(buf, pos, "VAULTS");
        case .DRAW_PANELS;        seh_append_str(buf, pos, "DRAW_PANELS");
        case .CONNECT_PANELS;     seh_append_str(buf, pos, "CONNECT_PANELS");
        case .FIXUP_TUNNELING;    seh_append_str(buf, pos, "FIXUP_TUNNELING");
        case .FURNISH_ROOMS;      seh_append_str(buf, pos, "FURNISH_ROOMS");
        case .PLACE_LIGHTS;       seh_append_str(buf, pos, "PLACE_LIGHTS");
        case .DEEP_TERRAIN;       seh_append_str(buf, pos, "DEEP_TERRAIN");
        case .PLACE_DOORS;        seh_append_str(buf, pos, "PLACE_DOORS");
        case .VALIDATE_DOORS;     seh_append_str(buf, pos, "VALIDATE_DOORS");
        case .PLACE_TRAPS;        seh_append_str(buf, pos, "PLACE_TRAPS");
        case .TREASURE_DEPOSITS;  seh_append_str(buf, pos, "TREASURE_DEPOSITS");
        case .PLACE_STAIRS;       seh_append_str(buf, pos, "PLACE_STAIRS");
        case .DESECRET_STAIRS;    seh_append_str(buf, pos, "DESECRET_STAIRS");
        case .POPULATE;           seh_append_str(buf, pos, "POPULATE");
        case .SKYLIGHTS;          seh_append_str(buf, pos, "SKYLIGHTS");
        case .COMPLETE;           seh_append_str(buf, pos, "COMPLETE");
        case;                     seh_append_str(buf, pos, "UNKNOWN");
    }
}

// ============================================================================
// Minidump Support
// ============================================================================

// Write a minidump to crash-dumps/ directory.
// Can be called with exception_pointers (from SEH handler) or without (on-demand).
// Uses only Win32 APIs and stack/global data — safe from exception filter context.
debug_write_minidump :: (exception_pointers: *EXCEPTION_POINTERS = null) -> bool {
    // Ensure crash-dumps directory exists (ignore error if already exists)
    CreateDirectoryA("crash-dumps".data, null);

    // Build filename with context: crash-dumps/crash-seed{seed}-depth{depth}.dmp
    ctx := *g_debug_context;
    filename := tprint("crash-dumps/crash-seed%-depth%.dmp", ctx.seed, ctx.depth);

    // Open file for writing
    // GENERIC_WRITE=0x40000000, share=0, CREATE_ALWAYS=2, FILE_ATTRIBUTE_NORMAL=0x80
    file := CreateFileA(filename.data, 0x40000000, 0, null, 2, 0x80, null);
    if cast(u64) file == 0xFFFF_FFFF_FFFF_FFFF  return false;  // INVALID_HANDLE_VALUE
    defer CloseHandle(file);

    // Set up exception info if provided
    mei: MINIDUMP_EXCEPTION_INFORMATION;
    mei_ptr: *MINIDUMP_EXCEPTION_INFORMATION = null;
    if exception_pointers {
        mei.ThreadId = GetCurrentThreadId();
        mei.ExceptionPointers = exception_pointers;
        mei.ClientPointers = .FALSE;
        mei_ptr = *mei;
    }

    // Write the minidump with global variable state included
    result := MiniDumpWriteDump(
        GetCurrentProcess(),
        GetCurrentProcessId(),
        file,
        .MiniDumpWithDataSegs,
        mei_ptr,
        null,
        null
    );

    return result == .TRUE;
}

// ============================================================================
// Allocator-Free SEH Path
// ============================================================================

// Allocator-free minidump writer for the SEH path.
// Same logic as debug_write_minidump but builds filename via seh_append_*
// helpers into a stack buffer instead of tprint.
seh_write_minidump :: (ep: *EXCEPTION_POINTERS) #c_call {
    CreateDirectoryA("crash-dumps".data, null);

    // Build filename: crash-dumps/crash-seed{N}-depth{N}.dmp\0
    fname: [2048] u8;
    fpos: s32 = 0;
    seh_append_str(*fname, *fpos, "crash-dumps/crash-seed");
    seh_append_u64(*fname, *fpos, g_debug_context.seed);
    seh_append_str(*fname, *fpos, "-depth");
    seh_append_s32(*fname, *fpos, g_debug_context.depth);
    seh_append_str(*fname, *fpos, ".dmp");
    if fpos < 2048  fname[fpos] = 0;  // null terminate

    file := CreateFileA(fname.data, 0x40000000, 0, null, 2, 0x80, null);
    if cast(u64) file == 0xFFFF_FFFF_FFFF_FFFF  return;
    defer CloseHandle(file);

    mei: MINIDUMP_EXCEPTION_INFORMATION;
    mei.ThreadId = GetCurrentThreadId();
    mei.ExceptionPointers = ep;
    mei.ClientPointers = .FALSE;

    MiniDumpWriteDump(
        GetCurrentProcess(),
        GetCurrentProcessId(),
        file,
        .MiniDumpWithDataSegs,
        *mei,
        null,
        null
    );
}

// Allocator-free crash report writer for the SEH path.
// Formats breadcrumb fields from g_debug_context into a fixed buffer
// and writes via Win32 file I/O.
seh_write_crash_report :: (ep: *EXCEPTION_POINTERS) #c_call {
    ctx := *g_debug_context;

    // Build the detail string from the fixed buffer
    detail_str: string;
    detail_str.data = ctx.gen_step_detail.data;
    detail_str.count = ctx.gen_step_detail_len;

    buf: [2048] u8;
    pos: s32 = 0;

    seh_append_str(*buf, *pos, "=== CRASH REPORT ===\nmessage: Unhandled exception 0x");
    seh_append_hex(*buf, *pos, cast(u64) ep.ExceptionRecord.ExceptionCode, 8);
    seh_append_str(*buf, *pos, "\nseed: ");
    seh_append_u64(*buf, *pos, ctx.seed);
    seh_append_str(*buf, *pos, "\ndepth: ");
    seh_append_s32(*buf, *pos, ctx.depth);
    seh_append_str(*buf, *pos, "\nturn: ");
    seh_append_s32(*buf, *pos, ctx.turn);
    seh_append_str(*buf, *pos, "\nplayer_x: ");
    seh_append_s32(*buf, *pos, ctx.player_x);
    seh_append_str(*buf, *pos, "\nplayer_y: ");
    seh_append_s32(*buf, *pos, ctx.player_y);
    seh_append_str(*buf, *pos, "\nmap_hash: ");
    seh_append_hex(*buf, *pos, ctx.map_hash, 16);
    seh_append_str(*buf, *pos, "\ngen_step: ");
    seh_append_gen_step(*buf, *pos, ctx.gen_step);
    seh_append_str(*buf, *pos, "\ngen_step_detail: ");
    seh_append_str(*buf, *pos, detail_str);
    seh_append_str(*buf, *pos, "\nrng_mti: ");
    seh_append_s32(*buf, *pos, ctx.rng_mti);
    seh_append_str(*buf, *pos, "\nrng_calls: ");
    seh_append_u64(*buf, *pos, cast(u64) ctx.rng_calls);
    seh_append_str(*buf, *pos, "\ncurrent_room_index: ");
    seh_append_s32(*buf, *pos, ctx.current_room_index);
    seh_append_str(*buf, *pos, "\ncurrent_room_bounds: ");
    seh_append_s32(*buf, *pos, ctx.current_room_bounds.x1);
    seh_append_str(*buf, *pos, ",");
    seh_append_s32(*buf, *pos, ctx.current_room_bounds.y1);
    seh_append_str(*buf, *pos, ",");
    seh_append_s32(*buf, *pos, ctx.current_room_bounds.x2);
    seh_append_str(*buf, *pos, ",");
    seh_append_s32(*buf, *pos, ctx.current_room_bounds.y2);
    seh_append_str(*buf, *pos, "\nhas_current_room: ");
    seh_append_bool(*buf, *pos, ctx.has_current_room);
    seh_append_str(*buf, *pos, "\n=== END ===\n");

    // Write via Win32 file I/O (no allocator)
    file := CreateFileA("crash-report.txt".data, 0x40000000, 0, null, 2, 0x80, null);
    if cast(u64) file == 0xFFFF_FFFF_FFFF_FFFF  return;
    defer CloseHandle(file);

    bytes_written: u32;
    WriteFile(file, buf.data, cast(u32) pos, *bytes_written, null);
}

// SEH handler for unhandled exceptions (access violations, stack overflows, etc.)
// Fully allocator-free: uses only fixed buffers and Win32 APIs.
// Writes minidump first (most valuable artifact), then crash report.
debug_seh_handler :: (ep: *EXCEPTION_POINTERS) -> s32 #c_call {
    if g_seh_in_progress  return 1;  // Re-entry guard: prevent double-fault
    g_seh_in_progress = true;

    // 1. Write minidump FIRST (contains full process state for cdb analysis)
    seh_write_minidump(ep);

    // 2. Write crash report (fixed-buffer formatting, Win32 file I/O)
    seh_write_crash_report(ep);

    return 1;  // EXCEPTION_EXECUTE_HANDLER
}

// ============================================================================
// Assertion Handler
// ============================================================================

// Custom assertion handler that writes crash report and minidump before aborting.
debug_assertion_failed :: (
    loc: Source_Code_Location, message: string
) -> bool {
    crash_msg := tprint("Assertion failed at %:%: %", loc.fully_pathed_filename, loc.line_number, message);
    write_crash_report(crash_msg);
    debug_write_minidump();
    // Return false to let the default handler abort
    return false;
}

// ============================================================================
// Initialization
// ============================================================================

// Print validation issues to stderr (used by conditional validation in makelev).
debug_report_validation :: (result: *ValidationResult) {
    if result.issue_count == 0 return;
    text := format_validation_result(result);
    print("%\n", text);
}

// Install debug handlers. Call once at startup.
debug_init :: () {
    if g_debug_context.initialized return;

    // Install custom assertion handler
    context.assertion_failed = debug_assertion_failed;

    // Install SEH handler for unhandled exceptions and suppress Windows error dialog
    SetUnhandledExceptionFilter(debug_seh_handler);
    SetErrorMode(.SEM_FAILCRITICALERRORS | .SEM_NOGPFAULTERRORBOX);

    g_debug_context.initialized = true;
}
