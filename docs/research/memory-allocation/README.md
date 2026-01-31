# Memory Allocation Research

## Problem Statement

Stress testing revealed heap corruption during dungeon regeneration cycles (`free_game` → `init_game`). The crash manifests in `allocate_medium` with a corrupted free-list pointer (`0x10`), suggesting upstream write-after-free or buffer overflow. A partial fix (adding `features` array to cleanup) did not eliminate the crash.

Beyond the immediate corruption, the codebase has never had a systematic memory allocation audit. All allocation goes through Jai's default rpmalloc-based allocator with no use of arenas, pools, or lifetime-scoped allocation — despite Jai having strong built-in support for these patterns.

**Goals:**
1. Inventory all allocation sites and classify by lifetime
2. Identify leaks, missing frees, and cleanup gaps
3. Design an allocator strategy using Jai's Pool/Flat_Pool modules
4. Instrument with MEMORY_DEBUGGER to find the regen crash root cause
5. Implement fixes

## Current Allocation Inventory

### Allocation Mechanisms Used

| Mechanism | Count | Files |
|-----------|-------|-------|
| Dynamic arrays `[..]` | ~45 declarations | map.jai, weights.jai, parser.jai, bake.jai, makelev.jai, log.jai, creature.jai |
| `array_add` | ~90+ calls | makelev.jai (heaviest), bake.jai, weights.jai, log.jai, map.jai |
| `New(T)` | ~12 calls | generator.jai (BSPNode), object.jai (Stati), suites.jai (GameState) |
| `NewArray` | 1 call | map.jai (LocationInfo cells) |
| `copy_string` | ~15 calls | bake.jai (string persistence), parser.jai (macro args), terrain_registry.jai |
| `read_entire_file` | 2 calls | bake.jai, suites.jai |
| Hash Table | 1 instance | terrain_registry.jai |

### Cleanup Functions

| Function | Location | Frees |
|----------|----------|-------|
| `free_game(gs)` | game/loop.jai:44 | Calls `map_free` |
| `map_free(m)` | dungeon/map.jai:237 | rooms, monsters, items, features, doors, torch_positions, cell contents |
| `gen_state_free(gs)` | dungeon/makelev.jai:467 | Calls `terrain_registry_free` + `free_dungeon_weights` |
| `parser_free(p)` | resource/parser.jai:692 | All 16 parsed resource arrays |
| `free_dungeon_weights(w)` | dungeon/weights.jai:547 | room_regions, corridor_regions, vault_regions, corridor_weights |
| `terrain_registry_free(r)` | dungeon/terrain_registry.jai:49 | Hash table string keys + hash table + terrains array |
| `free_command_log(l)` | game/log.jai:145 | entries array |
| `thing_free_stati(t)` | object.jai:110 | Walks stati linked list, returns to free list |

### Allocation Patterns by Subsystem

**Dungeon Generation (heaviest allocator user):**
- `makelev.jai` creates many temporary `[..]` arrays per generation pass (flood fill stacks, edge lists, grids, paths, vault lists)
- Most local arrays are allocated from the heap, used within a function, then freed
- BSP tree nodes are individually `New`-allocated and `free`-d
- Room/monster/item/feature arrays persist in `GenMap` until `map_free`

**Resource System:**
- Parser allocates 16 dynamic arrays, freed by `parser_free`
- Baking copies strings with `copy_string` for persistence after parser is freed
- Runtime resource arrays are fixed slices (not dynamic) — no leak concern

**Game State:**
- `GameState` is `New`-allocated (~300KB due to embedded `GenMap` fixed arrays)
- `map.cells` is `NewArray`-allocated per map init
- Location contents are per-cell dynamic arrays

**Object System:**
- Stati uses a free-list pool pattern (good — avoids allocation churn)

## Lifetime Classification

Using Jon Blow's four lifetime categories:

### Category 1: Extremely Short-Lived (function scope)
**Should use: `temp` allocator or stack**

| Site | Current | Recommended |
|------|---------|-------------|
| `makelev.jai` flood fill stacks | heap `[..]` | `temp` allocator |
| `makelev.jai` edge lists | heap `[..]` | `temp` allocator |
| `makelev.jai` cellular automata grids | heap `[..]` | `temp` allocator |
| `makelev.jai` path arrays | heap `[..]` | `temp` allocator |
| `makelev.jai` vault lists | heap `[..]` | `temp` allocator |
| `makelev.jai` visited arrays | heap `[..]` | `temp` allocator |
| ~~`terrain_registry.jai` `to_lower_copy`~~ | ~~heap string~~ | ~~`tprint` / temp~~ (FIXED: keys freed in `terrain_registry_free`) |

These are all created, used, and freed within single functions. Using `temp` would eliminate ~30 individual `array_free`/`defer` calls and avoid fragmenting the heap during generation.

### Category 2: Short-Lived, Well-Defined Lifetime (per-level)
**Should use: `Pool` or `Flat_Pool`**

| Site | Current | Recommended |
|------|---------|-------------|
| `GenMap.rooms` | heap `[..]` | Pool (per-level) |
| `GenMap.monsters` | heap `[..]` | Pool (per-level) |
| `GenMap.items` | heap `[..]` | Pool (per-level) |
| `GenMap.features` | heap `[..]` | Pool (per-level) |
| `GenMap.doors` | heap `[..]` | Pool (per-level) |
| `GenMap.torch_positions` | heap `[..]` | Pool (per-level) |
| `map.cells[].contents` | heap `[..]` per cell | Pool (per-level) |
| BSP tree nodes | individual `New` | Pool (per-level) |
| `DungeonWeights` arrays | heap `[..]` | Pool (per-level) |
| `TerrainRegistry` | heap + hash table | Pool (per-level) |

All of these are created during `generate_makelev` and freed during `map_free`. A single Pool allocated at generation start and released at `map_free` would:
- Eliminate individual `array_free` calls and the risk of missing one
- Make the regen crash impossible (whole pool freed, no stale pointers)
- Reduce heap fragmentation

### Category 3: Long-Lived, Clear Owner (game session)
**Current approach is fine — heap allocation with explicit free**

| Site | Owner |
|------|-------|
| `GameState` | Game loop |
| Baked resource strings | Resource system (program lifetime) |
| Runtime resource arrays | Resource system (program lifetime) |

### Category 4: Long-Lived, Unclear Owner
**Should be rare — currently none identified (good)**

## Leaks Fixed (2026-02-01)

| Leak | Location | Fix |
|------|----------|-----|
| GenState internals (terrain registry + dungeon weights) | makelev.jai | `gen_state_free()` + `defer` after `gen_state_init` |
| `up_stairs` return array | makelev.jai | `defer array_free(up_stairs)` |
| `down_stairs` discarded return | generator.jai | Capture and `array_free` |
| Parser arrays (16 dynamic arrays x8 files) | bake.jai | `defer parser_free(*parser)` |
| Token arrays from lexer (x8 files) | bake.jai | `defer array_free(tokens)` |
| `to_lower_copy` hash table keys | terrain_registry.jai | Iterate and free keys before `deinit` |
| Dead code GenState leak | makelev.jai | Deleted unused legacy `write_streamer` overload |
| `validate_doors` `to_remove` array | makelev.jai | Switched to `.allocator = temp` |

## Regen Crash Root Cause (2026-02-01)

The regen crash (heap corruption in `allocate_medium` during `free_game` → `init_game` cycle) was caused by two bugs:

### Bug 1: Double-free in map_free → map_init

**`array_free` does not zero the data pointer** in the array header. It frees the backing memory but leaves `data` pointing to freed memory. When `map_init` is called on reuse, `array_reset` sees a non-null `data` pointer and frees it again — double-free.

- **4 affected arrays**: rooms, monsters, items, doors (features and torch_positions had no entries, so their data was already null)
- **Fix**: Null data pointers after each `array_free` in `map_free`
- **Jai lesson**: `array_free` ≠ `memset(0)`. Always null the data pointer after freeing a dynamic array that may be reused.

### Bug 2: Use-after-free in terrain registry (pointer invalidation)

`terrain_registry_add` stored `*RuntimeTerrain` pointers (pointing into the `terrains` dynamic array) in the hash table. When subsequent `array_add` calls caused the `terrains` array to grow and reallocate, all stored pointers became dangling.

During generation, `resolve_region_terrains` and terrain lookups dereferenced these dangling pointers. With the overwriting allocator, the freed memory was filled with `0xDE`, causing `fg_color` values to read as `0xDEDEDEDEDEDEDEDE` — caught by a cast bounds check.

- **Fix**: Separated `terrain_registry_add` (array-only) from `terrain_registry_build_index` (builds hash table after all entries are added, when the array is stable)
- **Jai lesson**: Never store pointers into a `[..] T` that may grow. Build pointer-based indexes only after the array is complete.

### Discovery Method

Wired `Overwriting_Allocator` (fills freed memory with `0xDE`) into the stress test via `--debug-alloc` flag. Added print fences to narrow down the crash location through binary search of the call stack.

## Jai Allocator Reference

### Available Modules

| Module | Type | Use Case |
|--------|------|----------|
| `Pool` | Block-based arena | Same-lifetime objects, per-level allocation |
| `Flat_Pool` | Virtual-memory arena | Linear allocation, single reset, minimal overhead |
| `Default_Allocator` | rpmalloc wrapper | Stats via `global_statistics()` for leak monitoring |
| `Overwriting_Allocator` | Debug | Fills freed memory with pattern, catches use-after-free |
| `Unmapping_Allocator` | Debug | Unmaps pages on free, immediate crash on use-after-free |

### Key APIs

**Pool (recommended for dungeon generation):**
```jai
#import "Pool";
pool: Pool;
set_allocators(*pool);
defer release(*pool);

// Use as context allocator for a scope:
pool_alloc := Allocator.{pool_allocator_proc, *pool};
new_ctx := context;
new_ctx.allocator = pool_alloc;
push_context new_ctx {
    // All allocations (including array_add) use the pool
    // No individual frees needed — release(*pool) frees everything
}
```

**MEMORY_DEBUGGER (for finding the regen leak):**
```jai
#import "Basic"()(MEMORY_DEBUGGER=true);
// At program end:
report := make_leak_report();
log_leak_report(report);
```

**DefaultAlloc statistics (lightweight monitoring):**
```jai
DefaultAlloc :: #import "Default_Allocator";
stats := DefaultAlloc.global_statistics();
print("Mapped: % bytes, Peak: %\n", stats.mapped, stats.mapped_peak);
```

**Overwriting_Allocator (for debugging use-after-free):**
```jai
#import "Overwriting_Allocator";
alloc := get_overwriting_allocator(overwrite_byte = 0xDE);
defer deinit_overwriting_allocator(alloc);
// Freed memory reads as 0xDEDEDEDE — easy to spot in debugger
```

**Temp allocator for dynamic arrays:**
```jai
stack: [..] Point;
stack.allocator = temp;  // No free needed, cleared with reset_temporary_storage()
array_add(*stack, point);
```

### Comma-Comma Operator
```jai
node := New(BSPNode,, allocator = temp);  // Single allocation override
```

## References

- [BSVino/JaiPrimer Wiki — Memory Management](https://github.com/BSVino/JaiPrimer/wiki/memory-management)
- [The_Way_to_Jai — Ch. 21A: Memory Allocators and Temporary Storage](https://github.com/Ivo-Balbaert/The_Way_to_Jai/blob/main/book/21A_Memory_Allocators_and_Temporary_Storage.md)
- [The_Way_to_Jai — Ch. 11A: Allocating and Freeing Memory](https://github.com/Ivo-Balbaert/The_Way_to_Jai/blob/main/book/11A_Allocating_and_freeing_memory.md)
- [The_Way_to_Jai — Ch. 25A: Context](https://github.com/Ivo-Balbaert/The_Way_to_Jai/blob/main/book/25A_Context.md)
- [Jai-Community Wiki — Advanced](https://github.com/Jai-Community/Jai-Community-Library/wiki/Advanced)
- Local: `C:\Data\R\git\jai\modules\Pool.md`
- Local: `C:\Data\R\git\jai\modules\Flat_Pool.md`
- Local: `C:\Data\R\git\jai\modules\Default_Allocator.md`
- Local: `C:\Data\R\git\jai\modules\Overwriting_Allocator.md`
- Local: `C:\Data\R\git\jai\modules\Unmapping_Allocator.md`
- Crash diagnosis: `docs/research/crash-diagnosis/`
