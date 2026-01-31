# Cross-Cutting Behavioral Flows

Traces key behaviors across subsystem boundaries to catch gaps that per-subsystem reviews miss. Each flow documents the full pipeline from origin to observable outcome, with verification checks.

**Rationale:** The implementation review marks steps as "MATCHES" based on structural code presence. But a function can exist without being called, or be called without its output being consumed. These flows trace data end-to-end and define observable checks to verify the chain is complete.

## How to Use This Document

For each flow:
1. Read the **chain** to understand what should happen
2. Check **verification** to confirm it actually works
3. **Status** shows current state: WORKING, BROKEN, or PARTIAL

When adding new features, check whether they participate in an existing flow and update this document.

---

## Flow 1: Player Spawn on Depth 1

**Observable:** Player starts at the Entry Chamber's cave entrance on depth 1.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Dungeon definition | Resource | `dungeon.irh`: `$"entry chamber" at level 1` | Parsed into `DungeonDef.specials` | OK |
| 2. Dungeon name propagation | Game init | `Game::NewGame` → `GetDungeonMap(dID, 1, ...)` → `Generate(dID, ...)` | `init_game` → `generate_dungeon` — passes `dungeon_name` | OK |
| 3. Special room placement | Generation | `MakeLev.cpp:1500-1569`: `WriteMap()` places Entry Chamber grid | `place_dungeon_specials` → `place_grid_special` → `write_grid_at_position` | OK |
| 4. TILE_START processing | Grid processing | `MakeLev.cpp:1139-1141`: sets `EnterX/EnterY` | `write_grid_at_position` sets `m.enter_x/enter_y` | OK |
| 5. Entry point storage | Map data | `Map::EnterX, EnterY` (public fields) | `GenMap.enter_x/enter_y` fields | OK |
| 6. Player placement | Game init | `Main.cpp:126-129`: places player at `EnterX/EnterY` | `game_init_player_position`: uses `enter_x/enter_y` when set | OK |

### Verification

- [x] Run dungeon_test with depth 1 → Entry Chamber room visible (large 23x22 room with corpses, pillars)
- [x] Player `@` starts on the `>` (cave entrance) tile
- [ ] Moving off start tile reveals `>` glyph underneath
- [x] Log shows "Placed grid special 'entry chamber' on depth 1"

### Current Status: WORKING (fixed in c5f4169)

---

## Flow 2: Stair Continuity Across Levels

**Observable:** Down-stairs on depth N connect to up-stairs at the same x,y on depth N+1.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Down-stairs placement | Generation | `MakeLev.cpp:1879-1900`: MIN to MAX stairs, avoid regions with existing stairs | `place_down_stairs()` `:4764` | OK |
| 2. Return positions | Generation | Portal objects at x,y stored for next level | Returns `[..] StairPos` from `generate_makelev` | OK |
| 3. Pass to next level | Generator | `Map::Generate(dID, Depth, Above)` — iterates Above's portals | `generate_makelev(above_down_stairs=...)` | OK |
| 4. Up-stairs placement | Generation | `MakeLev.cpp:1706-1743`: place at same x,y, carve if solid | `place_up_stairs()` `:4676` — places at x,y, carves 3x3 | OK |
| 5. Region avoidance | Generation | `stairsAt[]` prevents down-stairs in same room as up-stairs | `StairPos.room_index` tracking in `place_down_stairs` | OK |

### Verification

- [ ] Generate depth 1, record down-stair positions
- [ ] Generate depth 2 with those positions as `above_down_stairs`
- [ ] Verify up-stairs on depth 2 appear at same x,y coordinates
- [ ] If stair lands in solid rock, verify 3x3 area carved around it

### Current Status: WORKING (for multi-level generation when caller passes stair positions)

**Note:** `init_game` only generates a single level and discards `down_stairs`. Multi-level stair continuity requires the caller to manage the chain. The `generate_makelev` API supports it correctly.

---

## Flow 3: Region Terrain Theming

**Observable:** Rooms have distinct visual appearances (different wall/floor glyphs and colors) based on their region definition.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Region definition | Resource | `.irh`: `Walls: $"Dungeon Wall"; Floor: $"Floor"` | Parsed into `RuntimeRegion.floor_ref/wall_ref` | OK |
| 2. Terrain registry | Resource | `TerrainList[256]` with rID refs | `build_terrain_registry_from_baked()` `:terrain_registry.jai:122` | OK |
| 3. Resolution | Generation init | `TREG(regID)->Floor` on-demand | `resolve_region_terrains()` at `gen_state_init` — pre-resolves `floor_terrain/wall_terrain` pointers | OK |
| 4. Region selection | Generation | `DrawPanel` selects region by weight/depth/type | `select_region()` `:weights.jai:263` called from `draw_panel` | OK |
| 5. Region assignment | Generation | `regID` passed to room writers | `gs.current_region = region` set at `:makelev.jai:2589` before room writing | OK |
| 6. Terrain application | Room writing | `WriteAt(r, x, y, TREG(regID)->Floor, regID, prio)` | `get_region_floor/wall()` → `write_at_with_terrain()` | OK |
| 7. Glyph storage | Map | `TerrainList` + `Glyph` field on LocationInfo | `TileDisplay.glyph/fg_color` in `map_set_with_display` | OK |
| 8. Rendering | Display | Glyph from `Grid[].Glyph` | `get_cell_render` reads `TileDisplay` | OK |

### Verification

- [ ] Generate dungeon with visibility OFF (V key) → rooms have varied wall/floor styles
- [ ] Different region types (cavern, castle, etc.) use distinct glyphs/colors
- [ ] Corridors have themed appearance matching their corridor region

### Current Status: WORKING

---

## Flow 4: Connectivity Guarantee

**Observable:** Every non-solid tile on the map is reachable from every other non-solid tile (no isolated rooms).

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Initial flood fill | Generation | `FloodConnectA()` from first open tile | `flood_connect()` `:makelev.jai:496` — 8-directional, doors passable | OK |
| 2. Disconnect detection | Generation | Check for unflooded open tiles | `find_disconnected_regions()` `:556` — returns connected/unconnected edge lists | OK |
| 3. Pair finding | Generation | Best closest-pair per region | `fixup_tunneling()` `:4531` — multi-region, diagonal distance | OK |
| 4. Tunnel carving | Generation | `Tunnel()` with corridor region | `carve_tunnel()` `:2822` with optional corridor region | OK |
| 5. Re-flood | Generation | Re-run flood from tunnel source | `flood_connect(gs, m, sx, sy)` after each connection | OK |
| 6. Iteration | Generation | Up to 26 trials | `MAX_TRIALS = 26`, breaks when unconnected count = 0 | OK |

### Verification

- [ ] Generate 100 dungeons → no isolated rooms (player can reach all floor tiles)
- [ ] Toggle visibility OFF → visually confirm no disconnected areas

### Current Status: WORKING

---

## Flow 5: Chasm Propagation Across Levels

**Observable:** Chasms on depth N appear (possibly narrower) on depth N+1. Tiles below chasms are skylights (cyan, always lit).

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Chasm streamer | Generation | `WriteStreamer()` places chasm terrain on depth N | `carve_streamer()` `:3253` with `CHASM` type | OK |
| 2. Depth restriction | Generation | `MIN_CHASM_DEPTH`, no chasms on last level | `gs.con.MIN_CHASM_DEPTH = 5`, `DUN_DEPTH` check | OK |
| 3. Pass above map | Generator | `Map::Generate(dID, Depth, Above)` | `generate_makelev(above_map=...)` | OK |
| 4. Chasm copy | Generation | `MakeLev.cpp:1466-1490`: copy RF_CHASM tiles from above | `:5067-5086`: copy `.CHASM` tiles from `above_map` | OK |
| 5. Narrowing | Generation | 50% chance narrow (only copy if cardinal neighbors also chasm) | `REDUCE_CHASM_CHANCE` (50%), cardinal adjacency check | OK |
| 6. Skylight marking | Post-generation | Tiles below chasms: `isSkylight`, always lit | `:5215-5237`: `td.is_skylight = true`, lit flags set | OK |

### Verification

- [ ] Generate depth 5+ with chasm streamer → depth 6 shows narrower version
- [ ] Non-solid tiles below chasms appear with cyan tint (skylight)
- [ ] Skylights are always lit regardless of torch placement

### Current Status: WORKING (when caller provides `above_map`)

**Note:** Like stair continuity, requires caller to pass `above_map`. Single-level `init_game` does not exercise this.

---

## Flow 6: Secret Door Protection Near Stairs

**Observable:** On early levels (depth <= 5), secret doors within 17 tiles of up-stairs are converted to normal closed doors.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Secret door creation | Generation | `MakeSecretDoor()`: `DF_SECRET \| DF_LOCKED` | Door randomization: 14% secret | OK |
| 2. Up-stairs placement | Generation | Placed from above level's down-stairs | `place_up_stairs()` `:4676` | OK |
| 3. Desecret pass | Post-stairs | `MakeLev.cpp:2062-2071`: clear secret within range | `desecret_near_stairs()` `:3681` | OK |
| 4. Call timing | Generation | After stairs, before population | Called at `:5208` after stair placement | OK |
| 5. Distance check | Generation | Manhattan distance <= 17 from any up-stair | Manhattan distance, `SECRET_DOOR_CLEAR_DISTANCE` | OK |
| 6. Depth restriction | Generation | Only on early levels | `SECRET_DOOR_CLEAR_MAX_DEPTH` check | OK |

### Verification

- [ ] Generate depth 1 with up-stair → no secret doors within 17 Manhattan distance
- [ ] Generate depth 6+ → secret doors near stairs preserved

### Current Status: WORKING

---

## Flow 7: Monster Encounter Placement

**Observable:** Rooms contain CR-appropriate monsters with correct density, aquatic monsters in water, sleeping monsters.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Per-room trigger | Generation | `PopulatePanel()` per room | `populate_panel()` `:4294` per room | OK |
| 2. Open space counting | Generation | `FindOpenAreas()` → `OpenC` count | `count_open_tiles_in_room()` `:4218` | OK |
| 3. Density calculation | Generation | `OpenC / divisor` (75/50/30 by depth) | `monster_density_divisor()` by depth | OK |
| 4. Encounter selection | Resource | `EV_ENGEN` event → full 7-stage pipeline | `select_encounter()` `:runtime.jai:296` — CR-based selection | PARTIAL |
| 5. OOD chance | Generation | 22% chance for CR+1..+4 | 22% check at `:4313` | OK |
| 6. Aquatic constraint | Generation | `FOA_WATER_ONLY` flag | 20% aquatic chance if water in room `:4359` | OK |
| 7. Placement | Generation | `PlaceEncounter()` at open positions | `find_open_in_room()` + add to `m.monsters` | OK |
| 8. Sleep state | Generation | 50% sleeping | 50% sleeping at `:4382` | OK |
| 9. Party assignment | Generation | Same room = same party | `party_id` per `populate_panel` call | OK |

### Verification

- [ ] Depth 1 rooms have sparse monsters (divisor 75)
- [ ] Deeper levels have denser monsters (divisor 30)
- [ ] Water rooms occasionally contain aquatic monsters
- [ ] Monster glyphs match their resource definition

### Current Status: WORKING

**Note:** Encounter selection is simplified vs original 7-stage pipeline. Original uses event system with template/mount/alignment stages. Port uses direct CR-based resource lookup. Functionally equivalent for basic placement.

---

## Flow 8: Dungeon Specials System

**Observable:** Predefined special rooms appear at their designated depths (Entry Chamber at 1, library at 2, sanctuaries at odd levels, etc.)

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Dungeon definition | Resource | `dungeon.irh` Specials list with `at level N` | Parsed into `DungeonDef.specials` | OK |
| 2. Dungeon name propagation | Game init | `Generate(dID, Depth, Above)` — `dID` identifies dungeon | `dungeon_name` parameter — passed from `init_game` | OK |
| 3. Depth matching | Generation | Loop specials, check `Depth == level` | `place_dungeon_specials()` `:4924` — filters by `at_level` | OK |
| 4. Grid special placement | Generation | `WriteMap()` with vault overlap avoidance | `place_grid_special()` `:4830` — stair + vault overlap checks | OK |
| 5. Non-grid special | Generation | `DrawPanel()` with forced region | `place_nongrid_special()` `:4908` | OK |
| 6. Panel marking | Generation | `PanelsDrawn` bitmask | `gs.panels_drawn` bitmask | OK |
| 7. TILE_START | Grid processing | Sets `EnterX/EnterY` | Sets `m.enter_x/enter_y` | OK |
| 8. Tile objects | Grid processing | Spawns features/items from `with` clauses | `place_tile_object()` — partially implemented | PARTIAL |

### Verification

- [ ] Pass `dungeon_name = "The Goblin Caves"` → "Placed grid special 'entry chamber' on depth 1" in log
- [ ] Depth 2: "ancient library" placed
- [ ] Depth 3: "place of sanctuary" + "armoury" placed
- [ ] Special rooms have correct grid layout (not randomly generated)

### Current Status: WORKING (fixed in c5f4169)

---

## Flow 9: Door Lifecycle

**Observable:** Doors spawn with randomized states, display correct glyphs, and respond to player interaction.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Door placement | Generation | `MakeDoor()` at corridor/room intersections | `place_doors_makelev()` post-process | OK |
| 2. State randomization | Generation | 10% open, 50% locked, 14% secret | Same probabilities in door creation | OK |
| 3. Orientation | Generation | `SetImage()` checks adjacent solids | Vertical/horizontal from adjacent wall check | OK |
| 4. Glyph display | Rendering | Vertical=`│`, horizontal=`─`, open=`+`, secret=wall glyph | Terrain-based: `DOOR_CLOSED/OPEN/SECRET` → glyph lookup | OK |
| 5. Auto-open on walk | Game loop | Walking into closed door opens it (one action) | `do_move()` `:loop.jai:118-141` auto-opens | OK |
| 6. Locked blocking | Game loop | Locked doors block with message | `DF_LOCKED` check at `:121-124` | OK |
| 7. Secret blocking | Game loop | Secret doors block like walls | `DOOR_SECRET` check at `:144-147` | OK |
| 8. Depth 1-3 wood force | Generation | Forces `MAT_WOOD` on early levels | Not applicable (no door materials yet) | N/A |

### Verification

- [ ] Doors visible on map with correct orientation glyphs
- [ ] Walking into closed door: "You open the door" + door changes to open
- [ ] Walking into locked door: "The door is locked" + blocked
- [ ] Secret doors invisible (appear as wall)

### Current Status: WORKING (basic lifecycle)

---

## Flow 10: Trap Passability and Interaction

**Observable:** Player walks onto a hidden trap → trap triggers → damage/effect. Visible traps can be avoided.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Trap placement | Generation | `MakeLev.cpp:2155-2192`: places `Trap` Feature object on floor tile | `place_traps()`: sets terrain to `TRAP_HIDDEN` | DIFFERS |
| 2. Underlying terrain | Map | Terrain stays floor; trap is a Feature on top | **Terrain IS the trap** — floor is replaced by `TRAP_HIDDEN` | **INCORRECT** |
| 3. Passability | Game loop | Floor is passable; trap object is invisible | `game_can_move_to` lists `.TRAP` and `.TRAP_HIDDEN` as passable | OK |
| 4. Hidden display | Rendering | Trap has `F_INVIS` until `TS_FOUND`; floor glyph shows | `TRAP_HIDDEN` renders as `.` (correct visually) | OK |
| 5. Detection | Perception | Search check vs trap DC | Not implemented | MISSING |
| 6. Trigger | Combat/effects | Walk onto trap → save vs DC → effect | Not implemented | MISSING |

### Verification

- [x] Player can walk onto `TRAP_HIDDEN` tiles
- [x] Hidden traps look like floor tiles
- [ ] After detection, trap shows `^` glyph

### Current Status: PARTIAL (passable now, trigger/detection still missing)

Traps are modeled as terrain types instead of objects-on-floor. The passability issue is fixed (`.TRAP` and `.TRAP_HIDDEN` added to both `game_can_move_to` and `terrain_passable`), but:
- Traps cannot coexist with other features on the same tile
- Detection and trigger systems are not implemented

**Correct fix (long-term):** Traps should be Feature objects on floor tiles, not terrain types. Requires the Feature/Thing object system.

---

## Flow 11: FOV, Memory, and Rendering

**Observable:** Player sees nearby tiles in FOV; previously-seen tiles shown dimmed from memory; unseen tiles are blank.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. FOV calculation | Vision | Shadow casting from player position | `calculate_fov()` `:visibility.jai` on each turn | OK |
| 2. Visible marking | Vision | `VI_VISIBLE` set for tiles in FOV | `vis.flags \|= VI_VISIBLE \| VI_DEFINED` | OK |
| 3. Memory storage | Vision | `Memory` glyph stored when first seen | `memory_glyph` + `memory_fg` stored | OK |
| 4. Lit check | Lighting | `calcLight()` propagates from torches | `calculate_lighting()` with `TorchPos` array | OK |
| 5. Render visible | Rendering | Full glyph + colors for visible tiles | `get_cell_render` returns terrain/creature/item glyph | OK |
| 6. Render memory | Rendering | Dimmed memory glyph for defined-but-not-visible | `dim_color(vis.memory_fg)` with `memory_glyph` | OK |
| 7. Render unseen | Rendering | Blank/black for never-seen tiles | `GLYPH_UNSEEN` returned | OK |
| 8. Turn advance | Game loop | FOV recalculated each turn | `advance_turn()` calls `calculate_fov()` | OK |

### Verification

- [ ] Tiles near player are visible with full color
- [ ] Walk away from area → tiles dim but remain visible (memory)
- [ ] Areas never visited are black
- [ ] Toggle V key → FOV mode off shows entire map

### Current Status: WORKING

---

## Flow 12: Resource Parse Errors and Downstream Impact

**Observable:** Parse errors in `.irh` files → missing monsters/items in resource DB → encounter selection has fewer options → some CR ranges may have no matches.

### Chain

| Step | Subsystem | Original | Jai Port | Status |
|------|-----------|----------|----------|--------|
| 1. Parse `.irh` files | Resource | Built-in parser, all resources loaded | `init_resource_db()` with Jai parser | PARTIAL |
| 2. Parse errors | Resource | N/A (original parser handles all syntax) | `mon1-4.irh` have parse errors (418+ lines) | **DEGRADED** |
| 3. Resource DB | Resource | Full DB: all monsters, items, terrains | DB: 429 monsters, 201 items, 53 terrains (unknown how many skipped) | UNKNOWN |
| 4. CR coverage | Generation | Full CR range covered for encounters | `find_monster_by_cr_fuzzy` widens search ±tolerance, ultimate fallback random | RESILIENT |
| 5. Encounter quality | Generation | Thematic encounters matching dungeon depth | Encounters may be CR-mismatched due to gaps in parsed monster pool | DEGRADED |

### Verification

- [ ] Count parse errors vs total monster definitions to determine coverage percentage
- [ ] Check which CR ranges have zero monsters (holes in encounter selection)
- [ ] Compare dungeon_test monster variety against original game at same depth/seed

### Current Status: DEGRADED (functional but reduced variety due to parse errors)

**Note:** This is not a cross-subsystem bug but a data quality issue that degrades multiple downstream flows (encounter selection, item placement, terrain theming). The `find_monster_by_cr_fuzzy` fallback prevents crashes but may place inappropriate monsters.

---

## Summary

| Flow | Status | Blocking Issue |
|------|--------|----------------|
| 1. Player Spawn | WORKING | Fixed in c5f4169 |
| 2. Stair Continuity | WORKING | Single-level `init_game` doesn't exercise it |
| 3. Region Theming | WORKING | — |
| 4. Connectivity | WORKING | — |
| 5. Chasm Propagation | WORKING | Single-level `init_game` doesn't exercise it |
| 6. Secret Door Protection | WORKING | — |
| 7. Monster Placement | WORKING | Simplified encounter selection vs original |
| 8. Dungeon Specials | WORKING | Fixed in c5f4169 |
| 9. Door Lifecycle | WORKING | — |
| 10. Trap Passability | PARTIAL | Passable now; trigger/detection still missing |
| 11. FOV/Memory Rendering | WORKING | — |
| 12. Resource Parse Errors | DEGRADED | Parse errors reduce monster/item pool; fuzzy fallback masks gaps |

## Systemic Issues

Issues that affect multiple flows or represent architectural mismatches rather than single broken links.

### Issue A: `dungeon_name` Not Propagated (Root Cause for Flows 1, 8) — RESOLVED

**Fixed in c5f4169.** `init_game` now passes `dungeon_name = "The Goblin Caves"` through `generate_dungeon` → `generate_makelev`. Dungeon specials are placed and generation constants are applied correctly.

### Issue B: Traps Modeled as Terrain (Design Mismatch)

In the original, traps are Feature objects placed on floor tiles. In the port, traps are terrain types (`TRAP`, `TRAP_HIDDEN`). Consequences:

- **Blocks movement** — Neither `terrain_passable` nor `game_can_move_to` lists trap terrain as passable
- **FOV sees through** — `terrain_solid` doesn't include traps, so they don't block line of sight (correct)
- **Flood fill connects through** — Traps are non-solid so connectivity isn't affected (correct)
- **Can't coexist** — A trap terrain replaces the floor; in the original, trap + floor + item can all occupy one cell

**Minimum fix:** Add `.TRAP` and `.TRAP_HIDDEN` to `game_can_move_to`. **Correct fix:** Requires Feature object system (traps as objects on floor tiles).

### Issue C: Multi-Level Generation Never Exercised

No call site generates connected levels:

| Call Site | What It Does | `above_map` | `above_down_stairs` |
|-----------|-------------|-------------|---------------------|
| `init_game` | Single level | not passed | not passed |
| `stress_test --all-depths` | Each depth independently | not passed | not passed |
| `dungeon_screenshot` | Single level | not passed | not passed |
| `inspect` | Single level | not passed | not passed |

Flows 2 (stair continuity) and 5 (chasm propagation) are marked "WORKING" based on API review, but have zero runtime coverage. The `generate_makelev` API accepts `above_map` and `above_down_stairs` correctly, but no caller uses them.

### Issue D: Passability Function Inconsistency — RESOLVED (passability)

Trap passability inconsistency fixed: `.TRAP` and `.TRAP_HIDDEN` added to both `terrain_passable` and `game_can_move_to`.

| Terrain | `terrain_passable` (map.jai:60) | `game_can_move_to` (loop.jai:167) | `terrain_solid` (map.jai:66) |
|---------|------|------|------|
| Floor/Corridor/Stairs/Rubble | yes | yes | no |
| Water | **no** | **yes** | no |
| Open door | yes | yes | no |
| Trap/Trap hidden | yes | yes | no |
| Chasm/Lava | no | no | no |

**Remaining inconsistency:** Water is passable in `game_can_move_to` but not in `terrain_passable`. This is intentional — `terrain_passable` is used for general map queries where water may not be walkable, while `game_can_move_to` handles player movement where swimming is possible.

### Issue E: DUN_SPEED Not Implemented

The original calculates encounter CR as: `DepthCR = INITIAL_CR + (Depth * DUN_SPEED) / 100 - 1`

The port has a simplified version (makelev.jai:3831 comment). Without DUN_SPEED, CR scaling with depth may not match the original curve. This affects monster difficulty progression.

### Issue F: Validator Doesn't Check Entry Point

`validate_map` checks room bounds, terrain values, door consistency, entity positions, and connectivity. It does not check:
- Whether depth 1 has an entry point (up-stair or TILE_START)
- Whether `enter_x/enter_y` are set (field doesn't exist yet)
- Whether player spawn position matches entry point

Adding an entry-point check would catch the Flow 1 regression automatically in stress tests.

### Issue G: Test Suite Covers No Cross-Cutting Flows

`test_game_loop` verifies: player in bounds, movement works, determinism, turn advancement. It does not test:
- Entry Chamber placement
- Trap passability
- Dungeon constants application
- Multi-level stair continuity
- Dungeon specials placement

The test suite operates at unit level. Cross-cutting behavior is only testable by running dungeon_test visually or by adding integration tests.

---

**Key findings:**
- ~~**Issue A** is the highest-leverage fix~~ — **RESOLVED** in c5f4169. Dungeon name propagation, entry chamber placement, and generation constants all working.
- **Issue B** (trap terrain model) — passability fixed; the underlying terrain-vs-object mismatch remains a longer-term concern.
- **Issue C** means Flows 2 and 5 have zero runtime coverage despite being marked "WORKING" from code review alone — exactly the kind of gap this document exists to catch.
- **Issue D** — **RESOLVED.** Trap passability added to both `terrain_passable` and `game_can_move_to`.
- **Issues F and G** are process gaps: the validator and test suite don't cover cross-cutting behavior, so regressions in these flows would go undetected.
