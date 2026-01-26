// Incursion Port - Core Definitions
// Reconstructed from RECONSTRUCTION-CORE.md

VERSION_STRING :: "0.6.9Y19-jai";

// Direction enum
Dir :: enum u8 {
    NORTH     :: 0;
    SOUTH     :: 1;
    EAST      :: 2;
    WEST      :: 3;
    NORTHEAST :: 4;
    NORTHWEST :: 5;
    SOUTHEAST :: 6;
    SOUTHWEST :: 7;
    UP        :: 8;
    DOWN      :: 9;
    CENTER    :: 10;
}

DirX :: (d: Dir) -> s8 {
    if d == .EAST || d == .NORTHEAST || d == .SOUTHEAST return 1;
    if d == .WEST || d == .NORTHWEST || d == .SOUTHWEST return -1;
    return 0;
}

DirY :: (d: Dir) -> s8 {
    if d == .SOUTH || d == .SOUTHEAST || d == .SOUTHWEST return 1;
    if d == .NORTH || d == .NORTHEAST || d == .NORTHWEST return -1;
    return 0;
}

// Glyph - packed character + colors
Glyph :: struct {
    value: u32;  // Packed: char (8) + fg (8) + bg (8) + flags (8)
}

make_glyph :: (char: u8, fg: u8, bg: u8 = 0) -> Glyph {
    g: Glyph;
    // Parentheses needed: cast has lower precedence than <<
    g.value = (cast(u32) char) | ((cast(u32) fg) << 8) | ((cast(u32) bg) << 16);
    return g;
}

glyph_char :: (g: Glyph) -> u8 {
    return cast(u8) (g.value & 0xFF);
}

glyph_fg :: (g: Glyph) -> u8 {
    return cast(u8) ((g.value >> 8) & 0xFF);
}

glyph_bg :: (g: Glyph) -> u8 {
    return cast(u8) ((g.value >> 16) & 0xFF);
}

// Common type aliases
hObj :: s32;    // Object handle
rID :: s32;     // Resource ID

NULL_OBJ : hObj : -1;
NULL_ID : rID : -1;

// Size constants
SZ_TINY       :: 0;
SZ_SMALL      :: 1;
SZ_MEDIUM     :: 2;
SZ_LARGE      :: 3;
SZ_HUGE       :: 4;
SZ_GARGANTUAN :: 5;
SZ_COLLOSAL   :: 6;

// Material types (partial list)
MAT_IRON    :: 1;
MAT_WOOD    :: 2;
MAT_LEATHER :: 3;
MAT_STONE   :: 4;
MAT_CLOTH   :: 5;
MAT_BONE    :: 6;
MAT_GOLD    :: 7;
MAT_SILVER  :: 8;
MAT_COPPER  :: 9;
MAT_GLASS   :: 10;
MAT_PAPER   :: 11;

// Attribute indices
A_STR :: 0;
A_DEX :: 1;
A_CON :: 2;
A_INT :: 3;
A_WIS :: 4;
A_CHA :: 5;
A_LUC :: 6;

// Resource ID manipulation
rID_module :: (id: rID) -> s32 {
    return (id >> 16) & 0xFFFF;
}

rID_index :: (id: rID) -> s32 {
    return id & 0xFFFF;
}

make_rID :: (module: s32, index: s32) -> rID {
    return cast(rID) ((module << 16) | (index & 0xFFFF));
}

// Console colors
BLACK        :: 0;
BLUE         :: 1;
GREEN        :: 2;
CYAN         :: 3;
RED          :: 4;
MAGENTA      :: 5;
BROWN        :: 6;
GREY         :: 7;
SHADOW       :: 8;
AZURE        :: 9;
EMERALD      :: 10;
SKY          :: 11;
PINK         :: 12;
PURPLE       :: 13;
YELLOW       :: 14;
WHITE        :: 15;

// Math helpers
my_abs :: (x: $T) -> T {
    if x < 0 return -x;
    return x;
}

my_max :: (a: $T, b: T) -> T {
    if a > b return a;
    return b;
}

my_min :: (a: $T, b: T) -> T {
    if a < b return a;
    return b;
}

clamp :: (x: $T, lo: T, hi: T) -> T {
    if x < lo return lo;
    if x > hi return hi;
    return x;
}
