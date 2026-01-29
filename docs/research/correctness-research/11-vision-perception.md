# Vision & Perception System

**Source**: `Vision.cpp`, `Djikstra.cpp`
**Specs**: `docs/research/specs/visibility-system.md`, `docs/research/specs/lighting-system.md`
**Status**: Fully researched

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

### Perceives() Detailed Flow (735 lines)

**Early Returns:**
1. Mount delegation: if target is mounted, check perception of mount instead
2. Cross-map check: return 0 if on different maps
3. Illusion unwrapping: if perceiver is illusion, delegate to source creature
4. Sleep check: sleeping creatures perceive nothing
5. Engulfed target: return `PER_VISUAL` only if engulfed by self
6. Self-perception: always return `PER_VISUAL`
7. Seller exception: NPC sellers always visible to player if alive
8. Pet/follower boost: monsters leading/following player get automatic `PER_VISUAL`

**Distance Checks:**
- Build detection range lists from DETECTING statuses
- Distance > 30: short-circuit, return only non-distance perception

**Non-Visual Perception:**
- **Tremorsense**: Detects non-flying creatures; not paralyzed; not hiding (unless balance skill >= 30)
- **Blindsight**: Echolocation; no SILENCE field; LineOfFire path exists; same plane; target not hiding (or listener's LISTEN >= target's MOVE_SILENCE)
- **Penetrating Sight**: Short-range awareness if PERCEPTION status value set
- **Telepathy**: Detects non-MINDLESS, non-UNDEAD creatures
- **Scent**: Only if perceiver engulfed; detects via LineOfFire

**Companion Perception:**
- Players: can perceive through animal companion (`HAS_ANIMAL`)
- Monsters: can perceive through druid companion (`ANIMAL_COMPANION`)
- Uses recursion limiter to prevent infinite loops

**Visual Perception:**
- **Hiding check**: target's HIDE skill must exceed perceiver's SPOT skill (with HideVal bonus)
- **Invisibility**: blocked unless perceiver has SEE_INVIS
- **Invisible-to**: creature-type specific invisibility via INVIS_TO status
- **Player vision**: if within SightRange AND location VI_VISIBLE → `PER_VISUAL | PER_SHADOW`; if VI_DEFINED + ILLUMINATED → also visual
- **Non-player vision**: requires LineOfVisualSight
- **Far darkness**: if distance > 2×LightRange and location unlit → strip `PER_VISUAL | PER_SHADOW`
- **Infravision**: if InfraRange covers distance and LOS clear

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

### Path-Tracing Algorithm (HUGE_PATH_MACRO)
All LOS functions use a shared Bresenham-like line-drawing macro:
1. **Straight lines**: If `cx == tx` (vertical) or `cy == ty` (horizontal), step directly
2. **Diagonal movement**: Uses fractional slope comparison (`|2*ty - 2*cy|` vs `|2*tx - 2*cx|`) to decide step direction (X only, Y only, or diagonal)
3. Checks obstruction at each non-starting position; returns false on block

### LineOfVisualSight(sx, sy, tx, ty, Creature *c)
Visual LOS using `CARE_ABOUT_SEEING` check:
- Blocked by `OpaqueAt(cx,cy)` — opaque terrain
- Blocked by `Here.Dark && !ignoreDark` — dark tiles
- Blocked by `ObscureAt(cx,cy) && !ignoreObscure` — fog/obscurement (passable if creature has NatureSight)

### LineOfFire(sx, sy, tx, ty, Creature *c)
Fire path using `CARE_ABOUT_SOLID` check:
- Blocked by `SolidAt(cx,cy)` — solid objects
- Blocked by `Here.isWall` — walls
- More permissive than visual LOS — allows through obscure/dark terrain

### LineOfSight(sx, sy, tx, ty, Creature *c)
Combined: returns true if `LineOfVisualSight` OR within `BlindRange`

### VisionPath(pn, sx, sy, tx, ty, Creature *c, SiR, LiR, ShR)
Traces a vision cone using line drawing; marks tiles as seen with distance calculations via `MarkAsSeen()`. Used for player FOV edge sweeps.

### BlindsightVisionPath(pn, sx, sy, tx, ty, Creature *c, BlR)
Traces blindsight cone; ignores opaque/obscure terrain; uses only solid obstacle checks. Marks tiles within `BlindRange`.

## Vision Calculation

### VisionThing(pn, Creature *c, do_clear) — Main FOV Function

**Setup Phase:**
- Extract creature perception stats: SightRange, LightRange, ShadowRange, BlindRange, PercepRange, TremorRange
- `ShadowRange = max(ShadowRange, LightRange)` — shadow vision extends at least as far as light
- Calculate viewport bounds with 5-tile buffer around player screen position
- Optionally clear previous visibility flags if `do_clear=true`

**Visual Sight** (if SightRange > 0):
- Mark starting position as seen
- Trace `VisionPath()` to all edges of viewport (4 sweeps: top, bottom, left, right edges)
- Respects light/darkness per `MarkAsSeen` logic

**Blindsight** (if BlindRange > 0):
- Uses `BlindsightVisionPath()` instead
- Ignores opaque/obscure terrain; only checks solid obstacles
- Extends awareness through darkness but not solid rock

**Perception** (if PercepRange > 0):
- Simple distance check: all tiles within range
- Marks both `VI_VISIBLE` and `VI_DEFINED`
- Updates memory with current glyph

**Tremor Sense** (if TremorRange > 0):
- Range-based awareness of solid terrain (`SolidAt` check)
- Updates memory for known stone/rock positions
- Does NOT grant visual perception, only memory updates

**Special Cases:**
- Wizard sight option: reveals entire viewport
- Memory persistence: features (chests, fountains) remembered with their glyphs

### Player::CalcVision()
```cpp
void Player::CalcVision() {
    m->VisionThing(0, this, true);     // Recalc player's own vision, clear old
    StatiIterNature(this, HAS_ANIMAL)  // Include all animal companions
        m->VisionThing(0, oCreature(S->h), false);  // Don't clear again
    StatiIterEnd(this)
}
```

**Player-specific behavior:**
- Viewport clipping: only processes screen-visible region + 5-tile buffer
- Blind at unlit location: still marks starting position as VI_VISIBLE | VI_DEFINED (can always see self)
- Multiple vision passes (4 edge sweeps + blindsight if available)
- Region tracking: marks exterior regions as `VI_EXTERIOR`, tracks `lastRegion`/`playerRegion`
- Vision flags use 4-bit shift per player: `Mask >> (pn*4)` (supports multi-player, though game is single-player)

### MarkAsSeen Logic — Three Visibility Tiers

```
if (dist > SightRange)
    return true;                        // Beyond max range, stop tracing
else if (dist > ShadowOrBlindRange && !Here.Lit && !Here.mLight)
    return true;                        // Beyond shadow range in darkness, stop
else if (dist > LightRange && !Here.Lit && !Here.mLight)
    Mask = VI_DEFINED;                  // Shadow vision: outline only
else
    Mask = VI_VISIBLE | VI_DEFINED;     // Full visibility with light
```

| Tier | Flag | Condition |
|------|------|-----------|
| Fully visible | `VI_VISIBLE \| VI_DEFINED` | Distance ≤ LightRange OR cell Lit/mLight |
| Shadow vision | `VI_DEFINED` only | Distance between LightRange and ShadowRange, cell unlit |
| Not visible | none | Beyond ShadowRange with no light |

### Light Requirements
- Lit cells (Lit flag) visible at full SightRange
- Unlit cells only visible within personal LightRange
- `ShadowRange = max(ShadowRange, LightRange)` — extended shadow awareness
- Magical darkness blocks all visual perception
- Far darkness effect: even if VI_VISIBLE marked, distance > 2×LightRange with no Lit/mLight strips PER_VISUAL

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

## Edge Cases

- Cross-map items/creatures: return 0 perception
- Engulfed targets: locked to `PER_VISUAL` only if engulfed by self
- Mounted creatures: delegate perception to mount
- Illusions: delegate to source creature
- Sleeping creatures: perceive nothing
- Paralyzed creatures: affect tremorsense detection
- SILENCE fields: block blindsight (echolocation)
- Plane differences (ethereal vs material): block same-plane-only senses
- Delete-flagged creatures: use death location instead
- Secret doors / unsprung traps: undetectable by DETECT
- Creatures > 30 tiles away: no visual/light-based perception

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
- Full Perceives() with all perception modes and early returns
- Companion perception pooling (animal companions)
- Obscure/fog effects on vision (NatureSight bypass)
- Line of fire (distinct from LOS)
- Magical darkness/light interaction
- Three-tier visibility (visible/shadow/unseen)
- Far darkness effect (distance > 2×LightRange)
- Creature-based light sources
- Dijkstra pathfinding
- Field perception
- VisionThing with all 5 sense passes
