# Creature System

**Source**: `Creature.cpp`, `Character.cpp`, `Player.cpp`, `Monster.cpp`, `Create.cpp`
**Headers**: `inc/Creature.h`
**Status**: Architecture researched from headers; implementation details need per-function research during porting

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
- `RateAsTarget(t)` - Evaluate target attractiveness
- `Retarget()` - Find new targets
- `SmartDirTo(tx, ty)` - Pathfind toward target
- `Movement()` - Execute movement decision
- `PreBuff()` - Apply pre-combat buffs
- `MonsterGear()` - Equip from template
- `TurnHostileTo(cr)`, `Pacify(cr)` - Hostility management

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
