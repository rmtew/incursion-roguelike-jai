# Map System

**Source**: `Map.h`, `Display.cpp`, `MakeLev.cpp`, `Vision.cpp`
**Status**: Architecture researched from headers; dungeon generation DONE (see specs/dungeon-generation/)

## Overview

The Map class manages a dungeon level's grid data, objects, fields, and provides spatial queries, LOS/LOF, and vision calculations.

## LocationInfo (Per-Cell Data)

```cpp
struct LocationInfo {
    uint32 Glyph;                  // Display glyph (32-bit encoded)
    unsigned int Region      :8;   // Region ID
    unsigned int Terrain     :8;   // Terrain type
    unsigned int Opaque      :1;   // Blocks LOS (from map)
    unsigned int Obscure     :1;   // Foggy/misty
    unsigned int Lit         :1;   // Is illuminated
    unsigned int Bright      :1;   // Bright lighting
    unsigned int Solid       :1;   // Impassable
    unsigned int Shade       :1;   // Shaded by light source
    unsigned int hasField    :1;   // Has active field effect
    unsigned int Dark        :1;   // Magical Darkness
    unsigned int mLight      :1;   // Magical Light
    unsigned int mTerrain    :1;   // Magical Terrain (dispellable)
    unsigned int cOpaque     :1;   // Opaque (calculated at runtime)
    unsigned int Special     :1;   // Special terrain
    unsigned int isWall      :1;   // Wall (for pathfinding)
    unsigned int isVault     :1;   // Vault (scry/teleport restriction)
    unsigned int isSkylight  :1;   // Has skylight
    unsigned int mObscure    :1;   // Magical obscurement
    unsigned int Visibility  :16;  // Visibility flags (per-player)
    uint32 Memory;                 // Memory glyph (last seen)
    hObj Contents;                 // Handle to first object at cell
};
```

### Visibility Constants
```cpp
#define VI_VISIBLE  1    // Currently in FOV
#define VI_DEFINED  2    // Has been seen before
#define VI_EXTERIOR 4    // Exterior location
#define VI_TORCHED  8    // Lit by mobile light source
```

### Glyph Encoding (32-bit)
```
Bits 0-11:  Character ID (CP437 index)
Bits 12-15: Foreground color (ANSI 0-15)
Bits 16-19: Background color (ANSI 0-15)
Bits 20-31: Additional flags
```

## Map Class

### Private Fields
```cpp
int16 sizeX, sizeY;           // Map dimensions
int16 nextAvailableTerraKey;   // Key generator for magical terrain
bool  inGenerate;              // Currently generating
LocationInfo *Grid;             // Grid array (sizeX * sizeY)
rID   RegionList[256];         // Region definitions per index
uint8 SpecialDepths[16];       // Special content depth tracking
rID   TerrainList[256];        // Terrain definitions per index
int16 CurrThing;               // Iteration cursor for Things array
```

#### Static Vision Helpers
```cpp
static Fraction slope1, slope2, slope3, test;  // int32 numerator/denominator
```

#### Static Generation Arrays
```cpp
static int32  TotalCorridorLength;
static int32  RoomsTouched[32];
static int32  PanelsDrawn[32];
static rID    RoomWeights[1024];
static rID    CorridorWeights[1024];
static rID    VaultWeights[1024];
static rID    StreamWeights[1024];
static uint8  OpenX[2048], OpenY[2048];  // Open position buffer
static int16  OpenC;                      // Current open position count
static uint16 Corners[32], nCorners;
static uint16 Centers[16], nCenters;
static Rect   cPanel, cRoom;             // Current panel/room being generated
static uint32 Con[143];                   // LAST_DUNCONST = 143
static uint32 RM_Weights[64];            // RM_LAST*2 = 32*2
static uint32 RC_Weights[26];            // RC_LAST*2 = 13*2
static int8   panelsX, panelsY, disX, disY, mLuck;
static uint8  *FloodArray, *FloodStack, *EmptyArray;  // Dynamic
static uint8  PlayerStartX, PlayerStartY;
static bool   IndividualRooms;
```

#### Static Encounter Generation
```cpp
static EncMember EncMem[100];    // MAX_ENC_MEMBERS = 100
static int16  cEncMem;           // Current encounter member count
static int32  uniformKey[50];
static rID    uniformChoice[50];
static int16  cUniform;
```

#### Print Queue
```cpp
int8  QueueStack[32];
int8  QueueSP;                   // Queue stack pointer
```

### Public Fields
```cpp
rID   dID;                       // Dungeon resource ID
int16 PercentSI;                 // Percent special items
bool  inDaysPassed;              // Currently processing rest
int16 Depth, Level;              // Dungeon depth and level
int16 EnterX, EnterY;           // Entry point
int8  SpecialsLevels[64];       // Special content per level
int16 Day;                       // Current day counter
Overlay ov;                      // Glyph overlay system
NArray<hObj,1000,10> Things;     // All objects on this map
OArray<Field,10,5> Fields;       // Active field effects
OArray<MTerrain,0,10> TerraXY;   // Magical terrain positions
OArray<TerraRecord,0,5> TerraList; // Magical terrain records
NArray<uint16,20,20> TorchList;  // Light source positions
int16 FieldCount;                // Active field count
hObj  pl[4];                     // Player handles (max 4)
int16 PlayerCount;               // Number of players
int16 BreedCount;                // Monster breeding counter
int16 PreviousAuguries;          // Augury spell tracking
```

### Grid Access
```cpp
InBounds(x, y)          // Boundary check
At(x, y)                // LocationInfo reference at (x,y)
GlyphAt(x, y)           // Glyph at position
RegionAt(x, y)          // Region ID at position
TerrainAt(x, y)         // Terrain type at position
SolidAt(x, y)           // Is solid/impassable?
OpaqueAt(x, y)          // Is opaque to LOS?
ObscureAt(x, y)         // Is foggy/obscured?
LightAt(x, y)           // Is lit?
BrightAt(x, y)          // Is brightly lit?
```

### Object Queries
```cpp
GetAt(x, y, type, first)  // Get object of type at position
FirstAt(x, y)              // First object at position
NextAt(x, y)               // Next object (iteration)
FCreatureAt(x, y)          // First creature
FItemAt(x, y)              // First item
FDoorAt(x, y)              // First door
FFeatureAt(x, y)           // First feature
FTrapAt(x, y)              // First trap
FChestAt(x, y)             // First container
NChestAt(x, y)             // Next container
MChestAt(x, y)             // Multiple containers?
KnownFeatureAt(x, y)       // Feature visible to player
FirstThing() / NextThing()  // Iterate all Things (uses CurrThing cursor)
```

### Spatial Queries
```cpp
besideWall(x, y)           // Adjacent to wall?
StickyAt(x, y)             // Sticky terrain rID at position
TreeAt(x, y)               // Tree at position?
FallAt(x, y)               // Fall hazard at position?
PMultiAt(x, y, POV)        // Multiple perceived things at position
PTerrainAt(x, y, watcher)  // Perceived terrain (illusion-aware)
TerrainDisbelief(x, y, watcher) // Disbelieve illusory terrain
Filled(x, y)               // Position occupied?
```

### Vision/LOS
```cpp
LineOfSight(x1,y1,x2,y2)         // Can see between points?
LineOfVisualSight(x1,y1,x2,y2)   // Visual LOS (affected by obscure)
LineOfFire(x1,y1,x2,y2)          // Can shoot between points?
VisionThing(x1,y1,x2,y2)         // Vision with thing blocking
VisionPath(x1,y1,x2,y2)          // Vision path check
BlindsightVisionPath(x1,y1,x2,y2) // Blindsight path
MarkAsSeen(x,y)                   // Mark cell visible
calcLight()                        // Calculate all lighting
```

### Field Effects

#### Field Struct
```cpp
struct Field {
    rID    eID;          // Effect resource ID
    uint32 FType;        // Field type flags (bitmask)
    Glyph  Image;        // Display glyph (uint32)
    uint8  cx, cy, rad;  // Center X, Center Y, radius
    int16  Dur;          // Duration (turns remaining, -1 = permanent)
    hObj   Creator;      // Handle to creating object
    hObj   Next;         // Handle to next field (linked list)
    int8   Color;        // Color override

    bool inArea(int16 x, int16 y);  // dist(x,y,cx,cy) <= rad
    bool Affects(Thing *t);
    uint8 FieldDC();
};
```

#### Field Management
```cpp
NewField(eID, FType, Image, cx, cy, rad, Dur, Creator)  // Create field
RemoveField(f)                    // Remove field
RemoveEffField(rID eID)           // Remove field by effect ID
RemoveFieldFrom(hObj h)           // Remove field by creator
RemoveEffFieldFrom(rID eID, hObj h) // Remove by both
FieldAt(x, y)                     // Get field at position
FieldGlyph(x, y, og)              // Get field display glyph (merges with original)
UpdateFields()                    // Tick field durations
MoveField(f, x, y, is_walk)       // Move field center
DispelField(x, y, FType, eID, clev) // Dispel field at position
```

### Magical Terrain

#### MTerrain Struct (per-position tracking)
```cpp
struct MTerrain {
    uint8 x, y;   // Position on map
    uint8 old;     // Original terrain at this position
    uint8 pri;     // Priority (for overlapping magical terrain)
    int16 key;     // Unique key linking to TerraRecord
};
```

#### TerraRecord Struct (effect data)
```cpp
struct TerraRecord {
    int16  key;        // Unique key matching MTerrain entries
    int16  Duration;   // Remaining duration
    int8   SaveDC;     // Save DC for damage avoidance
    int8   DType;      // Damage type
    Dice   pval;       // Damage dice (Number, Sides, Bonus)
    rID    eID;        // Effect resource ID
    hObj   Creator;    // Creating object (for XP attribution)
};
```

#### Terrain Management
```cpp
WriteTerra(x, y, tID)            // Place magical terrain
RemoveTerra(key)                  // Remove by key
RemoveTerraXY(x, y, xID)         // Remove at position
UpdateTerra()                     // Tick terrain durations
GetTerraDC(x, y)                  // Get save DC at position
GetTerraCreator(x, y)            // Get creator at position
GetTerraDType(x, y)              // Get damage type at position
GetTerraDmg(x, y)                // Get damage at position
```

### Overlay System
```cpp
class Overlay {
    // Private
    int16 GlyphX[250];             // MAX_OVERLAY_GLYPHS = 250
    int16 GlyphY[250];
    Glyph GlyphImage[250];
    int16 GlyphCount;
    hObj  m;                        // Map handle
    // Public
    bool Active;
    void Activate();
    void DeActivate();
    void AddGlyph(int16 x, int16 y, Glyph g);
    void RemoveGlyph(int16 x, int16 y);
    void RemoveGlyph(int16 n);      // By index
    bool IsGlyphAt(int16 x, int16 y);
    void ShowGlyphs();
};
```
Used for animated effects, spell targeting, etc.

### Generation (see specs/dungeon-generation/ for details)
```cpp
Generate()                   // Full dungeon generation
GeneratePrompt()             // Interactive generation
LoadFixedMap()               // Load predefined map
WriteAt(x,y,terrain)         // Place terrain
WriteBox(rect, terrain)      // Fill rectangle
WriteRoom(rect, walls, floor) // Draw room
Tunnel(...)                  // Create corridor
MakeDoor(x,y)               // Place door
MakeSecretDoor(x,y)         // Place secret door
DrawPanel(...)               // Generate panel
PopulatePanel(...)           // Populate with encounters
```

#### Room Shape Writers
```cpp
WriteCircle(r, regID)        // Circular room
WriteLifeCave(r, regID)      // Cellular automata cave
WriteCastle(r, regID)        // Castle-style room
WriteRCavern(r, regID)       // Random cavern
WriteOctagon(r, regID)       // Octagonal room
WriteDiamond(x, y, regID)   // Diamond shape
WriteDestroyed(r, regID)    // Destroyed/ruined room
WriteMaze(r, regID, inset_count, ...) // Maze (variadic)
WriteCross(r, regID)         // Cross-shaped room
WriteMap(r, mID)             // Load fixed map layout
WriteBlobs(r, regID, bID)   // Blob terrain features
WriteStreamer(r, sx, sy, d, regID) // River/lava streamer
WriteWalls(r, regID)         // Wall-only write
LightPanel(r, regID)         // Apply panel lighting
SetRegion(r, regID)          // Set region for area
```

#### Flood Fill and Open Areas
```cpp
FloodConnectA(x, y, fCount) // Flood fill variant A
FloodConnectB(x, y)          // Flood fill variant B
FindOpenAreas(r, regID, Flags) // Find open positions in rect
GetOpenXY()                   // Get packed open position (x + y*256)
```

### Pathfinding
```cpp
PQInsert(Node, Weight)       // Priority queue insert
PQPeekMin()                  // Priority queue peek
PQPopMin()                   // Priority queue pop
ShortestPath(sx, sy, tx, ty, c, dangerFactor, ThePath)  // Dijkstra
PathPoint(n)                 // Get step N on path
RunOver(x, y, memonly, c, dangerFactor, Incor, Meld)     // Auto-run
```

### Encounter Generation
```cpp
// Public encounter generation API (9 variants)
thEnGen(xID, fl, CR, enAlign)                           // Basic
thEnGenXY(xID, fl, CR, enAlign, x, y)                  // At position
thEnGenSummXY(xID, fl, CR, enAlign, crea, x, y)        // Summoned at pos
thEnGenMon(xID, mID, fl, CR, enAlign)                   // Specific monster
thEnGenMonXY(xID, mID, fl, CR, enAlign, x, y)          // Monster at pos
thEnGenMType(xID, mt, fl, CR, enAlign)                  // Monster type
thEnGenMTypeXY(xID, mt, fl, CR, enAlign, x, y)         // Type at pos
thEnGenMonSummXY(xID, mID, fl, CR, enAlign, crea, x, y) // Mon summon at pos
thEnGenMTypeSummXY(xID, mt, fl, CR, enAlign, crea, x, y) // Type summon
rtEnGen(e, xID, fl, CR, enAlign)                        // Runtime via event

// Internal pipeline
enGenerate(e) → enGenPart(e) → enBuildMon(e) → enSelectTemps(e)
enChooseMID(e), enChooseTemp(e), enGenMount(e), enGenAlign(e)

// Placement and query
PlaceEncounter(ex, ey, creator)
GetEncounterCreature(i)
PrintEncounter()
```

### EncMember Struct
```cpp
struct EncMember {
    rID    mID;      // Monster resource ID
    rID    tID;      // Template 1 resource ID
    rID    tID2;     // Template 2
    rID    tID3;     // Template 3
    rID    iID;      // Item resource ID
    rID    pID;      // Part resource ID
    rID    hmID;     // Mount monster ID
    rID    htID;     // Mount template 1
    rID    htID2;    // Mount template 2
    uint16 Flags;    // Encounter member flags
    uint16 Align;    // Alignment
    hObj   hMon;     // Handle to spawned monster
    int8   Part;     // Which encounter part
    int8   xxx;      // Padding
};
```

### Message Queue
```cpp
SetQueue(Queue)              // Push queue
UnsetQueue(Queue)            // Pop queue
PrintQueue(Queue)            // Print queued messages
EmptyQueue(Queue)            // Discard queued messages
QueueNum()                   // Current queue ID
```

### Noise
```cpp
MakeNoiseXY(x, y, radius)   // Generate noise at position
```

### Miscellaneous
```cpp
RegisterPlayer(h)            // Register player on map
DaysPassed()                 // Update map when player rests
ResetImages()                // Reset all display glyphs
Load(mID)                    // Load map from resource
SetGlyphAt(x, y, g)         // Set glyph with masking
isTorched(x, y, t)          // Check torch illumination
CorrectDir(cx, cy, dx, dy, Curr) // Direction correction
PopulateChest(c)             // Fill container with items
```

### Serialization
```cpp
ARCHIVE_CLASS(Map, Object, r)
    r.Block((void**)&Grid, sizeof(LocationInfo)*sizeX*sizeY);
    Things.Serialize(r);
    Fields.Serialize(r);
    TerraXY.Serialize(r);
    TerraList.Serialize(r);
    TorchList.Serialize(r);
END_ARCHIVE
```

## Supporting Types

### Thing Base Class (inherited by all map objects)
```cpp
class Thing : public Object {
    Map*    m;                      // Current map
    hObj    Next, hm;              // Next in chain; map handle
    int16   x, y;                  // Position
    Glyph   Image;                 // Display glyph (uint32)
    int16   Timeout;               // Turn timeout
    int16   StoredMovementTimeout; // Saved movement timeout
    uint32  Flags;                 // Object flags (F_DELETE, etc.)
    String  Named;                 // Custom name
    StatiCollection __Stati;       // All status effects
    NArray<hObj,10,20> backRefs;   // Back-references for cleanup
};
```

### StatiCollection
```cpp
typedef struct StatiCollection {
    Status*  S;              // Main status array
    Status*  Added;          // Newly added during iteration
    int16    szAdded;        // Count of added entries
    uint16*  Idx;            // Index array (LAST_STATI=237 entries)
    int16    Last;           // Last used element in S
    int16    Allocated;      // Allocated size of S
    int16    Removed;        // Removed count in current iteration
    int8     Nested;         // Nesting depth of iteration loops
};
```

### Status Struct
```cpp
struct Status {
    unsigned int Nature  :8;
    signed int   Val     :16;
    signed int   Mag     :16;
    signed int   Duration :16;
    unsigned int Source  :8;
    unsigned int CLev    :6;
    unsigned int Dis     :1;
    unsigned int Once    :1;
    signed int   eID     :32;
    signed int   h       :32;
};
```

### StatiIter Macros
Safe iteration over status effects with nesting protection:
- `StatiIter(targ)` / `StatiIterEnd(targ)` - basic iteration
- `StatiIterNature(targ, n)` - iterate by Nature, uses `Idx[]` for fast lookup
- `StatiIterAdjust(targ)` - iterate ADJUST-type stati
- `StatiIter_RemoveCurrent(targ)` - safe removal during iteration
- `StatiIter_DispelCurrent(targ)` - removal with dispel event
- `StatiIterBreakout(targ, ret)` - break out safely

### Constants
```cpp
MAX_OVERLAY_GLYPHS   250
MAX_ENC_MEMBERS      100
LAST_DUNCONST        143
RM_LAST              32
RC_LAST              13
LAST_STATI           237
ADDED_SIZE           128
NO_STATI_ENTRY       0xFFFF
```

### Globals
```cpp
extern int8  MapMakerMode;
extern Tile* MapLetterArray[127];
extern Map*  TheMainMap;
```

### Danger Flags (pathfinding)
```cpp
DF_ALL_SAFE          0
DF_IGNORE_TRAPS      1
DF_IGNORE_TERRAIN    2
```
**Note**: These `DF_*` are unrelated to the door flags (`DF_OPEN`, etc.) or damage flags (`DF_FIRE`, etc.) - naming collision in original source.

## Porting Status

### Already Ported
- Basic GenMap structure (`src/dungeon/map.jai`)
- Terrain types and rendering
- Dungeon generation (8-step process)
- Visibility system (FOV + lighting)
- Tile display system
- Room/corridor/door/trap placement

### Needs Porting
- Full LocationInfo bitfield (original has 16 flags vs our simplified version)
- Field effects system
- Magical terrain system
- Overlay system
- Object storage at cells (Contents linked list)
- Pathfinding (Dijkstra)
- Full LOS/LOF implementations
- Region and terrain resource references
- Serialization
