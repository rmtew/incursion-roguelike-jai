# Feature Placement Specification

## Verification Status

| Section | Status | Source |
|---------|--------|--------|
| MakeDoor function | VERIFIED | MakeLev.cpp:1270-1288 |
| MakeSecretDoor function | VERIFIED | MakeLev.cpp:1290-1302 |
| Door constructor | VERIFIED | Feature.cpp:310-337 |
| Door::SetImage | VERIFIED | Feature.cpp:342-397 |
| Door flags | VERIFIED | Defines.h:2231-2236 |
| Up-stairs placement | VERIFIED | MakeLev.cpp:1706-1743 |
| Down-stairs placement | VERIFIED | MakeLev.cpp:1879-1900 |
| Trap placement | VERIFIED | MakeLev.cpp:2155-2192 |
| Stair constants | VERIFIED | Defines.h:3587-3588, 3620-3621 |
| Trap constants | VERIFIED | Defines.h:3643 |

## Door Placement

### MakeDoor Function

**Source:** `MakeLev.cpp:1270-1288`

```cpp
void Map::MakeDoor(uint8 x, uint8 y, rID fID) {
    Door *d;
    if (!fID)
        fID = FIND("oak door");

    // Force all doors on dlev 1-3 to be wood -- some character
    // types can't get through the other kinds of doors in the
    // early game!
    if (Depth <= 3 && TFEAT(fID)->Material != MAT_WOOD)
        fID = FIND("oak door");

    ASSERT(fID);
    if (FFeatureAt(x, y))
        return;
    d = new Door(fID);
    d->PlaceAt(this, x, y);
    d->SetImage();
}
```

**Key behavior:**
- Default door type: "oak door"
- Depth 1-3: Forces wood doors regardless of region setting
- Skips placement if feature already exists at location

### MakeSecretDoor Function

**Source:** `MakeLev.cpp:1290-1302`

```cpp
void Map::MakeSecretDoor(uint8 x, uint8 y, rID fID) {
    Door *d;
    if (!fID)
        fID = FIND("oak door");
    ASSERT(fID);
    if (FFeatureAt(x, y))
        return;
    d = new Door(fID);
    d->DoorFlags &= (~DF_VERTICAL);
    d->DoorFlags |= DF_SECRET | DF_LOCKED;
    d->PlaceAt(this, x, y);
    d->SetImage();
}
```

**Key behavior:**
- Always sets `DF_SECRET | DF_LOCKED` flags
- Clears `DF_VERTICAL` (re-determined by SetImage)

### Door Flags

**Source:** `Defines.h:2231-2239`

```cpp
#define DF_VERTICAL 0x01
#define DF_OPEN     0x02
#define DF_STUCK    0x04
#define DF_LOCKED   0x08
#define DF_TRAPPED  0x10
#define DF_SECRET   0x20
#define DF_BROKEN   0x40
#define DF_SEARCHED 0x80
#define DF_PICKED   0x80  /* Same as DF_SEARCHED */
```

### Door Constructor

**Source:** `Feature.cpp:310-337`

Two code paths exist based on `WEIMER` define:

**Default path (`#ifndef WEIMER`):**
```cpp
Door::Door(rID fID) : Feature(TFEAT(fID)->Image, fID, T_DOOR) {
    DoorFlags = 0;
    if (!random(10))           // 10% chance
        DoorFlags |= DF_OPEN;
    else {
        Flags |= F_SOLID;
        if (!random(2))        // 50% chance if closed
            DoorFlags |= DF_LOCKED;
    }
    if (!random(7)) {          // ~14% chance
        DoorFlags &= ~DF_OPEN;
        DoorFlags |= DF_SECRET;
        if (!random(2))        // 50% chance if secret
            DoorFlags |= DF_LOCKED;
    }
}
```

**Probabilities (default path):**
- Open: 10%
- Closed & Locked: ~45% (90% closed × 50% locked)
- Closed & Unlocked: ~45%
- Secret: ~14% (overrides open)
- Secret & Locked: ~7%

**WEIMER path:**
```cpp
    DoorFlags = DF_LOCKED;
    Flags |= F_SOLID;
    if(!random(7))
        DoorFlags |= DF_SECRET;
```

All doors start closed and locked; ~14% secret.

### Door Orientation (SetImage)

**Source:** `Feature.cpp:355-360`

```cpp
if (m->SolidAt(x, y - 1) && m->SolidAt(x, y + 1))
    DoorFlags |= DF_VERTICAL;
else if (m->SolidAt(x - 1, y) && m->SolidAt(x + 1, y))
    DoorFlags &= ~DF_VERTICAL;
else
    DoorFlags |= DF_BROKEN;
```

- **Vertical**: Walls above and below (door spans east-west opening)
- **Horizontal**: Walls left and right (door spans north-south opening)
- **Broken**: Neither pattern matches

### Door Creation During Tunneling

Doors are created in `Tunnel()` at two points:

**1. Corridor intersection (MakeLev.cpp:3471-3473):**
```cpp
if (At(NEXTX, NEXTY).Solid)
    if (At(NEXTX2, NEXTY2).Priority == PRIO_CORRIDOR_WALL)
        MakeDoor(NEXTX, NEXTY, TREG(RegionAt(NEXTX, NEXTY))->Door);
```

**2. Room wall intersection (MakeLev.cpp:3506-3512):**
```cpp
else if (At(NEXTX, NEXTY).Priority == PRIO_ROOM_WALL) {
    if (!random(2))
        MakeDoor((uint8)x, (uint8)y, TREG(RegionAt(NEXTX, NEXTY))->Door);
    else
        MakeDoor(NEXTX, NEXTY, TREG(RegionAt(NEXTX, NEXTY))->Door);
}
```

50% chance door placed on current tile vs next tile.

## Stairs Placement

### Stair Constants

**Source:** `Defines.h:3587-3588, 3620-3621`

```cpp
#define MIN_STAIRS            15 /* The minimum number of stairs down to generate at each depth other than the last. */
#define MAX_STAIRS            16 /* The maximum number of stairs down to generate at each depth other than the last. */
#define STAIRS_UP             50 /* Reference to feature to use for stairs up. */
#define STAIRS_DOWN           51 /* Reference to feature to use for stairs down. */
```

Note: These are constant *indices* into `Con[]` array.

### Depth 1 Entry Point (NOT PORTED)

On depth 1 of each dungeon, the original places an **Entry Chamber** (a dungeon special from the Specials list) rather than a generic up-staircase. The Entry Chamber grid has a tile marked with `TILE_START` which sets `Map::EnterX/EnterY`. The player starts at these coordinates.

**Original flow:**
1. `dungeon.irh`: `$"entry chamber" at level 1` in The Goblin Caves
2. `MakeLev.cpp:1500-1569`: Places grid special via `WriteMap()`
3. `MakeLev.cpp:1139-1141`: `TILE_START` flag → `EnterX = x + r.x1; EnterY = y + r.y1;`
4. `Main.cpp:126-129`: Player placed at `EnterX/EnterY`

**Jai port status:** Not implemented. `dungeon_name` not propagated from `init_game`; `TILE_START` not handled; `GenMap` lacks entry point fields. See `correctness-research/BACKLOG.md` for full gap analysis.

### Up-Stairs Placement

**Source:** `MakeLev.cpp:1706-1743`

```cpp
if (Above)
    MapIterate(Above, t, i)
        if (t->Type == T_PORTAL)
            if (((Portal*)t)->isDownStairs()) {
                st = new Portal(Con[STAIRS_UP]);
                ASSERT(st);
                if (SolidAt(t->x, t->y)) {
                    // Carve out space if stairs would be in solid rock
                    WriteAt(r, t->x, t->y, FIND("floor"), RegionAt(t->x, t->y), PRIO_FEATURE_FLOOR);
                    for (j = 0; j < 8; j++)
                        WriteAt(r, t->x + DirX[j], t->y + DirY[j], FIND("dungeon wall"),
                                RegionAt(t->x, t->y), PRIO_CORRIDOR_WALL);
                }
                st->PlaceAt(this, t->x, t->y);
                // Track region to avoid placing down-stairs in same room
                if (RegionAt(t->x, t->y)) {
                    for (j = 0; stairsAt[j]; j++)
                        ;
                    stairsAt[j] = RegionAt(t->x, t->y);
                }
            }
```

**Key behavior:**
- Placed at same coordinates as down-stairs on level above
- If in solid rock, carves floor + surrounding walls
- Tracks regions where stairs exist (for down-stairs avoidance)

### Down-Stairs Placement

**Source:** `MakeLev.cpp:1879-1900`

```cpp
if ((int16)Con[MAX_STAIRS] && Depth < (int16)Con[DUN_DEPTH]) {
    j = (int16)Con[MIN_STAIRS] + random((int16)(Con[MAX_STAIRS] - Con[MIN_STAIRS]));
    for (i = 0; i != j; i++) {
        Tries = 0;
        do {
            x = random((int16)Con[LEVEL_SIZEX]);
            y = random((int16)Con[LEVEL_SIZEY]);
            if (Tries++ > 500)
                break;
            bool already = false;
            for (int k = 0; stairsAt[k]; k++)
                if (RegionAt(x, y) == stairsAt[k])
                    already = true;
            if (already) continue;
        } while (At(x, y).Solid || (At(x, y).Priority > PRIO_ROOM_FLOOR) ||
            TTER(TerrainAt(x, y))->HasFlag(TF_WATER) ||
            TTER(TerrainAt(x, y))->HasFlag(TF_FALL));
        st = new Portal(Con[STAIRS_DOWN]);
        ASSERT(st)
        st->PlaceAt(this, x, y);
    }
}
```

**Placement rules:**
- Count: `MIN_STAIRS` to `MAX_STAIRS` (random)
- Not on last dungeon level (`Depth < DUN_DEPTH`)
- Valid location must be:
  - Not solid
  - Priority <= `PRIO_ROOM_FLOOR` (70)
  - Not water terrain (`TF_WATER`)
  - Not fall terrain (`TF_FALL`)
  - Not in region with existing stairs
- Up to 500 tries per stair

## Trap Placement

### Trap Constants

**Source:** `Defines.h:3643`

```cpp
#define TRAP_CHANCE           73 /* Trap placement chance range, compared to depth CR. */
```

### Trap Placement Algorithm

**Source:** `MakeLev.cpp:2155-2192`

Comment from source:
```cpp
/* We put the trap at the T in the following places:
*  .
* #T#
*  .
*
*  #
* .T.
*  #
*
* (where the T was assumed to be empty before). Theory: Kobolds are
* smart, they'll trap bottlenecks.
*/
```

**Two placement conditions:**

**1. At doors (lines 2170-2175):**
```cpp
if (FDoorAt(x, y) && (random((int16)Con[TRAP_CHANCE]) <= (int16)(DepthCR + 10))) {
    rID tID = theGame->GetEffectID(PUR_DUNGEON, 0, (int8)DepthCR, AI_TRAP);
    if (tID) {
        Trap * tr = new Trap(FIND("trap"), tID);
        tr->PlaceAt(this, x, y);
    }
}
```

Chance: `random(TRAP_CHANCE) <= DepthCR + 10`

**2. At corridor bottlenecks (lines 2176-2191):**
```cpp
else if (!At(x, y).Solid && !FFeatureAt(x, y)) {
    bool up, down, left, right;
    up = At(x, y - 1).Solid && !FDoorAt(x, y - 1);
    down = At(x, y + 1).Solid && !FDoorAt(x, y + 1);
    left = At(x - 1, y).Solid && !FDoorAt(x - 1, y);
    right = At(x + 1, y).Solid && !FDoorAt(x + 1, y);
    // Bottleneck pattern: open N-S with walls E-W, or open E-W with walls N-S
    if ((!up && !down && left && right) || (up && down && !left && !right)) {
        if (random((int16)Con[TRAP_CHANCE]) <= (int16)((DepthCR + 2) / 3)) {
            rID tID = theGame->GetEffectID(PUR_DUNGEON, 0, (int8)DepthCR, AI_TRAP);
            if (tID) {
                Trap * tr = new Trap(FIND("trap"), tID);
                tr->PlaceAt(this, x, y);
            }
        }
    }
}
```

- Bottleneck pattern: walls on two opposite sides, open on other two
- Chance: `random(TRAP_CHANCE) <= (DepthCR + 2) / 3`
- Lower chance than door traps (~1/3 the base CR contribution)

### Trap Effect Selection

```cpp
rID tID = theGame->GetEffectID(PUR_DUNGEON, 0, (int8)DepthCR, AI_TRAP);
```

Trap effect selected based on:
- Purpose: `PUR_DUNGEON`
- CR: `DepthCR`
- AI type: `AI_TRAP`

## Treasure Deposits

**Source:** `MakeLev.cpp:2197-2229`

```cpp
int16 cDeposits;
cDeposits = Dice::Roll(1, 4, (int8)Depth);  // 1d4 + Depth
for (n = 0; n != cDeposits; n++) {
    // Find valid location in solid rock
    do {
        x = 1 + random(sizeX - 1);
        y = 1 + random(sizeY - 1);
        // Must be rock glyph
        if ((TTER(TerrainAt(x, y))->Image & GLYPH_ID_MASK) != GLYPH_ROCK)
            goto TryAgain;
        // Must have no adjacent open spaces
        for (j = 0; j != 8; j++)
            if (InBounds(x + DirX[j], y + DirY[j]) && !SolidAt(x + DirX[j], y + DirY[j]))
                goto TryAgain;
        // If base rock terrain, 6/7 chance to retry (prefer other rock types)
        if ((TerrainAt(x, y) == Con[TERRAIN_ROCK]) && random(7))
            goto TryAgain;
        break;
    TryAgain:;
    } while (1);

    // Select deposit type based on depth
    for (int mIdx = 0; theGame->Modules[mIdx]; mIdx++)
        for (i = 0; i < theGame->Modules[mIdx]->szTer; i++) {
            depID = theGame->Modules[mIdx]->TerrainID(i);
            if (TTER(depID)->HasFlag(TF_DEPOSIT))
                if ((int16)TTER(depID)->GetConst(DEPOSIT_DEPTH) <= Depth)
                    Candidates[nCandidates++] = depID;
        }
    depID = Candidates[random(nCandidates)];
    WriteAt(r, x, y, depID, RegionAt(x, y), PRIO_DEPOSIT);
}
```

**Key behavior:**
- Count: `1d4 + Depth` deposits per level
- Must be fully surrounded by solid rock
- Prefers non-base rock terrain (6/7 chance to retry if base rock)
- Deposit type filtered by `TF_DEPOSIT` flag and `DEPOSIT_DEPTH` constant
