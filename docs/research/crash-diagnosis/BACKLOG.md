# Crash Diagnosis Backlog

## Investigated

- [x] Does the Jai compiler produce .pdb files by default? — **Yes**, all executables in `tools/` have `.pdb` siblings.
- [x] What Win32 FFI pattern does this project use? — Jai's `#import "Windows"` module already has all needed bindings: `MiniDumpWriteDump`, `SetUnhandledExceptionFilter`, `MINIDUMP_EXCEPTION_INFORMATION`, `EXCEPTION_POINTERS`, `CONTEXT`, `STACKFRAME64`, `SymInitialize`, `SymFromAddr`, `StackWalk64`, `MINIDUMP_TYPE` enum, `SYMOPT` enum, etc. No custom FFI needed.
- [x] Is `winget` available? — **Yes**, used to install WinDbg.
- [x] Where should dump files live? — `crash-dumps/` directory, gitignored. Filenames include context: `crash-seed{seed}-depth{depth}.dmp`.

## To implement

- [x] **Core dump utility** — `debug_write_minidump()` in `crash_handler.jai`, callable from anywhere with optional exception pointers (2026-01-31)
- [x] **SEH handler** — `debug_seh_handler` registered via `SetUnhandledExceptionFilter` + `SetErrorMode` to suppress Windows error dialog (2026-01-31). Note: `_set_invalid_parameter_handler` and `_set_purecall_handler` not yet added (CRT handlers, less critical for Jai code).
- [x] **Assertion handler integration** — `debug_assertion_failed` calls `debug_write_minidump()` after writing crash-report.txt (2026-01-31)
- [x] **Stress test integration** — `debug_write_minidump()` called before `add_failure()` at all three failure sites (2026-01-31)
- [ ] ~~**WER LocalDumps registry setup**~~ — deferred; persistent registry change unwanted on this machine. In-process SEH handler covers the same cases without system-level config.
- [x] **Install cdb.exe** — installed via `winget install Microsoft.WinDbg` (MSIX package)
- [x] **cdb analysis workflow** — tested end-to-end, `.ecxr; kb; q` works reliably (`!analyze -v` hangs on symbol server)
- [x] **cdb automation wrapper scripts** — `analyze-dump.sh` (post-mortem) and `attach-dump.sh` (live-attach). Solves Claude Code approval friction via "allow similar" on a stable command pattern. (2026-01-31)
- [x] **Runtime verification** — diagnosed regen crash via live-attach. Double-fault: allocator corruption in `place_doors_makelev` → SEH handler crashes on `tprint`. (2026-01-31). Follow-up (2026-01-31): SEH handler fixed, `features` array lifecycle fixed. Regen crash persisted. **RESOLVED** (2026-02-01): Root cause found via `Overwriting_Allocator` in stress test — two bugs: (1) `array_free` doesn't null data pointer, `array_reset` double-frees on reuse; (2) terrain registry stored pointers into growing `[..] RuntimeTerrain`, invalidated by realloc. See `docs/research/memory-allocation/` for full write-up.
- [x] **SEH handler safety** — Rewritten to be fully allocator-free (2026-01-31). Re-entry guard (`g_seh_in_progress`), fixed-buffer formatting helpers (`seh_append_*`), minidump-first ordering. No `push_context`, `tprint`, or allocator calls in the SEH path. Verified: produces valid crash-report.txt and .dmp on allocator-corruption crash.
- [x] **agent-docs guide** — `agent-docs/windows/crash_diagnosis.md` covering minidump generation, cdb analysis, handler safety, WER LocalDumps, Application Verifier, and wrapper scripts. Project-agnostic with C and Jai examples. (2026-01-31)

## Future ideas

- [ ] StackWalk64 / SymFromAddr for in-process symbol resolution in crash-report.txt
- [ ] ~~Application Verifier integration~~ — not needed, Overwriting_Allocator was sufficient
- [ ] procdump wrapper for monitoring long stress test runs
- [ ] Event log query as first-pass triage step
- [ ] On-demand dump command in game UI (following original Incursion's [M]inidump pattern)
