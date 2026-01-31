# Jai Language Reference

**CONSTRAINT**: No access to official Jai distribution except the compiler executable at `C:/Data/R/jai/bin/jai.exe`. All language documentation comes from the local reverse-engineered reference repo.

**Local Reference Repo**: `C:\Data\R\git\jai\` - Contains reverse-engineered Jai documentation including:
- `jai-language.md` - Core language reference with syntax and semantics
- `modules/*.md` - Module documentation for standard library

## External Reference Sources

Best web sources for Jai language research (quality-ranked):

| Source | URL | Quality | Covers |
|--------|-----|---------|--------|
| The Way to Jai (book) | `github.com/Ivo-Balbaert/The_Way_to_Jai` | Comprehensive | Full language tutorial with chapters on allocators (21A), memory (11A), context (25A), metaprogramming, etc. |
| BSVino/JaiPrimer Wiki | `github.com/BSVino/JaiPrimer/wiki` | Good overview | Memory management, ownership (`!`), pools, context system, compile-time execution |
| Jai-Community Library Wiki | `github.com/Jai-Community/Jai-Community-Library/wiki` | Good | Context system, temporary storage, advanced patterns, compiler overview |
| ForrestTheWoods blog | `forrestthewoods.com/blog/learning-jai-via-advent-of-code/` | Practical | Real-world usage patterns, context/allocator ergonomics, defer patterns |
| Local reference repo | `C:\Data\R\git\jai\` | Authoritative | Module docs, language spec, examples, test code |

**Key pages by topic:**

| Topic | Best Source |
|-------|------------|
| Allocator system | The_Way_to_Jai Ch. 21A, local `modules/Basic.md` |
| Pool/Flat_Pool | Local `modules/Pool.md`, `modules/Flat_Pool.md` |
| Debug allocators | Local `modules/Overwriting_Allocator.md`, `modules/Unmapping_Allocator.md` |
| MEMORY_DEBUGGER | The_Way_to_Jai Ch. 21A (leak report section) |
| Context system | The_Way_to_Jai Ch. 25A, Jai-Community Wiki Advanced |
| Metaprogramming | The_Way_to_Jai Ch. 28+, BSVino Wiki |
| Compiler/build system | Local `jai-language.md`, Jai-Community Wiki Overview |
| String handling | Local `modules/Basic.md`, `modules/String.md` |
| Default allocator stats | Local `modules/Default_Allocator.md` |

**Note**: The `jai.community` forum has relevant threads but its SSL certificate was expired as of 2026-02-01.

## Key Patterns Used in This Project

- `using` for struct composition: `Monster :: struct { using creature: Creature; }`
- `[..]` for dynamic arrays
- `*[..] T` for mutable array pointers
- `#string` for multiline strings (test data)
- `#import "Module"` for module imports
- `#load "file.jai"` for splitting code into files (merges into current scope)
- `temp` / `temporary_allocator` for per-frame scratch allocations (auto-reset)
- `push_allocator(temp)` to use temporary allocator in a scope

## Useful Modules

See `C:\Data\R\git\jai\modules\*.md` for full documentation.

| Module | Purpose |
|--------|---------|
| Basic | Core utilities: print, arrays, strings, memory |
| String | String manipulation, comparison, parsing |
| Math | Math constants, trig, min/max/clamp |
| File | File I/O operations |
| Hash_Table | Hash map implementation |
| Pool | Arena allocator for efficient memory |

## Key Modules for MVP

| Module | Purpose | Location |
|--------|---------|----------|
| Simp | 2D rendering, fonts, colors | `modules/Simp.md` |
| Window_Creation | Window management | `modules/Window_Creation.md` |
| Input | Keyboard/mouse events | `modules/Input.md` |
| GUI_Test | Screenshot capture, synthetic input | `tools/GUI_Test/` |
| Bucket_Array | Stable-handle storage for Registry | `modules/Bucket_Array.md` |
| Pool | Block allocator with reset | `modules/Pool.md` |
| Bit_Array | Memory-efficient FOV/explored maps | `modules/Bit_Array.md` |
| Hash_Table | Resource lookup by name/ID | `modules/Hash_Table.md` |
| PCG | Deterministic RNG | `modules/PCG.md` |
| Relative_Pointers | Save files that survive mmap | `modules/Relative_Pointers.md` |
| Command_Line | CLI args from struct | `modules/Command_Line.md` |
| Iprof | Profiling plugin | `modules/Iprof.md` |
