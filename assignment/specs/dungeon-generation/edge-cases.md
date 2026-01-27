# Edge Cases Specification

## Verification Status

| Section | Status | Source |
|---------|--------|--------|
| Region exhaustion | VERIFIED | MakeLev.cpp:2364-2377 |
| Room type exhaustion | VERIFIED | MakeLev.cpp:2412-2416 |
| Stair placement failure | VERIFIED | MakeLev.cpp:1882-1887 |
| Connectivity failure | VERIFIED | MakeLev.cpp:1779, 1865 |
| Map edge protection | VERIFIED | MakeLev.cpp:255-257 |
| Corridor boundary | VERIFIED | MakeLev.cpp:3489-3491, 3534-3541 |
| Room sizing overflow | VERIFIED | Base.h:285-298 |
| Resource limits | VERIFIED | MakeLev.cpp:282, 297, 1260 |

## Region and Room Type Exhaustion

### All Regions Used

**Source:** `MakeLev.cpp:2364-2377`

When all room type weights sum to zero (all types exhausted):

```cpp
if (weighting_sum == 0) {
    if (usedInThisLevel[0]) {
        // Reset all used regions for reuse
        if (theGame->GetPlayer(0)->WizardMode)
            theGame->GetPlayer(0)->IPrint("The air seems to shift.");
        memset(usedInThisLevel, 0, sizeof(usedInThisLevel));
        /* Reset the weightings (which must be all marked invalid). */
        TDUN(dID)->GetList(RM_WEIGHTS, RM_Weights, RM_LAST * 2);
        goto Reselect;
    } else {
        // None to use, none to reuse.  No recovery from this.
        Fatal("Complete failure to generate a room.");
    }
}
```

**Behavior:**
- First exhaustion: Reset `usedInThisLevel[]` and `RM_Weights[]`, retry
- Second exhaustion (no regions ever worked): Fatal error

### No Compatible Regions for Room Type

**Source:** `MakeLev.cpp:2412-2416`

When a room type has no compatible regions available:

```cpp
if (!c) {
    // No candidates left, disregard this room type from selection.
    RM_Weights[RM_WeightIndex + 1] = -1;
    Tries++;
    goto Reselect;
}
```

**Behavior:**
- Mark room type weight as -1 (disabled)
- Increment tries counter
- Retry room type selection

### Maximum Tries Exceeded

**Source:** `MakeLev.cpp:2353`

```cpp
Error("Two hundred tries and no viable room/region combo.");
```

After 200 attempts, logs an error but continues (non-fatal).

## Stair Placement Failure

**Source:** `MakeLev.cpp:1882-1887`

```cpp
Tries = 0;
do {
    x = random((int16)Con[LEVEL_SIZEX]);
    y = random((int16)Con[LEVEL_SIZEY]);
    if (Tries++ > 500)
        break;
    // ... validation checks ...
} while (/* invalid location */);
```

**Behavior:**
- Try up to 500 random locations per stair
- If 500 tries exceeded, skip this stair (graceful degradation)
- No fatal error - dungeon may have fewer stairs than intended

## Connectivity Failure

**Source:** `MakeLev.cpp:1779, 1865`

```cpp
while (trials++ < 26) {
    // ... find disconnected regions ...
    // ... tunnel to connect them ...
}
// Loop exits after 26 trials regardless of connectivity
```

**Behavior:**
- Maximum 26 fix-up tunneling attempts
- If still disconnected after 26 trials, accepts dungeon as-is
- No fatal error - dungeon may have isolated areas
- Game continues with potentially unreachable regions

## Map Edge Protection

**Source:** `MakeLev.cpp:255-257`

```cpp
if (x == 0 || y == 0 || x == sizeX - 1 || y == sizeY - 1)
    if (!Force && Pri < PRIO_MAX && !(RES(dID)->Type == T_TREGION))
        return;
```

**Behavior:**
- Map edge tiles (x=0, y=0, x=max, y=max) are protected
- WriteAt returns early unless:
  - `Force` parameter is true
  - Priority is `PRIO_MAX` (120)
  - Resource is a region type

This ensures a solid border around the map.

## Corridor Boundary Handling

### Soft Turn (within 4 tiles)

**Source:** `MakeLev.cpp:3489-3491`

```cpp
if ((x + DirX[CurrDir] * 4) > (sizeX - 1) || (x + DirX[CurrDir] * 4) < 0)
    force_turn = true;
if ((y + DirY[CurrDir] * 4) > (sizeY - 1) || (y + DirY[CurrDir] * 4) < 0)
    force_turn = true;
```

Forces a direction change when corridor would reach within 4 tiles of edge.

### Hard Clamp (within 2-3 tiles)

**Source:** `MakeLev.cpp:3534-3541`

```cpp
if (x <= 2)
    CurrDir = EAST;
else if (y <= 2)
    CurrDir = SOUTH;
else if (x >= sizeX - 3)
    CurrDir = WEST;
else if (y >= sizeY - 3)
    CurrDir = NORTH;
```

Absolute direction override when very close to map edge.

## Room Sizing Overflow

### PlaceWithinSafely

**Source:** `Base.h:285-298`

```cpp
Rect& PlaceWithinSafely(uint8 sx, uint8 sy) {
    static Rect r;
    r.x1 = (uint8)(x1 + random(max(0,((x2-x1)-1)-sx)));
    r.x2 = r.x1 + sx;
    r.y1 = (uint8)(y1 + random(max(0,((y2-y1)-1)-sy)));
    r.y2 = r.y1 + sy;

    r.x1 = max(r.x1, x1 + 2);
    r.y1 = max(r.y1, y1 + 2);
    r.x2 = min(r.x2, x2 - 2);
    r.y2 = min(r.y2, y2 - 2);
    return r;
}
```

**Behavior:**
- Ensures 2-tile border from panel edges
- If room too large, clamps to panel size minus 4 (2 on each side)
- Can result in `x1 > x2` or `y1 > y2` for very large rooms in small panels
- Calling code should handle degenerate rectangles

### PlaceWithin (less safe)

**Source:** `Base.h:266-284`

- Only ensures 1-tile border
- Falls back to panel-1 if room larger than panel

## Resource Limits

### Maximum Terrain Types

**Source:** `MakeLev.cpp:282`

```cpp
Fatal("Too many Terrain types on one map!");
```

Limit: 255 unique terrain types per map (stored as uint8 index).

### Maximum Region Types

**Source:** `MakeLev.cpp:297, 1260`

```cpp
Fatal("Too many Regions on one map!");
```

Limit: 255 unique regions per map (stored as uint8 index).

### Maximum Panel Grid

**Source:** `MakeLev.cpp:1378`

```cpp
if (panelsX > 32 || panelsY > 32)
    Fatal("Panel grid exceeds maximum of 32 x 32.");
```

Limit: 32x32 = 1024 maximum panels.

### Panel/Level Size Mismatch

**Source:** `MakeLev.cpp:1368-1371`

```cpp
if (Con[LEVEL_SIZEX] % Con[PANEL_SIZEX])
    Fatal("Mismatch between LEVEL_SIZEX and PANEL_SIZEX.");
if (Con[LEVEL_SIZEY] % Con[PANEL_SIZEY])
    Fatal("Mismatch between LEVEL_SIZEY and PANEL_SIZEY.");
```

Level dimensions must be evenly divisible by panel dimensions.

## Error Handling Summary

| Condition | Severity | Behavior |
|-----------|----------|----------|
| Region exhaustion (first) | Recoverable | Reset and retry |
| Region exhaustion (second) | Fatal | Game crash |
| Room type exhaustion | Recoverable | Disable type, retry |
| 200 room tries | Warning | Log error, continue |
| Stair placement (500 tries) | Graceful | Skip stair |
| Connectivity (26 trials) | Graceful | Accept disconnected |
| Map edge write | Silent | Skip write |
| Corridor at edge | Handled | Force turn/clamp |
| Too many terrains | Fatal | Game crash |
| Too many regions | Fatal | Game crash |
| Panel overflow | Fatal | Game crash |
| Size mismatch | Fatal | Game crash |

## RM_NOROOM Special Case

**Source:** `MakeLev.cpp:2444-2447`

```cpp
case RM_NOROOM:
    /* Simple, no? Remember that it doesn't need to be touched, though. */
    RoomsTouched[py] |= (1 << px);
    return;
```

Empty panels are valid - marks panel as "touched" for connectivity but generates nothing.
