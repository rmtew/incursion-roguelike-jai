# Rendering Pipeline Specification

How Incursion decides what to render, from resource data to screen output.

## Glyph Type

```c
typedef uint32 Glyph;
```

**Bitfield encoding:**
| Bits | Field | Range | Purpose |
|------|-------|-------|---------|
| 0-11 | GLYPH_ID | 0-4095 | Character code or GLYPH_* constant |
| 12-15 | GLYPH_FORE | 0-15 | Foreground color index |
| 16-19 | GLYPH_BACK | 0-15 | Background color index |
| 20-31 | (unused) | - | Reserved |

**Helper macros:**
```c
GLYPH_ID_VALUE(g)   // Extract character ID (bits 0-11)
GLYPH_FORE_VALUE(g) // Extract foreground color (bits 12-15)
GLYPH_BACK_VALUE(g) // Extract background color (bits 16-19)
GLYPH_VALUE(id, attr) // Combine ID and color attribute
```

## Color Palette

16 ANSI colors (from `inc/Defines.h` lines 4106-4121):

| Index | Name | Index | Name |
|-------|------|-------|------|
| 0 | BLACK | 8 | SHADOW |
| 1 | BLUE | 9 | AZURE |
| 2 | GREEN | 10 | EMERALD |
| 3 | CYAN | 11 | SKYBLUE |
| 4 | RED | 12 | PINK |
| 5 | PURPLE | 13 | MAGENTA |
| 6 | BROWN | 14 | YELLOW |
| 7 | GREY | 15 | WHITE |

## Resource Image Syntax

From `lang/Grammar.acc` lines 329-337:

```
Image: [color] <char|number> [on color];
```

**Examples:**
- `Image: green 'g';` - Green 'g', black background
- `Image: blue 247;` - Blue CP437 code 247
- `Image: red '@' on yellow;` - Red '@' on yellow background

## Runtime Storage

| Type | Field | Source |
|------|-------|--------|
| TMonster | `Glyph Image` | inc/Res.h:338 |
| TItem | `uint32 Image` | inc/Res.h:425 |
| TFeature | `int16 Image` | inc/Res.h:466 |
| TTerrain | `Glyph Image` | inc/Res.h:649 |
| TTemplate | `Glyph NewImage` | inc/Res.h:681 |

## GLYPH_* Constants

Extended glyph constants (256+) are semantic aliases. They must be converted to CP437 codes at render time.

**Key constants** (from `inc/Defines.h` lines 4171-4305):

| Constant | Value | CP437 | Character |
|----------|-------|-------|-----------|
| GLYPH_FLOOR | 323 | 250 | Middle dot · |
| GLYPH_FLOOR2 | 324 | 249 | Small square |
| GLYPH_WALL | 264 | 177 | Medium shade ▒ |
| GLYPH_ROCK | 265 | 176 | Light shade ░ |
| GLYPH_WATER | 258 | 247 | Almost equal ≈ |
| GLYPH_LAVA | 262 | 247 | Almost equal ≈ |
| GLYPH_CHASM | 261 | 176 | Light shade ░ |
| GLYPH_DOOR | 269 | 43 | Plus + |
| GLYPH_PLAYER | 361 | 64 | At sign @ |
| GLYPH_HUMAN | 362 | 1 | Smiling face ☺ |
| GLYPH_UNKNOWN | ? | 63 | Question mark ? |
| GLYPH_MULTI | ? | 198 | AE ligature Æ |
| GLYPH_PILE | ? | 42 | Asterisk * |
| GLYPH_LAST | 375 | - | Maximum ID |

**Note:** Water and lava share the same CP437 code (247). Color distinguishes them.

## CP437 Lookup Table

**Authoritative source:** `src/Wlibtcod.cpp` lines 448-606

**Function:** `int glyphchar_to_char(Glyph g)`

**Logic:**
1. Extract GLYPH_ID from bits 0-11
2. If ID < 256, return ID directly (standard ASCII/CP437)
3. If ID >= 256, look up in conversion table
4. Return CP437 code (0-255) for font atlas

## Map Cell Storage

**LocationInfo** (from `inc/Map.h` lines 25-49):

```c
struct LocationInfo {
    uint32 Glyph;      // Terrain's base glyph + color
    uint32 Region:8;   // Region ID
    uint32 Terrain:8;  // Terrain type ID
    uint32 Opaque:1;   // Blocks light
    uint32 Solid:1;    // Not passable
    uint32 Lit:1;      // Illuminated
    uint32 Memory;     // What player remembers
    hObj Contents;     // Things at this location
};
```

## Rendering Decision Flow

**Source:** `src/Term.cpp` lines 701-868 (`Map::Update()`)

### Priority System

When multiple things occupy a cell, highest priority wins:

1. **Creatures** (priority 3) - Always visible if present
2. **Items** (priority varies by type)
3. **Features** (doors, traps, etc.)
4. **Terrain** (base layer)

### Multiple Things

- Multiple creatures → `GLYPH_MULTI` (Æ symbol)
- Multiple items → `GLYPH_PILE` (asterisk)
- Single entity → Entity's glyph

### Visibility Rules

| Condition | Display |
|-----------|---------|
| Never seen | `GLYPH_UNSEEN` (space) |
| Seen but not visible | Memory glyph |
| Currently visible | Current contents |

### Color Resolution

1. Start with terrain's background color
2. Entity's foreground color from its glyph
3. If FG == BG, auto-adjust to avoid invisible text
4. Special highlights (target markers) override background

## Terminal Rendering

**Source:** `src/Wlibtcod.cpp` lines 1139-1142

```c
void libtcodTerm::SPutChar(int16 x, int16 y, Glyph g) {
    int c = glyphchar_to_char(g);  // GLYPH_* → CP437
    TCOD_console_put_char_ex(
        bScroll, x, y, c,
        Colors[GLYPH_FORE_VALUE(g)],
        Colors[GLYPH_BACK_VALUE(g)]
    );
}
```

## Verification Checklist

For the Jai port to render correctly:

- [ ] Parse `Image:` syntax extracting color and character separately
- [ ] Store glyph as u32 with correct bitfield layout
- [ ] Implement GLYPH_* → CP437 lookup table
- [ ] Color values stored in bits 12-15 (FG) and 16-19 (BG)
- [ ] Rendering priority matches original
- [ ] GLYPH_MULTI/GLYPH_PILE for multiple entities
- [ ] Visibility/memory system checks flags before display

## Key Source Files

| File | Lines | Content |
|------|-------|---------|
| `inc/Defines.h` | 4100-4305 | GLYPH_* constants, colors, macros |
| `inc/Res.h` | 332-681 | Resource struct Image fields |
| `inc/Map.h` | 25-49 | LocationInfo struct |
| `lang/Grammar.acc` | 329-337 | Image parsing grammar |
| `src/Wlibtcod.cpp` | 448-606 | CP437 lookup table |
| `src/Term.cpp` | 701-868 | Rendering decision logic |
