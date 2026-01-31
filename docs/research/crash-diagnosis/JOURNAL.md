# Crash Diagnosis Research Journal

## 2026-01-31: Initial research and options survey

Investigated Windows crash diagnosis capabilities that Claude can automate, motivated by crashes that bypass the existing assertion-based crash handler.

### Current state assessment

The project has a solid breadcrumb system (`src/debug/crash_handler.jai`) that captures game context at safe checkpoints and writes `crash-report.txt` on assertion failures. Supporting infrastructure includes a state validator, stress tester, replay tool, and headless harness.

**Key gap identified**: Hard crashes (access violations, stack overflows, null dereferences) bypass `debug_assertion_failed` entirely — Windows terminates the process with no crash report generated.

### System inventory

Checked what's available on the development machine:
- `dbghelp.dll` present in System32 (provides MiniDumpWriteDump, StackWalk64, SymFromAddr)
- Windows SDK 10 installed (versions up to 10.0.26100.0)
- Application Verifier installed
- **Not installed**: cdb.exe/WinDbg (debugger tools component), procdump (Sysinternals)

### Options identified

Organized into four tiers by effort level. See README.md for full details. Key findings:

1. **WER LocalDumps** (Tier 1) — registry-only configuration, zero code changes, Windows auto-saves dumps for any crashing process
2. **SEH + MiniDumpWriteDump** (Tier 2) — code change to crash handler, catches hard crashes, generates .dmp files with controlled naming
3. **cdb.exe** (Tier 3) — command-line debugger, installable, enables Claude to parse dump files and extract automated analysis
4. **Application Verifier** (Tier 4) — already installed, useful for heap corruption detection

### Recommended combination

WER LocalDumps (safety net) + SEH handler in crash_handler.jai (controlled dumps) + cdb.exe (automated analysis). This gives a full pipeline from crash capture through automated diagnosis.

### Open questions logged

Recorded questions about Jai PDB generation, Win32 FFI patterns in the project, dump file management, and winget availability. These need answers before implementation can proceed.

### cdb end-to-end test

Built a minimal C test program (`docs/research/crash-diagnosis/test/`) that:
1. Writes an on-demand dump via `MiniDumpWriteDump` (process alive, no exception)
2. Triggers an access violation caught by SEH, writes a crash dump with exception context

Both dumps generated successfully. Then tested cdb analysis from Git Bash.

**What works:**
- `.ecxr; kb` — switches to exception context and prints full stack with symbol names. Resolved `inner_function`, `middle_function`, `outer_function`, `main`. Showed the faulting instruction (`mov dword ptr [rax],7Bh` at NULL address).
- PDB loaded automatically when in the same directory as the exe.
- Dynamic cdb path resolution: `powershell -Command "(Get-AppxPackage *WinDbg*).InstallLocation + '\amd64\cdb.exe'"`

**Issues found and resolved:**
1. **`!analyze -v` hangs** — the default `srv*` symbol path triggers network downloads. Initially worked around with `-y <local-path>` (local only, no network). This made `!analyze -v` fast but degraded — `WRONG_SYMBOLS`, no source lines, no bug classification.
2. **OS symbols matter** — with OS symbols, `!analyze -v` gives exact source file + line number, bug classification (`INVALID_POINTER_WRITE`), null deref detection, and clean stack walks through system frames. Without them the analysis is significantly worse.
3. **Solution: symbol server + local cache** — use `srv*C:\symbols*https://msdl.microsoft.com/download/symbols` in the sympath. First run downloads ~104MB (ntdll, kernel32, etc.), cached to `C:\symbols`. Subsequent runs: ~3 seconds total (666ms analysis + 2.5s init).
4. **Bash `!` expansion** — `!analyze` mangled by bash even in single quotes. **Fix**: `-cf <script-file>` instead of `-c`.
5. **NatVis noise** — filtered with `grep -v NatVis`.

**Recommended cdb invocation:**
```bash
CDB=$(powershell -Command "(Get-AppxPackage *WinDbg*).InstallLocation + '\amd64\cdb.exe'" | tr -d '\r')
"$CDB" -sins -z <dump.dmp> -cf analyze.txt 2>&1 | grep -v NatVis
```
With `analyze.txt` setting sympath to `srv*C:\symbols*https://msdl.microsoft.com/download/symbols;<pdb-dir>`, then `.reload`, `!analyze -v`, `.ecxr`, `kb`, `q`.

### Original Incursion minidump support

Examined the original C++ source. It uses **Google Breakpad** (`ExceptionHandler` with `HANDLER_ALL`) but the important pattern is the on-demand usage: the `Error()` function presents `[M]inidump, [E]xit or [C]ontinue?` and pressing M calls `WriteMinidump()` while the process is alive. This isn't just crash recovery — it's a general diagnostic tool for inspecting runtime state at any error.

**Reframed the sub-project scope**: dumps are a general diagnostic artifact produced from multiple trigger points (SEH handler, assertion handler, stress test failures, on-demand), not just a crash catcher. Breakpad itself isn't needed — it wraps the same `dbghelp.dll` APIs we'd call directly. The value is the pattern: call `MiniDumpWriteDump` from anywhere, analyze with cdb later.

## 2026-01-31: Tier 2 implementation — minidump support in crash_handler.jai

Implemented the core dump utility and all three planned trigger points.

### What was implemented

1. **`debug_write_minidump(exception_pointers: *EXCEPTION_POINTERS = null) -> bool`** — Core callable function. Creates `crash-dumps/` directory via `CreateDirectoryA`, builds filename with seed/depth context, opens file via `CreateFileA`, fills `MINIDUMP_EXCEPTION_INFORMATION` if exception pointers provided, calls `MiniDumpWriteDump` with `MiniDumpWithDataSegs` flag.

2. **`debug_seh_handler`** — `#c_call` function registered as the unhandled exception filter. Uses `push_context` to get a default Jai context, then calls `write_crash_report` and `debug_write_minidump` with exception pointers.

3. **`debug_init()` changes** — Calls `SetUnhandledExceptionFilter(debug_seh_handler)` and `SetErrorMode(.SEM_FAILCRITICALERRORS | .SEM_NOGPFAULTERRORBOX)` to suppress the Windows error dialog.

4. **`debug_assertion_failed()` changes** — Calls `debug_write_minidump()` (no exception pointers) after writing the text crash report.

5. **`stress_test.jai` integration** — `debug_write_minidump()` called before `add_failure()` at all three failure sites.

6. **`.gitignore`** — Added `crash-dumps/` and `*.dmp`.

### Jai implementation notes

- **`Context` is not a named type** — Can't declare `g_saved_context: Context;` at global scope. The plan called for saving the context at `debug_init()` time for use in the `#c_call` SEH handler. Solution: `push_context` without arguments in the handler creates a default context with working allocators. This is the documented pattern from the Jai language reference for `#c_call` functions (see `jai-language.md` line 755-756).

- **Win32 constants** — `GENERIC_WRITE` (0x40000000), `CREATE_ALWAYS` (2), `FILE_ATTRIBUTE_NORMAL` (0x80) are used as inline hex values. The Jai Windows module `.md` only documents functions, structs, and enums — it's unclear whether these `#define`-style constants are exported. Inline hex avoids redefinition errors.

- **`INVALID_HANDLE_VALUE` check** — Implemented as `cast(u64) file == 0xFFFF_FFFF_FFFF_FFFF` since INVALID_HANDLE_VALUE is `(HANDLE)(-1)`.

- **`#import "Windows"` in a `#load`ed file** — crash_handler.jai is `#load`ed by all 9 entry points. The import becomes available to all. Jai's Windows module is declarations only — no runtime cost unless functions are called. Confirmed: all 9 targets compile and link (DbgHelp.lib already in link lines).

### Verification

- All 9 build targets compile successfully
- Test suite: 213/217 pass (4 pre-existing parser failures, no regressions)
- Dumps not yet tested at runtime (requires triggering a crash or assertion failure)

## 2026-01-31: cdb automation flow validated end-to-end

### Problem: Claude Code approval friction

Running cdb directly requires user approval for each invocation. The command arguments (dump path, script file) change between runs, so "allow similar" doesn't match across invocations.

**Solution**: Wrapper scripts. A single `bash analyze-dump.sh <dump>` command gets one approval, then "allow similar" covers all subsequent invocations with different dump paths. Two scripts created in `docs/research/crash-diagnosis/test/`:

- **`analyze-dump.sh`** — post-mortem analysis of `.dmp` files. Resolves cdb path dynamically, sets up symbol server with local cache, runs `!analyze -v` + `.ecxr` + `kb`.
- **`attach-dump.sh`** — live-attach to a running/hung process. Dumps all thread stacks (`~*kb`), writes a full dump for follow-up, then detaches (process continues).

### Test results: crashtest.c dumps

Both scripts validated against the C test program's dumps:

**Crash dump** (`crash.dmp`) — full analysis with:
- Bug classification: `INVALID_POINTER_WRITE`
- Source location: `crashtest.c:47`
- Stack trace with symbol names through all frames
- Null dereference detection: `AV.Dereference: NullPtr`

**On-demand dump** (`ondemand.dmp`) — `.ecxr` correctly reports "no exception context." `!analyze -v` gives a `BREAKPOINT` classification (expected — no crash to analyze). For on-demand dumps, the stack shows `MiniDumpWriteDump` internals, not application state.

**Key insight**: `!analyze -v` is for crash dumps. For on-demand/hang dumps, `~*kb` (all thread stacks) is the primary diagnostic tool.

### Real-world test: regen crash diagnosed via live-attach

The known regen crash (`--count 5 --regen`) couldn't be reproduced as a clean crash — individual seeds pass, but multi-seed runs appear to hang. Used `attach-dump.sh` to diagnose the live process.

**Finding: double-fault, not a hang.** Thread 0 stack trace revealed:

1. **Original fault**: `array_add(T=DoorInfo)` in `place_doors_makelev` → `reallocate` → `allocate_medium` — allocator corruption during realloc of the doors array.
2. **SEH handler fires**: `UnhandledExceptionFilter` → `debug_seh_handler`.
3. **Secondary fault**: `debug_seh_handler` calls `tprint` → `builder_to_string` → `alloc` → `temporary_allocator_proc` → `allocate` — crashes again because the allocator is corrupt.
4. **Result**: Process stuck in the secondary fault inside the exception filter. Windows can't dispatch a second exception from within `UnhandledExceptionFilter`, so the process appears hung.

**Two bugs identified**:
1. **Root cause**: Stale array state after `free_game`/`init_game` regen cycle. `map_free()` and `map_init()` don't handle the `features` array, leading to leaked/stale dynamic array metadata. The allocator corruption likely comes from the stale `doors` array metadata (doors IS freed/reset, but the corruption propagates through the allocator's internal state from the leaked features allocation).
2. **SEH handler safety**: `debug_seh_handler` uses `tprint` which depends on a working allocator. When the crash IS an allocator corruption, the handler itself crashes. Needs a guard against re-entry or a pre-allocated buffer strategy.

## 2026-01-31: SEH handler made allocator-safe + regen investigation

### SEH handler rewrite

Eliminated all allocator dependencies from `debug_seh_handler`:

1. **Re-entry guard** — `g_seh_in_progress` global flag prevents double-fault when the handler itself crashes.
2. **Fixed-buffer formatting** — Six `#c_call`-safe helpers (`seh_append_str`, `seh_append_u64`, `seh_append_s32`, `seh_append_hex`, `seh_append_bool`, `seh_append_gen_step`) format into a `[2048] u8` stack buffer using `while` loops (not `for`, which requires Jai context).
3. **Minidump-first ordering** — `seh_write_minidump` (most valuable artifact) runs before `seh_write_crash_report`.
4. **Win32-only I/O** — `CreateFileA`/`WriteFile`/`CloseHandle` instead of `write_entire_file`.

No `push_context`, no `tprint`, no allocator calls in the SEH path. Existing `write_crash_report` and `debug_write_minidump` unchanged — still used by the assertion handler and stress test where the allocator is intact.

**Jai #c_call constraint**: `for` loops require context (dispatch through `for_expansion`), so all helpers use `while` loops. `gen_step_name` (non-`#c_call`) can't be called from a `#c_call` function, so a separate `seh_append_gen_step` was added.

### Features array lifecycle fix

`GenMap.features` (`[..] EntityPos`) was missing from both `map_free` and `map_init`. Added `array_free(m.features)` and `array_reset(*m.features)` alongside the other dynamic arrays. This was originally identified as the root cause of the regen crash, but the crash persists after the fix.

### Regen crash investigation

With the SEH handler now working, `stress_test.exe --count 5 --regen` produces a valid crash dump and report instead of hanging. Analysis:

**Crash dump findings** (`crash-seed2-depth1.dmp`):
- Failure bucket: `INVALID_POINTER_READ_c0000005_stress_test.exe!allocate_medium`
- Faulting instruction: `mov rax, qword ptr [rax]` with `rax=0x10` — following a corrupted free-list pointer
- Stack: `allocate_medium` → `allocate` → `reallocate` → `allocator_proc` → `realloc` → `array_add(T=Room)` → `place_doors_makelev` → `generate_makelev`
- The `T=Room` symbol is likely debugger symbol dedup — `place_doors_makelev` only calls `array_add(*m.doors, door)` where `door: DoorInfo`

**Reproduction testing**:
- `--count 20` (no regen): PASSES — 20 seeds with determinism check (each generates twice)
- `--seed 2 --no-determinism` (no regen): PASSES — seed 2 alone is fine
- `--seed 1 --no-determinism --regen`: CRASHES — seed 1 → free → seed 2
- `--seed 1 --regen` (with determinism): PASSES — the extra gs2 allocation shifts heap layout enough to mask corruption
- `--count 5 --regen`: CRASHES

**Conclusion**: Heap corruption occurs during the `free_game` → `init_game` regen cycle, not during fresh generation. The corruption source is upstream of PLACE_DOORS — some earlier step writes to freed memory or overflows a buffer, but it only manifests when heap blocks from the first generation are reused.

**Code analysis** (no smoking gun found):
- All local `[..]` arrays in makelev.jai use `temp` allocator — not heap leaks
- No pointer-invalidation pattern found (no `array_add(*m.rooms)` during room iteration)
- `map_free` → `map_init` → `array_add` lifecycle appears correct
- `GenState` is stack-local, `MapGenInfo` uses fixed-size arrays with bounds checks

**Untested hypothesis**: `reset_temporary_storage()` in `free_game` before regen. Temp overflow pages accumulate across generations; if the allocator interacts badly with fragmented heap from overflow pages, resetting temp could help. Deferred for now.

**Recommended next steps**: Application Verifier heap checks (`appverif -enable Heaps -for stress_test.exe`) would pinpoint the exact write that corrupts heap metadata.

### Workflow summary

Two operational modes for Claude-driven debugging:

| Mode | Script | When to use | Key commands |
|------|--------|-------------|--------------|
| Post-mortem | `analyze-dump.sh <dump> [pdb-dir]` | Crash dumps from SEH handler or assertions | `!analyze -v`, `.ecxr`, `kb` |
| Live-attach | `attach-dump.sh <exe-or-pid>` | Hung or stuck processes | `~*kb` (all thread stacks) |

Both resolve cdb dynamically, handle symbol server setup, and produce deterministic output for Claude to parse.

## 2026-02-01: Regen crash resolved

The regen crash was ultimately diagnosed not through cdb/minidump analysis but via Jai's `Overwriting_Allocator`, which fills freed memory with `0xDE`. This made both root causes immediately visible.

### Root causes

1. **Double-free**: `array_free` (Jai beta 0.2.025) does not null the `data` pointer in dynamic array headers. `map_free` freed backing storage but left dangling pointers. `map_init`'s `array_reset` then freed those pointers again. Fix: null data pointers after `array_free`.

2. **Use-after-free**: `terrain_registry_add` stored `*RuntimeTerrain` pointers into a `[..] RuntimeTerrain` that could grow, invalidating all stored pointers on realloc. Fix: build hash table index only after array is fully populated.

### Retrospective

The earlier cdb-based investigation correctly identified that the corruption was upstream of `place_doors_makelev` and occurred during the regen cycle. The `Overwriting_Allocator` approach was more effective for this class of bug because it makes the corrupted data immediately identifiable (all bytes read as `0xDE`), whereas cdb only sees the downstream crash after heap metadata is corrupted.

See `docs/research/memory-allocation/` for the full investigation log.
