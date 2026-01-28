# Terrain Assignment Specification

## Verification Status

| Section | Status | Source |
|---------|--------|--------|
| WriteAt function | VERIFIED | MakeLev.cpp:232-330 |
| WriteRoom function | VERIFIED | MakeLev.cpp:332-353 |
| WriteBox function | VERIFIED | MakeLev.cpp:355-365 |
| WriteCircle function | VERIFIED | MakeLev.cpp:368-401 |
| WriteWalls function | VERIFIED | MakeLev.cpp:403-417 |
| WriteLifeCave function | VERIFIED | MakeLev.cpp:419-468 |
| WriteStreamer function | VERIFIED | MakeLev.cpp:841-911 |
| WriteBlobs function | VERIFIED | MakeLev.cpp:913-951 |
| TF_* flags | VERIFIED | Defines.h:677-703 |
| Terrain constants | VERIFIED | Defines.h:3577-3622 |
| TRegion structure | VERIFIED | Res.h:630-643 |
| TTerrain structure | VERIFIED | Res.h:645-660 |

## Core Write Function

### WriteAt

**Source:** `MakeLev.cpp:232-330`

```cpp
void Map::WriteAt(Rect &r, int16 x, int16 y, rID terID, rID regID, int32 Pri, bool Force)
```

**Parameters:**
- `r` - Bounding rect (for events)
- `x, y` - Tile coordinates
- `terID` - Terrain resource ID
- `regID` - Region resource ID
- `Pri` - Priority value
- `Force` - If true, ignore priority check

**Algorithm:**

```cpp
// Handle feature resources as special case (lines 242-247)
if (TTER(terID)->Type == T_TFEATURE) {
    WriteAt(r, x, y, FIND("floor"), regID, Pri, Force);
    Feature *ft = new Feature(TFEAT(terID)->Image, terID, T_FEATURE);
    ft->PlaceAt(this, x, y);
    return;
}

// Priority check (line 253-254)
if (At(x, y).Priority > (uint32)Pri && !Force)
    return;

// Map edge protection (lines 255-257)
if (x == 0 || y == 0 || x == sizeX - 1 || y == sizeY - 1)
    if (!Force && Pri < PRIO_MAX && !(RES(dID)->Type == T_TREGION))
        return;

// Track open tiles for corridor endpoints (lines 260-264)
if (OpenC < 2048 && !t->HasFlag(TF_SOLID)) {
    OpenX[OpenC] = (uint8)x;
    OpenY[OpenC] = (uint8)y;
    OpenC++;
}

// Remove creatures if terrain becomes incompatible (lines 269-271)
if (FCreatureAt(x, y))
    if (TTER(terID)->HasFlag(TF_SOLID) ||
        (FCreatureAt(x, y)->HasMFlag(M_AQUATIC) && !TTER(terID)->HasFlag(TF_WATER)))
        FCreatureAt(x, y)->Remove(true);

// Terrain/Region lookup tables (lines 273-301)
// Uses TerrainList[] and RegionList[] arrays
// Stores index (0-255) in LocationInfo

// Set tile properties (lines 303-311)
At(x, y).Glyph = t->Image;
At(x, y).Region = RegionVal;
At(x, y).Terrain = TerrainVal;
At(x, y).Opaque = t->HasFlag(TF_OPAQUE);
At(x, y).Obscure = t->HasFlag(TF_OBSCURE);
At(x, y).Solid = t->HasFlag(TF_SOLID);
At(x, y).Shade = t->HasFlag(TF_SHADE);
At(x, y).Priority = Pri;
At(x, y).isWall = t->HasFlag(TF_WALL);

// Special terrain initialization (lines 314-324)
if (t->HasFlag(TF_SPECIAL)) {
    EventInfo e;
    e.Event = EV_INITIALIZE;
    t->Event(e, terID);
}

// Torch tracking (lines 325-328)
if (t->HasFlag(TF_TORCH)) {
    TorchPos = x + y * 256;
    TorchList.Add(TorchPos);
}
```

## Room Shape Functions

### WriteRoom

**Source:** `MakeLev.cpp:332-353`

```cpp
void Map::WriteRoom(Rect &r, rID regID) {
    rID WallID, FloorID;
    if (r.x2 - r.x1 <= 1) return;
    if (r.y2 - r.y1 <= 1) return;

    WallID = TREG(regID)->Walls;
    FloorID = TREG(regID)->Floor;

    for (int16 x = r.x1; x <= r.x2; x++)
        for (int16 y = r.y1; y <= r.y2; y++)
            if (x == r.x1 || x == r.x2 || y == r.y1 || y == r.y2)
                WriteAt(r, x, y, WallID, regID, PRIO_ROOM_WALL);
            else
                WriteAt(r, x, y, FloorID, regID, PRIO_ROOM_FLOOR);

    // Track corners for corridor connections
    Corners[nCorners++] = (r.x1 + 1) + (r.y1 + 1) * 256;
    Corners[nCorners++] = (r.x2 - 1) + (r.y1 + 1) * 256;
    Corners[nCorners++] = (r.x1 + 1) + (r.y2 - 1) * 256;
    Corners[nCorners++] = (r.x2 - 1) + (r.y2 - 1) * 256;

    // Track center
    Centers[nCenters++] = (r.x1 + (r.x2 - r.x1) / 2) +
        (r.y1 + (r.y2 - r.y1) / 2) * 256;
}
```

- Walls on perimeter, floor inside
- Wall priority: `PRIO_ROOM_WALL` (20)
- Floor priority: `PRIO_ROOM_FLOOR` (70)
- Minimum size: 2x2 (else returns early)

### WriteBox

**Source:** `MakeLev.cpp:355-365`

```cpp
void Map::WriteBox(Rect &r, rID regID) {
    rID FloorID = TREG(regID)->Floor;
    if (r.x2 - r.x1 <= 1) return;
    if (r.y2 - r.y1 <= 1) return;

    for (uint8 x = r.x1; x <= r.x2; x++)
        for (uint8 y = r.y1; y <= r.y2; y++)
            WriteAt(r, x, y, FloorID, regID, PRIO_ROOM_FLOOR);
}
```

- Floor only, no walls
- Used for adjacent room shapes where walls added later

### WriteCircle

**Source:** `MakeLev.cpp:368-401`

```cpp
void Map::WriteCircle(Rect &r, rID regID) {
    // Calculate radius from bounding rect
    if (r.x2 - r.x1 > r.y2 - r.y1)
        radius = r.y2 - r.y1;
    else
        radius = r.x2 - r.x1;
    radius /= 2;
    if (radius % 2) radius++;  // Round up to even

    cx = r.x1 + (r.x2 - r.x1) / 2;
    cy = r.y1 + (r.y2 - r.y1) / 2;

    for (x = r.x1; x < r.x2 + 1; x++)
        for (y = r.y1; y < r.y2 + 1; y++)
            if (dist(x, y, cx, cy) <= radius)
                WriteAt(r, x, y, FloorID, regID, PRIO_ROOM_FLOOR);
}
```

- Uses distance check for circular shape
- Minimum size: 5x5
- Walls added later by `WriteWalls()`

### WriteWalls

**Source:** `MakeLev.cpp:403-417`

```cpp
void Map::WriteWalls(Rect &r, rID regID) {
    FloorID = TREG(regID)->Floor;
    WallID = TREG(regID)->Walls;

    for (x = max(1, r.x1 - 1); x < min(r.x2 + 2, sizeX - 1); x++)
        for (y = max(1, r.y1 - 1); y < min(r.y2 + 2, sizeY - 1); y++)
            if (TerrainAt(x, y) != FloorID)
                if (TerrainAt(x, y + 1) == FloorID || TerrainAt(x + 1, y) == FloorID ||
                    TerrainAt(x, y - 1) == FloorID || TerrainAt(x - 1, y) == FloorID ||
                    TerrainAt(x + 1, y + 1) == FloorID || TerrainAt(x - 1, y - 1) == FloorID ||
                    TerrainAt(x - 1, y + 1) == FloorID || TerrainAt(x + 1, y - 1) == FloorID)
                    WriteAt(r, x, y, WallID, regID, PRIO_ROOM_WALL);
}
```

- Adds walls adjacent to floor tiles (all 8 directions)
- Checks one tile beyond bounding rect
- Used after `WriteCircle`, `WriteOctagon`, etc.

## Cave Generation

### WriteLifeCave (Cellular Automata)

**Source:** `MakeLev.cpp:419-468`

```cpp
void Map::WriteLifeCave(Rect &r, rID regID) {
    const int buffer = 3;

    // Initialize border as solid
    for (x = r.x1; x <= r.x2; x++)
        for (y = r.y1; y <= r.y2; y++)
            At(x, y).Visibility = 1;

    // Random fill interior (based on LIFE_PERCENT)
    for (x = r.x1 + buffer; x <= r.x2 - buffer; x++)
        for (y = r.y1 + buffer; y <= r.y2 - buffer; y++)
            At(x, y).Visibility = (random(100) > (int16)Con[LIFE_PERCENT] - 1) ? 0 : 1;

    // 20 iterations of cellular automata
    for (i = 0; i != 20; i++) {
        for (x = r.x1 + buffer; x <= r.x2 - buffer; x++)
            for (y = r.y1 + buffer; y <= r.y2 - buffer; y++) {
                // Count neighbors
                j = (8 adjacent cells summed);

                if (j >= 5)      // 5+ walls -> become wall
                    At(x, y).LifeFlag = true;
                else if (j <= 3) // 3 or fewer walls -> become floor
                    At(x, y).LifeFlag = false;
                // 4 neighbors -> no change
            }

        // Apply changes
        for (...)
            At(x, y).Visibility = At(x, y).LifeFlag;
    }

    // Write final terrain
    for (x = r.x1 + buffer; x <= r.x2 - buffer; x++)
        for (y = r.y1 + buffer; y <= r.y2 - buffer; y++)
            if (!At(x, y).Visibility)
                WriteAt(r, x, y, FloorID, regID, PRIO_ROOM_FLOOR);
}
```

**Key parameters:**
- `LIFE_PERCENT` (constant index 52): Initial fill percentage
- `buffer = 3`: Solid border around edge
- 20 iterations of automata rules

**Automata rules:**
- 5+ solid neighbors → become solid
- 3 or fewer solid neighbors → become floor
- 4 neighbors → unchanged

## Streamer Generation

### WriteStreamer

**Source:** `MakeLev.cpp:841-911`

```cpp
void Map::WriteStreamer(Rect &r, uint8 sx, uint8 sy, Dir d, rID regID) {
    rID terID = TREG(regID)->Floor;
    isWater = TTER(terID)->HasFlag(TF_WATER);

    if (TREG(regID)->HasFlag(RF_RIVER)) {
        isRiver = true;
        Width = MWidth = 2 + random(4);  // 2-5 tiles wide
        // Start at map edge
        if (sx > sy) { sy = 0; d = SOUTHEAST or SOUTHWEST; }
        else { sx = 0; d = SOUTHEAST or NORTHEAST; }
    } else {
        Width = 1;
        MWidth = 2 + random((int16)Con[MAX_STREAMER_WIDTH]);
        // Random diagonal direction
        if (d == -1)
            d = SOUTHEAST/SOUTHWEST/NORTHEAST/NORTHWEST;
    }

    if (TREG(regID)->HasFlag(RF_CHASM))
        MWidth = max(4, MWidth + 1);

    // Meander ratios
    rx = 2 + random(10);
    ry = 2 + random(10);

    while (Width && InBounds(sx, sy)) {
        // Non-rivers vary width
        if (!isRiver && !random(13)) {
            if (midpoint) Width--;
            else Width++;
        }

        // Move based on meander ratios
        if (random(rx + ry) + 1 <= rx)
            sx += DirX[d];
        else
            sy += DirY[d];

        // Write terrain in Width x Width square
        for (ix = sx - Width/2; ix < sx - Width/2 + Width; ix++)
            for (iy = sy - Width/2; iy < sy - Width/2 + Width; iy++) {
                int prio = PRIO_ROCK_STREAMER;  // 60
                if (TREG(regID)->HasFlag(RF_CHASM) || TREG(regID)->HasFlag(RF_RIVER))
                    prio = PRIO_RIVER_STREAMER;  // 90
                WriteAt(r, ix, iy, terID, regID, prio);
            }
    }
}
```

**Key behavior:**
- Rivers start at edge, fixed width
- Non-rivers start anywhere, varying width
- Chasms minimum width 4
- Priority: `PRIO_ROCK_STREAMER` (60) or `PRIO_RIVER_STREAMER` (90)

## Terrain Flags

**Source:** `Defines.h:677-703`

```cpp
#define TF_SOLID      1   // Blocks movement
#define TF_OPAQUE     2   // Blocks vision
#define TF_OBSCURE    3   // Partial vision block
#define TF_SHADE      4   // Shaded floor glyph
#define TF_SPECIAL    5   // Has EV_INITIALIZE handler
#define TF_WARN       6   // Warning terrain
#define TF_WATER      7   // Water terrain
#define TF_TORCH      10  // Light source
#define TF_EFFECT     11  // Has terrain effect
#define TF_SHOWNAME   12  // Show terrain name
#define TF_NOGEN      13  // Don't generate randomly
#define TF_INTERIOR   14  // Show as wall from outside
#define TF_TREE       15  // Tree terrain
#define TF_DEEP_LIQ   16  // Deep liquid
#define TF_UNDERTOW   17  // Has undertow
#define TF_FALL       18  // Fall through (chasm)
#define TF_STICKY     19  // Sticky terrain
#define TF_WALL       20  // Wall terrain type
#define TF_BSOLID     21  // Blocks rays/blasts
#define TF_MSOLID     22  // Monster-solid
#define TF_CONCEAL    23  // Hides items
#define TF_VERDANT    24  // Natural growth
#define TF_LOCAL_LIGHT 25 // Self-lit
#define TF_DEPOSIT    26  // Mining deposit
#define TF_PIT        27  // Pit terrain
#define TF_LAST       28
```

## Terrain Constants

**Source:** `Defines.h:3577-3622`

```cpp
#define MAX_STREAMER_WIDTH    5  /* Maximum (non-river) streamer width */
#define MAX_STREAMERS         7  /* Maximum number of streamers per level */
#define TERRAIN_MAPEDGE       8  /* Terrain for impassable map border */
#define TERRAIN_ROCK          9  /* Default level fill before generation */
#define LIFE_PERCENT          52 /* Game of life cave fill percentage */
```

## Region Structure

**Source:** `Res.h:630-643`

```cpp
class TRegion: public Resource {
    int8 Depth, Size;
    rID Walls, Floor, Door;     // Terrain/Feature references
    int8 MTypes[4];             // Monster types allowed
    rID Furnishings[6];         // Furnishing terrain types
    uint32 RoomTypes;           // Bitmask of allowed RM_* types
    uint8 sx, sy;               // Size for shaped regions
    hText Grid;                 // Predefined map grid
    uint8 Flags[(RF_LAST/8)+1]; // Region flags
};
```

## Region Examples

**Source:** `lib/dungeon.irh:2511-2556`

```
Region "Winding Corridor" : RF_CORRIDOR {
    Walls: $"Dungeon Wall";
    Floor: $"Floor";
    Door: $"oak door";
    Flags: RF_STAPLE;
    RoomTypes: 0;
    Size: SZ_LARGE;
}

Region "Icy Corridor": RF_CORRIDOR {
    Walls: $"ice Wall";
    Floor: $"ice Floor";
    Door: $"ice door";
    RoomTypes: 0;
    Size: SZ_LARGE;
}

Region "Flooded Corridor": RF_CORRIDOR {
    Walls: $"dungeon Wall";
    Floor: $"shallow water";
    Door: $"oak door";
    RoomTypes: 0;
    Size: SZ_LARGE;
}
```

## Terrain Examples

**Source:** `lib/dungeon.irh:514-588`

```
Terrain "Solid Rock" {
    Image: brown GLYPH_ROCK;
    Mat: MAT_GRANITE;
    Flags: TF_SOLID, TF_OPAQUE, TF_WALL;
}

Terrain "Dungeon Wall" {
    Image: grey GLYPH_WALL;
    Mat: MAT_GRANITE;
    Flags: TF_SOLID, TF_OPAQUE, TF_WALL;
}

Terrain "Wall Torch" {
    Image: yellow GLYPH_WALL;
    Mat: MAT_GRANITE;
    Flags: TF_SOLID, TF_OPAQUE, TF_TORCH, TF_INTERIOR, TF_WALL;
}

Terrain "Ice Wall" {
    Image: bright blue GLYPH_SOLID on blue;
    Mat: MAT_ICE;
    Flags: TF_SOLID, TF_WALL, TF_SPECIAL;
    On Event EV_MAGIC_XY { /* melts with fire */ };
}
```

## Priority System

Terrain priority controls overwrite behavior. Higher priority terrain overwrites lower.

| Priority | Constant | Use |
|----------|----------|-----|
| 1 | `PRIO_EMPTY` | Initial rock fill |
| 10 | `PRIO_CORRIDOR_WALL` | Corridor walls |
| 20 | `PRIO_ROOM_WALL` | Room walls |
| 30 | `PRIO_ROOM_WALL_TORCH` | Wall torches |
| 40 | `PRIO_ROOM_WALL_MODIFIER` | Modified walls |
| 50 | `PRIO_PILLARS` | Room pillars |
| 60 | `PRIO_ROCK_STREAMER` | Rock-type streamers |
| 65 | `PRIO_DEPOSIT` | Mining deposits |
| 70 | `PRIO_ROOM_FLOOR` | Room/corridor floors |
| 80 | `PRIO_ROOM_FURNITURE` | Furnishings, blobs |
| 90 | `PRIO_RIVER_STREAMER` | Rivers, chasms |
| 100 | `PRIO_VAULT` | Vault terrain |
| 110 | `PRIO_FEATURE_FLOOR` | Feature placement floor |
| 120 | `PRIO_MAX` | Maximum (forced writes) |
