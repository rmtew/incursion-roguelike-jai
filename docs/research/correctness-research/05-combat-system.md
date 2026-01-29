# Combat System

**Source**: `Fight.cpp`, `Move.cpp`
**Status**: Architecture researched from headers; formulas need implementation-level research during porting

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

## Porting Considerations

1. **Event chain** - Each step must allow script intervention; port event dispatch first
2. **d20 formulas** - Well-documented in OGL; verify against original source during porting
3. **Bonus stacking** - D&D 3.5e stacking rules (same type don't stack, except dodge); Values.cpp handles this
4. **Attack iteration** - NAttack iterates TMonster's Attk[32] array; each generates separate Strike
5. **Static weapon references** - Creature has static `meleeWep`, `offhandWep`, etc. for current attack context
