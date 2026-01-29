# Encounter Generation System

**Source**: `Encounter.cpp`
**Spec**: `docs/research/specs/dungeon-generation/population.md`
**Status**: Architecture researched from headers; partially documented in population spec

## Overview

Encounter generation creates balanced groups of monsters for dungeon population. It works within CR (Challenge Rating) constraints and supports multi-part encounters with template stacking.

## Key Data Structures

### EncMember
```cpp
struct EncMember {
    rID mID, tID, tID2, tID3;   // Monster and template IDs
    rID iID, pID;                // Item and party IDs
    rID hmID, htID, htID2;       // Humanoid mount/template IDs
    uint16 Flags, Align;
    hObj hMon;                   // Created monster handle
    int8 Part, xxx;
};
```

### TEncounter (Resource)
```cpp
class TEncounter : public Resource {
    uint32 Terrain;              // Terrain type bitmask
    int16 Weight;                // Selection weight
    int16 minCR, maxCR;          // CR range
    int16 Freak, Depth, Align;
    EncPart Parts[MAX_PARTS];    // Multi-part encounter
    uint8 Flags[(NF_LAST/8)+1];  // NF_* flags
};
```

### Encounter Flags (NF_*, 31 types)
- NF_NOGEN - Not randomly generated
- Formation and behavior flags

## EventInfo Encounter Fields

The EventInfo struct has ~40 fields dedicated to encounter generation:

### Encounter-Level
```cpp
uint32 enTerrain;    // Terrain type
int16 enCR;          // Target CR
int16 enDepth;       // Depth
int32 enXCR;         // Total XCR (experience CR)
rID enID;            // Encounter template ID
rID enRegID;         // Region ID
int16 enAlign;       // Alignment constraint
int16 enPurpose;     // Generation purpose
uint32 enFlags;      // Encounter flags
```

### Encounter Part
```cpp
int16 epMinAmt, epMaxAmt, epAmt; // Part size
int16 ep_monCR;                   // Individual monster CR
rID ep_mID;                       // Monster ID
rID ep_tID, ep_tID2, ep_tID3;    // Templates to apply
rID ep_hmID, ep_htID, ep_htID2;   // Humanoid mount/templates
int32 epXCR;                      // Part XCR budget
```

## Generation Flow

### Events
1. `EV_ENGEN` - Generate full encounter
2. `EV_ENGEN_PART` - Generate one part
3. `EV_ENBUILD_MON` - Build individual monster
4. `EV_ENCHOOSE_MID` - Choose monster ID
5. `EV_ENCHOOSE_TEMP` - Choose template
6. `EV_ENSELECT_TEMPS` - Select template combination
7. `EV_ENGEN_MOUNT` - Generate mount for rider
8. `EV_ENGEN_ALIGN` - Determine encounter alignment

### Algorithm (High Level)
1. Determine encounter CR based on depth and context
2. Select TEncounter template matching terrain/CR/depth
3. For each encounter part:
   a. Choose monster type within CR budget
   b. Apply templates (up to 3 stacking)
   c. Determine count to fill XCR budget
   d. Create individual monsters
4. Place monsters on map

### CR Budget System
- XCR (experience CR) is exponential: XCR = 2^CR
- Multi-monster encounters: sum XCR of all monsters
- Example: 4 CR2 monsters = 4 * 4 = 16 XCR = CR4 encounter

### Template Stacking
Monsters can have up to 3 templates applied:
- tID: Primary template (e.g., "Advanced")
- tID2: Secondary (e.g., "Fire")
- tID3: Tertiary (e.g., "Elite")
Templates modify base monster stats via MVal adjustments

## Room Population (RC_*, 13 types)

```
RC_EMPTY(1), RC_CLEAN(2), RC_LIGHT(3), RC_NORMAL(4),
RC_MEDIUM(5), RC_HEAVY(6), RC_PACKED(7), RC_LAIR(8),
...up to RC_LAST(13)
```

Population density determines encounter quantity and CR for each room.

## Porting Status

### Already Ported
- Basic monster placement during generation
- Room population density selection
- Monster resource lookup from .irh files

### Needs Porting
- Full encounter generation algorithm
- CR-balanced monster selection
- Template stacking
- Multi-part encounters
- Humanoid mounts and riders
- Encounter alignment constraints
- XCR budget system
- Summoning effects (share encounter generation code)
