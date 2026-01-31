# Memory Allocation Research — Journal

## 2026-02-01: Initial Audit

### Scope

Full inventory of memory allocation across the codebase (40 .jai files, 7 subsystems). Cross-referenced with Jai allocator documentation from:
- Local reference repo (`C:\Data\R\git\jai\modules\`)
- BSVino/JaiPrimer GitHub wiki
- Ivo-Balbaert/The_Way_to_Jai chapters 11A, 21A, 25A
- Jai-Community wiki

### Key Findings

**1. All allocation goes through the default heap allocator (rpmalloc)**

No custom allocators, no Pool/Flat_Pool usage, no `push_context` with alternate allocators. Every `New`, `array_add`, and `copy_string` hits the global heap. This is the simplest approach but creates maximum fragmentation and makes cleanup errors (the regen crash) inevitable.

**2. Dungeon generation is the heaviest allocator user**

`makelev.jai` alone creates ~15 temporary dynamic arrays per generation pass (flood fill stacks, edge lists, grids, paths, visited arrays). Each one individually allocates from the heap and must be individually freed. This is the most likely source of the regen crash — a single missing `array_free` or a stale pointer after `map_free` corrupts the heap.

**3. Lifetime mismatch: function-scoped arrays use heap allocation**

Arrays like flood fill stacks and cellular automata grids live for <1ms but go through `alloc`/`realloc`/`free` cycles. These should use `temp` allocator — zero overhead, zero cleanup required.

**4. Per-level data uses individual heap allocations instead of an arena**

`GenMap` fields (rooms, monsters, items, doors, etc.) all allocate independently and must each be freed in `map_free`. A Pool allocator scoped to the level would let us `release(*pool)` once and guarantee complete cleanup — no missing-free bugs possible.

**5. The Stati free-list is the only pooling pattern**

`object.jai` maintains a linked free-list for `Stati` objects. This is efficient for high-churn small objects. No other subsystem uses pooling.

**6. String copies in bake.jai may leak**

`bake.jai` calls `copy_string` ~15 times to persist strings past the parser's lifetime. These strings end up in runtime resource arrays that live for the entire program. Not a leak per se (they're intentionally long-lived), but they're never freed. Should be marked with `this_allocation_is_not_a_leak()` if we enable MEMORY_DEBUGGER.

### Crash Diagnosis Context

The regen crash (documented in `docs/research/crash-diagnosis/`) showed:
- Corrupted free-list pointer in `allocate_medium` during `array_add` in `place_doors_makelev`
- Only happens after `free_game` → `init_game` cycle (not on fresh generation)
- `features` array was missing from `map_free`/`map_init` (fixed, crash persists)
- Heap layout sensitivity: enabling determinism mode shifts allocations enough to mask the bug

**Hypothesis**: The corruption is from a missing cleanup in the `map_free` cascade, or from a dangling pointer to freed memory being written through during the next generation. A Pool-based approach would eliminate this entire class of bug.

### Recommended Approach

**Phase 1 — Diagnosis (find the exact bug):**
- Enable `MEMORY_DEBUGGER=true` on stress_test to get a leak report
- Use `Overwriting_Allocator` to catch use-after-free
- Add `DefaultAlloc.global_statistics()` before/after regen to measure leak size

**Phase 2 — Quick wins (temp allocator for function-scoped arrays):**
- Set `.allocator = temp` on all temporary arrays in `makelev.jai`
- Remove corresponding `array_free`/`defer` calls
- This reduces heap pressure and eliminates a class of cleanup bugs

**Phase 3 — Structural fix (Pool for per-level allocation):**
- Create a `Pool` in `generate_makelev`, pass via context
- All `GenMap` arrays, BSP nodes, weight arrays allocate from the pool
- `map_free` becomes `release(*pool)` — one call, complete cleanup
- This eliminates the regen crash by design

**Phase 4 — Verification:**
- Stress test with `--regen` flag passes
- MEMORY_DEBUGGER shows no leaks
- DefaultAlloc stats show stable memory across regen cycles

## 2026-02-01: Leak Fixes Implemented

### Phase 1: GenState + Stair Array Leaks (from plan)

**Problem:** Every call to `generate_makelev` leaked GenState internals (~8-16 KB) and the caller `generate_dungeon_original` discarded the returned `down_stairs` array.

**Fixes applied:**
1. Created `gen_state_free()` calling `terrain_registry_free` + `free_dungeon_weights` (makelev.jai)
2. Added `defer gen_state_free(*gs)` after `gen_state_init` in `generate_makelev`
3. Added `defer array_free(up_stairs)` after `place_up_stairs`
4. Captured and freed discarded `down_stairs` return in `generate_dungeon_original` (generator.jai)

**Dead code removed:** Legacy `write_streamer` overload (makelev.jai:3336-3352) that created and leaked a GenState with no callers.

**Minor cleanup:** Switched `validate_doors` `to_remove` array from heap+defer to `.allocator = temp`.

**Stress test diagnostics:** Added `Default_Allocator` import to stress_test.jai with `global_statistics()` logging before/after regen cycles and memory summary at end of run. Growth >64 KB flagged as test failure.

### Full Codebase Audit

Ran three parallel exploration agents covering:
1. All heap allocation sites (array_add, New, copy_string, table operations)
2. All free/cleanup functions and their callers
3. Struct lifecycle and ownership graph

**Results:** 152+ allocation sites found. Cross-referenced all three reports.

### Additional Leaks Found and Fixed

**1. Parser + token arrays in `parse_resource_file` (bake.jai:26-28)**

Largest leak. `parser_free()` existed but was never called. `lexer_tokenize_all()` returned a dynamic array never freed. Called 8 times (once per `.irh` file) at startup. Each parse created 16+ dynamic arrays that were abandoned after conversion.

Fix: Added `defer array_free(tokens)` and `defer parser_free(*parser)`.

**2. `to_lower_copy` string keys in `terrain_registry_add` (terrain_registry.jai:61)**

Each `terrain_registry_add` call allocated a lowercase string via `to_lower_copy()` as a hash table key. `Table.deinit()` frees bucket storage but not string keys. ~50 strings leaked per generation cycle.

Fix: Added key iteration and free in `terrain_registry_free` before `deinit`.

### False Positives Dismissed

- **`gen_info.cells`**: Fixed-size array `[MAP_WIDTH * MAP_HEIGHT] CellInfo` embedded in struct. No heap allocation.
- **`free_command_log` never called**: IS called in replay.jai:100 and suites.jai:1121.
- **`free_game` never called in main.jai**: main.jai doesn't run a game loop yet. All tools/tests that create GameState call it.

### Verification

- `./build.bat game test stress_test` — all three compile
- `./src/tests/test.exe` — 213/217 pass (4 pre-existing parser failures, unchanged)
- `./tools/stress_test.exe --count 20` — 20/20 pass
- Regen crash persists — pre-existing, not caused by leak fixes (also crashes on unmodified code)

### Files Changed

- `src/dungeon/makelev.jai` — gen_state_free, defer, dead code removal, temp allocator
- `src/dungeon/generator.jai` — free discarded down_stairs
- `src/dungeon/terrain_registry.jai` — free hash table string keys
- `src/resource/bake.jai` — defer parser_free + array_free(tokens)
- `tools/stress_test.jai` — Default_Allocator import, memory diagnostics

## 2026-02-01: Regen Crash Root Cause Found and Fixed

### Approach

Wired `Overwriting_Allocator` into stress test via `--debug-alloc` flag. The allocator fills freed memory with `0xDE`, making use-after-free and double-free immediately detectable.

### Bug 1: Double-free in map_free → map_init

**Discovery**: Running with `--debug-alloc --regen` produced 4 "previously freed" errors. Print fences narrowed the location to inside `map_init`. Pointer tracing in `map_free` showed `array_free` does not null the `data` pointer — the freed pointers were still in the array headers when `map_init`'s `array_reset` freed them again.

**Root cause**: Jai's `array_free` frees backing memory but does NOT zero the array header's `data` field. `array_reset` (called in `map_init`) frees any non-null `data` pointer before zeroing. On regen, `map_free` → `array_free` leaves dangling pointers, then `map_init` → `array_reset` double-frees them.

**Fix**: Null `data` pointer after each `array_free` in `map_free`.

### Bug 2: Use-after-free in terrain registry

**Discovery**: After fixing bug 1, the debug allocator revealed a cast bounds check failure: `fg_color` read as `0xDEDEDEDEDEDEDEDE` — the overwrite pattern from freed memory. This meant code was reading through a pointer to freed memory.

**Root cause**: `terrain_registry_add` stored `*RuntimeTerrain` pointers (into the `terrains` `[..] RuntimeTerrain` dynamic array) in the hash table. When later `array_add` calls grew the array, the backing was reallocated at a new address and the old backing freed. All stored pointers became dangling.

**Fix**: Split `terrain_registry_add` into array-only (no hash table) and `terrain_registry_build_index` (builds hash table after all entries added, when array is stable).

### Jai Lessons Learned

1. **`array_free` does not zero the header**: After `array_free`, `data` still points to freed memory. Must manually null it if the array will be reused.
2. **Never store pointers into `[..] T`**: Dynamic array pointers are invalidated by growth. Build pointer indexes only after the array is complete.

### Verification

- `./tools/stress_test.exe --count 100 --regen --debug-alloc` — 100/100 pass
- `./tools/stress_test.exe --count 100 --regen` — 100/100 pass
- `./src/tests/test.exe` — 213/217 pass (4 pre-existing)

### Files Changed

- `src/dungeon/map.jai` — null data pointers after array_free in map_free
- `src/dungeon/terrain_registry.jai` — split add/build_index, pointer invalidation fix
- `tools/stress_test.jai` — Overwriting_Allocator support (`--debug-alloc` flag)
