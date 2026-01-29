# Vision & Perception System

**Source**: `Vision.cpp`, `Djikstra.cpp`
**Specs**: `docs/research/specs/visibility-system.md`, `docs/research/specs/lighting-system.md`
**Status**: Partially implemented in port; original algorithm details need .cpp research

## Overview

Incursion has a multi-modal perception system where creatures can detect others through different senses. Vision is the primary mode but creatures may have tremorsense, blindsight, telepathy, scent, etc.

## Perception Types (PER_*, bitmask)

```cpp
PER_VISUAL    = 0x0001  // Normal sight
PER_TREMOR    = 0x0002  // Tremorsense (vibrations)
PER_BLIND     = 0x0004  // Blindsight
PER_INFRA     = 0x0008  // Infravision (heat)
PER_PERCEP    = 0x0010  // Magical perception
PER_TELEP     = 0x0020  // Telepathy
PER_SCENT     = 0x0040  // Scent detection
PER_SHADOW    = 0x0080  // Shadow perception
PER_SHARED    = 0x0100  // Shared perception (allies)
```

## Perceives() Method

Returns a bitmask of which perception modes detected the target:

```
uint16 Perceives(Thing* target, bool assertLOS)
```

Checks each perception mode against creature's ranges:
1. Visual: Within SightRange, requires LOS, requires light (or darkvision)
2. Tremor: Within TremorRange, doesn't require LOS, target must be on ground
3. Blind: Within BlindRange, doesn't require LOS
4. Infra: Within InfraRange, requires LOS, works in dark
5. Telepathy: Within TelepRange, no LOS needed, target must have mind
6. Scent: Within ScentRange, wind direction matters
7. Shadow: Within ShadowRange, perceives shadow/outline

### XPerceives()
Extended perception - excludes Shadow, Scent, and Detect Magic.
Used for determining "real" awareness vs. vague sensing.

### PerceivesField()
Can creature perceive a Field effect at location?

## Perception Range Precalculation

Creature caches these ranges for performance:
```cpp
uint8 TremorRange, SightRange, LightRange, BlindRange;
uint8 InfraRange, PercepRange, TelepRange;
uint8 ScentRange, ShadowRange, NatureSight;
```

Recalculated when equipment/stati change via CalcValues().

## Line of Sight (Map methods)

### LineOfSight(x1,y1,x2,y2)
Basic LOS: checks if any opaque cells block view.
Uses Bresenham-style line drawing between points.

### LineOfVisualSight(x1,y1,x2,y2)
Visual LOS: also considers Obscure (fog) tiles.
Fog reduces visibility distance.

### LineOfFire(x1,y1,x2,y2)
LOS for ranged attacks: checks both opacity and solid creatures blocking.

### VisionThing(x1,y1,x2,y2)
Vision check that accounts for blocking Things (large creatures, etc.)

## Vision Calculation

### Player FOV: CalcVision()
Player-specific FOV calculation:
1. Clear VI_VISIBLE for all cells
2. For each direction, cast vision ray
3. Mark cells as VI_VISIBLE | VI_DEFINED
4. Store Memory glyph for each newly-seen cell

### Light Requirements
- Lit cells (Lit flag) visible at full SightRange
- Unlit cells only visible within personal LightRange
- Bright cells visible at extended range
- Magical darkness blocks all visual perception

### Visibility Flags (per-cell)
```cpp
VI_VISIBLE  = 1  // Currently in FOV
VI_DEFINED  = 2  // Has been seen at least once
VI_EXTERIOR = 4  // Exterior location (different lighting rules)
VI_TORCHED  = 8  // Lit by mobile light source
```

### Memory System
When cell becomes !VI_VISIBLE, display the Memory glyph (last-seen state).
Memory shows terrain but not creatures or items.

## Lighting System

### Light Sources
- `TorchList` on Map - static light positions
- Creatures with LightRange > 0 (carrying light)
- Spell effects (EF_LIGHT, magical light fields)

### Brightness Levels
- Dark (default): Only blindsight/tremor/infra work
- Lit: Normal vision works
- Bright: Extended visual range

### Map Lighting Flags
```
Lit    - Cell is illuminated
Bright - Cell is brightly lit
Dark   - Magical darkness (overrides light)
mLight - Magical light (overrides darkness)
Shade  - In shadow of a light source
```

## Pathfinding (Djikstra.cpp)

### Dijkstra's Algorithm
```cpp
Map::ShortestPath(x1, y1, x2, y2)  // Find shortest path
Map::PathPoint(x, y)                // Next step on path
Map::RunOver(x, y)                  // Auto-run path
```

### Path Cost Factors
- Terrain movement cost (MoveMod from terrain type)
- Creature blocking
- Door state (open = passable, closed = higher cost)
- Trap avoidance
- Monster pathfinding uses SmartDirTo() which may use simplified heuristic

## Porting Status

### Already Ported
- Basic FOV calculation (`src/dungeon/visibility.jai`)
- Lighting calculation (torch-based)
- Visibility flags (VI_VISIBLE, VI_DEFINED)
- Memory system (remembered terrain)
- LOS via Bresenham line
- Torch placement during generation

### Needs Porting
- Multi-modal perception (tremor, blind, infra, telepathy, scent, shadow)
- Obscure/fog effects on vision
- Line of fire (distinct from LOS)
- Magical darkness/light interaction
- Brightness levels
- Creature-based light sources
- Dijkstra pathfinding
- Full CalcVision() with all perception modes
- Field perception
