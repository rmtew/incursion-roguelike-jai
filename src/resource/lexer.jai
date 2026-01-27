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
    MODULO      :: 24;   // % operator

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
    MOD_EQ     :: 79;  // %=
    TILDE_EQ   :: 80;  // ~=
    ELLIPSIS   :: 81;  // ...

    // Semantic token types (90-99) - carry values
    ATTRIBUTE  :: 90;  // Str, Dex, etc. - int_value = A_STR, A_DEX, etc.
    COLOR      :: 91;  // red, blue, etc. - int_value = color constant
    DIRECTION  :: 92;  // North, South, etc. - int_value = direction constant
    WEP_TYPE   :: 93;  // slash, pierce, blunt - int_value = SLASH, PIERCE, BLUNT
    STYPE      :: 94;  // fort, ref, will - int_value = FORT, REF, WILL
    MAPAREA    :: 95;  // Map grid data from {:...:} block

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

    // Type keywords (120-139) - Keywords1
    KW_VOID    :: 120;
    KW_BOOL    :: 121;
    KW_INT8    :: 122;
    KW_INT16   :: 123;
    KW_INT32   :: 124;
    KW_UINT8   :: 125;
    KW_UINT16  :: 126;
    KW_HOBJ    :: 127;
    KW_HTEXT   :: 128;
    KW_RID     :: 129;
    KW_STRING_TYPE :: 130;  // "string" as type (not literal)
    KW_RECT    :: 131;

    // Special words (140-159) - Keywords1
    KW_ABS     :: 140;
    KW_MEMBER  :: 141;
    KW_STATIC  :: 142;
    KW_TRUE    :: 143;
    KW_FALSE   :: 144;
    KW_NULL    :: 145;
    KW_MAX     :: 146;
    KW_MIN     :: 147;

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

    // Additional keywords (390-449)
    KW_POISON   :: 390;
    KW_DISEASE  :: 391;
    KW_SPELLS   :: 392;
    KW_FLOOR    :: 393;
    KW_PARTS    :: 394;
    KW_ALIGN    :: 395;
    KW_FEATS    :: 396;
    KW_POWER    :: 397;
    KW_SPECIALS :: 398;
    KW_MTYPE    :: 399;
    KW_IMMUNE   :: 400;

    // More Keywords2 (410-449)
    KW_GLYPH    :: 410;
    KW_VALUE    :: 411;
    KW_TYPE     :: 412;
    KW_DAY      :: 413;
    KW_WEEK     :: 414;
    KW_TILE     :: 415;
    KW_TILES    :: 416;
    KW_ALL      :: 417;
    KW_ALSO     :: 418;
    KW_AND      :: 419;
    KW_OR_KW    :: 420;  // "Or" keyword (distinct from || operator)
    KW_WITH     :: 421;
    KW_OF       :: 422;
    KW_FROM     :: 423;
    KW_TO       :: 424;
    KW_PER      :: 425;
    KW_FOR_KW   :: 426;  // "For" keyword in data (distinct from for loop)
    KW_INNATE   :: 427;
    KW_INVOKE   :: 428;
    KW_BASE     :: 429;
    KW_CHANCE   :: 430;
    KW_WALLS    :: 431;
    KW_DOOR     :: 432;
    KW_GRID     :: 433;
    KW_OBJECTS  :: 434;
    KW_OBJECT   :: 435;
    KW_EQUIP    :: 436;
    KW_WIELD    :: 437;
    KW_MODULE   :: 438;
    KW_SLOT     :: 439;
    KW_FILE     :: 440;
    KW_CASTER   :: 441;
    KW_RANDOM   :: 442;
    KW_AS       :: 443;
    KW_NEAR     :: 444;
    KW_NONE     :: 445;
    KW_NORMAL   :: 446;
    KW_PARTIAL  :: 447;
    KW_TURNS    :: 448;
    KW_TIMEOUT  :: 449;

    // Effect value keywords (450-469)
    KW_SVAL     :: 450;
    KW_DVAL     :: 451;
    KW_AVAL     :: 452;
    KW_LVAL     :: 453;
    KW_TVAL     :: 454;
    KW_RVAL     :: 455;
    KW_EVAL     :: 456;
    KW_PURPOSE  :: 457;

    // Item/container keywords (470-489)
    KW_LIFESPAN :: 470;
    KW_FUEL     :: 471;
    KW_CAPACITY :: 472;
    KW_WEIGHTLIM :: 473;
    KW_WEIGHTMOD :: 474;
    KW_MAXSIZE  :: 475;
    KW_CTYPE    :: 476;
    KW_FIRES    :: 477;
    KW_HITPOINTS :: 478;

    // Combat keywords (490-509)
    KW_MELEE    :: 490;
    KW_ARCHERY  :: 491;
    KW_BRAWL    :: 492;
    KW_THROWING :: 493;
    KW_HEAVY    :: 494;
    KW_SAVES    :: 495;
    KW_DMG      :: 496;
    KW_DC       :: 497;

    // Misc keywords (510-529)
    KW_CURSED   :: 510;
    KW_BLESSED  :: 511;
    KW_QUALITIES :: 512;
    KW_SUSTAINS :: 513;
    KW_RESISTS  :: 514;
    KW_EXPORT   :: 515;
    KW_STOCK    :: 516;
    KW_STORE    :: 517;
    KW_GUILD    :: 518;
    KW_ROOMTYPES :: 519;
    KW_REGIONS  :: 520;
    KW_ANY      :: 521;
    KW_COLOUR   :: 522;  // British spelling
    KW_MATERIAL :: 523;
    KW_MOVE     :: 524;
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
    grid_mode:   bool;  // Set after seeing Grid: to handle {: map grid :}
}

lexer_init :: (source: string) -> Lexer {
    lex: Lexer;
    lex.source = source;
    lex.pos = 0;
    lex.line = 1;
    lex.column = 1;
    lex.brace_level = 0;
    lex.grid_mode = false;
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

        // Preprocessor directives (#if, #endif, #define, etc.)
        if c == #char "#" {
            // Check for #if 0 ... #endif block to skip entirely
            if match_preprocessor_if_zero(lex) {
                skip_preprocessor_if_block(lex);
                continue;
            }
            // Skip other preprocessor lines (#define, #include, etc.)
            while !is_at_end(lex) && peek_char(lex) != #char "\n" {
                advance_char(lex);
            }
            continue;
        }

        break;
    }
}

// Check if we're at "#if 0" (with optional whitespace)
match_preprocessor_if_zero :: (lex: *Lexer) -> bool {
    if is_at_end(lex) || lex.source[lex.pos] != #char "#" return false;

    // Save position to restore if not matched
    save_pos := lex.pos;
    save_line := lex.line;
    save_col := lex.column;

    advance_char(lex);  // skip #

    // Skip whitespace
    while !is_at_end(lex) && (peek_char(lex) == #char " " || peek_char(lex) == #char "\t") {
        advance_char(lex);
    }

    // Check for "if"
    if lex.pos + 2 <= lex.source.count &&
       lex.source[lex.pos] == #char "i" &&
       lex.source[lex.pos + 1] == #char "f" {
        advance_char(lex);
        advance_char(lex);

        // Skip whitespace
        while !is_at_end(lex) && (peek_char(lex) == #char " " || peek_char(lex) == #char "\t") {
            advance_char(lex);
        }

        // Check for "0"
        if !is_at_end(lex) && peek_char(lex) == #char "0" {
            advance_char(lex);
            // Skip to end of line
            while !is_at_end(lex) && peek_char(lex) != #char "\n" {
                advance_char(lex);
            }
            return true;
        }
    }

    // Not #if 0, restore position
    lex.pos = save_pos;
    lex.line = save_line;
    lex.column = save_col;
    return false;
}

// Skip until matching #endif (handles nested #if/#endif)
skip_preprocessor_if_block :: (lex: *Lexer) {
    nesting := 1;

    while !is_at_end(lex) && nesting > 0 {
        c := peek_char(lex);

        if c == #char "\n" {
            lex.line += 1;
            lex.column = 0;
            advance_char(lex);
            continue;
        }

        if c == #char "#" {
            // Check for #if or #endif
            save_pos := lex.pos;

            advance_char(lex);

            // Skip whitespace
            while !is_at_end(lex) && (peek_char(lex) == #char " " || peek_char(lex) == #char "\t") {
                advance_char(lex);
            }

            // Check for "if" (increases nesting)
            if lex.pos + 2 <= lex.source.count &&
               lex.source[lex.pos] == #char "i" &&
               lex.source[lex.pos + 1] == #char "f" {
                nesting += 1;
            }
            // Check for "endif" (decreases nesting)
            else if lex.pos + 5 <= lex.source.count &&
                    lex.source[lex.pos] == #char "e" &&
                    lex.source[lex.pos + 1] == #char "n" &&
                    lex.source[lex.pos + 2] == #char "d" &&
                    lex.source[lex.pos + 3] == #char "i" &&
                    lex.source[lex.pos + 4] == #char "f" {
                nesting -= 1;
            }

            // Skip to end of line
            while !is_at_end(lex) && peek_char(lex) != #char "\n" {
                advance_char(lex);
            }
            continue;
        }

        advance_char(lex);
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

// Lookup semantic token types that carry values
// Returns token type and value, or INVALID if not found
lookup_attribute :: (text: string) -> TokenType, s64 {
    lower: [8] u8;
    len := min(text.count, 7);
    for i: 0..len-1 {
        c := text[i];
        if c >= #char "A" && c <= #char "Z" lower[i] = c + 32;
        else lower[i] = c;
    }
    lower_str: string;
    lower_str.data = lower.data;
    lower_str.count = len;

    // A_STR=0, A_DEX=1, A_CON=2, A_INT=3, A_WIS=4, A_CHA=5, A_LUC=6, A_LOY=7
    if lower_str == "str" return .ATTRIBUTE, 0;
    if lower_str == "dex" return .ATTRIBUTE, 1;
    if lower_str == "con" return .ATTRIBUTE, 2;
    if lower_str == "int" return .ATTRIBUTE, 3;
    if lower_str == "wis" return .ATTRIBUTE, 4;
    if lower_str == "cha" return .ATTRIBUTE, 5;
    if lower_str == "luc" return .ATTRIBUTE, 6;
    if lower_str == "loy" return .ATTRIBUTE, 7;
    return .INVALID, 0;
}

lookup_color :: (text: string) -> TokenType, s64 {
    lower: [16] u8;
    len := min(text.count, 15);
    for i: 0..len-1 {
        c := text[i];
        if c >= #char "A" && c <= #char "Z" lower[i] = c + 32;
        else lower[i] = c;
    }
    lower_str: string;
    lower_str.data = lower.data;
    lower_str.count = len;

    // Color values from Defines.h
    if lower_str == "black"   return .COLOR, 0;
    if lower_str == "grey" || lower_str == "gray" return .COLOR, 1;
    if lower_str == "white"   return .COLOR, 2;
    if lower_str == "blue"    return .COLOR, 3;
    if lower_str == "green"   return .COLOR, 4;
    if lower_str == "red"     return .COLOR, 5;
    if lower_str == "purple"  return .COLOR, 6;
    if lower_str == "cyan"    return .COLOR, 7;
    if lower_str == "magenta" return .COLOR, 8;
    if lower_str == "yellow"  return .COLOR, 9;
    if lower_str == "azure"   return .COLOR, 10;
    if lower_str == "sky" || lower_str == "skyblue" return .COLOR, 11;
    if lower_str == "pink"    return .COLOR, 12;
    if lower_str == "brown"   return .COLOR, 13;
    if lower_str == "shadow"  return .COLOR, 14;
    return .INVALID, 0;
}

lookup_direction :: (text: string) -> TokenType, s64 {
    lower: [16] u8;
    len := min(text.count, 15);
    for i: 0..len-1 {
        c := text[i];
        if c >= #char "A" && c <= #char "Z" lower[i] = c + 32;
        else lower[i] = c;
    }
    lower_str: string;
    lower_str.data = lower.data;
    lower_str.count = len;

    // Direction values from Defines.h
    if lower_str == "north"     return .DIRECTION, 0;
    if lower_str == "south"     return .DIRECTION, 1;
    if lower_str == "east"      return .DIRECTION, 2;
    if lower_str == "west"      return .DIRECTION, 3;
    if lower_str == "northeast" return .DIRECTION, 4;
    if lower_str == "northwest" return .DIRECTION, 5;
    if lower_str == "southeast" return .DIRECTION, 6;
    if lower_str == "southwest" return .DIRECTION, 7;
    if lower_str == "up"        return .DIRECTION, 8;
    if lower_str == "down"      return .DIRECTION, 9;
    if lower_str == "center"    return .DIRECTION, 10;
    return .INVALID, 0;
}

lookup_wep_type :: (text: string) -> TokenType, s64 {
    lower: [16] u8;
    len := min(text.count, 15);
    for i: 0..len-1 {
        c := text[i];
        if c >= #char "A" && c <= #char "Z" lower[i] = c + 32;
        else lower[i] = c;
    }
    lower_str: string;
    lower_str.data = lower.data;
    lower_str.count = len;

    // Weapon type values: SLASH=0, PIERCE=1, BLUNT=2
    if lower_str == "slash" || lower_str == "slashing" return .WEP_TYPE, 0;
    if lower_str == "pierce" || lower_str == "piercing" return .WEP_TYPE, 1;
    if lower_str == "blunt" return .WEP_TYPE, 2;
    return .INVALID, 0;
}

lookup_stype :: (text: string) -> TokenType, s64 {
    lower: [8] u8;
    len := min(text.count, 7);
    for i: 0..len-1 {
        c := text[i];
        if c >= #char "A" && c <= #char "Z" lower[i] = c + 32;
        else lower[i] = c;
    }
    lower_str: string;
    lower_str.data = lower.data;
    lower_str.count = len;

    // Save type values: FORT=0, REF=1, WILL=2
    if lower_str == "fort" return .STYPE, 0;
    if lower_str == "ref"  return .STYPE, 1;
    if lower_str == "will" return .STYPE, 2;
    return .INVALID, 0;
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
    if lower_str == "flavor" || lower_str == "flavour" return .KW_FLAVOR;
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
    if lower_str == "poison" return .KW_POISON;
    if lower_str == "disease" return .KW_DISEASE;
    if lower_str == "spells" return .KW_SPELLS;
    if lower_str == "floor" return .KW_FLOOR;
    if lower_str == "parts" return .KW_PARTS;
    if lower_str == "align" return .KW_ALIGN;
    if lower_str == "feats" return .KW_FEATS;
    if lower_str == "power" return .KW_POWER;
    if lower_str == "specials" return .KW_SPECIALS;
    if lower_str == "mtype" return .KW_MTYPE;
    if lower_str == "immune" return .KW_IMMUNE;

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

    // Note: Attribute words (Str, Dex, etc.) are handled by lookup_attribute()
    // and return ATTRIBUTE token type with value, not keywords

    // Keywords1 - Type keywords (work everywhere)
    if lower_str == "void" return .KW_VOID;
    if lower_str == "bool" return .KW_BOOL;
    if lower_str == "int8" return .KW_INT8;
    if lower_str == "int16" return .KW_INT16;
    if lower_str == "int32" return .KW_INT32;
    if lower_str == "uint8" return .KW_UINT8;
    if lower_str == "uint16" return .KW_UINT16;
    if lower_str == "hobj" return .KW_HOBJ;
    if lower_str == "htext" return .KW_HTEXT;
    if lower_str == "rid" return .KW_RID;
    if lower_str == "string" return .KW_STRING_TYPE;
    if lower_str == "rect" return .KW_RECT;

    // Keywords1 - Special words (work everywhere)
    if lower_str == "abs" return .KW_ABS;
    if lower_str == "member" return .KW_MEMBER;
    if lower_str == "static" return .KW_STATIC;
    if lower_str == "true" return .KW_TRUE;
    if lower_str == "false" return .KW_FALSE;
    if lower_str == "null" return .KW_NULL;
    if lower_str == "max" return .KW_MAX;
    if lower_str == "min" return .KW_MIN;

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

    // Keywords2 - only outside code blocks
    if !in_code {
        // More property keywords
        if lower_str == "glyph" return .KW_GLYPH;
        if lower_str == "value" return .KW_VALUE;
        if lower_str == "type" return .KW_TYPE;
        if lower_str == "day" return .KW_DAY;
        if lower_str == "week" return .KW_WEEK;
        if lower_str == "tile" return .KW_TILE;
        if lower_str == "tiles" return .KW_TILES;
        if lower_str == "all" return .KW_ALL;
        if lower_str == "also" return .KW_ALSO;
        if lower_str == "and" return .KW_AND;
        if lower_str == "or" return .KW_OR_KW;
        if lower_str == "with" return .KW_WITH;
        if lower_str == "of" return .KW_OF;
        if lower_str == "from" return .KW_FROM;
        if lower_str == "to" return .KW_TO;
        if lower_str == "per" return .KW_PER;
        if lower_str == "for" return .KW_FOR_KW;
        if lower_str == "innate" return .KW_INNATE;
        if lower_str == "invoke" return .KW_INVOKE;
        if lower_str == "base" return .KW_BASE;
        if lower_str == "chance" return .KW_CHANCE;
        if lower_str == "walls" return .KW_WALLS;
        if lower_str == "door" return .KW_DOOR;
        if lower_str == "grid" return .KW_GRID;
        if lower_str == "objects" return .KW_OBJECTS;
        if lower_str == "object" return .KW_OBJECT;
        if lower_str == "equip" return .KW_EQUIP;
        if lower_str == "wield" return .KW_WIELD;
        if lower_str == "module" return .KW_MODULE;
        if lower_str == "slot" return .KW_SLOT;
        if lower_str == "file" return .KW_FILE;
        if lower_str == "caster" return .KW_CASTER;
        if lower_str == "random" return .KW_RANDOM;
        if lower_str == "as" return .KW_AS;
        if lower_str == "near" return .KW_NEAR;
        if lower_str == "none" return .KW_NONE;
        if lower_str == "normal" return .KW_NORMAL;
        if lower_str == "partial" return .KW_PARTIAL;
        if lower_str == "turns" return .KW_TURNS;
        if lower_str == "timeout" return .KW_TIMEOUT;

        // Effect value keywords
        if lower_str == "sval" return .KW_SVAL;
        if lower_str == "dval" return .KW_DVAL;
        if lower_str == "aval" return .KW_AVAL;
        if lower_str == "lval" return .KW_LVAL;
        if lower_str == "tval" return .KW_TVAL;
        if lower_str == "rval" return .KW_RVAL;
        if lower_str == "eval" return .KW_EVAL;
        if lower_str == "purpose" return .KW_PURPOSE;

        // Item/container keywords
        if lower_str == "lifespan" return .KW_LIFESPAN;
        if lower_str == "fuel" return .KW_FUEL;
        if lower_str == "capacity" return .KW_CAPACITY;
        if lower_str == "weightlim" return .KW_WEIGHTLIM;
        if lower_str == "weightmod" return .KW_WEIGHTMOD;
        if lower_str == "maxsize" return .KW_MAXSIZE;
        if lower_str == "ctype" return .KW_CTYPE;
        if lower_str == "fires" return .KW_FIRES;
        if lower_str == "hitpoints" return .KW_HITPOINTS;

        // Combat keywords
        if lower_str == "melee" return .KW_MELEE;
        if lower_str == "archery" return .KW_ARCHERY;
        if lower_str == "brawl" return .KW_BRAWL;
        if lower_str == "throwing" || lower_str == "thrown" return .KW_THROWING;
        if lower_str == "heavy" return .KW_HEAVY;
        if lower_str == "saves" || lower_str == "sav" || lower_str == "save" return .KW_SAVES;
        if lower_str == "dmg" || lower_str == "dam" || lower_str == "damage" return .KW_DMG;
        if lower_str == "dc" return .KW_DC;

        // Misc keywords
        if lower_str == "cursed" return .KW_CURSED;
        if lower_str == "blessed" return .KW_BLESSED;
        if lower_str == "qualities" return .KW_QUALITIES;
        if lower_str == "sustains" return .KW_SUSTAINS;
        if lower_str == "resists" return .KW_RESISTS;
        if lower_str == "export" return .KW_EXPORT;
        if lower_str == "stock" return .KW_STOCK;
        if lower_str == "store" return .KW_STORE;
        if lower_str == "guild" return .KW_GUILD;
        if lower_str == "roomtypes" return .KW_ROOMTYPES;
        if lower_str == "regions" return .KW_REGIONS;
        if lower_str == "any" return .KW_ANY;
        if lower_str == "colour" || lower_str == "color" return .KW_COLOUR;
        if lower_str == "material" return .KW_MATERIAL;
        if lower_str == "move" return .KW_MOVE;
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
    in_code := lex.brace_level >= 2;

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

    // Outside code blocks, check for semantic tokens (AttrWords, ColourWords, DirWords, etc.)
    if !in_code {
        // Check attribute words
        attr_type, attr_val := lookup_attribute(text);
        if attr_type != .INVALID {
            tok := make_token(lex, attr_type, text, start_line, start_col);
            tok.int_value = attr_val;
            return tok;
        }

        // Check direction words
        dir_type, dir_val := lookup_direction(text);
        if dir_type != .INVALID {
            tok := make_token(lex, dir_type, text, start_line, start_col);
            tok.int_value = dir_val;
            return tok;
        }

        // Check weapon types
        wep_type, wep_val := lookup_wep_type(text);
        if wep_type != .INVALID {
            tok := make_token(lex, wep_type, text, start_line, start_col);
            tok.int_value = wep_val;
            return tok;
        }

        // Check save types
        save_type, save_val := lookup_stype(text);
        if save_type != .INVALID {
            tok := make_token(lex, save_type, text, start_line, start_col);
            tok.int_value = save_val;
            return tok;
        }

        // Note: Color words are handled as keywords (KW_RED, KW_BLUE, etc.) for parser compatibility.
        // The COLOR token type is available for future grammar alignment if needed.
    }

    // Check for keyword
    kw_type := lookup_keyword(text, in_code);
    if kw_type != .INVALID {
        // Set grid_mode when we see the Grid keyword
        if kw_type == .KW_GRID {
            lex.grid_mode = true;
        }
        return make_token(lex, kw_type, text, start_line, start_col);
    }

    // Plain identifier
    return make_token(lex, .IDENTIFIER, text, start_line, start_col);
}

// Map grid scanning - reads {: ... :} block
// Returns MAPAREA token with grid contents, stripping whitespace from line edges
scan_map_grid :: (lex: *Lexer, start_pos: s64, start_line: s32, start_col: s32) -> Token {
    // We've seen '{', now consume ':'
    advance_char(lex);  // consume ':'
    lex.grid_mode = false;  // Reset grid mode

    grid_start := lex.pos;

    // Read until we see :}
    while !is_at_end(lex) {
        c := peek_char(lex);
        if c == #char ":" {
            // Check if next is }
            if lex.pos + 1 < lex.source.count && lex.source[lex.pos + 1] == #char "}" {
                // Found :}, extract grid content
                grid_content := slice(lex.source, grid_start, lex.pos - grid_start);
                advance_char(lex);  // consume ':'
                advance_char(lex);  // consume '}'

                // Process the grid: strip leading/trailing whitespace from each line
                // and calculate dimensions
                tok := make_token(lex, .MAPAREA, grid_content, start_line, start_col);
                return tok;
            }
        }
        if c == #char "\n" {
            lex.line += 1;
            lex.column = 0;
        }
        advance_char(lex);
    }

    // Unterminated grid
    tok := make_token(lex, .INVALID, "Unterminated map grid", start_line, start_col);
    return tok;
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

scan_percent :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .MOD_EQ, "%=", start_line, start_col);
    }
    // Standalone % is the modulo operator
    return make_token(lex, .MODULO, "%", start_line, start_col);
}

scan_tilde :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "=" {
        advance_char(lex);
        return make_token(lex, .TILDE_EQ, "~=", start_line, start_col);
    }
    return make_token(lex, .TILDE, "~", start_line, start_col);
}

scan_dot :: (lex: *Lexer, start_line: s32, start_col: s32) -> Token {
    if peek_char(lex) == #char "." && peek_next(lex) == #char "." {
        advance_char(lex);
        advance_char(lex);
        return make_token(lex, .ELLIPSIS, "...", start_line, start_col);
    }
    return make_token(lex, .DOT, ".", start_line, start_col);
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
        // Check for map grid syntax: {: ... :}
        if lex.grid_mode && peek_char(lex) == #char ":" {
            return scan_map_grid(lex, start_pos, start_line, start_col);
        }
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
    if c == #char "." return scan_dot(lex, start_line, start_col);
    if c == #char "*" return scan_star(lex, start_line, start_col);
    if c == #char "/" return scan_slash(lex, start_line, start_col);
    if c == #char "+" return scan_plus(lex, start_line, start_col);
    if c == #char "-" return scan_minus(lex, start_line, start_col);
    if c == #char "|" return scan_pipe(lex, start_line, start_col);
    if c == #char "&" return scan_ampersand(lex, start_line, start_col);
    if c == #char "~" return scan_tilde(lex, start_line, start_col);
    if c == #char "!" return scan_bang(lex, start_line, start_col);
    if c == #char "?" return make_token(lex, .QUESTION, "?", start_line, start_col);
    if c == #char "<" return scan_less(lex, start_line, start_col);
    if c == #char ">" return scan_greater(lex, start_line, start_col);
    if c == #char "=" return scan_equal(lex, start_line, start_col);
    if c == #char "^" return make_token(lex, .CARET, "^", start_line, start_col);
    if c == #char "@" return make_token(lex, .AT, "@", start_line, start_col);
    if c == #char "#" return make_token(lex, .HASH, "#", start_line, start_col);
    if c == #char "%" return scan_percent(lex, start_line, start_col);
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
