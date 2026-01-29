# Object & Registry System

**Source**: `Base.cpp`, `Registry.cpp`, `inc/Base.h`
**Status**: Researched from headers

## Core Types

### Primitive Types
```cpp
rID    = unsigned long    // Resource ID (module << 24 | offset)
hObj   = signed long      // Object handle (registry index)
hData  = signed long      // Data handle
Glyph  = unsigned long    // 32-bit glyph (char:12, fg:4, bg:4, ...)
Dir    = signed char      // Direction enum
EvReturn = signed char    // Event return (-1=ERROR, 0=NOTHING, 1=DONE, 2=ABORT, 3=NOMSG)
```

### String Class
Custom string with buffer management and canary guard value:
- `int32 Canary` - Guard value for memory corruption detection
- `char* Buffer` - Character data
- `int32 Length` - String length
- Methods: `Trim()`, `Replace()`, `Upper()`, `Lower()`, `Capitalize()`, `Decolorize()`
- Color codes embedded in strings (Decolorize strips them)

### Array Template
```cpp
template<class S, int32 Initial, int32 Delta> class Array
```
- `S* Items` - Dynamic array
- `uint32 Size, Count` - Capacity and used count
- Methods: `Add()`, `Remove()`, `Clear()`, `Total()`, `NewItem()`, `Serialize()`
- Variants: `NArray` (operator[] returns values), `OArray` (operator[] returns pointers)

### Dice Struct
```cpp
struct Dice { int8 Number, Sides, Bonus; }
```
- `Roll()` - Roll the dice
- `LevelAdjust()` - Adjust by level
- `Str()` - String representation (e.g., "2d6+3")

### MVal (Modifier Value)
Bitfield struct for attribute modifiers:
- `Value:10` - The modifier value
- `VType:4` - Type (MVAL_NONE=0, MVAL_ADD=1, MVAL_SET=2, MVAL_PERCENT=3)
- `Bound:10` - Bound value
- `BType:4` - Bound type (MBOUND_NONE, MBOUND_MIN, MBOUND_MAX, MBOUND_NEAR)
- `Adjust(int16 oval)` - Apply modifier to original value

### Rect Struct
```cpp
struct Rect { uint8 x1, x2, y1, y2; }
```
- Methods: `Within()`, `PlaceWithin()`, `Overlaps()`, `Volume()`

### Fraction Class
- `int32 m_numerator, m_denominator`
- `Normalize()`, comparison operators

## Object System

### Object (Root Class)
Base class for ALL game objects:
- `int16 Type` - Object type (T_* constant)
- `hObj myHandle` - Registry handle
- Virtual methods: `Name()`, `Describe()`, `Dump()`, `Serialize()`
- Type checks: `isCreature()`, `isFeature()`, `isItem()`, `isPlayer()`, `isMonster()`, `isCharacter()`, `isContainer()`

### Thing (Physical Object Base)
Inherits Object. Base for all dungeon entities:
- `Map* m` - Containing map
- `hObj Next, hm` - Linked list and map handle
- `int16 x, y` - Position
- `Glyph Image` - Display glyph
- `int16 Timeout` - Action timer
- `uint32 Flags` - Behavior flags
- `String Named` - Custom name
- `StatiCollection __Stati` - Status effects
- `NArray<hObj,10,20> backRefs` - Back references

Key virtual methods:
- `SetImage()`, `Initialize()`, `Event()`, `DoTurn()`, `Move()`, `Remove()`
- `StatiOn()`, `StatiOff()` - Status effect callbacks
- `PlaceAt()`, `PlaceNear()`, `PlaceOpen()` - Placement
- `DirTo()`, `DistFrom()` - Spatial queries
- `ProjectTo()`, `ProjectDir()` - Line projection

## Registry System

### Handle-based Object Management
All game objects are referenced via `hObj` handles, not direct pointers:
```cpp
#define oThing(h)     ( theRegistry->GetThing(h) )
#define oCreature(h)  ( theRegistry->GetCreature(h) )
#define oItem(h)      ( theRegistry->GetItem(h) )
#define oMap(h)       ( theRegistry->GetMap(h) )
// etc.
```

### Serialization
All persistent objects use ARCHIVE_CLASS macro:
```cpp
#define ARCHIVE_CLASS(ClassName, Base, r) \
  friend class Registry; protected: \
  ClassName(Registry*r) : Base(r) {} \
  virtual size_t ObjectSize() { return sizeof(ClassName); } \
  virtual void Serialize(Registry &r, bool isSave) { \
    Base::Serialize(r,isSave);
#define END_ARCHIVE }
```

## Porting Considerations

### For Jai Port
1. **hObj handles** - Can use integer indices into a flat array, or tagged unions
2. **String** - Jai has built-in string type; need to handle color codes
3. **Array** - Jai has `[..]` dynamic arrays built in
4. **Dice** - Simple struct, already ported
5. **MVal** - Jai supports bitfield-like structs via bit operations
6. **Serialization** - Jai doesn't have virtual dispatch; need explicit type switches or procedure tables
7. **Virtual methods** - Core design challenge: Jai has no inheritance. Options:
   - Tagged union with procedure tables
   - Interface pattern with function pointers
   - Switch-based dispatch on type field
8. **Glyph encoding** - Already partially ported in `glyph_cp437.jai`
