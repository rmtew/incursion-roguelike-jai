// GLYPH_* to CP437 lookup table
// Extracted from original Incursion source: src/Wlibtcod.cpp lines 448-617
// Constants from: inc/Defines.h lines 4169-4305

// Extended glyph constants (256+) are semantic aliases that must be
// converted to CP437 character codes (0-255) for font atlas lookup.

// Glyph bitfield layout (32-bit):
//   Bits 0-11:  Character ID (0-4095, includes GLYPH_* constants)
//   Bits 12-15: Foreground color (0-15)
//   Bits 16-19: Background color (0-15)

GLYPH_ID_BITS   :: 12;
GLYPH_ID_MASK   :: (1 << GLYPH_ID_BITS) - 1;  // 0x0FFF

glyph_id :: (g: u32) -> u16 {
    return cast(u16)(g & GLYPH_ID_MASK);
}

glyph_fg :: (g: u32) -> u8 {
    return cast(u8)((g >> 12) & 0x0F);
}

glyph_bg :: (g: u32) -> u8 {
    return cast(u8)((g >> 16) & 0x0F);
}

make_glyph :: (id: u16, fg: u8, bg: u8 = 0) -> u32 {
    return cast(u32)id | (cast(u32)fg << 12) | (cast(u32)bg << 16);
}

// GLYPH_* constant definitions
GLYPH_FIRST     :: 256;

GLYPH_PERSON    :: 256;
GLYPH_BULK      :: 257;
GLYPH_WATER     :: 258;
GLYPH_FOG       :: 259;
GLYPH_ICE       :: 260;
GLYPH_WEB       :: 261;
GLYPH_LAVA      :: 262;
GLYPH_BLAST     :: 263;
GLYPH_WALL      :: 264;
GLYPH_ROCK      :: 265;
GLYPH_SOLID     :: 266;
GLYPH_PILLAR1   :: 267;
GLYPH_VIEWPOINT :: 268;
GLYPH_GRAVE     :: 269;
GLYPH_SHELF     :: 270;
GLYPH_PILLAR2   :: 271;

GLYPH_POTION    :: 272;
GLYPH_SCROLL    :: 273;
// 274 unused
GLYPH_WEAPON    :: 275;
GLYPH_ROD       :: 276;
GLYPH_STAFF     :: 277;
GLYPH_WAND      :: 278;
GLYPH_FOOD      :: 279;
GLYPH_CORPSE    :: 280;
GLYPH_BOOK      :: 281;
GLYPH_TORCH     :: 282;
GLYPH_LARMOUR   :: 283;
GLYPH_MARMOUR   :: 284;
GLYPH_HARMOUR   :: 285;
GLYPH_SHIELD    :: 286;
GLYPH_GAUNTLETS :: 287;
GLYPH_HELMET    :: 288;
GLYPH_HEADBAND  :: 289;
GLYPH_BOOTS     :: 290;
GLYPH_BRACERS   :: 291;
GLYPH_GIRDLE    :: 292;
GLYPH_CLOTHES   :: 293;
GLYPH_CONTAIN   :: 294;
GLYPH_CROWN     :: 295;
GLYPH_DUST      :: 296;
GLYPH_DECK      :: 297;
GLYPH_RING      :: 298;
GLYPH_AMULET    :: 299;
GLYPH_FIGURE    :: 300;
GLYPH_HORN      :: 301;
GLYPH_EYES      :: 302;
GLYPH_HERB      :: 303;
GLYPH_MUSH      :: 304;
GLYPH_GEM       :: 305;
GLYPH_COIN      :: 306;
GLYPH_TOOL      :: 307;
GLYPH_SWORD     :: 308;
GLYPH_BOW       :: 309;
GLYPH_JUNK      :: 310;
GLYPH_CHEST     :: 311;

GLYPH_CLOAK     :: 312;
GLYPH_STATUE    :: 313;
GLYPH_PILE      :: 314;
GLYPH_MULTI     :: 315;
GLYPH_ALTAR     :: 316;
GLYPH_FOUNTAIN  :: 317;
GLYPH_THRONE    :: 318;
GLYPH_SYMBOL    :: 319;

GLYPH_HEDGE     :: 320;
GLYPH_RUBBLE    :: 321;
GLYPH_BRIDGE    :: 322;
GLYPH_FLOOR     :: 323;
GLYPH_FLOOR2    :: 324;
GLYPH_VDOOR     :: 325;
GLYPH_HDOOR     :: 326;
GLYPH_ODOOR     :: 327;
GLYPH_BDOOR     :: 328;
GLYPH_PIT       :: 329;
GLYPH_PORTAL    :: 330;

GLYPH_STORE         :: 331;
GLYPH_GUILD         :: 332;
GLYPH_STORE_VWALL   :: 333;
GLYPH_STORE_HWALL   :: 334;
GLYPH_STORE_CORNER  :: 335;

GLYPH_USTAIRS   :: 336;
GLYPH_DSTAIRS   :: 337;
GLYPH_TREE      :: 338;
GLYPH_CHECK     :: 339;
GLYPH_FURNATURE :: 340;
GLYPH_UNKNOWN   :: 341;
GLYPH_TRASH     :: 342;
GLYPH_BONES     :: 343;
GLYPH_CHECKMARK :: 344;

GLYPH_TRAP      :: 345;
GLYPH_DISARMED  :: 346;

GLYPH_ARROW       :: 347;
GLYPH_ARROW_UP    :: 348;
GLYPH_ARROW_DOWN  :: 349;
GLYPH_ARROW_RIGHT :: 350;
GLYPH_ARROW_LEFT  :: 351;

GLYPH_GUARD     :: 352;
GLYPH_TOWNIE    :: 353;
GLYPH_TOWNSCUM  :: 354;
GLYPH_TOWN_NPC  :: 355;
GLYPH_LDEMON    :: 356;
GLYPH_GDEMON    :: 357;
GLYPH_LDEVIL    :: 358;
GLYPH_GDEVIL    :: 359;
GLYPH_FIEND     :: 360;

GLYPH_PLAYER    :: 361;
GLYPH_HUMAN     :: 362;
GLYPH_ELF       :: 363;
GLYPH_DWARF     :: 364;
GLYPH_GNOME     :: 365;
GLYPH_HOBBIT    :: 366;

GLYPH_VLINE         :: 367;
GLYPH_HLINE         :: 368;
GLYPH_DIVIDE        :: 369;
GLYPH_APPROXIMATELY :: 370;
GLYPH_BLACK_SQUARE  :: 371;

GLYPH_SUMMONING_CIRCLE :: 372;
GLYPH_POINTER_LEFT     :: 373;
GLYPH_POINTER_RIGHT    :: 374;

GLYPH_UNSEEN    :: 375;
GLYPH_LAST      :: 375;

// CP437 lookup table
// Index: GLYPH_* constant value (256-375)
// Value: CP437 character code (0-255)
// 0 means "use raw value" (passthrough for standard ASCII)
GLYPH_TO_CP437 :: u8.[
    // 256-271: Environment/terrain
    6,      // 256 GLYPH_PERSON    -> 6 (spade)
    197,    // 257 GLYPH_BULK      -> 197 (box cross)
    247,    // 258 GLYPH_WATER     -> 247 (almost equal ≈)
    #char "~", // 259 GLYPH_FOG    -> '~'
    254,    // 260 GLYPH_ICE       -> 254 (black square)
    #char "#", // 261 GLYPH_WEB    -> '#'
    247,    // 262 GLYPH_LAVA      -> 247 (almost equal ≈)
    15,     // 263 GLYPH_BLAST     -> 15 (white sun)
    177,    // 264 GLYPH_WALL      -> 177 (medium shade ▒)
    176,    // 265 GLYPH_ROCK      -> 176 (light shade ░)
    219,    // 266 GLYPH_SOLID     -> 219 (full block █)
    9,      // 267 GLYPH_PILLAR1   -> 9 (white circle)
    9,      // 268 GLYPH_VIEWPOINT -> 9 (white circle)
    239,    // 269 GLYPH_GRAVE     -> 239 (product symbol)
    216,    // 270 GLYPH_SHELF     -> 216 (box V1H2)
    15,     // 271 GLYPH_PILLAR2   -> 15 (white sun)

    // 272-311: Items
    173,    // 272 GLYPH_POTION    -> 173 (inverted !)
    168,    // 273 GLYPH_SCROLL    -> 168 (inverted ?)
    0,      // 274 (unused)
    251,    // 275 GLYPH_WEAPON    -> 251 (check mark)
    #char "|", // 276 GLYPH_ROD    -> '|'
    #char "/", // 277 GLYPH_STAFF  -> '/'
    #char "-", // 278 GLYPH_WAND   -> '-'
    #char "%", // 279 GLYPH_FOOD   -> '%'
    #char "%", // 280 GLYPH_CORPSE -> '%'
    254,    // 281 GLYPH_BOOK      -> 254 (black square)
    #char "}", // 282 GLYPH_TORCH  -> '}'
    228,    // 283 GLYPH_LARMOUR   -> 228 (Σ)
    228,    // 284 GLYPH_MARMOUR   -> 228 (Σ)
    228,    // 285 GLYPH_HARMOUR   -> 228 (Σ)
    #char "]", // 286 GLYPH_SHIELD -> ']'
    229,    // 287 GLYPH_GAUNTLETS -> 229 (σ)
    155,    // 288 GLYPH_HELMET    -> 155 (cent ¢)
    155,    // 289 GLYPH_HEADBAND  -> 155 (cent ¢)
    224,    // 290 GLYPH_BOOTS     -> 224 (α)
    224,    // 291 GLYPH_BRACERS   -> 224 (α)
    226,    // 292 GLYPH_GIRDLE    -> 226 (Γ)
    20,     // 293 GLYPH_CLOTHES   -> 20 (pilcrow ¶)
    127,    // 294 GLYPH_CONTAIN   -> 127 (house)
    #char "^", // 295 GLYPH_CROWN  -> '^'
    240,    // 296 GLYPH_DUST      -> 240 (≡)
    240,    // 297 GLYPH_DECK      -> 240 (≡)
    235,    // 298 GLYPH_RING      -> 235 (δ)
    11,     // 299 GLYPH_AMULET    -> 11 (male ♂)
    156,    // 300 GLYPH_FIGURE    -> 156 (£)
    #char "&", // 301 GLYPH_HORN   -> '&'
    236,    // 302 GLYPH_EYES      -> 236 (∞)
    #char "\"", // 303 GLYPH_HERB  -> '"'
    227,    // 304 GLYPH_MUSH      -> 227 (π)
    4,      // 305 GLYPH_GEM       -> 4 (diamond ♦)
    #char "$", // 306 GLYPH_COIN   -> '$'
    234,    // 307 GLYPH_TOOL      -> 234 (Ω)
    #char "(", // 308 GLYPH_SWORD  -> '('
    #char ")", // 309 GLYPH_BOW    -> ')'
    #char "&", // 310 GLYPH_JUNK   -> '&'
    127,    // 311 GLYPH_CHEST     -> 127 (house)

    // 312-319: More items/features
    6,      // 312 GLYPH_CLOAK     -> 6 (hearts ♥) -- Note: original says 6
    5,      // 313 GLYPH_STATUE    -> 5 (spades ♠)
    #char "*", // 314 GLYPH_PILE   -> '*'
    146,    // 315 GLYPH_MULTI     -> 146 (Æ)
    #char "8", // 316 GLYPH_ALTAR  -> '8'
    244,    // 317 GLYPH_FOUNTAIN  -> 244 (integral top)
    190,    // 318 GLYPH_THRONE    -> 190 (box U1L2)
    237,    // 319 GLYPH_SYMBOL    -> 237 (Ø)

    // 320-330: Terrain/dungeon features
    #char "\"", // 320 GLYPH_HEDGE -> '"'
    #char ":", // 321 GLYPH_RUBBLE -> ':'
    #char "=", // 322 GLYPH_BRIDGE -> '='
    250,    // 323 GLYPH_FLOOR     -> 250 (middle dot ·)
    249,    // 324 GLYPH_FLOOR2    -> 249 (small square)
    179,    // 325 GLYPH_VDOOR     -> 179 (box V1)
    196,    // 326 GLYPH_HDOOR     -> 196 (box H1)
    #char "+", // 327 GLYPH_ODOOR  -> '+'
    241,    // 328 GLYPH_BDOOR     -> 241 (±)
    #char "0", // 329 GLYPH_PIT    -> '0'
    240,    // 330 GLYPH_PORTAL    -> 240 (≡)

    // 331-335: Store/guild
    21,     // 331 GLYPH_STORE        -> 21 (§)
    20,     // 332 GLYPH_GUILD        -> 20 (¶)
    186,    // 333 GLYPH_STORE_VWALL  -> 186 (box V2)
    205,    // 334 GLYPH_STORE_HWALL  -> 205 (box H2)
    219,    // 335 GLYPH_STORE_CORNER -> 219 (full block)

    // 336-344: Stairs, furniture, misc
    #char "<", // 336 GLYPH_USTAIRS    -> '<'
    #char ">", // 337 GLYPH_DSTAIRS    -> '>'
    157,    // 338 GLYPH_TREE         -> 157 (¥)
    251,    // 339 GLYPH_CHECK        -> 251 (√)
    254,    // 340 GLYPH_FURNATURE    -> 254 (black square)
    #char "?", // 341 GLYPH_UNKNOWN   -> '?'
    #char "&", // 342 GLYPH_TRASH     -> '&'
    #char "&", // 343 GLYPH_BONES     -> '&'
    251,    // 344 GLYPH_CHECKMARK    -> 251 (√)

    // 345-346: Traps
    232,    // 345 GLYPH_TRAP      -> 232 (Φ)
    246,    // 346 GLYPH_DISARMED  -> 246 (÷)

    // 347-351: Arrows
    24,     // 347 GLYPH_ARROW       -> 24 (↑)
    24,     // 348 GLYPH_ARROW_UP    -> 24 (↑)
    25,     // 349 GLYPH_ARROW_DOWN  -> 25 (↓)
    26,     // 350 GLYPH_ARROW_RIGHT -> 26 (→)
    27,     // 351 GLYPH_ARROW_LEFT  -> 27 (←)

    // 352-360: NPCs/creatures
    140,    // 352 GLYPH_GUARD    -> 140 (î)
    139,    // 353 GLYPH_TOWNIE   -> 139 (ï)
    141,    // 354 GLYPH_TOWNSCUM -> 141 (ì)
    #char "i", // 355 GLYPH_TOWN_NPC -> 'i'
    151,    // 356 GLYPH_LDEMON   -> 151 (ù)
    154,    // 357 GLYPH_GDEMON   -> 154 (Ü)
    148,    // 358 GLYPH_LDEVIL   -> 148 (ö)
    153,    // 359 GLYPH_GDEVIL   -> 153 (Ö)
    152,    // 360 GLYPH_FIEND    -> 152 (ÿ)

    // 361-366: Player races
    #char "@", // 361 GLYPH_PLAYER -> '@'
    1,      // 362 GLYPH_HUMAN    -> 1 (☺)
    132,    // 363 GLYPH_ELF      -> 132 (custom face)
    131,    // 364 GLYPH_DWARF    -> 131 (custom face)
    133,    // 365 GLYPH_GNOME    -> 133 (custom small face)
    133,    // 366 GLYPH_HOBBIT   -> 133 (custom small face)

    // 367-371: UI/lines
    179,    // 367 GLYPH_VLINE         -> 179 (│)
    196,    // 368 GLYPH_HLINE         -> 196 (─)
    246,    // 369 GLYPH_DIVIDE        -> 246 (÷)
    247,    // 370 GLYPH_APPROXIMATELY -> 247 (≈)
    254,    // 371 GLYPH_BLACK_SQUARE  -> 254 (■)

    // 372-375: Misc
    233,    // 372 GLYPH_SUMMONING_CIRCLE -> 233 (Θ)
    17,     // 373 GLYPH_POINTER_LEFT     -> 17 (◄)
    16,     // 374 GLYPH_POINTER_RIGHT    -> 16 (►)
    #char " ", // 375 GLYPH_UNSEEN        -> ' '
];

// Convert glyph ID to CP437 character code for font atlas lookup
// Input: glyph ID (0-4095, but typically 0-375)
// Output: CP437 code (0-255)
glyph_to_cp437 :: (id: u16) -> u8 {
    // Standard ASCII/CP437 range - pass through directly
    if id < 256 {
        return cast(u8)id;
    }

    // Extended glyph range - look up in table
    if id <= GLYPH_LAST {
        index := id - GLYPH_FIRST;
        result := GLYPH_TO_CP437[index];
        // 0 in table means passthrough (shouldn't happen for valid extended glyphs)
        if result == 0 return #char "?";
        return result;
    }

    // Invalid glyph ID
    return #char "?";
}

// Convert full glyph value (with colors) to CP437
// Extracts ID from bits 0-11, converts to CP437
glyph_value_to_cp437 :: (g: u32) -> u8 {
    return glyph_to_cp437(glyph_id(g));
}
