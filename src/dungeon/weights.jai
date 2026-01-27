// Weighted Room Selection System
//
// Implements Incursion-compatible weighted room and region selection
// for exact dungeon replication - same RNG seed produces identical dungeons.
//
// Two-tier selection system:
// 1. Room Type Selection: Cumulative weight algorithm picks room shape
// 2. Region Selection: Constraint filtering picks appearance (walls, floors, monsters)
//
// Note: WeightListEntry and ParsedWeightList are defined in parser.jai

// ============================================================================
// Runtime region (resolved from ParsedRegion)
// ============================================================================

RuntimeRegion :: struct {
    name: string;
    index: s32;            // Index in source regions array
    room_types: u32;       // Bitmask of supported RM_* types (0 = all)
    depth: s32;            // Minimum CR requirement
    flags: u32;            // RF_VAULT, RF_CORRIDOR, RF_STAPLE, RF_NOGEN, etc.

    // Terrain references (resolved later)
    floor_ref: string;     // $"terrain" reference
    wall_ref: string;      // $"terrain" reference
    door_ref: string;      // $"feature" reference

    // Grid data for RM_SHAPED regions
    has_grid: bool;
    grid: string;
    grid_width: s32;
    grid_height: s32;

    // Size constraint
    size: s32;             // SZ_* constant (0 = any)
}

// Region flags (from Defines.h)
RF_RIVER    :: 0x00000001;
RF_CHASM    :: 0x00000002;
RF_CORRIDOR :: 0x00000004;
RF_ROOM     :: 0x00000008;
RF_VAULT    :: 0x00000010;
RF_STAPLE   :: 0x00000020;   // Can be used multiple times
RF_NOGEN    :: 0x00000040;   // Never randomly generated
RF_RAINBOW  :: 0x00000080;   // Rainbow walls
RF_NEVER_LIT :: 0x00000100;
RF_CENTER_ENC :: 0x00000200;
RF_ODD_WIDTH :: 0x00000400;
RF_ODD_HEIGHT :: 0x00000800;

// ============================================================================
// Dungeon weights container
// ============================================================================

DungeonWeights :: struct {
    // Room type weights (from RM_WEIGHTS list)
    // Stored as parallel arrays: type, weight pairs
    rm_types: [RM_LAST] s32;
    rm_weights: [RM_LAST] s32;
    rm_count: s32;

    // Region lists (from ROOM_WEIGHTS / resolved regions)
    room_regions: [..] RuntimeRegion;
    corridor_regions: [..] RuntimeRegion;
    vault_regions: [..] RuntimeRegion;

    // Corridor weights (type, weight pairs for frequency expansion)
    corridor_weights: [..] WeightListEntry;
}

// Default room type weights (from original MakeLev.cpp)
DEFAULT_RM_TYPES :: s32.[
    RM_NORMAL,   RM_NOROOM,   RM_LARGE,    RM_CROSS,
    RM_OVERLAP,  RM_ADJACENT, RM_AD_ROUND, RM_AD_MIXED,
    RM_CIRCLE,   RM_OCTAGON,  RM_DIAMONDS, RM_DOUBLE,
    RM_PILLARS,  RM_CHECKER,  RM_BUILDING, RM_GRID,
    RM_LIFECAVE, RM_RCAVERN,  RM_MAZE,     RM_LCIRCLE,
    RM_SHAPED,
];

DEFAULT_RM_WEIGHTS :: s32.[
    10,  // RM_NORMAL
    1,   // RM_NOROOM
    1,   // RM_LARGE
    1,   // RM_CROSS
    1,   // RM_OVERLAP
    1,   // RM_ADJACENT
    2,   // RM_AD_ROUND
    2,   // RM_AD_MIXED
    4,   // RM_CIRCLE
    5,   // RM_OCTAGON
    4,   // RM_DIAMONDS
    2,   // RM_DOUBLE
    3,   // RM_PILLARS
    1,   // RM_CHECKER
    3,   // RM_BUILDING
    1,   // RM_GRID
    10,  // RM_LIFECAVE
    4,   // RM_RCAVERN
    2,   // RM_MAZE
    1,   // RM_LCIRCLE
    2,   // RM_SHAPED
];

// ============================================================================
// Per-level selection state
// ============================================================================

SelectionState :: struct {
    // Mutable copy of rm_weights (modified during level generation)
    rm_weights: [RM_LAST] s32;
    rm_types: [RM_LAST] s32;
    rm_count: s32;

    // Regions used this level (prevent repeats unless RF_STAPLE)
    used_regions: [128] s32;  // indices into room_regions
    used_count: s32;

    // Dungeon depth info
    depth_cr: s32;            // Current level CR
    min_vault_depth: s32;     // Minimum depth for vaults
}

// ============================================================================
// Initialize selection state from dungeon weights
// ============================================================================

init_selection_state :: (state: *SelectionState, weights: *DungeonWeights, depth: s32) {
    // Copy room type weights
    state.rm_count = weights.rm_count;
    for i: 0..weights.rm_count-1 {
        state.rm_types[i] = weights.rm_types[i];
        state.rm_weights[i] = weights.rm_weights[i];
    }

    // If no weights defined, use defaults
    if state.rm_count == 0 {
        state.rm_count = DEFAULT_RM_TYPES.count;
        for i: 0..DEFAULT_RM_TYPES.count-1 {
            state.rm_types[i] = DEFAULT_RM_TYPES[i];
            state.rm_weights[i] = DEFAULT_RM_WEIGHTS[i];
        }
    }

    // Clear used regions
    state.used_count = 0;

    // Set depth
    state.depth_cr = depth;
    state.min_vault_depth = 4;  // Vaults appear at depth 4+
}

// Reset all exhausted weights back to original values
reset_rm_weights :: (state: *SelectionState, weights: *DungeonWeights) {
    if weights.rm_count > 0 {
        for i: 0..weights.rm_count-1 {
            if state.rm_weights[i] < 0 {
                state.rm_weights[i] = weights.rm_weights[i];
            }
        }
    } else {
        for i: 0..DEFAULT_RM_WEIGHTS.count-1 {
            if state.rm_weights[i] < 0 {
                state.rm_weights[i] = DEFAULT_RM_WEIGHTS[i];
            }
        }
    }
}

// ============================================================================
// Room Type Selection (Cumulative Weight Algorithm)
//
// Original algorithm from MakeLev.cpp:
// - Sum all positive weights
// - Pick random number in [0, total)
// - Walk through weights cumulatively until we hit the choice
// - If all weights exhausted, reset and retry
// ============================================================================

select_room_type :: (state: *SelectionState, weights: *DungeonWeights) -> room_type: s32, weight_index: s32 {
    // Sum positive weights
    total: s32 = 0;
    for i: 0..state.rm_count-1 {
        w := state.rm_weights[i];
        if w > 0 total += w;
    }

    // All exhausted? Reset and retry
    if total == 0 {
        reset_rm_weights(state, weights);
        // Recompute total
        for i: 0..state.rm_count-1 {
            w := state.rm_weights[i];
            if w > 0 total += w;
        }
        if total == 0 {
            // Still nothing? Return normal room
            return RM_NORMAL, 0;
        }
    }

    // Cumulative selection
    choice := random(total);
    cumulative: s32 = 0;

    for i: 0..state.rm_count-1 {
        w := state.rm_weights[i];
        if w > 0 {
            cumulative += w;
            if choice < cumulative {
                return state.rm_types[i], cast(s32)i;
            }
        }
    }

    // Fallback (shouldn't happen)
    return RM_NORMAL, 0;
}

// ============================================================================
// Region Selection (Constraint Filter)
//
// Filters regions by:
// 1. RoomTypes bitmask - region must support the chosen room type
// 2. Depth requirement - level CR must be >= region depth
// 3. Vault depth - vaults only at sufficient depth
// 4. Corridor flag - skip corridor regions for room selection
// 5. Uniqueness - skip regions already used this level (unless RF_STAPLE)
// 6. RF_NOGEN - never randomly generated
//
// Returns null if no valid region found (caller should exhaust room type and retry)
// ============================================================================

select_region :: (state: *SelectionState, weights: *DungeonWeights,
                  room_type: s32, rm_index: *s32) -> *RuntimeRegion, bool {
    candidates: [128] s32;
    count: s32 = 0;

    for i: 0..weights.room_regions.count-1 {
        region := *weights.room_regions[i];

        // Filter: RF_NOGEN regions are never randomly generated
        if region.flags & RF_NOGEN continue;

        // Filter: RoomTypes bitmask (0 means all types accepted)
        if region.room_types != 0 {
            type_bit := cast(u32)(1 << room_type);
            if !(region.room_types & type_bit) continue;
        }

        // Filter: Depth requirement
        if state.depth_cr < region.depth continue;

        // Filter: Vault depth
        if (region.flags & RF_VAULT) && state.depth_cr < state.min_vault_depth continue;

        // Filter: Skip corridor regions
        if region.flags & RF_CORRIDOR continue;

        // Filter: Not already used this level (unless RF_STAPLE)
        if !(region.flags & RF_STAPLE) {
            used := false;
            for j: 0..state.used_count-1 {
                if state.used_regions[j] == cast(s32)i {
                    used = true;
                    break;
                }
            }
            if used continue;
        }

        candidates[count] = cast(s32)i;
        count += 1;
        if count >= 128 break;
    }

    if count == 0 {
        // No valid regions - exhaust this room type
        if rm_index.* >= 0 && rm_index.* < RM_LAST {
            state.rm_weights[rm_index.*] = -1;
        }
        return null, false;
    }

    // Pick uniformly from candidates
    chosen := candidates[random(count)];

    // Mark as used
    if state.used_count < 128 {
        state.used_regions[state.used_count] = chosen;
        state.used_count += 1;
    }

    return *weights.room_regions[chosen], true;
}

// ============================================================================
// Corridor Selection (Frequency Expansion)
//
// For corridors, we use frequency expansion:
// - Each corridor region appears N times in an expanded list based on weight
// - Pick uniformly from expanded list
// - Check uniqueness (skip for RF_STAPLE)
// ============================================================================

select_corridor :: (state: *SelectionState, weights: *DungeonWeights) -> *RuntimeRegion {
    if weights.corridor_regions.count == 0 return null;

    // Build expanded list (each region appears weight times)
    expanded: [1024] s32;
    count: s32 = 0;

    for i: 0..weights.corridor_regions.count-1 {
        region := *weights.corridor_regions[i];

        // Skip RF_NOGEN
        if region.flags & RF_NOGEN continue;

        // Default weight of 1 if no explicit weight
        w: s32 = 1;
        // Could look up in corridor_weights if we stored them

        for j: 0..w-1 {
            if count >= 1024 break;
            expanded[count] = cast(s32)i;
            count += 1;
        }
    }

    if count == 0 return null;

    // Try to find an unused corridor (or accept RF_STAPLE)
    for try: 0..99 {
        chosen := expanded[random(count)];
        region := *weights.corridor_regions[chosen];

        // RF_STAPLE can always be used
        if region.flags & RF_STAPLE return region;

        // Check if already used
        used := false;
        for i: 0..state.used_count-1 {
            // Use negative indices for corridors to distinguish from rooms
            if state.used_regions[i] == -(chosen + 1) {
                used = true;
                break;
            }
        }

        if !used {
            if state.used_count < 128 {
                state.used_regions[state.used_count] = -(chosen + 1);
                state.used_count += 1;
            }
            return region;
        }
    }

    // Fallback: just return any corridor
    chosen := expanded[random(count)];
    return *weights.corridor_regions[chosen];
}

// ============================================================================
// Build dungeon weights from parsed data
// ============================================================================

init_dungeon_weights :: (weights: *DungeonWeights) {
    weights.rm_count = 0;
    array_reset(*weights.room_regions);
    array_reset(*weights.corridor_regions);
    array_reset(*weights.vault_regions);
    array_reset(*weights.corridor_weights);
}

free_dungeon_weights :: (weights: *DungeonWeights) {
    array_free(weights.room_regions);
    array_free(weights.corridor_regions);
    array_free(weights.vault_regions);
    array_free(weights.corridor_weights);
}

// Helper to convert room type constant to bit position
room_type_to_bit :: (room_type: s64) -> u32 {
    if room_type < 0 || room_type >= 32 return 0;
    return cast(u32)(1 << room_type);
}

// Parse a RoomTypes bitmask from an array of constants
// Input: array of RM_* constants, possibly combined with |
parse_room_types_mask :: (types: [] s64) -> u32 {
    mask: u32 = 0;
    for t: types {
        mask |= room_type_to_bit(t);
    }
    return mask;
}
