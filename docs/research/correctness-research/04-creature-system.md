# Creature System

**Source**: `Creature.cpp`, `Character.cpp`, `Player.cpp`, `Monster.cpp`, `Create.cpp`, `Target.cpp`
**Headers**: `inc/Creature.h`, `inc/Target.h`
**Status**: Fully researched

## Class Hierarchy

```
Thing (physical dungeon object)
└── Creature (all living beings) [also inherits Magic mixin]
    ├── Character (class/race/skill system)
    │   └── Player (UI, input, journal)
    └── Monster (AI, behavior)
```

## Creature Class (Base)

### Core Fields
```cpp
rID mID, tmID;              // Monster and template resource IDs
int16 PartyID;              // Party affiliation
int16 cHP, mHP;             // Current/max hit points
int16 Subdual;              // Subdual (non-lethal) damage
int16 cFP;                  // Fatigue points
int32 uMana, mMana, hMana;  // Used/max/held mana
int32 ManaPulse;            // Mana regeneration counter
int16 Attr[ATTR_LAST];      // All attributes (41 indices)
Dir LastMoveDir;            // Last movement direction
int8 AoO;                   // Attacks of opportunity remaining
int8 FFCount;               // Flat-footed counter
int8 HideVal;               // Stealth value
int16 StateFlags;           // MS_* state flags
int8 AttrDeath;             // Attribute that caused death (drain)
TargetSystem ts;            // Embedded target/hostility system
```

### Perception Precalculations
Cached per-creature for performance:
```cpp
uint8 TremorRange;    // Tremorsense distance
uint8 SightRange;     // Normal sight distance
uint8 LightRange;     // Personal light radius
uint8 BlindRange;     // Blindsight distance
uint8 InfraRange;     // Infravision distance
uint8 PercepRange;    // General perception range
uint8 TelepRange;     // Telepathy range
uint8 ScentRange;     // Scent detection range
uint8 ShadowRange;    // Shadow perception
uint8 NatureSight;    // Nature sight (see through foliage)
```

### Key Method Categories

**Mana Management:**
- `cMana()` - Current available mana
- `tMana()` - Total including adjustments
- `LoseMana(amt, hold)` - Spend or hold mana
- `GainMana(amt)` - Regain mana

**Attribute System:**
- `GetAttr(at)` - Get calculated attribute value
- `IAttr(at)` - Innate (base) attribute
- `KnownAttr(at)` - What player knows about attribute
- `Mod(a)` - Attribute modifier ((attr - 10) / 2)
- `Exercise(at, amt, col, cap)` - Increase from use
- `Abuse(at, amt)` - Decrease from abuse
- `AddBonus(btype, attr, bonus)` - Add typed bonus
- `StackBonus(btype, attr, bonus)` - Stack bonus (respecting stacking rules)

**Combat (see 05-combat-system.md):**
- `NAttack()`, `WAttack()`, `RAttack()`, `SAttack()`, `OAttack()`
- `Strike()`, `Hit()`, `Miss()`, `Damage()`, `Death()`
- `GetBAB(mode)` - Base attack bonus
- `getDef()` - Defense/AC value
- `ResistLevel(DType)` - Damage resistance

**Spellcasting (see 07-magic-system.md):**
- `SpellRating(eID, mm)` - Rate spell effectiveness
- `CasterLev()` - Caster level
- `getSpellDC(spID)` - Spell save DC
- `getSpellMana(spID, MM)` - Mana cost
- `Cast(e)`, `Counterspell(e)` - Casting actions

**Perception:**
- `Perceives(target, assertLOS)` - Returns bitmask of perception types used
- `XPerceives(t)` - Extended (excludes shadow/scent/detect)
- `PerceivesField(x, y, f)` - Can perceive field effect

**Skills & Feats:**
- `HasFeat(n)`, `HasAbility(n)`, `HasSkill(sk)` - Check possession
- `SkillLevel(n)`, `AbilityLevel(n)` - Get levels
- `WepSkill(wep)` - Weapon proficiency level

**Inventory:** (Pure virtual, implemented in Character/Monster)
- `PickUp()`, `Drop()`, `Wield()`, `TakeOff()`, `DropAll()`
- `InSlot(slot)`, `GetInv(first)`, `GainItem(it)`

**Status Effects:**
- `GainStatiFromBody(mID)` - Apply template stati
- `GainStatiFromTemplate(tID)` - Apply modifier stati
- `StatiOn(s)`, `StatiOff(s)` - Callbacks on status change

**Core Loop:**
- `DoTurn()` - Execute turn
- `ChooseAction()` - Pure virtual: Player uses input, Monster uses AI

## Character Class

Adds class/race system, equipment slots, and progression.

### Key Fields
```cpp
hObj Inv[NUM_SLOTS];           // Equipment slots
int16 BAttr[7];               // Base attributes (before mods)
int16 KAttr[ATTR_LAST];       // Known attributes
int8 SkillRanks[SK_LASTSKILL]; // Skill ranks invested
uint16 Feats[(FT_LAST/8)+1];  // Feat bitfield
uint8 Abilities[CA_LAST];     // Class abilities
rID ClassID[6];               // Up to 6 multiclass slots
rID RaceID, GodID;            // Race and deity
int8 Level[3];                // Levels per class
uint32 XP, XP_Drained;        // Experience
int16 alignGE, alignLC;       // Alignment axes
int16 FavourLev[MAX_GODS];    // Deity favor per god
int32 SacVals[MAX_GODS][MAX_SAC_CATS+2]; // Sacrifice tracking
uint16 Spells[MAX_SPELLS+1];  // Known spell flags
```

### Progression Methods
- `AdvanceLevel()` - Level up (pure virtual)
- `GainFeat(list, param)` - Grant feat
- `GainAbility(ab, pa, sourceID)` - Grant class ability
- `GainXP(xp)`, `LoseXP(xp)`, `KillXP(kill)` - XP management
- `CalcValues(KnownOnly, thrown)` - Recalculate all derived values
- `CalcSP()` - Recalculate skill points

### Religion System
- `gainFavour(gID, amt)` - Increase deity favor
- `Transgress(gID, mag)` - Commit act against deity
- `calcFavour(gID)` - Calculate current favor level
- `PaladinFall()`, `PaladinAtone()` - Fall/redemption

## Player Class

Player-specific: UI, input, journal, options.

### Key Fields
```cpp
Term* MyTerm;                  // Display terminal
int8 Options[OPT_LAST];       // Game options (~100)
String Journal;                // Adventure journal
String MessageQueue[8];        // Message buffer
rID Macros[MAX_MACROS];        // F-key macros
QuickKey QuickKeys[MAX_QKEYS]; // Quick bindings
int16 AutoBuffs[64];           // Auto-buff list
int16 MaxDepths[MAX_DUNGEONS]; // Explored depth per dungeon
bool WizardMode, ExploreMode;  // Debug modes
```

### Key Methods
- `ChooseAction()` - Get player input
- `Create(reincarnate)` - Character creation
- `CalcVision()` - Player-specific FOV
- `IPrint(msg)` - Print message to player
- `IDPrint(you_msg, they_msg)` - Dual perspective message
- `yn(msg)` - Yes/no prompt
- `ShowStats()`, `ManageInv()` - UI screens

## Monster Class

AI-controlled creatures.

### Key Fields
```cpp
hObj Inv;                      // Inventory (linked list head)
int8 BuffCount, FoilCount;     // Buff tracking
uint8 Recent[6];               // Recent action history
static ActionInfo Acts[64];    // Action priority queue
static EffectInfo Effs[1024];  // Available spell effects
static Creature *mtarg, *rtarg; // Current targets
// 20+ static boolean condition flags (isAfraid, isBlind, etc.)
```

### AI Methods
- `ChooseAction()` - Main AI decision loop
- `AddAct(act, pri, tar)` - Queue action with priority
- `SmartDirTo(tx, ty)` - Pathfind toward target
- `Movement()` - Execute movement decision
- `PreBuff()` - Apply pre-combat buffs
- `MonsterGear()` - Equip from template

## Target System

**Source**: `inc/Target.h`, `src/Target.cpp` (1642 lines)

Every Creature has an embedded `TargetSystem ts` that tracks what it considers enemies, allies, and targets. The system maintains a "proof chain" explaining *why* each relationship exists.

### HostilityWhyType Enum (23 values)

Reason codes for hostility/friendliness:

| Value | Meaning |
|---|---|
| `HostilityDefault` | No particular reason |
| `HostilityFeud` | Racial feud (e.g., Elf vs Drow) |
| `HostilityMindless` | Mindless creature attacks everything |
| `HostilityPeaceful` | Peaceful creature |
| `HostilityGood` | Both good-aligned |
| `HostilityOutsider` | Outsider alignment conflict |
| `HostilityDragon` | Dragon alignment conflict |
| `HostilitySmite` | Good smites evil |
| `HostilityLeader` | Leader/follower relationship |
| `HostilityMount` | Mount obeys rider |
| `HostilityDefendLeader` | Defends its leader |
| `HostilityYourLeaderHatesMe` | Target's leader is hostile to me |
| `HostilityYourLeaderIsOK` | OK with target's leader |
| `HostilityParty` | Same party |
| `HostilityFlag` | Hostile by nature (M_HOSTILE) |
| `HostilitySolidarity` | Same race solidarity |
| `HostilityEID` | Effect-based (carries rID) |
| `HostilityTarget` | Personal memory/grudge |
| `HostilityFood` | Carnivore/herbivore wants food |
| `HostilityEvil` | Evil attacks the weak |
| `HostilityAlienation` | Creature out of element |
| `HostilityCharmed` | Charmed |
| `HostilityCommanded` | Commanded |

### Hostility Evaluation Structures

```cpp
// Why hostile/friendly
struct HostilityWhy {
    HostilityWhyType type;
    union {
        struct { uint8 ma; } solidarity;      // MA_* type
        struct { uint8 m1, m2; } feud;        // Racial feud pair
        struct { rID eid; } eid;              // Effect resource
    } data;
};

// Qualitative assessment
enum HostilityQual { Neutral, Enemy, Ally };

// Quantitative strength
enum HostilityQuant {
    Apathy=0, Minimal=1, Tiny=2, Weak=10, Medium=20, Strong=30
};

// Combined hostility result
struct Hostility {
    HostilityQual quality;
    HostilityQuant quantity;
    HostilityWhy why;
};
```

### Three-Tier Hostility Evaluation

Evaluation flows: **SpecificHostility** → **LowPriorityStatiHostility** → **RacialHostility**

#### Tier 1: SpecificHostility (highest priority)
Personal/relationship checks in order:
1. Player-vs-player: always Neutral
2. Self: Strong Ally
3. CHARMED (CH_DOMINATE/CH_COMMAND): Strong Ally
4. CHARMED (CH_CHARM): Strong Neutral
5. Illusion check: if not real, Neutral
6. Existing Target memory: use stored Enemy/Ally/Leader
7. Leader relationships: defend leader, follow leader's disposition
8. Target's leader: if hostile to me → Enemy
9. PartyID match: Strong Ally
10. Target's leader OK: check lower tiers
11. Fall through to Tier 2

#### Tier 2: LowPriorityStatiHostility (medium priority)
Status effect checks:
1. ENEMY_TO stati: Medium Enemy
2. ALLY_TO stati: Strong Neutral
3. NEUTRAL_TO stati: Medium Neutral
4. CHARMED(CH_CALMED): Strong Neutral
5. Fall through to Tier 3

#### Tier 3: RacialHostility (lowest priority)
Race/type-based defaults:
1. Mindless: solidarity check only, then Strong Enemy
2. Peaceful: Weak Neutral
3. Outsider alignment conflict: Strong Enemy
4. Dragon alignment conflict: Strong Enemy
5. Racial feuds (7 pairs at Medium, Elf/Dwarf at Weak):
   - Undead/Living, Elf/Orc, Gnome/Kobold, Elf/Drow, Halfling/Goblin, Dwarf/Orc, Cat/Dog
6. Solidarity (same-race friendship): Strong for Lizardfolk/Illithid, Medium for many others
7. M_HOSTILE flag: Strong Enemy
8. Evil creature: Tiny Enemy if CR >= target
9. Carnivore/Herbivore food: Tiny Enemy if CR >= target
10. Good mutual respect: Weak Neutral
11. Good smites evil: Weak Enemy
12. OrderAttackNeutrals: Tiny Enemy
13. Alienation: Tiny Enemy (animals, elementals out of element)

### TargetType Enum

**Creature relationships:** TargetInvalid, TargetEnemy, TargetAlly, TargetLeader, TargetSummoner, TargetMaster, TargetMount

**Spatial/item targets:** TargetArea, TargetWander, TargetItem

**Orders (15 types):** OrderStandStill, OrderDoNotAttack, OrderAttackNeutrals, OrderHide, OrderDoNotHide, OrderWalkInFront/InBack/NearMe/ToPoint, OrderBeFriendly, OrderAttackTarget, OrderTakeWatches, OrderGiveMeItem, OrderReturnHome, OrderNoPickup

**Memory flags (5):** MemoryCantHitPhased, MemoryCantHitWImmune, MemoryElemResistKnown, MemoryMeleeDCKnown, MemoryRangedDCKnown

### Target Struct
```cpp
struct Target {
    TargetType type;
    uint16 priority;            // Higher = more important
    uint16 vis;                 // Visible now? (perception flags)
    TargetWhy why;              // Reason + turn of birth
    union {
        struct { hObj c; uint32 damageDoneToMe; } Creature;
        struct { uint8 x, y; } Area;
        struct { hObj i; } Item;
    } data;
};
```

### TargetSystem (32-target fixed array)
```cpp
struct TargetSystem {
    Target t[32];               // NUM_TARGETS = 32
    uint8 tCount;
    bool shouldRetarget;

    // Three-tier evaluation
    Hostility RacialHostility(Creature *me, Creature *t);
    Hostility SpecificHostility(Creature *me, Creature *t);
    Hostility LowPriorityStatiHostility(Creature *me, Creature *t);

    // Target management
    void RateAsTarget(Creature *me, Thing *t, Target &newT);
    Target* GetTarget(Thing *thing);
    bool addCreatureTarget(Creature *targ, TargetType type);
    bool addTarget(Target &newT);
    void removeCreatureTarget(Creature *targ, TargetType type);
    bool giveOrder(Creature *me, Creature *master, TargetType order, ...);

    // Events/reactions
    void ItHitMe(Creature *me, Creature *t, int16 damage);
    void Liberate(Creature *me, Creature *lib);
    void Pacify(Creature *me, Creature *t);
    void Wanderlust(Creature *me, Thing *t=NULL);
    void HearNoise(Creature *me, uint8 x, uint8 y);
    void TurnHostileTo(Creature *me, Creature *hostile_to);
    void TurnNeutralTo(Creature *me, Creature *neutral_to);
    void Consider(Creature *me, Thing *t);

    // Full rebuild
    void Retarget(Creature *me, bool force=false);
    void ForgetOrders(Creature *me, int ofType=-1);
    void Clear();
};
```

### Retarget Algorithm
1. If not forced, sets `shouldRetarget = true` and returns (deferred)
2. Copies existing targets to temp buffer (1024 entries)
3. Checks engulfed creature
4. Scans all tiles within `MAX_TARG_DIST = 18` Chebyshev distance
5. For each creature/item: calls `RateAsTarget()`
6. Sorts by priority (leaders first, then descending priority, then type, then pointer tiebreak)
7. Deduplicates, copies top 32 back

### ItHitMe Damage Thresholds
When an ally/leader/mount hits the creature, tolerance before turning hostile:
- Ally: `damageDoneToMe > 5 + CHA_mod*2`
- Leader: `damageDoneToMe > 10 + CHA_mod*2`
- Mount/Summoner: `damageDoneToMe > 10 + CHA_mod*2` / `15 + CHA_mod*2`
- Same-party hit: Leader attempts SK_DIPLOMACY DC 15 to diffuse
- On turning hostile: all friendly creatures on map also turn hostile to attacker

## Player Memory Structures

Per-player knowledge tracking, accessed via `MONMEM/ITMMEM/EFFMEM/REGMEM(xID, player)`:

### MonMem
```cpp
struct MonMem {
    unsigned Battles:8, Deaths:8, Kills:8, pKills:8;
    unsigned Attacks:9, Resists:8, Immune:16;
    unsigned Seen:1, Fought:1, Feats:16, Flags:5;
};
```

### ItemMem
```cpp
struct ItemMem {
    unsigned Known:1, ProfLevel:3, Tried:1, Mastered:1, Unused:2;
};
```

### EffMem
```cpp
struct EffMem {
    unsigned FlavorID:32, PFlavorID:32;
    unsigned Known:1, Tried:1, PKnown:1, PTried:1;
};
```

### RegMem
```cpp
struct RegMem { unsigned int Seen; };  // 32-bit area bitmask
```

## Porting Considerations

1. **Inheritance hierarchy** - Jai has no classes. Options:
   - Single `Entity` struct with type tag and union of type-specific data
   - Composition with shared base fields
   - Virtual dispatch via procedure tables indexed by type
2. **Static Monster fields** - Acts[], Effs[] are shared across all monsters; in Jai, use module-level globals
3. **Perception precalcs** - Cache invalidation pattern needed
4. **CalcValues()** - Called frequently; optimize for Jai's strengths
5. **Equipment slots** - Fixed array for Character, linked list for Monster; unify in Jai
6. **The 41 attributes** - ATTR_LAST=41; use a fixed array
7. **Feat bitfield** - 200+ feats packed in uint16 array; use Jai bit operations
8. **TargetSystem** - 32-target fixed array is straightforward; the three-tier hostility evaluation requires careful porting of racial/alignment/status checks
9. **Memory structs** - Bitfield packing; use Jai bit operations or byte-level storage
