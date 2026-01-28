# Correctness Research Backlog

## Open Questions

- [ ] How much does the original parser compute at parse-time vs runtime?
- [ ] Are there undocumented behaviors in the original we need to match?
- [ ] What's the minimal viable verification for MVP?
- [ ] Can we build the original source to create reference executable?

## Tools to Develop

- [ ] Jai parser dump utility (serialize ParsedX structs)
- [ ] Golden file test runner
- [ ] Constant verification script
- [ ] Diff tool for comparing parsed output

## Deferred Work

### Glyph Rendering Verification

**Priority**: High

Implement GLYPH_* → CP437 lookup table based on `src/Wlibtcod.cpp` lines 448-600. Current 8x8.png font is already CP437 layout, so only the lookup table is needed.

### Phase 2-4 Verification

Deferred until Phase 1 (parser verification) is complete:
- Constants and flags verification (3572 constants)
- Mechanics verification (combat, skills, spells, status effects)
- Generation verification (dungeon generation, placement rules)

## Ideas

- Use original `TMonster::Dump()`, `TItem::Dump()` functions from `src/Debug.cpp` to generate expected output if original can be built
- Property-based invariant testing as supplementary verification
- Replay testing for full system behavior (requires significant infrastructure)
