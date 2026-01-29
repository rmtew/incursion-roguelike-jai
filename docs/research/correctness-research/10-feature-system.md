# Feature System

**Source**: `Feature.cpp`, `inc/Feature.h`
**Status**: Fully researched

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

### Feature Methods
```cpp
virtual String & Name(int16 Flags=0);
virtual String & Describe(Player *p);
EvReturn Event(EventInfo &e);
virtual void StatiOn(Status s);
virtual void StatiOff(Status s);
virtual int8 Material();          // returns TFEAT(fID)->Material
```

### Feature Constructors
```cpp
Feature(int16 Image, rID _fID, int16 _Type);  // Explicit image/type
Feature(rID _fID);                              // Defaults from resource
```
Both constructors: set `fID`, `Timeout = -1`, copy `Flags`/`MoveMod`/`cHP`/`mHP` from `TFEAT(fID)`. Second constructor defaults to `TFEAT(_fID)->Image` and `T_FEATURE`.

## Door Class

```cpp
class Door : public Feature {
    int8  DoorFlags;          // 8-bit bitmask of DF_* flags
    Glyph SecretSavedGlyph;   // Saved glyph for secret door display
};
```

### Door Flags (8-bit, `Defines.h:2231-2239`)
```cpp
DF_VERTICAL  0x01   // Door is vertical orientation
DF_OPEN      0x02   // Currently open
DF_STUCK     0x04   // Stuck (requires force to open)
DF_LOCKED    0x08   // Locked (requires key or lockpick)
DF_TRAPPED   0x10   // Door is trapped
DF_SECRET    0x20   // Secret door (hidden from view)
DF_BROKEN    0x40   // Door is destroyed
DF_SEARCHED  0x80   // Has been searched
DF_PICKED    0x80   // Lock has been picked (alias of DF_SEARCHED)
```
**Note**: `DF_SEARCHED` and `DF_PICKED` share the same value (0x80). These `DF_*` constants are unrelated to the 32-bit damage flags (`DF_FIRE`, `DF_COLD`, etc.) or the pathfinding danger flags (`DF_ALL_SAFE`, etc.) - naming collision in original source.

### Door Methods
```cpp
Event(EventInfo &e)          // Handle events
SetImage()                   // Update glyph based on state
isDead()                     // (Flags & F_DELETE) || (DoorFlags & DF_BROKEN)
Describe(Player *p)          // Description text
Zapped(EventInfo &e)         // Magical effect on door
```

### Door Initialization
Two modes:
- **Normal**: 10% open, 90% closed. Of closed: 50% locked. ~14% secret overall.
- **Weimer**: All doors start locked and solid.

### EV_OPEN Flow
1. Validate: must have hands (not M_NOHANDS), material plane
2. Cannot open broken or already-open doors
3. **Lock picking (if locked, not wizard-locked)**:
   - Check TRIED status (prevents immediate retry)
   - `SK_LOCKPICKING` vs DC = `14 + dungeon_depth` (+10 if wizard-locked)
   - Retry bonus carries forward (+2 per attempt via `BoostRetry()`)
   - Success: clear DF_LOCKED, award `90 + (diff-14)*10` XP
   - Failure: set TRIED status (temporary)
4. Open: clear F_SOLID, set DF_OPEN, clear DF_SECRET, timeout 15

### EV_CLOSE
Validate hands, material plane, not broken, not already closed. Set F_SOLID, clear DF_OPEN. Timeout 15.

### SetImage() Logic
1. Determine orientation from adjacent solids
2. Secret: display as adjacent terrain, set F_INVIS, mark solid/opaque
3. Open: show `+`, not solid
4. Closed: GLYPH_VLINE or GLYPH_HLINE by orientation
5. Broken: GLYPH_BDOOR
6. Wizard-locked: RED background

## Trap Class

```cpp
class Trap : public Feature {
    uint8 TrapFlags;   // State flags
    rID tID;           // Trap type resource ID
};
```

### Trap State Flags (`TS_*`, `Defines.h:1223-1227`)
```cpp
TS_FOUND     0x0001   // Trap has been discovered
TS_DISARMED  0x0002   // Trap has been disarmed
TS_NODISARM  0x0004   // Cannot be disarmed
TS_SEARCHED  0x0008   // Has been searched
TS_NORESET   0x0010   // Does not reset after triggering
```

### Trap Methods
```cpp
Event(EventInfo &e)                      // Handle events
Name(int16 Flags=0)                     // Display name
SetImage()                               // Show/hide trap glyph
TrapLevel()                              // returns TEFF(tID)->Level
TriggerTrap(EventInfo &e, bool foundBefore) // Activate trap effect
```

### Trap Constructor
```cpp
Trap(rID _fID, rID _tID)
    : Feature(TFEAT(_fID)->Image, _fID, T_TRAP)
    , TrapFlags(0), tID(_tID)
    { SetImage(); }
```

### TriggerTrap Process
1. **Discovery**: if not found before, all perceiving players learn of trap
2. **Saving throw DC**: `15 + trap_level` (+5 if not previously found)
   - Non-mundane traps: combine trap + magic save types
   - FT_FEATHERFOOT: auto-avoid if previously found
3. **Execute**: set isTrap, caster level=12, ReThrow(EV_EFFECT)
4. **Outcome**:
   - Victim revealed, action halted
   - XP to trap placer (RESET_BY): `100 + 25 × victim_CR`
   - If trap kills monster: also award kill XP
   - Auto-disarms after triggering (sets TS_DISARMED)

### Trap SetImage
- Show GLYPH_TRAP or GLYPH_DISARMED based on state
- Invisible (F_INVIS) until TS_FOUND set
- Color from `TEFF(tID)->ef.cval`

### Trap Types
Defined by TFeature resources with:
- Effect (damage, status, teleport, alarm, etc.)
- DC (difficulty class for detection/disarm)
- Level (determines in-dungeon placement depth)
- Factor (damage dice)

## Portal Class

```cpp
class Portal : public Feature {
    // No additional fields beyond Feature base
};
```

### Portal Type Constants (`POR_*`, `Defines.h:3405-3414`)
Stored in `TFeature::xval`:
```cpp
POR_UP_STAIR    1    // Upward stairs
POR_DOWN_STAIR  2    // Downward stairs
POR_STORE       3    // Store entrance
POR_BUILDING    4    // Building entrance
POR_GUILD       5    // Guild entrance
POR_POCKET      6    // Rope Trick pocket dimension
POR_DUN_ENTRY   7    // Dungeon entry point
POR_SUBDUNGEON  8    // Subdungeon entrance
POR_TOWN        9    // Town entrance
POR_RETURN      10   // Return portal
```

### Portal Methods
```cpp
isDownStairs()   // returns TFEAT(fID)->xval == POR_DOWN_STAIR
Event(EventInfo &e)
Enter(EventInfo &e)
EnterDir(Dir d)
```

### EnterDir() Logic
- UP_STAIR: only via UP direction
- DOWN_STAIR: only via DOWN direction
- Default: via CENTER direction

### Portal::Enter() Level Transition
**Down/Up stairs**: `MoveDepth(m->Depth ± 1, true)` with player confirmation for unsafe areas.

**Dungeon entry**: `GetDungeonMap(TFEAT(fID)->xID, 1, player, NULL)`, store ENTERED_AT status, place at EnterX/EnterY.

**Return portal**: Find ENTERED_AT status with matching portal, place at original location, clean up status.

### PRE_ENTER Validation
- Dwarven Focus check: if focused creature is on this level, block with ABORT ("will not flee while <Obj> still lives!")

## Feature Template (TFeature)

```cpp
class TFeature : public Resource {
    uint32 Flags;      // Terrain feature flags (TF_* bit indices)
    int16 Image;       // Display glyph
    uint8 FType;       // Feature type
    uint8 Level;       // Minimum depth
    int8 MoveMod;      // Movement cost modifier
    uint16 hp;         // Hit points
    rID xID;           // Cross-reference ID
    int16 xval;        // Extra value (e.g., POR_* for portals)
    Dice Factor;       // Effect dice (for traps)
    int8 Material;     // Material type
};
```

### Terrain Feature Flags (`TF_*`, bit indices, `Defines.h:677-703`)
These are bit indices (not bitmasks) used with bit-test operations on `TFeature::Flags`:
```cpp
TF_SOLID       1    // Blocks movement
TF_OPAQUE      2    // Blocks LOS
TF_OBSCURE     3    // Foggy/misty
TF_SHADE       4    // Shaded
TF_SPECIAL     5    // Special terrain
TF_WARN        6    // Warning terrain
TF_WATER       7    // Water terrain
TF_TORCH       10   // Torch/light source
TF_EFFECT      11   // Has associated effect
TF_SHOWNAME    12   // Show terrain name
TF_NOGEN       13   // Don't place during generation
TF_INTERIOR    14   // Show as normal wall from outside
TF_TREE        15   // Tree terrain
TF_DEEP_LIQ    16   // Deep liquid
TF_UNDERTOW    17   // Undertow (drowning hazard)
TF_FALL        18   // Fall hazard
TF_STICKY      19   // Sticky terrain (slows)
TF_WALL        20   // Wall terrain
TF_BSOLID      21   // Blocks rays/blasts
TF_MSOLID      22   // Blocks magical travel
TF_CONCEAL     23   // Conceals items within
TF_VERDANT     24   // Verdant/natural
TF_LOCAL_LIGHT 25   // Self-lit (no radius)
TF_DEPOSIT     26   // Mineral deposit
TF_PIT         27   // Pit terrain
TF_LAST        28
```

### Thing Flags (`F_*`, bitmask, `Defines.h:237-252`)
Inherited from `Thing::Flags` (uint32):
```cpp
F_SOLID       0x0001   // Prevents travel
F_XSOLID      0x0002   // Prevents ethereal travel
F_INVIS       0x0004   // Invisible
F_DELETE      0x0008   // Marked for deletion
F_UPDATE      0x0010   // Glyph changed this turn
F_HILIGHT     0x0100   // Detect effects highlight
F_OPAQUE      0x0200   // Opaque
F_HIDING      0x0400   // Hiding
F_FOCUS       0x0800   // Dwarven focus target
F_NO_MEMORY   0x1000   // Don't show in map memory
F_TREE        0x2000   // Tree
F_OBSCURE     0x4000   // Obscurement
F_STICKY      0x8000   // Sticky
F_WARN        0x10000  // Warning
F_BRIDGE      0x20000  // Bridge
F_ALTAR       0x40000  // Altar
```

### Feature Type Constants
```cpp
T_PORTAL   10
T_DOOR     11
T_TRAP     12
T_FEATURE  13
T_ALTAR    14
T_BARRIER  15
```

## Feature HP and Damage (EV_DAMAGE)

### Damage Processing
1. Material hardness: `MaterialHardness(TFEAT(fID)->Material, e.DType)` → -1 = immune, ≥0 = reduction
2. Sunder feat/quality: ×2 damage multiplier
3. Actual damage: `e.aDmg = e.vDmg - hardness`
4. If aDmg > 0: `cHP -= aDmg`

### Destruction (cHP ≤ 0)
Messages vary by damage type: SONIC="shatters", ACID="eaten away", FIRE="burns down", other="destroyed".
- Broadcast sound at range 20
- Clear actor's ACTING status
- If trapped door destroyed: trap triggers automatically
- Remove(true) destroys feature

### Door-Specific Damage
- Planar immunity: damage passes through if on different planes
- Piercing non-blunt: 1/3 damage
- Wizard-locked: ×2 HP multiplier
- STR exercise on successful break (random 1-12)
- Repeating kicks: OPT_REPEAT_KICK auto-repeats (max 20 attempts)

## Level Transition System (Limbo)

### Limbo Queue
Manages entities following player across levels:
```cpp
struct LimboEntry {
    hObj h;           // Entity handle
    int16 x, y;      // Position on new map
    rID mID;          // Target dungeon
    int16 Depth;      // Target depth
    int16 OldDepth;   // Source depth
    int32 Arrival;    // Turn number to place
    String Message;   // Entry message
};
```

**EnterLimbo()**: Remove entity from old map, add to queue with arrival time.
**LimboCheck()**: Called each turn; when `Arrival ≤ Turn`, place entity at target location.

### Player::MoveDepth() Flow
1. Store level stats, save game
2. Clear movement statuses (SPRINTING, ENGULFED, GRAPPLED, etc.)
3. Navigate: depth≤0 → ABOVE_DUNGEON, depth>max → BELOW_DUNGEON, else same dungeon
4. Collect followers: nearby monsters where `ts.isLeader(this)`, remove from old map
5. Dwarven Focus check: if target on this level, XP penalty + lose focus
6. Find safe landing: random position, avoid solid/vault/pits if safe mode
7. Place player + followers, refresh display, NoteArrival()

### GetDungeonMap() Caching
```cpp
DungeonID[i]      // Resource ID of dungeon
DungeonSize[i]    // Max depth
DungeonLevels[i]  // Array of map handles per depth
```
Generates maps on demand, stores handles for reuse. Links stairs across intermediate depths.

## Status Types Used by Features
- ACTING - Door being kicked repeatedly
- TRIED - Lock pick attempted (prevents immediate retry)
- RETRY_BONUS - Cumulative skill check bonus
- WIZLOCK - Magical lock (harder DC, mental open)
- DWARVEN_FOCUS - Prevents fleeing from target
- ENTERED_AT - Remembers entry portal for return
- RESET_BY - Trap placer (for XP distribution)
- XP_GAINED - Trap already awarded XP
- SUMMONED - Temporary feature (removed on status loss)

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
