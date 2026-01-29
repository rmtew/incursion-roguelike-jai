# Event System

**Source**: `Event.cpp`, `inc/Events.h`, `inc/Defines.h`
**Status**: Researched from headers

## Overview

The event system is the central dispatch mechanism for ALL game actions. Every action (attack, move, cast, pick up, etc.) is represented as an `EventInfo` struct and dispatched through the event system. Resource scripts handle events to implement custom behavior.

## EventInfo Structure

The EventInfo struct is massive (~200 fields) and serves as the universal parameter block for all game operations.

### Core Fields
```cpp
uint16 Event;            // Event type (EV_* constant)
EvParam p[5];            // 5 parameter slots (union of pointers)
Field *EField;           // Associated field
Map *EMap;               // Associated map
```

### Parameter Accessors (Macros)
```cpp
#define EActor    p[0].c    // Acting creature
#define EPActor   p[0].pl   // Acting player
#define ETarget   p[1].t    // Target thing
#define EVictim   p[1].c    // Victim creature
#define EItem     p[2].i    // Primary item
#define EWeapon   p[2].wp   // Weapon used
#define EItem2    p[3].i    // Secondary item
#define EFeat     p[1].f    // Feature
```

### EvParam Union
```cpp
union EvParam {
    Thing *t; Item *i; Creature *c; Player *pl;
    Attack *at; Feature *f; Map *m; Object *o; Weapon *wp;
};
```

### Combat Fields
```cpp
int8 vRoll, vtRoll;      // d20 roll, total roll
int8 AType, DType;       // Attack type, damage type
int8 vHit, vDef;         // Hit modifier, defense modifier
int8 vThreat, vCrit;     // Threat range, crit multiplier
int8 vArm, vPen;         // Armor, penetration
int8 saveDC;             // Save DC
int8 vCasterLev;         // Caster level
int16 vDmg, bDmg, aDmg, xDmg; // Damage values
int16 vMult, vDuration;  // Multiplier, duration
Dice Dmg;                // Damage dice
```

### Boolean Flags (~60 flags)
Combat state: `isHit`, `isCrit`, `isFumble`, `Died`, `ADied`, `Blocked`, `Saved`, `Immune`, `MagicRes`, `Resist`, `Absorb`

Perception: `actUnseen`, `vicUnseen`, `actIncor`, `vicIncor`

Combat modifiers: `Ranged`, `isAoO`, `isCleave`, `isSurprise`, `isGreatBlow`, `isSneakAttack`, `isFlanking`, `isFlatFoot`, `isOffhand`, `isGhostTouch`

Magic: `isSpell`, `isBlessed`, `isCursed`, `effDisbelieved`, `actIllusion`, `vicIllusion`, `effIllusion`

Output control: `Silence` (suppress ALL output), `Terse` (suppress non-essential)

### Positional/Directional Fields
```cpp
int16 x, y, z;          // Position and direction
int16 sp;                // Spell number
int16 EvFlags;           // Event-specific flags
int32 EParam, EParam2;   // Generic integer parameters
```

### Additional Combat Fields
```cpp
int8 vRange;             // Range
int8 vRadius;            // Area radius
int8 vOpp1, vOpp2;       // Opposed check values
int8 vRideCheck;         // Ride check result
int8 vChainCount, vChainMax; // Chain attack tracking
int8 vPenetrateBonus;    // Spell resistance penetration
Item *remainingAmmo;     // Ammunition tracking
uint32 MM;               // Metamagic flags
```

### String Fields (24 strings)
**Message strings:** `GraveText`, `strDmg`, `strXDmg`, `strHit`, `strDef`, `strOpp1`, `strOpp2`, `strBlastDmg`

**Naming system (for EV_PRINT_NAME):** `nPrefix`, `nCursed`, `nPrequal`, `nPostqual`, `nNamed`, `nBase`, `nAppend`, `nOf`, `nAdjective`, `nFlavour`, `nInscrip`, `nMech`, `nArticle`, `nPlus`, `Text`, `enDump`

### Encounter Generation Fields (~40 fields)
**Encounter-level:** `enTerrain`, `enCR`, `enDepth`, `enXCR`, `enID`, `enRegID`, `enAlign`, `enPurpose`, `enFlags`, `enFreaky`, `enSleep`, `enType`, `enPartyID`, `enDriftGE`, `enDriftLC`, `enConstraint`

**Per-part:** `epMinAmt`, `epMaxAmt`, `epAmt`, `epFreaky`, `epWeight`, `epMType`, `ep_monCR`, `ep_mountCR`, `ep_mID`, `ep_tID`, `ep_tID2`, `ep_tID3`, `ep_hmID`, `ep_htID`, `ep_htID2`, `ep_pID`, `ep_iID`, `epXCR`, `eimXCR`

### Dungeon Generation Fields
```cpp
Rect cPanel, cMap, cRoom; // Current panel/map/room during generation
int16 vDepth, vLevel;     // Generation depth/level
int16 terraKey, terrainListIndex; // Terrain mutation keys
```

### Resource Selection Fields
```cpp
uint32 chType;            // Resource type to choose
uint16 chList;            // Resource list
bool chMaximize;          // Maximize selection
bool chBestOfTwo;         // Best-of-two selection
rID chResult;             // Chosen resource ID
rID chSource;             // Source constraint
bool (*chCriteria)(EventInfo&, rID); // Custom filter callback
```

### Illusion Fields
```cpp
uint16 illFlags;          // Illusion flags
char illType;             // Illusion type
rID ill_eID;              // Illusion effect resource ID
```

## Event Types (EV_* Constants)

190+ event types organized by category:

### Movement & Navigation (1-10)
EV_MOVE(1), EV_BREAK(2), EV_PUSH(3), EV_PULL(4), EV_MIX(5), EV_POUR(6), EV_ZAP(7)

### Attack Sequence (11-28)
EV_ATTK(11), EV_NATTACK(17), EV_WATTACK(18), EV_STRIKE(19), EV_HIT(20), EV_MISS(21), EV_CRIT(22), EV_FUMBLE(23), EV_BLOCK(24), EV_PARRY(25), EV_DODGE(26), EV_ATTACKMSG(27), EV_MAGIC_HIT(28)

### Object Interaction (29-52)
EV_OPEN(29), EV_CLOSE(30), EV_DRINK(35), EV_INVOKE(36), EV_CAST(37), EV_READ(38), EV_DAMAGE(41), EV_DEATH(42), EV_FIELDON(43), EV_FIELDOFF(44), EV_REST(45), EV_WALKON(47), EV_EFFECT(52)

### Social (55-67)
EV_TALK(55), EV_BARTER(56), EV_COW(57), EV_GREET(62), EV_ORDER(63), EV_TAUNT(67)

### Combat Special (71-83)
EV_OATTACK(71), EV_HIDE(73), EV_TURNING(80), EV_JUMP(81), EV_MAGIC_STRIKE(83)

### Religion (134-149)
EV_PRAY(134), EV_SACRIFICE(135), EV_BLESSING(147), EV_GOD_RAISE(148)

### Character Creation (150-177)
EV_BIRTH(150), EV_PREREQ(151), EV_ADVANCE(153), EV_ISTARGET(155)

### Dungeon Generation (180-192)
EV_GEN_DUNGEON(180), EV_GEN_LEVEL(181), EV_GEN_PANEL(182), EV_GEN_ROOM(183), EV_ENGEN(184)

## Event Dispatch Macros

### PEVENT - Post Event
```cpp
#define PEVENT(ev, actor, xID, set_val, r) {
    EventInfo e; e.Clear();
    e.Event = ev; e.EActor = actor; e.EVictim = actor;
    e.EMap = e.EActor ? e.EActor->m : NULL;
    set_val;  // Custom setup
    r = TEFF(xID)->Event(e, xID, 0);
}
```

### DAMAGE - Damage Event
```cpp
#define DAMAGE(act, vic, dtype, amt, str, set_val) {
    EventInfo xe; xe.Clear();
    xe.Event = EV_DAMAGE; xe.EActor = act; xe.EVictim = vic;
    xe.DType = dtype; xe.vDmg = amt; xe.GraveText = str;
    set_val;
    ReThrow(EV_DAMAGE, xe);
}
```

### THROW / XTHROW / RXTHROW
```cpp
THROW(ev, set_val)            // Create and dispatch new event
XTHROW(ev, e, set_val)        // Copy event, modify, and rethrow
RXTHROW(ev, e, r, set_val)    // Like XTHROW but capture return
```

## Event Dispatch Flow

1. EventInfo populated with parameters
2. `ReThrow(ev, e)` called
3. ReThrow searches resource database for handlers
4. Calls `TEFF(xID)->Event(e, xID, 0)` for each matching handler
5. Return value (EvReturn) determines continuation:
   - ERROR(-1): Failed
   - NOTHING(0): Continue
   - DONE(1): Complete
   - ABORT(2): Cancel operation
   - NOMSG(3): Success but suppress messages

## Porting Considerations

1. **EventInfo size** - This is a massive struct. In Jai, could use a similar flat struct or break into sub-structs by category (combat, encounter, chargen)
2. **EvParam union** - Jai has tagged unions; could use `#type_info` or explicit tag
3. **Dispatch macros** - Replace with inline procedures in Jai
4. **Event handler lookup** - Currently via virtual methods and resource scripts; in Jai, use procedure tables or tagged dispatch
5. **String fields** - Many temporary strings in EventInfo; Jai's string handling differs
6. **The ~60 boolean flags** - Could use a bitfield in Jai
