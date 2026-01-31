# Windows Crash Diagnosis Automation

**Status**: Tier 2 + Tier 3 operational — allocator-safe SEH handler + minidump generation + cdb automation scripts for post-mortem and live-attach debugging.
**Goal**: Produce minidumps as a general diagnostic artifact — both on-demand and on crash — for automated analysis via cdb.

## Current Infrastructure

The project has a breadcrumb-based crash handler (`src/debug/crash_handler.jai`) and supporting tools:

| Component | Location | Purpose |
|-----------|----------|---------|
| Crash handler | `src/debug/crash_handler.jai` | Assertion handler, breadcrumb context, text crash reports |
| Validator | `src/debug/validator.jai` | Post-generation map validation (bounds, connectivity, doors, terrain) |
| Stress tester | `tools/stress_test.jai` | Bulk seed testing with determinism and validation checks |
| Replay tool | `tools/replay.jai` | Deterministic replay with checkpoint hash verification |
| Headless harness | `tools/headless.jai` | Scripted game execution with logging |

### What the crash handler captures

- Game identity: seed, depth, turn, player position
- Generation progress: step enum + freeform detail string
- Map state hash at last checkpoint
- Current room index and bounds
- RNG state (mti index, call count)

### Gaps (resolved)

1. ~~**Hard crashes bypass the handler.**~~ Fixed: SEH handler via `SetUnhandledExceptionFilter` catches access violations, stack overflows, etc. Writes both crash-report.txt and .dmp file.
2. ~~**No on-demand dumps.**~~ Fixed: `debug_write_minidump()` callable from anywhere — assertion handler, stress test, or directly.
3. **No machine-readable artifacts.** ~~The text report cannot be loaded into a debugger.~~ Partially fixed: .dmp files are machine-readable via cdb. Text report still breadcrumbs-only.
4. **No symbol resolution.** Stack addresses are not resolved to function names or source lines in the text report. (Available via cdb analysis of .dmp files.)

## Original Incursion Implementation

The original C++ Incursion uses **Google Breakpad** for minidump support, treating dumps as a general diagnostic tool — not just a crash catcher.

### Architecture

- **Breakpad ExceptionHandler** wraps `dbghelp.dll` / `MiniDumpWriteDump` and registers three handlers:
  - `SetUnhandledExceptionFilter` — access violations, etc.
  - `_set_invalid_parameter_handler` — CRT invalid parameter calls
  - `_set_purecall_handler` — pure virtual calls
  - Combined as `HANDLER_ALL`
- **Release builds only** — debug builds offer `[B]reak` for debugger attachment instead
- **Dump location** — written to the executable's directory

### On-demand dumps from Error()

The `Error()` function (the game's assertion/error path) presents a dialog:

```
Error: <message>
[M]inidump, [E]xit or [C]ontinue?
```

Pressing **M** calls `crashdumpHandler->WriteMinidump()` while the process is still alive, capturing full runtime state. The user can then continue or exit. This means dumps are available for any error condition, not just terminal crashes.

**Issue #215 note**: Some users had problems with forced dumps, which is why it's a user choice rather than automatic.

### Relevance to port

We don't need Breakpad — it's a large dependency that wraps APIs we can call directly. The key insight is the **on-demand pattern**: `MiniDumpWriteDump` can be called at any point, not just from an exception filter. This means:

- The assertion handler can write a dump alongside the text crash report
- Stress test failures can trigger dumps for the specific seed/depth that failed
- A debug command could dump on demand during gameplay
- Claude can trigger dumps programmatically when investigating issues

## System Inventory

Checked 2026-01-31:

| Tool | Available | Notes |
|------|-----------|-------|
| `dbghelp.dll` | Yes | `C:\Windows\System32\dbghelp.dll` — MiniDumpWriteDump, StackWalk64, SymFromAddr |
| Windows SDK 10 | Yes | Versions up to 10.0.26100.0 |
| Application Verifier | Yes | `C:\Program Files\Application Verifier\` |
| cdb.exe / WinDbg | Yes | MSIX package, resolve path via `(Get-AppxPackage *WinDbg*).InstallLocation + '\amd64\cdb.exe'` |
| procdump | No | Sysinternals tool, not installed |
| MSVC toolchain | Yes | Via vcvarsall.bat (not in PATH by default) |

## Options

### Tier 1: No code changes

**WER LocalDumps** — Windows Error Reporting can automatically save minidumps for any crashing process via a registry key. No code changes required.

```
HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\<exe-name>
    DumpFolder  REG_EXPAND_SZ  <path>\crash-dumps
    DumpType    REG_DWORD      1 (mini) or 2 (full)
    DumpCount   REG_DWORD      10
```

Per-exe keys override the global default. Can be set for `stress_test.exe`, `game.exe`, etc.

Claude automation: `reg add` to configure, then check the dump folder after crashes.

**Event Log queries** — Windows logs application crashes in the Application event log. Query with:

```
wevtutil qe Application /q:"*[System[Provider[@Name='Application Error']]]" /c:5 /f:text
```

Gives faulting module, exception code, and offset. Useful for first-pass triage.

### Tier 2: Code changes to crash handler

**SetUnhandledExceptionFilter + MiniDumpWriteDump** — Register a Windows SEH callback that catches all unhandled exceptions (access violations, divide by zero, stack overflow). Inside the handler:

1. Call `MiniDumpWriteDump` (from `dbghelp.dll`) to create a `.dmp` file
2. Write the existing text crash report with breadcrumb context
3. Optionally name the dump with context: `crash-seed42-depth3.dmp`

This is the highest-value code change — it captures crashes that currently vanish.

Key APIs (all from `dbghelp.dll` / `kernel32.dll`):
- `SetUnhandledExceptionFilter` — register the handler
- `MiniDumpWriteDump` — write the dump file
- `MINIDUMP_EXCEPTION_INFORMATION` — passes exception pointers to the dump writer

**StackWalk64 / SymFromAddr** — Resolve stack frames to function names + source lines directly in the text crash report. Requires `.pdb` files (Jai compiler generates these).

APIs: `SymInitialize`, `SymSetOptions`, `StackWalk64`, `SymFromAddr`, `SymGetLineFromAddr64`.

### Tier 3: Installable tools

**cdb.exe (command-line debugger)** — Part of "Debugging Tools for Windows" SDK component. Install via SDK installer or `winget install Microsoft.WinDbg`.

Claude automation: open a dump and extract automated analysis:
```
cdb -z crash.dmp -c "!analyze -v; .ecxr; kb; q"
```

Produces: faulting instruction, exception type, full annotated call stack. Output is text that Claude can parse directly.

**procdump (Sysinternals)** — Monitor a running process, capture dumps on crash or hang:
```
procdump -e -ma stress_test.exe
```

Available via `winget install Sysinternals`. Useful for intermittent crashes during stress runs.

### Tier 4: Already installed

**Application Verifier** — Instruments a process to detect heap corruption, handle leaks, lock issues:
```
appverif -enable Heaps Locks -for stress_test.exe
```

Run the exe normally after enabling. Particularly useful if memory corruption is suspected.

## Recommended Approach

Two layers: dump generation (multiple triggers) and dump analysis (cdb).

### Dump generation

Following the original Incursion pattern, `MiniDumpWriteDump` is called directly (no Breakpad dependency) from multiple trigger points:

1. **SEH handler** — `SetUnhandledExceptionFilter` catches hard crashes (access violations, stack overflows). Automatic, no user action needed.
2. **Assertion handler** — `debug_assertion_failed` writes a dump alongside the text crash report. The process is still alive, so the dump captures full state.
3. **Stress test failures** — when a seed/depth fails, dump before moving to the next test. Enables post-hoc analysis of specific failures.
4. **On-demand** — a callable function that any tool or debug command can invoke to snapshot state at any point.

All dumps go to a `crash-dumps/` directory with contextual names (e.g., `crash-seed42-depth3.dmp`, `assert-panels-jai-412.dmp`).

**WER LocalDumps** as a safety net — registry configuration catches anything the in-process handlers miss (e.g., if the handler itself crashes).

### Dump analysis

**cdb.exe** (installed via `winget install Microsoft.WinDbg`) — lets Claude open dumps and extract structured analysis from the command line.

Resolve path dynamically (MSIX package, version in path changes on update):
```bash
CDB=$(powershell -Command "(Get-AppxPackage *WinDbg*).InstallLocation + '\amd64\cdb.exe'" | tr -d '\r')
```

Analyze a crash dump:
```bash
"$CDB" -sins -z <dump.dmp> -cf analyze.txt 2>&1 | grep -v NatVis
```

Where `analyze.txt` contains:
```
.sympath srv*C:\symbols*https://msdl.microsoft.com/download/symbols;<pdb-directory>
.reload
!analyze -v
.ecxr
kb
q
```

**Key flags:**
- `-sins` — ignore symbol path environment variables (prevents inheriting stale `srv*` defaults)
- `-cf <file>` — read commands from script file. Avoids bash `!` expansion issues with `!analyze`.

### Symbol strategy

Use the Microsoft symbol server with a local cache at `C:\symbols`:

```
srv*C:\symbols*https://msdl.microsoft.com/download/symbols;<pdb-directory>
```

- First run downloads OS symbols (~104MB for ntdll, kernel32, etc.). One-time cost per OS version.
- Subsequent runs use the cache. Full `!analyze -v` completes in ~3 seconds.
- Without OS symbols, `!analyze -v` degrades to `WRONG_SYMBOLS` — no source line info, no bug classification, broken stack walk through system frames.

**With OS symbols**, `!analyze -v` provides:
- Bug classification: `INVALID_POINTER_WRITE`, `HEAP_CORRUPTION`, etc.
- Exact source file and line number (`FAULTING_SOURCE_LINE_NUMBER`)
- Clean stack walk through both application and system frames
- Null pointer dereference detection (`AV.Dereference: NullPtr`)

**Automation approach**: always use the symbol server path. If the cache exists (normal case), there's no delay. If symbols need downloading (first run or new OS build), Claude should detect the longer runtime and note it rather than assuming a hang. The `-cf` script approach means there's no interactive prompt to stall on — cdb either completes or times out.

Workflow: dump generated (by any trigger) → Claude runs cdb → parses output → correlates with crash-report.txt breadcrumbs → reports root cause with stack trace, faulting instruction, and game context.

### Automation scripts

Two wrapper scripts in `docs/research/crash-diagnosis/test/` solve the Claude Code approval friction — "allow similar" covers all invocations once approved once per script:

**Post-mortem analysis** (`analyze-dump.sh`):
```bash
bash docs/research/crash-diagnosis/test/analyze-dump.sh <dump-file> [pdb-directory]
```
Resolves cdb dynamically, sets up symbol server with local cache, runs `!analyze -v` + `.ecxr` + `kb`. Best for crash dumps from the SEH handler or assertion handler.

**Live-attach debugging** (`attach-dump.sh`):
```bash
bash docs/research/crash-diagnosis/test/attach-dump.sh <exe-name-or-pid>
```
Attaches to a running/hung process, dumps all thread stacks (`~*kb`), writes a full minidump to `crash-dumps/`, then detaches (process continues). Best for processes that appear hung or are stuck in a tight loop.

| Mode | Script | When to use | Primary output |
|------|--------|-------------|----------------|
| Post-mortem | `analyze-dump.sh` | Crash dumps (.dmp files) | `!analyze -v` bug classification, source line, stack |
| Live-attach | `attach-dump.sh` | Hung/stuck processes | `~*kb` all thread stacks |

### Known limitations

- **`!analyze -v` on live-attach dumps**: The dump captures the debugger break-in thread as the "exception." Use `~*kb` during attach instead, or switch to thread 0 manually in the dump.
- ~~**SEH handler double-fault**~~: Fixed. `debug_seh_handler` is now fully allocator-free (re-entry guard, fixed-buffer formatting, Win32-only I/O). Produces valid dump + report even when the crash is allocator corruption.

## Implementation Notes

### Jai FFI approach

`#import "Windows"` in `crash_handler.jai` provides all needed bindings. Since crash_handler.jai is `#load`ed by all 9 entry points, the import is available project-wide. No `#system_library` or custom FFI declarations needed.

Win32 `#define`-style constants (`GENERIC_WRITE`, `CREATE_ALWAYS`, `FILE_ATTRIBUTE_NORMAL`) are used as inline hex values since the Windows module .md only documents functions/structs/enums. `INVALID_HANDLE_VALUE` is checked as `cast(u64) handle == 0xFFFF_FFFF_FFFF_FFFF`.

### Context handling in #c_call SEH handler

The SEH handler avoids `push_context` entirely — all formatting is done with `#c_call`-safe helpers that don't need Jai context. Key constraint: `for` loops require context (they dispatch through `for_expansion`), so all helpers use `while` loops. Non-`#c_call` functions like `gen_step_name` can't be called from a `#c_call` function, so a separate `seh_append_gen_step` duplicates the lookup.

### Signal handler safety

The SEH handler (`debug_seh_handler`) is fully allocator-free — no `push_context`, `tprint`, or allocator calls. It uses:
- `g_seh_in_progress` re-entry guard to prevent double-fault
- `seh_append_*` helpers that format into fixed `[2048] u8` stack buffers using `while` loops (not `for`, which requires Jai context)
- `seh_write_minidump` and `seh_write_crash_report` that use only Win32 APIs (`CreateFileA`/`WriteFile`/`CloseHandle`)
- Minidump-first ordering (most valuable artifact written before crash report formatting)

The existing `write_crash_report` and `debug_write_minidump` (which use `tprint`) are unchanged — they're called from the assertion handler and stress test where the allocator is intact. `MiniDumpWriteDump` is documented as safe to call from an exception filter.

### Dump file naming

Files go to `crash-dumps/` (gitignored) with contextual names: `crash-seed{seed}-depth{depth}.dmp`. The directory is created on first dump via `CreateDirectoryA` (ignores "already exists" error).

## Open Questions (Resolved)

- ~~Does the Jai compiler produce .pdb files by default?~~ **Yes**, all executables have `.pdb` siblings.
- ~~What Jai module/pattern is used for Win32 FFI bindings?~~ `#import "Windows"` provides everything.
- ~~Should dump files be gitignored?~~ Yes, `crash-dumps/` and `*.dmp` added to `.gitignore`.
- ~~Is `winget` available?~~ Yes, used to install WinDbg.
