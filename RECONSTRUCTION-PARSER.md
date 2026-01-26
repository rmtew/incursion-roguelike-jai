# Parser Implementation Details

## Parser Core Functions

```jai
// Initialize parser with tokens
parser_init :: (tokens: [] Token) -> Parser {
    p: Parser;
    p.tokens = tokens;
    p.pos = 0;
    return p;
}

// Main parse loop
parser_parse :: (p: *Parser) -> bool {
    while !is_at_end(p) {
        if !parse_resource(p) {
            // Error recovery
            while !is_at_end(p) && !check(p, .SEMICOLON) && !check(p, .RBRACE) {
                advance(p);
            }
            if check(p, .SEMICOLON) advance(p);
        }
    }
    return !p.had_error;
}

// Free parser resources
parser_free :: (p: *Parser) {
    array_free(p.errors);
    for *f: p.flavors { /* free sub-arrays */ }
    array_free(p.flavors);
    // ... same for all parsed arrays
}

// Resource dispatch
parse_resource :: (p: *Parser) -> bool {
    tok := peek(p);
    if tok.type == {
        case .KW_FLAVOR;   return parse_flavor(p);
        case .KW_MONSTER;  return parse_monster(p);
        case .KW_ITEM;     return parse_item(p);
        case .KW_EFFECT;   return parse_effect(p, false);
        case .KW_SPELL;    return parse_effect(p, true);
        case .KW_WIZARD; #through;
        case .KW_PRIEST;   return parse_effect_with_sources(p);
        case .KW_FEATURE;  return parse_feature(p);
        case .KW_TERRAIN;  return parse_terrain(p);
        case .KW_RACE;     return parse_race(p);
        case .KW_CLASS;    return parse_class(p);
        case;
            add_error(p, "Expected resource definition");
            return false;
    }
}
```

## Helper Functions

```jai
// Token manipulation
peek :: (p: *Parser) -> Token { return p.tokens[p.pos]; }
advance :: (p: *Parser) -> Token { t := peek(p); p.pos += 1; return t; }
is_at_end :: (p: *Parser) -> bool { return peek(p).type == .EOF; }
check :: (p: *Parser, type: TokenType) -> bool { return peek(p).type == type; }
match :: (p: *Parser, type: TokenType) -> bool {
    if check(p, type) { advance(p); return true; }
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
```

## Expression Parsing

```jai
// Precedence levels:
// parse_cexpr  - lowest: bitwise OR |
// parse_cexpr2 - middle: bitwise AND &, addition +, subtraction -
// parse_cexpr3 - highest: unary -, parentheses, atoms

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
        return parse_cexpr3(p);
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
```

## Dice Parsing

```jai
parse_dice_value :: (p: *Parser) -> ParsedDice, bool {
    dice: ParsedDice;

    // Parse number of dice
    num_tok := peek(p);
    if num_tok.type == .NUMBER {
        dice.num = cast(s8) num_tok.int_value;
        advance(p);
    } else {
        dice.num = 1;
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
```

## Color Parsing

```jai
parse_color :: (p: *Parser) -> ParsedColor, bool {
    color: ParsedColor;
    color.modifier = .NONE;

    tok := peek(p);
    if tok.type == .KW_BRIGHT {
        advance(p); color.modifier = .BRIGHT;
    } else if tok.type == .KW_LIGHT {
        advance(p); color.modifier = .LIGHT;
    } else if tok.type == .KW_DARK {
        advance(p); color.modifier = .DARK;
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

token_to_base_color :: (type: TokenType) -> BaseColor, bool {
    if type == {
        case .KW_BLACK;   return .BLACK, true;
        case .KW_WHITE;   return .WHITE, true;
        case .KW_RED;     return .RED, true;
        case .KW_BLUE;    return .BLUE, true;
        case .KW_GREEN;   return .GREEN, true;
        case .KW_YELLOW;  return .YELLOW, true;
        case .KW_PURPLE;  return .PURPLE, true;
        case .KW_CYAN;    return .CYAN, true;
        case .KW_BROWN;   return .BROWN, true;
        case .KW_GREY;    return .GREY, true;
        case .KW_MAGENTA; return .MAGENTA, true;
        case .KW_PINK;    return .PINK, true;
        case .KW_SHADOW;  return .SHADOW, true;
        case .KW_SKY;     return .SKY, true;
        case .KW_AZURE;   return .AZURE, true;
        case;             return .NONE, false;
    }
}
```

## Image Parsing (with background color support)

```jai
// Parse: "bright blue 'X' on red" or "grey GLYPH_WALL"
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

    // Check for "on color" background
    if check(p, .KW_ON) {
        advance(p);
        bg, bg_ok := parse_color(p);
        if !bg_ok return glyph, false;
        glyph.has_bg = true;
        glyph.bg_color = bg;
    }

    return glyph, true;
}
```

## Grant Parsing (shared by Race and Class)

```jai
// Parse: Feat[FT_X] at 1st level
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

// Parse: Ability[CA_X,+3] at 2nd level
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

// Parse: Stati[SUSTAIN,A_STR,+5] at 1st level
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

// Parse: "at 1st level" or "at every 2nd level starting at 1st"
parse_grant_level_condition :: (p: *Parser, grant: *ParsedGrant) -> bool {
    _, at_ok := consume(p, .KW_AT, "Expected 'at'");
    if !at_ok return false;

    if match(p, .KW_EVERY) {
        tok := peek(p);
        if tok.type == .KW_LEVEL {
            // "at every level starting at Nth"
            advance(p);
            grant.level_type = .EVERY_LEVEL;
            grant.every_n = 1;
        } else {
            // "at every Nth level starting at Mth"
            n, n_ok := parse_cexpr3(p);
            if !n_ok return false;
            skip_ordinal_suffix(p);

            _, lvl_ok := consume(p, .KW_LEVEL, "Expected 'level'");
            if !lvl_ok return false;

            grant.level_type = .EVERY_NTH_LEVEL;
            grant.every_n = n;
        }

        // Parse "starting at Nth"
        _, start_ok := consume(p, .KW_STARTING, "Expected 'starting'");
        if !start_ok return false;
        _, at2_ok := consume(p, .KW_AT, "Expected 'at'");
        if !at2_ok return false;

        start_level, start_ok2 := parse_cexpr3(p);
        if !start_ok2 return false;
        skip_ordinal_suffix(p);

        grant.starting_level = start_level;
    } else {
        // "at Nth level"
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

// Skip ordinal suffix (st, nd, rd, th)
skip_ordinal_suffix :: (p: *Parser) {
    tok := peek(p);
    if tok.type == .KW_ST || tok.type == .KW_ND ||
       tok.type == .KW_RD || tok.type == .KW_TH {
        advance(p);
    }
}
```

## Flags Parsing (generic)

```jai
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
                add_error(p, tprint("Unknown flag: %", tok.text));
                return false;
            }
        } else {
            add_error(p, "Expected flag constant");
            return false;
        }

        if !match(p, .COMMA) break;
    }

    _, semi_ok := consume(p, .SEMICOLON, "Expected ';'");
    return semi_ok;
}
```

## Constants Section Parsing

```jai
// Parse: Constants: * KEY VALUE; * KEY VALUE; ...
parse_constants_section :: (p: *Parser, constants: *[..] ParsedConstant) -> bool {
    advance(p);  // consume 'Constants'

    _, colon_ok := consume(p, .COLON, "Expected ':'");
    if !colon_ok return false;

    while check(p, .STAR) {
        advance(p);  // consume '*'

        // Parse key (constant name)
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

        // Parse value
        value, val_ok := parse_cexpr(p);
        if !val_ok return false;

        // Handle resource reference as value
        tok := peek(p);
        if tok.type == .RES_REF {
            // For now, just skip resource refs in constants
            advance(p);
        }

        c: ParsedConstant;
        c.key = key;
        c.value = value;
        array_add(constants, c);

        // Semicolon or comma between entries
        if match(p, .SEMICOLON) break;
        match(p, .COMMA);
    }

    return true;
}
```

## Event Handler Skipping

```jai
// Skip event handlers (complex code blocks)
skip_event_handler :: (p: *Parser) -> bool {
    advance(p);  // consume 'On' or event name

    // Skip until we find matching braces
    if check(p, .KW_EVENT) advance(p);

    // Skip event type
    while !check(p, .LBRACE) && !is_at_end(p) {
        advance(p);
    }

    if !check(p, .LBRACE) return true;

    // Match braces
    brace_count := 0;
    while !is_at_end(p) {
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
```

## String Helpers

```jai
// Extract content from "quoted string" -> quoted string
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

// Extract name from $"name" -> name
extract_res_ref_name :: (s: string) -> string {
    // Skip $" and trailing "
    if s.count < 3 return s;
    start := 0;
    if s[0] == #char "$" start = 1;
    if s[start] == #char "\"" start += 1;
    end := s.count;
    if s[end-1] == #char "\"" end -= 1;

    result: string;
    result.data = s.data + start;
    result.count = end - start;
    return result;
}

// Case-insensitive string compare
strings_equal_nocase :: (a: string, b: string) -> bool {
    if a.count != b.count return false;
    for i: 0..a.count-1 {
        ca := a[i];
        cb := b[i];
        if ca >= #char "a" && ca <= #char "z" ca -= 32;
        if cb >= #char "a" && cb <= #char "z" cb -= 32;
        if ca != cb return false;
    }
    return true;
}
```
