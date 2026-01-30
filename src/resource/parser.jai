// Incursion Port - Resource File Parser
// Reconstructed from RECONSTRUCTION-PARSER.md

// Color types
ColorModifier :: enum u8 { NONE; BRIGHT; LIGHT; DARK; }
BaseColor :: enum u8 { NONE; BLACK; WHITE; RED; BLUE; GREEN; YELLOW; PURPLE; CYAN; GREY; BROWN; PINK; MAGENTA; SHADOW; SKY; AZURE; EMERALD; }

ParsedColor :: struct {
    modifier: ColorModifier;
    base:     BaseColor;
}

ParsedGlyph :: struct {
    color:     ParsedColor;
    char_code: s64;
    has_bg:    bool;
    bg_color:  ParsedColor;
}

ParsedDice :: struct {
    num:   s8;
    sides: s8;
    bonus: s8;
}

ParsedConstant :: struct {
    key:      s64;
    value:    s64;
    is_ref:   bool;    // True if value is a resource reference
    ref_name: string;  // Resource reference name (when is_ref=true)
}

// Grant types
GrantType :: enum u8 { FEAT; ABILITY; STATI; }
LevelType :: enum u8 { AT_LEVEL; EVERY_LEVEL; EVERY_NTH_LEVEL; }

ParsedGrant :: struct {
    grant_type:     GrantType;
    feat_id:        s64;
    feat_param:     s64;        // For Feat[ID,param] syntax
    has_feat_param: bool;
    ability_id:     s64;
    ability_param1: s64;
    ability_param2: s64;
    has_param2:     bool;
    has_ability_ref: bool;      // When ability param is a $"ref" instead of a constant
    ability_ref:    string;     // The referenced resource name
    stati_type:     s64;
    stati_param1:   s64;
    stati_param2:   s64;
    level_type:     LevelType;
    level:          s64;
    every_n:        s64;
    starting_level: s64;
}

GearFlags :: enum_flags u32 {
    CURSED;        // GF_CURSED
    BLESSED;       // GF_BLESSED
    RANDOM_ITEM;   // GF_RANDOM_ITEM
    RANDOM_EFFECT; // GF_RANDOM_EFFECT
    ELSE_BRANCH;   // GF_ELSE
}

ParsedGearEntry :: struct {
    // Condition (IF expr)
    has_condition:   bool;
    condition:       string;  // We store condition code as string for now

    // Chance percentage (N%)
    has_chance:      bool;
    chance:          s64;

    // Quantity (dice)
    has_quantity:    bool;
    quantity:        ParsedDice;

    // Item reference or random
    item_ref:        string;       // $"item name"
    random_item:     s64;          // RANDOM cexpr3

    // Enhancement bonus (+N or -N)
    has_bonus:       bool;
    bonus:           s64;

    // Qualities (WITH [...])
    qualities:       [4] s64;
    quality_count:   s64;

    // Template (OF $"template")
    template_ref:    string;

    // Random effect range (OF RANDOM N TO M)
    random_effect_min: s64;
    random_effect_max: s64;

    // Location (AT (x, y))
    has_location:    bool;
    loc_x:           s64;
    loc_y:           s64;

    // Flags
    flags:           GearFlags;
}

ParsedList :: struct {
    list_type: s64;
    entries:   [..] ParsedListEntry;
}

ParsedListEntry :: struct {
    level: s64;
    refs:  [..] string;
}

// Parsed resource types
ParsedFlavor :: struct {
    name:         string;
    itype:        s64;
    has_desc:     bool;
    desc:         string;
    has_material: bool;
    material:     s64;
    has_color:    bool;
    color:        ParsedColor;
    has_weight:   bool;
    weight:       s64;
    line, column: s32;
}

ParsedAttack :: struct {
    atype:       s64;
    damage:      ParsedDice;
    dtype:       s64;
    dc:          s64;
    has_dc:      bool;
    extra_dtype: s64;
    has_extra:   bool;
    res_ref:     string;
    has_res_ref: bool;
}

ParsedStati :: struct {
    stati_type: s64;
    param1:     s64;
    param2:     s64;
    has_param2: bool;
}

ParsedItem :: struct {
    name:         string;
    itype:        s64;
    has_image:    bool;
    image:        ParsedGlyph;
    has_level:    bool;
    level:        s64;
    has_depth:    bool;
    depth:        s64;
    has_material: bool;
    material:     s64;
    has_weight:   bool;
    weight:       s64;
    has_size:     bool;
    size:         s64;
    has_cost:     bool;
    cost:         s64;
    has_group:    bool;
    group:        s64;
    has_hp:       bool;
    hp:           s64;
    has_nutrition: bool;
    nutrition:    s64;
    has_small_dmg: bool;
    small_dmg:    ParsedDice;
    has_large_dmg: bool;
    large_dmg:    ParsedDice;
    has_acc:      bool;
    acc:          s64;
    has_crit:     bool;
    crit:         s64;
    has_threat:   bool;
    threat:       s64;
    has_speed:    bool;
    speed:        s64;
    has_parry:    bool;
    parry:        s64;
    has_range:    bool;
    range:        s64;
    has_coverage: bool;
    coverage:     s64;
    has_penalty:  bool;
    penalty:      s64;
    has_arm:      bool;
    arm:          s64;
    has_def:      bool;
    def:          s64;
    // Light source properties
    has_lifespan: bool;
    lifespan:     s64;
    has_fuel:     bool;
    fuel:         s64;
    // Container properties
    has_capacity: bool;
    capacity:     s64;
    has_weight_lim: bool;
    weight_lim:   s64;
    has_weight_mod: bool;
    weight_mod:   s64;
    has_max_size: bool;
    max_size:     s64;
    has_timeout:  bool;
    timeout:      s64;
    has_ctype:    bool;
    ctype:        s64;
    // Wand/charged item properties
    has_fires:    bool;
    fires:        [..] string;  // $"spell" references
    flags:        [..] s64;
    has_desc:     bool;
    desc:         string;
    line, column: s32;
}

ParsedMonster :: struct {
    name:         string;
    mtypes:       [..] s64;
    has_image:    bool;
    image:        ParsedGlyph;
    has_desc:     bool;
    desc:         string;
    has_size:     bool;
    size:         s64;
    has_cr:       bool;
    cr:           s64;
    has_hd:       bool;
    hd:           s64;
    has_mov:      bool;
    mov:          s64;
    has_spd:      bool;
    spd:          s64;
    has_hit:      bool;
    hit:          s64;
    has_def:      bool;
    def:          s64;
    has_arm:      bool;
    arm:          s64;
    has_str:      bool;
    str_val:      s64;
    has_dex:      bool;
    dex_val:      s64;
    has_con:      bool;
    con_val:      s64;
    has_int:      bool;
    int_val:      s64;
    has_wis:      bool;
    wis_val:      s64;
    has_cha:      bool;
    cha_val:      s64;
    attacks:      [..] ParsedAttack;
    flags:        [..] s64;
    immunities:   [..] s64;
    resistances:  [..] s64;
    stati:        [..] ParsedStati;
    gear:         [..] ParsedGearEntry;
    line, column: s32;
}

ParsedSubEffect :: struct {
    etype:    s64;
    has_xval: bool;
    xval:     s64;
    has_yval: bool;
    yval:     s64;
    has_pval: bool;
    pval:     ParsedDice;
    flags:    [..] s64;
}

ParsedEffect :: struct {
    name:         string;
    etype:        s64;
    is_spell:     bool;
    sources:      [..] s64;
    has_level:    bool;
    level:        s64;
    has_schools:  bool;
    schools:      s64;
    has_qval:     bool;
    qval:         s64;
    has_xval:     bool;
    xval:         s64;
    has_yval:     bool;
    yval:         s64;
    has_pval:     bool;
    pval:         ParsedDice;
    // Additional effect properties
    has_sval:     bool;
    sval:         s64;
    has_dval:     bool;
    dval:         s64;
    has_aval:     bool;
    aval:         s64;
    has_lval:     bool;
    lval:         s64;
    has_tval:     bool;
    tval:         s64;
    has_rval:     bool;
    rval:         s64;
    has_eval:     bool;
    eval:         s64;
    has_base_chance: bool;
    base_chance:  s64;
    has_purpose:  bool;
    purpose:      s64;
    purpose_param: s64;
    has_purpose_param: bool;
    flags:        [..] s64;
    has_desc:     bool;
    desc:         string;
    sub_effects:  [..] ParsedSubEffect;
    line, column: s32;
}

ParsedFeature :: struct {
    name:         string;
    ftype:        s64;
    has_image:    bool;
    image:        ParsedGlyph;
    has_material: bool;
    material:     s64;
    has_hp:       bool;
    hp:           s64;
    has_xval:     bool;
    xval:         s64;
    has_cval:     bool;
    cval:         s64;
    has_target:   bool;
    target:       string;
    has_desc:     bool;
    desc:         string;
    flags:        [..] s64;
    constants:    [..] ParsedConstant;
    line, column: s32;
}

ParsedTerrain :: struct {
    name:         string;
    has_image:    bool;
    image:        ParsedGlyph;
    has_material: bool;
    material:     s64;
    has_move:     bool;
    move_mod:     s64;
    has_penalty:  bool;
    penalty:      s64;
    has_desc:     bool;
    desc:         string;
    flags:        [..] s64;
    constants:    [..] ParsedConstant;
    line, column: s32;
}

ParsedRace :: struct {
    name:             string;
    has_parent:       bool;
    parent:           string;
    has_attrs:        bool;
    str_mod:          s64;
    dex_mod:          s64;
    con_mod:          s64;
    int_mod:          s64;
    wis_mod:          s64;
    cha_mod:          s64;
    luc_mod:          s64;
    has_monster:      bool;
    monster:          string;
    favoured:         [..] string;
    skills:           [..] s64;
    grants:           [..] ParsedGrant;
    gear:             [..] ParsedGearEntry;
    has_desc:         bool;
    desc:             string;
    has_male_names:   bool;
    male_names:       string;
    has_female_names: bool;
    female_names:     string;
    has_family_names: bool;
    family_names:     string;
    lists:            [..] ParsedList;
    constants:        [..] ParsedConstant;
    line, column:     s32;
}

ParsedAttackBonus :: struct {
    skill: s64;
    bonus: s64;
}

ParsedClass :: struct {
    name:          string;
    has_desc:      bool;
    desc:          string;
    has_hitdice:   bool;
    hitdice:       s64;
    has_mana:      bool;
    mana:          s64;
    has_def:       bool;
    def_num:       s64;
    def_denom:     s64;
    attk:          [..] ParsedAttackBonus;
    has_skills:    bool;
    skill_count:   s64;
    skills:        [..] s64;
    proficiencies: [..] s64;
    grants:        [..] ParsedGrant;
    gear:          [..] ParsedGearEntry;
    flags:         [..] s64;
    lists:         [..] ParsedList;
    constants:     [..] ParsedConstant;
    line, column:  s32;
}

// Template attribute modifier
ParsedAttrMod :: struct {
    is_percentage: bool;
    value:         s64;      // Percentage value (e.g., 55 for 55%) or absolute modifier (e.g., +8)
    has_min:       bool;
    min_value:     s64;
}

ParsedTemplate :: struct {
    name:         string;
    ttype:        s64;           // TM_AGECAT, TM_CLASS, etc.
    has_for:      bool;
    for_mtype:    s64;           // MA_DRAGON, MA_ANIMAL, etc.
    has_desc:     bool;
    desc:         string;
    has_cr:       bool;
    cr:           s64;           // Can be +/- N
    has_size:     bool;
    size:         s64;           // Can be +/- N
    has_power:    bool;
    power:        s64;
    has_depth:    bool;
    depth:        s64;
    // Attribute modifiers
    has_str:      bool;
    str_mod:      ParsedAttrMod;
    has_dex:      bool;
    dex_mod:      ParsedAttrMod;
    has_con:      bool;
    con_mod:      ParsedAttrMod;
    has_int:      bool;
    int_mod:      ParsedAttrMod;
    has_wis:      bool;
    wis_mod:      ParsedAttrMod;
    has_cha:      bool;
    cha_mod:      ParsedAttrMod;
    // Percentage modifiers
    has_mov:      bool;
    mov:          s64;
    has_arm:      bool;
    arm:          s64;
    has_hitdice:  bool;
    hitdice:      s64;
    has_hit:      bool;
    hit:          s64;
    has_caster_level: bool;
    caster_level: s64;
    // Lists
    attacks:      [..] ParsedAttack;
    flags:        [..] s64;
    feats:        [..] s64;
    immunities:   [..] s64;
    mtypes:       [..] s64;
    gear:         [..] ParsedGearEntry;
    grants:       [..] ParsedGrant;
    line, column: s32;
}

// Region
ParsedRegion :: struct {
    name:         string;
    rtype:        s64;           // RF_RIVER, RF_CORRIDOR, etc.
    has_floor:    bool;
    floor:        string;        // $"shallow water"
    has_walls:    bool;
    walls:        string;        // $"Dungeon Wall"
    has_door:     bool;
    door:         string;        // $"oak door"
    has_depth:    bool;
    depth:        s64;
    has_room_types: bool;
    room_types:   [..] s64;      // RM_* constants (parsed from RoomTypes:)
    has_size:     bool;
    size:         s64;           // SZ_* constant
    has_grid:     bool;
    grid:         string;        // Map grid content
    grid_width:   s64;           // Width calculated from grid
    grid_height:  s64;           // Height calculated from grid
    tiles:        [..] ParsedTile;  // Tile overrides from Tiles: section
    flags:        [..] s64;      // RF_VAULT, RF_CORRIDOR, RF_STAPLE, etc.
    lists:        [..] ParsedWeightList;
    constants:    [..] ParsedConstant;
    line, column: s32;
}

// Encounter
ParsedEncounter :: struct {
    name:         string;
    has_weight:   bool;
    weight:       s64;
    has_cr:       bool;
    cr_min:       s64;
    cr_max:       s64;
    has_terrain:  bool;
    terrain:      s64;
    has_align:    bool;
    align:        s64;
    flags:        [..] s64;
    lists:        [..] ParsedList;
    constants:    [..] ParsedConstant;
    line, column: s32;
}

// Domain
ParsedDomain :: struct {
    name:         string;
    index:        s64;
    has_desc:     bool;
    desc:         string;
    grants:       [..] ParsedGrant;
    spells:       [..] string;   // $"spell name" references
    line, column: s32;
}

// God
ParsedGod :: struct {
    name:         string;
    has_desc:     bool;
    desc:         string;
    domains:      [..] string;   // $"domain name" references
    grants:       [..] ParsedGrant;
    lists:        [..] ParsedList;
    constants:    [..] ParsedConstant;
    line, column: s32;
}

// Text (simple help text)
ParsedText :: struct {
    name:         string;
    content:      string;
    line, column: s32;
}

// Module header
ParsedModule :: struct {
    has_name:     bool;
    name:         string;
    has_file:     bool;
    file:         string;
    has_slot:     bool;
    slot:         s64;
}

// Artifact power types
ArtPowerType :: enum u8 { EQUIP; WIELD; HIT; INVOKE; }
ArtPowerKind :: enum u8 { STATI; EFFECT; INNATE; FEAT; }

ParsedArtPower :: struct {
    power_type:   ArtPowerType;  // When this power activates
    kind:         ArtPowerKind;  // What kind of power
    // For STATI
    stati_type:   s64;
    stati_param:  s64;
    // For EFFECT/INNATE
    effect_ref:   string;        // $"spell name"
    // For FEAT
    feat_id:      s64;
    // Usage limits
    has_uses:     bool;
    uses_per_day: s64;
    uses_per_week: s64;
    has_dice:     bool;
    use_dice:     ParsedDice;
}

ParsedArtifact :: struct {
    name:         string;
    has_desc:     bool;
    desc:         string;
    has_item:     bool;
    item_ref:     string;        // Base item $"item name"
    // Attribute adjustments
    attr_adj:     [8] s64;       // A_STR through A_LOY
    has_attr_adj: [8] bool;
    // Properties
    resists:      s64;           // Bitfield of resistances
    sustains:     s64;           // Bitfield of sustained attributes
    qualities:    s64;           // Bitfield of qualities
    // Powers
    powers:       [..] ParsedArtPower;
    line, column: s32;
}

// Dungeon
ParsedSpecial :: struct {
    room_ref:     string;        // $"room name"
    at_level:     s64;
}

// Grid tile override (from Tiles: section in regions)
ParsedTile :: struct {
    ch:           u8;            // Grid character ('A', '1', etc.)
    terrain_ref:  string;        // $"terrain name" (base terrain)
    object_ref:   string;        // $"name" from 'with' clause (monster/item/feature)
    owner_ref:    string;        // $"name" from 'of' clause (template/god)
    flags:        u32;           // TILE_* flags bitmask
}

// Weight list entry for dungeon/region Lists:
WeightListEntry :: struct {
    weight: s64;          // Selection weight (default 1 if not specified)
    value: s64;           // Constant value (RM_*, color, etc.)
    is_ref: bool;         // True if this is a $"ref" reference
    ref_name: string;     // Resource reference name
    // For macro entries like CONSTRAINED_ENC($"name", MA_AQUATIC)
    has_macro: bool;
    macro_name: string;
    macro_args: [..] string;
}

// Weight list (used in dungeons and regions)
ParsedWeightList :: struct {
    list_type: s64;               // RM_WEIGHTS, ROOM_WEIGHTS, WALL_COLOURS, ENCOUNTER_LIST, etc.
    entries: [..] WeightListEntry;
}

ParsedDungeon :: struct {
    name:         string;
    has_desc:     bool;
    desc:         string;
    constants:    [..] ParsedConstant;
    specials:     [..] ParsedSpecial;
    lists:        [..] ParsedWeightList;
    line, column: s32;
}

ParseError :: struct {
    line:    s32;
    column:  s32;
    message: string;
}

Parser :: struct {
    tokens:    [] Token;
    pos:       s64;
    errors:    [..] ParseError;
    had_error: bool;

    // Module header (optional, at top of file)
    module:     ParsedModule;

    // Parsed results
    flavors:    [..] ParsedFlavor;
    items:      [..] ParsedItem;
    monsters:   [..] ParsedMonster;
    effects:    [..] ParsedEffect;
    features:   [..] ParsedFeature;
    terrains:   [..] ParsedTerrain;
    races:      [..] ParsedRace;
    classes:    [..] ParsedClass;
    templates:  [..] ParsedTemplate;
    regions:    [..] ParsedRegion;
    encounters: [..] ParsedEncounter;
    domains:    [..] ParsedDomain;
    gods:       [..] ParsedGod;
    texts:      [..] ParsedText;
    dungeons:   [..] ParsedDungeon;
    artifacts:  [..] ParsedArtifact;
}

// Parser initialization
parser_init :: (tokens: [] Token) -> Parser {
    p: Parser;
    p.tokens = tokens;
    p.pos = 0;
    p.had_error = false;
    return p;
}

parser_free :: (p: *Parser) {
    array_free(p.errors);
    array_free(p.flavors);
    array_free(p.items);
    array_free(p.monsters);
    array_free(p.effects);
    array_free(p.features);
    array_free(p.terrains);
    array_free(p.races);
    array_free(p.classes);
    array_free(p.templates);
    array_free(p.regions);
    array_free(p.encounters);
    array_free(p.domains);
    array_free(p.gods);
    array_free(p.texts);
    array_free(p.dungeons);
}

// Helper functions
peek :: (p: *Parser) -> Token {
    return p.tokens[p.pos];
}

advance :: (p: *Parser) -> Token {
    t := peek(p);
    if p.pos < p.tokens.count - 1 {
        p.pos += 1;
    }
    return t;
}

parser_is_at_end :: (p: *Parser) -> bool {
    return peek(p).type == .EOF;
}

check :: (p: *Parser, type: TokenType) -> bool {
    return peek(p).type == type;
}

match :: (p: *Parser, type: TokenType) -> bool {
    if check(p, type) {
        advance(p);
        return true;
    }
    return false;
}

// Optional colon - consumes colon if present, returns true either way
// Used for grammar rules with (':')?
optional_colon :: (p: *Parser) {
    match(p, .COLON);
}

consume :: (p: *Parser, type: TokenType, msg: string) -> Token, bool {
    if check(p, type) return advance(p), true;
    add_error(p, msg);
    return .{}, false;
}

add_error :: (p: *Parser, msg: string) {
    tok := peek(p);
    err: ParseError;
    err.line = tok.line;
    err.column = tok.column;
    err.message = msg;
    array_add(*p.errors, err);
    p.had_error = true;
}

// Calculate grid dimensions from map grid content
// Returns (width, height). Width is the length of the first non-empty line.
calculate_grid_dimensions :: (grid_text: string) -> s64, s64 {
    width: s64 = 0;
    height: s64 = 0;
    line_start: s64 = 0;
    line_count: s64 = 0;

    for i: 0..grid_text.count-1 {
        if grid_text[i] == #char "\n" {
            line_len := i - line_start;
            // Skip leading/trailing whitespace on the line
            trimmed_len := count_non_whitespace_chars(grid_text, line_start, i);
            if trimmed_len > 0 {
                if width == 0 width = trimmed_len;
                height += 1;
            }
            line_start = i + 1;
        }
    }
    // Handle last line if no trailing newline
    if line_start < grid_text.count {
        trimmed_len := count_non_whitespace_chars(grid_text, line_start, grid_text.count);
        if trimmed_len > 0 {
            if width == 0 width = trimmed_len;
            height += 1;
        }
    }
    return width, height;
}

count_non_whitespace_chars :: (text: string, start: s64, end: s64) -> s64 {
    count: s64 = 0;
    for i: start..end-1 {
        c := text[i];
        if c != #char " " && c != #char "\t" && c != #char "\r" {
            count += 1;
        }
    }
    return count;
}

// Expression parsing
parse_cexpr :: (p: *Parser) -> s64, bool {
    left, ok := parse_cexpr2(p);
    if !ok return 0, false;

    while match(p, .PIPE) {
        right, ok2 := parse_cexpr2(p);
        if !ok2 return 0, false;
        left |= right;
    }
    return left, true;
}

parse_cexpr2 :: (p: *Parser) -> s64, bool {
    left, ok := parse_cexpr3(p);
    if !ok return 0, false;

    while true {
        if match(p, .AMPERSAND) {
            right, ok2 := parse_cexpr3(p);
            if !ok2 return 0, false;
            left &= right;
        } else if match(p, .PLUS) {
            right, ok2 := parse_cexpr3(p);
            if !ok2 return 0, false;
            left += right;
        } else if match(p, .MINUS) {
            right, ok2 := parse_cexpr3(p);
            if !ok2 return 0, false;
            left -= right;
        } else {
            break;
        }
    }
    return left, true;
}

parse_cexpr3 :: (p: *Parser) -> s64, bool {
    tok := peek(p);

    // Unary minus
    if tok.type == .MINUS {
        advance(p);
        val, ok := parse_cexpr3(p);
        if !ok return 0, false;
        return -val, true;
    }

    // Unary plus
    if tok.type == .PLUS {
        advance(p);
        val, ok := parse_cexpr3(p);
        return val, ok;
    }

    // Parenthesized expression
    if tok.type == .LPAREN {
        advance(p);
        val, ok := parse_cexpr(p);
        if !ok return 0, false;
        _, close_ok := consume(p, .RPAREN, "Expected ')'");
        if !close_ok return 0, false;
        return val, true;
    }

    // Number literal
    if tok.type == .NUMBER {
        advance(p);
        return tok.int_value, true;
    }

    // Constant
    if tok.type == .CONSTANT {
        advance(p);
        return tok.int_value, true;
    }

    // Percentage (100%)
    if tok.type == .PERCENT {
        advance(p);
        return tok.int_value, true;
    }

    // Critical multiplier (x2, x3)
    if tok.type == .CRIT_MULT {
        advance(p);
        return tok.int_value, true;
    }

    // Unknown identifier - could be a macro call like OPT_COST(a,b)
    // We parse the call and return the last argument value
    if tok.type == .IDENTIFIER {
        advance(p);
        if check(p, .LPAREN) {
            // Function-like macro call
            advance(p);  // consume '('
            last_val: s64 = 0;
            while !check(p, .RPAREN) && !parser_is_at_end(p) {
                val, ok := parse_cexpr(p);
                if ok {
                    last_val = val;
                }
                if !match(p, .COMMA) break;
            }
            match(p, .RPAREN);
            return last_val, true;
        }
        // Plain identifier - treat as 0
        return 0, true;
    }

    add_error(p, "Expected expression");
    return 0, false;
}

// Dice parsing
parse_dice_value :: (p: *Parser) -> ParsedDice, bool {
    dice: ParsedDice;
    dice.num = 1;
    dice.sides = 0;
    dice.bonus = 0;

    // Parse number of dice - can be NUMBER or (cexpr)
    num_tok := peek(p);
    if num_tok.type == .NUMBER {
        dice.num = cast(s8) num_tok.int_value;
        advance(p);
    } else if num_tok.type == .LPAREN {
        // Parenthesized expression for dice count (e.g., (LEVEL_1PER1)d8)
        advance(p);  // consume '('
        val, ok := parse_cexpr(p);
        if !ok return dice, false;
        _, rparen_ok := consume(p, .RPAREN, "Expected ')' in dice count");
        if !rparen_ok return dice, false;
        dice.num = cast(s8) val;
    }

    // Expect 'd'
    _, d_ok := consume(p, .DICE_D, "Expected 'd' in dice");
    if !d_ok return dice, false;

    // Parse sides
    sides_tok, sides_ok := consume(p, .NUMBER, "Expected dice sides");
    if !sides_ok return dice, false;
    dice.sides = cast(s8) sides_tok.int_value;

    // Optional bonus
    if match(p, .PLUS) {
        bonus_tok, bonus_ok := consume(p, .NUMBER, "Expected bonus value");
        if !bonus_ok return dice, false;
        dice.bonus = cast(s8) bonus_tok.int_value;
    } else if match(p, .MINUS) {
        bonus_tok, bonus_ok := consume(p, .NUMBER, "Expected bonus value");
        if !bonus_ok return dice, false;
        dice.bonus = cast(s8) (-bonus_tok.int_value);
    }

    return dice, true;
}

// Color parsing
token_to_base_color :: (type: TokenType) -> BaseColor, bool {
    if type == .KW_BLACK   return .BLACK, true;
    if type == .KW_WHITE   return .WHITE, true;
    if type == .KW_RED     return .RED, true;
    if type == .KW_BLUE    return .BLUE, true;
    if type == .KW_GREEN   return .GREEN, true;
    if type == .KW_YELLOW  return .YELLOW, true;
    if type == .KW_PURPLE  return .PURPLE, true;
    if type == .KW_CYAN    return .CYAN, true;
    if type == .KW_BROWN   return .BROWN, true;
    if type == .KW_GREY    return .GREY, true;
    if type == .KW_MAGENTA return .MAGENTA, true;
    if type == .KW_PINK    return .PINK, true;
    if type == .KW_SHADOW  return .SHADOW, true;
    if type == .KW_SKY     return .SKY, true;
    if type == .KW_AZURE   return .AZURE, true;
    if type == .KW_EMERALD return .EMERALD, true;
    return .NONE, false;
}

parse_color :: (p: *Parser) -> ParsedColor, bool {
    color: ParsedColor;
    color.modifier = .NONE;

    tok := peek(p);
    if tok.type == .KW_BRIGHT {
        advance(p);
        color.modifier = .BRIGHT;
    } else if tok.type == .KW_LIGHT {
        advance(p);
        color.modifier = .LIGHT;
    } else if tok.type == .KW_DARK {
        advance(p);
        color.modifier = .DARK;
    }

    tok = peek(p);
    base, ok := token_to_base_color(tok.type);
    if !ok {
        add_error(p, "Expected color name");
        return color, false;
    }
    advance(p);
    color.base = base;
    return color, true;
}

// Image parsing
parse_glyph_image :: (p: *Parser) -> ParsedGlyph, bool {
    glyph: ParsedGlyph;

    // Parse foreground color
    fg, fg_ok := parse_color(p);
    if !fg_ok return glyph, false;
    glyph.color = fg;

    // Parse character (char constant, GLYPH_ constant, or bare number)
    tok := peek(p);
    if tok.type == .CHAR_CONST {
        advance(p);
        glyph.char_code = tok.int_value;
    } else if tok.type == .CONSTANT {
        advance(p);
        glyph.char_code = tok.int_value;
    } else if tok.type == .NUMBER {
        // Allow bare numbers as character codes (e.g., "red 8" for '8')
        advance(p);
        glyph.char_code = tok.int_value;
    } else {
        add_error(p, "Expected character or glyph constant");
        return glyph, false;
    }

    // Check for "on color" background (use identifier "on")
    tok = peek(p);
    if tok.type == .KW_ON || (tok.type == .IDENTIFIER && strings_equal_nocase(tok.text, "on")) {
        advance(p);
        bg, bg_ok := parse_color(p);
        if !bg_ok return glyph, false;
        glyph.has_bg = true;
        glyph.bg_color = bg;
    }

    return glyph, true;
}

// String helpers
extract_string_content :: (s: string) -> string {
    if s.count < 2 return s;
    if s[0] == #char "\"" && s[s.count-1] == #char "\"" {
        result: string;
        result.data = s.data + 1;
        result.count = s.count - 2;
        return result;
    }
    return s;
}

extract_res_ref_name :: (s: string) -> string {
    if s.count < 3 return s;
    start: s64 = 0;
    if s[0] == #char "$" start = 1;
    if s[start] == #char "\"" start += 1;
    end := s.count;
    if s[end-1] == #char "\"" end -= 1;

    result: string;
    result.data = s.data + start;
    result.count = end - start;
    return result;
}

// Skip event handlers
skip_event_handler :: (p: *Parser) -> bool {
    // Event handlers can be chained: On Event PRE(EV_HIT) {...}, PRE(EV_APPLY) {...};
    // We need to skip all chained handlers until we see a semicolon not followed by more handlers

    while true {
        // Skip until we find matching braces
        while !check(p, .LBRACE) && !check(p, .SEMICOLON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
            advance(p);
        }

        if !check(p, .LBRACE) {
            // No more brace blocks - just consume semicolon if present
            match(p, .SEMICOLON);
            return true;
        }

        // Match braces
        brace_count := 0;
        while !parser_is_at_end(p) {
            tok := advance(p);
            if tok.type == .LBRACE brace_count += 1;
            else if tok.type == .RBRACE {
                brace_count -= 1;
                if brace_count == 0 break;
            }
        }

        // Check what follows the closing brace
        if match(p, .SEMICOLON) {
            // End of event handler chain
            return true;
        }

        if match(p, .COMMA) {
            // Another handler follows - continue the loop
            continue;
        }

        // Something else - we're done
        return true;
    }

    return true;
}

// Grant parsing
skip_ordinal_suffix :: (p: *Parser) {
    tok := peek(p);
    if tok.type == .KW_ST || tok.type == .KW_ND ||
       tok.type == .KW_RD || tok.type == .KW_TH {
        advance(p);
    }
}

parse_grant_level_condition :: (p: *Parser, grant: *ParsedGrant) -> bool {
    _, at_ok := consume(p, .KW_AT, "Expected 'at'");
    if !at_ok return false;

    if match(p, .KW_EVERY) {
        tok := peek(p);
        if tok.type == .KW_LEVEL {
            // "every level" - every level starting at 1
            advance(p);
            grant.level_type = .EVERY_LEVEL;
            grant.every_n = 1;
            grant.starting_level = 1;
        } else {
            // "every N level" - every Nth level
            n, n_ok := parse_cexpr3(p);
            if !n_ok return false;
            skip_ordinal_suffix(p);

            _, lvl_ok := consume(p, .KW_LEVEL, "Expected 'level'");
            if !lvl_ok return false;

            grant.level_type = .EVERY_NTH_LEVEL;
            grant.every_n = n;
            grant.starting_level = 1;  // Default starting level
        }

        // Optional "starting at N" clause
        if match(p, .KW_STARTING) {
            _, at2_ok := consume(p, .KW_AT, "Expected 'at'");
            if !at2_ok return false;

            start_level, start_ok2 := parse_cexpr3(p);
            if !start_ok2 return false;
            skip_ordinal_suffix(p);

            grant.starting_level = start_level;

            // Optional trailing "level" keyword
            match(p, .KW_LEVEL);
        }
    } else {
        // "N level" or "Nth" - at specific level N
        level, lvl_ok := parse_cexpr3(p);
        if !lvl_ok return false;
        skip_ordinal_suffix(p);

        // "level" keyword is optional after ordinal (e.g., "at 10th" vs "at 10th level")
        match(p, .KW_LEVEL);

        grant.level_type = .AT_LEVEL;
        grant.level = level;
    }

    return true;
}

parse_grant_feat :: (p: *Parser, grants: *[..] ParsedGrant) -> bool {
    advance(p);  // consume 'Feat'
    _, lbracket_ok := consume(p, .LBRACKET, "Expected '['");
    if !lbracket_ok return false;

    // Use parse_cexpr3 to avoid binary +/- consuming comma-separated params
    feat_id, ok := parse_cexpr3(p);
    if !ok return false;

    grant: ParsedGrant;
    grant.grant_type = .FEAT;
    grant.feat_id = feat_id;

    // Handle optional parameter: Feat[FT_SCHOOL_FOCUS,SC_ENC]
    if match(p, .COMMA) {
        param, param_ok := parse_cexpr3(p);
        if !param_ok return false;
        grant.feat_param = param;
        grant.has_feat_param = true;
    }

    _, rbracket_ok := consume(p, .RBRACKET, "Expected ']'");
    if !rbracket_ok return false;

    if !parse_grant_level_condition(p, *grant) return false;

    array_add(grants, grant);
    return true;
}

parse_grant_ability :: (p: *Parser, grants: *[..] ParsedGrant) -> bool {
    advance(p);
    _, lbracket_ok := consume(p, .LBRACKET, "Expected '['");
    if !lbracket_ok return false;

    // Use parse_cexpr3 to avoid binary +/- consuming comma-separated params like ",+1"
    ability_id, ok := parse_cexpr3(p);
    if !ok return false;

    grant: ParsedGrant;
    grant.grant_type = .ABILITY;
    grant.ability_id = ability_id;

    if match(p, .COMMA) {
        // Parameter can be a cexpr OR a resource reference $"name"
        if check(p, .RES_REF) {
            ref_tok := advance(p);
            grant.ability_ref = extract_res_ref_name(ref_tok.text);
            grant.has_ability_ref = true;
        } else {
            param1, ok1 := parse_cexpr3(p);
            if !ok1 return false;
            grant.ability_param1 = param1;
        }

        if match(p, .COMMA) {
            param2, ok2 := parse_cexpr3(p);
            if !ok2 return false;
            grant.ability_param2 = param2;
            grant.has_param2 = true;
        }
    }

    _, rbracket_ok := consume(p, .RBRACKET, "Expected ']'");
    if !rbracket_ok return false;

    if !parse_grant_level_condition(p, *grant) return false;

    array_add(grants, grant);
    return true;
}

parse_grant_stati :: (p: *Parser, grants: *[..] ParsedGrant) -> bool {
    advance(p);
    _, lbracket_ok := consume(p, .LBRACKET, "Expected '['");
    if !lbracket_ok return false;

    // Use parse_cexpr3 to avoid binary +/- consuming comma-separated params like ",+1"
    stati_type, ok := parse_cexpr3(p);
    if !ok return false;

    grant: ParsedGrant;
    grant.grant_type = .STATI;
    grant.stati_type = stati_type;

    if match(p, .COMMA) {
        param1, ok1 := parse_cexpr3(p);
        if !ok1 return false;
        grant.stati_param1 = param1;

        if match(p, .COMMA) {
            param2, ok2 := parse_cexpr3(p);
            if !ok2 return false;
            grant.stati_param2 = param2;
        }
    }

    _, rbracket_ok := consume(p, .RBRACKET, "Expected ']'");
    if !rbracket_ok return false;

    if !parse_grant_level_condition(p, *grant) return false;

    array_add(grants, grant);
    return true;
}

// Flags parsing
parse_flags_list :: (p: *Parser, flags: *[..] s64) -> bool {
    advance(p);  // consume 'Flags'

    optional_colon(p);  // Colon is optional per grammar

    while true {
        tok := peek(p);

        if tok.type == .CONSTANT {
            advance(p);
            array_add(flags, tok.int_value);
        } else if tok.type == .IDENTIFIER {
            val, found := lookup_resource_constant(tok.text);
            if found {
                advance(p);
                array_add(flags, val);
            } else {
                add_error(p, "Unknown flag");
                return false;
            }
        } else {
            break;
        }

        // Accept both comma and pipe as separators (some files use | for flags)
        if !match(p, .COMMA) && !match(p, .PIPE) break;
    }

    _, semi_ok := consume(p, .SEMICOLON, "Expected ';'");
    return semi_ok;
}

// Gear parsing - full grammar support
// gear_entry: (IF '(' expr ')')? (N%)? (dice)? (CURSED|BLESSED)? (res_ref|RANDOM n) (+/-N)? (WITH [..] | OF ..)*
parse_gear_list :: (p: *Parser, gear: *[..] ParsedGearEntry) -> bool {
    advance(p);  // consume 'Gear'

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    is_else := false;
    while true {
        entry: ParsedGearEntry;
        if is_else {
            entry.flags |= .ELSE_BRANCH;
        }

        if !parse_gear_entry(p, *entry) return false;
        array_add(gear, entry);

        // Check for comma (continue) or ELSE (else branch) or done
        if match(p, .COMMA) {
            is_else = false;
        } else if match(p, .KW_ELSE) {
            is_else = true;
        } else {
            break;
        }
    }

    match(p, .SEMICOLON);
    return true;
}

parse_gear_entry :: (p: *Parser, entry: *ParsedGearEntry) -> bool {
    // (IF '(' sep_expr ')' )?
    if match(p, .KW_IF) {
        _, lparen_ok := consume(p, .LPAREN, "Expected '('");
        if !lparen_ok return false;

        // Skip the condition expression for now - we'd need full expression parsing
        entry.has_condition = true;
        paren_depth := 1;
        while paren_depth > 0 && !parser_is_at_end(p) {
            tok := advance(p);
            if tok.type == .LPAREN paren_depth += 1;
            if tok.type == .RPAREN paren_depth -= 1;
        }
    }

    // (NUMBER '%' )?
    if check(p, .NUMBER) || check(p, .PERCENT) {
        next := peek(p);
        // Check if it's N% or a PERCENT token (which includes the number)
        if next.type == .PERCENT {
            entry.has_chance = true;
            entry.chance = next.int_value;
            advance(p);
        } else if next.type == .NUMBER {
            // Look ahead for %
            advance(p);
            if match(p, .MODULO) {  // % operator
                entry.has_chance = true;
                entry.chance = next.int_value;
            } else {
                // Not a percentage, put it back (will be parsed as dice or item)
                p.pos -= 1;
            }
        }
    }

    // (dice_only)? - e.g., 1d4, 2d6
    // Dice are tokenized as NUMBER DICE_D NUMBER (e.g., 1d4)
    // We check if this looks like a dice expression (not a percentage, not an item ref)
    if (check(p, .NUMBER) && check_at(p, 1, .DICE_D)) ||
       (check(p, .DICE_D)) {
        // Try to parse dice
        dice, dice_ok := parse_dice_value(p);
        if dice_ok {
            entry.has_quantity = true;
            entry.quantity = dice;
        }
    }

    // (CURSED | BLESSED)?
    if match(p, .KW_CURSED) {
        entry.flags |= .CURSED;
    } else if match(p, .KW_BLESSED) {
        entry.flags |= .BLESSED;
    }

    // (res_ref | RANDOM cexpr3) - required
    tok := peek(p);
    if tok.type == .RES_REF {
        advance(p);
        entry.item_ref = extract_res_ref_name(tok.text);
    } else if match(p, .KW_RANDOM) {
        entry.flags |= .RANDOM_ITEM;
        val, ok := parse_cexpr3(p);
        if ok {
            entry.random_item = val;
        }
    } else {
        // No item specified - might be syntax error, but let it pass
        return true;
    }

    // (+/- NUMBER)?
    if match(p, .PLUS) {
        val, ok := parse_cexpr3(p);
        if ok {
            entry.has_bonus = true;
            entry.bonus = val;
        }
    } else if match(p, .MINUS) {
        val, ok := parse_cexpr3(p);
        if ok {
            entry.has_bonus = true;
            entry.bonus = -val;
        }
    }

    // (WITH [...] | OF ... | AT (x,y))*
    while true {
        // WITH '[' qualities ']'
        if match(p, .KW_WITH) {
            _, lbracket_ok := consume(p, .LBRACKET, "Expected '['");
            if !lbracket_ok return false;

            while entry.quality_count < 4 && !check(p, .RBRACKET) && !parser_is_at_end(p) {
                qual_val, qual_ok := parse_cexpr(p);
                if !qual_ok break;
                entry.qualities[entry.quality_count] = qual_val;
                entry.quality_count += 1;
                match(p, .COMMA);
            }

            _, rbracket_ok := consume(p, .RBRACKET, "Expected ']'");
            if !rbracket_ok return false;
        }
        // OF res_ref | OF RANDOM ...
        else if match(p, .KW_OF) {
            if match(p, .KW_RANDOM) {
                entry.flags |= .RANDOM_EFFECT;

                // Check for range: TO syntax
                if check(p, .NUMBER) || check(p, .CONSTANT) {
                    min_val, min_ok := parse_cexpr3(p);
                    if min_ok {
                        if match(p, .KW_TO) {
                            max_val, max_ok := parse_cexpr3(p);
                            if max_ok {
                                entry.random_effect_min = min_val;
                                entry.random_effect_max = max_val;
                            }
                        } else {
                            // Just max value
                            entry.random_effect_max = min_val;
                        }
                    }
                }
                // else: just RANDOM with no value
            } else if check(p, .RES_REF) {
                tmpl_tok := advance(p);
                entry.template_ref = extract_res_ref_name(tmpl_tok.text);
            }
        }
        // AT '(' x ',' y ')'
        else if match(p, .KW_AT) {
            _, lparen_ok := consume(p, .LPAREN, "Expected '('");
            if !lparen_ok return false;

            x_val, x_ok := parse_cexpr3(p);
            if !x_ok return false;

            _, comma_ok := consume(p, .COMMA, "Expected ','");
            if !comma_ok return false;

            y_val, y_ok := parse_cexpr3(p);
            if !y_ok return false;

            _, rparen_ok := consume(p, .RPAREN, "Expected ')'");
            if !rparen_ok return false;

            entry.has_location = true;
            entry.loc_x = x_val;
            entry.loc_y = y_val;
        }
        else {
            break;
        }
    }

    return true;
}

// Check token at offset from current position
check_at :: (p: *Parser, offset: s64, token_type: TokenType) -> bool {
    idx := p.pos + offset;
    if idx >= p.tokens.count return false;
    return p.tokens[idx].type == token_type;
}

// Constants section parsing
parse_constants_section :: (p: *Parser, constants: *[..] ParsedConstant) -> bool {
    advance(p);  // consume 'Constants'

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    while check(p, .STAR) {
        advance(p);  // consume '*'

        key_tok := peek(p);
        key: s64;
        if key_tok.type == .CONSTANT {
            key = key_tok.int_value;
            advance(p);
        } else if key_tok.type == .IDENTIFIER {
            val, found := lookup_resource_constant(key_tok.text);
            if found {
                key = val;
                advance(p);
            } else {
                add_error(p, "Unknown constant key");
                return false;
            }
        } else {
            add_error(p, "Expected constant key");
            return false;
        }

        // Value can be either a numeric expression or a resource reference
        value: s64;
        ref_name: string;
        is_ref := false;

        tok := peek(p);
        if tok.type == .RES_REF {
            // Resource reference value: $"name"
            ref_name = extract_res_ref_name(tok.text);
            is_ref = true;
            value = 0;  // Resource refs don't have numeric values at parse time
            advance(p);
        } else {
            // Numeric expression value
            val_result, val_ok := parse_cexpr(p);
            if !val_ok return false;
            value = val_result;
        }

        c: ParsedConstant;
        c.key = key;
        c.value = value;
        c.is_ref = is_ref;
        c.ref_name = ref_name;
        array_add(constants, c);

        if match(p, .SEMICOLON) break;
        match(p, .COMMA);
    }

    return true;
}

// Main parse loop
parser_parse :: (p: *Parser) -> bool {
    while !parser_is_at_end(p) {
        if !parse_resource(p) {
            // Error recovery - skip to next statement or block boundary
            while !parser_is_at_end(p) && !check(p, .SEMICOLON) && !check(p, .RBRACE) {
                advance(p);
            }
            // Consume the terminator to avoid infinite loops
            if check(p, .SEMICOLON) || check(p, .RBRACE) {
                advance(p);
            }
        }
    }
    return !p.had_error;
}

// Resource dispatch
parse_resource :: (p: *Parser) -> bool {
    tok := peek(p);

    // Module header statements (can appear at top of file)
    if tok.type == .KW_MODULE {
        advance(p);
        name_tok, name_ok := consume(p, .STRING, "Expected module name");
        if !name_ok return false;
        p.module.has_name = true;
        p.module.name = extract_string_content(name_tok.text);
        _, semi_ok := consume(p, .SEMICOLON, "Expected ';'");
        return semi_ok;
    }
    if tok.type == .KW_FILE {
        advance(p);
        file_tok, file_ok := consume(p, .STRING, "Expected file path");
        if !file_ok return false;
        p.module.has_file = true;
        p.module.file = extract_string_content(file_tok.text);
        _, semi_ok := consume(p, .SEMICOLON, "Expected ';'");
        return semi_ok;
    }
    if tok.type == .KW_SLOT {
        advance(p);
        slot_val, slot_ok := parse_cexpr(p);
        if !slot_ok return false;
        p.module.has_slot = true;
        p.module.slot = slot_val;
        _, semi_ok := consume(p, .SEMICOLON, "Expected ';'");
        return semi_ok;
    }

    // Skip global variable declarations (e.g., "int16 var1, var2;")
    // These are script-level variables that we don't need for parsing resources
    if tok.type == .KW_INT8 || tok.type == .KW_INT16 || tok.type == .KW_INT32 ||
       tok.type == .KW_UINT8 || tok.type == .KW_UINT16 ||
       tok.type == .KW_HOBJ || tok.type == .KW_RID || tok.type == .KW_BOOL {
        // Skip the type and all identifiers/commas until semicolon
        advance(p);
        while !parser_is_at_end(p) && !check(p, .SEMICOLON) {
            advance(p);
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Resource definitions
    if tok.type == .KW_FLAVOR    return parse_flavor(p);
    if tok.type == .KW_MONSTER   return parse_monster(p);
    if tok.type == .KW_ITEM      return parse_item(p);
    if tok.type == .KW_EFFECT    return parse_effect(p, false);
    if tok.type == .KW_SPELL     return parse_effect(p, true);
    if tok.type == .KW_FEATURE   return parse_feature(p);
    if tok.type == .KW_TERRAIN   return parse_terrain(p);
    if tok.type == .KW_RACE      return parse_race(p);
    if tok.type == .KW_CLASS     return parse_class(p);
    if tok.type == .KW_TEMPLATE  return parse_template(p);
    if tok.type == .KW_REGION    return parse_region(p);
    if tok.type == .KW_ENCOUNTER return parse_encounter(p);
    if tok.type == .KW_DOMAIN    return parse_domain(p);
    if tok.type == .KW_GOD       return parse_god(p);
    if tok.type == .KW_TEXT      return parse_text(p);
    if tok.type == .KW_DUNGEON   return parse_dungeon(p);
    if tok.type == .KW_ARTIFACT  return parse_artifact(p);

    // Effect definitions can start with source constants:
    // e.g., "Potion Effect ...", "AI_POTION Effect ...", "AI_POTION/AI_SCROLL Effect ..."
    // Grammar: effect_def: ( cexpr3<n> ('/')? )* (SPELL | EFFECT | POISON | DISEASE) LITERAL ...
    if tok.type == .CONSTANT {
        // Look ahead to see if this is followed by Effect/Spell/Poison/Disease
        save_pos := p.pos;
        sources: [..] s64;
        sources.allocator = temp;

        // Consume sources (constants optionally separated by '/')
        while (check(p, .CONSTANT) || check(p, .NUMBER)) && sources.count < 4 {
            src_tok := advance(p);
            array_add(*sources, src_tok.int_value);
            if !match(p, .SLASH) break;
        }

        // Check if followed by Effect/Spell/Poison/Disease keyword
        next := peek(p);
        if next.type == .KW_EFFECT || next.type == .KW_SPELL ||
           next.type == .KW_POISON || next.type == .KW_DISEASE {
            is_spell := next.type == .KW_SPELL;
            return parse_effect_with_sources(p, is_spell, sources);
        }

        // Not an effect definition, restore position
        p.pos = save_pos;
    }

    add_error(p, "Expected resource definition");
    return false;
}

// Individual resource parsers (simplified versions)
parse_flavor :: (p: *Parser) -> bool {
    advance(p);  // consume 'Flavor'

    name_tok, name_ok := consume(p, .STRING, "Expected flavor name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    type_val, type_ok := parse_cexpr(p);
    if !type_ok return false;

    flavor: ParsedFlavor;
    flavor.name = extract_string_content(name_tok.text);
    flavor.itype = type_val;
    flavor.line = name_tok.line;
    flavor.column = name_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);
        if tok.type == .KW_DESC {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            desc_tok, desc_ok := consume(p, .STRING, "Expected description string");
            if !desc_ok return false;
            flavor.has_desc = true;
            flavor.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_MAT {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            mat_val, mat_ok := parse_cexpr(p);
            if !mat_ok return false;
            flavor.has_material = true;
            flavor.material = mat_val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_WEIGHT {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            weight_val, weight_ok := parse_cexpr(p);
            if !weight_ok return false;
            flavor.has_weight = true;
            flavor.weight = weight_val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_IMAGE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            color, color_ok := parse_color(p);
            if !color_ok return false;
            flavor.has_color = true;
            flavor.color = color;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_COLOUR {
            // Colour: bright green;
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            color, color_ok := parse_color(p);
            if !color_ok return false;
            flavor.has_color = true;
            flavor.color = color;
            match(p, .SEMICOLON);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.flavors, flavor);
    return true;
}

parse_monster :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Monster'

    name_tok, name_ok := consume(p, .STRING, "Expected monster name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    monster: ParsedMonster;
    monster.name = extract_string_content(name_tok.text);
    monster.line = start_tok.line;
    monster.column = start_tok.column;

    // Parse types until {
    while !check(p, .LBRACE) && !parser_is_at_end(p) {
        tok := peek(p);
        if tok.type == .CONSTANT {
            array_add(*monster.mtypes, tok.int_value);
            advance(p);
        } else if tok.type == .COMMA {
            advance(p);
        } else {
            break;
        }
    }

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    // Parse body (simplified)
    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);
        if tok.type == .KW_IMAGE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            image, image_ok := parse_glyph_image(p);
            if !image_ok return false;
            monster.has_image = true;
            monster.image = image;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_CR {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;

            // Handle fractional CR (1/2, 1/4, 1/8, etc.) or regular CR
            cr_val, cr_ok := parse_cexpr3(p);
            if !cr_ok return false;

            // Check for fractional CR (e.g., 1/4)
            if match(p, .SLASH) {
                denom, denom_ok := parse_cexpr3(p);
                if !denom_ok return false;
                // Store fractional CR as negative value: 1/2 = -2, 1/4 = -4, 1/8 = -8
                // This matches how Incursion encodes fractional CR internally
                if cr_val == 1 && denom > 1 {
                    cr_val = -denom;
                }
            }

            monster.has_cr = true;
            monster.cr = cr_val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_HITDICE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            hd_val, hd_ok := parse_cexpr(p);
            if !hd_ok return false;
            monster.has_hd = true;
            monster.hd = hd_val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_SIZE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            size_val, size_ok := parse_cexpr(p);
            if !size_ok return false;
            monster.has_size = true;
            monster.size = size_val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *monster.flags) return false;
        } else if tok.type == .KW_GEAR {
            if !parse_gear_list(p, *monster.gear) return false;
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.monsters, monster);
    return true;
}

parse_item :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Item'

    name_tok, name_ok := consume(p, .STRING, "Expected item name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    type_val, type_ok := parse_cexpr(p);
    if !type_ok return false;

    item: ParsedItem;
    item.name = extract_string_content(name_tok.text);
    item.itype = type_val;
    item.line = start_tok.line;
    item.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);
        if tok.type == .KW_IMAGE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            image, image_ok := parse_glyph_image(p);
            if !image_ok return false;
            item.has_image = true;
            item.image = image;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_LEVEL {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_level = true;
            item.level = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_MAT {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_material = true;
            item.material = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_WEIGHT {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_weight = true;
            item.weight = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_SIZE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_size = true;
            item.size = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_COST {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_cost = true;
            item.cost = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_GROUP {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_group = true;
            item.group = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_HP || tok.type == .KW_HITPOINTS {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_hp = true;
            item.hp = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DEPTH {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_depth = true;
            item.depth = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_LIFESPAN {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_lifespan = true;
            item.lifespan = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FUEL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_fuel = true;
            item.fuel = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_CAPACITY {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_capacity = true;
            item.capacity = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_WEIGHTLIM {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_weight_lim = true;
            item.weight_lim = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_WEIGHTMOD {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_weight_mod = true;
            item.weight_mod = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_MAXSIZE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_max_size = true;
            item.max_size = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_TIMEOUT {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_timeout = true;
            item.timeout = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_CTYPE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_ctype = true;
            item.ctype = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FIRES {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            item.has_fires = true;
            // Parse list of $"spell" references
            while true {
                spell_tok := peek(p);
                if spell_tok.type == .RES_REF {
                    array_add(*item.fires, extract_res_ref_name(spell_tok.text));
                    advance(p);
                } else {
                    break;
                }
                if !match(p, .COMMA) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DESC {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            item.has_desc = true;
            item.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *item.flags) return false;
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.items, item);
    return true;
}

// Parse effect with leading source constants (e.g., "Potion Effect ...", "AI_POTION/AI_SCROLL Effect ...")
parse_effect_with_sources :: (p: *Parser, is_spell: bool, sources: [] s64) -> bool {
    start_tok := advance(p);  // consume 'Effect', 'Spell', 'Poison', or 'Disease'

    name_tok, name_ok := consume(p, .STRING, "Expected effect name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    type_val, type_ok := parse_cexpr(p);
    if !type_ok return false;

    effect: ParsedEffect;
    effect.name = extract_string_content(name_tok.text);
    effect.etype = type_val;
    effect.is_spell = is_spell;
    effect.line = start_tok.line;
    effect.column = start_tok.column;

    // Store sources
    for src: sources {
        array_add(*effect.sources, src);
    }

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    // Parse effect body - inline since effect body parsing is complex
    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);
        if tok.type == .KW_LEVEL {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_level = true;
            effect.level = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *effect.flags) return false;
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else if tok.type == .KW_DESC {
            advance(p);
            optional_colon(p);
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            effect.has_desc = true;
            effect.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_LISTS {
            // Skip lists section for effects (not stored in ParsedEffect)
            advance(p);
            optional_colon(p);
            // Skip list entries until we hit another keyword or closing brace
            while !parser_is_at_end(p) && !check(p, .RBRACE) {
                inner_tok := peek(p);
                // Stop when we hit another entry keyword
                if inner_tok.type == .KW_ON || inner_tok.type == .KW_FLAGS ||
                   inner_tok.type == .KW_LEVEL || inner_tok.type == .KW_DESC {
                    break;
                }
                advance(p);
            }
        } else {
            // Skip unknown tokens in effect body
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.effects, effect);
    return true;
}

parse_effect :: (p: *Parser, is_spell: bool) -> bool {
    start_tok := advance(p);  // consume 'Effect' or 'Spell'

    name_tok, name_ok := consume(p, .STRING, "Expected effect name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    type_val, type_ok := parse_cexpr(p);
    if !type_ok return false;

    effect: ParsedEffect;
    effect.name = extract_string_content(name_tok.text);
    effect.etype = type_val;
    effect.is_spell = is_spell;
    effect.line = start_tok.line;
    effect.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);

        // Skip local variable declarations inside effect bodies
        if tok.type == .KW_INT8 || tok.type == .KW_INT16 || tok.type == .KW_INT32 ||
           tok.type == .KW_UINT8 || tok.type == .KW_UINT16 ||
           tok.type == .KW_HOBJ || tok.type == .KW_RID || tok.type == .KW_BOOL {
            advance(p);
            while !parser_is_at_end(p) && !check(p, .SEMICOLON) {
                advance(p);
            }
            match(p, .SEMICOLON);
            continue;
        }

        if tok.type == .KW_LEVEL {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_level = true;
            effect.level = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_QVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_qval = true;
            effect.qval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_XVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_xval = true;
            effect.xval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_YVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_yval = true;
            effect.yval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_PVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            dice, dice_ok := parse_dice_value(p);
            if !dice_ok return false;
            effect.has_pval = true;
            effect.pval = dice;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_SVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_sval = true;
            effect.sval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_dval = true;
            effect.dval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_AVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_aval = true;
            effect.aval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_LVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_lval = true;
            effect.lval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_TVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_tval = true;
            effect.tval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_RVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_rval = true;
            effect.rval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_EVAL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_eval = true;
            effect.eval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_BASE {
            // Base Chance: N%;
            advance(p);
            // Optional "Chance" keyword
            if check(p, .KW_CHANCE) advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_base_chance = true;
            effect.base_chance = val;
            match(p, .MODULO);  // Optional % after value
            match(p, .SEMICOLON);
        } else if tok.type == .KW_PURPOSE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_purpose = true;
            effect.purpose = val;
            // Optional (param) after purpose
            if match(p, .LPAREN) {
                param, param_ok := parse_cexpr(p);
                if !param_ok return false;
                effect.has_purpose_param = true;
                effect.purpose_param = param;
                _, rparen_ok := consume(p, .RPAREN, "Expected ')'");
                if !rparen_ok return false;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_SCHOOLS {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_schools = true;
            effect.schools = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DESC {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            effect.has_desc = true;
            effect.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *effect.flags) return false;
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    // Handle 'and EA_*' continuation blocks (edef_body : abil_def | edef_body 'and' abil_def)
    while check(p, .KW_AND) {
        advance(p);  // consume 'and'

        // Parse ability type (EA_GENERIC, EA_TERRAFORM, etc.)
        _, abil_ok := parse_cexpr(p);
        if !abil_ok return false;

        _, lbrace2_ok := consume(p, .LBRACE, "Expected '{'");
        if !lbrace2_ok return false;

        // Parse the continuation block body (same as main effect body)
        while !check(p, .RBRACE) && !parser_is_at_end(p) {
            tok2 := peek(p);

            // Skip local variable declarations
            if tok2.type == .KW_INT8 || tok2.type == .KW_INT16 || tok2.type == .KW_INT32 ||
               tok2.type == .KW_UINT8 || tok2.type == .KW_UINT16 ||
               tok2.type == .KW_HOBJ || tok2.type == .KW_RID || tok2.type == .KW_BOOL {
                advance(p);
                while !parser_is_at_end(p) && !check(p, .SEMICOLON) {
                    advance(p);
                }
                match(p, .SEMICOLON);
                continue;
            }

            if tok2.type == .KW_ON || tok2.type == .KW_EVENT {
                skip_event_handler(p);
            } else {
                // Skip any property in continuation blocks
                advance(p);
            }
        }

        _, rbrace2_ok := consume(p, .RBRACE, "Expected '}'");
        if !rbrace2_ok return false;
    }

    array_add(*p.effects, effect);
    return true;
}

parse_feature :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Feature'

    name_tok, name_ok := consume(p, .STRING, "Expected feature name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    type_val, type_ok := parse_cexpr(p);
    if !type_ok return false;

    feature: ParsedFeature;
    feature.name = extract_string_content(name_tok.text);
    feature.ftype = type_val;
    feature.line = start_tok.line;
    feature.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);
        if tok.type == .KW_IMAGE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            image, image_ok := parse_glyph_image(p);
            if !image_ok return false;
            feature.has_image = true;
            feature.image = image;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *feature.flags) return false;
        } else if tok.type == .KW_CONSTANTS {
            if !parse_constants_section(p, *feature.constants) return false;
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else if tok.type == .KW_MAT {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            feature.has_material = true;
            feature.material = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_HP || tok.type == .KW_HITPOINTS {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            feature.has_hp = true;
            feature.hp = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DESC {
            advance(p);
            optional_colon(p);
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            feature.has_desc = true;
            feature.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_XVAL {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            feature.has_xval = true;
            feature.xval = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_MOVE || tok.type == .KW_MOV {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            // Skip move modifier for features (not stored)
            match(p, .PERCENT);
            match(p, .SEMICOLON);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.features, feature);
    return true;
}

parse_terrain :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Terrain'

    name_tok, name_ok := consume(p, .STRING, "Expected terrain name");
    if !name_ok return false;

    terrain: ParsedTerrain;
    terrain.name = extract_string_content(name_tok.text);
    terrain.line = start_tok.line;
    terrain.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);
        if tok.type == .KW_IMAGE {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            image, image_ok := parse_glyph_image(p);
            if !image_ok return false;
            terrain.has_image = true;
            terrain.image = image;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *terrain.flags) return false;
        } else if tok.type == .KW_CONSTANTS {
            if !parse_constants_section(p, *terrain.constants) return false;
        } else if tok.type == .KW_MAT {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            terrain.has_material = true;
            terrain.material = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_MOVE || tok.type == .KW_MOV {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            terrain.has_move = true;
            terrain.move_mod = val;
            match(p, .PERCENT);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_PENALTY {
            advance(p);
            optional_colon(p);
            val, ok := parse_cexpr(p);
            if !ok return false;
            terrain.has_penalty = true;
            terrain.penalty = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DESC {
            advance(p);
            optional_colon(p);
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            terrain.has_desc = true;
            terrain.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.terrains, terrain);
    return true;
}

parse_race :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Race'

    name_tok, name_ok := consume(p, .STRING, "Expected race name");
    if !name_ok return false;

    race: ParsedRace;
    race.name = extract_string_content(name_tok.text);
    race.line = start_tok.line;
    race.column = start_tok.column;

    // Check for parent race
    if match(p, .COLON) {
        parent_tok, parent_ok := consume(p, .STRING, "Expected parent race");
        if !parent_ok return false;
        race.has_parent = true;
        race.parent = extract_string_content(parent_tok.text);
    }

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        if !parse_race_entry(p, *race) return false;
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.races, race);
    return true;
}

parse_race_entry :: (p: *Parser, race: *ParsedRace) -> bool {
    tok := peek(p);

    if tok.type == .KW_GRANTS {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;

        while true {
            grant_tok := peek(p);
            if grant_tok.type == .KW_FEAT {
                if !parse_grant_feat(p, *race.grants) return false;
            } else if grant_tok.type == .KW_ABILITY {
                if !parse_grant_ability(p, *race.grants) return false;
            } else if grant_tok.type == .KW_STATI {
                if !parse_grant_stati(p, *race.grants) return false;
            } else {
                break;
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_FLAGS {
        return parse_flags_list(p, *race.skills);  // Race uses skills, not flags
    }

    if tok.type == .KW_CONSTANTS {
        return parse_constants_section(p, *race.constants);
    }

    // Attribute modifiers: STR +2, DEX -2, etc.
    // Handle both KW_* tokens (in code) and ATTRIBUTE tokens (outside code)
    if tok.type == .ATTRIBUTE || tok.type == .KW_STR || tok.type == .KW_DEX ||
       tok.type == .KW_CON || tok.type == .KW_INT || tok.type == .KW_WIS ||
       tok.type == .KW_CHA || tok.type == .KW_LUC {
        race.has_attrs = true;
        while true {
            attr_tok := peek(p);
            if attr_tok.type != .ATTRIBUTE && attr_tok.type != .KW_STR &&
               attr_tok.type != .KW_DEX && attr_tok.type != .KW_CON &&
               attr_tok.type != .KW_INT && attr_tok.type != .KW_WIS &&
               attr_tok.type != .KW_CHA && attr_tok.type != .KW_LUC {
                break;
            }

            // Get attribute index (0=STR, 1=DEX, 2=CON, 3=INT, 4=WIS, 5=CHA, 6=LUC)
            attr_index: s64 = -1;
            if attr_tok.type == .ATTRIBUTE {
                attr_index = attr_tok.int_value;
            } else {
                if attr_tok.type == .KW_STR attr_index = 0;
                else if attr_tok.type == .KW_DEX attr_index = 1;
                else if attr_tok.type == .KW_CON attr_index = 2;
                else if attr_tok.type == .KW_INT attr_index = 3;
                else if attr_tok.type == .KW_WIS attr_index = 4;
                else if attr_tok.type == .KW_CHA attr_index = 5;
                else if attr_tok.type == .KW_LUC attr_index = 6;
            }
            advance(p);

            val, ok := parse_cexpr(p);
            if !ok return false;

            if attr_index == 0 race.str_mod = val;
            else if attr_index == 1 race.dex_mod = val;
            else if attr_index == 2 race.con_mod = val;
            else if attr_index == 3 race.int_mod = val;
            else if attr_index == 4 race.wis_mod = val;
            else if attr_index == 5 race.cha_mod = val;
            else if attr_index == 6 race.luc_mod = val;

            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_DESC {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        desc_tok, desc_ok := consume(p, .STRING, "Expected description");
        if !desc_ok return false;
        race.has_desc = true;
        race.desc = extract_string_content(desc_tok.text);
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .IDENTIFIER || tok.type == .CONSTANT {
        // Handle MALE_NAMES, FEMALE_NAMES, FAMILY_NAMES
        if tok.text == "MALE_NAMES" ||
           (tok.type == .CONSTANT && is_names_constant(tok.text)) {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            names_tok, names_ok := consume(p, .STRING, "Expected names string");
            if !names_ok return false;
            race.has_male_names = true;
            race.male_names = extract_string_content(names_tok.text);
            match(p, .SEMICOLON);
            return true;
        }
        if tok.text == "FEMALE_NAMES" {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            names_tok, names_ok := consume(p, .STRING, "Expected names string");
            if !names_ok return false;
            race.has_female_names = true;
            race.female_names = extract_string_content(names_tok.text);
            match(p, .SEMICOLON);
            return true;
        }
        if tok.text == "FAMILY_NAMES" {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            names_tok, names_ok := consume(p, .STRING, "Expected names string");
            if !names_ok return false;
            race.has_family_names = true;
            race.family_names = extract_string_content(names_tok.text);
            match(p, .SEMICOLON);
            return true;
        }
    }

    if tok.type == .KW_ON || tok.type == .KW_EVENT {
        return skip_event_handler(p);
    }

    // Skip unknown
    advance(p);
    return true;
}

parse_class :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Class'

    name_tok, name_ok := consume(p, .STRING, "Expected class name");
    if !name_ok return false;

    cls: ParsedClass;
    cls.name = extract_string_content(name_tok.text);
    cls.line = start_tok.line;
    cls.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        if !parse_class_entry(p, *cls) return false;
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.classes, cls);
    return true;
}

parse_class_entry :: (p: *Parser, cls: *ParsedClass) -> bool {
    tok := peek(p);

    if tok.type == .KW_HITDICE {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        cls.has_hitdice = true;
        cls.hitdice = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_MANA {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        cls.has_mana = true;
        cls.mana = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_DEF {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        num, ok := parse_cexpr3(p);
        if !ok return false;
        _, slash_ok := consume(p, .SLASH, "Expected '/'");
        if !slash_ok return false;
        denom, ok2 := parse_cexpr3(p);
        if !ok2 return false;
        cls.has_def = true;
        cls.def_num = num;
        cls.def_denom = denom;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_GRANTS {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;

        while true {
            grant_tok := peek(p);
            if grant_tok.type == .KW_FEAT {
                if !parse_grant_feat(p, *cls.grants) return false;
            } else if grant_tok.type == .KW_ABILITY {
                if !parse_grant_ability(p, *cls.grants) return false;
            } else if grant_tok.type == .KW_STATI {
                if !parse_grant_stati(p, *cls.grants) return false;
            } else {
                break;
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_FLAGS {
        return parse_flags_list(p, *cls.flags);
    }

    if tok.type == .KW_PROFICIENCIES {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;

        while true {
            prof_tok := peek(p);
            if prof_tok.type == .CONSTANT {
                array_add(*cls.proficiencies, prof_tok.int_value);
                advance(p);
            } else {
                break;
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_CONSTANTS {
        return parse_constants_section(p, *cls.constants);
    }

    if tok.type == .KW_DESC {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        desc_tok, desc_ok := consume(p, .STRING, "Expected description");
        if !desc_ok return false;
        cls.has_desc = true;
        cls.desc = extract_string_content(desc_tok.text);
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_ON || tok.type == .KW_EVENT {
        return skip_event_handler(p);
    }

    // Skip unknown
    advance(p);
    return true;
}

// ============================================================================
// Template parser
// ============================================================================
parse_template :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Template'

    name_tok, name_ok := consume(p, .STRING, "Expected template name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    // Parse template type (TM_AGECAT, TM_CLASS, etc.)
    type_val, type_ok := parse_cexpr(p);
    if !type_ok return false;

    tmpl: ParsedTemplate;
    tmpl.name = extract_string_content(name_tok.text);
    tmpl.ttype = type_val;
    tmpl.line = start_tok.line;
    tmpl.column = start_tok.column;

    // Check for "for MA_*" clause
    // Note: "for" is tokenized as KW_FOR_KW outside code blocks, or IDENTIFIER in some contexts
    tok := peek(p);
    if tok.type == .KW_FOR_KW || tok.type == .KW_FOR ||
       (tok.type == .IDENTIFIER && strings_equal_nocase(tok.text, "for")) {
        advance(p);
        for_val, for_ok := parse_cexpr(p);
        if !for_ok return false;
        tmpl.has_for = true;
        tmpl.for_mtype = for_val;
    }

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        if !parse_template_entry(p, *tmpl) return false;
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.templates, tmpl);
    return true;
}

parse_template_entry :: (p: *Parser, tmpl: *ParsedTemplate) -> bool {
    tok := peek(p);

    if tok.type == .KW_DESC {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        desc_tok, desc_ok := consume(p, .STRING, "Expected description");
        if !desc_ok return false;
        tmpl.has_desc = true;
        tmpl.desc = extract_string_content(desc_tok.text);
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_CR {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_cr = true;
        tmpl.cr = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_SIZE {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_size = true;
        tmpl.size = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_POWER {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_power = true;
        tmpl.power = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_DEPTH {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_depth = true;
        tmpl.depth = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_FLAGS {
        return parse_flags_list(p, *tmpl.flags);
    }

    if tok.type == .KW_FEATS {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        while true {
            feat_tok := peek(p);
            if feat_tok.type == .CONSTANT {
                array_add(*tmpl.feats, feat_tok.int_value);
                advance(p);
            } else {
                break;
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_IMMUNE {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        while true {
            imm_tok := peek(p);
            if imm_tok.type == .CONSTANT {
                array_add(*tmpl.immunities, imm_tok.int_value);
                advance(p);
            } else {
                break;
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_MTYPE {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        mtype_val, ok := parse_cexpr(p);
        if !ok return false;
        array_add(*tmpl.mtypes, mtype_val);
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_ATTK {
        // Skip attack definitions for now (complex)
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        // Skip until semicolon
        while !check(p, .SEMICOLON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
            advance(p);
        }
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_GEAR {
        return parse_gear_list(p, *tmpl.gear);
    }

    if tok.type == .KW_GRANTS {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;

        while true {
            grant_tok := peek(p);
            if grant_tok.type == .KW_FEAT {
                if !parse_grant_feat(p, *tmpl.grants) return false;
            } else if grant_tok.type == .KW_ABILITY {
                if !parse_grant_ability(p, *tmpl.grants) return false;
            } else if grant_tok.type == .KW_STATI {
                if !parse_grant_stati(p, *tmpl.grants) return false;
            } else {
                break;
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Handle attribute modifiers (Str, Dex, Con, etc.) with mval syntax
    // e.g., Str: +8; or Str: 55% (min 10);
    if tok.type == .ATTRIBUTE || tok.type == .KW_STR || tok.type == .KW_DEX ||
       tok.type == .KW_CON || tok.type == .KW_INT || tok.type == .KW_WIS ||
       tok.type == .KW_CHA {

        // Get attribute index
        attr_index: s64 = -1;
        if tok.type == .ATTRIBUTE {
            attr_index = tok.int_value;
        } else {
            if tok.type == .KW_STR attr_index = 0;
            else if tok.type == .KW_DEX attr_index = 1;
            else if tok.type == .KW_CON attr_index = 2;
            else if tok.type == .KW_INT attr_index = 3;
            else if tok.type == .KW_WIS attr_index = 4;
            else if tok.type == .KW_CHA attr_index = 5;
        }
        advance(p);

        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;

        // Parse mval: could be +N, -N, =N, N%, or N% (min M)
        attr_mod: ParsedAttrMod;

        // Check for percentage value (N% format - lexer returns PERCENT token)
        if check(p, .PERCENT) {
            pct_tok := advance(p);
            attr_mod.is_percentage = true;
            attr_mod.value = pct_tok.int_value;

            // Check for (min N) or (max N)
            if match(p, .LPAREN) {
                next := peek(p);
                if next.type == .KW_MIN || (next.type == .IDENTIFIER && strings_equal_nocase(next.text, "min")) {
                    advance(p);
                    min_val, min_ok := parse_cexpr3(p);
                    if !min_ok return false;
                    attr_mod.has_min = true;
                    attr_mod.min_value = min_val;
                }
                _, rparen_ok := consume(p, .RPAREN, "Expected ')'");
                if !rparen_ok return false;
            }
        } else {
            // Parse as regular expression (+N, -N, =N, or just N)
            val, ok := parse_cexpr(p);
            if !ok return false;
            attr_mod.is_percentage = false;
            attr_mod.value = val;

            // Check if followed by % (N% format without combined token)
            if match(p, .MODULO) {
                attr_mod.is_percentage = true;
                // Check for (min N)
                if match(p, .LPAREN) {
                    next := peek(p);
                    if next.type == .KW_MIN || (next.type == .IDENTIFIER && strings_equal_nocase(next.text, "min")) {
                        advance(p);
                        min_val, min_ok := parse_cexpr3(p);
                        if !min_ok return false;
                        attr_mod.has_min = true;
                        attr_mod.min_value = min_val;
                    }
                    _, rparen_ok := consume(p, .RPAREN, "Expected ')'");
                    if !rparen_ok return false;
                }
            }
        }

        // Store in template
        if attr_index == 0 { tmpl.has_str = true; tmpl.str_mod = attr_mod; }
        else if attr_index == 1 { tmpl.has_dex = true; tmpl.dex_mod = attr_mod; }
        else if attr_index == 2 { tmpl.has_con = true; tmpl.con_mod = attr_mod; }
        else if attr_index == 3 { tmpl.has_int = true; tmpl.int_mod = attr_mod; }
        else if attr_index == 4 { tmpl.has_wis = true; tmpl.wis_mod = attr_mod; }
        else if attr_index == 5 { tmpl.has_cha = true; tmpl.cha_mod = attr_mod; }

        match(p, .COMMA);  // Attributes can be comma-separated
        match(p, .SEMICOLON);
        return true;
    }

    // Handle Mov, Arm, HitDice, Hit, Caster Level
    if tok.type == .KW_MOV {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_mov = true;
        tmpl.mov = val;
        // Skip trailing % if present
        match(p, .PERCENT);
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_ARM {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_arm = true;
        tmpl.arm = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_HITDICE {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_hitdice = true;
        tmpl.hitdice = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_HIT {
        advance(p);
        _, colon_ok := consume(p, .COLON, "Expected ':'");
        if !colon_ok return false;
        val, ok := parse_cexpr(p);
        if !ok return false;
        tmpl.has_hit = true;
        tmpl.hit = val;
        match(p, .SEMICOLON);
        return true;
    }

    if tok.type == .KW_ON || tok.type == .KW_EVENT {
        return skip_event_handler(p);
    }

    // Skip unknown tokens
    advance(p);
    return true;
}

// ============================================================================
// Region parser
// ============================================================================
parse_region :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Region'

    name_tok, name_ok := consume(p, .STRING, "Expected region name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    // Parse region type (RF_RIVER, RF_CORRIDOR, etc.)
    type_val, type_ok := parse_cexpr(p);
    if !type_ok return false;

    region: ParsedRegion;
    region.name = extract_string_content(name_tok.text);
    region.rtype = type_val;
    region.line = start_tok.line;
    region.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);

        if tok.type == .KW_FLOOR {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            floor_tok, floor_ok := consume(p, .RES_REF, "Expected $\"terrain\" reference");
            if !floor_ok return false;
            region.has_floor = true;
            region.floor = extract_res_ref_name(floor_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_WALLS {
            // Walls: $"terrain";
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            walls_tok, walls_ok := consume(p, .RES_REF, "Expected $\"terrain\" reference");
            if !walls_ok return false;
            region.has_walls = true;
            region.walls = extract_res_ref_name(walls_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DOOR {
            // Door: $"feature";
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            door_tok, door_ok := consume(p, .RES_REF, "Expected $\"feature\" reference");
            if !door_ok return false;
            region.has_door = true;
            region.door = extract_res_ref_name(door_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DEPTH {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            region.has_depth = true;
            region.depth = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_ROOMTYPES {
            // RoomTypes: RM_NORMAL, RM_CIRCLE, RM_OCTAGON | RM_DOUBLE;
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            region.has_room_types = true;
            // Parse list of room type constants (can be comma-separated or | combined)
            while !check(p, .SEMICOLON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
                val, ok := parse_cexpr3(p);  // parse single value without binary ops
                if ok {
                    array_add(*region.room_types, val);
                }
                // Skip comma or pipe
                if !match(p, .COMMA) && !match(p, .PIPE) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_SIZE {
            // Size: SZ_MEDIUM;
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            region.has_size = true;
            region.size = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            // Flags: RF_VAULT, RF_NEVER_LIT;
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            while !check(p, .SEMICOLON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
                val, ok := parse_cexpr3(p);
                if ok {
                    array_add(*region.flags, val);
                }
                if !match(p, .COMMA) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_GRID {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            // Grid: is followed by MAPAREA token ({: ... :})
            grid_tok, grid_ok := consume(p, .MAPAREA, "Expected map grid");
            if !grid_ok return false;
            region.has_grid = true;
            region.grid = grid_tok.text;
            // Calculate grid dimensions from content
            width, height := calculate_grid_dimensions(grid_tok.text);
            region.grid_width = width;
            region.grid_height = height;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_CONSTANTS {
            parse_constants_section(p, *region.constants);
        } else if tok.type == .KW_LISTS {
            parse_lists_section(p, *region.lists);
        } else if tok.type == .KW_DESC {
            // Desc: "description";
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            // Skip the description string
            if check(p, .STRING) {
                advance(p);
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_TILES {
            // Tiles: 'ch': $"terrain" [with $"obj" [of $"owner"]] [as COLOR GLYPH] [[TILE_*]] (,|;)
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;

            while !check(p, .RBRACE) && !parser_is_at_end(p) {
                // Check for section-ending keywords
                next := peek(p);
                if next.type == .KW_LISTS || next.type == .KW_FLAGS ||
                   next.type == .KW_ON || next.type == .KW_EVENT ||
                   next.type == .KW_GRID || next.type == .KW_CONSTANTS ||
                   next.type == .KW_DESC || next.type == .KW_TILES {
                    break;
                }

                // Expect CHAR_CONST: 'A', '1', etc.
                if !check(p, .CHAR_CONST) break;
                ch_tok := peek(p);
                advance(p);

                _, tile_colon_ok := consume(p, .COLON, "Expected ':' after tile character");
                if !tile_colon_ok break;

                tile: ParsedTile;
                tile.ch = cast(u8) ch_tok.int_value;

                // Terrain ref: $"terrain name"
                if check(p, .RES_REF) {
                    ref_tok := peek(p);
                    advance(p);
                    tile.terrain_ref = extract_res_ref_name(ref_tok.text);
                }

                // Optional: with $"object" [of $"owner"]
                if check(p, .KW_WITH) {
                    advance(p);
                    if check(p, .RES_REF) {
                        obj_tok := peek(p);
                        advance(p);
                        tile.object_ref = extract_res_ref_name(obj_tok.text);
                    }
                    // Optional: of $"owner"
                    if check(p, .KW_OF) {
                        advance(p);
                        if check(p, .RES_REF) {
                            owner_tok := peek(p);
                            advance(p);
                            tile.owner_ref = extract_res_ref_name(owner_tok.text);
                        }
                    }
                }

                // Optional: as COLOR GLYPH (skip - visual override deferred)
                if check(p, .KW_AS) {
                    advance(p);
                    // Skip color token
                    if check(p, .COLOR) || check(p, .CONSTANT) || check(p, .IDENTIFIER) {
                        advance(p);
                    }
                    // Skip glyph constant
                    if check(p, .CONSTANT) || check(p, .IDENTIFIER) {
                        advance(p);
                    }
                }

                // Optional: [TILE_FLAG1 | TILE_FLAG2 ...]
                if check(p, .LBRACKET) {
                    advance(p);
                    flags_val, flags_ok := parse_cexpr(p);
                    if flags_ok {
                        tile.flags = cast(u32) flags_val;
                    }
                    match(p, .RBRACKET);
                }

                array_add(*region.tiles, tile);

                // Comma continues, semicolon ends section
                if check(p, .SEMICOLON) {
                    advance(p);
                    break;
                }
                match(p, .COMMA);
            }
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.regions, region);
    return true;
}

// ============================================================================
// Lists section parser
// Parses: Lists: * LIST_TYPE entry1 entry2 ..., * LIST_TYPE2 ...;
// ============================================================================
parse_lists_section :: (p: *Parser, lists: *[..] ParsedWeightList) {
    advance(p);  // consume 'Lists'
    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return;

    // Parse each list (starts with *)
    while check(p, .STAR) && !parser_is_at_end(p) {
        advance(p);  // consume '*'

        wlist: ParsedWeightList;
        current_weight: s64 = 1;  // Default weight

        // First token after * is the list type (e.g., WALL_COLOURS, ENCOUNTER_LIST)
        type_tok := peek(p);
        if type_tok.type == .CONSTANT || type_tok.type == .IDENTIFIER {
            val, ok := parse_cexpr3(p);
            if ok {
                wlist.list_type = val;
            }
        } else {
            // Unknown list type, skip this list
            while !check(p, .STAR) && !check(p, .SEMICOLON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
                advance(p);
            }
            continue;
        }

        // Parse entries until we hit *, ; or ,
        while !check(p, .STAR) && !check(p, .SEMICOLON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
            entry_tok := peek(p);

            // Check for comma (separates lists)
            if entry_tok.type == .COMMA {
                advance(p);
                break;  // End of this list
            }

            // Number sets the weight for following entries
            if entry_tok.type == .NUMBER {
                current_weight = entry_tok.int_value;
                advance(p);
                continue;
            }

            // Resource reference: $"name"
            if entry_tok.type == .RES_REF {
                entry: WeightListEntry;
                entry.weight = current_weight;
                entry.is_ref = true;
                entry.ref_name = extract_res_ref_name(entry_tok.text);
                array_add(*wlist.entries, entry);
                advance(p);
                current_weight = 1;  // Reset weight after use
                continue;
            }

            // Constant (color word, RM_*, etc.)
            if entry_tok.type == .CONSTANT || entry_tok.type == .COLOR {
                entry: WeightListEntry;
                entry.weight = current_weight;
                entry.is_ref = false;
                val, ok := parse_cexpr3(p);
                if ok {
                    entry.value = val;
                }
                array_add(*wlist.entries, entry);
                current_weight = 1;
                continue;
            }

            // Macro call: CONSTRAINED_ENC($"name", MA_AQUATIC) or CON_ENC_MINMAX(...)
            if entry_tok.type == .IDENTIFIER {
                // Check if this looks like a macro (followed by LPAREN)
                macro_name := entry_tok.text;
                advance(p);

                if check(p, .LPAREN) {
                    // It's a macro call
                    entry: WeightListEntry;
                    entry.weight = current_weight;
                    entry.has_macro = true;
                    entry.macro_name = macro_name;

                    advance(p);  // consume '('
                    // Parse arguments until ')'
                    while !check(p, .RPAREN) && !parser_is_at_end(p) {
                        arg_tok := peek(p);
                        if arg_tok.type == .RES_REF {
                            array_add(*entry.macro_args, extract_res_ref_name(arg_tok.text));
                            advance(p);
                        } else if arg_tok.type == .CONSTANT || arg_tok.type == .IDENTIFIER {
                            array_add(*entry.macro_args, arg_tok.text);
                            advance(p);
                        } else if arg_tok.type == .NUMBER {
                            // Convert number to string for macro args
                            num_str := tprint("%", arg_tok.int_value);
                            array_add(*entry.macro_args, copy_string(num_str));
                            advance(p);
                        } else {
                            advance(p);
                        }
                        match(p, .COMMA);  // Skip comma between args
                    }
                    match(p, .RPAREN);  // consume ')'
                    array_add(*wlist.entries, entry);
                    current_weight = 1;
                    continue;
                } else {
                    // Not a macro, treat as constant - try to look it up
                    val, found := lookup_resource_constant(macro_name);
                    if found {
                        entry: WeightListEntry;
                        entry.weight = current_weight;
                        entry.is_ref = false;
                        entry.value = val;
                        array_add(*wlist.entries, entry);
                    }
                    current_weight = 1;
                    continue;
                }
            }

            // Unknown token, skip it
            advance(p);
        }

        array_add(lists, wlist);
    }

    match(p, .SEMICOLON);
}

// ============================================================================
// Encounter parser
// ============================================================================
parse_encounter :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Encounter'

    name_tok, name_ok := consume(p, .STRING, "Expected encounter name");
    if !name_ok return false;

    enc: ParsedEncounter;
    enc.name = extract_string_content(name_tok.text);
    enc.line = start_tok.line;
    enc.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);

        if tok.type == .KW_WEIGHT {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            enc.has_weight = true;
            enc.weight = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_CR {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            // Parse CR: N+ or N-M format (must handle as simple numbers, not expressions)
            num_tok := peek(p);
            min_val: s64 = 0;
            if num_tok.type == .NUMBER {
                min_val = num_tok.int_value;
                advance(p);
            } else {
                // Fall back to expression parsing for complex cases
                parsed_val, ok := parse_cexpr(p);
                if !ok return false;
                min_val = parsed_val;
            }
            enc.has_cr = true;
            enc.cr_min = min_val;
            enc.cr_max = min_val;

            // Check for + (open ended) or - (range)
            if match(p, .PLUS) {
                enc.cr_max = 99;  // Open-ended
            } else if match(p, .MINUS) {
                max_tok := peek(p);
                if max_tok.type == .NUMBER {
                    enc.cr_max = max_tok.int_value;
                    advance(p);
                } else {
                    max_val, max_ok := parse_cexpr(p);
                    if !max_ok return false;
                    enc.cr_max = max_val;
                }
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_TERRAIN {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            enc.has_terrain = true;
            enc.terrain = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_ALIGN {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            enc.has_align = true;
            enc.align = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            parse_flags_list(p, *enc.flags);
        } else if tok.type == .KW_PARTS {
            // Skip Parts for now (very complex syntax)
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            while !check(p, .SEMICOLON) && !check(p, .KW_FLAGS) &&
                  !check(p, .KW_LISTS) && !check(p, .KW_CONSTANTS) &&
                  !check(p, .KW_ON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
                advance(p);
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_LISTS {
            // Skip Lists for now
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            while !check(p, .SEMICOLON) && !check(p, .KW_FLAGS) &&
                  !check(p, .KW_CONSTANTS) && !check(p, .KW_ON) &&
                  !check(p, .RBRACE) && !parser_is_at_end(p) {
                advance(p);
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_CONSTANTS {
            parse_constants_section(p, *enc.constants);
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.encounters, enc);
    return true;
}

// ============================================================================
// Domain parser
// ============================================================================
parse_domain :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Domain'

    name_tok, name_ok := consume(p, .STRING, "Expected domain name");
    if !name_ok return false;

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    // Parse index (usually 0)
    index, ok := parse_cexpr(p);
    if !ok return false;

    domain: ParsedDomain;
    domain.name = extract_string_content(name_tok.text);
    domain.index = index;
    domain.line = start_tok.line;
    domain.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);

        if tok.type == .KW_DESC {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            domain.has_desc = true;
            domain.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_GRANTS {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;

            while true {
                grant_tok := peek(p);
                if grant_tok.type == .KW_FEAT {
                    if !parse_grant_feat(p, *domain.grants) return false;
                } else if grant_tok.type == .KW_ABILITY {
                    if !parse_grant_ability(p, *domain.grants) return false;
                } else if grant_tok.type == .KW_STATI {
                    if !parse_grant_stati(p, *domain.grants) return false;
                } else {
                    break;
                }
                if !match(p, .COMMA) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_SPELLS {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            // Parse list of $"spell" references
            while true {
                spell_tok := peek(p);
                if spell_tok.type == .RES_REF {
                    array_add(*domain.spells, extract_res_ref_name(spell_tok.text));
                    advance(p);
                } else {
                    break;
                }
                if !match(p, .COMMA) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.domains, domain);
    return true;
}

// ============================================================================
// God parser
// ============================================================================
parse_god :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'God'

    name_tok, name_ok := consume(p, .STRING, "Expected god name");
    if !name_ok return false;

    god: ParsedGod;
    god.name = extract_string_content(name_tok.text);
    god.line = start_tok.line;
    god.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);

        if tok.type == .KW_DESC {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            god.has_desc = true;
            god.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_DOMAINS {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            // Parse list of $"domain" references
            while true {
                domain_tok := peek(p);
                if domain_tok.type == .RES_REF {
                    array_add(*god.domains, extract_res_ref_name(domain_tok.text));
                    advance(p);
                } else {
                    break;
                }
                if !match(p, .COMMA) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_GRANTS {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;

            while true {
                grant_tok := peek(p);
                if grant_tok.type == .KW_FEAT {
                    if !parse_grant_feat(p, *god.grants) return false;
                } else if grant_tok.type == .KW_ABILITY {
                    if !parse_grant_ability(p, *god.grants) return false;
                } else if grant_tok.type == .KW_STATI {
                    if !parse_grant_stati(p, *god.grants) return false;
                } else {
                    break;
                }
                if !match(p, .COMMA) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_LISTS {
            // Skip Lists for now (complex)
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            // Skip until we hit a keyword we recognize
            while !check(p, .KW_DESC) && !check(p, .KW_DOMAINS) &&
                  !check(p, .KW_GRANTS) && !check(p, .KW_CONSTANTS) &&
                  !check(p, .KW_ON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
                advance(p);
            }
        } else if tok.type == .KW_CONSTANTS {
            parse_constants_section(p, *god.constants);
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.gods, god);
    return true;
}

// ============================================================================
// Text parser
// ============================================================================
parse_text :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Text'

    name_tok, name_ok := consume(p, .STRING, "Expected text name");
    if !name_ok return false;

    text: ParsedText;
    text.name = extract_string_content(name_tok.text);
    text.line = start_tok.line;
    text.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    // Text resources just contain a single string
    content_tok := peek(p);
    if content_tok.type == .STRING {
        text.content = extract_string_content(content_tok.text);
        advance(p);
    }

    // Skip anything else until rbrace
    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        advance(p);
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.texts, text);
    return true;
}

// ============================================================================
// Dungeon parser
// ============================================================================
parse_dungeon :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Dungeon'

    name_tok, name_ok := consume(p, .STRING, "Expected dungeon name");
    if !name_ok return false;

    dungeon: ParsedDungeon;
    dungeon.name = extract_string_content(name_tok.text);
    dungeon.line = start_tok.line;
    dungeon.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        tok := peek(p);

        if tok.type == .KW_DESC {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            desc_tok, desc_ok := consume(p, .STRING, "Expected description");
            if !desc_ok return false;
            dungeon.has_desc = true;
            dungeon.desc = extract_string_content(desc_tok.text);
            match(p, .SEMICOLON);
        } else if tok.type == .KW_CONSTANTS {
            parse_constants_section(p, *dungeon.constants);
        } else if tok.type == .KW_SPECIALS {
            advance(p);
            _, colon_ok := consume(p, .COLON, "Expected ':'");
            if !colon_ok return false;
            // Parse: * $"room" at level N, ...
            while check(p, .STAR) {
                advance(p);  // consume '*'

                room_tok := peek(p);
                if room_tok.type == .RES_REF {
                    advance(p);

                    special: ParsedSpecial;
                    special.room_ref = extract_res_ref_name(room_tok.text);

                    // Expect "at level N"
                    at_tok := peek(p);
                    if at_tok.type == .KW_AT ||
                       (at_tok.type == .IDENTIFIER && strings_equal_nocase(at_tok.text, "at")) {
                        advance(p);
                        level_tok := peek(p);
                        if level_tok.type == .KW_LEVEL ||
                           (level_tok.type == .IDENTIFIER && strings_equal_nocase(level_tok.text, "level")) {
                            advance(p);
                        }
                        level_val, ok := parse_cexpr(p);
                        if ok {
                            special.at_level = level_val;
                        }
                    }

                    array_add(*dungeon.specials, special);
                }

                if !match(p, .COMMA) break;
            }
            match(p, .SEMICOLON);
        } else if tok.type == .KW_LISTS {
            parse_lists_section(p, *dungeon.lists);
        } else if tok.type == .KW_ON || tok.type == .KW_EVENT {
            skip_event_handler(p);
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.dungeons, dungeon);
    return true;
}

// Artifact resource parser
// Grammar: artifact_def: ARTIFACT LITERAL '{' (arti_entry)* '}';
parse_artifact :: (p: *Parser) -> bool {
    start_tok := advance(p);  // consume 'Artifact'

    name_tok, name_ok := consume(p, .STRING, "Expected artifact name");
    if !name_ok return false;

    artifact: ParsedArtifact;
    artifact.name = extract_string_content(name_tok.text);
    artifact.line = start_tok.line;
    artifact.column = start_tok.column;

    _, lbrace_ok := consume(p, .LBRACE, "Expected '{'");
    if !lbrace_ok return false;

    while !check(p, .RBRACE) && !parser_is_at_end(p) {
        if !parse_artifact_entry(p, *artifact) {
            // Skip to next entry on error
            while !check(p, .RBRACE) && !check(p, .SEMICOLON) && !parser_is_at_end(p) {
                advance(p);
            }
            match(p, .SEMICOLON);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.artifacts, artifact);
    return true;
}

parse_artifact_entry :: (p: *Parser, artifact: *ParsedArtifact) -> bool {
    tok := peek(p);

    // Desc: "text";
    if tok.type == .KW_DESC {
        advance(p);
        match(p, .COLON);
        desc_tok, desc_ok := consume(p, .STRING, "Expected description");
        if !desc_ok return false;
        artifact.has_desc = true;
        artifact.desc = extract_string_content(desc_tok.text);
        match(p, .SEMICOLON);
        return true;
    }

    // Item: $"item ref";
    if tok.type == .KW_ITEM {
        advance(p);
        match(p, .COLON);
        ref_tok, ref_ok := consume(p, .RES_REF, "Expected item reference");
        if !ref_ok return false;
        artifact.has_item = true;
        artifact.item_ref = extract_res_ref_name(ref_tok.text);
        match(p, .SEMICOLON);
        return true;
    }

    // Attribute adjustments: Str: +2, Dex: -1, ...;
    if tok.type == .ATTRIBUTE {
        while check(p, .ATTRIBUTE) {
            attr_tok := advance(p);
            attr_idx := attr_tok.int_value;
            match(p, .COLON);
            val, val_ok := parse_cexpr3(p);
            if !val_ok return false;
            if attr_idx >= 0 && attr_idx < 8 {
                artifact.has_attr_adj[attr_idx] = true;
                artifact.attr_adj[attr_idx] = val;
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Resists: RES_FIRE, RES_COLD, ...;
    if tok.type == .KW_RESISTS {
        advance(p);
        match(p, .COLON);
        while true {
            res_val, res_ok := parse_cexpr3(p);
            if !res_ok break;
            artifact.resists |= res_val;
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Sustains: Str, Dex, ...;
    if tok.type == .KW_SUSTAINS {
        advance(p);
        match(p, .COLON);
        while check(p, .ATTRIBUTE) {
            attr_tok := advance(p);
            attr_idx := attr_tok.int_value;
            if attr_idx >= 0 && attr_idx < 8 {
                artifact.sustains |= (1 << attr_idx);
            }
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Qualities: QU_ONE, ...;
    if tok.type == .KW_QUALITIES {
        advance(p);
        match(p, .COLON);
        while true {
            qu_val, qu_ok := parse_cexpr3(p);
            if !qu_ok break;
            artifact.qualities |= qu_val;
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Equip/Wield/Hit/Invoke FOR power, power, ...;
    if tok.type == .KW_EQUIP || tok.type == .KW_WIELD ||
       tok.type == .KW_HIT || tok.type == .KW_INVOKE {
        power_type: ArtPowerType;
        if tok.type == .KW_EQUIP  power_type = .EQUIP;
        if tok.type == .KW_WIELD  power_type = .WIELD;
        if tok.type == .KW_HIT    power_type = .HIT;
        if tok.type == .KW_INVOKE power_type = .INVOKE;
        advance(p);

        // Expect FOR
        if !match(p, .KW_FOR) && !match(p, .KW_FOR_KW) {
            add_error(p, "Expected 'for' after power type");
            return false;
        }

        // Parse power list
        while true {
            if !parse_art_power(p, artifact, power_type) return false;
            if !match(p, .COMMA) break;
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Event handler - skip
    if tok.type == .KW_ON || tok.type == .KW_EVENT {
        skip_event_handler(p);
        return true;
    }

    // Constants section
    if tok.type == .KW_CONSTANTS {
        // Skip constants section for now
        advance(p);
        match(p, .COLON);
        while !check(p, .SEMICOLON) && !check(p, .RBRACE) && !parser_is_at_end(p) {
            advance(p);
        }
        match(p, .SEMICOLON);
        return true;
    }

    // Unknown entry - skip
    advance(p);
    return true;
}

// Parse individual artifact power
// Grammar: Stati[type,param] | Stati[type] | res_ref | res_ref N/day | innate res_ref | Feat id
parse_art_power :: (p: *Parser, artifact: *ParsedArtifact, power_type: ArtPowerType) -> bool {
    tok := peek(p);
    power: ParsedArtPower;
    power.power_type = power_type;

    // Stati[type, param] or Stati[type]
    if tok.type == .KW_STATI {
        advance(p);
        power.kind = .STATI;

        _, lbracket_ok := consume(p, .LBRACKET, "Expected '['");
        if !lbracket_ok return false;

        stati_type, type_ok := parse_cexpr3(p);
        if !type_ok return false;
        power.stati_type = stati_type;

        if match(p, .COMMA) {
            stati_param, param_ok := parse_cexpr3(p);
            if !param_ok return false;
            power.stati_param = stati_param;
        }

        _, rbracket_ok := consume(p, .RBRACKET, "Expected ']'");
        if !rbracket_ok return false;

        array_add(*artifact.powers, power);
        return true;
    }

    // Innate $"effect"
    if tok.type == .KW_INNATE {
        advance(p);
        power.kind = .INNATE;

        ref_tok, ref_ok := consume(p, .RES_REF, "Expected effect reference");
        if !ref_ok return false;
        power.effect_ref = extract_res_ref_name(ref_tok.text);

        array_add(*artifact.powers, power);
        return true;
    }

    // Feat FEAT_ID
    if tok.type == .KW_FEAT {
        advance(p);
        power.kind = .FEAT;

        feat_val, feat_ok := parse_cexpr3(p);
        if !feat_ok return false;
        power.feat_id = feat_val;

        array_add(*artifact.powers, power);
        return true;
    }

    // $"effect" with optional modifiers
    if tok.type == .RES_REF {
        advance(p);
        power.kind = .EFFECT;
        power.effect_ref = extract_res_ref_name(tok.text);

        next := peek(p);

        // $"effect" at STYPE (optional save type)
        if next.type == .KW_AT {
            advance(p);
            // Skip save type for now
            if check(p, .STYPE) advance(p);
        }
        // $"effect" every Xd6 turns
        else if next.type == .KW_EVERY {
            advance(p);
            power.has_dice = true;
            dice, dice_ok := parse_dice_value(p);
            if dice_ok power.use_dice = dice;
            match(p, .KW_TURNS);
        }
        // $"effect" N/day or N per day
        else if next.type == .NUMBER || next.type == .CONSTANT {
            uses, uses_ok := parse_cexpr3(p);
            if uses_ok {
                power.has_uses = true;
                after := peek(p);
                if after.type == .SLASH || after.type == .KW_PER {
                    advance(p);
                    if match(p, .KW_DAY) {
                        power.uses_per_day = uses;
                    } else if match(p, .KW_WEEK) {
                        power.uses_per_week = uses;
                    }
                }
            }
        }

        array_add(*artifact.powers, power);
        return true;
    }

    add_error(p, "Expected artifact power");
    return false;
}
