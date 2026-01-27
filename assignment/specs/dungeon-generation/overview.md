# Dungeon Generation Overview

## Verification Status

| Section | Status | Notes |
|---------|--------|-------|
| Generation Phases | VERIFIED | Step comments from source lines 1349-1900 |
| Panel System | VERIFIED | Code at lines 1367-1378 |
| Tunnel Flags | VERIFIED | #defines at lines 76-82 |
| Constants | PARTIAL | Names from dungeon.irh, values need verification |

**Legend:**
- VERIFIED: Directly confirmed from source code
- PARTIAL: Some aspects confirmed, others need verification
- UNVERIFIED: Inferred or assumed, needs confirmation

## Source Files

| File | Lines | Purpose |
|------|-------|---------|
| `src/MakeLev.cpp` | 3842 | Main generation algorithm |
| `lib/dungeon.irh` | ~1500+ | Dungeon definitions, regions, features |
| `inc/Map.h` | - | Map data structures |

## Entry Point

```cpp
void Map::Generate(rID _dID, int16 _Depth, Map *Above, int8 Luck)
```

**Parameters:**
- `_dID` - Dungeon resource ID (e.g., "The Goblin Caves")
- `_Depth` - Current dungeon level (1-based)
- `Above` - Pointer to the map level above (for stair placement, chasm continuation)
- `Luck` - Player's luck attribute (affects some generation)

## Generation Phases

The algorithm proceeds in distinct numbered steps (per comments in source):

### Step 1: Initialize the Map (lines 1349-1416)

1. Load dungeon constants from resource: `TDUN(dID)->GetConst(i)`
2. Load weight lists for room types, corridors, streamers, vaults
3. Allocate map grid: `sizeX * sizeY` LocationInfo structures
4. Calculate panel grid dimensions: `panelsX = LEVEL_SIZEX / PANEL_SIZEX`
5. Fill entire map with rock terrain (`TERRAIN_ROCK`)
6. Place map edge terrain (`TERRAIN_MAPEDGE`)

**Key Constants:**
- `LEVEL_SIZEX`, `LEVEL_SIZEY` - Total map dimensions
- `PANEL_SIZEX`, `PANEL_SIZEY` - Individual panel dimensions
- `TERRAIN_ROCK`, `TERRAIN_MAPEDGE` - Default terrain types
- `BASE_REGION` - Default region for unassigned areas

### Step 2: Place Streamers (lines 1419-1490)

Streamers are map-spanning terrain features like rivers, chasms, and lava flows.

1. Generate `MIN_STREAMERS` to `MAX_STREAMERS` streamers
2. Each streamer starts at a random position
3. Choose streamer type from `STREAMER_WEIGHTS` list
4. Depth restrictions: rivers require `MIN_RIVER_DEPTH`, chasms require `MIN_CHASM_DEPTH`
5. Call `WriteStreamer()` to draw the terrain
6. If map above has chasms, propagate them down (with optional narrowing via `REDUCE_CHASM_CHANCE`)

### Step 3: Place Large Submaps / Special Rooms (lines 1494-1602)

1. Process dungeon's `AN_DUNSPEC` annotations (from `Specials:` in resource file)
2. For each special with matching depth:
   - If type is `T_TREGION` with a grid, place the predefined map
   - Find panel location that doesn't overlap existing content or stairs
   - Call `WriteMap()` to place the special region
   - Mark used panels in `PanelsDrawn` bitmap

**Special Room Examples:**
- Entry chambers
- Places of sanctuary
- Armouries
- Boss lairs (e.g., "the Goblin Encampment")

### Step 4: Draw Each Panel (lines 1607-1614)

For each panel not already filled by Step 3:

```cpp
for (x = 0; x < panelsX; x++)
    for (y = 0; y < panelsY; y++)
        if (!(PanelsDrawn[y] & (1 << x)))
            DrawPanel(x, y);
```

`DrawPanel()` generates a room within the panel bounds using weighted room type selection.

### Step 5: Connect Each Panel (lines 1616-1701)

Ensures basic connectivity between adjacent panels:

1. For each panel, find all non-solid "edge" tiles (tiles with <4 non-solid neighbors)
2. For each pair of adjacent panels (horizontal, vertical, diagonal):
   - Find closest pair of edge tiles
   - Tunnel between them using `TT_DIRECT | TT_WANDER` flags

### Step 5b: Fix-Up Tunneling (lines 1745-1870)

Uses flood-fill to ensure full map connectivity:

1. Flood-fill from first open tile, marking as "Connected"
2. Repeat up to 26 trials:
   - Find unconnected regions
   - Find closest points between connected and unconnected areas
   - Tunnel to connect them
   - Re-flood to update connectivity

### Step 6: Place Stairs & Required Content (lines 1876-1900+)

1. Place up-stairs at corresponding down-stair locations from level above
2. Generate `MIN_STAIRS` to `MAX_STAIRS` down-stairs:
   - Random placement on non-solid, non-water tiles
   - Avoid placing multiple stairs in same region
3. Place dungeon specials (monsters, items, features) at their designated depths

## Key Data Structures

### Panel System

The level is divided into a grid of panels:
- Each panel is `PANEL_SIZEX` x `PANEL_SIZEY` tiles
- Level size must be evenly divisible by panel size
- Maximum 32x32 panels
- `PanelsDrawn[y] & (1 << x)` tracks which panels are generated

### Tracking Arrays

```cpp
int32 RoomsTouched[32];      // Bitmap of rooms reached by tunnels
int32 PanelsDrawn[32];       // Bitmap of panels already generated
rID RoomWeights[1024];       // Room type selection weights
rID CorridorWeights[1024];   // Corridor type weights
rID VaultWeights[1024];      // Vault placement weights
rID StreamWeights[1024];     // Streamer type weights
```

### Tunnel Termination Flags

```cpp
#define TT_CONNECT  0x01  // Terminate on Connected flag change
#define TT_DIRECT   0x02  // Take most direct route to destination
#define TT_LENGTH   0x04  // Terminate if length exceeds value
#define TT_NOTOUCH  0x08  // Don't "touch" rooms
#define TT_EXACT    0x10  // Go to exact destination
#define TT_WANDER   0x20  // Chance to end after touching 2 rooms
#define TT_NATURAL  0x40  // Curved, natural, non-horizontal tunnels
```

## Dungeon Constants

From `dungeon.irh`, key constants include:

| Constant | Example Value | Purpose |
|----------|---------------|---------|
| `ROOM_MAXX` | 16 | Maximum room width |
| `ROOM_MAXY` | 16 | Maximum room height |
| `TURN_CHANCE` | 20 | Corridor turn probability |
| `STUBBORN_CORRIDOR` | 4 | Corridor persistence factor |
| `DUN_DEPTH` | 10 | Total dungeon levels |
| `INITIAL_CR` | varies | Starting challenge rating |
| `DUN_SPEED` | varies | CR increase per level |

## Room Types

Room shapes are selected via `RC_WEIGHTS` list. Types include:
- `RM_NORMAL` - Rectangular rooms
- `RM_LIFECAVE` - Organic cave shapes
- `RM_CASTLE` - Structured castle-like rooms
- `RM_MAZE` - Maze sections
- `RM_DESTROYED` - Ruined areas
- (See `room-placement.md` for full list)

## Region System

Regions define thematic areas with:
- Floor/wall terrain types
- Door types
- Lighting rules
- Monster/item restrictions
- Special flags (RF_RIVER, RF_CHASM, etc.)

## Next Documents

- `room-placement.md` - Detailed room generation algorithms
- `corridor-generation.md` - Tunneling system
- `terrain-assignment.md` - How terrain is chosen
- `feature-placement.md` - Doors, traps, stairs
- `population.md` - Monster/item placement
