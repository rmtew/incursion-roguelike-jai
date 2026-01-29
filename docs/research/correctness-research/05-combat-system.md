# Combat System

**Source**: `Fight.cpp`, `Move.cpp`, `Values.cpp`
**Status**: Fully researched

## Overview

Combat uses the d20 system (based on D&D 3.5e Open Gaming License). Attacks flow through a chain of events, each step allowing resource scripts to modify behavior.

## Attack Event Flow

```
Player/Monster selects attack action
  → EV_ATTK (generic attack setup)
    → EV_NATTACK (natural attack - iterates all attacks)
    or EV_WATTACK (weapon attack - uses equipped weapon)
    or EV_RATTACK (ranged - throwing/shooting)
      → EV_STRIKE (individual strike attempt)
        → Hit roll: d20 + vHit vs vDef
          → EV_HIT (on success)
            → EV_DAMAGE (apply damage)
              → EV_DEATH (if HP <= 0)
          → EV_MISS (on failure)
          → EV_CRIT (on critical)
          → EV_FUMBLE (on natural 1)
          → EV_BLOCK / EV_PARRY / EV_DODGE (defensive reactions)
        → EV_ATTACKMSG (generate combat message)
```

## Attack Types (A_* Constants, 114 types)

### Standard Attacks
Melee natural attacks (A_PUNC, A_BITE, A_CLAW, A_KICK, A_SLAM, A_GORE, etc.)

### Post-Grab Attacks
Executed after successful grapple (A_SWALLOW, A_CRUSH, A_BLOOD, etc.)

### Special Attacks
Non-standard combat actions (A_SPIT, A_ROAR, A_GAZE, A_AURA, etc.)

### Response Attacks
Triggered reactively (A_DEQU - disarm on equip, A_BREA - breath weapon)

### Maneuvers
Combat technique attacks (A_TRIP, A_DISARM, A_SUNDER, A_BULL, A_GRAB)

### Ability Attacks
Special ability-based (A_ALSO, A_CRIT - extra damage on crit, A_SPE1/A_SPE2)

## TAttack Structure
```cpp
struct TAttack {
    int8 AType;          // Attack type (A_* constant)
    int8 DType;          // Damage type
    Dice u;              // Damage dice OR rID for special
    int8 DC_Type;        // Save DC type (or 0)
};
```

## Hit Calculation

### Attack Roll
```
d20 + Base Attack Bonus + Strength/Dex mod + size mod + misc bonuses
```

### Defense (AC)
```
10 + armor bonus + shield bonus + Dex mod + size mod + natural armor + deflection + misc
```

### Critical Hits
1. Threat: Natural roll >= weapon's threat range (typically 20, or 19-20, or 18-20)
2. Confirm: Second attack roll vs AC
3. Damage multiplied by crit multiplier (typically x2 or x3)

### Fumbles
Natural 1 always misses. May trigger additional fumble effects.

## Damage Calculation

```
Weapon damage dice + Strength mod (or 1.5x for two-handed)
+ enhancement bonus + feat bonuses + sneak attack (if applicable)
```

### Damage Types
Physical: Slashing, Piercing, Bludgeoning
Energy: Fire, Cold, Electricity, Acid, Sonic
Special: Positive, Negative, Force, Alignment-based

### Damage Resistance
- `ResistLevel(DType)` returns resistance value
- Resistance reduces damage by flat amount
- Some creatures immune to specific types

## Special Combat

### Attacks of Opportunity (AoO)
- Triggered by: movement through threatened area, casting in melee, ranged attack in melee
- Limited by AoO count per round (default 1, feats increase)
- `canMakeAoO(victim)` checks eligibility
- `EV_OATTACK` event type

### Cleave
- On killing a target, may immediately attack adjacent enemy
- Great Cleave allows unlimited cleave attacks per round

### Grapple
- Grapple check: d20 + BAB + Str mod + size mod
- While grappled: limited actions, post-grab attacks possible

### Bull Rush
- Opposed Strength checks
- Success pushes target back

### Maneuvers
Trip, Disarm, Sunder - each has specific opposed check formulas

### Whirlwind Attack
- Attack all adjacent enemies in one action

### Sneak Attack
- Extra damage when: flanking, target flat-footed, target denied Dex
- Damage: +Nd6 (based on rogue level)

## Movement System (Move.cpp)

### Walking
- `EV_MOVE` event
- Movement cost based on terrain and creature speed
- `MoveTimeout(from_x, from_y)` calculates speed

### Passability
- `canMoveThrough(e, tx, ty, blocked_by)` - comprehensive check
- Considers: terrain solidity, creature occupancy, flying/swimming/phasing
- Returns blocking entity if blocked

### Special Movement
- Flying: ignores ground terrain
- Swimming: required for water terrain
- Phasing: moves through walls
- Jumping: `EV_JUMP` - leap over obstacles
- Pushing: `EV_PUSH` - push creatures/objects

### Movement and AoO
Moving out of a threatened square provokes AoO unless:
- Using 5-foot step
- Creature has specific feats (Spring Attack, etc.)

## EventInfo Combat Fields

### Attack Resolution
| Field | Type | Purpose |
|-------|------|---------|
| vRoll | int8 | Natural d20 roll |
| vtRoll | int8 | Total attack roll |
| AType | int8 | Attack type (A_*) |
| DType | int8 | Damage type |
| vHit | int8 | Attack bonus |
| vDef | int8 | Defense value |
| vThreat | int8 | Threat range |
| vCrit | int8 | Critical multiplier |
| vArm | int8 | Armor value |
| vPen | int8 | Penetration |
| vDmg | int16 | Total damage |
| bDmg | int16 | Base damage |
| aDmg | int16 | Additional damage |
| xDmg | int16 | Extra damage |
| Dmg | Dice | Damage dice |

### Combat State Booleans
isHit, isCrit, isFumble, Died, ADied, Blocked, Saved, Immune, Resist, Absorb, Ranged, isAoO, isCleave, isSurprise, isGreatBlow, isSneakAttack, isFlanking, isFlatFoot, isOffhand, isGhostTouch, isPrecision

## CalcValues() - Central Recalculation Engine

**Source**: `Values.cpp` (1546 lines)

Recalculates ALL creature attributes. Called when status effects change, equipment changes, or level-up occurs.

### Attributes Calculated
- `Attr[0-6]` - STR, DEX, CON, INT, WIS, CHA, LUC
- `Attr[A_SIZ]` - Size
- `Attr[A_FAT]` - Fatigue points
- `Attr[A_MOV]` - Movement speed
- `Attr[A_ARM]` - Natural armor
- `Attr[A_DEF]` - Defense/AC
- `Attr[A_MR]` - Magic resistance
- Hit bonuses: A_HIT_ARCHERY, A_HIT_MELEE, A_HIT_BRAWL, A_HIT_OFFHAND, A_HIT_THROWN
- Damage bonuses: A_DMG_ARCHERY, A_DMG_MELEE, A_DMG_BRAWL, A_DMG_OFFHAND, A_DMG_THROWN
- Speed bonuses: A_SPD_ARCHERY, A_SPD_MELEE, A_SPD_BRAWL, A_SPD_OFFHAND, A_SPD_THROWN
- Spell bonuses: ARC, DIV, SOR, PRI, BAR
- Saving throws: A_SAV_FORT, A_SAV_REF, A_SAV_WILL
- Perception ranges: SightRange, LightRange, ShadowRange, ScentRange, InfraRange, TelepRange, TremorRange, BlindRange, NatureSight, PercepRange
- Derived: cHP, cFP, cMana, mHP, mMana, A_CDEF (casting defense)

### CalcValues Flow
1. Save old attribute values
2. Clear `AttrAdj[ATTR_LAST][BONUS_LAST]` array (41×39)
3. Apply bonuses in priority order
4. Handle special states (polymorphed, mounted)
5. Apply weapon/armor bonuses
6. Apply status effect modifiers
7. Apply feat bonuses
8. Sum bonus array into final values
9. Handle special cases (attribute death, minimums)
10. UpdateImage, handle size-change side effects

## Bonus Stacking System

### AttrAdj Matrix
`AttrAdj[41][39]` - 2D array tracking bonus by attribute × bonus type. Bonus types include:
BONUS_BASE, BONUS_NATURAL, BONUS_CLASS/CLASS2/CLASS3, BONUS_TEMP, BONUS_WEAPON, BONUS_ENHANCE, BONUS_SKILL, BONUS_FEAT, BONUS_STATUS, BONUS_DODGE, BONUS_SHIELD, BONUS_ARMOUR, BONUS_SACRED, BONUS_INSIGHT, BONUS_COMP, BONUS_ARTI, BONUS_DEFLECT, BONUS_DAMAGE, BONUS_NEGLEV, BONUS_MORALE, BONUS_LUCK, BONUS_RESIST, BONUS_PAIN, BONUS_SIZE, BONUS_ENCUM, BONUS_FATIGUE, BONUS_RAGE, BONUS_GRACE, BONUS_DUAL, BONUS_CIRC, BONUS_ATTR, BONUS_HIDE, BONUS_INHERANT, BONUS_TACTIC, BONUS_ELEV, BONUS_HUNT, BONUS_DIETY

### StackBonus() - Always Stacks
```cpp
AttrAdj[attr][btype] += bonus;  // Direct addition
```
Used for: all penalties, dodge bonuses, circumstance bonuses.

### AddBonus() - Smart Stacking
```cpp
if (bonus < 0 || special_type)
    StackBonus(btype, attr, bonus);      // Stack negatives
else
    AttrAdj[attr][btype] = WESMAX(AttrAdj[attr][btype], bonus);  // Take best positive
```

WESMAX macro: `(attr < 0) ? attr + bonus : max(attr, bonus)` - handles mixed positive/negative from same source (imperfectly - see known issues).

### Concentration Burn
Negative bonus to A_MAG can be absorbed by concentration pool:
```cpp
if (concentUsed + (-bonus) <= concentTotal) { concentUsed += (-bonus); return; }
```

### Percentage Attributes (Movement, Mana)
Multiplicative stacking: `((Attr[i]*5+100) * (AttrAdj[i][j]*5+100)) / 100 - 100) / 5`

### Magic Resistance Stacking (Diminishing Returns)
```cpp
MR_total += ((100 - MR_total) * source) / 100  // 50% + 50% = 75%, not 100%
```

### Known Stacking Issues
- Penalties from same effect don't track source eID, so two slow traps create double penalty
- `AttrAdj[][]` doesn't store effect ID for deduplication
- Planned fix: separate AttrBon/AttrPen arrays (not implemented)

## Saving Throw Calculation

### Monsters
```cpp
tsav = MonGoodSaves(MType[0]) | MonGoodSaves(MType[1]) | MonGoodSaves(MType[2]);
if (tsav & XBIT(FORT)) AddBonus(BONUS_BASE, A_SAV_FORT, GoodSave[CR]);
else                    AddBonus(BONUS_BASE, A_SAV_FORT, PoorSave[CR]);
```

### Characters
Per-class good/poor saves (CF_GOOD_FORT/REF/WILL flags), plus:
- Fortitude: +CON mod (+FT_GREAT_FORTITUDE +3, +CA_DIVINE_GRACE)
- Reflex: +DEX mod (+FT_LIGHTNING_REFLEXES +3)
- Will: +WIS mod (+FT_IRON_WILL +3, +CA_UNEARTHLY_LUCK)
- FT_ONE_BODY_ONE_SOUL: uses max(CON mod, WIS mod) for Fort

## Attack Bonus Calculation

```
Total Hit = BAB + STR/DEX mod + weapon accuracy + GetPlus()
          + size mod + finesse adjustments + skill bonuses + feat bonuses
          - non-proficiency penalty - two-weapon penalty
```

### BAB
- Monsters: `TMON(mID)->Hit` + template adjustments
- Characters: Sum of `ClassAttkVal[mode] × Level / 100` per class

### Weapon Finesse
```cpp
AddBonus(BONUS_ATTR, A_HIT_MELEE, max(Mod(A_STR), Mod(A_DEX)));
```

### Weapon Skill Bonuses

| Skill Level | Hit | Damage | Speed | AC |
|---|---|---|---|---|
| WS_NOT_PROF | -4 | - | -10 | - |
| WS_PROFICIENT | 0 | 0 | 0 | 0 |
| WS_FOCUSED | +1 | 0 | 0 | 0 |
| WS_SPECIALIST | +1 | +2 | +2 | 0 |
| WS_MASTERY | +2 | +2 | +4 | +2 |
| WS_HIGH_MASTERY | +2 | +3 | +6 | +3 |
| WS_GRAND_MASTERY | +3 | +4 | +10 | +4 |

### Weapon Damage by Grip
- Two-handed: `STR_mod * 3 / 2` (1.5× STR)
- One-handed: `STR_mod`
- Off-hand: `STR_mod / 2` (full if double weapon feat)
- Ranged with STR bow: `STR_mod`
- Thrown: `max(0, STR_mod)`

## AC/Defense Calculation

```
AC = 10 + DEX mod + armor bonus + shield bonus + natural armor
   + dodge bonuses + deflection + size mod + misc
```

Size modifier: `SZ_MEDIUM - Attr[A_SIZ]` (Fine:-8 Dim:-4 Tiny:-2 Small:-1 Med:0 Large:+1 Huge:+2 Garg:+4 Col:+8)

Special cases:
- Incorporeal: +max(1, CHA mod) deflection
- Grappling: lose dodge/shield bonuses
- Two-weapon fighting: -2 without feat

## Damage Resistance

### ResistLevel() (lines 1745-1886)

Returns cumulative resistance. `-1` = immune.

**Sources accumulated:**
1. Immunity check: `HasStati(IMMUNITY, DType)` → return -1
2. Monster type: `7 + (CR*2)/3`
3. Abilities: `CA_BOOST_RESISTS` level
4. Status effects: best per source (excludes disabled)
5. Feats: FT_DIVINE_ARMOUR (CHA×2 for necro/holy/lawful/chaotic), FT_DIVINE_RESISTANCE (CHA for fire/cold/elec), FT_HARDINESS (5 for toxin/poison/disease)
6. Rage immunities: confusion (mag≥7), stun (mag≥13)
7. Physical: natural armor + equipped armor ArmVal

### Resistance Stacking Formula
```
total = highest + (2nd_highest / 2) + sum(remaining / 3)
```
Prevents abuse of many small resistances.

## HP Calculation

### Characters
```
mHP = 20 (base)
+ sum(per-class per-level: max(1, CON_mod + hpRolls[class][level]))
+ template HD adjustments
+ CA_TOUGH_AS_HELL: level × max(0, CON_mod)
+ FT_TOUGHNESS: mHP / 4
```

Size multipliers: Miniscule ×0.5, Tiny ×0.7, Small ×0.9, Medium ×1.0, Large ×1.1, Huge ×1.3, Garg ×1.6, Colossal ×2.0

FT_ONE_BODY_ONE_SOUL: uses max(CON mod, WIS mod) for HP calculation.

Death check: if recalc drops cHP≤0, Fort save DC 20 → succeed: cHP=1, fail: Death().

### Monsters (CalcHP)
```
mHP = Roll(HD, HDType) + HD × CON_mod
+ CA_TOUGH_AS_HELL, FT_TOUGHNESS bonuses
+ size multipliers
+ summoned bonus: mHP × (summoner_best_know_skill × 5) / 100
+ HEROIC_QUALITY: +20
```

## Encumbrance Penalties

| Load | AC | Movement | Ref Save | Speed | Fatigue |
|---|---|---|---|---|---|
| Light | - | -2 | - | - | - |
| Moderate | -1 | -4 | - | - | -1 |
| Heavy | -2 | -6 | -2 | -2 | -2 |
| Extreme | -4 | -10 | -4 | -5 | -3 |

## Fatigue Penalties

| State | STR | DEX | CHA | Movement | Speed |
|---|---|---|---|---|---|
| Fatigued | -2 | -2 | -2 | -2 | -2 |
| Exhausted | -6 | -6 | -6 | -5 | -5 |

## Hunger Penalties

| State | MAG | FAT | STR | CON |
|---|---|---|---|---|
| Hungry | - | -1 | -1 | -1 |
| Starving | -3 | -2 | -2 | -2 |
| Weak | -6 | -2 | -4 | -4 |
| Fainting | -6 | -2 | -4 | -4 |

## Rage Bonuses
Small race: STR+Val/2, DEX+Val/2. Normal: STR+Val. Both: CON+Val, SPD+Val, Will save+Val/2.

## Skill Points
```
TotalSP[class] = ClassSkillPoints + INT_mod × Level[class]   // normal
                 (× 2 for high skill point classes)
```

## Porting Considerations

1. **Event chain** - Each step must allow script intervention; port event dispatch first
2. **CalcValues()** - Central 1546-line function; consider breaking into sub-procedures by category
3. **Bonus stacking** - AttrAdj[41][39] matrix with AddBonus/StackBonus dual system
4. **Attack iteration** - NAttack iterates TMonster's Attk[32] array; each generates separate Strike
5. **Static weapon references** - Creature has static `meleeWep`, `offhandWep`, etc. for current attack context
6. **Resistance stacking** - Custom diminishing returns formula, not simple addition
7. **Known stacking bug** - Penalty deduplication by eID not implemented; needs design decision during port
