\# CLAUDE.md



This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.



\## Project Overview



This repository is for .. to be fleshed out.



\## Environment



\- \*\*Shell\*\*: Git Bash on Windows

\- \*\*Python\*\*: Use `py` command (not `python`)



\## Tools and Locations



\### Jai Compiler

\- \*\*Executable\*\*: `C:\\Data\\R\\jai\\bin\\jai.exe`

\- \*\*Documentation\*\*: `C:\\Data\\R\\git\\jai`

\- \*\*IMPORTANT\*\*: Jai is under NDA closed beta. NEVER read, access, or explore any files in the Jai installation directory (`C:\\Data\\R\\jai\\`) other than invoking the executable. Do not attempt to read modules, examples, or any other files in that directory tree.



\### Project Tools

To be fleshed out.



\## Project Structure



/projects/       - Per-game reverse engineering projects

/tools/          - Jai-based tooling for analysis

/docs/           - Documentation and notes



\### Per-Project Organization



Each project lives in `/project/<sanitized-name>/` (lowercase, hyphens).



\*\*Required files per project:\*\*

\- `README.md` - Concise overview: current state, project details, how to work with it, references to local journal/backlog

\- `JOURNAL.md` - Target-specific development journal

\- `BACKLOG.md` - Target-specific workarounds, deferred work, ideas



\*\*Standard subdirectories:\*\*

/project/subproject-name/

&nbsp; README.md

&nbsp; JOURNAL.md

&nbsp; BACKLOG.md

&nbsp; /tools/        - Target-specific tooling if needed

&nbsp; /notes/        - Research notes, references, documentation



\*\*Top-level journal\*\* - When updating a target's JOURNAL.md, add a brief entry in the root JOURNAL.md referencing the target-specific update.



\## Conventions



\### Code Comments

\- Mark unclear sections with `TODO:` or `UNKNOWN:`



\## Session Workflow



\### Before Creating Task List

\- Read JOURNAL.md to understand recent work and context

\- Check BACKLOG.md for pending issues or deferred work relevant to current task

\- Use this context to inform task list creation



\### Task Lists



Use task lists for any work involving multiple steps or file modifications.



\*\*Structure:\*\*

1\. ... work tasks ...

2\. `\[Finalize]` Update JOURNAL.md with session summary

3\. `\[Finalize]` Update BACKLOG.md if workarounds/deferred items added

4\. `\[Finalize]` Commit all changes



After completing all tasks, halt for user review before proceeding to new work.



\### Journal and Backlog Maintenance

\- \*\*JOURNAL.md\*\* - Append entries at the end. Use narrative style with:

&nbsp; - `## YYYY-MM-DD: Topic` header

&nbsp; - `### Subsection` for key decisions or findings

&nbsp; - \*\*Bold labels\*\* for important points

&nbsp; - Code snippets where relevant

&nbsp; - Reasoning behind decisions, not just what was done

\- \*\*BACKLOG.md\*\* - Track workarounds, deferred work, and ideas. Update when adding workarounds or identifying issues to revisit later.



\### Autonomy Rules



\*\*Scope of changes\*\* - No limit. Proceed with changes of any size.



\*\*Destructive actions:\*\*

\- Before overwriting work that hasn't been committed, confirm with user

\- No git push - local commits only



\*\*Uncertainty during work:\*\*

\- If there's a reasonable path forward that doesn't accumulate error, make a best guess and mark with `TODO:`

\- Halt at end of task list for user review before continuing



\*\*Architectural decisions\*\* - Prompt user. Directory structure, file organization, and naming conventions follow direct user instruction.



\*\*Tool usage\*\* - Proceed with using other tools to maintain automated flow.



\### Verification



\*\*Correctness testing\*\* - Flesh me out.



\*\*Verification standard:\*\* - Flesh me out.



\*\*Documentation:\*\*

\- Target README.md - Summary status (what works, what doesn't, known discrepancies)

\- Target JOURNAL.md - Detailed verification session notes

\- Target BACKLOG.md - Track known discrepancies to resolve



\### External References



\*\*Location:\*\*

\- `/notes/` - Project-wide references (research related files)

\- `/project/<target>/notes/` - Target-specific references (research related files)



\*\*What to reference:\*\*

\- Flesh me out.



\*\*Archival approach:\*\*

\- Include source URL

\- Save excerpts and summaries locally

\- Avoid link rot by capturing key information



\### Error Handling



When tools fail, crash, produce unexpected output, or dependencies are missing:



1\. \*\*If error is due to incorrect usage\*\* - Attempt to fix the invocation and retry

2\. \*\*If unfixable\*\* - Halt for user review

3\. \*\*If other work can proceed\*\* - Log the error and pivot to unblocked tasks



\*\*Document errors in both:\*\*

\- JOURNAL.md under `### Errors` section - what happened, what was tried

\- BACKLOG.md - for follow-up investigation



\### Git Discipline



\- \*\*Commit frequency\*\* - At end of task list, not after every change

\- \*\*Commit messages\*\* - Short, clear text overview. No emojis. Detail is in JOURNAL.md

\- \*\*What to commit\*\* - All changes together in one commit

\- \*\*Branching\*\* - Work on main



\## Build Commands



\### Jai

`C:\\Data\\R\\jai\\bin\\jai.exe <source\_file.jai>`



(Additional build commands will be added as tooling is developed)



