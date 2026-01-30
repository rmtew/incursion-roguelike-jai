// State Validator - Map invariant checking for debug/stress testing
//
// Validation functions that check map invariants and return structured issues.
// Called at checkpoints during generation and from the stress tester.
//
// Usage:
//   g_debug_validate = true;                   // Enable validation
//   result := validate_map(m, .DRAW_PANELS);   // Run validators
//   if result.issue_count > 0 {
//       text := format_validation_result(*result);
//       print("%\n", text);
//   }

// ============================================================================
// Validation Result
// ============================================================================

MAX_VALIDATION_ISSUES :: 64;

ValidationIssue :: struct {
    category: string;   // e.g. "room_bounds", "entity_position"
    message: string;    // Human-readable description
    x: s32;             // Map coordinate (if applicable, -1 otherwise)
    y: s32;
}

ValidationResult :: struct {
    issues: [MAX_VALIDATION_ISSUES] ValidationIssue;
    issue_count: s32;
    step: GenStep;      // Which step validation was run after
    seed: u64;          // For identification
}

add_issue :: (result: *ValidationResult, category: string, message: string, x: s32 = -1, y: s32 = -1) {
    if result.issue_count >= MAX_VALIDATION_ISSUES return;
    issue := *result.issues[result.issue_count];
    issue.category = category;
    issue.message = message;
    issue.x = x;
    issue.y = y;
    result.issue_count += 1;
}

// ============================================================================
// Individual Validators
// ============================================================================

// Check that all rooms have non-degenerate bounds within the map.
validate_room_bounds :: (m: *GenMap, result: *ValidationResult) {
    for room, idx: m.rooms {
        r := room.bounds;

        // Non-degenerate
        if r.x1 > r.x2 || r.y1 > r.y2 {
            add_issue(result, "room_bounds",
                tprint("Room % has degenerate bounds: %,%,%,%", idx, r.x1, r.y1, r.x2, r.y2),
                r.x1, r.y1);
        }

        // Within map
        if r.x1 < 0 || r.y1 < 0 || r.x2 >= m.width || r.y2 >= m.height {
            add_issue(result, "room_bounds",
                tprint("Room % out of map bounds: %,%,%,% (map %x%)", idx, r.x1, r.y1, r.x2, r.y2, m.width, m.height),
                r.x1, r.y1);
        }
    }
}

// Check that all monsters and items are within map bounds and on passable terrain.
validate_entity_positions :: (m: *GenMap, result: *ValidationResult) {
    for mon, idx: m.monsters {
        if !map_in_bounds(m, mon.x, mon.y) {
            add_issue(result, "entity_position",
                tprint("Monster % at %,% is out of bounds", idx, mon.x, mon.y),
                mon.x, mon.y);
            continue;
        }

        t := map_get(m, mon.x, mon.y);
        // Aquatic monsters can be on water, aerial on chasms; otherwise must be passable
        passable := terrain_passable(t) || terrain_is_water(t);
        if mon.is_aquatic  passable = passable || terrain_is_water(t);
        if mon.is_aerial   passable = passable || (t == .CHASM);
        if !passable {
            add_issue(result, "entity_position",
                tprint("Monster % at %,% on impassable terrain %", idx, mon.x, mon.y, t),
                mon.x, mon.y);
        }
    }

    for item, idx: m.items {
        if !map_in_bounds(m, item.x, item.y) {
            add_issue(result, "entity_position",
                tprint("Item % at %,% is out of bounds", idx, item.x, item.y),
                item.x, item.y);
            continue;
        }

        t := map_get(m, item.x, item.y);
        // Items should be on passable terrain (floor, corridor, etc.)
        // Treasure deposits are deliberately placed in ROCK/WALL — allow solid terrain for items
        // (The original Incursion places hidden treasure in rock walls)
        if !terrain_passable(t) && !terrain_is_water(t) && t != .ROCK && t != .WALL {
            add_issue(result, "entity_position",
                tprint("Item % at %,% on impassable terrain %", idx, item.x, item.y, t),
                item.x, item.y);
        }
    }
}

// Check that all terrain values are valid enum values and edges are solid.
validate_terrain_values :: (m: *GenMap, result: *ValidationResult) {
    max_terrain := cast(u8) Terrain.RUBBLE;

    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            t := map_get(m, x, y);
            tv := cast(u8) t;

            // Valid enum range
            if tv > max_terrain {
                add_issue(result, "terrain_value",
                    tprint("Invalid terrain value % at %,%", tv, x, y),
                    x, y);
            }

            // Edges must be solid (ROCK or WALL)
            if x == 0 || y == 0 || x == m.width-1 || y == m.height-1 {
                if !terrain_solid(t) && t != .ROCK {
                    add_issue(result, "terrain_value",
                        tprint("Non-solid edge terrain % at %,%", t, x, y),
                        x, y);
                }
            }
        }
    }
}

// Check door consistency: door terrain matches door data.
validate_door_consistency :: (m: *GenMap, result: *ValidationResult) {
    for door, idx: m.doors {
        if !map_in_bounds(m, door.x, door.y) {
            add_issue(result, "door_consistency",
                tprint("Door % at %,% is out of bounds", idx, door.x, door.y),
                door.x, door.y);
            continue;
        }

        t := map_get(m, door.x, door.y);
        is_door_terrain := (t == .DOOR_CLOSED || t == .DOOR_OPEN || t == .DOOR_SECRET);

        if !is_door_terrain {
            add_issue(result, "door_consistency",
                tprint("Door % at %,% has terrain % (expected door)", idx, door.x, door.y, t),
                door.x, door.y);
        }

        // Check flag/terrain consistency
        if (door.flags & DF_OPEN) != 0 && t != .DOOR_OPEN {
            add_issue(result, "door_consistency",
                tprint("Door % at %,% has DF_OPEN but terrain is %", idx, door.x, door.y, t),
                door.x, door.y);
        }

        if (door.flags & DF_SECRET) != 0 && t != .DOOR_SECRET {
            add_issue(result, "door_consistency",
                tprint("Door % at %,% has DF_SECRET but terrain is %", idx, door.x, door.y, t),
                door.x, door.y);
        }
    }
}

// Check room connectivity via flood fill (only valid after fixup_tunneling step).
validate_room_connectivity :: (m: *GenMap, result: *ValidationResult) {
    if m.rooms.count < 2 return;

    // Find first passable tile to start flood fill
    start_x: s32 = -1;
    start_y: s32 = -1;

    r0 := m.rooms[0].bounds;
    cx, cy := rect_center(r0);
    if map_in_bounds(m, cx, cy) {
        t := map_get(m, cx, cy);
        if terrain_passable(t) || terrain_is_water(t) || t == .DOOR_CLOSED || t == .DOOR_SECRET {
            start_x = cx;
            start_y = cy;
        }
    }

    if start_x < 0 {
        // Search room 0 for any passable tile
        for y: r0.y1..r0.y2 {
            for x: r0.x1..r0.x2 {
                t := map_get(m, x, y);
                if terrain_passable(t) || terrain_is_water(t) {
                    start_x = x;
                    start_y = y;
                    break;
                }
            }
            if start_x >= 0 break;
        }
    }

    if start_x < 0 {
        add_issue(result, "room_connectivity", "Cannot find passable tile in room 0 for flood fill");
        return;
    }

    // Flood fill from start
    visited: [MAP_WIDTH * MAP_HEIGHT] bool;
    stack_x: [4096] s32;
    stack_y: [4096] s32;
    stack_top: s32 = 0;

    stack_x[0] = start_x;
    stack_y[0] = start_y;
    stack_top = 1;
    visited[start_y * m.width + start_x] = true;

    while stack_top > 0 {
        stack_top -= 1;
        sx := stack_x[stack_top];
        sy := stack_y[stack_top];

        // Check 4 cardinal neighbors
        neighbors_x :: s32.[0, 0, -1, 1];
        neighbors_y :: s32.[-1, 1, 0, 0];

        for i: 0..3 {
            nx := sx + neighbors_x[i];
            ny := sy + neighbors_y[i];

            if !map_in_bounds(m, nx, ny) continue;
            idx := ny * m.width + nx;
            if visited[idx] continue;

            t := map_get(m, nx, ny);
            // Can traverse through: passable terrain, water, doors (even closed/secret)
            if terrain_passable(t) || terrain_is_water(t) || t == .DOOR_CLOSED || t == .DOOR_SECRET {
                visited[idx] = true;
                if stack_top < 4096 {
                    stack_x[stack_top] = nx;
                    stack_y[stack_top] = ny;
                    stack_top += 1;
                }
            }
        }
    }

    // Check that each room has at least one visited tile
    for room, idx: m.rooms {
        found := false;
        for y: room.bounds.y1..room.bounds.y2 {
            for x: room.bounds.x1..room.bounds.x2 {
                if map_in_bounds(m, x, y) && visited[y * m.width + x] {
                    found = true;
                    break;
                }
            }
            if found break;
        }

        if !found {
            add_issue(result, "room_connectivity",
                tprint("Room % (%,%,%,%) is not reachable from room 0",
                    idx, room.bounds.x1, room.bounds.y1, room.bounds.x2, room.bounds.y2));
        }
    }
}

// ============================================================================
// Entry Point
// ============================================================================

// Run all validators appropriate for the current generation step.
// Returns a ValidationResult with any issues found.
validate_map :: (m: *GenMap, step: GenStep) -> ValidationResult {
    result: ValidationResult;
    result.step = step;
    result.seed = g_debug_context.seed;

    // Room bounds: valid after DRAW_PANELS
    if step >= .DRAW_PANELS {
        validate_room_bounds(m, *result);
    }

    // Terrain values: always valid
    validate_terrain_values(m, *result);

    // Door consistency: valid after VALIDATE_DOORS
    if step >= .VALIDATE_DOORS {
        validate_door_consistency(m, *result);
    }

    // Entity positions: valid after POPULATE
    if step >= .POPULATE {
        validate_entity_positions(m, *result);
    }

    // Room connectivity: valid after FIXUP_TUNNELING
    if step >= .FIXUP_TUNNELING {
        validate_room_connectivity(m, *result);
    }

    return result;
}

// Format validation result as multiline text.
format_validation_result :: (result: *ValidationResult) -> string {
    if result.issue_count == 0 {
        return tprint("Validation passed (step: %)", gen_step_name(result.step));
    }

    builder: String_Builder;
    print_to_builder(*builder, "=== VALIDATION ISSUES (step: %, seed: %) ===\n",
                     gen_step_name(result.step), result.seed);

    for i: 0..result.issue_count-1 {
        issue := result.issues[i];
        if issue.x >= 0 {
            print_to_builder(*builder, "[%] at %,%: %\n",
                             issue.category, issue.x, issue.y, issue.message);
        } else {
            print_to_builder(*builder, "[%]: %\n",
                             issue.category, issue.message);
        }
    }

    print_to_builder(*builder, "Total: % issue(s)\n", result.issue_count);
    return builder_to_string(*builder);
}
