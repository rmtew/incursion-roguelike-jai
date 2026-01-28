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

### Glyph Rendering (HIGH PRIORITY)

**Status:** Lookup table extracted, integration needed

**Spec:** `docs/research/specs/rendering-pipeline.md`
**Implementation:** `src/glyph_cp437.jai`

**Tasks:**
1. [x] Extract full GLYPH_* → CP437 lookup table from `src/Wlibtcod.cpp` lines 448-606
2. [x] Implement `glyph_to_cp437(id: u16) -> u8` function
3. [ ] Update terminal rendering to apply lookup before font atlas indexing
4. [ ] Verify extended glyphs (GLYPH_FLOOR, GLYPH_WALL, etc.) render correctly

**Key insight:** Glyph is a u32 bitfield:
- Bits 0-11: Character ID (may be GLYPH_* constant 256+)
- Bits 12-15: Foreground color (0-15)
- Bits 16-19: Background color (0-15)

### Rendering Priority System

**Status:** Spec complete, not yet implemented

When multiple things occupy a cell:
- Creatures override items
- Multiple creatures → GLYPH_MULTI (Æ)
- Multiple items → GLYPH_PILE (*)

### Visibility/Memory System

**Status:** Not yet researched in detail

Map cells track:
- Whether player has ever seen the cell
- What the player remembers seeing (Memory field)
- Current visibility state

### Phase 2-4 Verification

Deferred until Phase 1 (parser verification) is complete:
- Constants and flags verification (3572 constants)
- Mechanics verification (combat, skills, spells, status effects)
- Generation verification (dungeon generation, placement rules)

## Ideas

- Use original `TMonster::Dump()`, `TItem::Dump()` functions from `src/Debug.cpp` to generate expected output if original can be built
- Property-based invariant testing as supplementary verification
- Replay testing for full system behavior (requires significant infrastructure)
