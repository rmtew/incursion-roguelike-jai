# Corridor Generation Specification

## Verification Status

| Section | Status | Source |
|---------|--------|--------|
| Tunnel function signature | VERIFIED | MakeLev.cpp:3395 |
| TT_* flags | VERIFIED | MakeLev.cpp:76-82 |
| PRIO_* constants | VERIFIED | Defines.h:4307-4320 |
| Corridor constants | VERIFIED | Defines.h:3593-3596, 3619 |
| MAX_CORRIDOR_LENGTH | VERIFIED | Defines.h:4331 |
| CorrectDir function | VERIFIED | MakeLev.cpp:3611-3639 |
| Corridor region selection | VERIFIED | MakeLev.cpp:3406-3423 |
| Main loop logic | VERIFIED | MakeLev.cpp:3460-3564 |
| WriteCorridor logic | VERIFIED | MakeLev.cpp:3566-3608 |

## Source Location

`src/MakeLev.cpp`, function `Map::Tunnel()` (lines 3395-3609)

## Function Signature

```cpp
// MakeLev.cpp:3395
uint16 Map::Tunnel(uint8 sx, uint8 sy, uint8 dx, uint8 dy, uint8 TFlags, Dir StartDir, int8 TType)
```

**Parameters:**
- `sx, sy` - Start coordinates
- `dx, dy` - Destination coordinates
- `TFlags` - Tunnel termination flags (see below)
- `StartDir` - Initial direction (-1 for auto-select)
- `TType` - Tunnel type (passed but appears unused in main logic)

**Returns:** `uint16` - Final position as `x + y*256`

## Tunnel Termination Flags

**Source:** `MakeLev.cpp:76-82`

```cpp
#define TT_CONNECT  0x01  /* Terminate when reach area where Connected flag differs from its value at sx/sy. */
#define TT_DIRECT   0x02  /* Always take the most direct route to dx/dy */
#define TT_LENGTH   0x04  /* Terminate if length exceeds given value. */
#define TT_NOTOUCH  0x08  /* Don't "touch" rooms */
#define TT_EXACT    0x10  /* Go to *exact* destination */
#define TT_WANDER   0x20  /* Chance to end after touching 2 rooms. */
#define TT_NATURAL  0x40  /* Curved, natural, non-horizontal tunnels */
```

## Priority Constants

**Source:** `Defines.h:4307-4320`

```cpp
#define PRIO_EMPTY               1
#define PRIO_CORRIDOR_WALL      10
#define PRIO_ROOM_WALL          20
#define PRIO_ROOM_WALL_TORCH    30
#define PRIO_ROOM_WALL_MODIFIER 40
#define PRIO_PILLARS            50
#define PRIO_ROCK_STREAMER      60
#define PRIO_DEPOSIT            65
#define PRIO_ROOM_FLOOR         70
#define PRIO_ROOM_FURNITURE     80
#define PRIO_RIVER_STREAMER     90
#define PRIO_VAULT              100
#define PRIO_FEATURE_FLOOR      110
#define PRIO_MAX                120
```

## Corridor Constants

**Source:** `Defines.h:3593-3596, 3619, 4331`

```cpp
#define TURN_CHANCE           21 /* Percentage chance of a turn in a corridor along a segment. */
#define STUBBORN_CORRIDOR     22 /* Percentage chance that a corridor will be "stubborn". */
#define SEGMENT_MINLEN        23 /* The minimum number of tiles in a corridor segment length. */
#define SEGMENT_MAXLEN        24 /* The maximum number of tiles in a corridor segment length. */
#define CORRIDOR_REGION       49 /* Reference to region to use for tunnel generation. */
#define MAX_CORRIDOR_LENGTH 8192
```

Note: These are constant *indices* into the `Con[]` array, not the values themselves.

## Algorithm

### Phase 1: Region Selection (lines 3404-3427)

```cpp
// MakeLev.cpp:3404
rID regID = Con[CORRIDOR_REGION];

// MakeLev.cpp:3407-3423
if (dist(sx, sy, dx, dy) > 5) {
    // Build candidate list from CorridorWeights
    for (i = 0; CorridorWeights[i * 2]; i++)
        for (x = 0; x < (int16)CorridorWeights[i * 2 + 1]; x++)
            Candidates[c++] = CorridorWeights[i * 2];

    if (c) {
        // Select random region, avoiding already-used ones
        regID = Candidates[random(c)];
        // Mark as used unless RF_STAPLE flag set
        if (!(TREG(regID)->HasFlag(RF_STAPLE)))
            usedInThisLevel[i] = regID;
    }
}

// Load region-specific constants (lines 3425-3427)
for (i = 0; regionConsts[i]; i++)
    if (n = TREG(regID)->GetConst(regionConsts[i]))
        Con[regionConsts[i]] = n;
```

Region-specific constants that can be overridden:
- `TURN_CHANCE`
- `STUBBORN_CORRIDOR`
- `SEGMENT_MINLEN`
- `SEGMENT_MAXLEN`

### Phase 2: Direction Initialization (lines 3441-3456)

```cpp
// MakeLev.cpp:3441-3451
if (StartDir == -1) {
    if (MYABS(sx - dx) > MYABS(sy - dy)) {
        if (sx > dx)
            StartDir = WEST;
        else
            StartDir = EAST;
    } else if (sy > dy)
        StartDir = NORTH;
    else
        StartDir = SOUTH;
}
```

Auto-selects direction based on which axis has greater distance to destination.

### Phase 3: Main Tunneling Loop (lines 3460-3564)

The main loop continues until `stop_flag` is set:

#### Room Touching (lines 3461-3469)

```cpp
// MakeLev.cpp:3461-3469
if (!(TFlags & TT_NOTOUCH))
    if (At(x, y).Priority == PRIO_ROOM_FLOOR)
        if (!(RoomsTouched[y / Con[PANEL_SIZEY]] & (1 << (x / Con[PANEL_SIZEX])))) {
            RoomsFound++;
            RoomsTouched[y / Con[PANEL_SIZEY]] |= 1 << (x / Con[PANEL_SIZEX]);
            if (TFlags & TT_WANDER)
                if (random(RoomsFound) && random(RoomsFound))
                    goto WriteCorridor;  // Early termination
        }
```

- Tracks rooms touched via bitmap `RoomsTouched[]`
- With `TT_WANDER`, increasing chance to stop after touching rooms

#### Door Creation at Corridor Intersection (lines 3471-3473)

```cpp
// MakeLev.cpp:3471-3473
if (At(NEXTX, NEXTY).Solid)
    if (At(NEXTX2, NEXTY2).Priority == PRIO_CORRIDOR_WALL)
        MakeDoor(NEXTX, NEXTY, TREG(RegionAt(NEXTX, NEXTY))->Door);
```

Creates door when corridor is about to intersect another corridor.

#### Connection Check (lines 3478-3481)

```cpp
// MakeLev.cpp:3478-3481
if (TFlags & TT_CONNECT)
    if ((At(x, y).Connected != 0) != startConnected)
        if (!At(x, y).Solid)
            stop_flag = true;
```

With `TT_CONNECT`, stops when reaching area with different connectivity state.

#### Force Turn Conditions (lines 3487-3520)

Turn is forced when:

```cpp
// Near map edge (within 4 tiles)
if ((x + DirX[CurrDir] * 4) > (sizeX - 1) || (x + DirX[CurrDir] * 4) < 0)
    force_turn = true;
if ((y + DirY[CurrDir] * 4) > (sizeY - 1) || (y + DirY[CurrDir] * 4) < 0)
    force_turn = true;

// Hitting vault/special area
if (At(x, y).Priority >= PRIO_VAULT)
    force_turn = true;

// About to write over corridor wall
if (At(NEXTX, NEXTY).Priority == PRIO_CORRIDOR_WALL && At(NEXTX2, NEXTY2).Priority == PRIO_CORRIDOR_WALL)
    force_turn = true;

// About to write over room wall
if (At(x, y).Priority == PRIO_ROOM_WALL && At(NEXTX, NEXTY).Priority == PRIO_ROOM_WALL)
    force_turn = true;

// Reached destination coordinate on current axis
if (x == dx && DirX[CurrDir])
    force_turn = true;
if (y == dy && DirY[CurrDir])
    force_turn = true;

// Segment length exceeded
if (segLength > (int16)Con[SEGMENT_MAXLEN])
    force_turn = true;
```

#### Turn Decision (lines 3522-3532)

```cpp
// MakeLev.cpp:3522-3532
if (force_turn || (segLength > (int16)Con[SEGMENT_MINLEN] && (random(100) < (int16)Con[TURN_CHANCE]))) {
    segLength = 0;
    if (TFlags & TT_DIRECT || random(100) > (int16)Con[STUBBORN_CORRIDOR])
        CurrDir = CorrectDir(x, y, dx, dy, CurrDir);
    else {
        // Random direction change
        OldDir = CurrDir;
        while (CurrDir == OldDir)
            CurrDir = !random(4) ? EAST :
                      !random(3) ? WEST :
                      !random(2) ? NORTH : SOUTH;
    }
}
```

- Turn when forced OR (segment > min length AND random < turn chance)
- With `TT_DIRECT` or low stubborn roll: turn toward destination
- Otherwise: random direction (avoiding same direction)

#### Edge Clamping (lines 3534-3541)

```cpp
// MakeLev.cpp:3534-3541
if (x <= 2)
    CurrDir = EAST;
else if (y <= 2)
    CurrDir = SOUTH;
else if (x >= sizeX - 3)
    CurrDir = WEST;
else if (y >= sizeY - 3)
    CurrDir = NORTH;
```

Hard override when within 2-3 tiles of map edge.

#### Termination Check (lines 3543-3556)

```cpp
// MakeLev.cpp:3550-3556
// Comment from source:
/* Tunneling is done when:
 * - We're within 9 squares of destination
 * - We're on the same panel as the destination
 * - We're in the same region as the destination
 * - We're not somewhere in solid rock
 * Some of these are unnecessary, but paranoia is good...
 */
if (!(TFlags & TT_CONNECT))
    if (dist(x, y, dx, dy) < 10)
        if (!At(x, y).Solid)
            if (RegionAt(x, y) == RegionAt(dx, dy))
                if (x / Con[PANEL_SIZEX] == dx / Con[PANEL_SIZEX])
                    if (y / Con[PANEL_SIZEY] == dy / Con[PANEL_SIZEY])
                        stop_flag = true;
```

### Phase 4: Write Corridor (lines 3566-3608)

```cpp
// MakeLev.cpp:3570-3588
for (i = 0; i != cc; i++) {
    x = Corr[i] % 256;
    y = Corr[i] / 256;

    if (At(x, y).Solid) {
        const int f_prio = PRIO_ROOM_FLOOR;
        const int w_prio = PRIO_CORRIDOR_WALL;
        WriteAt(r, x, y, TREG(regID)->Floor, rw, f_prio);
        for (int w = 0; w < 8; w++)
            WriteAt(r, x + DirX[w], y + DirY[w], TREG(regID)->Walls, rw, w_prio);
    }
    if (startConnected)
        At(x, y).Connected = true;
}
```

For each recorded position:
- If solid, write floor at position with `PRIO_ROOM_FLOOR` (70)
- Write walls in all 8 directions with `PRIO_CORRIDOR_WALL` (10)
- Propagate connectivity flag if started in connected area

## CorrectDir Function

**Source:** `MakeLev.cpp:3611-3639`

```cpp
Dir Map::CorrectDir(int16 x, int16 y, int16 dx, int16 dy, Dir Curr) {
    // If on same X, go North/South toward target
    if (x == dx)
        Option1 = y > dy ? NORTH : SOUTH;
    // If on same Y, go East/West toward target
    if (y == dy)
        Option1 = x > dx ? WEST : EAST;
    // If not diametrically opposite to current, use it
    if (Option1 != CENTER && !DIAMETRIC(Option1, Curr))
        return Option1;

    // Otherwise pick best axis
    Option1 = y > dy ? NORTH : SOUTH;
    Option2 = x > dx ? WEST : EAST;

    // Prefer axis with greater distance
    if (lx > ly)
        SWAP(Option1, Option2)
    // 25% chance to swap anyway
    if (!random(4))
        SWAP(Option1, Option2)

    // Avoid going directly back
    if (DIAMETRIC(Option1, Curr))
        return Option2;
    else
        return Option1;
}
```

Key behavior: Never returns the diametrically opposite direction to current (avoids backtracking).

## Door Creation at Room Walls

**Source:** `MakeLev.cpp:3503-3512`

```cpp
// MakeLev.cpp:3503-3512
if (At(x, y).Priority == PRIO_ROOM_WALL && At(NEXTX, NEXTY).Priority == PRIO_ROOM_WALL)
    // Writing over a room wall - force turn
    force_turn = true;
else if (At(NEXTX, NEXTY).Priority == PRIO_ROOM_WALL) {
    // Intersecting Room Wall - create door
    if (!random(2))
        MakeDoor((uint8)x, (uint8)y, TREG(RegionAt(NEXTX, NEXTY))->Door);
    else
        MakeDoor(NEXTX, NEXTY, TREG(RegionAt(NEXTX, NEXTY))->Door);
}
```

50% chance door placed on current tile vs next tile when intersecting room wall.

## Typical Usage in Generation

From `Map::Generate()`:

```cpp
// Panel connection (line 1693)
Tunnel(sx, sy, dx, dy, TT_DIRECT | TT_WANDER, -1, 0);

// Fix-up tunneling (line 1862)
Tunnel(best[mi].sx, best[mi].sy, best[mi].dx, best[mi].dy, TT_DIRECT | TT_WANDER, -1, trials);
```

Primary flags used: `TT_DIRECT | TT_WANDER`
- `TT_DIRECT`: Prefer direction toward destination
- `TT_WANDER`: May terminate early after touching multiple rooms
