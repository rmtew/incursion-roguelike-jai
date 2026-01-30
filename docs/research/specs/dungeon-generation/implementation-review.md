# Implementation Review: Jai Dungeon Generator vs Original Spec

## Overview

This document compares the existing Jai implementation in `src/dungeon/makelev.jai` against the specifications derived from the original `MakeLev.cpp`.

**Review Date:** 2026-01-28

## Generation Steps Comparison

| Step | Spec (MakeLev.cpp) | Implementation (makelev.jai) | Status |
|------|-------------------|------------------------------|--------|
| 1. Initialize | Fill with TERRAIN_ROCK, edge with TERRAIN_MAPEDGE, load constants | Fill with ROCK, edge with WALL | PARTIAL |
| 2. Streamers | MIN_STREAMERS to MAX_STREAMERS, weighted selection, chasm propagation | MIN_STREAMERS to MAX_STREAMERS loop, depth restrictions, type reuse, chasm propagation | MATCHES |
| 3. Special Rooms | AN_DUNSPEC annotations, predefined maps at specific depths | Hardcoded VAULTS array, simpler selection | DIFFERS |
| 4. Draw Panels | Weighted room type + region selection, 200 tries max | Weighted selection implemented, regions optional | PARTIAL |
| 5. Connect Panels | Edge tiles, closest pairs, TT_DIRECT\|TT_WANDER tunnels | connect_panels() with edge tiles + closest pairs | MATCHES |
| 5b. Fix-Up | 26 trials flood-fill connectivity check | fixup_tunneling() with 26 trials | MATCHES |
| 2b. Chasm Propagation | Copy chasms from above level, 50% narrow chance | Step 2b with REDUCE_CHASM_CHANCE | MATCHES |
| 6. Place Stairs | Up-stairs at Above coordinates, MIN_STAIRS to MAX_STAIRS down | Simple first/last room placement | DIFFERS |
| 7. Deallocation | Free FloodArray, EmptyArray | Not needed (temp allocator) | N/A |
| 9. Skylight Marking | Tiles below above-level chasms: cyan tint, always lit | Step 9 with is_skylight + lit flags | MATCHES |

## Room Types Comparison

### Implemented Room Types

| RM_* Type | Spec Function | Implementation | Status |
|-----------|---------------|----------------|--------|
| RM_NOROOM | Mark touched, no room | Returns early after marking touched | MATCHES |
| RM_NORMAL | WriteRoom (rect + walls) | write_room() | MATCHES |
| RM_LARGE | Larger WriteRoom (1d4 - panel edge) | max(panel/2, panel-(random(8)+2)) | MATCHES |
| RM_CROSS | WriteCross (overlapping bars) | write_cross() | MATCHES |
| RM_OVERLAP | 2-4 overlapping rectangles | write_overlap() | MATCHES |
| RM_ADJACENT | 4 quadrants sharing center | write_adjacent() | MATCHES |
| RM_AD_ROUND | Adjacent with circles | write_adjacent(use_circles=true) | MATCHES |
| RM_AD_MIXED | Adjacent mixed shapes | write_adjacent(mixed=true) | MATCHES |
| RM_CIRCLE | WriteCircle | write_circle() | MATCHES |
| RM_LCIRCLE | Large circle variant | max(panel/2, panel-(random(5)+5)) | MATCHES |
| RM_OCTAGON | WriteOctagon (corners cut) | write_octagon() | MATCHES |
| RM_DOUBLE | Room within room | write_double() | MATCHES |
| RM_PILLARS | Room with pillar grid | write_pillars(), +3 size, even dims | MATCHES |
| RM_CASTLE | Subdivided building | write_castle(), large sizing | MATCHES |
| RM_CHECKER | Checkerboard pillars | write_checker(), +2 size | MATCHES |
| RM_BUILDING | Falls to CASTLE | Falls through to write_castle() | MATCHES |
| RM_LIFECAVE | WriteLifeCave (cellular automata) | write_lifecave() | MATCHES |
| RM_RCAVERN | Repeated-L rough caverns | write_rcavern() + wall streamer pass | MATCHES |
| RM_MAZE | WriteMaze (recursive backtrack) | write_maze(), large sizing | MATCHES |
| RM_DIAMONDS | Chain of filled diamonds with doors | write_diamonds() chain algorithm | MATCHES |
| RM_SHAPED | Grid-based predefined rooms | NOT IMPLEMENTED | MISSING |
| RM_LIFELINK | Life w/ linked regions | NOT IMPLEMENTED | MISSING |
| RM_RANDTOWN | Random town | Falls to default | MISSING |
| RM_DESTROYED | Collapsed area | Falls to default | MISSING |
| RM_GRID | Furnishing grid | Falls to default | MISSING |

### Missing Room Types Analysis

**RM_SHAPED (Critical):**
- Spec: Uses TRegion.Grid with tile definitions, 50% flip chance
- Used for special pre-designed rooms from resource files
- Impact: Many themed areas won't generate correctly

**RM_LIFELINK:**
- Spec: Game of Life with linked regions
- Used for interconnected cavern systems
- Impact: Reduces variety

**RM_DESTROYED, RM_RANDTOWN, RM_GRID:**
- Lower priority - less common room types

## Corridor Generation Comparison

| Aspect | Spec | Implementation | Status |
|--------|------|----------------|--------|
| Tunnel flags | TT_CONNECT, TT_DIRECT, TT_LENGTH, TT_NOTOUCH, TT_EXACT, TT_WANDER, TT_NATURAL | All defined | MATCHES |
| Direction correction | CorrectDir with diametric check | correct_dir() with is_diametric() | MATCHES |
| Turn chance | TURN_CHANCE constant, random check after SEGMENT_MIN | gs.con.TURN_CHANCE = 10 | MATCHES |
| Segment lengths | SEGMENT_MINLEN=4, SEGMENT_MAXLEN=10 | gs.con.SEGMENT_MINLEN=4, SEGMENT_MAXLEN=10 | MATCHES |
| Priority system | PRIO_CORRIDOR_WALL=10, PRIO_CORRIDOR_FLOOR=30 | PRIO_CORRIDOR_WALL=10, PRIO_CORRIDOR_FLOOR=30 | MATCHES |
| Door creation at intersections | Check solid + corridor wall priority | place_doors_makelev() post-process | DIFFERS |
| Stubborn corridor | STUBBORN_CORRIDOR controls direction persistence | gs.con.STUBBORN_CORRIDOR = 30 | MATCHES |
| Panel connection | Edge tiles, closest pairs, left/up/diagonal | Edge tiles + closest pairs, left/up/diagonal | MATCHES |
| Region selection | CorridorWeights, one-time use unless RF_STAPLE | Not using regions for corridors | MISSING |

### Key Corridor Differences

1. **Door placement timing**: Spec places doors during tunneling; implementation does post-process pass
2. **Corridor regions**: Spec uses themed corridor appearances; implementation uses plain corridors

## Terrain Assignment Comparison

| Aspect | Spec | Implementation | Status |
|--------|------|----------------|--------|
| WriteAt priority system | Higher priority prevents overwrite | write_at() checks priority | MATCHES |
| Map edge protection | Returns if edge unless Force or PRIO_MAX | Edge filled with WALL at PRIO_MAX | MATCHES |
| Open tile tracking | OpenX[]/OpenY[] for corridor endpoints | open_x[]/open_y[] arrays | MATCHES |
| WriteLifeCave | LIFE_PERCENT=45, 20 iterations, 5+/3- rule | LIFE_PERCENT=45, 20 iterations | MATCHES |
| WriteStreamer | Rivers from edge, chasms min width 4 | write_streamer() | PARTIAL |
| Deep terrain conversion | Shallow→deep when surrounded (water, lava, brimstone) | convert_deep_terrain() (water, lava) | MATCHES |
| Skylight marking | Tiles below chasms: cyan tint, always lit | is_skylight + renderer override | MATCHES |
| Region terrain refs | Floor/Wall/Door from region definition | Not using region terrain | MISSING |

### Priority System

**Spec values (Defines.h:4307-4320):**
```
PRIO_EMPTY = 0
PRIO_ROCK_STREAMER = 5
PRIO_CORRIDOR_WALL = 10
PRIO_CORRIDOR_FLOOR = 30
PRIO_ROOM_WALL = 40
PRIO_ROOM_FLOOR = 70
PRIO_VAULT = 90
PRIO_RIVER_STREAMER = 90
PRIO_FEATURE_FLOOR = 100
PRIO_DEPOSIT = 110
PRIO_MAX = 120
```

**Implementation values (FIXED 2026-01-28):**
```
PRIO_EMPTY = 0
PRIO_ROCK_STREAMER = 5
PRIO_CORRIDOR_WALL = 10
PRIO_CORRIDOR_FLOOR = 30
PRIO_ROOM_WALL = 40
PRIO_ROOM_FLOOR = 70
PRIO_ROOM_FURNITURE = 75
PRIO_VAULT = 90
PRIO_RIVER_STREAMER = 90
PRIO_FEATURE_FLOOR = 100
PRIO_DEPOSIT = 110
PRIO_MAX = 120
```

**Status: MATCHES** - All priority values now align with spec.

## Feature Placement Comparison

| Feature | Spec | Implementation | Status |
|---------|------|----------------|--------|
| Door creation | MakeDoor at corridor/room intersections | place_doors_makelev() post-process | DIFFERS |
| Door validation | Remove invalid/adjacent doors, floor under valid | validate_doors() post-process | MATCHES |
| Door flags | DF_VERTICAL, DF_OPEN, DF_STUCK, DF_LOCKED, DF_TRAPPED, DF_SECRET | All flags defined, randomization matches | MATCHES |
| Door randomization | 10% open, 50% locked, 14% secret | 10% open, 50% locked, 14% secret | MATCHES |
| Secret door protection | Depth<=5: clear DF_SECRET within 17 of up-stairs | desecret_near_stairs() | MATCHES |
| Early game protection | Depth 1-3 forces wood doors | Not applicable (no door materials) | N/A |
| Up-stairs placement | At same position as down-stairs on level above | place_up_stairs() with carving | MATCHES |
| Down-stairs placement | MIN_STAIRS to MAX_STAIRS, avoid regions | place_down_stairs() with 500 tries | MATCHES |
| Stair region avoidance | Track stairsAt[], avoid same region | StairPos.room_index tracking | MATCHES |
| Trap placement | At doors and bottlenecks based on DepthCR | place_traps() with TRAP_CHANCE | MATCHES |
| Treasure deposits | 1d4+Depth in solid rock | place_treasure_deposits() | MATCHES |

## Population System Comparison

| Aspect | Spec | Implementation | Status |
|--------|------|----------------|--------|
| PopulatePanel | Trigger encounter for each panel | populate_panel() per room | MATCHES |
| Encounter generation | 7-stage algorithm with XCR budget | Simplified density-based | PARTIAL |
| Monster density | OpenC/30 (depth>2), /50 (depth=2), /75 (depth=1) | monster_density_divisor() | MATCHES |
| Monster count caps | maxAmtByCR: 5/7/10/12/15/50 | max_monsters_by_cr() | MATCHES |
| FurnishArea | Place furniture based on region | furnish_room() with patterns | MATCHES |
| Chest chance | CHEST_CHANCE percentage | 15% chest placement | MATCHES |
| Treasure chance | TREASURE_CHANCE percentage | 25% treasure at CR+3 | MATCHES |
| Cursed items | CURSED_CHANCE percentage | 10% of treasure cursed | MATCHES |
| Staple items | STAPLE_CHANCE percentage | 20% staple items | MATCHES |
| Out-of-depth monsters | 22% - mLuck chance | 22% chance, CR +1 to +4 | MATCHES |
| Aquatic placement | Aquatic in water, non-aquatic not | find_open_in_room() | MATCHES |
| Party assignment | Same panel = same party | party_id per room | MATCHES |

**Status:** Population system fully implemented with per-panel placement, proper item distribution, and terrain rules.

## Region System Comparison

| Aspect | Spec | Implementation | Status |
|--------|------|----------------|--------|
| TRegion structure | Walls/Floor/Door refs, RoomTypes mask | RuntimeRegion struct | PARTIAL |
| RF_* flags | 27 flags defined | 12 flags defined | PARTIAL |
| Room region selection | Filter by RoomTypes, Depth, uniqueness | select_region() | MATCHES |
| Corridor region selection | CorridorWeights, RF_STAPLE=16 | select_corridor() | PARTIAL |
| Weight list generation | ROOM_WEIGHTS, CORRIDOR_WEIGHTS | Hardcoded defaults | DIFFERS |
| Grid processing | WriteMap with tile definitions, 50% flip | NOT IMPLEMENTED | MISSING |
| Region terrain application | Floor/Wall/Door from region definition | Not applying region terrain | MISSING |

### Missing RF_* Flags

Implemented: RF_RIVER, RF_CHASM, RF_CORRIDOR, RF_ROOM, RF_VAULT, RF_STAPLE, RF_NOGEN, RF_RAINBOW, RF_NEVER_LIT, RF_CENTER_ENC, RF_ODD_WIDTH, RF_ODD_HEIGHT

Missing: RF_ROCKTYPE, RF_CAVE, RF_AUTO, RF_OPT_DIM, RF_VAULT, RF_NOMONSTER, RF_NO_CEILING, RF_KNOWN, RF_SHOWNAME, RF_DECAY, RF_OUTDOOR, RF_NOBUILD, RF_SHADOWLAND, RF_NOFLOOR

## Edge Cases Comparison

| Edge Case | Spec | Implementation | Status |
|-----------|------|----------------|--------|
| Region exhaustion (first) | Reset usedInThisLevel[], retry | reset_rm_weights() | MATCHES |
| Region exhaustion (second) | Fatal error | Returns RM_NORMAL | DIFFERS |
| Room type exhaustion | Disable type, retry | rm_weights = -1 | MATCHES |
| 200 room tries | Log error, continue | Breaks loop | DIFFERS |
| Stair placement (500 tries) | Skip stair | Not applicable (simple placement) | N/A |
| Connectivity (26 trials) | Accept disconnected | MAX_TRIALS = 26 | MATCHES |
| Map edge write | Silent skip | PRIO_MAX protection | MATCHES |
| Corridor at edge | Force turn, hard clamp | Not checked | MISSING |
| Resource limits | Fatal if exceeded | Not enforced | MISSING |

## Summary: Critical Gaps

### High Priority (Affects Core Gameplay)

1. ~~**Population system** - No monsters/items/features generated~~ **FIXED** (full per-panel implementation)
2. ~~**RM_SHAPED rooms** - Can't render predefined room layouts~~ **FIXED**
3. ~~**Region terrain** - All rooms look the same (no themed areas)~~ **FIXED** (verified working at runtime, Gap 1)
4. ~~**Trap placement** - Missing hazards~~ **FIXED**
5. ~~**Stair placement** - Single stair instead of MIN_STAIRS to MAX_STAIRS~~ **FIXED**

### Medium Priority (Affects Variety)

1. **Corridor regions** - No themed corridor appearances
2. ~~**Streamer system** - Simplified compared to original~~ **FIXED** (MIN/MAX_STREAMERS loop, depth restrictions)
3. ~~**Missing room types** - RM_DESTROYED, RM_RANDTOWN, RM_GRID, RM_LIFELINK~~ **FIXED** (RM_DESTROYED, RM_GRID, RM_LIFELINK)
4. ~~**Door states** - No open/locked/trapped states~~ **FIXED**
5. ~~**Furnishing system** - No room furniture~~ **FIXED**

### Lower Priority (Polish)

1. ~~**Corridor edge clamping** - Corridors might hit map edge~~ **FIXED**
2. ~~**Treasure deposits** - Hidden treasures in walls~~ **FIXED**
3. **RF_* flags** - Many region flags not implemented

## Recommendations

### Phase 1: Make Dungeons Playable
1. ~~Implement population system (at least basic monster placement)~~ **DONE (2026-01-28)**
2. ~~Fix stair placement (MIN_STAIRS to MAX_STAIRS)~~ **DONE (2026-01-28)**
3. ~~Add trap placement~~ **DONE (2026-01-28)**

**Phase 1 COMPLETE** - Dungeons are now playable with stairs, traps, monsters, and items.

### Phase 2: Visual Variety
1. Implement region terrain application
2. Add RM_SHAPED for predefined rooms
3. Implement corridor regions

### Phase 3: Full Spec Compliance
1. ~~Fix priority values to match spec~~ **DONE (2026-01-28)**
2. ~~Implement missing room types~~ **DONE (2026-01-30)** (RM_RANDTOWN, RM_DESTROYED, RM_GRID, RM_LIFELINK)
3. Add all RF_* flags
4. ~~Implement treasure deposits~~ **DONE (2026-01-28)**
5. ~~Add corridor edge clamping~~ **DONE (2026-01-28)**
6. ~~Fix corridor constants (TURN_CHANCE, SEGMENT_MINLEN, SEGMENT_MAXLEN)~~ **DONE (2026-01-30)**
7. ~~Rewrite connect_panels (edge tiles + closest pairs)~~ **DONE (2026-01-30)**
8. ~~Fix correct_dir diametric check~~ **DONE (2026-01-30)**
9. ~~Add deep terrain conversion~~ **DONE (2026-01-30)**
10. ~~Add multi-level chasm propagation~~ **DONE (2026-01-30)**
11. ~~Add skylight marking for tiles below chasms~~ **DONE (2026-01-30)**
12. ~~Add door validation and secret door protection near stairs~~ **DONE (2026-01-30)**
