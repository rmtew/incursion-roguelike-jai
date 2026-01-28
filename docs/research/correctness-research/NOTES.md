# Correctness Research - Technical Reference

Detailed notes on verification strategies and original source structure.

## Original Source Location

`C:\Data\R\roguelike - incursion\repo-work\`

## Authoritative Specification Files

The `lang/` folder contains the canonical parser specification:

### `lang/Tokens.lex` (FLex format)
The lexer specification defines:
- **Keywords1** (line 58-70): Reserved everywhere - `abs`, `continue`, `bool`, `break`, `case`, `default`, `do`, `else`, `false`, `for`, `hObj`, `hText`, `int8/16/32`, `uint8/16`, `if`, `max`, `min`, `member`, `return`, `rID`, `static`, `string`, `switch`, `true`, `NULL`, `void`, `while`, `rect`
- **Keywords2** (line 73-141): Only outside code blocks - `Ability`, `Acc`, `Align`, `Attk`, `CR`, `Flags`, `Gear`, `Glyph`, `Grants`, `Image`, `Monster`, etc.
- **AttrWords** (line 143-146): `Str`, `Dex`, `Con`, `Int`, `Wis`, `Cha`, `Luc`, `Loy` → returns ATTRIBUTE token with value
- **DirWords** (line 148-152): `North`, `South`, etc. → returns DIRECTION token with value
- **ColourWords** (line 154-160): `black`, `grey`, `white`, `blue`, etc. → returns COLOR token with value
- **Weapon types** (line 212-217): `slash`/`slashing`, `pierce`/`piercing`, `blunt` → WEP_TYPE
- **Save types** (line 219-224): `fort`, `ref`, `will` → STYPE

**Key lexer state variables:**
- `brace_level` - tracks `{` `}` nesting depth
- `decl_state` - set when parsing type declarations
- `if_cond` - set when parsing if condition outside code block
- `paren_level` - tracks `(` `)` nesting

**Context sensitivity:** Keywords2 become identifiers inside code blocks (brace_level >= 2)

### `lang/Grammar.acc` (ACCENT format)
The BNF+ grammar with semantic actions. Key production rules:

**Resource types:**
- `monster_def` (line 398-408)
- `item_def` (line 536-544)
- `feature_def` (line 620-625)
- `effect_def` (line 642-682) - includes AND chaining
- `race_def` (line 722-731)
- `class_def` (line 762-765)
- `artifact_def` (line 857-860)
- `dungeon_def` (line 818-821)
- `terrain_def` (line 940-944)
- `template_def` (line 1001-1007)
- `flavor_def` (line 1109-1117)
- `encounter_def` (line 1127-1134)
- `behaviour_def` (line 1202-1207)

**Expression/value parsing:**
- `cexpr` → `cexpr2` → `cexpr3` → `cexpr4` (precedence levels, lines 238-266)
- `dice_val` (line 268-277): `NdS+B` or just constant
- `mval` (line 385-396): Template modifiers with `+`, `-`, `=`, `%` and bounds
- `res_ref` (line 225-236): `$"name"` or `$constant`

**Shared constructs:**
- `gear_entry` (line 286-317): Complex gear with IF, chance, dice, CURSED/BLESSED, WITH/OF
- `glyph_entry` (line 329-337): `Image: color 'g';`
- `event_desc` (line 346-367): `On Event EV_XXX { code };`
- `special_ability` (line 790-797): `Ability[X]`, `Stati[X]`, `Feat[X]` AT level
- `abil_level` (line 805-816): `Nth level`, `every N level`, `every level starting at N`
- `dconst_entry` (line 830-849): `Constants: * CONST val;` and `Lists:`, `Specials:`

## Verification Approaches

### 1. Parser Output Comparison

**Concept**: Parse the same `.irh` files with both original C++ and new Jai parser, compare semantic output.

**Implementation Options**:
- A) Instrument original parser to dump parsed structures to JSON/text
- B) Write standalone C++ tool using original parsing code that outputs structured data
- C) Extract expected values manually and create golden test files

**Pros**: Direct comparison at the data level
**Cons**: Original parser is tightly coupled to game; may need significant extraction work

### 2. Golden File Testing

**Concept**: Create expected-output files for specific resources, verify parser produces matching results.

**Example**:
```
# Input: Monster "goblin" from base.irh
# Expected output:
name: "goblin"
mtype: MA_GOBLIN | MA_EVIL
cr: 1
hd: 1
size: SZ_SMALL
flags: M_HUMANOID
image.color: green
image.glyph: 'g'
```

**Pros**: Simple, self-contained tests; documents expected behavior
**Cons**: Manual effort to create; may miss edge cases

### 3. Value Extraction from Original Executable

**Concept**: Run original game, extract runtime data structures via debugger or memory inspection.

**Tools**:
- Visual Studio debugger with watch expressions
- Custom debug commands in original source
- Memory dumps with structure layouts

**Pros**: Gets actual runtime values including computed fields
**Cons**: Complex setup; requires building/running original

### 4. Behavioral Testing via Replay

**Concept**: Record game sessions in original, replay inputs in port, compare outcomes.

**Components**:
- Input recorder for original game
- Deterministic RNG seeding
- State comparator

**Pros**: Tests full system behavior
**Cons**: Requires significant infrastructure; may be fragile

### 5. Property-Based Invariant Testing

**Concept**: Define invariants that must hold, verify both implementations satisfy them.

**Example invariants**:
- "All monsters have non-negative HP"
- "CR 1 monsters have HD between 1-3"
- "Weapon damage dice are valid (e.g., 1d8, 2d6)"
- "All referenced constants exist"

**Pros**: Catches classes of bugs; documents rules
**Cons**: Doesn't guarantee exact replication

### 6. Side-by-Side Code Review

**Concept**: Structured manual review comparing original C++ to Jai port.

**Process**:
1. Identify critical functions (combat resolution, effect application, etc.)
2. Document original algorithm
3. Verify port implements same algorithm
4. Create test cases for edge behaviors

**Pros**: Catches subtle logic differences
**Cons**: Time-intensive; requires deep understanding

## Recommended Phased Approach

### Phase 1: Parser Verification (Current Priority)

1. **Create resource dump tool** for Jai parser
   - Output parsed structures in readable format
   - Include all fields, flags, grants, etc.

2. **Build golden file corpus**
   - Select representative resources from each type
   - Manually extract expected values from original
   - Create test files with input/expected pairs

3. **Automated comparison**
   - Parse test resources
   - Compare to golden files
   - Report discrepancies

### Phase 2: Constants and Flags Verification

1. Verify all 3572 constants have correct values
2. Cross-reference flag combinations used in resources
3. Ensure enum mappings match original

### Phase 3: Mechanics Verification (Post-Parser)

1. Combat formulas
2. Skill checks
3. Spell effects
4. Status effects (Stati)

### Phase 4: Generation Verification (Post-Dungeon Gen)

1. Room/corridor placement rules
2. Monster placement by depth
3. Item distribution
4. Feature placement

## Key Files for Extraction

### Original Source Files to Analyze

| Area | Files | Purpose |
|------|-------|---------|
| Parser | `src/Res.cpp`, `lang/Grammar.acc` | How resources are parsed |
| Combat | `src/Combat.cpp`, `src/Attack.cpp` | Combat resolution |
| Magic | `src/Magic.cpp`, `src/Spells.cpp` | Spell effects |
| Dungeon | `src/Dungeon.cpp` | Level generation |
| Monsters | `src/Monster.cpp` | Monster behavior |

### Resource Files to Test

| File | Contents | Priority |
|------|----------|----------|
| `lib/base.irh` | Core monsters, items | High |
| `lib/class.irh` | Character classes | High |
| `lib/race.irh` | Playable races | High |
| `lib/spell.irh` | Spell definitions | Medium |
| `lib/effect.irh` | Status effects | Medium |

## Original Dump Functions

The original has `Dump()` methods in `src/Debug.cpp`:
- `TMonster::Dump()` (line 1920) - outputs Image, CR, MType, Hit/Def/Mov/Spd, attributes, resistances, immunities, stati, flags, annotations
- `Resource::Dump()` (line 1856) - base name output
- `Annotation::Dump()` (line 1897) - annotation details

These can be used to generate reference output for comparison.

## Concrete Verification Example

### Test Case: Parsing "goblin" Monster

**Input** (from base.irh):
```
Monster "goblin" : MA_GOBLIN, MA_EVIL {
    Image: green 'g';
    CR: 1;
    HD: 1;
    Size: SZ_SMALL;
    Flags: M_HUMANOID;
}
```

**Expected Parsed Output**:
```
ParsedMonster {
    name: "goblin"
    mtypes: [MA_GOBLIN, MA_EVIL, 0]
    image: Glyph { fg: GREEN, bg: BLACK, char: 'g' }
    cr: 1
    hd: 1
    size: SZ_SMALL
    flags: [M_HUMANOID]
    // defaults
    hit: 0, def: 0, arm: 0, mov: 0, spd: 0
    attr: [0, 0, 0, 0, 0, 0]
    res: 0, imm: 0
}
```

**Verification Steps**:
1. Parse the resource with Jai lexer/parser
2. Serialize ParsedMonster to comparable format
3. Compare against expected values
4. Report any discrepancies

## Implementation Priority

### Phase 1: Core Correctness (Immediate)
1. **Constant values** - Verify all 3572 constants match original Defines.h
2. **Token types** - Verify lexer produces correct tokens for sample inputs
3. **Simple resources** - Verify Flavor, Feature, Terrain parse correctly

### Phase 2: Complex Resources
1. **Monster** - Full parsing including attacks, stati, gear, events
2. **Item** - All item types (weapon, armor, container, light)
3. **Effect** - Including AND chaining for multi-part effects

### Phase 3: Advanced Constructs
1. **Gear entries** - IF conditions, percentages, WITH/OF clauses
2. **Grants** - Ability/Stati/Feat at various level syntaxes
3. **Event handlers** - Code block parsing and compilation

### Phase 4: Integration
1. **Parse entire base.irh** - Verify all resources parse without error
2. **Cross-reference check** - Verify $"name" references resolve
3. **Module loading** - Verify Module/Slot/File headers work

## Display and Rendering Architecture

### Key Understanding (Corrected 2026-01-28)

The original Incursion has **two rendering paths**:

1. **Primary: CP437 Bitmap Fonts** (via libtcod)
   - Uses 256-character fonts in 16x16 grid layout
   - Characters are Code Page 437 glyphs
   - This is the MAIN display mode

2. **Fallback: Unicode/ASCII** (via curses)
   - Used only for pure text terminals
   - Maps GLYPH_* constants to Unicode code points
   - NOT the primary rendering path

### GLYPH_* Constants

The `GLYPH_*` constants (256+) are **aliases** that map to CP437 character codes via a lookup table:

| Constant | Value | CP437 Code | Character |
|----------|-------|------------|-----------|
| GLYPH_FLOOR | 323 | 250 | Middle dot · |
| GLYPH_FLOOR2 | 324 | 249 | Small square |
| GLYPH_WALL | 264 | 177 | Medium shade ▒ |
| GLYPH_ROCK | 265 | 176 | Light shade ░ |
| GLYPH_WATER | - | 247 | Almost equal ≈ |
| GLYPH_LAVA | - | 247 | Almost equal ≈ |

### Color Separation

**Color is applied separately from glyphs.** This allows:
- Lava (red) and water (blue) to share the same glyph image (CP437 code 247)
- The glyph defines the shape, color is applied on top
- This is why the color mapping system and glyph rendering are orthogonal

### Authoritative Reference Files

| File | Purpose |
|------|---------|
| `src/Wlibtcod.cpp` lines 448-600 | **Primary** GLYPH_* → CP437 lookup table |
| `src/Wcurses.cpp` lines 503-644 | Fallback GLYPH_* → Unicode mapping |
| `inc/Defines.h` | GLYPH_* constant definitions |
| `fonts/*.png` | CP437 bitmap font images |

### Verification Implications

When verifying rendering correctness:
1. Use CP437 lookup table from `Wlibtcod.cpp` as the authoritative reference
2. Do NOT use Unicode mappings from `Wcurses.cpp` (that's fallback only)
3. Verify glyph → CP437 mapping produces correct font atlas indices
4. Verify color application is independent of glyph selection
