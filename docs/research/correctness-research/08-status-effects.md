# Status Effects System

**Source**: `Status.cpp`, `inc/Creature.h` (StatiCollection)
**Status**: Architecture researched from headers

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

### Key Operations

**Adding Status Effects:**
- `GainPermStati(n, t, Cause, Val, Mag, eID, clev)` - Add permanent status
- `GainTempStati(n, t, Duration, Cause, Val, Mag, eID, clev)` - Add temporary status

**Removing Status Effects:**
- `RemoveStati(n, Cause, Val, Mag, t)` - Remove matching status
- Status removal triggers `StatiOff(s)` callback

**Querying Status Effects:**
- `HasStati(n, Val, t)` - Check if has matching status
- `GetStati(n, Val, t)` - Get first matching status
- `CountStati(n, Val, t)` - Count matching stati
- `HighStatiMag(n, Val, t)` - Highest magnitude among matching
- `SumStatiMag(n, Val, t)` - Sum of magnitudes

**Callbacks:**
- `StatiOn(s)` - Called when status becomes active
- `StatiOff(s, elapsed)` - Called when status ends (elapsed = timed out)
- `StatiMessage(n, val, ending)` - Display status message

**Template Application:**
- `GainStatiFromBody(mID)` - Apply stati from monster template
- `GainStatiFromTemplate(tID, turn_on)` - Apply stati from modifier template

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

### Field Operations
- `Map::NewField()` - Create area effect
- `Map::RemoveField()` - Remove area effect
- `Map::FieldAt()` - Check for field at location
- `Map::UpdateFields()` - Tick field durations
- `EV_FIELDON` / `EV_FIELDOFF` - Events for entering/leaving fields

## Duration System

- Duration = -1: Permanent (equipment, innate abilities)
- Duration = 0: Instantaneous (already resolved)
- Duration > 0: Remaining rounds/turns
- Decremented each turn; triggers `StatiOff(s, true)` when expired

## Nesting and Recursion

`StatiCollection.Nested` tracks nesting level to handle cases where:
- Applying a status triggers another status application
- Removing a status triggers removal of dependent stati
- Equipment changes cascade through multiple status updates

## CalcValues Integration

Status effects feed into `CalcValues()`:
1. Base attributes set from BAttr[]
2. Equipment effects applied
3. Status effects iterated and applied
4. Result stored in Attr[ATTR_LAST]

## Porting Considerations

1. **StatiCollection** - Dynamic array with index; Jai `[..]` array works
2. **Nesting counter** - Need to handle recursive status application carefully
3. **Status serialization** - Part of save/load system
4. **Duration tracking** - Need reliable turn counter
5. **Field effects** - Map-level status with spatial extent; already have GenMap in port
6. **Callback system** - StatiOn/StatiOff are virtual; need dispatch mechanism in Jai
