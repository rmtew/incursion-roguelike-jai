// Crash Handler - Structured crash reporting for debug diagnosis
//
// Provides a global DebugContext struct that is written at safe checkpoints
// during dungeon generation. On crash, writes everything to crash-report.txt.
//
// Usage:
//   debug_init();                          // Install handlers at startup
//   debug_set_gen_step(.DRAW_PANELS, "panel 2,1");  // Called at each step
//   debug_set_game_state(gs);              // Called after init_game / do_action
//
// Near-zero cost: each breadcrumb is a single global struct write.

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
// Assertion Handler
// ============================================================================

// Custom assertion handler that writes crash report before aborting.
debug_assertion_failed :: (
    loc: Source_Code_Location, message: string
) -> bool {
    crash_msg := tprint("Assertion failed at %:%: %", loc.fully_pathed_filename, loc.line_number, message);
    write_crash_report(crash_msg);
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

    g_debug_context.initialized = true;
}
