# Regions Specification

## Verification Status

| Section | Status | Source |
|---------|--------|--------|
| TRegion class | VERIFIED | Res.h:630-643 |
| RF_* flags | VERIFIED | Defines.h:705-732 |
| Region selection | VERIFIED | MakeLev.cpp:2396-2422 |
| Corridor selection | VERIFIED | MakeLev.cpp:3406-3423 |
| Weight list defaults | VERIFIED | Annot.cpp:294-426 |
| WriteMap (grid processing) | VERIFIED | MakeLev.cpp:953-1102 |
| Color lists | VERIFIED | MakeLev.cpp:2820-2842 |
| List constants | VERIFIED | Defines.h:3513-3520 |

## TRegion Structure

**Source:** `Res.h:630-643`

```cpp
class TRegion: public Resource {
    public:
        TRegion() : Resource (T_TREGION) { }
        int8 Depth, Size;
        rID Walls, Floor, Door;
        int8 MTypes[4];
        rID Furnishings[6];
        uint32 RoomTypes;
        uint8 sx,sy; hText Grid;
        uint8 Flags[(RF_LAST/8)+1];
};
```

**Fields:**
- `Depth` - Minimum dungeon depth for this region
- `Size` - Size constraint (e.g., SZ_MEDIUM for corridors)
- `Walls` - Reference to terrain for walls
- `Floor` - Reference to terrain for floor
- `Door` - Reference to feature for doors
- `MTypes[4]` - Monster types for this region
- `Furnishings[6]` - Inline furnishing references
- `RoomTypes` - Bitmask of compatible RM_* room types
- `sx, sy` - Grid dimensions (for RM_SHAPED)
- `Grid` - Text handle for grid map

## Region Flags

**Source:** `Defines.h:705-732`

```cpp
#define RF_CORRIDOR   1   /* Region is a corridor type */
#define RF_VAULT      2   /* Region is a vault (special area) */
#define RF_WARN       3   /* Dangerous region - warn player */
#define RF_ROOM       4   /* Region is a room type */
#define RF_NO_MON     5   /* No monster generation */
#define RF_NO_TRAP    6   /* No trap generation */
#define RF_NO_JUNK    7   /* No junk item generation */
#define RF_NO_TREA    8   /* No treasure generation */
#define RF_XTRA_MON   9   /* Extra monsters */
#define RF_XTRA_TRAP  10  /* Extra traps */
#define RF_XTRA_JUNK  11  /* Extra junk */
#define RF_XTRA_TREA  12  /* Extra treasure */
#define RF_TRAPMAZE   13  /* Maze with traps */
#define RF_XTRA_CORP  14  /* Extra corpses */
#define RF_NOGEN      15  /* Never auto-generate (script-only) */
#define RF_STREAMER   16  /* General streamer type */
#define RF_ROCKTYPE   17  /* Rock streamer (changes rock type) */
#define RF_CHASM      18  /* Chasm streamer */
#define RF_RIVER      19  /* River streamer */
#define RF_RAINBOW    20  /* Rainbow wall colors */
#define RF_RAINBOW_W  21  /* Rainbow wall colors (alternate) */
#define RF_ALWAYS_LIT 22  /* Room always lit */
#define RF_NEVER_LIT  23  /* Room never lit */
#define RF_STAPLE     24  /* Can be used multiple times per level */
#define RF_ODD_WIDTH  25  /* Prefer odd width rooms */
#define RF_ODD_HEIGHT 26  /* Prefer odd height rooms */
#define RF_CENTER_ENC 27  /* Place encounters at room center */
#define RF_LAST       28
```

## Region Categories

### Room Regions (RF_ROOM)

Used for main dungeon rooms. Selected during DrawPanel.

**Selection algorithm** (`MakeLev.cpp:2396-2422`):

```cpp
for (i = c = 0; RoomWeights[i * 2]; i++) {
    // Check room type compatibility
    if (!TREG(RoomWeights[i * 2])->RoomTypes ||
        (TREG(RoomWeights[i * 2])->RoomTypes & BIT(RType)))
        // Check depth requirement
        if (DepthCR >= TREG(RoomWeights[i * 2])->Depth)
            // Check vault depth
            if (!TREG(RoomWeights[i * 2])->HasFlag(RF_VAULT) ||
                DepthCR >= (int16)Con[MIN_VAULT_DEPTH]) {
                // Skip corridors
                if (!TREG(RoomWeights[i * 2])->HasFlag(RF_CORRIDOR)) {
                    // Skip already used (one-time regions)
                    for (j = 0; usedInThisLevel[j]; j++)
                        if (usedInThisLevel[j] == RoomWeights[i * 2])
                            goto SkipCandidate;
                    Candidates[c++] = RoomWeights[i * 2];
                }
            }
}
regID = Candidates[random(c)];
```

**Key behaviors:**
- Region must support the chosen room type (RoomTypes bitmask)
- Region depth must be <= current DepthCR
- Vaults only at MIN_VAULT_DEPTH or deeper
- Each region used only once per level (unless RF_STAPLE)

### Corridor Regions (RF_CORRIDOR)

Used for tunnels connecting rooms.

**Selection algorithm** (`MakeLev.cpp:3406-3423`):

```cpp
if (dist(sx, sy, dx, dy) > 5) {
    for (i = 0; CorridorWeights[i * 2]; i++)
        for (x = 0; x < (int16)CorridorWeights[i * 2 + 1]; x++)
            Candidates[c++] = CorridorWeights[i * 2];

    if (c) {
        regID = Candidates[random(c)];
        // Mark as used unless RF_STAPLE
        if (!(TREG(regID)->HasFlag(RF_STAPLE)))
            usedInThisLevel[i] = regID;
    }
}
```

**Key behaviors:**
- Only for corridors > 5 tiles long
- Weighted selection from CorridorWeights
- RF_STAPLE corridors get weight 16 (others get 1)
- One-time use unless RF_STAPLE

### Streamer Regions

Rivers, chasms, and rock type streamers that span the map.

**Streamer types:**
- `RF_RIVER` - Water/magma rivers
- `RF_ROCKTYPE` - Rock type changes (quartz, limestone, etc.)
- `RF_CHASM` - Chasms (continue from level above)
- `RF_STREAMER` - General streamer type

## Default Weight Lists

**Source:** `Annot.cpp:294-426`

### Room Type Weights (RM_Weights)

```cpp
static uint32 RM_Weights[] = {
    RM_NORMAL,   10,
    RM_NOROOM,   1,
    RM_LARGE,    1,
    RM_CROSS,    1,
    RM_OVERLAP,  1,
    RM_ADJACENT, 1,
    RM_AD_ROUND, 2,
    RM_AD_MIXED, 2,
    RM_CIRCLE,   4,
    RM_OCTAGON,  5,
    RM_DIAMONDS, 4,
    RM_DOUBLE,   2,
    RM_PILLARS,  3,
    RM_CHECKER,  1,
    RM_BUILDING, 3,
    RM_GRID,     1,
    RM_LIFECAVE, 10,
    RM_RCAVERN,  4,
    RM_MAZE,     2,
    RM_LCIRCLE,  1,
    RM_SHAPED,   2,
    0,           0
};
```

### Room Weight List (ROOM_WEIGHTS)

**Default generation** (`Annot.cpp:365-380`):

```cpp
case ROOM_WEIGHTS:
    for (q=0;q!=MAX_MODULES;q++)
        if (theGame->Modules[q]) {
            xID = theGame->Modules[q]->RegionID(0);
            endID = xID + theGame->Modules[q]->szReg;
            for(;xID!=endID && max;xID++)
                if (TREG(xID)->HasFlag(RF_ROOM))
                    if (!TREG(xID)->HasFlag(RF_NOGEN)) {
                        *lv++ = xID;
                        *lv++ = 1;  // Weight = 1
                    }
        }
```

All RF_ROOM regions without RF_NOGEN, weight 1.

### Corridor Weight List (CORRIDOR_WEIGHTS)

**Default generation** (`Annot.cpp:381-396`):

```cpp
case CORRIDOR_WEIGHTS:
    for (q=0;q!=MAX_MODULES;q++)
        if (theGame->Modules[q]) {
            xID = theGame->Modules[q]->RegionID(0);
            endID = xID + theGame->Modules[q]->szReg;
            for(;xID!=endID && max;xID++)
                if (TREG(xID)->HasFlag(RF_CORRIDOR))
                    if (!TREG(xID)->HasFlag(RF_NOGEN)) {
                        *lv++ = xID;
                        *lv++ = TREG(xID)->HasFlag(RF_STAPLE) ? 16 : 1;
                    }
        }
```

RF_STAPLE corridors get weight 16, others get weight 1.

### Streamer Weight List (STREAMER_WEIGHTS)

**Default generation** (`Annot.cpp:411-426`):

```cpp
case STREAMER_WEIGHTS:
    for (q=0;q!=MAX_MODULES;q++)
        if (theGame->Modules[q]) {
            for(;xID!=endID && max;xID++)
                if (TREG(xID)->HasFlag(RF_RIVER) ||
                    TREG(xID)->HasFlag(RF_ROCKTYPE) ||
                    TREG(xID)->HasFlag(RF_STREAMER) ||
                    TREG(xID)->HasFlag(RF_CHASM))
                    if (!TREG(xID)->HasFlag(RF_NOGEN)) {
                        *lv++ = xID;
                        *lv++ = 1;
                    }
        }
```

## Region Lists

**List constants** (`Defines.h:3513-3520`):

```cpp
#define ROOM_WEIGHTS          4
#define FURNISHINGS           6
#define WALL_COLOURS          7
#define FLOOR_COLOURS         8
#define CORRIDOR_WEIGHTS      11
#define ENCOUNTER_LIST        10
```

### FURNISHINGS List

Defines furnishing patterns for rooms:

```
Lists:
  * FURNISHINGS FU_SPLATTER $"rock column";
```

Format: `FU_* pattern` followed by terrain/item/feature resource.

### WALL_COLOURS / FLOOR_COLOURS Lists

Override glyph colors for region's walls/floors:

```
Lists:
  * WALL_COLOURS WHITE GREY SHADOW CYAN,
  * FLOOR_COLOURS GREEN;
```

**Application** (`MakeLev.cpp:2820-2842`):

```cpp
if (TREG(regID)->GetList(WALL_COLOURS, ColorList, 16)) {
    for (c = 0; ColorList[c]; c++)
        ;
    WallID = TREG(regID)->Walls;
    for (x = cPanel.x1; x <= cPanel.x2; x++)
        for (y = cPanel.y1; y <= cPanel.y2; y++)
            if (TerrainAt(x, y) == WallID) {
                At(x, y).Glyph = GLYPH_VALUE(GLYPH_ID_VALUE(At(x, y).Glyph),
                                             ColorList[random(c)]);
                At(x, y).Shade = false;
            }
}
```

Random color from list applied to each matching tile.

### ENCOUNTER_LIST

Region-specific encounters with weighted selection:

```
Lists:
  * ENCOUNTER_LIST
      50 CONSTRAINED_ENC($"lone dark-dwelling beast",MA_AQUATIC)
      40 CONSTRAINED_ENC($"pack encounter",MA_AQUATIC)
      20 CONSTRAINED_ENC($"tribal warband",MA_AQUATIC)
         $"water creatures"
       5 CONSTRAINED_ENC($"uniform classed group",MA_AQUATIC)
      ;
```

Format: `weight encounter` pairs. `CONSTRAINED_ENC(encounter, constraint)` limits to specific monster types.

## Grid-Based Regions (RM_SHAPED)

Regions with `RoomTypes: RM_SHAPED` use a predefined grid map.

### Grid Format

**Source:** `MakeLev.cpp:969-996`

```cpp
/* The default meanings of map-definition characters:
 * '#' Region's Wall, priority 80
 * '%' Standard Wall, priority 10
 * '1' to '9'  Monster N*2 levels OOD
 * '$' Pile of Gold
 * 'g' Good Item
 * 'G' Great Item
 * 't' Trap
 * 'T' *Badass* Trap
 * '.' Region's Floor
 * '+' Door
 * 'A' Altar
 * '~' Water
 * '_' Unworked Stone
 * ',' Floor, of Corridor Region
 * 'i' Potion or Scroll
 * 'I' Normal Item
 * '-' Trapped Door
 * '|' Tough Door
 * 'X' Indestructable Rock
 * 'V' Vault Door
 * 'v' 'Vault Warning' Region
 * 'G' City Guardspost
 * '@' Start the Player Here
 * 'S' Secret Door
 * '*' Call script EV_MAPSYMBOL
 */
```

### Custom Tiles

Regions can define custom tile meanings:

```
Tiles:
  'o': $"floor" with $"pillar",
  'b': $"bloodstain",
  '1': $"bloodstain" with $"corpse" of $"human",
  '>': $"floor" with $"cave entrance" [TILE_START];
```

Tile flags:
- `TILE_START` - Player spawn point
- `TILE_ITEM` - Place item
- `TILE_MONSTER` - Place monster
- `TILE_PEACEFUL` - Peaceful creature
- `TILE_HOSTILE` - Hostile creature
- `TILE_GUARDING` - Guarding creature
- `TILE_ASLEEP` - Sleeping creature
- `TILE_NO_PARTY` - Separate party ID

### Grid Processing

**Source:** `MakeLev.cpp:998-1102`

```cpp
bool flipHoriz = random(2) != 0;
bool flipVert = random(2) != 0;

for (x = 0; x < m->sx; x++)
    for (y = 0; y < m->sy; y++) {
        ch = gr[(flipHoriz ? ((m->sx - 1) - x) : x) +
                (flipVert ? ((m->sy - 1) - y) : y) * m->sx];
        At(r.x1 + x, r.y1 + y).isVault = true;
        if (t = MapLetterArray[ch]) {
            WriteAt(r, r.x1 + x, r.y1 + y, t->tID, regID, PRIO_VAULT);
            // Process tile flags, items, monsters, features...
        }
    }
```

**Key behaviors:**
- 50% chance horizontal flip
- 50% chance vertical flip
- Tiles marked with `isVault = true`
- Written at `PRIO_VAULT` (100) priority

## Example Region Definitions

### Simple Room

```
Region "Bare Cavern" : RF_ROOM
  { Desc: "This cavern is distinguished only by...";
    Walls: $"Dungeon Wall"; Floor: $"Floor";
    Door: $"oak door"; RoomTypes: RM_LIFECAVE;
    Lists:
      * WALL_COLOURS WHITE;
  }
```

### Corridor with Custom Behavior

```
Region "Twisty Little Passage" : RF_CORRIDOR
  { Desc: "This awkward, twisting tunnel...";
    Walls: $"dungeon wall"; Floor: $"floor"; RoomTypes: 0;
    Door: $"oak door"; Size: SZ_MEDIUM;
    On Event EV_MOVE {
      // Custom movement penalty code
    };
    Constants:
      * TURN_CHANCE       35,
      * SEGMENT_MINLEN    1,
      * SEGMENT_MAXLEN    4,
      * STUBBORN_CORRIDOR 30;
  }
```

### River Streamer

```
Region "Underground River" : RF_RIVER
  { Floor: $"shallow water";
    Lists:
      * ENCOUNTER_LIST
          50 CONSTRAINED_ENC($"lone dark-dwelling beast",MA_AQUATIC)
          ...;
  }
```

### Vault with Grid

```
Region "Lesser Vault;1" : RF_ROOM
  { Walls: $"Dungeon Wall"; Floor: $"Floor";
    Door: $"vault door"; RoomTypes: RM_SHAPED;
    Flags: RF_VAULT;
    Grid: {:
      %%%%%%%%%%%%%%%%%%%%%%%
      %.....................%
      %.#########+#########.%
      %.#.1.....1....1.+..#.%
      ...
      :};
  }
```

## Region Constants

Regions can override dungeon-wide constants:

```
Constants:
  * TURN_CHANCE       35,
  * SEGMENT_MINLEN    1,
  * SEGMENT_MAXLEN    4,
  * STUBBORN_CORRIDOR 30,
  * BLOB_WITH $"shallow water";
```

These override the defaults from the dungeon definition when the region is active.

## Region Events

Regions support event handlers for scripted behavior:

```
On Event EV_BIRTH {
  // Called when region is placed
};

On Event EV_MOVE {
  // Called when creature moves in region
};

On Event EV_REST {
  // Called when player tries to rest
};
```

Return values:
- `NOTHING` - Continue with default behavior
- `DONE` - Event handled, stop processing
- `ABORT` - Prevent the action
