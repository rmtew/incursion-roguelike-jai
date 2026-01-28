# Correctness Research Journal

## 2026-01-28: Initial Setup

### Session Goals
- Created `assignment/correctness-research` folder
- Established initial notes on verification strategies
- Identified key approaches for ensuring reimplementation correctness

### Approaches Identified

1. **Parser Output Comparison** - Compare parsed structures between original and port
2. **Golden File Testing** - Create expected-output test files
3. **Value Extraction** - Extract runtime data from original executable
4. **Replay Testing** - Record and replay game sessions
5. **Property-Based Testing** - Define and verify invariants
6. **Side-by-Side Review** - Manual code comparison

### Recommended Starting Point

**Golden file testing** appears most practical for immediate use:
- Self-contained
- No need to modify or build original source
- Can incrementally cover more resources
- Documents expected behavior as side effect

### Key Questions Raised

1. Can original Incursion source be built to create reference executable?
2. What computed values exist in parsed resources that differ from file content?
3. What's the minimum verification needed for MVP confidence?

### Next Steps

1. Create sample golden file for one Monster resource
2. Build dump utility for Jai parser output
3. Design comparison format

---

## 2026-01-28: Authoritative Specification Analysis

### Key Discovery: lang/ Folder

The `lang/` folder in the original source contains the **authoritative specification**:

1. **`Tokens.lex`** (483 lines) - FLex lexer specification
   - Defines all token types, keywords, context sensitivity
   - Shows exactly how `brace_level`, `decl_state` control keyword recognition
   - Lists all Keywords1 (always reserved) vs Keywords2 (only outside code)
   - Defines ATTRIBUTE, COLOR, DIRECTION, WEP_TYPE, STYPE tokens with values

2. **`Grammar.acc`** (1500+ lines) - ACCENT parser grammar
   - Complete BNF+ with semantic actions
   - Shows exact syntax for every resource type
   - Defines `cexpr` precedence levels, `dice_val`, `mval`, etc.
   - Shows `gear_entry`, `special_ability`, `abil_level` syntax

### Verification Strategy Refinement

With the authoritative specs available, the best approach is:

1. **Grammar-Based Testing**: Write test cases that exercise every grammar rule
2. **Token Verification**: Ensure lexer produces correct tokens for all categories
3. **Parse Tree Comparison**: For each resource type, verify parsed structures match

### Practical Verification Checklist

For each resource type, verify:
- [ ] All fields are parsed correctly
- [ ] Optional fields default to correct values
- [ ] Flags are accumulated properly (| operator)
- [ ] Nested constructs (gear_entry, special_ability) work
- [ ] Event handlers parse and attach correctly
- [ ] Constants and Lists are stored properly

### Original Parser Infrastructure

From exploration:
- `src/yygram.cpp` (36,962 lines) - Generated ACCENT parser
- `src/Tokens.cpp` - Generated FLex lexer
- `src/RComp.cpp` (1,440 lines) - Compiler driver
- `src/Debug.cpp` - Has `Dump()` methods for all resource types (lines 1856-1978)

The `TMonster::Dump()`, `TItem::Dump()` etc. functions could be used to generate expected output for comparison.

---

## 2026-01-28: Glyph Rendering Architecture Discovery

### Context

Extended glyphs (GLYPH_FLOOR = 323, GLYPH_WALL = 264, etc.) were rendering as "?" in screenshots because the bitmap font only has 256 characters.

### Initial Misunderstanding

Investigation initially focused on `src/Wcurses.cpp` which contains Unicode mappings for GLYPH_* constants. This led to the assumption that Unicode was the primary rendering path.

### Corrected Understanding

User pointed out that **fonts are the PRIMARY display**:

1. The original Incursion used CP437 bitmap fonts as the main rendering mode
2. Unicode/ASCII in `Wcurses.cpp` is a **fallback** for pure curses/text terminals
3. The authoritative lookup table is in `src/Wlibtcod.cpp` lines 448-600

### Key Technical Details

**GLYPH_* constants are aliases** that map to CP437 character codes:
- `GLYPH_FLOOR (323)` → CP437 code 250 (middle dot)
- `GLYPH_WALL (264)` → CP437 code 177 (medium shade)
- `GLYPH_ROCK (265)` → CP437 code 176 (light shade)

**Color is applied separately** from glyphs:
- Lava (red) and water (blue) share the same glyph image (CP437 code 247)
- The glyph defines shape, color is applied on top

### Files Examined

| File | Role |
|------|------|
| `src/Wlibtcod.cpp` | Primary rendering - CP437 lookup table (authoritative) |
| `src/Wcurses.cpp` | Fallback rendering - Unicode mapping (NOT primary) |
| `fonts/*.png` | CP437 bitmap fonts (16x16 grid of 256 chars) |

### Action Taken

- Updated notes.md with "Display and Rendering Architecture" section
- Added high-priority backlog entry for implementing GLYPH_* → CP437 lookup
- Our 8x8.png font is already CP437 layout, so only the lookup table is needed

### Verification Implications

When verifying rendering correctness:
- Use `Wlibtcod.cpp` as the authoritative reference, NOT `Wcurses.cpp`
- Verify glyph → CP437 mapping produces correct font atlas indices
- Color application is independent of glyph selection

---

## 2026-01-29: Subproject Structure Alignment

### Changes Made

Restructured correctness-research to follow preferred subproject structure from CLAUDE.md:

**Before:**
```
correctness-research/
├── notes.md      # Everything in one file
└── JOURNAL.md
```

**After:**
```
correctness-research/
├── README.md     # Overview, current state, quick reference
├── NOTES.md      # Detailed technical reference (renamed for consistent casing)
├── JOURNAL.md    # Session history
└── BACKLOG.md    # Open questions, tools to develop, deferred work
```

### Content Distribution

- **README.md** - Goal, current state, approach summary, verification phases, key references
- **NOTES.md** - Authoritative specs, verification approaches, phased approach details, file references, concrete examples, rendering architecture
- **BACKLOG.md** - Open questions, tools to develop checklist, deferred work items, ideas

### Rationale

- Quick orientation via README without wading through technical details
- Trackable open items in BACKLOG (checkboxes for tools, deferred work)
- Deep reference material preserved in NOTES
- Consistent uppercase naming across subproject files

---

## 2026-01-29: Rendering Pipeline Investigation

### Motivation

Extended glyphs (GLYPH_FLOOR=323, GLYPH_WALL=264, etc.) were rendering as "?" because we didn't understand how glyph IDs map to rendered characters. This investigation documents the complete rendering pipeline.

### Key Discoveries

**Glyph is a u32 bitfield:**
```
Bits 0-11:  Character ID (0-4095, includes GLYPH_* constants)
Bits 12-15: Foreground color (0-15 ANSI palette)
Bits 16-19: Background color (0-15 ANSI palette)
```

**GLYPH_* constants are semantic aliases:**
- Values 256+ represent semantic meaning (GLYPH_FLOOR, GLYPH_WALL, etc.)
- Must be converted to CP437 codes (0-255) at render time
- Lookup table in `src/Wlibtcod.cpp` lines 448-606 is authoritative

**Color separation is intentional:**
- Water (blue) and Lava (red) share CP437 code 247 (≈)
- Color field distinguishes them, not the glyph shape
- This is why FG color is stored separately from character ID

**Runtime storage:**
- TMonster, TItem, TTerrain all have `Glyph Image` field
- Field stores complete bitfield (character + colors)
- Parsed from `Image: color 'char';` syntax in .irh files

### Rendering Decision Flow

From `src/Term.cpp` lines 701-868:

1. Get base terrain glyph from LocationInfo
2. Check Contents list for creatures/items
3. Apply priority (creatures > items > features > terrain)
4. Handle multiples (GLYPH_MULTI for creatures, GLYPH_PILE for items)
5. Apply visibility rules (unseen → space, remembered → memory, visible → current)
6. Extract colors and character, call terminal

### Output

Created `docs/research/specs/rendering-pipeline.md` with:
- Complete Glyph bitfield documentation
- GLYPH_* to CP437 mapping table
- Color palette reference
- Rendering priority rules
- Verification checklist

### Impact

This investigation would have prevented the "?" glyph bug if done earlier. The fix is clear:
1. Implement GLYPH_* → CP437 lookup table
2. Apply lookup before font atlas indexing
3. Our 8x8.png font is already CP437 layout - no font changes needed

---

## 2026-01-29: CP437 Lookup Integration

Integrated `glyph_to_cp437()` into the rendering pipeline.

**Changes:**
- `src/terminal/window.jai`: Apply CP437 lookup before UV coordinate calculation
- `tools/dungeon_test.jai`: Use lookup in screenshot rendering
- `tools/inspect.jai`: Use lookup for ASCII output
- `src/dungeon/terrain_registry.jai`: Fixed u8 truncation bug (was losing extended glyphs)

**Verification:**
- All tools compile successfully
- Tests pass (177/181, same as before)
- "Extended glyph codes (256+) preserved: YES" in test output

**Remaining:** Visual verification that GLYPH_FLOOR, GLYPH_WALL render correctly.

---

*Future entries should be appended below*
