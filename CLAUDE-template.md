# [Project Name] - Claude Code Project Guide

## Directives for Future Sessions

1. **Use reference sections** - Don't clutter this file with details. Link to `docs/research/` for deep dives, specs, and implementation notes.
2. **Keep this file scannable** - Use headers and bullet points; move large content to linked files
3. **Maintain JOURNAL.md** - Record summaries of changes made in each session by appending new entries. Include what was changed, why, and test results.
4. **Maintain BACKLOG.md** - Track workarounds, deferred work, and ideas for future improvements. Update when adding workarounds or identifying issues to revisit later.
5. **Subproject structure** - Research subprojects (in `docs/research/`) can have their own `README.md` (overview, current state), `JOURNAL.md`, and `BACKLOG.md`. When updating a subproject journal, add a brief entry in the root JOURNAL.md referencing the update.

## Environment

- **Shell**: [e.g., Git Bash on Windows, zsh on macOS]
- **Python**: [e.g., `py` command, `python3`]
- **Compiler/Runtime**: [path to compiler or runtime]
- **Version**: [version info if relevant]

## Reference Structure

| Location | Purpose |
|----------|---------|
| `docs/research/` | Research notes, deep dives, implementation details |
| `docs/research/[topic]/` | Topic-specific research with README, JOURNAL, BACKLOG |

## Build & Test

```bash
# Compile
[compile command]

# Run tests
[test command]
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
- **Never run** `git clean -fd` without checking `git status` first

**Uncertainty during work:**
- If there's a reasonable path forward that doesn't accumulate error, make a best guess and mark with `TODO:`
- Halt at end of task list for user review before continuing

**Architectural decisions** - Prompt user. Directory structure, file organization, and naming conventions follow direct user instruction.

**Tool usage** - Proceed with using tools to maintain automated flow.

### Verification

**Correctness testing:**
- [How to compile/build]
- [How to run tests]
- All tests must pass before committing

**Verification standard:**
- [Project-specific verification approaches]

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

---

## Project-Specific Sections

*Add project-specific sections below this line.*
