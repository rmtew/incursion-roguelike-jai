# Jai Language Reference

**CONSTRAINT**: No access to official Jai distribution except the compiler executable at `C:/Data/R/jai/bin/jai.exe`. All language documentation comes from the local reverse-engineered reference repo.

**Local Reference Repo**: `C:\Data\R\git\jai\` - Contains reverse-engineered Jai documentation including:
- `jai-language.md` - Core language reference with syntax and semantics
- `modules/*.md` - Module documentation for standard library

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
