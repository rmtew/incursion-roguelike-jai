# Incursion Port - Claude Code Project Guide

## Directives for Future Sessions

1. **Use reference sections** - Don't clutter this file with details. Link to `docs/research/` for deep dives, specs, and implementation notes.
2. **Keep this file scannable** - Use headers and bullet points; move large content to linked files
3. **Maintain JOURNAL.md** - Record summaries of changes made in each session by appending new entries. Include what was changed, why, and test results.
4. **Maintain BACKLOG.md** - Track workarounds, deferred work, and ideas for future improvements. Update when adding workarounds or identifying issues to revisit later.
5. **Subproject structure** - Research subprojects (in `docs/research/`) can have their own `README.md` (overview, current state), `JOURNAL.md`, and `BACKLOG.md`. When updating a subproject journal, add a brief entry in the root JOURNAL.md referencing the update.

## Reference Structure

| Location | Purpose |
|----------|---------|
| `docs/research/` | Research notes, deep dives, implementation details |
| `docs/research/jai-reference.md` | Jai language patterns, modules, NDA constraints |
| `docs/research/correctness-research/` | Verifying port matches original Incursion behavior |
| `docs/research/specs/` | Specifications derived from correctness research |
| `docs/research/parser-research/` | Lexer/parser implementation notes |
| `docs/research/scripting/` | Scripting system research |

## Environment

- **Shell**: Git Bash on Windows (cmd/terminal)
- **Python**: Use `py` command (not `python`)
- **Jai Compiler**: `C:/Data/R/jai/bin/jai.exe`
- **Jai Version**: `beta 0.2.025` (released 2026-01-19, last verified: 2026-01-28)
- **IMPORTANT**: Jai is under NDA closed beta. NEVER read, access, or explore any files in the Jai installation directory (`C:/Data/R/jai/`) other than invoking the executable. Do not attempt to read modules, examples, or any other files in that directory tree.

## Original Incursion Source

**Location**: `C:\Data\R\roguelike - incursion\repo-work\`

For details on key files, resource formats, and grammar specifications, see `docs/research/correctness-research/` and `docs/research/specs/`.

## Build & Test

```bash
# Compile
C:/Data/R/jai/bin/jai.exe src/main.jai

# Run tests
./main.exe
```

## Conventions

### Code Comments
- Mark unclear sections with `TODO:` or `UNKNOWN:`
- Use comments to explain *why*, not *what*

## Session Workflow

### Before Creating Task List
- Read JOURNAL.md to understand recent work and context
- Check BACKLOG.md for pending issues or deferred work relevant to current task
- Use this context to inform task list creation

### Task Lists

Use task lists for any work involving multiple steps or file modifications.

**Structure:**
1. ... work tasks ...
2. `[Finalize]` Update JOURNAL.md with session summary
3. `[Finalize]` Update BACKLOG.md if workarounds/deferred items added
4. `[Finalize]` Commit all changes

After completing all tasks, halt for user review before proceeding to new work.

### Journal and Backlog Maintenance

- **JOURNAL.md** - Append entries at the end. Use narrative style with:
  - `## YYYY-MM-DD: Topic` header
  - `### Subsection` for key decisions or findings
  - **Bold labels** for important points
  - Code snippets where relevant
  - Reasoning behind decisions, not just what was done
- **BACKLOG.md** - Track workarounds, deferred work, and ideas. Update when adding workarounds or identifying issues to revisit later.

### Autonomy Rules

**Scope of changes** - No limit. Proceed with changes of any size.

**Destructive actions:**
- Before overwriting work that hasn't been committed, confirm with user
- No git push - local commits only
- **Never run** `git clean -fd` without checking `git status` first (files were lost on 2026-01-26)

**Uncertainty during work:**
- If there's a reasonable path forward that doesn't accumulate error, make a best guess and mark with `TODO:`
- Halt at end of task list for user review before continuing

**Architectural decisions** - Prompt user. Directory structure, file organization, and naming conventions follow direct user instruction.

**Tool usage** - Proceed with using tools to maintain automated flow.

### Verification

**Correctness testing:**
- Compile with `C:/Data/R/jai/bin/jai.exe src/main.jai`
- Run `./main.exe` to execute test suite
- All tests must pass before committing

**Verification standard:**
- Parser changes: test against .irh files in `lib/`
- Dungeon changes: visual inspection via `tools/dungeon_test.jai`

**Documentation:**
- README.md - Summary status (what works, what doesn't)
- JOURNAL.md - Detailed session notes
- BACKLOG.md - Track known issues to resolve

### External References

**Location:**
- `docs/` - Project-wide references and screenshots

**Archival approach:**
- Include source URL in comments/docs
- Save excerpts and summaries locally
- Avoid link rot by capturing key information

### Error Handling

When tools fail, crash, produce unexpected output, or dependencies are missing:

1. **If error is due to incorrect usage** - Attempt to fix the invocation and retry
2. **If unfixable** - Halt for user review
3. **If other work can proceed** - Log the error and pivot to unblocked tasks

**Document errors in both:**
- JOURNAL.md under `### Errors` section - what happened, what was tried
- BACKLOG.md - for follow-up investigation

## Jai Language Reference

See `docs/research/jai-reference.md` for language patterns, useful modules, and NDA constraints.

**Local Reference Repo**: `C:\Data\R\git\jai\` (reverse-engineered documentation)
