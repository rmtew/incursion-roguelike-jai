# Incursion Port - Claude Code Project Guide

## Directives for Future Sessions

1. **Use reference sections** - Don't clutter this file with details. Link to `docs/research/` for deep dives, specs, and implementation notes.
2. **Keep this file scannable** - Use headers and bullet points; move large content to linked files

## Critical Development Rules

- **Jai NDA**: NEVER read, access, or explore any files in the Jai installation directory (`C:/Data/R/jai/`) other than invoking the compiler executable. Do not attempt to read modules, examples, or any other files in that directory tree.
- **Running `.bat` files**: Run with `./build.bat`, not `build.bat`. Git Bash delegates `.bat` files to `cmd.exe` automatically. Do NOT use `cmd /c` or `powershell` wrappers. See `agent-docs/windows/terminal_quirks.md` for details.
- **Never run** `git clean -fd` without checking `git status` first (files were lost on 2026-01-26).
- **Design docs**: When modifying:
  - Parser → update `docs/research/parser-research/`
  - Dungeon generator → update `docs/research/specs/`
  - Resource formats → update `docs/research/correctness-research/`

## Session Conventions

Follow [agent-docs/workflows/session_conventions.md](agent-docs/workflows/session_conventions.md) for:
- JOURNAL.md and BACKLOG.md maintenance
- Task list structure with finalization steps
- Autonomy rules (when to proceed vs. halt)
- Error handling patterns

## Environment

- **Shell**: Git Bash on Windows (cmd/terminal)
- **Python**: Use `py` command (not `python`)
- **Jai Compiler**: `C:/Data/R/jai/bin/jai.exe`
- **Jai Version**: `beta 0.2.025` (released 2026-01-19, last verified: 2026-01-28)

## Reference Structure

| Location | Purpose |
|----------|---------|
| `agent-docs/` | Shared session conventions and workflows (git submodule) |
| `agent-docs/windows/terminal_quirks.md` | Git Bash quirks: `.bat` invocation, path conversion |
| `docs/research/` | Research notes, deep dives, implementation details |
| `docs/research/jai-reference.md` | Jai language patterns, modules, NDA constraints |
| `docs/research/correctness-research/` | Verifying port matches original Incursion behavior |
| `docs/research/specs/` | Specifications derived from correctness research |
| `docs/research/parser-research/` | Lexer/parser implementation notes |
| `docs/research/memory-allocation/` | Memory allocation audit and allocator strategy |
| `docs/research/scripting/` | Scripting system research |

## Build & Test

```bash
# Build all targets
./build.bat

# Build specific target(s)
./build.bat test             # test runner only
./build.bat game             # game executable only
./build.bat game test        # multiple targets

# Run tests
./src/tests/test.exe

# Build targets:
#   game              src/main.jai         (game entry point)
#   test              src/tests/test.jai   (test runner)
#   headless          tools/headless.jai
#   dungeon_test      tools/dungeon_test.jai
#   dungeon_screenshot tools/dungeon_screenshot.jai
#   dungeon_verify    tools/dungeon_verify.jai
#   inspect           tools/inspect.jai
#   replay            tools/replay.jai
```

## Verification

**Correctness testing:**
- Compile with `./build.bat test`
- Run `./src/tests/test.exe` to execute test suite
- All tests must pass before committing

**Verification standard:**
- Parser changes: test against .irh files in `lib/`
- Dungeon changes: visual inspection via `tools/dungeon_test.jai`

**Documentation:**
- README.md - Summary status (what works, what doesn't)
- JOURNAL.md - Detailed session notes
- BACKLOG.md - Track known issues to resolve

---

## Project-Specific: Incursion Port

### Original Incursion Source

**Location**: `C:\Data\R\roguelike - incursion\repo-work\`

For details on key files, resource formats, and grammar specifications, see `docs/research/correctness-research/` and `docs/research/specs/`.

### Jai Language Reference

See `docs/research/jai-reference.md` for language patterns, useful modules, and NDA constraints.

**Local Reference Repo**: `C:\Data\R\git\jai\` (reverse-engineered documentation)
