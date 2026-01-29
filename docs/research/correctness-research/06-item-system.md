# Item System

**Source**: `Item.cpp`, `Inv.cpp`, `inc/Item.h`
**Status**: Fully researched

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

### Armor Value Formulas

**ArmVal(typ)**: base from template `ti->u.a.Arm[typ]` + Plus (if known) + material bonuses (Adamant: +1/+2/+3 by weight; Orcish/Dwarven: +1)

**CovVal**: for shields, depends on FT_SHIELD_EXPERT + size comparison (larger=10, same=8, +1=4, +2=2, much larger=1); for armor, base from template + Plus

**DefVal**: for shields, same as CovVal base + FT_SHIELD_FOCUS (+2); for armor, base from template + Plus

**PenaltyVal**: base from template (negative) + quality modifiers:
- Graceful: halves penalty; Elven: +2; Orcish: -1; Darkwood: +2; Mithril: +3; Agility: penalty = 0
- For skills: adds 2; Armor Optimization feat: further reduces by (val-2)/3; minimum 0

**GetGroup()**: Mithril shifts Heavy→Medium, Medium→Light (affects quality eligibility)

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

### Corpse System
- Fresh: less than 12 hours old; fully decayed: more than 14 days
- Disease DC: base 8-25 by creature type, +1 per 2 hours after 6 hours, higher for undead
- Weight by size: Tiny=50, Small=500, Medium=1500, Large=4000, Huge=10000, Gargantuan=250000, Colossal=1000000; statues ×5
- Eating: incremental (5 units per action); nutrition by size (Tiny=1, Small=10, Medium=25, Large=50, Huge=100); cannibalism alignment penalty; disease risk via Wild Lore check

### Food Mechanics
- Nutrition from `TITEM(iID)->Nutrition`
- Satiation tracking: full at CONTENT level; bloated limit: BLOATED + 500
- Slow Metabolism: 1/3 nutrition need; large creatures: hold 2× more

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

### Player/Character Inventory
Fixed slot array: `Inv[SL_LAST]` indexed by SL_* constants.
Form-based restrictions: `TMON(mID)->HasSlot(sl)` validates slot accessibility for polymorphed characters.
SL_ARCHERY is a "fake slot" — characters cannot use it directly.

### Monster Inventory
Linked list: single `hObj Inv` head, items linked via `Next` field.
```
Monster::Inv -> Item1 (Next) -> Item2 (Next) -> Item3 (Next) -> NULL
```
`InSlot(slot, eff)` searches linked list for equipped item with `IF_WORN` flag.
`PickUp()` adds to head of list: `e.EItem->Next = Inv; Inv = e.EItem->myHandle;`

### Equipment Slots (SL_*)
| Slot | Purpose | Notes |
|------|---------|-------|
| SL_WEAPON | Primary melee weapon | Two-handed fills both WEAPON+READY |
| SL_READY | Off-hand/ready weapon | Same handle as WEAPON when two-handed |
| SL_ARCHERY | Ranged weapon | Fake slot, not used by characters |
| SL_LIGHT | Light source | |
| SL_INAIR | Currently held item | Default pickup destination |
| SL_LSHOULDER, SL_RSHOULDER | Shoulder slots | Exchange weapon storage |
| SL_BELT, SL_BELT1-5 | Belt slots | Exchange weapon storage |
| SL_EYES | Eye slot | Monocles, masks |
| SL_CLOTHES | Clothing | Mutually exclusive with magical cloak |
| SL_ARMOUR | Body armor | Cannot equip while threatened/stuck/prone |
| SL_BOOTS | Footwear | |
| SL_CLOAK | Cloaks | Mutually exclusive with magical clothing |
| SL_LRING, SL_RRING | Ring slots | |
| SL_AMULET | Amulets | |
| SL_GAUNTLETS | Gloves | |
| SL_HELM | Headgear | |
| SL_BRACERS | Bracers | |
| SL_PACK | Backpack | |

### Wielding Constraints (Character)
1. **Form restrictions**: `TMON(mID)->HasSlot(sl)` — polymorphed forms lose slots
2. **Reach weapon conflicts**: Cannot mix reach and non-reach weapons in WEAPON+READY
3. **Magical clothing conflicts**: Cannot wear both magical cloak AND magical clothing
4. **Armor while threatened**: Cannot equip armor while threatened by hostiles
5. **Armor while stuck/prone**: Cannot equip armor while stuck or prone
6. **Fiendish restrictions**: Demons/devils/undead cannot use silver items; fiends cannot use blessed items
7. **Planar restrictions**: Incorporeal characters cannot use material items unless ghost-touch
8. **Weapon size restrictions**: Item must fit character's size
9. **Exotic weapons**: Some require specific feat (`WEP_SKILL` effect)
10. **Two-handed weapons**: Auto-fills both WEAPON+READY if both empty and player confirms
11. **Alignment warnings**: Holy vs evil, unholy vs good, lawful vs chaotic, balance vs non-neutral

### Weapon Exchange System (Character::Exchange)
Switches between melee and ranged weapon sets:
- Stores `defMelee`, `defOffhand`, `defRanged`, `defAmmo` defaults
- If currently wielding melee → switch to ranged + ammo
- Otherwise → switch to melee + offhand
- Old weapons stored in shoulder/belt slots
- Handles two-handed conflicts automatically

### PickUp Flow (Character)
1. Weight check: `e.EItem->Weight() > MaxPress()` → ABORT
2. Silver/blessed item check for fiends
3. Stacking: first try equipped slots, then auto-stow to pack
4. Default: place in SL_INAIR (hand)

### Stacking Rules
- `TryStack()` merges items with matching properties
- Active slots prevent stacking (except WG_THROWN weapons)
- Multi-item stacks split via `TakeOne()` when wielding
- Swap() can split stacks when Alt-held, prompts via `OneSomeAll()`

### Inventory Operation Timeouts
```
Wield:  QD(2000) / (100 + 10 * Mod(A_DEX))
PickUp: FE(1500) / (100 + 10 * Mod(A_DEX))
Drop:   FE(1000) / (100 + 10 * Mod(A_DEX))
```
Quick Draw / Faster Than Eye feats reduce by 4×.

## Container System (Inv.cpp)

### Container Structure
`Contents` — hObj pointer to first item (linked list). Items inside have `Parent` pointer back to container.

### Insert(EventInfo &e, bool force)
**Validation:**
- No hands check, raging check
- Container can't contain itself
- Silver/blessed item handling for fiends
- Incorporeal/planar restrictions
- Locked container → auto pick lock attempt

**Capacity checks:**
- `u.c.WeightLim` — maximum weight
- `u.c.Capacity` — maximum item count
- `u.c.MaxSize` — maximum individual item size
- `u.c.CType` — restricted item type
- FT_FASTER_THAN_THE_EYE (Packrat): doubles weight limit and capacity, increases max size by 1

**Logic:** Attempts stacking with existing items first, then links to end of list.

### XInsert(Item *it)
Force insert without event handling. Returns bool. Checks weight/capacity silently, auto-stacks if possible.

### Container Weight Calculation
```cpp
int32 Container::Weight(bool psych_might) {
    j = sum of all contained item weights;
    j -= ((TITEM(iID)->u.c.WeightMod * j) / 100);  // Weight reduction modifier
    j += TITEM(iID)->Weight;                         // Add container's own weight
    return j;
}
```

### Container Access Time
`AccessTime()` adds time cost for deeply nested containers. Each nesting level adds its individual timeout cost. Packrat feat halves the time.

### PickLock (Container)
DC = 19 + dungeon depth. Success removes LOCKED status. Failure applies DO_NOT_PICKUP status until rest.

### Dump/Pour Operations
- `DumpOutContents()` — empties container to ground
- `PourInContents()` — transfers contents to another container
- Both validate silver/blessed/planar restrictions per item

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

## Item Creation and Initialization

### Constructor
Sets `iID`, `Timeout = -1`, `cHP = MaxHP()`, `Image` from template, `eID = 0`, `Quantity = 1`, `Known = IFlags = 0`, `Plus = 0`, `GenNum = theGame->ItemGenNum++`. Wands get 30-50 charges; staffs get 20-29 charges; lights set Age from template lifespan.

### Factory — Item::Create(rID)
Routes to subclass: T_CORPSE/FIGURE/STATUE → Corpse; T_FOOD → Food; T_WEAPON/BOW/MISSILE/STAFF → Weapon; T_CONTAIN/CHEST → Container; T_ARMOUR/BOOTS/GAUNTLETS/SHIELD → Armour; all others → base Item.

### Initialize(in_play)
- Rope: quantity 6 or 20 randomly
- Effect application (if eID): changes base item (BASE_ITEM), applies initial plus (INITIAL_PLUS), adds qualities from ITEM_QUALITIES list, sets bane from BANE_LIST
- Fires EV_BIRTH event

### Flavor Assignment — Game::SetFlavors()
Assigns random visual/textual flavors to unidentified potions and scrolls; stores in player-specific effect memory.

## Item Stacking Rules

### operator==() — Equality for Stacking
Items can stack when ALL match:
1. Same type (T_COIN always stackable; T_CONTAIN/T_WAND never stack)
2. T_WEAPON/BOW/ARMOUR: all 8 quality slots must match
3. Different GenNum: both must be fully identified (KN_MAGIC, KN_PLUS, KN_BLESS)
4. Non-easy-stack: names must match exactly
5. Identical status effects (except POISONED, SUMMONED, BOOST_PLUS, EXTRA_QUALITY, HOME_REGION)
6. Both must have identical poison types/magnitudes (OPT_POISON_MERGE: slightly more lenient)
7. Light items: same Age (remaining fuel)
8. Same Plus, cHP, Flavor, iID, eID; inscriptions merged intelligently

### TryStack()
Merges: `Quantity += other.Quantity`, `Known |= other.Known`. Poison merging: random chance based on relative quantities. Removes source item.

## Item Identification

### MakeKnown(k)
Sets Known flags. When fully identified (KN_MAGIC + KN_PLUS): clears inscriptions. For scrolls/wands/rings/etc with eID: marks effect as known in player memory. Potions: marks PKnown. Notifies player via journal.

### IdentByTrial(Item, Quality)
Auto-identifies on use. Grants INT exercise (random(6) + max(1, level/2), cap 60).

### VisibleID()
Auto-identifies when wielder is detected via PER_DETECT or PER_SHADOW. Handles EF_USERID and EF_AUTOID flags.

## Item Damage System (Item::Damage)

### Processing Order
1. Corporeal check: force/emptyness items immune
2. Owner resistance: apply creature's resistance to damage type
3. Hardness calculation: from material + owner bonus; halved if halfHardness flag
4. Special: attacking own items ignores hardness; Sunder feat = 2× damage
5. Damage distribution: spreads across quantity for stacked items
6. Destruction: container contents spill out with 1.5× hardness damage to contents
7. Spellbreaker ability: XP for destroying magical items (scaled by item vs player level)

### Destruction Messages (by damage type)
| Damage | Partial | Full |
|--------|---------|------|
| Sonic/Potion | "crack" | "shatter" |
| Fire + Potion | "boil" | "boil and explode" |
| Fire + Metal | "melt" | "melt into slag" |
| Fire + Other | "burn" | "burn up" |
| Acid | "melt" | "melt away" |
| Disintegration | — | "disintegrate" |
| Necrotic | "wither" | "wither away" |
| Rust | "rust" | "rust away completely" |
| Default | "is damaged" | "is destroyed" |

## Weight System

### Base Weight
`TITEM(iID)->Weight × Quantity`. Zero-weight fallback: coins = Quantity/500, missiles = Quantity/5, default = Quantity/2.

### Quality Weight Modifiers (QItem::Weight)
- Elven: 75%; Dwarven: 125%; Darkwood/Mithril: 50%; Featherlight: 25%
- Food with Psychometric Might: 1/3 weight

## Material Utilities

### MaterialHardness(mat, DType)
40+ materials × damage types. Key values:
- Paper: -1 to 5; Cloth: 3-5; Leather: 10; Dragon hide: 15; Wood: 5
- Copper/Silver/Gold: 5; Iron: 10; Mithril: 15; Adamant: 20
- Indestructible: -1 (immune) vs all
- Rust (AD_RUST): 0 for iron/copper, -1 for others
- Acid: -1 for glass/gemstone

### QItem::Hardness Modifiers
Dwarven: +10; Orcish/Silver: ÷2; Adamant/Darkwood: ×2; Mithril: ×1.5; Plus ≥ 0: +Plus×5; Cursed: +50

### Material Query Functions
```cpp
MaterialIsMetallic(mat);   // Iron, copper, gold, silver, metal, mithril, adamant, platinum
MaterialIsWooden(mat);     // Wood, ironwood, darkwood
MaterialIsOrganic(mat);    // Veggy, wax, flesh, cloth, leather, paper, bone, dragon hide, webbing, wooden
MaterialIsCorporeal(mat);  // Everything except force and emptyness
```

## Item Level Calculations

### Weapon::ItemLevel()
Base from Item::ItemLevel (cost level or LevelAdjust). Random weapons: QPlus from Plus + quality modifier table. Bounded: max(base, Plus×2).

### Armour::ItemLevel()
Similar: QPlus + (QPlus × 150) / 100. Bounded: max(base, Plus×2).

## Weapon-Specific

### DamageType(target)
Selects optimal from slashing/piercing/blunt based on weapon flags. Against creatures: analyzes target resistance, picks type with lowest defense. Immune types (resistance = -1) treated as 999999.

### Bane System
- Bane = 0: none; Bane = monster type ID: direct; Bane = -2: lookup BANE_LIST from effect
- RandomBane(): assigns from 30+ monster types

### ParryVal
Base from template + Elven(+1)/Orcish(-1) + skill modifier (WS_NOT_PROF: -4, else +2 per level above proficient). Cap: 2× template value. Minimum 0.

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
