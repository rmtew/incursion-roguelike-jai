# Lexer Implementation Details

## Lexer Struct

```jai
Lexer :: struct {
    source:      string;
    pos:         s64;
    line:        s32;
    column:      s32;
    brace_level: s32;   // Track { } depth for context-sensitive lexing
}

Token :: struct {
    type:        TokenType;
    text:        string;
    int_value:   s64;    // For NUMBER, CONSTANT, PERCENT, CRIT_MULT
    line:        s32;
    column:      s32;
}

lexer_init :: (source: string) -> Lexer {
    lex: Lexer;
    lex.source = source;
    lex.pos = 0;
    lex.line = 1;
    lex.column = 1;
    lex.brace_level = 0;
    return lex;
}

lexer_free :: (lex: *Lexer) {
    // Nothing to free - strings are views into source
}

lexer_tokenize_all :: (lex: *Lexer) -> [] Token {
    tokens: [..] Token;
    while true {
        tok := lexer_next_token(lex);
        array_add(*tokens, tok);
        if tok.type == .EOF break;
    }
    return tokens;
}
```

## Main Tokenization Loop

```jai
lexer_next_token :: (lex: *Lexer) -> Token {
    skip_whitespace_and_comments(lex);

    if is_at_end(lex) {
        return make_token(lex, .EOF, "");
    }

    start_pos := lex.pos;
    start_line := lex.line;
    start_col := lex.column;

    c := advance_char(lex);

    // Single character tokens
    if c == {
        case #char ":";
            if peek_char(lex) == #char ":" {
                advance_char(lex);
                return make_token(lex, .SCOPE, "::");
            }
            return make_token(lex, .COLON, ":");
        case #char ";"; return make_token(lex, .SEMICOLON, ";");
        case #char ","; return make_token(lex, .COMMA, ",");
        case #char "{";
            lex.brace_level += 1;
            return make_token(lex, .LBRACE, "{");
        case #char "}";
            lex.brace_level -= 1;
            return make_token(lex, .RBRACE, "}");
        case #char "("; return make_token(lex, .LPAREN, "(");
        case #char ")"; return make_token(lex, .RPAREN, ")");
        case #char "["; return make_token(lex, .LBRACKET, "[");
        case #char "]"; return make_token(lex, .RBRACKET, "]");
        case #char "."; return make_token(lex, .DOT, ".");
        case #char "*"; return scan_star_or_eq(lex, start_pos);
        case #char "/"; return scan_slash_or_eq(lex, start_pos);
        case #char "+"; return scan_plus(lex, start_pos);
        case #char "-"; return scan_minus(lex, start_pos);
        case #char "|"; return scan_pipe(lex, start_pos);
        case #char "&"; return scan_ampersand(lex, start_pos);
        case #char "~"; return make_token(lex, .TILDE, "~");
        case #char "!"; return scan_bang(lex, start_pos);
        case #char "?"; return make_token(lex, .QUESTION, "?");
        case #char "<"; return scan_less(lex, start_pos);
        case #char ">"; return scan_greater(lex, start_pos);
        case #char "="; return scan_equal(lex, start_pos);
        case #char "^"; return make_token(lex, .CARET, "^");
        case #char "@"; return make_token(lex, .AT, "@");
        case #char "#"; return make_token(lex, .HASH, "#");
        case #char "$"; return scan_res_ref(lex, start_pos, start_line, start_col);
        case #char "\""; return scan_string(lex, start_pos, start_line, start_col);
        case #char "'"; return scan_char(lex, start_pos, start_line, start_col);
    }

    // Numbers
    if is_digit(c) {
        return scan_number(lex, start_pos, start_line, start_col);
    }

    // Identifiers, keywords, constants
    if is_alpha(c) || c == #char "_" {
        // Special case: 'x' followed by digit = crit mult
        if c == #char "x" && is_digit(peek_char(lex)) {
            return scan_crit_mult(lex, start_pos, start_line, start_col);
        }
        return scan_identifier(lex, start_pos, start_line, start_col);
    }

    // Unknown character
    return make_token(lex, .INVALID, slice(lex.source, start_pos, 1));
}
```

## Character Helpers

```jai
is_at_end :: (lex: *Lexer) -> bool { return lex.pos >= lex.source.count; }

peek_char :: (lex: *Lexer) -> u8 {
    if is_at_end(lex) return 0;
    return lex.source[lex.pos];
}

peek_next :: (lex: *Lexer) -> u8 {
    if lex.pos + 1 >= lex.source.count return 0;
    return lex.source[lex.pos + 1];
}

advance_char :: (lex: *Lexer) -> u8 {
    c := lex.source[lex.pos];
    lex.pos += 1;
    if c == #char "\n" {
        lex.line += 1;
        lex.column = 1;
    } else {
        lex.column += 1;
    }
    return c;
}

is_digit :: (c: u8) -> bool { return c >= #char "0" && c <= #char "9"; }
is_alpha :: (c: u8) -> bool {
    return (c >= #char "a" && c <= #char "z") ||
           (c >= #char "A" && c <= #char "Z");
}
is_alnum :: (c: u8) -> bool { return is_alpha(c) || is_digit(c); }
is_upper :: (c: u8) -> bool { return c >= #char "A" && c <= #char "Z"; }

make_token :: (lex: *Lexer, type: TokenType, text: string) -> Token {
    tok: Token;
    tok.type = type;
    tok.text = text;
    tok.line = lex.line;
    tok.column = lex.column;
    return tok;
}

slice :: (s: string, start: s64, length: s64) -> string {
    result: string;
    result.data = s.data + start;
    result.count = length;
    return result;
}
```

## Whitespace and Comments

```jai
skip_whitespace_and_comments :: (lex: *Lexer) {
    while !is_at_end(lex) {
        c := peek_char(lex);

        // Whitespace
        if c == #char " " || c == #char "\t" || c == #char "\r" || c == #char "\n" {
            advance_char(lex);
            continue;
        }

        // Line comment //
        if c == #char "/" && peek_next(lex) == #char "/" {
            while !is_at_end(lex) && peek_char(lex) != #char "\n" {
                advance_char(lex);
            }
            continue;
        }

        // Block comment /* */
        if c == #char "/" && peek_next(lex) == #char "*" {
            advance_char(lex);  // skip /
            advance_char(lex);  // skip *
            while !is_at_end(lex) {
                if peek_char(lex) == #char "*" && peek_next(lex) == #char "/" {
                    advance_char(lex);
                    advance_char(lex);
                    break;
                }
                advance_char(lex);
            }
            continue;
        }

        break;
    }
}
```

## Number Scanning

```jai
scan_number :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Check for hex
    if lex.source[start_pos] == #char "0" && peek_char(lex) == #char "x" {
        advance_char(lex);  // skip 'x'
        while is_hex_digit(peek_char(lex)) {
            advance_char(lex);
        }
        text := slice(lex.source, start_pos, lex.pos - start_pos);
        tok := make_token(lex, .NUMBER, text);
        tok.int_value = parse_hex(text);
        tok.line = start_line;
        tok.column = start_col;
        return tok;
    }

    // Decimal
    while is_digit(peek_char(lex)) {
        advance_char(lex);
    }

    // Check for % suffix
    if peek_char(lex) == #char "%" {
        text := slice(lex.source, start_pos, lex.pos - start_pos);
        advance_char(lex);  // skip %
        tok := make_token(lex, .PERCENT, text);
        tok.int_value = parse_decimal(text);
        tok.line = start_line;
        tok.column = start_col;
        return tok;
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);
    tok := make_token(lex, .NUMBER, text);
    tok.int_value = parse_decimal(text);
    tok.line = start_line;
    tok.column = start_col;
    return tok;
}

is_hex_digit :: (c: u8) -> bool {
    return is_digit(c) ||
           (c >= #char "a" && c <= #char "f") ||
           (c >= #char "A" && c <= #char "F");
}

parse_decimal :: (s: string) -> s64 {
    result: s64 = 0;
    for i: 0..s.count-1 {
        result = result * 10 + (s[i] - #char "0");
    }
    return result;
}

parse_hex :: (s: string) -> s64 {
    result: s64 = 0;
    start := 2;  // skip "0x"
    for i: start..s.count-1 {
        c := s[i];
        digit: s64;
        if c >= #char "0" && c <= #char "9" {
            digit = c - #char "0";
        } else if c >= #char "a" && c <= #char "f" {
            digit = 10 + (c - #char "a");
        } else if c >= #char "A" && c <= #char "F" {
            digit = 10 + (c - #char "A");
        }
        result = result * 16 + digit;
    }
    return result;
}
```

## String and Character Scanning

```jai
scan_string :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Already consumed opening "
    while !is_at_end(lex) && peek_char(lex) != #char "\"" {
        if peek_char(lex) == #char "\\" && peek_next(lex) == #char "\"" {
            advance_char(lex);  // skip backslash
        }
        advance_char(lex);
    }

    if !is_at_end(lex) {
        advance_char(lex);  // closing "
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);
    tok := make_token(lex, .STRING, text);
    tok.line = start_line;
    tok.column = start_col;
    return tok;
}

scan_char :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Already consumed opening '
    char_val: s64 = 0;

    c := peek_char(lex);
    if c == #char "\\" {
        advance_char(lex);
        c = peek_char(lex);
        if c == #char "n" char_val = 10;      // newline
        else if c == #char "t" char_val = 9;   // tab
        else if c == #char "r" char_val = 13;  // carriage return
        else if c == #char "\\" char_val = #char "\\";
        else if c == #char "'" char_val = #char "'";
        else char_val = c;
        advance_char(lex);
    } else {
        char_val = c;
        advance_char(lex);
    }

    if peek_char(lex) == #char "'" {
        advance_char(lex);  // closing '
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);
    tok := make_token(lex, .CHAR_CONST, text);
    tok.int_value = char_val;
    tok.line = start_line;
    tok.column = start_col;
    return tok;
}
```

## Resource Reference Scanning

```jai
scan_res_ref :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Already consumed $
    if peek_char(lex) == #char "\"" {
        // $"name"
        advance_char(lex);  // skip "
        while !is_at_end(lex) && peek_char(lex) != #char "\"" {
            advance_char(lex);
        }
        if !is_at_end(lex) {
            advance_char(lex);  // closing "
        }
    } else if is_digit(peek_char(lex)) {
        // $123
        while is_digit(peek_char(lex)) {
            advance_char(lex);
        }
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);
    tok := make_token(lex, .RES_REF, text);
    tok.line = start_line;
    tok.column = start_col;
    return tok;
}
```

## Critical Multiplier Scanning

```jai
scan_crit_mult :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Already consumed 'x', now read digits
    while is_digit(peek_char(lex)) {
        advance_char(lex);
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);

    // Extract multiplier value
    mult: s64 = 0;
    for i: 1..text.count-1 {  // skip 'x'
        mult = mult * 10 + (text[i] - #char "0");
    }

    tok := make_token(lex, .CRIT_MULT, text);
    tok.int_value = mult;
    tok.line = start_line;
    tok.column = start_col;
    return tok;
}
```

## Identifier and Keyword Scanning

```jai
scan_identifier :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Special case: 'd' followed by digit is dice notation
    if lex.source[start_pos] == #char "d" && is_digit(peek_char(lex)) {
        text := slice(lex.source, start_pos, 1);
        tok := make_token(lex, .DICE_D, text);
        tok.line = start_line;
        tok.column = start_col;
        return tok;
    }

    // Consume identifier characters
    while !is_at_end(lex) {
        c := peek_char(lex);
        if is_alnum(c) || c == #char "_" {
            advance_char(lex);
        } else {
            break;
        }
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);

    // Standalone 'd' is dice notation
    if text.count == 1 && text[0] == #char "d" {
        tok := make_token(lex, .DICE_D, text);
        tok.line = start_line;
        tok.column = start_col;
        return tok;
    }

    // Check for uppercase constant (T_WEAPON, MA_DRAGON, etc.)
    if is_uppercase_constant(text) {
        value, found := lookup_resource_constant(text);
        if found {
            tok := make_token(lex, .CONSTANT, text);
            tok.int_value = value;
            tok.line = start_line;
            tok.column = start_col;
            return tok;
        }
    }

    // Check for keyword
    kw_type := lookup_keyword(text, lex.brace_level >= 2);
    if kw_type != .INVALID {
        tok := make_token(lex, kw_type, text);
        tok.line = start_line;
        tok.column = start_col;
        return tok;
    }

    // Plain identifier
    tok := make_token(lex, .IDENTIFIER, text);
    tok.line = start_line;
    tok.column = start_col;
    return tok;
}

is_uppercase_constant :: (text: string) -> bool {
    if text.count < 3 return false;
    if !is_upper(text[0]) return false;

    has_underscore := false;
    for i: 0..text.count-1 {
        c := text[i];
        if c == #char "_" {
            has_underscore = true;
        } else if !is_upper(c) && !is_digit(c) {
            return false;
        }
    }
    return has_underscore;
}
```

## Keyword Lookup

```jai
lookup_keyword :: (text: string, in_code: bool) -> TokenType {
    // Convert to lowercase for comparison
    lower: [64] u8;
    len := min(text.count, 63);
    for i: 0..len-1 {
        c := text[i];
        if c >= #char "A" && c <= #char "Z" {
            lower[i] = c + 32;
        } else {
            lower[i] = c;
        }
    }
    lower_str: string;
    lower_str.data = lower.data;
    lower_str.count = len;

    // Resource keywords
    if strings_equal(lower_str, "monster") return .KW_MONSTER;
    if strings_equal(lower_str, "item") return .KW_ITEM;
    if strings_equal(lower_str, "flavor") return .KW_FLAVOR;
    if strings_equal(lower_str, "effect") return .KW_EFFECT;
    if strings_equal(lower_str, "spell") return .KW_SPELL;
    if strings_equal(lower_str, "feature") return .KW_FEATURE;
    if strings_equal(lower_str, "terrain") return .KW_TERRAIN;
    if strings_equal(lower_str, "race") return .KW_RACE;
    if strings_equal(lower_str, "class") return .KW_CLASS;
    if strings_equal(lower_str, "god") return .KW_GOD;
    if strings_equal(lower_str, "domain") return .KW_DOMAIN;

    // Property keywords
    if strings_equal(lower_str, "image") return .KW_IMAGE;
    if strings_equal(lower_str, "level") return .KW_LEVEL;
    if strings_equal(lower_str, "hitdice") || strings_equal(lower_str, "hd") return .KW_HITDICE;
    if strings_equal(lower_str, "mat") return .KW_MAT;
    if strings_equal(lower_str, "weight") return .KW_WEIGHT;
    if strings_equal(lower_str, "size") return .KW_SIZE;
    if strings_equal(lower_str, "desc") return .KW_DESC;
    if strings_equal(lower_str, "flags") return .KW_FLAGS;
    if strings_equal(lower_str, "cr") return .KW_CR;
    if strings_equal(lower_str, "hp") return .KW_HP;
    if strings_equal(lower_str, "mov") return .KW_MOV;
    if strings_equal(lower_str, "spd") return .KW_SPD;
    if strings_equal(lower_str, "hit") return .KW_HIT;
    if strings_equal(lower_str, "def") return .KW_DEF;
    if strings_equal(lower_str, "arm") return .KW_ARM;
    if strings_equal(lower_str, "mana") return .KW_MANA;
    if strings_equal(lower_str, "attk") return .KW_ATTK;
    // ... many more

    // Effect keywords
    if strings_equal(lower_str, "qval") return .KW_QVAL;
    if strings_equal(lower_str, "xval") return .KW_XVAL;
    if strings_equal(lower_str, "yval") return .KW_YVAL;
    if strings_equal(lower_str, "pval") return .KW_PVAL;
    if strings_equal(lower_str, "schools") return .KW_SCHOOLS;

    // Race/Class keywords
    if strings_equal(lower_str, "grants") return .KW_GRANTS;
    if strings_equal(lower_str, "favoured") || strings_equal(lower_str, "favored") return .KW_FAVOURED;
    if strings_equal(lower_str, "skills") return .KW_SKILLS;
    if strings_equal(lower_str, "lists") return .KW_LISTS;
    if strings_equal(lower_str, "ability") return .KW_ABILITY;
    if strings_equal(lower_str, "feat") return .KW_FEAT;
    if strings_equal(lower_str, "at") return .KW_AT;
    if strings_equal(lower_str, "every") return .KW_EVERY;
    if strings_equal(lower_str, "starting") return .KW_STARTING;
    if strings_equal(lower_str, "proficiencies") return .KW_PROFICIENCIES;
    if strings_equal(lower_str, "gear") return .KW_GEAR;
    if strings_equal(lower_str, "domains") return .KW_DOMAINS;

    // Color keywords
    if strings_equal(lower_str, "red") return .KW_RED;
    if strings_equal(lower_str, "blue") return .KW_BLUE;
    if strings_equal(lower_str, "green") return .KW_GREEN;
    if strings_equal(lower_str, "white") return .KW_WHITE;
    if strings_equal(lower_str, "black") return .KW_BLACK;
    if strings_equal(lower_str, "yellow") return .KW_YELLOW;
    if strings_equal(lower_str, "purple") return .KW_PURPLE;
    if strings_equal(lower_str, "cyan") return .KW_CYAN;
    if strings_equal(lower_str, "grey") || strings_equal(lower_str, "gray") return .KW_GREY;
    if strings_equal(lower_str, "brown") return .KW_BROWN;
    if strings_equal(lower_str, "pink") return .KW_PINK;
    if strings_equal(lower_str, "shadow") return .KW_SHADOW;
    if strings_equal(lower_str, "bright") return .KW_BRIGHT;
    if strings_equal(lower_str, "dark") return .KW_DARK;
    if strings_equal(lower_str, "light") return .KW_LIGHT;

    // Attribute keywords
    if strings_equal(lower_str, "str") return .KW_STR;
    if strings_equal(lower_str, "dex") return .KW_DEX;
    if strings_equal(lower_str, "con") return .KW_CON;
    if strings_equal(lower_str, "int") return .KW_INT;
    if strings_equal(lower_str, "wis") return .KW_WIS;
    if strings_equal(lower_str, "cha") return .KW_CHA;
    if strings_equal(lower_str, "luc") return .KW_LUC;

    // Control flow (only in code blocks)
    if in_code {
        if strings_equal(lower_str, "if") return .KW_IF;
        if strings_equal(lower_str, "else") return .KW_ELSE;
        if strings_equal(lower_str, "for") return .KW_FOR;
        if strings_equal(lower_str, "while") return .KW_WHILE;
        if strings_equal(lower_str, "return") return .KW_RETURN;
        if strings_equal(lower_str, "switch") return .KW_SWITCH;
        if strings_equal(lower_str, "case") return .KW_CASE;
        if strings_equal(lower_str, "break") return .KW_BREAK;
    }

    return .INVALID;
}

strings_equal :: (a: string, b: string) -> bool {
    if a.count != b.count return false;
    for i: 0..a.count-1 {
        if a[i] != b[i] return false;
    }
    return true;
}
```

## Multi-Character Operator Scanning

```jai
scan_plus :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "+" {
        advance_char(lex);
        return make_token(lex, .INCREMENT, "++");
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .PLUS_EQ, "+=");
    }
    return make_token(lex, .PLUS, "+");
}

scan_minus :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "-" {
        advance_char(lex);
        return make_token(lex, .DECREMENT, "--");
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .MINUS_EQ, "-=");
    }
    if peek_char(lex) == #char ">" {
        advance_char(lex);
        return make_token(lex, .ARROW, "->");
    }
    return make_token(lex, .MINUS, "-");
}

scan_pipe :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "|" {
        advance_char(lex);
        return make_token(lex, .OR, "||");
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .OR_EQ, "|=");
    }
    return make_token(lex, .PIPE, "|");
}

scan_ampersand :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "&" {
        advance_char(lex);
        return make_token(lex, .AND, "&&");
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .AND_EQ, "&=");
    }
    return make_token(lex, .AMPERSAND, "&");
}

scan_equal :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .EQ, "==");
    }
    return make_token(lex, .EQUAL, "=");
}

scan_bang :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .NEQ, "!=");
    }
    return make_token(lex, .BANG, "!");
}

scan_less :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .LEQ, "<=");
    }
    if peek_char(lex) == #char "<" {
        advance_char(lex);
        if peek_char(lex) == #char "=" {
            advance_char(lex);
            return make_token(lex, .LSHIFT_EQ, "<<=");
        }
        return make_token(lex, .LSHIFT, "<<");
    }
    return make_token(lex, .LESS, "<");
}

scan_greater :: (lex: *Lexer, start_pos: s64) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .GEQ, ">=");
    }
    if peek_char(lex) == #char ">" {
        advance_char(lex);
        if peek_char(lex) == #char "=" {
            advance_char(lex);
            return make_token(lex, .RSHIFT_EQ, ">>=");
        }
        return make_token(lex, .RSHIFT, ">>");
    }
    return make_token(lex, .GREATER, ">");
}
```
