# Dungeon Generation Specification - Plan

## Purpose

Create human-readable markdown documentation that fully specifies how Incursion generates dungeons. This spec serves as:
1. Reference documentation for implementing dungeon generation in Jai
2. Baseline for verification passes checking implementation correctness
3. Persistent context for future development sessions

## Critical Principle

**Specs must document actual original behavior, not interpreted behavior.**

- All claims must be traceable to specific source lines
- Code snippets must be verbatim from original (or clearly marked as paraphrased)
- When behavior is unclear, mark as `[UNVERIFIED]` not assumed
- Avoid inferring "why" - document "what" the code does
- Verification passes should confirm spec accuracy against original

## Specification Documents

| Document | Contents | Status |
|----------|----------|--------|
| `overview.md` | High-level algorithm, phases, data structures | **Draft complete** |
| `room-placement.md` | Room types, sizing, positioning rules | **Draft complete** |
| `corridor-generation.md` | How corridors connect rooms | **Draft complete** |
| `terrain-assignment.md` | Floor, wall, special terrain rules | **Draft complete** |
| `feature-placement.md` | Doors, traps, stairs, portals | **Draft complete** |
| `population.md` | Monster, item, feature placement by depth | **Draft complete** |
| `regions.md` | Region system, themed areas | **Draft complete** |

## Source Files to Analyze

Primary sources in `C:\Data\R\roguelike - incursion\repo-work\`:

| File | Expected Contents |
|------|-------------------|
| `src/Dungeon.cpp` | Main generation algorithm |
| `src/Gen.cpp` | Additional generation code (if exists) |
| `inc/Dungeon.h` | Data structures, constants |
| `lib/region.irh` | Region definitions |
| `lib/terrain.irh` | Terrain definitions |

## Approach

### Phase 1: Code Survey
- Identify all files involved in dungeon generation
- Map out function call graph
- Identify key data structures

### Phase 2: Algorithm Extraction
- Document each generation phase
- Extract constants and parameters
- Note randomization points

### Phase 3: Specification Writing
- Write each spec document
- Include examples and edge cases
- Reference source locations

### Phase 4: Verification
- Review specs against original code
- Test understanding with specific scenarios
- Update as corrections are found

## Verification Passes

After specs are written, verification can check:
- [ ] Spec accurately describes original algorithm
- [ ] All generation phases are documented
- [ ] Constants and parameters are correct
- [ ] Edge cases are covered
- [ ] Implementation matches spec

## Success Criteria

The specification is complete when:
1. A developer can implement dungeon generation from the spec alone
2. Verification passes confirm spec matches original behavior
3. Edge cases and randomization are documented
