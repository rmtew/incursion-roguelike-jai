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
