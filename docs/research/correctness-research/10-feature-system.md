# Feature System

**Source**: `Feature.cpp`, `inc/Feature.h`
**Status**: Architecture researched from headers

## Class Hierarchy

```
Thing
└── Feature (non-movable dungeon features)
    ├── Door (lockable/breakable portals)
    ├── Trap (triggered hazards)
    └── Portal (stairs and transport)
```

## Feature Base Class

```cpp
class Feature : public Thing {
    int16 cHP, mHP;    // Current/max hit points
    rID fID;           // Feature resource ID
    int8 MoveMod;      // Movement modifier
};
```

Key methods:
- `Name(Flags)`, `Describe(p)` - Display
- `Event(e)` - Handle events
- `StatiOn(s)`, `StatiOff(s)` - Status effect callbacks
- `Material()` - Feature material type

## Door Class

```cpp
class Door : public Feature {
    int8 DoorFlags;          // State flags
    Glyph SecretSavedGlyph;  // Hidden appearance
};
```

### Door Flags
- DF_BROKEN - Door is destroyed
- DF_LOCKED - Locked (requires key or lockpick)
- DF_OPEN - Currently open
- DF_SECRET - Secret door (hidden from view)
- DF_STUCK - Stuck (requires force to open)
- DF_JAMMED - Jammed shut

### Door Operations
- Open: Check locked/stuck → EV_OPEN
- Close: EV_CLOSE
- Lock/Unlock: EV_UNLOCK (requires key or lockpick)
- Break: Apply damage → check vs door HP → DF_BROKEN
- Secret detection: Perception check to find hidden doors
- `SetImage()` - Update glyph based on state (open/closed/secret)
- `isDead()` - Check if broken
- `Zapped(e)` - Magical effect on door

## Trap Class

```cpp
class Trap : public Feature {
    uint8 TrapFlags;   // State flags
    rID tID;           // Trap type resource ID
};
```

### Trap Flags
- Hidden/revealed state
- Disarmed state
- Triggered state

### Trap Operations
- `TriggerTrap(e, foundBefore)` - Activate trap effect
- `TrapLevel()` - Difficulty level
- Detection: Search check vs trap DC
- Disarm: EV_DISARM event
- `SetImage()` - Show/hide trap glyph

### Trap Types
Defined by TFeature resources with:
- Effect (damage, status, teleport, alarm, etc.)
- DC (difficulty class for detection/disarm)
- Level (determines in-dungeon placement depth)
- Factor (damage dice)

## Portal Class

```cpp
class Portal : public Feature {
    // No additional fields - uses fID and events
};
```

### Portal Operations
- `isDownStairs()` - Going deeper
- `Enter(e)` - Use portal (level transition)
- `EnterDir(d)` - Check if movement direction enters portal
- `Event(e)` - Handle portal events

### Level Transitions
- Stairs up: `EV_ASCEND`
- Stairs down: `EV_DESCEND`
- Depth management: `MoveDepth(NewDepth, safe)`

## Feature Template (TFeature)

```cpp
class TFeature : public Resource {
    uint32 Flags;      // Feature flags
    int16 Image;       // Display glyph
    uint8 FType;       // Feature type
    uint8 Level;       // Minimum depth
    int8 MoveMod;      // Movement cost modifier
    uint16 hp;         // Hit points
    rID xID;           // Cross-reference ID
    int16 xval;        // Extra value
    Dice Factor;       // Effect dice (for traps)
    int8 Material;     // Material type
};
```

## Porting Status

### Already Ported
- Door placement during generation (`src/dungeon/makelev.jai`)
- Basic door data in GenMap (position, open/closed state)
- Trap placement during generation
- Stairs/portal placement

### Needs Porting
- Full Door/Trap/Portal classes with methods
- Feature HP and damage system
- Door locking/unlocking/breaking mechanics
- Secret door detection
- Trap triggering and effects
- Level transition logic
- Feature-specific event handling
