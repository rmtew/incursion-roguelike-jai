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

### IFlags Constants (uint16 bitmask)
```cpp
IF_BLESSED     0x0001   // Item is blessed
IF_CURSED      0x0002   // Item is cursed
IF_WORN        0x0004   // Item is equipped (alias: IF_WIELDED, IF_HELD)
IF_MASTERWORK  0x0008   // Masterwork quality
IF_BROKEN      0x0010   // Item is broken
IF_INTUITED    0x0020   // Intuitively identified
IF_PROPERTY    0x0040   // Shop property
IF_RUNIC       0x0080   // Has runic inscription
IF_DECIPHERED  0x0100   // Inscription read
IF_GHOST_TOUCH 0x0200   // Affects incorporeal
IF_REAPPLYING  0x0400   // Currently reapplying effects
```

### Knowledge Flags (KN_*, uint16 bitmask)
```cpp
KN_NATURE     0x01   // Base nature known
KN_CURSE      0x02   // Cursed/blessed status known (alias: KN_BLESS)
KN_MAGIC      0x04   // Magical properties known
KN_PLUS       0x08   // Enhancement bonus known
KN_PLUS2      0x10   // Secondary bonus known
KN_ARTI       0x20   // Artifact nature known
KN_RUSTPROOF  0x40   // Rustproof status known
KN_IDENTIFIED 0x60   // Combination: KN_ARTI | KN_RUSTPROOF
KN_HANDLED    0x80   // Has been handled/touched
```

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

### Weapon Qualities (WQ_*, 63+ types)
By category:
- **Alignment**: WQ_HOLY(1), WQ_UNHOLY(2), WQ_CHAOTIC(3), WQ_LAWFUL(4), WQ_BALANCE(5)
- **Elemental**: WQ_CORROSIVE(6), WQ_FLAMING(7), WQ_SHOCKING(8), WQ_FROST(9)
- **Critical**: WQ_KEEN(13), WQ_VORPAL(14), WQ_IMPACT(46)
- **Combat**: WQ_DEFENDING(16), WQ_SPEED(22), WQ_ACCURACY(23), WQ_PARRYING(33)
- **Special**: WQ_SLAYING(24), WQ_BANE(35), WQ_VAMPIRIC(32), WQ_DANCING(25), WQ_DISRUPTION(26)
- **Debuff**: WQ_WEAKENING(37), WQ_NUMBING(38), WQ_WITHERING(39) (drain STR/DEX/CON)
- **Other**: WQ_RETURNING(27), WQ_DISTANCE(21), WQ_VENOM(47), WQ_FORKING(50)

### Armor Qualities (AQ_*, 42+ types)
By category:
- **Classification**: AQ_LIGHT_FOR(1), AQ_MEDIUM_FOR(2), AQ_HEAVY_FOR(3)
- **Resistance**: AQ_FIRE_RES(4), AQ_COLD_RES(5), AQ_ACID_RES(6), AQ_LIGHT_RES(7), AQ_SONIC_RES(8), AQ_POISON_RES(9)
- **Defense**: AQ_ARROW_DEF(11), AQ_INVULN(19), AQ_GREAT_INV(18), AQ_REFLECTION(21)
- **Special**: AQ_GHOST_TOUCH(16), AQ_ETHEREALNESS(14), AQ_SHADOW(22), AQ_SILENT(23)
- **Stat Boost**: AQ_MIGHT(25), AQ_AGILITY(26), AQ_ENDURANCE(27)
- **Other**: AQ_ANIMATED(10), AQ_BASHING(12), AQ_HEALING(28), AQ_COMMAND(30), AQ_SACRED(33)

## Weapon Class

```cpp
int16 Bane;    // Bane creature type (extra damage vs type)
```

### Weapon Group Constants (WG_*, uint32 bitmask)
```cpp
WG_SIMPLE     0x00000001   // Simple weapons
WG_EXOTIC     0x00000002   // Exotic weapons
WG_SBLADES    0x00000004   // Short blades
WG_LBLADES    0x00000008   // Long blades
WG_AXES       0x00000010   // Axes
WG_ARCHERY    0x00000020   // Bows/crossbows
WG_STAVES     0x00000040   // Staves
WG_IMPACT     0x00000080   // Impact weapons
WG_THROWN     0x00000100   // Thrown weapons
WG_POLEARMS   0x00000200   // Polearms
WG_SPEARS     0x00000400   // Spears
WG_LANCES     0x00000800   // Lances
WG_DAGGERS    0x00001000   // Daggers
WG_MARTIAL    0x00002000   // Martial arts weapons
WG_FLEXIBLE   0x00004000   // Chains, nunchaku
WG_FIREARMS   0x00008000   // Firearms
WG_LIGHT      0x00010000   // Light-weight weapons
WG_FLAILS     0x00020000   // Flails
WG_SHIELDS    0x10000000   // Shields (shared with armor)
WG_LARMOUR    0x20000000   // Light armor
WG_MARMOUR    0x40000000   // Medium armor
WG_HARMOUR    0x80000000   // Heavy armor
```

Key methods:
- `SDmg()`, `LDmg()` - Damage dice for small/large targets
- `DamageType(target)` - Effective damage type
- `Threat(c)`, `CritMult(c)` - Critical mechanics
- `RangeInc(c)` - Range for throwing/shooting
- `isBaneOf(MType)` / `isBaneOf(Creature*)` - Check bane effectiveness
- `SetBane(MType)`, `GetBane()`, `RandomBane()` - Bane management
- `useStrength()` - Whether strength applies to damage
- `useInGrapple(c)` - Usable in grapple
- `canFinesse()` - Whether weapon finesse works
- `thrownOnly()` - Only in WG_THROWN/WG_EXOTIC/WG_ARCHERY groups
- `isGroup(gr)` - Weapon group membership via TItem->Group
- `QualityDmg(e)` - Extra damage from qualities
- `Wield(c)`, `Unwield(c)` - Equip/unequip handling

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

## TItem Resource Template

```cpp
class TItem : public Resource {
    Glyph   Image;       // Visual display glyph
    int16   IType;       // Item type code
    int8    Level, Depth;// Generation level/depth
    int8    Material;    // MAT_* constant
    int8    Nutrition;   // Food value
    int16   Weight;      // Base weight
    uint16  hp;          // Max hit points
    int8    Size;        // SZ_* constant
    uint32  Cost;        // Base cost
    uint32  Group;       // WG_* group bitmask
    uint8   Flags[];     // Bit-packed IT_* flags
    union {
        struct { Dice SDmg, LDmg; int8 Crit, Threat, RangeInc, Acc, Spd, ParryMod; } w;  // Weapon
        struct { int16 Arm[3], Cov, Def, Penalty; } a;                                     // Armor
        struct { int16 Capacity, MaxSize, WeightMod, CType, Timeout, WeightLim; } c;       // Container
        struct { int16 LightRange, Lifespan; rID Fuel; } l;                                // Light
    } u;
};
```

## Item Generation

### ItemGen Table Entry
```cpp
struct ItemGen {
    uint8       Prob;       // Probability weight
    uint8       Type;       // Item type constant
    uint8       Source;     // Generation source
    bool        NeverGood;  // Never generate as "good" quality
    uint8       MinLevel;   // Minimum dungeon level
    uint16      CostMult;   // Cost multiplier
    const char* Prototype;  // Template string
    bool        Flavored;   // Uses unidentified appearance
};
```

Generation tables: `DungeonItems[]`, `MonsterItems[]`, `IllusionItems[]`, `ChestItems[]`, `MageItems[]`, `StapleItems[]`

Static factory: `Item::GenItem(Flags, rID, Depth, Luck, ItemGen*)` - probabilistic item generation
Static factory: `Item::Create(rID)` - create specific item by resource ID

## Material Utilities

```cpp
int16 MaterialHardness(int8 Mat, int8 DType);
bool MaterialIsMetallic(int8 mat);
bool MaterialIsWooden(int8 mat);
bool MaterialIsOrganic(int8 mat);
bool MaterialIsCorporeal(int8 mat);
```

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
