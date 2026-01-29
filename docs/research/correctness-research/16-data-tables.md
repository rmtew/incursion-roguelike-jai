# Data, Tables & Support Systems

**Source**: `Tables.cpp`, `Annot.cpp`, `Target.cpp`, `Res.cpp`, `Base.cpp`, `Registry.cpp`, `Debug.cpp`
**Status**: Architecture identified from headers

## Tables (Tables.cpp)

### Static Data
Tables.cpp contains hard-coded data tables with no active code:
- Saving throw progression tables
- Base attack bonus tables
- Experience point tables
- Skill point tables
- Static arrays for game mechanics

### Purpose
These tables define the d20 system progression curves:
- How saving throws improve per class/level
- How BAB progresses (good/average/poor)
- XP thresholds per level

## Annotations (Annot.cpp)

### Overview
Annotations extend Resource objects with typed metadata. They are the primary mechanism for attaching complex data to resources.

### Annotation Types
| Function | Data Stored |
|----------|-------------|
| `AddResID(at, sID)` | Resource cross-references |
| `AddAbility(...)` | Class/creature abilities |
| `AddEvent(...)` | Event handlers (script code) |
| `AddEquip(...)` | Equipment grants (starting gear) |
| `AddTile(...)` | Map tile definitions |
| `AddPower(...)` | Powers/abilities |
| `GetConst(cn)` | Named constants |
| `GetList(ln, lv, max)` | Resource lists |

### Access Pattern
```cpp
// Get constant from resource
uint32 value = RES(rID)->GetConst(CONST_NAME);

// Iterate sub-resources
rID sub = RES(rID)->FirstRes(AT_TYPE);
while (sub) {
    // process sub
    sub = RES(rID)->NextRes(AT_TYPE);
}

// Grant equipment
RES(rID)->GrantGear(creature, ...);
```

## Targeting (Target.cpp)

### TargetSystem
Monster class contains `TargetSystem ts` for tracking targets:
```cpp
void TurnHostileTo(Creature *cr)     // Become hostile
void TurnNeutralTo(Creature *cr)     // Become neutral
void Pacify(Creature *cr)            // Stop attacking
void ForgetOrders(int ofType)        // Clear orders
void Consider(Thing *t)              // Evaluate thing
bool hasTargetOfType(TargetType t)   // Check target type
bool hasTargetThing(Thing *t)        // Check specific target
```

### Hostility Levels
Multi-level hostility system:
- Friendly (allied)
- Neutral (non-hostile)
- Hostile (will attack)
- Determined by alignment, actions, and events

## Resource Runtime (Res.cpp)

### Runtime Operations
- Resource ID to pointer resolution
- Random resource selection by type/level/range
- Player memory management (what player has identified)
- Resource name formatting

### Random Resource Selection
```cpp
Module::RandomResource(uint8 RType, int8 Level, int8 Range)
```
Selects a random resource matching type and level constraints.

## Base Data Structures (Base.cpp)

### String Operations
- Buffer management with canary values
- String concatenation, comparison, searching
- Color code handling (embedded in strings)
- Serialization support

### Array Operations
- Dynamic resize with Initial/Delta strategy
- Serialization of array contents
- Index management

### Dictionary
Binary search tree for word-to-ID mapping:
- `ProcessName()` - Parse multi-word names
- `InsertWord()` - Add to dictionary
- `Parse()` - Lookup word

## Registry (Registry.cpp)

### Object Management
- Handle (hObj) based object references
- Object creation and destruction
- Type-safe retrieval: `GetThing()`, `GetCreature()`, `GetItem()`, etc.

### Save/Load
- Serialize all objects in registry
- Handle fixup after load (pointer reconstruction)
- Module and game state persistence

## Debug (Debug.cpp)

### Wizard Mode
Debug commands for testing:
- Object inspection
- Monster scrutiny
- Level treasure listing
- Container inspection

### Dump Functions (lines 1856-1978)
Output all fields of game objects - essential for verification:
```cpp
void Thing::Dump()
void Creature::Dump()
void Item::Dump()
void Feature::Dump()
// etc.
```

## Bonus Type System (BONUS_*, 39 types)

D&D 3.5e bonus types for stacking rules:
```
BONUS_BASE(0), BONUS_ARMOR(1), BONUS_SHIELD(2), BONUS_NATURAL(3),
BONUS_DEFLECT(4), BONUS_DODGE(5), BONUS_ENHANCE(6), BONUS_LUCK(7),
BONUS_MORALE(8), BONUS_INSIGHT(9), BONUS_SACRED(10), BONUS_PROFANE(11),
BONUS_RESIST(12), BONUS_COMP(13), BONUS_CIRC(14), BONUS_SIZE(15),
... up to BONUS_LAST(39)
```

### Stacking Rules
- Same-type bonuses generally DON'T stack (only highest applies)
- Exceptions: BONUS_DODGE always stacks
- Unnamed bonuses may stack (implementation-dependent)
- Penalties always stack

## Porting Considerations

1. **Tables** - Static data, direct port to Jai constants
2. **Annotations** - Flexible metadata; design Jai equivalent (tagged union or struct)
3. **Targeting** - AI subsystem; port with Monster AI
4. **Registry** - Core design decision: handle system vs direct pointers
5. **Bonus stacking** - Critical for correctness; verify all 39 types
6. **Debug/Dump** - Essential for verification during porting
7. **Dictionary** - May not need full port (Jai has hash maps)
