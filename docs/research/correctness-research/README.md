# Correctness Research

Verification strategies and comprehensive architecture research for ensuring the Jai port faithfully replicates original Incursion behavior.

## Scope

- Full source architecture (47 .cpp files, 23 headers, 45 constant categories)
- Resource parsing (monsters, items, spells, etc.)
- Game mechanics (combat, skills, magic, values)
- Dungeon generation
- Script/effect logic
- UI and display systems

## Current State

**Architecture research complete** - All subsystems documented at header level.

Completed:
- Full class hierarchy mapped (Object > Thing > Creature/Feature/Item)
- All 21 resource types documented
- Event system (190+ event types, EventInfo 200+ fields)
- All 45 constant categories identified (Defines.h, ~4700 lines)
- 17 subsystem research documents created
- Master research index linking all areas

Remaining for porting:
- Implementation-level detail for key algorithms (CalcValues, combat formulas, AI logic)
- These should be researched per-system when porting each area

## Master Index

See **`master-index.md`** for the comprehensive research index covering all subsystems with status tracking and priority ordering.

## Research Documents

| Doc | Subsystem | Status |
|-----|-----------|--------|
| `01-object-registry.md` | Object, Registry, base types | Architecture |
| `02-resource-system.md` | Resources, rID, Module, 21 types | Architecture |
| `03-event-system.md` | EventInfo, dispatch, 190+ events | Architecture |
| `04-creature-system.md` | Creature/Character/Player/Monster | Architecture |
| `05-combat-system.md` | Attack flow, d20 combat, maneuvers | Architecture |
| `06-item-system.md` | Item hierarchy, qualities, equipment | Architecture |
| `07-magic-system.md` | Spells, effects, metamagic, prayer | Architecture |
| `08-status-effects.md` | Stati, StatiCollection, fields | Architecture |
| `09-map-system.md` | LocationInfo, Map class, LOS | Architecture |
| `10-feature-system.md` | Door, Trap, Portal | Architecture |
| `11-vision-perception.md` | FOV, 9 perception types, lighting | Architecture |
| `12-encounter-generation.md` | CR-balanced encounters, templates | Architecture |
| `13-skills-feats.md` | 49 skills, 200+ feats, 143 abilities | Architecture |
| `14-social-quest.md` | NPC interaction, companions, quests | Architecture |
| `15-ui-display.md` | Terminal, managers, messages | Architecture |
| `16-data-tables.md` | Tables, annotations, targeting, debug | Architecture |
| `17-values-calcvalues.md` | CalcValues, bonus stacking, d20 rules | Architecture |

## Approach

**Golden file testing** selected as primary verification method:
- Parse `.irh` files with Jai parser
- Compare structured output against expected values
- Self-contained, no need to build original source

**Cross-cutting flow verification** catches gaps between subsystems:
- Traces key behaviors end-to-end across subsystem boundaries
- Defines observable outcomes (not just code presence)
- See `cross-cutting-flows.md` for all traced flows

## Verification Phases

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Parser verification | In progress |
| 2 | Architecture research | **Complete** |
| 3 | Constants and flags (4700+ lines, 45 categories) | Documented |
| 4 | Mechanics (combat, skills, spells) | Architecture documented |
| 5 | Dungeon generation | **Complete** (see specs/) |
| 6 | Implementation-level detail | Per-system during porting |

## Key References

| Resource | Location |
|----------|----------|
| Original source | `C:\Data\R\roguelike - incursion\repo-work\` |
| Original headers (23) | `repo-work/inc/` |
| Original source (47) | `repo-work/src/` |
| Lexer spec | `lang/Tokens.lex` |
| Grammar spec | `lang/Grammar.acc` |
| Dump functions | `src/Debug.cpp` lines 1856-1978 |
| CP437 glyph lookup | `src/Wlibtcod.cpp` lines 448-600 |

## Files

| File | Purpose |
|------|---------|
| `README.md` | This overview |
| `master-index.md` | Comprehensive subsystem index with priorities |
| `01-17*.md` | Individual subsystem research documents |
| `cross-cutting-flows.md` | End-to-end behavioral flow traces |
| `NOTES.md` | Detailed technical reference |
| `JOURNAL.md` | Session history |
| `BACKLOG.md` | Open questions and deferred work |
