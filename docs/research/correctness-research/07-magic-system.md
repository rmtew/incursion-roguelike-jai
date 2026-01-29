# Magic & Effects System

**Source**: `Magic.cpp`, `Effects.cpp`, `Prayer.cpp`, `inc/Magic.h`
**Status**: Architecture researched from headers; spell formulas need implementation-level research

## Overview

Magic in Incursion follows d20/OGL rules with modifications. Spells are TEffect resources with school/source/purpose metadata. The effects system implements 14+ archetypes for different spell behaviors.

## Spell Resources (TEffect)

```cpp
class TEffect : public Resource {
    uint32 Schools;              // School bitmask (Evocation, Necromancy, etc.)
    int8 Sources[4];             // Spell sources (arcane, divine, etc.)
    uint32 Purpose;              // EP_* flags (what the effect is for)
    uint8 ManaCost;              // Base mana cost
    uint8 BaseChance;            // Base success chance
    uint8 SaveType;              // Save type (Fortitude, Reflex, Will)
    int8 Level;                  // Spell level
    uint8 EFlags[(EF_LAST/8)+1]; // Effect flags (105 flags)
    EffectValues ef;             // Effect parameters
};
```

### EffectValues Structure
```cpp
struct EffectValues {
    int8  eval;   // Effect archetype (EA_* constant)
    int8  dval;   // Distance/range value
    int8  aval;   // Area of effect (AR_* constant)
    int8  tval;   // Target type
    int8  qval;   // Query/prompt flags
    int8  sval;   // Saving throw type
    int8  lval;   // Level parameter (max HD, radius)
    int8  cval;   // Color of blast visual
    rID   rval;   // Resource value (or extra flags)
    uint8 xval;   // Misc value (stati number, damage type)
    int16 yval;   // Second misc value (stati Val)
    Dice  pval;   // Power value (damage/healing dice)
};
```

### Effect Flags (EF_*, 105+ types, bit indices)
By category:
- **Duration**: EF_DSHORT(23), EF_D1ROUND(24), EF_DLONG(25), EF_DXLONG(26), EF_PERMANANT(54)
- **Frequency**: EF_1PERDAY(94), EF_3PERDAY(76), EF_7PERDAY(77), EF_ONCEONLY(13)
- **Targeting**: EF_CASTER_IMMUNE(34), EF_ALLIES_IMMUNE(35), EF_ANIMAL(36), EF_UNDEAD(37), EF_ELEMENTAL(38), EF_AFFECTS_ITEMS(40), EF_ITEMS_ONLY(41)
- **Damage**: EF_PARTIAL(11), EF_HALF_UNTYPED(62), EF_NO_BONUS_DMG(83), EF_KNOCKBACK(9), EF_KNOCKDOWN(10)
- **Level caps**: EF_CAP5(42), EF_CAP10(43), EF_CR_CAP(39)
- **Generation**: EF_NOGEN(18), EF_CURSED(2), EF_HALF_CURSED(3), EF_COMMON(32), EF_STAPLE(45)
- **Naming**: EF_NAMEFIRST(19), EF_NAMEONLY(20), EF_POSTFIX(91), EF_PROPER(92)
- **Alignment**: EF_CHAOTIC(21), EF_LAWFUL(22), EF_EVIL(55), EF_GOOD(56)
- **Misc**: EF_PERIODIC(1), EF_MULTI(12), EF_STRAIN(15), EF_MENTAL(53), EF_SOUND(58), EF_DEATH(63), EF_FEAR(70), EF_COMPULSION(103), EF_GAZE(104)

### Effect Purpose (EP_* flags)
- EP_PLAYER_ONLY - Only usable by player
- EP_DISPEL - Can be dispelled

## Spellcasting Flow

### Casting a Spell
1. Player/monster selects spell → EV_CAST event
2. Check mana availability (`hasMana(cost)`)
3. Check spell components (verbal, somatic, material)
4. Determine caster level (`CasterLev()`)
5. Calculate spell DC (`getSpellDC()`)
6. Apply metamagic modifiers
7. Spend mana (`LoseMana()`)
8. Dispatch to effect archetype

### Mana System
- `uMana` - Used mana (increases when casting)
- `mMana` - Maximum mana (derived from class/level/stats)
- `hMana` - Held mana (reserved for maintained effects)
- `cMana() = mMana - uMana` - Current available
- `ManaPulse` - Regeneration counter

### Spell DC
```
Base DC = 10 + spell level + casting stat modifier + misc bonuses
```

### Caster Level
Determines spell effectiveness (range, duration, damage dice).
Based on class levels in spellcasting classes.

## Metamagic System (MM_*, 27 types as bitmask)

Applied as modifiers to spells:
```cpp
MM_AMPLIFY    = 0x00000001  // Increase power
MM_EMPOWER    = 0x00000002  // Multiply numeric effects
MM_EXTEND     = 0x00000004  // Double duration
MM_MAXIMIZE   = 0x00000008  // Maximum dice rolls
MM_QUICKEN    = 0x00000010  // Faster casting
MM_SILENT     = 0x00000020  // No verbal component
MM_STILL      = 0x00000040  // No somatic component
MM_WIDEN      = 0x00000080  // Larger area
// ... up to 27 types
MM_WARP       = 0x08000000
```

### Monster Metamagic
`SetMetamagic(eID, tar, Pur)` - AI determines appropriate metamagic for situation

## Counterspelling

- `Counterspell(e, cs)` - Attempt to counter enemy spell
- Requires readied action and appropriate spell knowledge
- FoilCount tracks counterspell resources on Monster

## Magic Class

The `Magic` class is a method mixin (no member variables) inherited by `Item` via multiple inheritance. It provides area-of-effect delivery and effect resolution.

### Global Variables
```cpp
extern int16  ZapX[];      // X coordinates of projectile path
extern int16  ZapY[];      // Y coordinates of projectile path
extern Map*   ZapMap;       // Map the zap occurs on
extern uint16 ZapImage[];   // Visual glyphs for animation
```

### Area-of-Effect Delivery
```cpp
ABallBeamBolt(EventInfo&)              // Unified: ball, beam, bolt, chain, cone, ray
PredictVictimsOfBallBeamBolt(...)      // AI helper: predict victims without casting
ATouch(EventInfo&)                     // Touch-range delivery
AGlobe(EventInfo&)                     // Globe/emanation (centered on caster)
AField(EventInfo&)                     // Persistent area (web, darkness)
ABarrier(EventInfo&)                   // Wall/barrier effects
```

### Core Processing Pipeline
```cpp
isTarget(EventInfo&, Thing*)           // Should thing be affected?
CalcEffect(EventInfo&)                 // Calculate parameters (damage, DC, duration)
MagicEvent(EventInfo&)                 // Main entry: orchestrates full resolution
MagicStrike(EventInfo&)               // Apply as weapon strike (quality-based)
MagicHit(EventInfo&)                  // Apply on successful attack
MagicXY(EventInfo&, x, y)            // Apply at specific coordinate
```

### Area Range Constants (AR_*)
```cpp
AR_NONE(0)    AR_BOLT(1)      AR_BEAM(2)     AR_BALL(3)
AR_RAY(4)     AR_BURST(5)     AR_TOUCH(6)    AR_FIELD(7)
AR_BARRIER(8) AR_MFIELD(9)    AR_PFIELD(10)  AR_GLOBE(11)
AR_BREATH(12) AR_GRADIENT(13) AR_POISON(14)  AR_DISEASE(15)
AR_CHAIN(16)  AR_CONE(17)
```

## Effect Archetypes (EA_*, 46 types)

Each archetype is a method handling a specific category of magical effect, selected by `EffectValues.eval`:

| EA Code | Method | Purpose |
|---|---|---|
| EA_BLAST(1) | `Blast(e)` | Direct damage (fireball, lightning bolt) |
| EA_GRANT(2) | `Grant(e)` | Apply beneficial status (haste, bull's strength) |
| EA_INFLICT(3) | `Inflict(e)` | Apply harmful status (blindness, slow) |
| EA_DRAIN(4) | `Drain(e)` | Drain attributes or levels |
| EA_TERRAFORM(5) | `Terraform(e)` | Modify terrain (stone to mud) |
| EA_TRAVEL(6) | `Travel(e)` | Teleportation, dimension door |
| EA_IDENTIFY(7) | `Identify(e)` | Identify items |
| EA_ILLUSION(8) | `Illusion(e)` | Create illusions |
| EA_SUMMON(9) | `Summon(e)` | Summon creatures |
| EA_ANIMATE(10) | `Animate(e)` | Animate dead, construct golems |
| EA_CREATION(13) | `Creation(e)` | Create items (major creation) |
| EA_SLAYING(18) | `Slaying(e)` | Instant death (slay living, PW kill, disintegrate) |
| EA_DETECT(20) | `Detect(e)` | Detection spells |
| EA_DISPEL(22) | `Dispel(e)` | Dispel magic / disjunction |
| EA_BANISH(24) | `Banish(e)` | Imprisonment, abjure, banishment |
| EA_HEALING(26) | `Healing(e)` | Cure/heal, gain mana/bonus HP |
| EA_RAISE(27) | `Raise(e)` | Raise dead, resurrection |
| EA_MENU(28) | `Menu(e)` | Multi-effect staves and artifacts |
| EA_CANCEL(29) | `Cancel(e)` | Rod of cancellation |
| EA_OVERRIDE(30) | `Override(e)` | Override effect |
| EA_MANYTHINGS(31) | `ManyThings(e)` | Complex multi-effect |
| EA_POLYMORPH(32) | `Polymorph(e)` | Polymorph |
| EA_LEVGAIN(34) | `LevGain(e)` | Level gain |
| EA_HOLDING(35) | `Holding(e)` | Bags of holding, deeppockets |
| EA_WARNING(36) | `Warning(e)` | Amulet of warning |
| EA_DIGGING(37) | `Digging(e)` | Wand of digging, rock to mud |
| EA_EARTHQUAKE(38) | `Earthquake(e)` | Earthquake |
| EA_CURE(39) | `Cure(e)` | Remove status effects |
| EA_RESTORE(40) | `Restore(e)` | Restore drained attributes |
| EA_REVEAL(42) | `Reveal(e)` | Reveal hidden things |
| EA_CONSTRUCT(44) | `EConstruct(e)` | Spiritual weapon, black blade |
| EA_VISION(47) | `Vision(e)` | Vision effects |
| EA_SHIELD(8) | `Shield(e)` | Shield effects |

Additional effect methods (not directly EA_ mapped):
`Bless`, `Charm`, `Poison`, `TimeStop`, `Telepathy`, `Castigate` (turning), `Wonder` (wand of wonder), `Genocide`

## Prayer System (Prayer.cpp)

### Divine Mechanics
- `EV_PRAY` - Player prays to deity
- `EV_SACRIFICE` - Offer items to deity
- `EV_BLESSING` - Receive divine blessing
- `EV_GOD_RAISE` - Deity resurrects player

### Deity Favor
```cpp
int16 FavourLev[MAX_GODS];     // Favor level per deity
int32 TempFavour[MAX_GODS];    // Temporary favor
int16 Anger[MAX_GODS];         // Anger level
int32 SacVals[MAX_GODS][MAX_SAC_CATS+2]; // Sacrifice tracking
```

### God Flags (GF_*, 21 types)
GF_GOOD, GF_EVIL, GF_LAWFUL, GF_CHAOTIC - deity alignment

### Favor Calculation
- `calcFavour(gID)` - Calculate current favor
- `gainFavour(gID, amt)` - Increase favor
- `Transgress(gID, mag)` - Decrease favor (sinful act)
- Favor determines: prayer success rate, blessing power, divine intervention chance

### Crowning
At maximum favor, deity crowns the character with a special artifact.

## Spell Knowledge

### Character Spell System
```cpp
uint16 Spells[MAX_SPELLS+1];  // Bitfield of spell knowledge flags
uint32 MMArray[MAX_SPELLS];   // Stored metamagic per spell
```

### Spell Access
- `hasAccessToSpell(spID)` - Can character learn/cast this spell?
- `HasInnateSpell(spID)` - Has innate (non-learned) access
- `getSpellFlags(spID)` - Knowledge flags for spell
- `getStoredMM(spID)` - Stored metamagic configuration

## Magic School Constants (SC_*, uint32 bitmask)
```cpp
SC_ABJ  0x00000001   // Abjuration
SC_ARC  0x00000002   // Arcane
SC_DIV  0x00000004   // Divination
SC_ENC  0x00000008   // Enchantment
SC_EVO  0x00000010   // Evocation
SC_ILL  0x00000020   // Illusion
SC_NEC  0x00000040   // Necromancy
SC_THA  0x00000080   // Thaumaturgy
```

## Saving Throw Types (SN_*, 22+ types)
```
SN_MAGIC(1) SN_EVIL(2) SN_NECRO(3) SN_PARA(4) SN_DEATH(5) SN_ENCH(6)
SN_PETRI(7) SN_POISON(8) SN_TRAPS(9) SN_GRAB(10) SN_FEAR(11) SN_ILLUS(12)
SN_CONF(13) SN_DISEASE(14) SN_COMP(15) SN_SPELLS(16) SN_CLOSE(17)
SN_THEFT(18) SN_DISINT(19) SN_KNOCKDOWN(20) SN_STUN(21) SN_REST(22)
```

## Damage Type Constants (AD_*, 94+ types)

### Physical
AD_NORM(0), AD_SLASH(11), AD_PIERCE(12), AD_BLUNT(13)

### Elemental/Energy
AD_FIRE(1), AD_COLD(2), AD_ACID(3), AD_ELEC(4), AD_TOXI(5), AD_NECR(6), AD_PSYC(7), AD_MAGC(8), AD_SUNL(9), AD_SONI(10)

### Status Effects (as damage types)
AD_SLEE(16), AD_STUN(17), AD_PLYS(18), AD_STON(19), AD_POLY(20), AD_CHRM(21), AD_DISN(22), AD_BLND(24), AD_SLOW(25), AD_CONF(26), AD_FEAR(28), AD_NAUS(30)

### Drain Effects
AD_DREX(32 life levels), AD_DRMA(33 mana), AD_DRST-AD_DRLU(43-49 stat drains), AD_DAST-AD_DALU(50-56 stat damage)

### Special Attacks
AD_STEA(36 steal), AD_SGLD(37 steal gold), AD_TLPT(38 teleport), AD_RUST(39), AD_WRAP(42 grab), AD_GRAB(63), AD_ENGL(66 engulf), AD_TRIP(67), AD_DISA(68 disarm)

### Alignment
AD_HOLY(69), AD_LAWF(70), AD_CHAO(71), AD_EVIL(72)

### Other
AD_VAMP(73 vampiric), AD_SOAK(74 water), AD_POIS(60 true poison), AD_BLEE(59 bleeding), AD_WERE(58 lycanthropy), AD_KNOC(61 knockback)

## Porting Considerations

1. **Effect dispatch** - Each archetype is a separate handler; in Jai, use a switch on EA_* type
2. **EffectValues** - 12 generic parameter fields; document what each means per archetype
3. **Metamagic bitmask** - Straightforward in Jai
4. **Spell knowledge bitfield** - Direct port
5. **Deity favor** - Complex multi-dimensional tracking system
6. **Mana vs spell slots** - Incursion uses mana (not Vancian slots)
