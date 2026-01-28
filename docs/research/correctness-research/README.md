# Correctness Research

Verification strategies for ensuring the Jai port faithfully replicates original Incursion behavior.

## Scope

- Resource parsing (monsters, items, spells, etc.)
- Game mechanics (combat, skills, magic)
- Dungeon generation
- Script/effect logic

## Current State

**Phase 1: Parser Verification** (in progress)

Completed:
- Identified verification approaches
- Located authoritative specifications (`lang/Tokens.lex`, `lang/Grammar.acc`)
- Clarified glyph rendering architecture (CP437 primary, Unicode fallback)

Next:
- Create sample golden file for one Monster resource
- Build dump utility for Jai parser output
- Design comparison format

## Approach

**Golden file testing** selected as primary method:
- Parse `.irh` files with Jai parser
- Compare structured output against expected values
- Self-contained, no need to build original source
- Documents expected behavior

## Verification Phases

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Parser verification | In progress |
| 2 | Constants and flags (3572 total) | Pending |
| 3 | Mechanics (combat, skills, spells) | Pending |
| 4 | Dungeon generation | Pending |

## Key References

| Resource | Location |
|----------|----------|
| Original source | `C:\Data\R\roguelike - incursion\repo-work\` |
| Lexer spec | `lang/Tokens.lex` |
| Grammar spec | `lang/Grammar.acc` |
| Dump functions | `src/Debug.cpp` lines 1856-1978 |
| CP437 glyph lookup | `src/Wlibtcod.cpp` lines 448-600 |

## Files

| File | Purpose |
|------|---------|
| `README.md` | This overview |
| `NOTES.md` | Detailed technical reference |
| `JOURNAL.md` | Session history |
| `BACKLOG.md` | Open questions and deferred work |
