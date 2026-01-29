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
    // 12 parameter fields for different effect aspects
    int eval, dval, aval, tval, qval;
    int sval, lval, cval, rval;
    int xval, yval, pval;
};
```

### Effect Flags (EF_*, 105 types)
Key flags:
- EF_PERIODIC(1) - Repeating effect
- EF_CURSED(2) - Creates cursed items
- EF_KNOCKBACK(9) - Pushes target
- EF_MENTAL(53) - Mind-affecting
- EF_PERMANENT(54) - Permanent duration
- EF_CHAOTIC(21)/EF_LAWFUL(22) - Alignment effects
- EF_CASTER_IMMUNE(34) - Caster not affected

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

## Effect Archetypes (EA_*, 46 types)

### EA_BLAST - Area Damage
Damage in area (fireball, lightning bolt, etc.)
- Parameters: damage dice, element type, area shape/size

### EA_GRANT - Buff/Enhancement
Grant abilities, bonuses, or states
- Parameters: bonus type, value, duration

### EA_DRAIN - Attribute/Level Drain
Reduce attributes or levels
- Parameters: attribute affected, amount, save DC

### EA_INFLICT - Status Effects
Apply negative conditions (blind, paralyze, etc.)
- Parameters: condition type, duration, save

### EA_HEALING - Restoration
Restore HP, remove conditions
- Parameters: heal dice, conditions removed

### EA_SUMMON - Summoning
Bring creatures into existence
- Parameters: creature type, count, duration

### EA_POLYMORPH - Transformation
Change creature form
- Parameters: new form, merge items flag

### EA_DISPEL - Remove Effects
Counter/remove existing magical effects
- Parameters: dispel check bonus, area

### EA_REVEAL - Information
Detect/identify/reveal hidden information
- Parameters: detection type, range

### EA_TERRAFORM - Terrain Modification
Change map terrain
- Parameters: new terrain type, area, duration

### EA_ILLUSION - False Perception
Create false sensory impressions
- Parameters: illusion type, believability

### EA_CREATION - Create Objects
Conjure items or materials
- Parameters: item type, quantity

### EA_DETECT - Magical Detection
Sense specific things (magic, evil, traps, etc.)
- Parameters: detection target, range

### EA_TRAVEL - Movement/Teleportation
Magical movement (teleport, dimension door, etc.)
- Parameters: destination, range

### EA_VISION - Sight Enhancement
Enhance or grant vision types
- Parameters: vision type, range, duration

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

## Porting Considerations

1. **Effect dispatch** - Each archetype is a separate handler; in Jai, use a switch on EA_* type
2. **EffectValues** - 12 generic parameter fields; document what each means per archetype
3. **Metamagic bitmask** - Straightforward in Jai
4. **Spell knowledge bitfield** - Direct port
5. **Deity favor** - Complex multi-dimensional tracking system
6. **Mana vs spell slots** - Incursion uses mana (not Vancian slots)
