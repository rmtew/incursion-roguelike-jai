# Memory Allocation Research — Backlog

## Phase 1: Diagnosis

- [x] Add `DefaultAlloc.global_statistics()` logging before/after each regen cycle (in stress_test.jai)
- [x] Audit `map_free` completeness — compare every field of `GenMap` against its cleanup
- [x] Full codebase allocation audit (all allocation sites, cleanup functions, struct lifecycles)
- [x] Try `Overwriting_Allocator` to catch use-after-free patterns — found and fixed 2 bugs:
  - Double-free: `array_free` doesn't null data pointer → `array_reset` frees again (map.jai)
  - Use-after-free: `terrain_registry_add` stored pointers into growing `[..] RuntimeTerrain` → dangling after realloc (terrain_registry.jai)
- [ ] Enable `MEMORY_DEBUGGER=true` in stress_test build and capture leak report
- [ ] ~~Try `Unmapping_Allocator`~~ (not needed — overwriting allocator was sufficient)
- [ ] ~~Try Windows Application Verifier~~ (not needed)

## Phase 2: Temp Allocator for Function-Scoped Arrays

Candidate sites in `makelev.jai`:
- [x] Flood fill stacks (`stack: [..] Point`)
- [x] Connected/unconnected edge lists
- [x] Cellular automata grids (`grid`, `next_grid`)
- [x] Pathfinding stacks and visited arrays
- [x] Life game grids
- [x] Corridor path arrays
- [x] Panel edge arrays
- [x] Valid vault index arrays
- [x] Removal tracking arrays
- [x] Maze stacks, best pairs, all_stairs, vault lists
- [x] `up_stairs` in `generate_makelev` (via `place_up_stairs`)

**Note:** `down_stairs` intentionally stays heap-allocated — it's the return value of `generate_makelev` and ownership transfers to the caller.

Each change: set `.allocator = temp`, remove corresponding `array_free`/`defer`.

## Phase 3: Pool Allocator for Per-Level Data

- [ ] `#import "Pool"` in dungeon module
- [ ] Create pool in `generate_makelev`, store in GenMap or pass via context
- [ ] Route GenMap dynamic arrays through pool (rooms, monsters, items, features, doors, torch_positions)
- [ ] Route map cell contents arrays through pool
- [ ] Route BSP tree nodes through pool (replace individual `New`/`free`)
- [ ] Route DungeonWeights arrays through pool
- [ ] Route TerrainRegistry through pool
- [ ] Replace `map_free` cascade with single `release(*pool)`
- [ ] Test: stress_test with `--regen` passes
- [ ] Test: memory stable across 100+ regen cycles

## Phase 4: Verification & Monitoring

- [ ] MEMORY_DEBUGGER leak report clean
- [ ] DefaultAlloc.global_statistics() stable across regen
- [ ] Mark intentional long-lived allocations with `this_allocation_is_not_a_leak()`
- [x] Stress test: `--count 100 --regen` no crash, no growth
- [ ] Remove or gate MEMORY_DEBUGGER behind debug build flag

## Deferred / Ideas

- **Pool for Stati**: Replace free-list with Pool allocation (lower priority — free-list works)
- **Flat_Pool**: Consider for dungeon generation if Pool overhead is measurable (unlikely)
- **Per-frame temp reset**: If game loop processes frames, reset_temporary_storage() per frame
- **Memory budget**: Log peak allocation per level to understand memory profile
- **Compile-time allocation**: Some resource data could be `#run`-baked into read-only data segment
