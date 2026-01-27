// Incursion Port - Resource File Lexer
// Reconstructed from RECONSTRUCTION-LEXER.md

TokenType :: enum u16 {
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
    COLON     :: 30;
    SEMICOLON :: 31;
    COMMA     :: 32;
    LBRACE    :: 33;
    RBRACE    :: 34;
    LPAREN    :: 35;
    RPAREN    :: 36;
    LBRACKET  :: 37;
    RBRACKET  :: 38;
    DOT       :: 39;

    // Operators (40-59)
    PLUS      :: 40;
    MINUS     :: 41;
    STAR      :: 42;
    SLASH     :: 43;
    PIPE      :: 44;
    AMPERSAND :: 45;
    TILDE     :: 46;
    BANG      :: 47;
    QUESTION  :: 48;
    LESS      :: 49;
    GREATER   :: 50;
    EQUAL     :: 51;
    CARET     :: 52;
    AT        :: 53;
    HASH      :: 54;
    SCOPE     :: 55;  // ::

    // Multi-char operators (60-89)
    INCREMENT  :: 60;  // ++
    DECREMENT  :: 61;  // --
    PLUS_EQ    :: 62;  // +=
    MINUS_EQ   :: 63;  // -=
    STAR_EQ    :: 64;  // *=
    SLASH_EQ   :: 65;  // /=
    ARROW      :: 66;  // ->
    EQ         :: 67;  // ==
    NEQ        :: 68;  // !=
    AND        :: 69;  // &&
    OR         :: 70;  // ||
    LEQ        :: 71;  // <=
    GEQ        :: 72;  // >=
    LSHIFT     :: 73;  // <<
    RSHIFT     :: 74;  // >>
    LSHIFT_EQ  :: 75;  // <<=
    RSHIFT_EQ  :: 76;  // >>=
    OR_EQ      :: 77;  // |=
    AND_EQ     :: 78;  // &=

    // Control flow keywords (100-119)
    KW_IF      :: 100;
    KW_ELSE    :: 101;
    KW_FOR     :: 102;
    KW_WHILE   :: 103;
    KW_RETURN  :: 104;
    KW_SWITCH  :: 105;
    KW_CASE    :: 106;
    KW_BREAK   :: 107;
    KW_DEFAULT :: 108;
    KW_DO      :: 109;
    KW_CONTINUE :: 110;

    // Resource keywords (200-229)
    KW_MONSTER :: 200;
    KW_ITEM    :: 201;
    KW_FLAVOR  :: 202;
    KW_EFFECT  :: 203;
    KW_SPELL   :: 204;
    KW_FEATURE :: 205;
    KW_TERRAIN :: 206;
    KW_RACE    :: 207;
    KW_CLASS   :: 208;
    KW_GOD     :: 209;
    KW_DOMAIN  :: 210;
    KW_DUNGEON :: 211;
    KW_ARTIFACT :: 212;
    KW_REGION  :: 213;
    KW_NPC     :: 214;
    KW_ENCOUNTER :: 215;
    KW_WIZARD  :: 216;
    KW_PRIEST  :: 217;
    KW_TEMPLATE :: 218;
    KW_TEXT    :: 219;
    KW_QUEST   :: 220;
    KW_BEHAVIOUR :: 221;
    KW_ROUTINE :: 222;
    KW_EVENT   :: 223;
    KW_ON      :: 224;

    // Property keywords (230-279)
    KW_IMAGE   :: 230;
    KW_LEVEL   :: 231;
    KW_HITDICE :: 232;
    KW_MAT     :: 233;
    KW_WEIGHT  :: 234;
    KW_SIZE    :: 235;
    KW_SDMG    :: 236;
    KW_ATTK    :: 237;
    KW_LDMG    :: 238;
    KW_DESC    :: 239;
    KW_FLAGS   :: 240;
    KW_CR      :: 241;
    KW_HP      :: 242;
    KW_MOV     :: 243;
    KW_SPD     :: 244;
    KW_HIT     :: 245;
    KW_DEF     :: 246;
    KW_ARM     :: 247;
    KW_MANA    :: 248;
    KW_ACC     :: 249;
    KW_CRIT    :: 250;
    KW_THREAT  :: 251;
    KW_SPEED   :: 252;
    KW_PARRY   :: 253;
    KW_RANGE   :: 254;
    KW_COVERAGE :: 255;
    KW_PENALTY :: 256;
    KW_COST    :: 257;
    KW_GROUP   :: 258;
    KW_NUTRITION :: 259;
    KW_DEPTH   :: 260;
    KW_RES     :: 261;
    KW_IMM     :: 262;
    KW_STATI   :: 263;
    KW_SOURCE  :: 264;
    KW_SOURCES :: 265;

    // Attribute keywords (280-289)
    KW_STR     :: 280;
    KW_DEX     :: 281;
    KW_CON     :: 282;
    KW_INT     :: 283;
    KW_WIS     :: 284;
    KW_CHA     :: 285;
    KW_LUC     :: 286;

    // Color keywords (310-329)
    KW_RED     :: 310;
    KW_BLUE    :: 311;
    KW_GREEN   :: 312;
    KW_WHITE   :: 313;
    KW_BLACK   :: 314;
    KW_YELLOW  :: 315;
    KW_PURPLE  :: 316;
    KW_CYAN    :: 317;
    KW_GREY    :: 318;
    KW_BROWN   :: 319;
    KW_PINK    :: 320;
    KW_SHADOW  :: 321;
    KW_MAGENTA :: 322;
    KW_SKY     :: 323;
    KW_AZURE   :: 324;
    KW_EMERALD :: 325;

    // Color modifiers (330-339)
    KW_BRIGHT  :: 330;
    KW_DARK    :: 331;
    KW_LIGHT   :: 332;

    // Effect keywords (350-359)
    KW_QVAL    :: 350;
    KW_XVAL    :: 351;
    KW_YVAL    :: 352;
    KW_PVAL    :: 353;
    KW_SCHOOLS :: 354;

    // Feature/Terrain keywords (360-369)
    KW_TARGET  :: 360;
    KW_CONSTANTS :: 361;
    KW_CVAL    :: 362;

    // Race/Class keywords (370-389)
    KW_GRANTS  :: 370;
    KW_FAVOURED :: 371;
    KW_SKILLS  :: 372;
    KW_LISTS   :: 373;
    KW_ABILITY :: 374;
    KW_FEAT    :: 375;
    KW_AT      :: 376;
    KW_EVERY   :: 377;
    KW_STARTING :: 378;
    KW_ND      :: 379;
    KW_RD      :: 380;
    KW_TH      :: 381;
    KW_ST      :: 382;
    KW_PROFICIENCIES :: 383;
    KW_GEAR    :: 384;
    KW_DOMAINS :: 385;
    KW_MALE_NAMES :: 386;
    KW_FEMALE_NAMES :: 387;
    KW_FAMILY_NAMES :: 388;
}

Token :: struct {
    type:      TokenType;
    text:      string;
    int_value: s64;    // For NUMBER, CONSTANT, PERCENT, CRIT_MULT
    line:      s32;
    column:    s32;
}

Lexer :: struct {
    source:      string;
    pos:         s64;
    line:        s32;
    column:      s32;
    brace_level: s32;   // Track { } depth for context-sensitive lexing
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

lexer_tokenize_all :: (lex: *Lexer) -> [..] Token {
    tokens: [..] Token;
    while true {
        tok := lexer_next_token(lex);
        array_add(*tokens, tok);
        if tok.type == .EOF break;
    }
    return tokens;
}

// Character helpers
is_at_end :: (lex: *Lexer) -> bool {
    return lex.pos >= lex.source.count;
}

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

lex_is_digit :: (c: u8) -> bool { return c >= #char "0" && c <= #char "9"; }
lex_is_alpha :: (c: u8) -> bool {
    return (c >= #char "a" && c <= #char "z") ||
           (c >= #char "A" && c <= #char "Z");
}
lex_is_alnum :: (c: u8) -> bool { return lex_is_alpha(c) || lex_is_digit(c); }
lex_is_upper :: (c: u8) -> bool { return c >= #char "A" && c <= #char "Z"; }
lex_is_hex_digit :: (c: u8) -> bool {
    return lex_is_digit(c) ||
           (c >= #char "a" && c <= #char "f") ||
           (c >= #char "A" && c <= #char "F");
}

make_token :: (lex: *Lexer, type: TokenType, text: string, start_line: s32, start_col: s32) -> Token {
    tok: Token;
    tok.type = type;
    tok.text = text;
    tok.line = start_line;
    tok.column = start_col;
    tok.int_value = 0;
    return tok;
}

// Use to_string from Basic module for substring views
slice :: (s: string, start: s64, length: s64) -> string {
    return to_string(s.data + start, length);
}

// Skip whitespace and comments
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

// Number parsing
parse_decimal :: (s: string) -> s64 {
    result: s64 = 0;
    for i: 0..s.count-1 {
        result = result * 10 + cast(s64)(s[i] - #char "0");
    }
    return result;
}

parse_hex :: (s: string) -> s64 {
    result: s64 = 0;
    start: s64 = 2;  // skip "0x"
    for i: start..s.count-1 {
        c := s[i];
        digit: s64;
        if c >= #char "0" && c <= #char "9" {
            digit = cast(s64)(c - #char "0");
        } else if c >= #char "a" && c <= #char "f" {
            digit = 10 + cast(s64)(c - #char "a");
        } else if c >= #char "A" && c <= #char "F" {
            digit = 10 + cast(s64)(c - #char "A");
        }
        result = result * 16 + digit;
    }
    return result;
}

// Scan functions
scan_number :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Check for hex
    if lex.source[start_pos] == #char "0" && peek_char(lex) == #char "x" {
        advance_char(lex);  // skip 'x'
        while lex_is_hex_digit(peek_char(lex)) {
            advance_char(lex);
        }
        text := slice(lex.source, start_pos, lex.pos - start_pos);
        tok := make_token(lex, .NUMBER, text, start_line, start_col);
        tok.int_value = parse_hex(text);
        return tok;
    }

    // Decimal
    while lex_is_digit(peek_char(lex)) {
        advance_char(lex);
    }

    // Check for % suffix
    if peek_char(lex) == #char "%" {
        text := slice(lex.source, start_pos, lex.pos - start_pos);
        advance_char(lex);  // skip %
        tok := make_token(lex, .PERCENT, text, start_line, start_col);
        tok.int_value = parse_decimal(text);
        return tok;
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);
    tok := make_token(lex, .NUMBER, text, start_line, start_col);
    tok.int_value = parse_decimal(text);
    return tok;
}

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
    return make_token(lex, .STRING, text, start_line, start_col);
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
    tok := make_token(lex, .CHAR_CONST, text, start_line, start_col);
    tok.int_value = char_val;
    return tok;
}

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
    } else if lex_is_digit(peek_char(lex)) {
        // $123
        while lex_is_digit(peek_char(lex)) {
            advance_char(lex);
        }
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);
    return make_token(lex, .RES_REF, text, start_line, start_col);
}

scan_crit_mult :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Already consumed 'x', now read digits
    while lex_is_digit(peek_char(lex)) {
        advance_char(lex);
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);

    // Extract multiplier value
    mult: s64 = 0;
    for i: 1..text.count-1 {  // skip 'x'
        mult = mult * 10 + cast(s64)(text[i] - #char "0");
    }

    tok := make_token(lex, .CRIT_MULT, text, start_line, start_col);
    tok.int_value = mult;
    return tok;
}

// Check if identifier is an uppercase constant pattern
lex_is_uppercase_constant :: (text: string) -> bool {
    if text.count < 2 return false;
    if !lex_is_upper(text[0]) return false;

    has_underscore := false;
    for i: 0..text.count-1 {
        c := text[i];
        if c == #char "_" {
            has_underscore = true;
        } else if !lex_is_upper(c) && !lex_is_digit(c) {
            return false;
        }
    }
    return has_underscore;
}

// Check if a constant is one of the names constants
is_names_constant :: (text: string) -> bool {
    if text.count < 10 return false;
    return text == "MALE_NAMES" ||
           text == "FEMALE_NAMES" ||
           text == "FAMILY_NAMES";
}

// strings_equal replaced with == operator (Jai compares string content)
// strings_equal_nocase kept for case-insensitive comparison (no stdlib equivalent)
strings_equal_nocase :: (a: string, b: string) -> bool {
    if a.count != b.count return false;
    for i: 0..a.count-1 {
        ca := a[i];
        cb := b[i];
        if ca >= #char "A" && ca <= #char "Z" ca += 32;
        if cb >= #char "A" && cb <= #char "Z" cb += 32;
        if ca != cb return false;
    }
    return true;
}

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
    if lower_str == "monster" return .KW_MONSTER;
    if lower_str == "item" return .KW_ITEM;
    if lower_str == "flavor" return .KW_FLAVOR;
    if lower_str == "effect" return .KW_EFFECT;
    if lower_str == "spell" return .KW_SPELL;
    if lower_str == "feature" return .KW_FEATURE;
    if lower_str == "terrain" return .KW_TERRAIN;
    if lower_str == "race" return .KW_RACE;
    if lower_str == "class" return .KW_CLASS;
    if lower_str == "god" return .KW_GOD;
    if lower_str == "domain" return .KW_DOMAIN;
    if lower_str == "dungeon" return .KW_DUNGEON;
    if lower_str == "artifact" return .KW_ARTIFACT;
    if lower_str == "region" return .KW_REGION;
    if lower_str == "npc" return .KW_NPC;
    if lower_str == "encounter" return .KW_ENCOUNTER;
    if lower_str == "wizard" return .KW_WIZARD;
    if lower_str == "priest" return .KW_PRIEST;
    if lower_str == "template" return .KW_TEMPLATE;
    if lower_str == "text" return .KW_TEXT;
    if lower_str == "quest" return .KW_QUEST;
    if lower_str == "behaviour" return .KW_BEHAVIOUR;
    if lower_str == "routine" return .KW_ROUTINE;
    if lower_str == "event" return .KW_EVENT;
    if lower_str == "on" return .KW_ON;

    // Property keywords
    if lower_str == "image" return .KW_IMAGE;
    if lower_str == "level" return .KW_LEVEL;
    if lower_str == "hitdice" || lower_str == "hd" return .KW_HITDICE;
    if lower_str == "mat" return .KW_MAT;
    if lower_str == "weight" return .KW_WEIGHT;
    if lower_str == "size" return .KW_SIZE;
    if lower_str == "sdmg" return .KW_SDMG;
    if lower_str == "attk" return .KW_ATTK;
    if lower_str == "ldmg" return .KW_LDMG;
    if lower_str == "desc" return .KW_DESC;
    if lower_str == "flags" return .KW_FLAGS;
    if lower_str == "cr" return .KW_CR;
    if lower_str == "hp" return .KW_HP;
    if lower_str == "mov" return .KW_MOV;
    if lower_str == "spd" return .KW_SPD;
    if lower_str == "hit" return .KW_HIT;
    if lower_str == "def" return .KW_DEF;
    if lower_str == "arm" return .KW_ARM;
    if lower_str == "mana" return .KW_MANA;
    if lower_str == "acc" return .KW_ACC;
    if lower_str == "crit" return .KW_CRIT;
    if lower_str == "threat" return .KW_THREAT;
    if lower_str == "speed" return .KW_SPEED;
    if lower_str == "parry" return .KW_PARRY;
    if lower_str == "range" return .KW_RANGE;
    if lower_str == "coverage" return .KW_COVERAGE;
    if lower_str == "penalty" return .KW_PENALTY;
    if lower_str == "cost" return .KW_COST;
    if lower_str == "group" return .KW_GROUP;
    if lower_str == "nutrition" return .KW_NUTRITION;
    if lower_str == "depth" return .KW_DEPTH;
    if lower_str == "res" return .KW_RES;
    if lower_str == "imm" return .KW_IMM;
    if lower_str == "stati" return .KW_STATI;
    if lower_str == "source" return .KW_SOURCE;
    if lower_str == "sources" return .KW_SOURCES;

    // Effect keywords
    if lower_str == "qval" return .KW_QVAL;
    if lower_str == "xval" return .KW_XVAL;
    if lower_str == "yval" return .KW_YVAL;
    if lower_str == "pval" return .KW_PVAL;
    if lower_str == "schools" return .KW_SCHOOLS;

    // Feature/Terrain keywords
    if lower_str == "target" return .KW_TARGET;
    if lower_str == "constants" return .KW_CONSTANTS;
    if lower_str == "cval" return .KW_CVAL;

    // Race/Class keywords
    if lower_str == "grants" return .KW_GRANTS;
    if lower_str == "favoured" || lower_str == "favored" return .KW_FAVOURED;
    if lower_str == "skills" return .KW_SKILLS;
    if lower_str == "lists" return .KW_LISTS;
    if lower_str == "ability" return .KW_ABILITY;
    if lower_str == "feat" return .KW_FEAT;
    if lower_str == "at" return .KW_AT;
    if lower_str == "every" return .KW_EVERY;
    if lower_str == "starting" return .KW_STARTING;
    if lower_str == "nd" return .KW_ND;
    if lower_str == "rd" return .KW_RD;
    if lower_str == "th" return .KW_TH;
    if lower_str == "st" return .KW_ST;
    if lower_str == "proficiencies" return .KW_PROFICIENCIES;
    if lower_str == "gear" return .KW_GEAR;
    if lower_str == "domains" return .KW_DOMAINS;

    // Color keywords
    if lower_str == "red" return .KW_RED;
    if lower_str == "blue" return .KW_BLUE;
    if lower_str == "green" return .KW_GREEN;
    if lower_str == "white" return .KW_WHITE;
    if lower_str == "black" return .KW_BLACK;
    if lower_str == "yellow" return .KW_YELLOW;
    if lower_str == "purple" return .KW_PURPLE;
    if lower_str == "cyan" return .KW_CYAN;
    if lower_str == "grey" || lower_str == "gray" return .KW_GREY;
    if lower_str == "brown" return .KW_BROWN;
    if lower_str == "pink" return .KW_PINK;
    if lower_str == "shadow" return .KW_SHADOW;
    if lower_str == "magenta" return .KW_MAGENTA;
    if lower_str == "sky" return .KW_SKY;
    if lower_str == "azure" return .KW_AZURE;
    if lower_str == "emerald" return .KW_EMERALD;
    if lower_str == "bright" return .KW_BRIGHT;
    if lower_str == "dark" return .KW_DARK;
    if lower_str == "light" return .KW_LIGHT;

    // Attribute keywords
    if lower_str == "str" return .KW_STR;
    if lower_str == "dex" return .KW_DEX;
    if lower_str == "con" return .KW_CON;
    if lower_str == "int" return .KW_INT;
    if lower_str == "wis" return .KW_WIS;
    if lower_str == "cha" return .KW_CHA;
    if lower_str == "luc" return .KW_LUC;

    // Control flow (only in code blocks)
    if in_code {
        if lower_str == "if" return .KW_IF;
        if lower_str == "else" return .KW_ELSE;
        if lower_str == "for" return .KW_FOR;
        if lower_str == "while" return .KW_WHILE;
        if lower_str == "return" return .KW_RETURN;
        if lower_str == "switch" return .KW_SWITCH;
        if lower_str == "case" return .KW_CASE;
        if lower_str == "break" return .KW_BREAK;
        if lower_str == "default" return .KW_DEFAULT;
        if lower_str == "do" return .KW_DO;
        if lower_str == "continue" return .KW_CONTINUE;
    }

    return .INVALID;
}

scan_identifier :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // Special case: 'd' followed by digit is dice notation
    if lex.source[start_pos] == #char "d" && lex_is_digit(peek_char(lex)) {
        text := slice(lex.source, start_pos, 1);
        return make_token(lex, .DICE_D, text, start_line, start_col);
    }

    // Consume identifier characters
    while !is_at_end(lex) {
        c := peek_char(lex);
        if lex_is_alnum(c) || c == #char "_" {
            advance_char(lex);
        } else {
            break;
        }
    }

    text := slice(lex.source, start_pos, lex.pos - start_pos);

    // Standalone 'd' is dice notation
    if text.count == 1 && text[0] == #char "d" {
        return make_token(lex, .DICE_D, text, start_line, start_col);
    }

    // Check for uppercase constant (T_WEAPON, MA_DRAGON, etc.)
    // But not MALE_NAMES, FEMALE_NAMES, FAMILY_NAMES which are keywords
    if lex_is_uppercase_constant(text) && !is_names_constant(text) {
        value, found := lookup_resource_constant(text);
        if found {
            tok := make_token(lex, .CONSTANT, text, start_line, start_col);
            tok.int_value = value;
            return tok;
        }
    }

    // Check for keyword
    kw_type := lookup_keyword(text, lex.brace_level >= 2);
    if kw_type != .INVALID {
        return make_token(lex, kw_type, text, start_line, start_col);
    }

    // Plain identifier
    return make_token(lex, .IDENTIFIER, text, start_line, start_col);
}

// Multi-character operator scanning
scan_plus :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "+" {
        advance_char(lex);
        return make_token(lex, .INCREMENT, "++", start_line, start_col);
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .PLUS_EQ, "+=", start_line, start_col);
    }
    return make_token(lex, .PLUS, "+", start_line, start_col);
}

scan_minus :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "-" {
        advance_char(lex);
        return make_token(lex, .DECREMENT, "--", start_line, start_col);
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .MINUS_EQ, "-=", start_line, start_col);
    }
    if peek_char(lex) == #char ">" {
        advance_char(lex);
        return make_token(lex, .ARROW, "->", start_line, start_col);
    }
    return make_token(lex, .MINUS, "-", start_line, start_col);
}

scan_star :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .STAR_EQ, "*=", start_line, start_col);
    }
    return make_token(lex, .STAR, "*", start_line, start_col);
}

scan_slash :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .SLASH_EQ, "/=", start_line, start_col);
    }
    return make_token(lex, .SLASH, "/", start_line, start_col);
}

scan_pipe :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "|" {
        advance_char(lex);
        return make_token(lex, .OR, "||", start_line, start_col);
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .OR_EQ, "|=", start_line, start_col);
    }
    return make_token(lex, .PIPE, "|", start_line, start_col);
}

scan_ampersand :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "&" {
        advance_char(lex);
        return make_token(lex, .AND, "&&", start_line, start_col);
    }
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .AND_EQ, "&=", start_line, start_col);
    }
    return make_token(lex, .AMPERSAND, "&", start_line, start_col);
}

scan_equal :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .EQ, "==", start_line, start_col);
    }
    return make_token(lex, .EQUAL, "=", start_line, start_col);
}

scan_bang :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .NEQ, "!=", start_line, start_col);
    }
    return make_token(lex, .BANG, "!", start_line, start_col);
}

scan_less :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .LEQ, "<=", start_line, start_col);
    }
    if peek_char(lex) == #char "<" {
        advance_char(lex);
        if peek_char(lex) == #char "=" {
            advance_char(lex);
            return make_token(lex, .LSHIFT_EQ, "<<=", start_line, start_col);
        }
        return make_token(lex, .LSHIFT, "<<", start_line, start_col);
    }
    return make_token(lex, .LESS, "<", start_line, start_col);
}

scan_greater :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .GEQ, ">=", start_line, start_col);
    }
    if peek_char(lex) == #char ">" {
        advance_char(lex);
        if peek_char(lex) == #char "=" {
            advance_char(lex);
            return make_token(lex, .RSHIFT_EQ, ">>=", start_line, start_col);
        }
        return make_token(lex, .RSHIFT, ">>", start_line, start_col);
    }
    return make_token(lex, .GREATER, ">", start_line, start_col);
}

scan_colon :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char ":" {
        advance_char(lex);
        return make_token(lex, .SCOPE, "::", start_line, start_col);
    }
    return make_token(lex, .COLON, ":", start_line, start_col);
}

// Main tokenization function
lexer_next_token :: (lex: *Lexer) -> Token {
    skip_whitespace_and_comments(lex);

    if is_at_end(lex) {
        return make_token(lex, .EOF, "", lex.line, lex.column);
    }

    start_pos := lex.pos;
    start_line := lex.line;
    start_col := lex.column;

    c := advance_char(lex);

    // Single character tokens
    if c == #char ":" return scan_colon(lex, start_line, start_col);
    if c == #char ";" return make_token(lex, .SEMICOLON, ";", start_line, start_col);
    if c == #char "," return make_token(lex, .COMMA, ",", start_line, start_col);
    if c == #char "{" {
        lex.brace_level += 1;
        return make_token(lex, .LBRACE, "{", start_line, start_col);
    }
    if c == #char "}" {
        lex.brace_level -= 1;
        return make_token(lex, .RBRACE, "}", start_line, start_col);
    }
    if c == #char "(" return make_token(lex, .LPAREN, "(", start_line, start_col);
    if c == #char ")" return make_token(lex, .RPAREN, ")", start_line, start_col);
    if c == #char "[" return make_token(lex, .LBRACKET, "[", start_line, start_col);
    if c == #char "]" return make_token(lex, .RBRACKET, "]", start_line, start_col);
    if c == #char "." return make_token(lex, .DOT, ".", start_line, start_col);
    if c == #char "*" return scan_star(lex, start_line, start_col);
    if c == #char "/" return scan_slash(lex, start_line, start_col);
    if c == #char "+" return scan_plus(lex, start_line, start_col);
    if c == #char "-" return scan_minus(lex, start_line, start_col);
    if c == #char "|" return scan_pipe(lex, start_line, start_col);
    if c == #char "&" return scan_ampersand(lex, start_line, start_col);
    if c == #char "~" return make_token(lex, .TILDE, "~", start_line, start_col);
    if c == #char "!" return scan_bang(lex, start_line, start_col);
    if c == #char "?" return make_token(lex, .QUESTION, "?", start_line, start_col);
    if c == #char "<" return scan_less(lex, start_line, start_col);
    if c == #char ">" return scan_greater(lex, start_line, start_col);
    if c == #char "=" return scan_equal(lex, start_line, start_col);
    if c == #char "^" return make_token(lex, .CARET, "^", start_line, start_col);
    if c == #char "@" return make_token(lex, .AT, "@", start_line, start_col);
    if c == #char "#" return make_token(lex, .HASH, "#", start_line, start_col);
    if c == #char "$" return scan_res_ref(lex, start_pos, start_line, start_col);
    if c == #char "\"" return scan_string(lex, start_pos, start_line, start_col);
    if c == #char "'" return scan_char(lex, start_pos, start_line, start_col);

    // Numbers
    if lex_is_digit(c) {
        return scan_number(lex, start_pos, start_line, start_col);
    }

    // Identifiers, keywords, constants
    if lex_is_alpha(c) || c == #char "_" {
        // Special case: 'x' followed by digit = crit mult
        if c == #char "x" && lex_is_digit(peek_char(lex)) {
            return scan_crit_mult(lex, start_pos, start_line, start_col);
        }
        return scan_identifier(lex, start_pos, start_line, start_col);
    }

    // Unknown character
    return make_token(lex, .INVALID, slice(lex.source, start_pos, 1), start_line, start_col);
}
