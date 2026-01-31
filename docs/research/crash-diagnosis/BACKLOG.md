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
- [ ] **agent-docs guide** — `agent-docs/windows/crash_diagnosis.md` covering the general-purpose knowledge (WER, minidumps, cdb, dbghelp APIs, Application Verifier). Must be project-agnostic so other repos using the agent-docs submodule can reference it.
- [ ] **Runtime verification** — trigger a real crash or assertion and verify dump file is written and analyzable with cdb

## Future ideas

- [ ] StackWalk64 / SymFromAddr for in-process symbol resolution in crash-report.txt
- [ ] Application Verifier integration for stress test runs (heap corruption detection)
- [ ] procdump wrapper for monitoring long stress test runs
- [ ] Event log query as first-pass triage step
- [ ] Agent-docs guide for Windows crash diagnosis workflow (shareable across projects)
- [ ] On-demand dump command in game UI (following original Incursion's [M]inidump pattern)
