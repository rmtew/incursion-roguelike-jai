# Item System

**Source**: `Item.cpp`, `Inv.cpp`, `inc/Item.h`
**Status**: Architecture researched from headers

## Class Hierarchy

```
Thing
└── Item [also inherits Magic mixin]
    ├── QItem (items with magical qualities)
    │   ├── Food
    │   │   └── Corpse
    │   ├── Container
    │   ├── Weapon
    │   └── Armour
    └── Coin
```

## Item Base Class

### Fields
```cpp
uint16 Known;          // Knowledge flags (KN_MAGIC, KN_QUALITY, etc.)
int8 Plus;             // Enhancement bonus (+1, +2, etc.)
int8 Charges;          // Charges remaining (wands, staves)
int8 DmgType;          // Damage type
int16 GenNum;          // Generation number (for stacking)
hObj Parent;           // Owner/container handle
rID homeID;            // Home region
int16 Flavor;          // Flavor identifier (unidentified appearance)
int16 cHP;             // Current HP (durability)
uint32 Quantity;       // Stack quantity
String Inscrip;        // Player inscription
rID iID, eID;          // Item and effect resource IDs
uint16 IFlags;         // IF_BLESSED, IF_CURSED, IF_MASTERWORK, etc.
```

### Knowledge Flags (Known field)
- KN_MAGIC - Player knows item is magical
- KN_QUALITY - Player knows magical qualities
- KN_PLUS - Player knows enhancement bonus
- KN_CURSE - Player knows cursed status
- KN_NATURE - Full identification

### Key Methods
- `Name(Flags)` - Get item name (respects knowledge flags)
- `Describe(p)` - Full description
- `Initialize(in_play)` - Set up item
- `Weight(psych_might)` - Calculate weight
- `Hardness(DType)` - Material hardness vs damage type
- `MakeKnown(k)` - Reveal knowledge to player
- `ReApply()` - Reapply item effects

### Combat Properties
- `ArmVal(ty, knownOnly)` - Armor value
- `CovVal(c, knownOnly)` - Coverage value
- `DefVal(c, knownOnly)` - Defense bonus
- `ParryVal(c, knownOnly)` - Parry bonus
- `SDmg()` - Small creature damage dice
- `LDmg()` - Large creature damage dice
- `DamageType(target)` - Effective damage type
- `Threat(c)` - Threat range
- `CritMult(c)` - Critical multiplier
- `RangeInc(c)` - Range increment
- `Penalty(for_skill)` - Armor check penalty
- `Size(wield)` - Effective size for wielder

## QItem (Quality Items)

Adds magical quality system:
```cpp
int8 Qualities[8];        // Up to 8 quality IDs
uint8 KnownQualities;     // Bitfield of identified qualities
```

Methods:
- `HasQuality(q)` - Check for quality
- `KnownQuality(q)` - Player knows quality
- `AddQuality(q, param)` - Add magical quality
- `RemoveQuality(q)` - Remove quality
- `GetQuality(i)` - Get quality at index

### Weapon Qualities (WQ_*, 64 types)
Examples: WQ_HOLY, WQ_FLAMING, WQ_FROST, WQ_SHOCK, WQ_KEEN, WQ_VORPAL, WQ_SPEED, etc.

### Armor Qualities (AQ_*, 42 types)
Examples: AQ_LIGHT_FOR, AQ_SHADOW, AQ_SILENT, AQ_FORTIFICATION, AQ_GHOST_TOUCH, etc.

## Weapon Class

```cpp
int16 Bane;    // Bane creature type (extra damage vs type)
```

Key methods:
- `SDmg()`, `LDmg()` - Damage dice for small/large targets
- `DamageType(target)` - Effective damage type
- `Threat(c)`, `CritMult(c)` - Critical mechanics
- `RangeInc(c)` - Range for throwing/shooting
- `isBaneOf(MType)` - Check bane effectiveness
- `useStrength()` - Whether strength applies to damage
- `canFinesse()` - Whether weapon finesse works
- `thrownOnly()` - Thrown-only weapon
- `isGroup(gr)` - Weapon group membership
- `QualityDmg(e)` - Extra damage from qualities

## Armour Class

Key methods:
- `ArmVal(ty, knownOnly)` - Armor class bonus
- `CovVal(c, knownOnly)` - Coverage percentage
- `DefVal(c, knownOnly)` - Defense bonus
- `PenaltyVal(c, for_skill)` - Check penalty
- `MaxDexBonus(c)` - Maximum Dex bonus in armor
- `isGroup(gr)` - Armor group (light/medium/heavy/shield)

## Food & Corpse

```cpp
// Food
int16 Eaten;           // Consumption progress

// Corpse
rID mID;               // Monster type that was killed
uint32 TurnCreated;    // Freshness tracking
int16 LastDiseaseDCCheck;
```

Methods: `Eat(e)`, `isFresh()`, `fullyDecayed()`, `noDiseaseDC()`

## Container

```cpp
hObj Contents;         // First item in container (linked list)
```

Methods: `Insert(e)`, `TakeOut(e)`, `PickLock(e)`, `DumpOutContents(e)`, `Sort()`, `getItem(n)`

## Coin

Simple currency item with `Quantity` field and special event handling.

## Item Type Constants (IT_*, 49 flags)
Bit flags for item properties:
- IT_NOGEN - Not randomly generated
- IT_WEAPON, IT_ARMOUR, IT_SHIELD
- IT_MAGICAL, IT_CURSED
- IT_FOOD, IT_POTION, IT_SCROLL, IT_WAND, IT_STAFF
- etc.

## Acquisition Categories (AI_*, 60 types)
For loot generation: AI_POTION, AI_SCROLL, AI_WEAPON, AI_ARMOUR, AI_RING, AI_AMULET, etc.

## Equipment Slot System (SL_*, 24 slots)
```
SL_INAIR(0), SL_WEAPON(1), SL_READY(2), SL_OFFHAND(3),
SL_ARMOUR(4), SL_HELMET(5), SL_GAUNTLETS(6), SL_BOOTS(7),
SL_CLOAK(8), SL_RING1(9), SL_RING2(10), SL_AMULET(11),
SL_BELT(12), SL_EYES(13), SL_LSHOULDER(14), SL_RSHOULDER(15),
// ... up to SL_LAST(24)
```

## Inventory Management (Inv.cpp)

### Player Inventory
Fixed slots: `Inv[NUM_SLOTS]` array indexed by SL_* constants

### Monster Inventory
Linked list: single `hObj Inv` head, items linked via `Next` field

### Key Operations
- PickUp: Check weight, add to inventory
- Drop: Remove from inventory, place on map
- Wield: Move to weapon slot, apply effects
- TakeOff: Remove from slot, unapply effects
- Stacking: Items with same iID, Plus, and no special properties can stack

## Porting Considerations

1. **Item hierarchy** - Jai has no inheritance. Use tagged union or composition:
   ```jai
   Item :: struct {
       base: ItemBase;
       using type_data: union {
           weapon: WeaponData;
           armour: ArmourData;
           food: FoodData;
           container: ContainerData;
       };
   }
   ```
2. **Quality system** - Array of 8 quality IDs is straightforward
3. **Knowledge flags** - Bitfield, maps directly
4. **Inventory** - Unify player slots and monster linked list into a single system
5. **Stacking** - Need clear rules for what can stack
6. **Item identification** - Flavor system maps unidentified appearance to actual item
