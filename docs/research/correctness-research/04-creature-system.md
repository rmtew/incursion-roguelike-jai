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
int8 concentUsed;           // Concentration slots used
int16 StateFlags;           // MS_* state flags
int8 AttrDeath;             // Attribute that caused death (drain)
TargetSystem ts;            // Embedded target/hostility system
```

### Static Members
```cpp
static int8 AttrAdj[ATTR_LAST][BONUS_LAST];  // [41][39] bonus matrix
static Item *meleeWep, *offhandWep, *missileWep, *thrownWep, *myShield;  // Weapon cache
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

### Core Fields
```cpp
hObj Inv[NUM_SLOTS];           // Equipment slots (24 slots)
hObj defMelee, defRanged, defAmmo, defOffhand; // Default weapon handles
int16 BAttr[7];               // Base attributes (STR-LUC)
int16 KAttr[ATTR_LAST];       // Known attributes (41 indices)
int8 SkillRanks[SK_LASTSKILL]; // Skill ranks invested (49 skills)
uint16 Feats[(FT_LAST/8)+1];  // Feat bitfield
uint8 Abilities[CA_LAST];     // Class abilities (143 abilities)
rID ClassID[6];               // Up to 6 multiclass slots
rID RaceID, GodID;            // Race and deity
int8 Level[3];                // Levels per class (max 3 classes)
uint32 XP, XP_Drained;        // Experience
```

### Skill Points
```cpp
uint16 SpentSP[6], BonusSP[6], TotalSP[6]; // Per-class skill points
```

### Turning & Favored Enemies
```cpp
uint8 TurnTypes[4], TurnLevels[4];   // Creature types that can be turned
uint8 FavTypes[12], FavLevels[12];   // Favored enemy types and bonuses
```

### Study & Focus
```cpp
uint8 IntStudy[STUDY_LAST];          // Intensive study progression (10)
int16 FocusWCount, FocusSCount;      // Weapon/school focus counts
int16 ExoticCount;                   // Exotic weapon count
int16 aStoryPluses, tStoryPluses;    // Story bonus tracking
```

### Leveling Detail
```cpp
int8 hpRolls[3][MAX_CHAR_LEVEL];     // HP rolls per class per level [3][11]
int8 manaRolls[3][MAX_CHAR_LEVEL];   // Mana rolls [3][11]
int8 SaveBonus[16];                  // Save bonus array
int16 GainAttr[7][15];              // Attribute gain tracking
int8 NotifiedLevel;                  // Last notified level
```

### Alignment & Misc
```cpp
int16 alignGE, alignLC;             // Alignment axes (Good/Evil, Law/Chaos)
uint32 Proficiencies;               // Weapon proficiency bitfield
uint16 desiredAlign;                // Desired alignment
hObj Mount;                         // Handle to mount creature
int16 resChance;                    // Resurrection chance
uint8 RageCount;                    // Number of rages used
int32 xpTicks;                      // XP tick counter
uint32 Personality;                 // Personality type flags
int16 polyTicks;                    // Polymorph duration counter
int32 LastRest;                     // Turn count of last rest
int16 fracFatigue;                  // Fractional fatigue accumulator
bool isFallenPaladin;               // Has paladin fallen?
```

### Religion
```cpp
int16 FavourLev[MAX_GODS];          // Deity favor per god (25 gods)
int32 TempFavour[MAX_GODS];         // Temporary favour accumulator
int16 Anger[MAX_GODS];              // Anger level per god
int32 SacVals[MAX_GODS][MAX_SAC_CATS+2]; // Sacrifice values [25][12]
int16 FavPenalty[MAX_GODS];         // Favour penalties
int16 PrayerTimeout[MAX_GODS];      // Prayer cooldown timers
int16 AngerThisTurn[MAX_GODS];      // Anger accumulated this turn
int32 lastPulse[MAX_GODS];          // Last pulse counter per god
uint16 godFlags[MAX_GODS];          // Per-god flags
```

### Spells
```cpp
uint16 Spells[MAX_SPELLS+1];        // Known spell flags (2049 entries)
uint8 SpellsLearned[10];            // Spells learned per level
uint8 SpellSlots[10];               // Spell slots per level
uint8 BonusSlots[10];               // Bonus spell slots per level
uint16 RecentSpells[10];            // Recently cast spells
uint16 RecentSkills[5];             // Recently used skills
uint16 RecentItems[5];              // Recently used items
rID Tattoos[10];                    // Magical tattoo resource IDs
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
int8 Options[OPT_LAST];       // Game options (900 entries)
String Journal;                // Adventure journal
String MessageQueue[8];        // Message buffer
rID Macros[MAX_MACROS];        // F-key macros (12)
QuickKey QuickKeys[MAX_QKEYS]; // Quick bindings (40)
int16 AutoBuffs[64];           // Auto-buff list
int16 cAutoBuff;               // Current auto-buff iterator
int16 MaxDepths[MAX_DUNGEONS]; // Explored depth per dungeon (32)
uint32 MMArray[MAX_SPELLS];    // Metamagic flags per spell (2048)
int16 SpellKeys[12];           // Spell quick-key bindings
int16 MapMemoryMask;           // Explored map memory bitmask
int16 GallerySlot;             // Character gallery slot
int8 MapSP;                    // Map stack pointer
String GraveText;              // Gravestone text
int16 HungerShown;             // Last hunger state shown
int16 RecentVerbs[5];          // Recently used verbs
int32 formulaSeed, storeSeed;  // RNG seeds for crafting/stores
int32 deathCount, rerollCount; // Death and reroll counters
int16 statMethod;              // Attribute rolling method
bool WizardMode, ExploreMode;  // Debug modes
bool VictoryFlag, QuitFlag;    // Game end flags
bool UpdateMap, DigMode;       // Map/dig state
bool statiChanged;             // Stati changed since display
bool shownFF, rerolledPerks;   // UI state flags
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

## State Flags (MS_*, Creature.StateFlags)

```cpp
MS_PEACEFUL    0x0001   // Non-hostile by default
MS_GUARDING    0x0002   // Guarding a location
MS_FEMALE      0x0004   // Female gender
MS_KNOWN       0x0008   // Already identified
MS_INVEN_GOOD  0x0010   // Inventory generated
MS_CURSED      0x0020   // Under a curse
MS_BOW_ACTIVE  0x0040   // Bow is readied
MS_SCRUTINIZED 0x0100   // Player examined closely
MS_POLY_KNOWN  0x0200   // Polymorph form known
MS_SEEN_CLOSE  0x0400   // Seen at close range
MS_CASTING     0x0800   // Currently casting a spell
MS_HAS_REACH   0x1000   // Has extended reach
MS_REACH_ONLY  0x2000   // Only reach attacks
MS_THREAT2     0x4000   // Threatens 2 squares
MS_STILL_CAST  0x8000   // Still Spell casting
```

## Perception Flags (PER_*, returned by Perceives())

```cpp
PER_VISUAL     0x0001   // Normal sight
PER_INFRA      0x0002   // Infravision
PER_SCENT      0x0004   // Scent
PER_BLIND      0x0008   // Blindsight
PER_PERCEPT    0x0010   // Perception
PER_TREMOR     0x0020   // Tremorsense
PER_SHADOW     0x0040   // Shadow perception
PER_TELE       0x0080   // Telepathy
PER_DETECT     0x0100   // Detect spell
PER_TRACK      0x0200   // Tracking
PER_SHARED     0x0400   // Shared senses
```

## Supporting Data Structures

### ActionInfo (Monster AI action candidate)
```cpp
struct ActionInfo {
    int8  Act;     // Action type (ACT_SATTACK, etc.)
    int32 Val;     // Sub-value
    Thing *Tar;    // Target
    int8  Pri;     // Priority
};
```

### EffectInfo (Monster AI spell/effect candidate)
```cpp
struct EffectInfo {
    rID    eID;      // Effect resource ID
    Item*  Source;   // Source item or CA_XXX constant
    uint16 Rating;   // Utility rating
    uint32 Purpose;  // What this effect is for
};
```

### FeatInfoStruct and Prerequisites
```cpp
struct FeatConjunct { int32 elt, arg, val; };      // Single prerequisite
struct FeatDisjunct { FeatConjunct And[5]; };       // Up to 5 AND conditions
struct FeatPrereq   { FeatDisjunct Or[3]; };        // Up to 3 OR branches

struct FeatInfoStruct {
    int16      feat;
    int32      flags;        // FF_* flags
    const char *name, *desc;
    FeatPrereq pre;
};
```

Prerequisite types (FP_*): `FP_ALWAYS(0)`, `FP_FEAT(1)`, `FP_ABILITY(2)`, `FP_BAB(3)`, `FP_SKILL(4)`, `FP_CR(5)`, `FP_ATTR(6)`, `FP_CASTER_LEVEL(7)`, `FP_WEP_SKILL(8)`, `FP_NOT_PROF(9)`, `FP_PROF(10)`, `FP_ATTACK(11)`, `FP_MTYPE(12)`

### SkillInfoStruct
```cpp
struct SkillInfoStruct {
    uint8 sk;              // Skill enum
    const char *name;
    bool imp;              // Implemented?
    bool active;           // Active use skill?
    const char *desc;
    int8 attr1, attr2;     // Governing attributes
    bool take_min;         // Use min instead of max of attrs
    int8 armour_penalty;   // Armor check penalty applies?
};
```

### Key Size Constants

| Constant | Value | Purpose |
|---|---|---|
| ATTR_LAST | 41 | Attribute array size |
| BONUS_LAST | 39 | Bonus type count |
| NUM_SLOTS | 24 | Equipment/inventory slots |
| SK_LASTSKILL | 49 | Number of skills |
| CA_LAST | 143 | Number of class abilities |
| STUDY_LAST | 10 | Study types |
| MAX_SPELLS | 2048 | Maximum spell count |
| MAX_CHAR_LEVEL | 11 | Maximum character level |
| MAX_GODS | 25 | Maximum deity count |
| MAX_SAC_CATS | 10 | Sacrifice categories |
| MAX_DUNGEONS | 32 | Maximum dungeon count |
| MAX_MACROS | 12 | Keyboard macro slots |
| MAX_QKEYS | 40 | Quick-key slots |
| OPT_LAST | 900 | Option slots |

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

## DoTurn() — Per-Turn Processing (Creature.cpp, lines 1246-1722)

### Processing Order
1. **Paralysis escape**: with 15+ ranks in Concentration or Escape Artist, can break paralysis on DC 18 Fort save
2. **Terrain damage**: crushed if in solid terrain on material plane (unless earthmeld/ghostwalk); suffocation if aquatic in non-water
3. **Resilience**: FT_RESILIENT passively regenerates 1 HP every 3 turns if not at full
4. **Ripple check**: detects invisible/phased creatures within 3 squares
5. **Engulfment processing**: phase escape checks, Escape Artist DC to break free, digestion attacks from engulfer
6. **Grappling**: FT_CHOKE_HOLD attempt to knock out; FT_EARTHS_EMBRACE crush damage
7. **Hunger & exercise**: random 1/30 chance; attribute abuse/exercise based on hunger state; armor penalty; depth-based risk exercise
8. **Divine intervention**: random 1/10 chance if character; 75% patron god, else random; checks anger vs tolerance
9. **Flat-footed management**: increments FFCount; removes RAGING and FLAWLESS_DODGE when appropriate
10. **Fatigue regeneration**: CA_FATIGUE_REGEN recovers 1 FP after 50+ FFCount; otherwise reset to 30
11. **Combat readiness**: updates AoO based on DEX modifier; FT_COMBAT_REFLEXES adds 1; FT_MOBILITY adds 1; gaze/proximity attacks trigger
12. **Mana recovery**: quadratic formula (see below)
13. **Status update**: `UpdateStati()` processes all status durations
14. **Field effects**: applies continual field effects
15. **Poison processing**: for each POISONED status, every `cval` turns: Fort save vs `sval` DC; success increments Mag (saves needed); if Mag >= lval: overcome poison with CON exercise; failure: apply effect, halt action
16. **Disease pulse**: separate disease handling via DiseasePulse()
17. **Bleeding**: if has blood type, take damage each turn
18. **Natural regeneration**: REGEN status: Mag% chance to regenerate 1 HP per 100 ranks each turn
19. **Periodic effects**: PERIODIC status effects trigger every Val turns
20. **Inherent regeneration**: CA_REGEN ability regenerates HP directly; costs increased hunger

### Mana Recovery System
```
Recovery requires 35-80% of max mana depending on Concentration skill.
Quadratic formula: time = N² to recover from N% loss.

if (uMana > 0) {
    if (!isPlayer() || cMana() >= (nhMana() * min(35+SkillLevel(SK_CONCENT)*2, 80)) / 100) {
        if (ManaPulse > 0) {
            ManaPulse--;
        } else {
            uMana--;
            N = (tMana() - (cMana() + hMana)) * 20 / max(1, tMana());
            ManaPulse = N * 100 / max(1, tMana());
        }
    }
}
```

## Creature Initialization

### Constructor
1. Parent Thing constructor call
2. Set `tmID = mID = _mID` (true and current monster ID)
3. Assert monster data exists
4. Set `Flags = F_SOLID`
5. Clear targeting system counter (`ts.tCount = 0`)
6. Determine gender: M_ALL_FEMALE → female; else 50% random (unless M_NEUTER or M_ALL_MALE)
7. Initialize fatigue and mana pulse to 0

### AddTemplate(rID tID)
- Checks CanAddTemplate() for validity
- Sets TEMPLATE status (Mag = visibility flag)
- Resolves attack conflicts (keeps higher damage attack)
- Grants new feats and skills from template
- Updates image appearance, recalculates values
- Re-equips if monster, updates map display

### Multiply(val, split, msg)
- Creates offspring copies of creature
- Copies mana pools; grants equipment from template/monster
- Applies GENERATION status (Mag = depth)
- Initializes offspring; splits or duplicates HP

## Hunger System

### Hunger States (ordered worst to best)
STARVED → FAINTING → WEAK → STARVING → HUNGRY → PECKISH → CONTENT → SATIATED → BLOATED

### GetHungrier(amt)
- Large creatures need 2× food (size scaling)
- Fasting ability: 66% of CR reduction per level
- Hunger value decreases food state; hitting 0 advances to worse state

## Encumbrance System

### Encumbrance()/MaxPress()
- Uses strength-based table with size multipliers
- Affected by items in all slots
- IGNORE_SLOT_WEIGHT status exempts specific items
- Returns: EN_NONE, EN_LIGHT, EN_MODERATE, EN_HEAVY, EN_EXTREME
- Affects DEX penalties and movement speed

## Fatigue System

### LoseFatigue(amt, avoid)
- `cFP` tracks current fatigue (can go negative)
- At `-Attr[A_FAT]`: Fort save or fall asleep (SLEEP_FATIGUE)
- Essiah favor: good creatures get divine help when fighting while fatigued
- Stat change triggers CalcValues() recalculation if crosses into/out of negative

## Challenge Rating

```cpp
int16 ChallengeRating(bool allow_neg) {
    CR = TMON(mID)->CR;
    // Adjust for all templates
    StatiIterNature(this, TEMPLATE)
        CR = TTEM(S->eID)->CR.Adjust(CR);
    // Characters use total class levels instead
    if (isCharacter())
        CR = Level[0] + Level[1] + Level[2];
    return allow_neg ? CR : max(0, CR);
}
```

## Flanking (isFlanking)
- Checks if this creature is flanking target c
- Requires adjacent ally opposite the target
- Uncanny Dodge with 4+ ranks prevents flanking
- Returns true if ally is hostile to target and adjacent

## Saving Throws

### Three types: FORT, REF, WILL

### Bonus sources:
- Base attribute saves
- SAVE_BONUS stati
- Skills (Balance, Poison Use, Pick Pockets)
- Feats (Hardiness)
- Rest bonus (+4)

### Exercise gains:
- Successful saves vs high DC grant attribute exercise
- Different exercise for poison/disease vs instant death saves

## Planes of Existence
```cpp
PHASE_MATERIAL   // Normal plane
PHASE_ETHEREAL   // Spirits, invisible creatures
PHASE_ASTRAL     // Astral plane
PHASE_NEGATIVE   // Negative energy plane (undead)
PHASE_SHADOW     // Shadow plane
PHASE_VORTEX     // Elemental vortices
```
`onPlane()` returns current plane state. Creatures on different planes can pass through each other.

## Illusion System
- `isIllusion()` — checks ILLUSION status
- `isRealTo(Creature *watcher)` — disbelief check (Will save vs illusion DC)
- `getIllusionFlags()` — returns IL_IMPROVED, IL_SPECTRAL, etc.
- `getIllusioncraft()` — gets caster skill level
- Spectral illusions require LOS to caster
- TRUE_SIGHT, blindsight, tremorsense, scent can penetrate illusions

## Attribute Death
```cpp
const char* CauseOfDeath[] = {
    "withering", "numbing", "unhealth",
    "brain damage", "catatonia", "ego annihilation",
    "the Hand of Fate"
};
```
Each ability score drain (STR-LUC + special) can trigger death via `ThrowDmg(EV_DEATH, AD_DAST+i, ...)`.

## canMoveThrough — Collision Detection
Checks in order:
1. Solidity test (unless ghostwalk/incorporeal)
2. Door/obstacle checks
3. Feature WALKON events
4. Creature collisions: illusions (check if real), hidden creatures (size-dependent), non-hostile (size-dependent), elevation differences, incorporeal/swarm types, different planes

## MoveAttr — Movement Speed Modifier
Factors (100% = normal, 130% = faster, 70% = slower):
- Base MOV attribute
- Terrain MoveMod
- Features on terrain
- Water terrain (70% normally, 100% if aquatic, bonus for swim skill)
- Region size restrictions (half speed in tight regions)
- Woodland Stride (negates terrain penalties)
- Incorporeal/aerial movement (no penalties)
- Blindness penalty (double time if blind without Blind-Fight feat)

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
