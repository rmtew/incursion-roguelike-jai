# Values & CalcValues System

**Source**: `Values.cpp`
**Status**: Architecture researched from headers; exact formulas need implementation read during porting

## Overview

Values.cpp is the d20 rules engine - it computes all derived attribute values from base stats, equipment, status effects, class features, and temporary modifiers. CalcValues() is called frequently and is one of the most critical functions for gameplay correctness.

## CalcValues() Method

```cpp
virtual void Creature::CalcValues(bool KnownOnly, Item *thrown)
virtual void Character::CalcValues(bool KnownOnly, Item *thrown)
```

### What It Calculates
Starting from base attributes, applies all modifiers to compute:

1. **Core Attributes** (Attr[ATTR_LAST], 41 entries)
   - A_STR, A_DEX, A_CON, A_INT, A_WIS, A_CHA, A_LUC (7 base)
   - Derived: A_HIT, A_DEF, A_ARM, A_MOV, A_SPD, A_SAV_FORT, A_SAV_REF, A_SAV_WILL
   - And 20+ other derived attributes

2. **Attack Values**
   - Base Attack Bonus (BAB) from class levels
   - Melee/ranged attack modifiers
   - Damage modifiers

3. **Defense Values**
   - Armor Class (AC) from all sources
   - Deflection, natural armor, shield bonuses
   - Max Dex bonus (from armor)

4. **Saving Throws**
   - Fortitude (CON-based)
   - Reflex (DEX-based)
   - Will (WIS-based)
   - Class progression + attribute mods + misc

5. **Hit Points**
   - From hit dice + CON modifier per level
   - Bonus HP from feats (Toughness)
   - `CalcHP()` handles HP calculation

6. **Perception Ranges**
   - SightRange, TremorRange, BlindRange, etc.
   - Derived from feats, abilities, equipment, stati

7. **Movement Speed**
   - Base speed from race
   - Modified by armor, encumbrance, spells

8. **Skill Modifiers**
   - Ranks + attribute mod + misc bonuses

### Calculation Order
1. Reset Attr[] to base values
2. Apply racial modifiers
3. Apply class-based values (BAB, saves, hit dice)
4. Apply equipment bonuses
5. Apply status effect modifiers
6. Apply feat/ability bonuses
7. Apply temporary modifiers
8. Enforce minimums/maximums
9. Cache perception ranges

### KnownOnly Parameter
When `KnownOnly = true`, only calculate values the player knows about (for display purposes). Hides unknown magical bonuses.

## Attribute System

### 7 Base Attributes
```
A_STR (0) - Strength: melee attack/damage, carrying capacity
A_DEX (1) - Dexterity: ranged attack, AC, reflex saves
A_CON (2) - Constitution: HP per level, fortitude saves
A_INT (3) - Intelligence: skill points, wizard spells
A_WIS (4) - Wisdom: will saves, cleric spells, perception
A_CHA (5) - Charisma: social skills, turning undead
A_LUC (6) - Luck: misc bonus (Incursion-specific)
```

### Attribute Modifier Formula
```
Mod = (Attr - 10) / 2  (round down)
```
Example: STR 16 → +3 modifier, STR 8 → -1 modifier

### ATTR_LAST = 41
Full attribute index includes derived values like:
```
A_HIT_MELEE, A_HIT_RANGED, A_HIT_BRAWL
A_DMG_MELEE, A_DMG_RANGED, A_DMG_BRAWL
A_DEF, A_ARM, A_MOV, A_SPD
A_SAV_FORT, A_SAV_REF, A_SAV_WILL
A_CRIT, A_THREAT
...
```

## Bonus Stacking Rules

### Bonus Types (BONUS_*, 39 types)
```
BONUS_BASE(0), BONUS_ARMOR(1), BONUS_SHIELD(2), BONUS_NATURAL(3),
BONUS_DEFLECT(4), BONUS_DODGE(5), BONUS_ENHANCE(6), BONUS_LUCK(7),
BONUS_MORALE(8), BONUS_INSIGHT(9), BONUS_SACRED(10), BONUS_PROFANE(11),
BONUS_RESIST(12), BONUS_COMP(13), BONUS_CIRC(14), BONUS_SIZE(15),
...
```

### Stacking Rule
```
For each bonus type applied to an attribute:
  if type == BONUS_DODGE: stack (add all)
  else: only highest bonus of that type applies
Penalties always stack (add all)
```

### Implementation
- `AddBonus(btype, attr, bonus)` - Add bonus tracking type
- `StackBonus(btype, attr, bonus)` - Apply with stacking rules
- CalcValues iterates all bonus sources and resolves stacking

## Resistance System

### ResistLevel(DType)
Returns creature's resistance to a damage type:
- Physical resistances (slashing, piercing, bludgeoning)
- Energy resistances (fire, cold, electricity, acid, sonic)
- Special resistances (positive, negative, force)

### Sources of Resistance
- Racial/monster innate (TMonster.Res)
- Equipment qualities (AQ_* armor qualities)
- Spell effects (EF_* effect flags)
- Class abilities (CA_*)
- Status effects

## Hostility Determination

Values.cpp also handles creature relationships:
- Alignment comparison
- Party membership
- Active hostility states
- Neutrality

## Size System (SZ_*, 8 categories)

```
SZ_MINISCULE(1), SZ_TINY(2), SZ_SMALL(3), SZ_MEDIUM(4),
SZ_LARGE(5), SZ_HUGE(6), SZ_GARGANTUAN(7), SZ_COLLOSAL(8)
```

Size affects:
- Attack/AC modifiers
- Grapple modifiers
- Carrying capacity
- Weapon size compatibility
- Reach

## Porting Considerations

1. **CalcValues() is critical** - Must be ported accurately for game balance
2. **Bonus stacking** - 39 types with specific stacking rules; core correctness requirement
3. **Attribute derivation** - All 41 attributes must be computed correctly
4. **Performance** - Called frequently; optimize for Jai's strengths
5. **KnownOnly mode** - Two computation paths (full vs. player-known)
6. **Implementation read needed** - The exact formulas in Values.cpp are essential for porting; flag for focused .cpp read when porting this system
