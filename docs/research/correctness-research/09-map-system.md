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

### Core Fields
```cpp
int16 sizeX, sizeY;           // Map dimensions
LocationInfo *Grid;             // Grid array (sizeX * sizeY)
rID RegionList[256];           // Region definitions per index
rID TerrainList[256];          // Terrain definitions per index
rID dID;                       // Dungeon ID
int16 Depth, Level;            // Dungeon depth and level
int16 EnterX, EnterY;         // Entry point
Overlay ov;                    // Glyph overlay system
NArray<hObj,1000,10> Things;   // All objects on this map
OArray<Field,10,5> Fields;     // Active field effects
OArray<MTerrain,0,10> TerraXY; // Magical terrain positions
OArray<TerraRecord,0,5> TerraList; // Magical terrain records
NArray<uint16,20,20> TorchList;    // Light source positions
hObj pl[4];                    // Player handles
int16 PlayerCount;             // Number of players
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
```cpp
NewField(eID, FType, Image, cx, cy, rad, Dur, Creator)  // Create field
RemoveField(f)                    // Remove field
FieldAt(x, y)                     // Get field at position
FieldGlyph(x, y)                  // Get field display glyph
UpdateFields()                    // Tick field durations
```

### Magical Terrain
```cpp
WriteTerra(key, x, y, terrain)    // Place magical terrain
RemoveTerra(key)                  // Remove by key
UpdateTerra()                     // Tick terrain durations
```

### Overlay System
```cpp
class Overlay {
    int16 GlyphX[MAX], GlyphY[MAX]; // Overlay positions
    Glyph GlyphImage[MAX];           // Overlay glyphs
    int16 GlyphCount;
    bool Active;
    // AddGlyph, RemoveGlyph, ShowGlyphs
};
```
Used for animated effects, spell targeting, etc.

### Generation (see specs/dungeon-generation/ for details)
```cpp
Generate()                   // Full dungeon generation
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

### Pathfinding
```cpp
ShortestPath(x1,y1,x2,y2)   // Dijkstra shortest path
PathPoint(x,y)               // Get next step on path
RunOver(x,y)                 // Auto-run pathfinding
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
