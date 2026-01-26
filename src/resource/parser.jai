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
    key:   s64;
    value: s64;
}

// Grant types
GrantType :: enum u8 { FEAT; ABILITY; STATI; }
LevelType :: enum u8 { AT_LEVEL; EVERY_LEVEL; EVERY_NTH_LEVEL; }

ParsedGrant :: struct {
    grant_type:     GrantType;
    feat_id:        s64;
    ability_id:     s64;
    ability_param1: s64;
    ability_param2: s64;
    has_param2:     bool;
    stati_type:     s64;
    stati_param1:   s64;
    stati_param2:   s64;
    level_type:     LevelType;
    level:          s64;
    every_n:        s64;
    starting_level: s64;
}

ParsedGearEntry :: struct {
    has_quantity: bool;
    quantity:     ParsedDice;
    item_ref:     string;
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

    // Parsed results
    flavors:   [..] ParsedFlavor;
    items:     [..] ParsedItem;
    monsters:  [..] ParsedMonster;
    effects:   [..] ParsedEffect;
    features:  [..] ParsedFeature;
    terrains:  [..] ParsedTerrain;
    races:     [..] ParsedRace;
    classes:   [..] ParsedClass;
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

    add_error(p, "Expected expression");
    return 0, false;
}

// Dice parsing
parse_dice_value :: (p: *Parser) -> ParsedDice, bool {
    dice: ParsedDice;
    dice.num = 1;
    dice.sides = 0;
    dice.bonus = 0;

    // Parse number of dice
    num_tok := peek(p);
    if num_tok.type == .NUMBER {
        dice.num = cast(s8) num_tok.int_value;
        advance(p);
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

    // Parse character (char constant or GLYPH_ constant)
    tok := peek(p);
    if tok.type == .CHAR_CONST {
        advance(p);
        glyph.char_code = tok.int_value;
    } else if tok.type == .CONSTANT {
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
    // Skip until we find matching braces
    while !check(p, .LBRACE) && !parser_is_at_end(p) {
        advance(p);
    }

    if !check(p, .LBRACE) return true;

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

    // Optional semicolon or comma after handler
    match(p, .SEMICOLON);
    match(p, .COMMA);

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
            advance(p);
            grant.level_type = .EVERY_LEVEL;
            grant.every_n = 1;
        } else {
            n, n_ok := parse_cexpr3(p);
            if !n_ok return false;
            skip_ordinal_suffix(p);

            _, lvl_ok := consume(p, .KW_LEVEL, "Expected 'level'");
            if !lvl_ok return false;

            grant.level_type = .EVERY_NTH_LEVEL;
            grant.every_n = n;
        }

        _, start_ok := consume(p, .KW_STARTING, "Expected 'starting'");
        if !start_ok return false;
        _, at2_ok := consume(p, .KW_AT, "Expected 'at'");
        if !at2_ok return false;

        start_level, start_ok2 := parse_cexpr3(p);
        if !start_ok2 return false;
        skip_ordinal_suffix(p);

        grant.starting_level = start_level;
    } else {
        level, lvl_ok := parse_cexpr3(p);
        if !lvl_ok return false;
        skip_ordinal_suffix(p);

        _, kw_ok := consume(p, .KW_LEVEL, "Expected 'level'");
        if !kw_ok return false;

        grant.level_type = .AT_LEVEL;
        grant.level = level;
    }

    return true;
}

parse_grant_feat :: (p: *Parser, grants: *[..] ParsedGrant) -> bool {
    advance(p);  // consume 'Feat'
    _, lbracket_ok := consume(p, .LBRACKET, "Expected '['");
    if !lbracket_ok return false;

    feat_id, ok := parse_cexpr2(p);
    if !ok return false;

    _, rbracket_ok := consume(p, .RBRACKET, "Expected ']'");
    if !rbracket_ok return false;

    grant: ParsedGrant;
    grant.grant_type = .FEAT;
    grant.feat_id = feat_id;

    if !parse_grant_level_condition(p, *grant) return false;

    array_add(grants, grant);
    return true;
}

parse_grant_ability :: (p: *Parser, grants: *[..] ParsedGrant) -> bool {
    advance(p);
    _, lbracket_ok := consume(p, .LBRACKET, "Expected '['");
    if !lbracket_ok return false;

    ability_id, ok := parse_cexpr2(p);
    if !ok return false;

    grant: ParsedGrant;
    grant.grant_type = .ABILITY;
    grant.ability_id = ability_id;

    if match(p, .COMMA) {
        param1, ok1 := parse_cexpr3(p);
        if !ok1 return false;
        grant.ability_param1 = param1;

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

    stati_type, ok := parse_cexpr2(p);
    if !ok return false;

    grant: ParsedGrant;
    grant.grant_type = .STATI;
    grant.stati_type = stati_type;

    if match(p, .COMMA) {
        param1, ok1 := parse_cexpr2(p);
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

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

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

        if !match(p, .COMMA) break;
    }

    _, semi_ok := consume(p, .SEMICOLON, "Expected ';'");
    return semi_ok;
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

        value, val_ok := parse_cexpr(p);
        if !val_ok return false;

        // Handle resource reference as value
        tok := peek(p);
        if tok.type == .RES_REF {
            advance(p);
        }

        c: ParsedConstant;
        c.key = key;
        c.value = value;
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
            // Error recovery
            while !parser_is_at_end(p) && !check(p, .SEMICOLON) && !check(p, .RBRACE) {
                advance(p);
            }
            if check(p, .SEMICOLON) advance(p);
        }
    }
    return !p.had_error;
}

// Resource dispatch
parse_resource :: (p: *Parser) -> bool {
    tok := peek(p);
    if tok.type == .KW_FLAVOR   return parse_flavor(p);
    if tok.type == .KW_MONSTER  return parse_monster(p);
    if tok.type == .KW_ITEM     return parse_item(p);
    if tok.type == .KW_EFFECT   return parse_effect(p, false);
    if tok.type == .KW_SPELL    return parse_effect(p, true);
    if tok.type == .KW_FEATURE  return parse_feature(p);
    if tok.type == .KW_TERRAIN  return parse_terrain(p);
    if tok.type == .KW_RACE     return parse_race(p);
    if tok.type == .KW_CLASS    return parse_class(p);

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
            cr_val, cr_ok := parse_cexpr(p);
            if !cr_ok return false;
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
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            item.has_level = true;
            item.level = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_MAT {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
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
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *item.flags) return false;
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

    array_add(*p.items, item);
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
        if tok.type == .KW_LEVEL {
            advance(p);
            _, colon2_ok := consume(p, .COLON, "Expected ':'");
            if !colon2_ok return false;
            val, ok := parse_cexpr(p);
            if !ok return false;
            effect.has_level = true;
            effect.level = val;
            match(p, .SEMICOLON);
        } else if tok.type == .KW_FLAGS {
            if !parse_flags_list(p, *effect.flags) return false;
        } else {
            advance(p);
        }
    }

    _, rbrace_ok := consume(p, .RBRACE, "Expected '}'");
    if !rbrace_ok return false;

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
    if tok.type == .KW_STR || tok.type == .KW_DEX || tok.type == .KW_CON ||
       tok.type == .KW_INT || tok.type == .KW_WIS || tok.type == .KW_CHA ||
       tok.type == .KW_LUC {
        race.has_attrs = true;
        while true {
            attr_tok := peek(p);
            attr_type := attr_tok.type;
            if attr_type != .KW_STR && attr_type != .KW_DEX && attr_type != .KW_CON &&
               attr_type != .KW_INT && attr_type != .KW_WIS && attr_type != .KW_CHA &&
               attr_type != .KW_LUC {
                break;
            }
            advance(p);

            val, ok := parse_cexpr(p);
            if !ok return false;

            if attr_type == .KW_STR race.str_mod = val;
            else if attr_type == .KW_DEX race.dex_mod = val;
            else if attr_type == .KW_CON race.con_mod = val;
            else if attr_type == .KW_INT race.int_mod = val;
            else if attr_type == .KW_WIS race.wis_mod = val;
            else if attr_type == .KW_CHA race.cha_mod = val;
            else if attr_type == .KW_LUC race.luc_mod = val;

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
        if strings_equal(tok.text, "MALE_NAMES") ||
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
        if strings_equal(tok.text, "FEMALE_NAMES") {
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
        if strings_equal(tok.text, "FAMILY_NAMES") {
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
