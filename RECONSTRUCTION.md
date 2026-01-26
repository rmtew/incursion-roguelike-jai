# Incursion Port - Reconstruction Guide

This document captures the implementation state before accidental deletion to aid in reconstruction.

## Project Structure

```
incursion-port/
  CLAUDE.md              - Project guide for Claude sessions
  specs/
    progress.md          - Progress tracker (564 tests passing)
    resource-system.md   - Resource system design
    resource-grammar.md  - Grammar reference
    architecture.md      - System architecture
    porting-patterns.md  - C++ to Jai patterns
  src/
    main.jai             - Entry point, imports all modules, runs tests
    defines.jai          - Core types, enums, constants (VERSION_STRING, etc.)
    dice.jai             - Dice system (Dice struct, roll, parse_dice, etc.)
    object.jai           - Object/Thing base classes with Stati system
    map.jai              - Map, LocationInfo, Field, Overlay
    creature.jai         - Creature, Character, Player, Monster
    item.jai             - Item, QItem, Weapon, Armour, Container
    feature.jai          - Feature, Door, Trap, Portal
    term.jai             - Terminal abstraction
    term_console.jai     - Windows console backend
    resource.jai         - Resource template structures (TMonster, TItem, etc.)
    event.jai            - Event system
    vision.jai           - Vision/FOV system
    registry.jai         - Handle-based object registry
    tests.jai            - Test suite (564 tests)
    resource/
      constants.jai      - 4045 constants extracted from Defines.h
      lexer.jai          - Tokenizer (130+ token types)
      parser.jai         - Recursive descent parser
```

## Resource Parser - Parsed Types

### Parser Struct
```jai
Parser :: struct {
    tokens:     [] Token;
    pos:        s64;
    errors:     [..] ParseError;
    had_error:  bool;

    // Parsed results
    flavors:    [..] ParsedFlavor;
    items:      [..] ParsedItem;
    monsters:   [..] ParsedMonster;
    effects:    [..] ParsedEffect;
    features:   [..] ParsedFeature;
    terrains:   [..] ParsedTerrain;
    races:      [..] ParsedRace;
    classes:    [..] ParsedClass;
}
```

### ParsedFlavor
```jai
ParsedFlavor :: struct {
    name:           string;
    itype:          s64;          // AI_POTION, AI_SCROLL, etc.
    has_desc:       bool;
    desc:           string;
    has_material:   bool;
    material:       s64;
    has_color:      bool;
    color:          ParsedColor;
    has_weight:     bool;
    weight:         s64;
    line, column:   s32;
}
```

### ParsedItem
```jai
ParsedItem :: struct {
    name:       string;
    itype:      s64;              // T_WEAPON, T_ARMOUR, etc.

    has_image:      bool;
    image:          ParsedGlyph;
    has_level:      bool;
    level:          s64;
    has_depth:      bool;
    depth:          s64;
    has_material:   bool;
    material:       s64;
    has_weight:     bool;
    weight:         s64;
    has_size:       bool;
    size:           s64;
    has_cost:       bool;
    cost:           s64;
    has_group:      bool;
    group:          s64;
    has_hp:         bool;
    hp:             s64;
    has_nutrition:  bool;
    nutrition:      s64;

    // Weapon properties
    has_small_dmg:  bool;
    small_dmg:      ParsedDice;
    has_large_dmg:  bool;
    large_dmg:      ParsedDice;
    has_acc:        bool;
    acc:            s64;
    has_crit:       bool;
    crit:           s64;
    has_threat:     bool;
    threat:         s64;
    has_speed:      bool;
    speed:          s64;
    has_parry:      bool;
    parry:          s64;
    has_range:      bool;
    range:          s64;

    // Armor properties
    has_coverage:   bool;
    coverage:       s64;
    has_penalty:    bool;
    penalty:        s64;
    has_arm:        bool;
    arm:            s64;
    has_def:        bool;
    def:            s64;

    flags:          [..] s64;
    has_desc:       bool;
    desc:           string;
    line, column:   s32;
}
```

### ParsedMonster
```jai
ParsedMonster :: struct {
    name:       string;
    mtypes:     [..] s64;         // MA_DRAGON, MA_FIRE, etc.

    has_image:      bool;
    image:          ParsedGlyph;
    has_desc:       bool;
    desc:           string;
    has_size:       bool;
    size:           s64;
    has_cr:         bool;
    cr:             s64;
    has_hd:         bool;
    hd:             s64;
    has_mov:        bool;
    mov:            s64;
    has_spd:        bool;
    spd:            s64;
    has_hit:        bool;
    hit:            s64;
    has_def:        bool;
    def:            s64;
    has_arm:        bool;
    arm:            s64;

    // Attributes
    has_str, has_dex, has_con: bool;
    has_int, has_wis, has_cha: bool;
    str_val, dex_val, con_val: s64;
    int_val, wis_val, cha_val: s64;

    attacks:        [..] ParsedAttack;
    flags:          [..] s64;
    immunities:     [..] s64;
    resistances:    [..] s64;
    stati:          [..] ParsedStati;
    line, column:   s32;
}

ParsedAttack :: struct {
    atype:      s64;              // A_BITE, A_CLAW, etc.
    damage:     ParsedDice;
    dtype:      s64;              // AD_SLASH, AD_FIRE, etc.
    dc:         s64;
    has_dc:     bool;
    extra_dtype: s64;
    has_extra:  bool;
    res_ref:    string;
    has_res_ref: bool;
}

ParsedStati :: struct {
    stati_type: s64;              // SUSTAIN, REGEN, etc.
    param1:     s64;
    param2:     s64;
    has_param2: bool;
}
```

### ParsedEffect (for Effect and Spell)
```jai
ParsedEffect :: struct {
    name:       string;
    etype:      s64;              // EA_INFLICT, EA_BLAST, etc.
    is_spell:   bool;

    sources:    [..] s64;         // AI_WIZARDRY, AI_PRIESTLY, etc.

    has_level:      bool;
    level:          s64;
    has_schools:    bool;
    schools:        s64;          // SC_EVO | SC_FIRE, etc.
    has_qval:       bool;
    qval:           s64;
    has_xval:       bool;
    xval:           s64;
    has_yval:       bool;
    yval:           s64;
    has_pval:       bool;
    pval:           ParsedDice;

    flags:          [..] s64;
    has_desc:       bool;
    desc:           string;

    sub_effects:    [..] ParsedSubEffect;
    line, column:   s32;
}

ParsedSubEffect :: struct {
    etype:      s64;
    has_xval:   bool;
    xval:       s64;
    has_yval:   bool;
    yval:       s64;
    has_pval:   bool;
    pval:       ParsedDice;
    flags:      [..] s64;
}
```

### ParsedFeature
```jai
ParsedFeature :: struct {
    name:       string;
    ftype:      s64;              // T_DOOR, T_PORTAL, T_FEATURE, T_TRAP

    has_image:      bool;
    image:          ParsedGlyph;  // Supports background color
    has_material:   bool;
    material:       s64;
    has_hp:         bool;
    hp:             s64;
    has_xval:       bool;
    xval:           s64;
    has_cval:       bool;
    cval:           s64;
    has_target:     bool;
    target:         string;
    has_desc:       bool;
    desc:           string;

    flags:          [..] s64;
    constants:      [..] ParsedConstant;
    line, column:   s32;
}
```

### ParsedTerrain
```jai
ParsedTerrain :: struct {
    name:       string;

    has_image:      bool;
    image:          ParsedGlyph;  // Supports background color
    has_material:   bool;
    material:       s64;
    has_desc:       bool;
    desc:           string;

    flags:          [..] s64;
    constants:      [..] ParsedConstant;
    line, column:   s32;
}
```

### ParsedRace
```jai
ParsedRace :: struct {
    name:       string;

    // Parent race (for subraces)
    has_parent: bool;
    parent:     string;

    // Attribute modifiers
    has_attrs:  bool;
    str_mod, dex_mod, con_mod: s64;
    int_mod, wis_mod, cha_mod: s64;
    luc_mod:    s64;

    // Monster template reference
    has_monster: bool;
    monster:    string;

    // Favoured classes
    favoured:   [..] string;

    // Racial skills
    skills:     [..] s64;

    // Grants
    grants:     [..] ParsedGrant;

    // Starting gear
    gear:       [..] ParsedGearEntry;

    // Description
    has_desc:   bool;
    desc:       string;

    // Names
    has_male_names:   bool;
    male_names:       string;
    has_female_names: bool;
    female_names:     string;
    has_family_names: bool;
    family_names:     string;

    // Lists and Constants
    lists:      [..] ParsedList;
    constants:  [..] ParsedConstant;

    line, column: s32;
}
```

### ParsedClass
```jai
ParsedClass :: struct {
    name:       string;

    has_desc:   bool;
    desc:       string;

    // Core stats
    has_hitdice: bool;
    hitdice:    s64;              // 4, 6, 8, 10, 12
    has_mana:   bool;
    mana:       s64;
    has_def:    bool;
    def_num:    s64;              // Defense fraction numerator
    def_denom:  s64;              // Defense fraction denominator

    // Attack bonuses
    attk:       [..] ParsedAttackBonus;

    // Skills[n]
    has_skills: bool;
    skill_count: s64;
    skills:     [..] s64;

    // Proficiencies
    proficiencies: [..] s64;

    // Grants, Gear, Flags, Lists, Constants
    grants:     [..] ParsedGrant;
    gear:       [..] ParsedGearEntry;
    flags:      [..] s64;
    lists:      [..] ParsedList;
    constants:  [..] ParsedConstant;

    line, column: s32;
}

ParsedAttackBonus :: struct {
    skill:      s64;              // S_BRAWL, S_MELEE, S_ARCHERY, S_THROWN
    bonus:      s64;              // Percentage (100, 75, 50)
}
```

### Shared Structs
```jai
ParsedGrant :: struct {
    grant_type: GrantType;        // FEAT, ABILITY, STATI

    // For Feat grants
    feat_id:    s64;

    // For Ability grants
    ability_id: s64;
    ability_param1: s64;
    ability_param2: s64;
    has_param2: bool;

    // For Stati grants
    stati_type: s64;
    stati_param1: s64;
    stati_param2: s64;

    // Level condition
    level_type: LevelType;        // AT_LEVEL, EVERY_LEVEL, EVERY_NTH_LEVEL
    level:      s64;
    every_n:    s64;
    starting_level: s64;
}

GrantType :: enum u8 { FEAT; ABILITY; STATI; }
LevelType :: enum u8 { AT_LEVEL; EVERY_LEVEL; EVERY_NTH_LEVEL; }

ParsedGearEntry :: struct {
    has_quantity: bool;
    quantity:   ParsedDice;
    item_ref:   string;
}

ParsedList :: struct {
    list_type:  s64;
    entries:    [..] ParsedListEntry;
}

ParsedListEntry :: struct {
    level:      s64;
    refs:       [..] string;
}

ParsedConstant :: struct {
    key:        s64;
    value:      s64;
}

ParsedDice :: struct {
    num:    s8;
    sides:  s8;
    bonus:  s8;
}

ParsedGlyph :: struct {
    color:      ParsedColor;
    char_code:  s64;
    has_bg:     bool;
    bg_color:   ParsedColor;
}

ParsedColor :: struct {
    modifier:   ColorModifier;    // NONE, BRIGHT, LIGHT, DARK
    base:       BaseColor;        // BLACK, WHITE, RED, etc.
}
```

## Lexer Token Types

```jai
TokenType :: enum u16 #specified {
    INVALID :: 0;
    EOF     :: 1;

    // Literals (10-19)
    NUMBER      :: 10;
    STRING      :: 11;
    CHAR_CONST  :: 12;
    IDENTIFIER  :: 13;
    CONSTANT    :: 14;   // Uppercase constant resolved to value

    // Special (20-29)
    DICE_D      :: 20;   // 'd' in dice notation
    RES_REF     :: 21;   // $"name" or $123
    CRIT_MULT   :: 22;   // x2, x3, x4
    PERCENT     :: 23;   // number%

    // Punctuation (30-39)
    COLON :: 30; SEMICOLON :: 31; COMMA :: 32;
    LBRACE :: 33; RBRACE :: 34;
    LPAREN :: 35; RPAREN :: 36;
    LBRACKET :: 37; RBRACKET :: 38;

    // Operators (40-59)
    PLUS :: 40; MINUS :: 41; STAR :: 42; SLASH :: 43;
    PIPE :: 44; AMPERSAND :: 45; // etc.

    // Multi-char operators (60-89)
    EQ :: 67; NEQ :: 68; AND :: 69; OR :: 70; // etc.

    // Keywords (100+)
    KW_IF :: 100; KW_ELSE :: 101; KW_FOR :: 102; // etc.

    // Resource keywords (200+)
    KW_MONSTER :: 200; KW_ITEM :: 201; KW_FLAVOR :: 202;
    KW_EFFECT :: 203; KW_SPELL :: 204; KW_FEATURE :: 205;
    KW_TERRAIN :: 206; KW_RACE :: 207; KW_CLASS :: 208;
    // ... many more

    // Property keywords (230+)
    KW_IMAGE :: 230; KW_LEVEL :: 231; KW_HITDICE :: 232;
    KW_MAT :: 233; KW_WEIGHT :: 234; KW_SIZE :: 235;
    KW_SDMG :: 236; KW_ATTK :: 237; KW_LDMG :: 238;
    // ... etc.

    // Effect keywords (350+)
    KW_QVAL :: 350; KW_XVAL :: 351; KW_YVAL :: 352;
    KW_PVAL :: 353; KW_SCHOOLS :: 354;

    // Feature/Terrain keywords (360+)
    KW_TARGET :: 360; KW_CONSTANTS :: 361; KW_CVAL :: 362;

    // Race/Class keywords (370+)
    KW_GRANTS :: 370; KW_FAVOURED :: 371; KW_SKILLS :: 372;
    KW_LISTS :: 373; KW_ABILITY :: 374; KW_FEAT :: 375;
    KW_AT :: 376; KW_EVERY :: 377; KW_STARTING :: 378;
    KW_ND :: 379; KW_RD :: 380; KW_TH :: 381; KW_ST :: 382;
    KW_PROFICIENCIES :: 383;

    // Attribute keywords (280+)
    KW_STR :: 280; KW_DEX :: 281; KW_CON :: 282;
    KW_INT :: 283; KW_WIS :: 284; KW_CHA :: 285;
    KW_LUC :: 286;

    // Color keywords (310+)
    KW_RED :: 310; KW_BLUE :: 311; KW_GREEN :: 312;
    KW_WHITE :: 313; KW_BLACK :: 314; KW_YELLOW :: 315;
    // ... etc.
    KW_BRIGHT :: 330; KW_DARK :: 331; KW_LIGHT :: 332;
}
```

## Key Implementation Details

### Constants System
- 4045 constants extracted from original Defines.h
- Binary search lookup by name
- Constants stored as s64 to handle both negative sentinels and large bit flags
- Hex values preserved where meaningful

### Lexer Features
- Context-sensitive: tracks brace_level for code blocks
- Handles: comments (// and /* */), strings, char constants
- Dice notation: 1d6, 2d8+3
- Resource references: $"name" and $123
- Critical multipliers: x2, x3, x4
- Percentages: 100%
- All uppercase with underscore = constant lookup

### Parser Features
- Recursive descent parser
- Expression parsing with precedence (parse_cexpr, parse_cexpr2, parse_cexpr3)
- Error recovery: skip to semicolon or brace
- Shared grant parsing between Race and Class
- Generic parse_flags_list function

### Test Framework
```jai
test_section :: (name: string) { ... }
test_assert :: (condition: bool, name: string) { ... }
test_assert_eq :: (actual: $T, expected: T, name: string) { ... }
test_strings_equal :: (a: string, b: string) -> bool { ... }
test_summary :: () { ... }
run_all_tests :: () { ... }
```

### Test Coverage (564 tests)
- Dice: 25
- Glyph: 6
- Direction: 6
- Registry: 3
- Object/Thing: 9
- Map: 10
- Creature: 6
- Item: 12
- Feature: 18
- Vision: 9
- Resource: 10
- Event: 5
- Resource Constants: 18
- Resource Lexer: 62
- Resource Parser: 365

## Original Source Reference
- Location: `C:\Data\R\roguelike - incursion\repo-work\`
- Key files:
  - `inc/Defines.h` - Constants
  - `inc/Res.h` - Resource structures
  - `lib/*.irh` - Resource definition files
  - `modaccent/Grammar.acc` - Original grammar

## Next Steps (Before Deletion)
1. TGod parsing was about to be implemented
2. TDomain parsing
3. Event handler translation
4. Resource file loading and linking
