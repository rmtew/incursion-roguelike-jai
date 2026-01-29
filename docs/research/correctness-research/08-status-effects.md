# Status Effects System

**Source**: `Status.cpp`, `inc/Creature.h` (StatiCollection)
**Status**: Fully researched

## Overview

Status effects (stati) are the universal mechanism for temporary and permanent modifications to creatures. They track buffs, debuffs, conditions, equipment effects, and more.

## Status Structure

```cpp
struct Status {
    int16 Nature;      // Status type identifier
    int16 Val;         // Primary value (context-dependent)
    int16 Mag;         // Magnitude
    int16 Duration;    // Remaining duration (-1 = permanent)
    int8 Source;       // What caused this status
    int8 CLev;         // Caster level (for dispelling)
    int8 Dis;          // Display category
    bool Once;         // Has been applied once
    rID eID;           // Effect resource ID
    hObj h;            // Handle to source object
};
```

## StatiCollection

Container managing all status effects on a Thing:

```cpp
struct StatiCollection {
    Status* S;         // Status array
    Status* Added;     // Recently added stati
    int16 szAdded;     // Count of added
    uint16* Idx;       // Index array (for fast lookup)
    int16 Last;        // Last used element
    int16 Allocated;   // Allocated size
    int16 Removed;     // Count removed
    int8 Nested;       // Nesting level (for recursive application)
};
```

### Querying
```cpp
HasStati(n, Val, t)         // Check if has matching status
GetStati(n, Val, t)         // Get first matching status
GetEffStati(n, xID, Val, t) // Get status by effect ID
CountStati(n, Val, t)       // Count matching stati
HighStatiMag(n, Val, t)     // Highest magnitude among matching
SumStatiMag(n, Val, t)      // Sum of magnitudes
HasStatiFrom(t)             // Has any status from source t
HasEffField(eID)            // Has field created by this creature
```

### Callbacks
```cpp
StatiOn(s)                  // Called when status becomes active
StatiOff(s, elapsed)        // Called when status ends
StatiMessage(n, val, ending) // Display status message to player
```

### Template Application
```cpp
GainStatiFromBody(mID)          // Apply stati from monster template
GainStatiFromTemplate(tID, on)  // Apply/remove modifier template stati
```

## Applying Status Effects

### GainTempStati Process

`GainTempStati(n, t, Duration, Cause, Val, Mag, eID, clev)`:

1. **Validation**: Check nature in range (1..LAST_STATI). Grapple statuses require source object.
2. **Enchantment stacking**: If Source=SS_ENCH and identical Val/Mag/h/eID exists with Duration>0, add new duration to existing instead of duplicating.
3. **Memory allocation**: If inside StatiIter loop (Nested>0), store in temporary `Added` buffer; otherwise allocate directly in `S` array. Array grows lazily: starts at 0, first alloc 4, doubles each realloc, max 256.
4. **Initialize**: Set Nature, Duration, Source, CLev, Once=0, Dis=0. Special case: TRAP_EVENT swaps Val/Mag.
5. **Back-references**: If status refers to another object, add this creature to that object's `backRefs`.
6. **Post-application**: Call `_FixupStati()`, then `StatiOn(s)` callback, throw `EV_GAIN_STATI` event, call `StatiMessage()`.

`GainPermStati(...)` is a wrapper that calls GainTempStati with Duration=0.

### _FixupStati Consolidation

Called after modifications to consolidate the collection:
1. Merge `Added` buffer into main `S` array
2. Sort all statuses by Nature via `qsort()`
3. Rebuild `Idx[]` lookup index for each Nature
4. Track first ADJUST-type status for StatiIterAdjust macro
5. Compact: remove entries marked for deletion

## Removing Status Effects

Five removal strategies:

```cpp
RemoveStati(n, Cause, Val, Mag, t)    // By nature + params (wildcards: -1)
RemoveOnceStati(n, Val)               // One-time (SS_ONCE source only)
RemoveEffStati(eID, ev, butNotNature) // By effect ID (throws events)
RemoveStatiFrom(t, ev)               // All from specific source object
RemoveStatiSource(ss)                // All with specific Source type
```

### RemoveEffStati Event Handling
1. Throws event `ev` (e.g., EV_ITEM_REMOVED)
2. If no handler returns ABORT, throws EV_REMOVED
3. Calls StatiMessage if handler returned NOTHING
4. Skips SS_MONI (monitoring) statuses

### CleanupRefedStati (Dangling Reference Cleanup)
When a creature dies/is removed:
- Iterates its `backRefs` array
- For SS_ATTK sources (except GRAPPLED/STUCK/GRABBED/GRAPPLING): **genericizes** (sets h=0, status persists without source)
- For other sources: removes status completely
- Restarts search after each removal (cascading changes possible)

## Stacking Rules

### Enchantment Stacking
- Source=SS_ENCH, identical Val/Mag/h/eID, Duration>0: adds duration to existing (no duplicate)

### Attack-Based Genericization
- When source creature dies, SS_ATTK statuses (except grapple types): h set to 0, status persists without source
- Example: Blindness from acid splash persists even after attacker dies

### Conflicting Statuses (resolved in StatiOn)
| Conflicts | Resolution |
|---|---|
| RAGING + AFRAID | Mutually exclusive (later removes earlier) |
| AFRAID + ENGULFER | AFRAID causes drop of engulfed creatures |
| PHASED + ANCHORED | Mutually exclusive |
| MANIFEST + PHASED/HIDING/INVIS | MANIFEST overrides all |
| SPRINTING + many | Removed by LEVITATION, POLYMORPH, STUNNED, CONFUSED, GRAPPLED, GRABBED, GRAPPLING, STUCK, PARALYSIS, ENGULFED, PRONE |

## StatiOn Callback (Creature)

Key status-specific behaviors when applied:

| Status | On Behavior |
|---|---|
| CHARGING | Reveal creature |
| AFRAID | Drop ENGULFER, remove RAGING |
| RAGING | Remove AFRAID |
| TEMPLATE | Call GainStatiFromTemplate |
| INVIS/INVIS_TO | RippleCheck(15), remove CHARGING, SetImage, VUpdate |
| HIDING | Remove CHARGING, SetImage, VUpdate |
| POISONED/DISEASED | Throw EV_EFFECT with isWield=true |
| ANCHORED | Remove PHASED |
| MANIFEST | Remove HIDING/INVIS/PHASED, call Planeshift |
| PHASED | Call Planeshift, RippleCheck if PHASE_ETHEREAL |
| POLYMORPH | Call Shapeshift, visual notification |
| BLIND | Set UpdateMap flag |
| CHARMED | Make companion if from player; remove old targets; Retarget |
| ILLUMINATED | Reveal if HIDING |
| PRONE | Try to maintain mount; EV_DISMOUNT if fail |
| LEVITATION | If MOUNTED, throw EV_DISMOUNT |
| TRUE_SIGHT/DISBELIEVED | Remove ILLUS_DMG from source; Retarget if monster |
| ENRAGED/CONFLICT/DISGUISED | Retarget all creatures; SetImage |
| NEUTRAL_TO/ENEMY_TO/ALLY_TO | Retarget creatures of matching type |
| INNATE_SPELL | Set SP_INNATE flag in player spell flags |
| ASLEEP | Remove HIDING/CHARGING/TUMBLING |

Most statuses trigger CalcValues() recalculation.

## StatiOff Callback (Creature)

Key behaviors when status expires or is removed:

| Status | Off Behavior |
|---|---|
| STONING | If elapsed + failed resist: create statue, kill creature, place; else: "feel limber" |
| MANIFEST/PHASED | Call Planeshift |
| CHARMED | If no other CHARMED from source, make enemy; Retarget |
| TEMPLATE | Call GainStatiFromTemplate(false) |
| POISONED/DISEASED | Throw EV_EFFECT with isRemove=true |
| INVIS/HIDING/INVIS_TO | SetImage, VUpdate |
| SUMMONED/ILLUSION | Drop non-property items to ground; remove creature |
| DETECTING | Remove F_HILIGHT from all map creatures |
| POLYMORPH | Return to original form; update player visuals |
| TRANSFORMED | Place original back; remove transformed version |
| HUNGER | If elapsed: "starve to death", throw EV_DEATH |
| BLIND | Set UpdateMap flag |
| SINGING | Remove all SS_SONG statuses from creatures sourced from this creature |
| ILLUS_DMG | Restore HP (cHP += s.Mag) |
| ENRAGED/CONFLICT/DISGUISED | Retarget all creatures; SetImage |
| INNATE_SPELL | Clear SP_INNATE flag |
| SLIP_MIND | Auto saving throw vs original enchantment; if success, remove it |

General cleanup: SetImage, CalcValues, remove mobile fields with matching eID, VUpdate if player.

### Item StatiOn/StatiOff
- DISPELLED/BOOST_PLUS: Call ReApply()
- SUMMONED/ILLUSION: Remove item ("winks out")

## Status Types

Status effects are identified by their Nature field. Categories include:

### Attribute Modifications
- Attribute bonuses/penalties
- ADJUST_* constants (ADJUST_IDX through ADJUST_LAST, 18 types)

### Combat Conditions
- Blind, Paralyzed, Stunned, Confused
- Grappled, Held, Prone
- Flat-footed, Surprised

### Buffs/Enhancements
- Haste, Bless, Shield of Faith
- Stat boosts, skill bonuses
- Protection effects

### Debuffs
- Disease, Poison
- Ability drain, Level drain
- Curses

### Equipment Effects
- Effects from worn/wielded items
- Aura effects
- Quality-based effects

### Status Types with Special Handling

| Status | Special Handling |
|---|---|
| PERIODIC | Skip duration decrement if already active from same source |
| HUNGER | Call GetHungrier() instead of normal decrement |
| SLOW_POISON | Prevents POISONED from decrementing |
| ACTING | Throw held item/creature on expiration |
| TRAP_EVENT | Swap Val/Mag before storage (event code encoding) |
| GRAPPLING/GRABBED/GRAPPLED | Require source object (enforced in GainTempStati) |
| STONING | Convert to statue on expiration with resist check |
| SS_ENCH source | Duration stacking instead of duplication |
| SINGING | Remove related song effects from others on expiration |
| TRANSFORMED/POLYMORPH | Restore original form on expiration |
| SUMMONED/ILLUSION | Remove creature and drop items on expiration |
| INNATE_SPELL | Modifies player spell flags directly |
| CHARMED | Alters AI targeting and companion status |
| TEMPLATE | Calls template-based status application system |
| SLIP_MIND | Automatic second saving throw on removal |

### Field Effects
Fields are area effects on the map:
```cpp
struct Field {
    rID eID;           // Effect ID
    uint32 FType;      // Field type
    Glyph Image;       // Display glyph
    uint8 cx, cy, rad; // Center and radius
    int16 Dur;         // Duration
    hObj Creator;      // Creator handle
    hObj Next;         // Linked list next
    int8 Color;        // Display color
};
```

### Field Type Flags (FI_*)
```
FI_LIGHT      // Provides light
FI_DARKNESS   // Provides darkness
FI_FOG        // Obscurement
FI_SILENCE    // Silence field
FI_SHADOW     // Shadow field
FI_MODIFIER   // Custom effect field
FI_ITERRAIN   // Illusory terrain
FI_SIZE       // Creature size field
FI_MOBILE     // Field moves with creator
FI_NO_PRESS   // Field collapses if entered by enemy
```

### Field Lifecycle

**Creation** (`NewField`): Allocate, set parameters, update tile flags (hasField, Dark, mLight, mObscure), throw EV_FIELDON for each creature in area.

**Movement** (`MoveField`): Validate creator/eID. For SIZE fields: check creature can fit (allow up to radius*3 edge blocks). Collect entering/leaving creatures. For EF_NO_PRESS: collapse if enemy enters. Update tile flags. Throw EV_FIELDOFF for leaving, EV_FIELDON for entering.

**Removal** (`RemoveField`): Remove from Fields array, update tile flags, throw EV_FIELDOFF for each creature in area, VUpdate.

**Enter/Leave callbacks** (`FieldOn`/`FieldOff`):
- FI_LIGHT: Remove HIDING
- FI_SILENCE: Remove SINGING
- FI_DARKNESS/SHADOW: Message only
- FI_MODIFIER: Throw EV_EFFECT with isEnter/isLeave

**PTerrainAt**: Perceived terrain considering illusory terrain fields (FI_ITERRAIN). Checks disbelief, TRUE_SIGHT, blindsight. Throws EV_ITERRAIN for effect to decide actual terrain.

### Field Operations
```cpp
Map::NewField(FType, x, y, rad, Img, Dur, eID, Creator)
Map::RemoveField(f)
Map::RemoveEffField(eID)        // Remove all fields with effect ID
Map::RemoveFieldFrom(h)         // Remove all fields by creator
Map::RemoveEffFieldFrom(eID, h) // Remove by both
Map::FieldAt(x, y)
Map::DispelField(x, y, FType, eID, clev)
Map::MoveField(f, cx, cy, is_walk)
Map::UpdateFields()              // Dur-- for Dur>1; remove when Dur=1
```

## Duration System

| Duration | Meaning |
|---|---|
| > 0 | Temporary: decremented each turn, StatiOff(s,true) when expired |
| 0 | Permanent: never expires |
| -1, -2 | Persistent/permanent fields: never decremented |

### UpdateStati() Per-Turn Processing
1. Skip dead/invalid creatures
2. **PERIODIC**: Skip decrement if already active from same source
3. **SLOW_POISON**: If POISONED and has SLOW_POISON, skip decrement
4. **HUNGER**: Call GetHungrier(1) instead of normal decrement
5. All others: Duration--
6. **ACTING expiration**: Throw held item/creature (Val determines target, Mag determines direction)
7. Other expirations: StatiIter_ElapseCurrent()

### Field Duration (UpdateFields)
- Dur > 1: Dur-- each turn
- Dur == 1: Remove field
- Dur <= 0: Never expires (-1 = permanent)

## Nesting and Recursion

`StatiCollection.Nested` tracks nesting level:
- During StatiIter loops, new statuses go to `Added` buffer (max ADDED_SIZE=128)
- Prevents corruption of array being iterated
- `_FixupStati()` merges Added into S after iteration completes

## CalcValues Integration

Status effects feed into `CalcValues()`:
1. Base attributes set from BAttr[]
2. Equipment effects applied
3. Status effects iterated and applied
4. Result stored in Attr[ATTR_LAST]

Most StatiOn callbacks trigger CalcValues() recalculation.

## Porting Considerations

1. **StatiCollection** - Dynamic array with index; Jai `[..]` array works
2. **Nesting counter** - Need to handle recursive status application carefully
3. **Status serialization** - Part of save/load system
4. **Duration tracking** - Need reliable turn counter
5. **Field effects** - Map-level status with spatial extent; already have GenMap in port
6. **Callback system** - StatiOn/StatiOff are virtual; need dispatch mechanism in Jai
