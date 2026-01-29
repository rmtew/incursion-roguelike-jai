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
3. [x] Update terminal rendering to apply lookup before font atlas indexing
4. [x] Verify extended glyphs (GLYPH_FLOOR, GLYPH_WALL, etc.) render correctly
5. [x] Create automated verification tool (`tools/dungeon_verify.exe`)

**Key insight:** Glyph is a u32 bitfield:
- Bits 0-11: Character ID (may be GLYPH_* constant 256+)
- Bits 12-15: Foreground color (0-15)
- Bits 16-19: Background color (0-15)

### Rendering Priority System

**Status:** COMPLETE

When multiple things occupy a cell:
- Creatures override items
- Multiple creatures → GLYPH_MULTI (Æ)
- Multiple items → GLYPH_PILE (*)

**Implementation:** `src/dungeon/render.jai`

### Resource Database Glyph Lookup

**Status:** COMPLETE

Entities now look up their actual glyphs from parsed .irh files:
- `find_monster_by_cr_fuzzy()` matches monsters by CR
- `find_item_by_level_fuzzy()` matches items by level
- `type_id` field stores index for future stat lookups

**Implementation:** `src/resource/runtime.jai`, `src/dungeon/makelev.jai`

### Visibility/Memory System

**Status:** Specification complete, implementation pending

**Spec:** `docs/research/specs/visibility-system.md`

Map cells track:
- `VI_VISIBLE` - Currently in player's FOV
- `VI_DEFINED` - Has been seen at least once
- `Memory` field - Glyph stored when cell first seen

**Implementation Plan (from spec):**
1. [ ] Data structures: Add `VisibilityInfo` struct with visibility flags + memory glyph
2. [ ] Memory assignment: Store terrain glyph when cell becomes visible
3. [ ] Rendering integration: Check visibility in `get_cell_render()`
4. [ ] FOV algorithm: Ray casting from player to viewport edges

### Lighting System

**Status:** Specification complete, implementation pending

**Spec:** `docs/research/specs/lighting-system.md`

Lighting affects both map generation and visibility:
- Torch placement on walls (TF_TORCH terrain)
- Room lit chance decreases with depth (50% - 4%/depth)
- Light level affects floor glyph color (yellow/brown)
- Vision ranges: SightRange, LightRange, ShadowRange, InfraRange, BlindRange

**Implementation Plan (from spec):**
1. [ ] Cell lighting data: Add Lit, Bright, Shade, Dark, mLight flags
2. [ ] Torch tracking: Place torches, calculate light propagation
3. [ ] Vision range calculation: Based on stats, equipment, abilities
4. [ ] FOV integration: Use light ranges in visibility decisions

### Phase 2-4 Verification

Deferred until Phase 1 (parser verification) is complete:
- Constants and flags verification (3572 constants)
- Mechanics verification (combat, skills, spells, status effects)
- Generation verification (dungeon generation, placement rules)

## Ideas

- Use original `TMonster::Dump()`, `TItem::Dump()` functions from `src/Debug.cpp` to generate expected output if original can be built
- Property-based invariant testing as supplementary verification
- Replay testing for full system behavior (requires significant infrastructure)
