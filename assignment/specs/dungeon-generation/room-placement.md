# Room Placement Specification

## Verification Status

| Section | Status | Source Lines |
|---------|--------|--------------|
| Room type switch cases | VERIFIED | 2443-2810 |
| Weight selection algorithm | VERIFIED | 2359-2390 |
| Region selection | VERIFIED | 2395-2422 |
| One-time use logic | VERIFIED | 2364-2377, 2420-2422 |
| Room type enum values | VERIFIED | inc/Defines.h lines 869-895 |
| Post-processing steps | PARTIAL | 2818-2898 |

**Legend:**
- VERIFIED: Code snippets taken directly from source
- PARTIAL: Logic confirmed, details may need verification
- UNVERIFIED: Inferred from context, needs source confirmation

## Source Location

`src/MakeLev.cpp`, function `Map::DrawPanel()` (lines 2316-2899)

## Room Selection Algorithm

### 1. Weight-Based Type Selection

```cpp
// Sum all room type weights from RM_WEIGHTS list
weighting_sum = 0;
for (i = 0; RM_Weights[i * 2 + 1]; i++)
    weighting_sum += max(0, RM_Weights[i * 2 + 1]);

// Random selection based on weights
c = random(weighting_sum);
for (i = 0; RM_Weights[i * 2 + 1]; i++) {
    if (c < weight) goto RM_Chosen;
    else c -= weight;
}
```

### 2. Region Selection

After room type is chosen, a compatible region is selected:

```cpp
// For each region in ROOM_WEIGHTS list:
// - Must support the chosen room type (RoomTypes & BIT(RType))
// - Must meet depth requirement (DepthCR >= Region.Depth)
// - Vaults require MIN_VAULT_DEPTH
// - Skip corridors (RF_CORRIDOR flag)
// - Skip regions already used this level
```

### 3. One-Time Use

Each region can only be used once per level. If all regions for a room type are exhausted, the room type is removed from selection (`RM_Weights[index] = -1`).

## Room Types

**Source:** `inc/Defines.h` lines 869-895

| Constant | Value | Description (from source comments) |
|----------|-------|-------------|
| `RM_ANY` | -1 | (wildcard) |
| `RM_NOROOM` | 0 | Empty panel; no room |
| `RM_NORMAL` | 1 | Single Small square |
| `RM_LARGE` | 2 | (1d4 - panel edge) |
| `RM_CROSS` | 3 | Two overlapping rectangles |
| `RM_OVERLAP` | 4 | 2-4 overlapping squares |
| `RM_ADJACENT` | 5 | Four squares with shared center |
| `RM_AD_ROUND` | 6 | As ADJACENT, but with circles |
| `RM_AD_MIXED` | 7 | As ADJACENT, but with either |
| `RM_CIRCLE` | 8 | Just a big circle |
| `RM_OCTAGON` | 9 | Roughly rounded room |
| `RM_DOUBLE` | 10 | Room within a room |
| `RM_PILLARS` | 11 | Room with pillars |
| `RM_CASTLE` | 12 | "Castle" / subdivided big room |
| `RM_CHECKER` | 13 | Checkerboard |
| `RM_BUILDING` | 14 | Large, Subdivided |
| `RM_DESTROYED` | 15 | Area collapsed; 10% rock, 30% rubble |
| `RM_GRID` | 16 | Room filled with Furnishings[n] as even grid |
| `RM_LIFECAVE` | 17 | Game-of-Life smooth caverns |
| `RM_RCAVERN` | 18 | Repeated-L rough caverns |
| `RM_LCIRCLE` | 19 | Large Circle |
| `RM_SHAPED` | 20 | Special Shapes (i.e., resource room maps) |
| `RM_LIFELINK` | 21 | Game of Life w. Linked Regions |
| `RM_RANDTOWN` | 22 | Small, Random Town in Dungeon |
| `RM_MAZE` | 23 | Random Maze fills most of panel |
| `RM_DIAMONDS` | 24 | Grid of Diamond squares |
| `RM_LAST` | 32 | (sentinel) |

## Room Type Details

### RM_NORMAL (Standard Room)

```cpp
sx = ROOM_MINX + random(ROOM_MAXX - ROOM_MINX);
sy = ROOM_MINY + random(ROOM_MAXY - ROOM_MINY);
r = cPanel.PlaceWithinSafely(sx, sy);
WriteRoom(r, regID);
```

- Size: `ROOM_MINX` to `ROOM_MAXX` x `ROOM_MINY` to `ROOM_MAXY`
- Placed randomly within panel bounds
- Uses `WriteRoom()` to draw floor and walls

### RM_CIRCLE (Circular Room)

```cpp
r = cPanel.PlaceWithinSafely(sx, sy);
WriteCircle(r, regID);
WriteWalls(r, regID);
```

- Same sizing as normal room
- Uses `WriteCircle()` for circular floor
- `WriteWalls()` adds walls around non-floor tiles

### RM_LCIRCLE (Large Circle)

```cpp
sx = max(PANEL_SIZEX/2, PANEL_SIZEX - (random(5) + 5));
sy = max(PANEL_SIZEY/2, PANEL_SIZEY - (random(5) + 5));
```

- Minimum half panel size
- Maximum: panel size minus 5-10 tiles

### RM_LARGE (Large Rectangle)

```cpp
sx = max(PANEL_SIZEX/2, PANEL_SIZEX - (random(8) + 2));
sy = max(PANEL_SIZEY/2, PANEL_SIZEY - (random(8) + 2));
```

- Similar to large circle but rectangular
- Uses `WriteRoom()`

### RM_MAZE

```cpp
sx = max(PANEL_SIZEX/2, PANEL_SIZEX - (random(8) + 2));
sy = max(PANEL_SIZEY/2, PANEL_SIZEY - (random(8) + 2));
WriteMaze(r, regID);
```

- Large area filled with maze pattern
- Uses `WriteMaze()` algorithm

### RM_ADJACENT / RM_AD_ROUND / RM_AD_MIXED

Four sub-rooms sharing a center point:

```
 ___
|  |_______
|r        |
|      r2 |
---  +   ----
| r3   r4|
|     ___|
|____|
```

- Panel divided into quadrants
- Each quadrant has 75% chance of having a room
- At least one room guaranteed
- `RM_ADJACENT`: All rectangles
- `RM_AD_ROUND`: All circles
- `RM_AD_MIXED`: Random mix

### RM_OVERLAP

2-4 overlapping rectangular rooms:

```cpp
// First room
WriteRoom(r, regID);

// Second room (must overlap first)
do r2 = cPanel.PlaceWithinSafely(sx, sy);
while (!r.Overlaps(r2));
WriteRoom(r2, regID);

// Third room (33% chance, must overlap existing)
// Fourth room (50% chance, must overlap existing)
```

- Creates organic, irregular shapes
- Each room is 2/3 normal size

### RM_OCTAGON

```cpp
sx = max(sx, 9);  // Minimum 9x9 for octagon
sy = max(sy, 9);
WriteOctagon(r, regID);
WriteWalls(r, regID);
```

- Requires minimum 9x9 size
- Uses `WriteOctagon()` for eight-sided shape

### RM_DIAMONDS

Chain of connected diamond-shaped rooms:

```cpp
i = 1 + random(7);  // 1-7 diamonds
do {
    WriteDiamond(x, y, regID);
    // Move in random diagonal direction
    d = NORTHEAST + random(4);
    x += DirX[d] * 6;
    y += DirY[d] * 6;
    // Place door at connection point
    MakeDoor(sx, sy, door);
} while (c != i);
```

- 1-7 diamonds in a chain
- Diamonds connected by doors
- Inner walls marked immutable (priority 60)

### RM_CASTLE / RM_BUILDING

Complex structure with internal divisions:

```cpp
IndividualRooms = random(2);
WriteRoom(r, regID);
WriteCastle(r, regID);  // Recursive subdivision
```

- Large room subdivided into smaller rooms
- `WriteCastle()` recursively divides space
- Each sub-room can be populated independently
- `IndividualRooms` flag controls population behavior

### RM_CHECKER

```cpp
for (x = r.x1+1; x < r.x2; x++)
    for (y = r.y1+1; y < r.y2; y++)
        if ((x + y) % 2)
            WriteAt(x, y, WallID, ...);
```

- Normal room with checkerboard pillar pattern
- Every other tile (where `(x+y) % 2`) is a wall

### RM_PILLARS / RM_GRID

```cpp
for (x = r.x1+1; x < r.x2; x++)
    for (y = r.y1+1; y < r.y2; y++)
        if (!((x-r.x1) % 2) && !((y-r.y1) % 2) && random(100) < 95)
            WriteAt(x, y, WallID, ...);
```

- Regular 2x2 grid of pillars/furnishings
- `RM_PILLARS`: Uses `TERRAIN_PILLAR`
- `RM_GRID`: Uses region's `Furnishings[0]`
- 5% chance each pillar is missing (variety)

### RM_CROSS

```cpp
WriteCross(r, regID);
WriteWalls(r, regID);
```

- Cross/plus-shaped room
- Uses `WriteCross()` algorithm

### RM_RCAVERN

```cpp
WriteRCavern(cPanel, regID);
```

- Random cavern filling entire panel
- Organic, irregular shape

### RM_LIFECAVE

```cpp
WriteLifeCave(cPanel, regID);
WriteWalls(cPanel, regID);
```

- Cellular automata-based cave generation
- Natural, organic cave shapes
- "Conway's Game of Life" style algorithm

### RM_DOUBLE

Room within a room:

```cpp
WriteRoom(r, regID);           // Outer room
// Shrink rect
r.x1 += 2; r.y1 += 2;
r.x2 -= 2; r.y2 -= 2;
// Draw inner walls
for (x = r.x1; x <= r.x2; x++) {
    WriteAt(x, r.y1, WallID, ...);
    WriteAt(x, r.y2, WallID, ...);
}
// Add random doors
MakeDoor(x, y, door);
```

- Outer rectangular room
- Inner rectangular wall with random doors

### RM_SHAPED

```cpp
sx = TREG(regID)->sx;
sy = TREG(regID)->sy;
r = cPanel.PlaceWithinSafely(sx, sy);
WriteMap(r, regID);
```

- Predefined shape from region's Grid
- Size determined by region's `sx`, `sy`
- Uses `WriteMap()` to place predefined tiles

## Region Flags Affecting Room Shape

| Flag | Effect |
|------|--------|
| `RF_ODD_WIDTH` | Ensure room width is odd |
| `RF_ODD_HEIGHT` | Ensure room height is odd |
| `RF_VAULT` | Requires `MIN_VAULT_DEPTH` |
| `RF_CORRIDOR` | Skip for room selection |

## Post-Room Processing

After room is drawn:

1. **Floor Colors**: If region has `FLOOR_COLOURS` list, randomize floor tile colors
2. **Wall Colors**: If region has `WALL_COLOURS` list, randomize wall tile colors
3. **PRE(EV_BIRTH) Event**: Region script can abort/modify room
4. **Blob Placement**: If `BLOB_WITH` constant set, add terrain blobs
5. **Lighting**: `LightPanel()` adds torches based on `TORCH_DENSITY`
6. **Furnishing**: `FurnishArea()` adds furniture
7. **Population**: `PopulatePanel()` adds monsters/items
8. **EV_BIRTH Event**: Final region script execution

## Write Functions

| Function | Purpose |
|----------|---------|
| `WriteRoom(r, regID)` | Rectangular room with walls |
| `WriteBox(r, regID)` | Rectangular floor only (no walls) |
| `WriteCircle(r, regID)` | Circular floor |
| `WriteWalls(r, regID)` | Add walls around non-floor tiles |
| `WriteOctagon(r, regID)` | Eight-sided room |
| `WriteDiamond(x, y, regID)` | Diamond-shaped room |
| `WriteCross(r, regID)` | Cross-shaped room |
| `WriteMaze(r, regID)` | Maze pattern |
| `WriteCastle(r, regID)` | Recursive subdivision |
| `WriteRCavern(r, regID)` | Random cavern |
| `WriteLifeCave(r, regID)` | Cellular automata cave |
| `WriteMap(r, regID)` | Predefined tile grid |
