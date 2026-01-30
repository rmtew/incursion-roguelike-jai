# Values & CalcValues System

**Source**: `Values.cpp` (2620 lines), plus `Creature.cpp` (Mod/Mod2), `Create.cpp` (SkillLevel, IAttr, CasterLev), `Monster.cpp` (BestHDType), `Tables.cpp` (lookup tables)
**Status**: Fully researched

## Overview

Values.cpp is the d20 rules engine. It computes all derived attribute values from base stats, equipment, status effects, class features, and temporary modifiers. `CalcValues()` is called frequently and is one of the most critical functions for gameplay correctness.

**Key design features:**
- Static `AttrAdj[ATTR_LAST][BONUS_LAST]` (41 x 39) array accumulates all bonuses by type
- Bonus stacking rules prevent same-type bonuses from stacking (with exceptions)
- Percent-based attributes (speed, movement) use multiplicative composition for certain bonus types
- Concentration skill can absorb negative magic casting modifiers
- Recursion guard via `theGame->inCalcVal` counter
- Fatigue changes can trigger a restart loop (up to 10 iterations)

## Architecture

### Static Shared State

```cpp
int8 Creature::AttrAdj[ATTR_LAST][BONUS_LAST];  // 41 x 39 array, zeroed each call
Item *Creature::missileWep, *Creature::thrownWep, *Creature::offhandWep, *Creature::meleeWep;
```

These are **static class members** -- shared across all creatures. Only one CalcValues can run at a time (guarded by `theGame->inCalcVal`).

### Attribute Indices (0-40, ATTR_LAST=41)

```
A_STR(0)  A_DEX(1)  A_CON(2)  A_INT(3)  A_WIS(4)  A_CHA(5)  A_LUC(6)

A_SPD_ARCHERY(7)  A_SPD_BRAWL(8)  A_SPD_MELEE(9)  A_SPD_THROWN(10)  A_SPD_OFFHAND(11)
A_HIT_ARCHERY(12) A_HIT_BRAWL(13) A_HIT_MELEE(14) A_HIT_THROWN(15)  A_HIT_OFFHAND(16)
A_ARM(17)         A_MR(18)
A_DMG_ARCHERY(20) A_DMG_BRAWL(21) A_DMG_MELEE(22) A_DMG_THROWN(23)  A_DMG_OFFHAND(24)
A_SIZ(25)         A_MOV(26)       A_DEF(27)
A_SAV_FORT(28)    A_SAV_REF(29)   A_SAV_WILL(30)
A_ARC(31)         A_DIV(32)       A_PRI(33)        A_BAR(34)         A_SOR(35)
A_THP(36)         A_MAN(37)       A_FAT(38)        A_COV(39)         A_CDEF(40)
```

### Virtual Attribute Aliases (>= 50, not stored)

These are used in AddBonus/StackBonus to fan out to multiple real attributes:
```
A_HIT(50) -> A_HIT_BRAWL, A_HIT_MELEE, A_HIT_OFFHAND, A_HIT_ARCHERY, A_HIT_THROWN
A_AID(51) -> A_HIT_* (all 5) + A_DEF + A_SAV_FORT + A_SAV_REF + A_SAV_WILL + A_ARC + A_DIV + A_SOR + A_PRI + A_BAR
A_SAV(52) -> A_SAV_FORT, A_SAV_REF, A_SAV_WILL
A_DMG(53) -> A_DMG_BRAWL, A_DMG_MELEE, A_DMG_OFFHAND, A_DMG_ARCHERY, A_DMG_THROWN
A_SPD(54) -> A_SPD_BRAWL, A_SPD_MELEE, A_SPD_OFFHAND, A_SPD_ARCHERY, A_SPD_THROWN
A_MAG(55) -> A_ARC, A_DIV, A_SOR, A_PRI, A_BAR
```

### Bonus Type Indices (0-38, BONUS_LAST=39)

```
BONUS_BASE(0)      BONUS_CLASS2(1)    BONUS_CLASS3(2)    BONUS_STUDY(3)
BONUS_ATTR(4)      BONUS_ENHANCE(5)   BONUS_ARTI(6)      BONUS_SACRED(7)
BONUS_MORALE(8)    BONUS_INSIGHT(9)   BONUS_FEAT(10)     BONUS_WEAPON(11)
BONUS_CLASS(12)    BONUS_NEGLEV(13)   BONUS_COMP(14)     BONUS_SIZE(15)
BONUS_DEFLECT(16)  BONUS_DAMAGE(17)   BONUS_RAGE(18)     BONUS_STATUS(19)
BONUS_INHERANT(20) BONUS_GRACE(21)    BONUS_DODGE(22)    BONUS_NATURAL(23)
BONUS_ARMOUR(24)   BONUS_SKILL(25)    BONUS_DUAL(26)     BONUS_FATIGUE(27)
BONUS_TEMP(28)     BONUS_CIRC(29)     BONUS_SHIELD(30)   BONUS_LUCK(31)
BONUS_ENCUM(32)    BONUS_RESIST(33)   BONUS_ELEV(34)     BONUS_TACTIC(35)
BONUS_HUNGER(36)   BONUS_PAIN(37)     BONUS_HIDE(38)
```

## Bonus Stacking Rules

### AddBonus(btype, attr, bonus)

The core stacking function. Uses `WESMAX` macro for non-negative, non-dodge, non-circumstance bonuses:

```cpp
#define WESMAX(attr,bonus) ((attr < 0) ? attr + bonus : max(attr,bonus))
```

**Stacking logic:**
- If `bonus < 0` (penalty) OR `btype == BONUS_DODGE` OR `btype == BONUS_CIRC`: call `StackBonus()` (always stacks/adds)
- Otherwise: take the WESMAX of current and new value. If current is already negative (from a previous penalty), ADD the new bonus. If current is non-negative, take the MAX.

This means:
- **Penalties always stack** (add together)
- **Dodge bonuses always stack** (add together)
- **Circumstance bonuses always stack** (add together)
- **All other positive bonuses**: only the highest of each type applies (with the WESMAX caveat for mixed sign)

### StackBonus(btype, attr, bonus)

Always adds the bonus to `AttrAdj[attr][btype]`. No max-check.

**Special: Concentration absorption** -- Before applying penalties to `A_MAG`, the Concentration skill can absorb them:
```cpp
if (attr == A_MAG && bonus < 0 && concentUsed < concentTotal)
    if (btype != BONUS_TACTIC && btype != BONUS_ARMOUR && btype != BONUS_SHIELD) {
        // absorb up to concentTotal worth of penalties
        concentUsed += (-bonus);  // if fits entirely
        return;                    // penalty fully absorbed
    }
```
`concentTotal = ConcentBuffer() = max(SkillLevel(SK_CONCENT) - 5, 0)`

### Percent Attributes (Speed/Movement)

These attributes are treated as percentage modifiers. The stored internal value represents `(percentage - 100) / 5`, so a stored value of 0 = 100%, stored +2 = 110%, stored -4 = 80%.

```cpp
#define percent_attr(i) (i == A_MOV || i == A_SPD_MELEE ||
   i == A_SPD_ARCHERY || i == A_SPD_THROWN || i == A_SPD_BRAWL ||
   i == A_SPD_OFFHAND || i == A_SPD)
```

For percent attributes, certain bonus types are **multiplicative** rather than additive:

```cpp
#define bonus_is_mult(i,j) (j == BONUS_WEAPON || j == BONUS_ENHANCE ||
                            j == BONUS_SACRED || j == BONUS_WEAPON ||
                            j == BONUS_SKILL || j == BONUS_COMP ||
                            j == BONUS_FEAT || AttrAdj[i][j] < 0)
```

**Composition formula** for multiplicative bonuses:
```cpp
Attr[i] = ((((Attr[i] * 5 + 100) * (AttrAdj[i][j] * 5 + 100)) / 100) - 100) / 5;
```

This converts internal representation to percentages, multiplies, then converts back.

### Magic Resistance (A_MR) -- Special Stacking

MR uses a **diminishing returns** formula instead of normal stacking:

```cpp
// Collect all non-zero MR bonuses, sort descending
qsort(MRVals, MRC, sizeof(int16), compare_int16);
// Apply with diminishing formula
for (j = 0; j != MRC; j++)
    Attr[A_MR] += ((100 - Attr[A_MR]) * MRVals[j]) / 100;
```

Each MR source is applied to the remaining percentage. Two 50% MR sources give 75%, not 100%.

## Creature::CalcValues() Main Flow (lines 236-1546)

### Phase 0: Pre-calculation Setup (lines 236-264)

```cpp
oldSize = Attr[A_SIZ];
oHP = cHP;
cFP -= Attr[A_FAT];  // Remove current fatigue max to recalculate
cHP -= Attr[A_THP];   // Remove current temp HP to recalculate

// Recursion guard
if (theGame->inCalcVal) return;
theGame->inCalcVal++;

Restart:
memset(AttrAdj, 0, sizeof(int8) * BONUS_LAST * ATTR_LAST);
oFP = Attr[A_FAT];
concentUsed = 0;
concentTotal = ConcentBuffer();
```

### Phase 1: Weapon Resolution (lines 268-316)

Determines which weapons are active in each slot:
- `meleeWep` = SL_WEAPON (unless bow or thrown-only)
- `offhandWep` = SL_READY (if weapon, not same as melee unless double weapon)
- `missileWep` = SL_ARCHERY (or SL_WEAPON if bow)
- `thrownWep` = parameter, or melee weapon if IT_THROWABLE

### Phase 2: Base Attributes (lines 318-423)

**For Characters (players):**
1. Set base attributes from `BAttr[0..6]` (BONUS_BASE)
2. If polymorphed: STR/DEX/CON from monster form (BONUS_NATURAL), INT/WIS/CHA keep racial
3. If not polymorphed: apply racial attribute adjustments (BONUS_NATURAL). Value -99 means attribute doesn't exist (set to 0)
4. Per-class BAB: `(TCLASS->AttkVal[mode] * Level[i]) / 100` per combat mode, stacked into BONUS_BASE/CLASS2/CLASS3
5. Per-class attack speed: `max(0, BAB - Level[i]/2)` as BONUS_NATURAL for speed
6. Save base values from class (GoodSave or PoorSave table by level)
7. Defense from class: `Level[i] / TCLASS->DefMod`
8. Study BAB adjustment if GetBAB() exceeds class-granted BAB

**For Monsters:**
1. If magically polymorphed: use mID attributes directly
2. If naturally shapeshifted: use max of tmID and mID attributes
3. Base hit from `TMON(mID)->Hit` applied to all A_HIT_*
4. Base speed from `TMON(mID)->Spd` as BONUS_NATURAL
5. Saves from MonGoodSaves() based on monster types, using GoodSave/PoorSave by ChallengeRating

**Both:**
- Defense: `TMON(mID)->Def` as BONUS_NATURAL
- Size: `TMON(mID)->Size` as BONUS_BASE
- Movement: `TMON(mID)->Mov` as BONUS_BASE
- Natural Armour: `TMON(mID)->Arm` as BONUS_NATURAL
- Iron Skin feat: +5 BONUS_NATURAL to A_ARM
- Base Fatigue: 4 (BONUS_NATURAL)
- Class fatigue: `Level[i] * HitDie / 12` per class (characters) or `CR / 2` (monsters)

### Phase 3: Weapon Skill Bonuses (lines 450-557)

Per combat mode (S_ARCHERY, S_BRAWL, S_MELEE, S_DUAL, S_THROWN):

| Weapon Skill | Hit | Dmg | Spd | Def |
|---|---|---|---|---|
| WS_NOT_PROF | -4 | -- | -10 | -- |
| WS_PROFICIENT | -- | -- | -- | -- |
| WS_FOCUSED | +1 | -- | -- | -- |
| WS_SPECIALIST | +1 | +2 | +2 | -- |
| WS_MASTERY | +2 | +2 | +4 | +2 (if in SL_WEAPON) |
| WS_HIGH_MASTERY | +2 | +3 | +6 | +3 (if in SL_WEAPON) |
| WS_GRAND_MASTERY | +3 | +4 | +10 | +4 (if in SL_WEAPON) |

All use BONUS_SKILL. Defense bonuses use StackBonus (always accumulate).

**Weapon quality bonuses (BONUS_WEAPON):**
- Hit: `TITEM->u.w.Acc + IQ_MITHRIL - IQ_ORCISH`
- Speed: `TITEM->u.w.Spd + IQ_ELVEN * 2`
- Damage: +1 for IQ_ORCISH or IQ_ADAMANT

**Enhancement bonuses (BONUS_ENHANCE, gated by KnownOnly):**
- Hit: `GetPlus() + (WQ_ACCURACY ? 4 : 0)`
- Speed: `GetPlus()`
- Damage: `GetPlus()`

**Metallic weapon penalty:** -16 to A_PRI (primal casting) per metallic weapon in melee/offhand (BONUS_ARMOUR, stacked)

**Alignment weapon penalties** (BONUS_NEGLEV, -2 hit/-2 dmg/-4 spd each):
- WQ_HOLY vs MA_EVIL wielder
- WQ_UNHOLY vs MA_GOOD wielder
- WQ_CHAOTIC vs MA_LAWFUL wielder
- WQ_LAWFUL vs MA_CHAOTIC wielder
- WQ_BALANCE vs wielder with both law/chaos AND good/evil

**Speed weapons (WQ_SPEED):**
- Melee with offhand: +5 BONUS_ENHANCE to A_SPD_MELEE; offhand adds another +5
- Melee without offhand: +10 BONUS_ENHANCE to A_SPD_MELEE
- Missile: +10 BONUS_ENHANCE to A_SPD_ARCHERY

### Phase 4: Status Effect Modifiers (lines 577-690)

| Status | Effect |
|---|---|
| PRONE | -4 hit, -4 def (BONUS_STATUS) |
| CONFUSED | -4 INT, -4 WIS, -15 MAG (BONUS_STATUS) |
| STUNNED/NAUSEA | -6 DEX, -10 SPD, -10 MAG (BONUS_STATUS) |
| DISTRACTED | MAG penalty = HighStatiMag(DISTRACTED) (BONUS_CIRC) |
| SINGING | -2 HIT (BONUS_STATUS) |

**Hunger states:**
| State | Effects |
|---|---|
| BLOATED | -2 SPD |
| HUNGRY | -1 FAT, -1 STR, -1 CON |
| STARVING | -3 MAG, -2 FAT, -2 STR, -2 CON (note: no break after HUNGRY, so stacks) |
| WEAK/FAINTING | -6 MAG, -2 FAT, -4 STR, -4 CON |

### Phase 5: Stati (Status Effect) Iteration (lines 620-690)

Each status type maps to a specific bonus type:

| Stati Type | Bonus Type | Stacking |
|---|---|---|
| ADJUST | BONUS_ENHANCE | AddBonus (max) |
| ADJUST_SAC | BONUS_SACRED | AddBonus |
| ADJUST_INS | BONUS_INSIGHT | AddBonus |
| ADJUST_COMP | BONUS_COMP | AddBonus |
| ADJUST_ART | BONUS_ARTI | AddBonus |
| ADJUST_DEFL | BONUS_DEFLECT | AddBonus |
| ADJUST_DMG | BONUS_DAMAGE or BONUS_NEGLEV | StackBonus |
| ADJUST_INH | BONUS_INHERANT | StackBonus |
| ADJUST_MOR | BONUS_MORALE | AddBonus |
| ADJUST_ARM | BONUS_ARMOUR | AddBonus |
| ADJUST_DODG | BONUS_DODGE | StackBonus |
| ADJUST_CIRC | BONUS_CIRC | StackBonus |
| ADJUST_NAT | BONUS_NATURAL | AddBonus |
| ADJUST_LUCK | BONUS_LUCK | AddBonus |
| ADJUST_RES | BONUS_RESIST | AddBonus |
| ADJUST_PAIN | BONUS_PAIN | AddBonus |
| ADJUST_SIZE | BONUS_SIZE | AddBonus |

**KnownOnly gate:** Each stati iteration uses `KNOWN` macro -- if KnownOnly is true and the source item isn't identified (KN_PLUS), the bonus is skipped.

**Pain reduction:**
```cpp
if (HasSkill(SK_CONCENT))
    n_add = max((SkillLevel(SK_CONCENT) - 8) / 2, 0);
if (HasFeat(FT_PAIN_TOLERANCE))
    n_div = 2;
// For each attr with pain penalty:
AttrAdj[i][BONUS_PAIN] = min(0, AttrAdj[i][BONUS_PAIN] + n_add);
AttrAdj[i][BONUS_PAIN] = AttrAdj[i][BONUS_PAIN] / n_div;
```

### Phase 6: Tactical Modifiers (lines 707-797)

| State | Effects |
|---|---|
| MANIFEST (ghost) | +4 CHA (BONUS_ENHANCE) |
| SPRINTING | +20 MOV, -2 DEF (BONUS_TACTIC) |
| CHARGING | +10 MOV, -2 DEF (BONUS_TACTIC) |
| DEFENSIVE | +4 DEF, -4 MAG, -5 MOV, -4 HIT, -2 DMG (BONUS_TACTIC) |
| HIDING (no FT_SNEAKY) | -10 MOV (BONUS_HIDE) |
| RAGING (large race) | +Val STR, +Val CON, +Val SPD, +Val/2 SAV_WILL (BONUS_RAGE) |
| RAGING (small race) | +Val/2 STR, +Val/2 DEX, +Val CON, +Val SPD, +Val/2 SAV_WILL |
| TUMBLING | +SKL/2 MOV, +SKL/2 DEF, -5 SPD, -5 MAG |
| ELEVATED | +Climb/6+2 DEF, +Climb/6+2 HIT, movement penalty varies |
| MOUNTED | +Ride/6+2 DEF, +Ride/5+1 HIT_MELEE, +Ride/5 DMG_MELEE |

**Tumble save bonus:** If SkillLevel(SK_TUMBLE) > 5: `+(SkillLevel - 3) / 3` to SAV_REF (BONUS_COMP)

**Template modifiers:** Applied via `APPLY_TEMPLATE_MODIFIER` macro which handles MVAL_SET (replace), MVAL_PERCENT (percentage for percent attrs), and additive adjustment.

### Phase 7: Armour & Shield (lines 804-858)

Iterates SL_ARMOUR, SL_READY, SL_WEAPON slots:

**Shields (not while grappling):**
- Coverage: `CovVal(this, KnownOnly)` (BONUS_SHIELD, stacked)
- Defense: `DefVal(this, KnownOnly)` (BONUS_SHIELD, max)
- Armour: `ArmVal(0, KnownOnly)` (BONUS_SHIELD, max)
- Arcane penalty: `PenaltyVal * 2` (BONUS_SHIELD, stacked)
- Metallic: -16 to A_PRI (BONUS_ARMOUR, stacked)
- Not proficient: penalty to SPD, HIT, SAV_REF (BONUS_SHIELD, stacked)
- Movement: `PenaltyVal / 2` (BONUS_SHIELD, max)

**Armour:**
- Coverage: `CovVal(this, KnownOnly)` (BONUS_ARMOUR, stacked)
- Arcane penalty: `PenaltyVal * 2` (BONUS_ARMOUR, stacked)
- Metallic: -16 to A_PRI (BONUS_ARMOUR, stacked)
- Non-light armour: bardic penalty `PenaltyVal * 2` (BONUS_ARMOUR, stacked)
- Not proficient: penalty to SPD, HIT, SAV_REF (BONUS_ARMOUR, stacked)
- Movement: `PenaltyVal` (BONUS_ARMOUR, max)

**Incorporeal creatures:** deflection bonus to DEF = `max(1, Mod2(A_CHA))` (BONUS_CIRC)

### Phase 8: Encumbrance (lines 869-898)

| Level | DEF | MOV | SAV_REF | SPD | FAT |
|---|---|---|---|---|---|
| EN_NONE | -- | -- | -- | -- | -- |
| EN_LIGHT | -- | -2 | -- | -- | -- |
| EN_MODERATE | -1 | -4 | -- | -- | -1 |
| EN_HEAVY | -2 | -6 | -2 | -2 | -2 |
| EN_EXTREME | -4 | -10 | -4 | -5 | -3 |

FT_LOADBEARER: EN_LIGHT/EN_MODERATE -> no penalties; EN_HEAVY/EN_EXTREME -> halved (integer division by 2)

### Phase 9: Feat & Ability Bonuses (lines 900-1248)

**Attribute improvement feats:** FT_IMPROVED_STRENGTH through FT_IMPROVED_LUCK: +1 (BONUS_FEAT)

**Save feats:**
- FT_ATHLETIC: +1 Fort (BONUS_COMP)
- FT_CLEAR_MINDED: +1 Will (BONUS_COMP)
- FT_LIGHTNING_REFLEXES: +3 Ref (BONUS_FEAT)
- FT_GREAT_FORTITUDE: +3 Fort (BONUS_FEAT)
- FT_IRON_WILL: +3 Will (BONUS_FEAT)

**Movement feats:**
- FT_RUN: +4 MOV (BONUS_FEAT)
- SK_ATHLETICS skill: `SkillLevel/2` MOV (BONUS_SKILL), `SkillLevel/3` FAT (BONUS_SKILL)

**Endurance:** +5 FAT (BONUS_FEAT)
**FT_WOODSMAN:** +2 FAT (BONUS_FEAT)
**FT_TALENTED:** +1 MAG (BONUS_FEAT)

**Zen abilities:**
- FT_ZEN_ARCHERY: +Mod(WIS) to HIT_ARCHERY (BONUS_INSIGHT)
- FT_ZEN_DEFENSE: +Mod(WIS) DEF (no armour) or +ceil(Mod(WIS)/2) DEF (light armour) (BONUS_INSIGHT)

**Fatigue state modifiers:**
- Fatigued (cFP < -Attr[A_FAT]): -2 STR/DEX/CHA, -2 MOV/SPD (BONUS_FATIGUE)
- Exhausted (cFP < -2*Attr[A_FAT]): -6 STR/DEX/CHA, -5 MOV/SPD (BONUS_FATIGUE)
- Not applied while raging

### Phase 10: Attribute Pre-calculation (lines 976-998)

The 7 base attributes (STR through LUC) are summed from AttrAdj **early** so they can be used in subsequent calculations:

```cpp
for (i = 0; i != 7; i++) {
    Attr[i] = 0;
    if (AttrAdj[i][BONUS_BASE] == 0)
        ;  // attribute doesn't exist naturally
    else for (j = 0; j != BONUS_LAST; j++)
        Attr[i] += AttrAdj[i][j];
    if (Attr[i] <= 0) Attr[i] = 0;
}
if (Attr[A_FAT] <= 0) Attr[A_FAT] = 1;
```

For KnownOnly, stores into `thisc->KAttr[i]` instead.

### Phase 11: Save Attribute Modifiers (lines 1000-1011)

**FT_ONE_BODY_ONE_SOUL** or CON == 0: uses `max(CON_mod, WIS_mod)` for both Fort and Will.

```cpp
if (HasFeat(FT_ONE_BODY_ONE_SOUL) || Attr[A_CON] == 0) {
    int16 one_mod = max(XMod(A_CON), XMod(A_WIS));
    AddBonus(BONUS_ATTR, A_SAV_FORT, one_mod);
    AddBonus(BONUS_ATTR, A_SAV_WILL, one_mod);
    AddBonus(BONUS_ATTR, A_FAT, (max_IAttr - 11) / 2);
} else {
    AddBonus(BONUS_ATTR, A_SAV_FORT, XMod(A_CON));
    AddBonus(BONUS_ATTR, A_SAV_WILL, XMod(A_WIS));
    AddBonus(BONUS_ATTR, A_FAT, (IAttr(A_CON) - 11) / 2);
}
AddBonus(BONUS_ATTR, A_SAV_REF, XMod(A_DEX));
```

### Phase 12: Combat Attribute Modifiers (lines 1013-1083)

**Attack bonuses from attributes:**
- Archery hit: +DEX mod
- Thrown hit: +DEX mod
- Brawl hit: +STR mod (or max(STR, DEX) with FT_WEAPON_FINESSE)
- Melee hit: +STR mod (or max(STR, DEX) if finesse + finesseable weapon)
- Offhand hit: +STR mod (or max(STR, DEX) if finesse + finesseable weapon)

**Size modifier to Defense and Hit:**
```cpp
StackBonus(BONUS_SIZE, A_DEF, SZ_MEDIUM - Attr[A_SIZ]);
StackBonus(BONUS_SIZE, A_HIT, SZ_MEDIUM - Attr[A_SIZ]);
```
SZ_MEDIUM = 4, so:
| Size | Hit/Def Mod |
|---|---|
| SZ_MINISCULE(1) | +3 |
| SZ_TINY(2) | +2 |
| SZ_SMALL(3) | +1 |
| SZ_MEDIUM(4) | +0 |
| SZ_LARGE(5) | -1 |
| SZ_HUGE(6) | -2 |
| SZ_GARGANTUAN(7) | -3 |
| SZ_COLLOSAL(8) | -4 |

**Damage bonuses from Strength:**
- Brawl: STR mod (or max(0, STR) with FT_WEAPON_FINESSE -- finesse fighters don't take STR penalty to brawl damage)
- Melee two-handed: `max(0, (STR_mod * 3 + 1) / 2)` (1.5x STR, rounded up)
- Melee one-handed: STR mod (but not negative if finesse + finesseable weapon)
- Thrown: `max(0, STR mod)` (no penalty for low STR)
- Archery: STR mod only if weapon `useStrength()`
- Offhand: `(STR_mod + 1) / 2` (0.5x STR). Full STR with FT_POWER_DOUBLE_WEAPON and same weapon as main hand. Full negative STR always applies.

**Defense from DEX:**
- FT_ELEGANT_DEFENSE: `DEX_mod * 2` (BONUS_ATTR)
- Normal: `DEX_mod` (BONUS_ATTR)

**Dodge feat:**
- No medium/heavy armour + light encumbrance: +3 DEF (BONUS_DODGE)
- Otherwise: +1 DEF (BONUS_DODGE)

**Expertise/Parry:**
- FT_EXPERTISE + melee weapon: parry value from weapon (or AbilityLevel(CA_UNARMED_STRIKE)*2 if unarmed)
- FT_DEFENSIVE_SYNERGY: `max(mainhand_parry, offhand_parry) + min(mainhand, offhand)/2`
- Otherwise: `max(mainhand_parry, offhand_parry)`

**Defending weapons:** +GetPlus() to DEF (BONUS_WEAPON, stacked)

### Phase 13: Class Abilities (lines 1126-1248)

**Flurry of Blows:**
- Penalty: `-3 + AbilityLevel(CA_FLURRY_OF_BLOWS)` to hit
- +20 to brawl speed
- Extends to melee/offhand if martial weapon or FT_NON_STANDARD_FLURRY
- Requires no armour and not polymorphed

**Divine Grace:** +CHA mod to all saves (BONUS_GRACE)

**Chaotic creatures:** Morale bonus to Will save based on alignment intensity

**Channeling abilities:**
- FT_DIVINE_MIGHT: +CHA mod (Mod2) to brawl/melee/offhand damage (BONUS_SACRED)
- FT_DIVINE_VIGOR: +2 CON, +CHA mod MOV (BONUS_SACRED)

**Unearthly Luck:** +LUC mod to all saves (BONUS_LUCK)

**CA_INCREASED_MOVE:** +AbilityLevel to MOV (BONUS_CLASS)

**Two-weapon fighting penalties:**
- No FT_AMBIDEXTERITY: -2 offhand hit, -2 offhand speed
- No FT_TWO_WEAPON_STYLE: -2 melee hit, -2 offhand hit
- No FT_TWIN_WEAPON_STYLE + offhand >= mainhand size: -2 melee, -2 offhand
- FT_TWO_WEAPON_TEMPEST: +10 SPD, +10 offhand SPD

**Mounted:** Replaces all MOV bonuses with mount's MOV + Ride/2 + CA_RAPID_RIDING

**Animal companion (not ridden):** +15 MOV (BONUS_CLASS)

**Polymorph restrictions:** While polymorphed, BONUS_ENHANCE/FEAT/INHERANT for STR/DEX/CON are capped at 0 (no positive enhancements to physical stats)

**FT_LION_HEART:** All negative BONUS_MORALE values halved

### Phase 14: Final Attribute Resolution (lines 1250-1322)

For all ATTR_LAST attributes:

1. **Normal attributes:** Sum all `AttrAdj[i][j]` values (excluding multiplicative bonuses for percent attrs)
2. **Percent attributes:** After additive sum, apply multiplicative bonuses sequentially:
   ```cpp
   Attr[i] = ((((Attr[i]*5 + 100) * (AttrAdj[i][j]*5 + 100)) / 100) - 100) / 5;
   ```
3. **Movement halt check:** If any multiplicative MOV modifier <= -20 (i.e., reduces to 0% or below), non-player creatures are halted
4. **Combat Defense (A_CDEF):**
   ```cpp
   A_CDEF = A_DEF - (max(0, weapon_bonus) + max(0, insight_bonus) + max(0, dodge_bonus) + (FT_COMBAT_CASTING ? 2 : 4));
   ```

### Phase 15: Attribute Death Check (lines 1324-1338)

If an attribute naturally exists (BONUS_BASE > 0) and has been reduced to 0 by damage (BONUS_DAMAGE), it's lethal:
```cpp
if (AttrAdj[i][BONUS_BASE] + AttrAdj[i][BONUS_TEMP] > 0)  // naturally > 0
    if (Attr[i] <= 0)
        if (BONUS_BASE + BONUS_TEMP + BONUS_FEAT + BONUS_DAMAGE <= 0)
            AttrDeath |= XBIT(i);  // lethal!
```

Non-lethal zero (fatigue, magic, naturally 0): attribute set to 1 (or 0 if naturally 0).

### Phase 16: Enforce Minimums (lines 1340-1391)

- MOV minimum: `max(min(-15, TMON->Mov), value)` (floor at -15 unless base is even lower)
- SPD minimums: -15 for all combat speeds
- Halted creatures: MOV = -20
- FT_COORDINATED_TACTICS: followers match leader's MOV if leader is faster

### Phase 17: Perception Ranges (lines 1392-1449)

Only computed when `!KnownOnly`:

```
SightRange = max(12, 15 + Mod(A_WIS)*3) + AbilityLevel(CA_SHARP_SENSES)*2
LightRange = light source range (from SL_LIGHT slot)
           + glowing weapon bonus (GetPlus() * 3 for WQ_GLOWING)
           + CA_LOWLIGHT if any light
ShadowRange = LightRange * 2
ScentRange = AbilityLevel(CA_SCENT) + (FT_WILD_SHAPE_SCENT ? 3 : 0)
InfraRange = AbilityLevel(CA_INFRAVISION)
TelepRange = AbilityLevel(CA_TELEPATHY)
TremorRange = AbilityLevel(CA_TREMORSENSE)
BlindRange = AbilityLevel(CA_BLINDSIGHT) + HasFeat(FT_BLINDSIGHT)
```

**BlindRange reductions:**
- Silence field: BlindRange = 0
- Metal helmet: BlindRange / 2
- Weapon in hand: `-(Size - SZ_TINY)` per weapon slot
- Minimum 1 if any blindsight

**FT_ACUTE_SENSES:** All ranges multiplied by 3/2

**Blind creatures:** SightRange, ShadowRange, InfraRange = 0

**Non-player creatures** with no special senses: InfraRange = max(6, InfraRange) (so they can function in dark dungeons)

### Phase 18: Fatigue Restart Loop (lines 1451-1457)

```cpp
if (Attr[A_FAT] != oFP) {
    if (restart_count++ < 10)
        goto Restart;
    Attr[A_FAT] = min(Attr[A_FAT], oFP);
}
```

If fatigue pool changed (because CON changed, which affects fatigue), restart the entire calculation. Limit 10 iterations. This handles recursive dependencies like: CON modifier affects fatigue, fatigue state affects STR/DEX, which might affect encumbrance, which affects fatigue...

### Phase 19: Post-calculation Fixup (lines 1459-1546)

1. Restore current FP/HP: `cFP += Attr[A_FAT]; cHP += Attr[A_THP]`
2. Temp HP logic: gaining temp HP increases current HP, losing only caps to new max
3. Update image and map
4. Size change effects: drop too-large weapons, adjust mount compatibility, update size field radius

## Character::CalcValues() (lines 1558-1739)

The Character version wraps Creature::CalcValues and adds:

1. **Calls both KnownOnly modes:** Always calculates both true and known values, with the requested mode calculated last (so AttrAdj retains those values)
2. **Hit point calculation** (detailed below)
3. **Mana calculation** (detailed below)
4. **Bonus spell slots**
5. **Skill point calculation**

## Hit Point Calculation

### Character HP (Character::CalcValues, lines 1582-1649)

**HP attribute for CON bonus:** A_CON normally, but A_WIS if FT_ONE_BODY_ONE_SOUL and WIS mod > CON mod.

```
Base mHP = 20
```

**Non-polymorphed:**
```
Total character level = Level[0] + Level[1] + Level[2]
Template-adjusted HD = TTEM->HitDice.Adjust(totalLevel) - totalLevel  (extra HD from templates)

If BestHDType > 8 (exceptional HD die):
    If max HP option: mHP += level * max(1, CON_mod + HDType)
    Else: mHP += level * max(1, CON_mod + HDType/2)
Else:
    For each class, for each level:
        mHP += max(1, CON_mod + hpRolls[class][level])  // stored rolls

Template bonus HD (if any):
    If max HP: templateHD * max(1, CON_mod + HDType)
    Else: templateHD * max(1, CON_mod + HDType/2)
```

**Polymorphed:**
```
numHD = TMON(mID)->HitDice, adjusted by templates
If max HP: mHP += numHD * max(1, CON_mod + HDType)
Else: mHP += numHD * max(1, CON_mod + HDType/2)
```

**Bonuses:**
- CA_TOUGH_AS_HELL: `+AbilityLevel * max(0, CON_mod)`
- FT_TOUGHNESS: `+mHP / 4` (25% bonus)

**Size HP multiplier (unless M_NO_SIZE_HP):**

| Size | Multiplier |
|---|---|
| SZ_MINISCULE | x0.50 |
| SZ_TINY | x0.70 |
| SZ_SMALL | x0.90 |
| SZ_MEDIUM | x1.00 |
| SZ_LARGE | x1.10 |
| SZ_HUGE | x1.30 |
| SZ_GARGANTUAN | x1.60 |
| SZ_COLLOSAL | x2.00 |

### Monster HP (Creature::CalcHP, lines 1974-2057)

```
HDType = BestHDType()  // best die type from monster types + templates (mod 100)
HD = TMON(mID)->HitDice, adjusted by templates

Monster max HP option:
  case 1: mHP = HD * HDType / 2
  case 2: mHP = HD * HDType       (max)
  case 3: mHP = HD * HDType * 2   (double max)
  default: mHP = Dice::Roll(HD, HDType)

CON bonus: mHP = max(mHP/2, mHP + HD * Mod(a_hp))
```
Same Toughness, size multiplier as characters. Minimum 1 HP.

**Summoned creature bonus:** `+mHP * (summoner_knowledge_skill * 5) / 100`
**HEROIC_QUALITY:** +20 HP flat

### Monster HD Types (MonHDType)

| Monster Type | Hit Die |
|---|---|
| Demon, Devil, Celestial | d20 |
| Lich | d16 |
| Construct, Dragon, Vampire, Wraith, Revenant, Zombie | d12 |
| Beast, Elemental, Ooze/Pudding/Jelly | d10 |
| Default (humanoid, etc.) | d8 |
| Faerie, Fungi, Goblin, Yuan-Ti, Elementalkin | d6 |
| Kobold | d4 |
| MA_FORCE_D4/D6/D8/D10/D12 | 104/106/108/110/112 (100+die, special) |

## Save Calculations

### Character Saves

Per class (up to 3 classes), save base = GoodSave[Level] or PoorSave[Level]:

```
Good/Poor determined by class flags: CF_GOOD_FORT, CF_GOOD_REF, CF_GOOD_WILL
```

**GoodSave table** (by level):
```
Lv:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
    +2 +3 +3 +4 +4 +5 +5 +6 +6 +7 +7 +8 +8 +9 +9 +10 +10 +11 +11 +12
```
Pattern: `floor(level/2) + 2`

**PoorSave table** (by level):
```
Lv:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
     0  0 +1 +1 +1 +2 +2 +2 +3 +3 +3 +4 +4 +4 +5 +5 +5 +6 +6 +6
```
Pattern: `floor(level/3)`

Multi-class: saves from each class are stacked (StackBonus using BONUS_BASE/CLASS2/CLASS3).

Attribute modifier added via BONUS_ATTR (Phase 11 above).

### Monster Saves

Good/Poor determined by `MonGoodSaves(MType)` -- OR of all 3 monster types:

| Types | Good Saves |
|---|---|
| Outsider, Demon, Devil, Dragon, Genie | Fort + Ref + Will |
| Beast, Mimic | Fort + Ref |
| Illithid, Eye, Undead | Will |
| Humanoid, Naga | Ref + Will |
| Plant, Animal, Worm, Quadruped, Elemental | Fort |
| Goblin, Kobold, Spider, Snake, Trapper, Vortex, Faerie, Bird | Ref |
| Fungi, default | None |

Uses `ChallengeRating()` instead of level for the GoodSave/PoorSave table index.

## Speed/Movement Calculation

Movement (A_MOV) and combat speeds (A_SPD_*) are **percent attributes**. Internal value represents `(percentage - 100) / 5`.

Example: stored value 0 = 100% speed, +4 = 120% speed, -4 = 80% speed.

**Base speed sources:**
- Characters: `TMON(mID)->Mov` (base racial speed) as BONUS_BASE
- Monsters: same

**Combat speed base:**
- Characters: `max(0, BAB_for_class - Level/2)` per class as BONUS_NATURAL
- Monsters: `TMON(mID)->Spd` as BONUS_NATURAL

**Modifiers** affect these as either additive (add to internal value before conversion) or multiplicative (applied as percentage multiplier after additive sum).

## Skill Value Computation (Creature::SkillLevel)

From `Create.cpp` lines 3638-3854:

```
Total = ranks + ability_mod + feat + enhance + domain + racial + item + insight
      + synergy + comp + circ + inherent + size + armour_penalty + training + kit + focus

ability_mod = Mod2(SkillAttr(sk))  // Mod2 = (Attr - 11) / 2, slightly lower than Mod
```

**Rank sources:**
- Characters: `SkillRanks[sk]` (direct investment)
- Monsters with skill: `max(1, ChallengeRating()) + 3`
- Spot/Listen without skill: `ChallengeRating() / 2`

**Training bonus:** +1 per source that grants the skill (race, each class), then +2 if any source grants it. So a class skill gives +3 total.

**Feat bonuses (FEAT_SKILL_BONUS = +3):** Various feat-to-skill mappings (FT_ALERTNESS -> Spot/Listen, etc.)

**Synergy system:** Defined in Synergies table (pairs of skills with divisor):
```
bonus = related_skill_ranks / divisor
```
Example: Diplomacy benefits from Appraise at rate ranks/3.

**Size modifier to Hide:** `(SZ_MEDIUM - Attr[A_SIZ]) * 4`

**Armour penalty:** `SkillInfo[sk].armour_penalty * PenaltyVal` for each armour/shield piece

## Resistance System (Creature::ResistLevel)

Lines 1745-1886:

### Sources of Resistance

1. **Innate (TMonster):** `Res` and `Imm` bitmasks, modified by templates (+AddRes, -SubRes, +AddImm, -SubImm)
2. **Stati (RESIST):** Per-source max stacking (16 sources tracked)
3. **Feats:** FT_DIVINE_ARMOUR (necro/alignment types, Mod(CHA)*2), FT_DIVINE_RESISTANCE (fire/cold/elec, Mod(CHA)), FT_HARDINESS (poison/disease, flat 5)
4. **Natural armour (A_ARM):** For weapon damage types (slash/pierce/blunt), if not bypassed
5. **Worn armour:** `ArmVal(DType - AD_SLASH)` for weapon damage types

### Immunity

Returns -1 for:
- Illusions vs. mind/physical/stone/stun/conf/vamp/holy/evil/lawful/chaotic/poison/disease/sleep/fear
- HasStati(IMMUNITY, DType)
- Imm bitmask bit set (DType < 32)
- Raging level >= 7: immune to confusion
- Raging level >= 13: immune to stun

### Damage Type Substitution
- AD_POIS -> AD_TOXI
- AD_DREX -> AD_NECR

### Resistance Stacking Formula

Multiple resistance values are combined with diminishing returns:
```
1. Sort all resistance values descending
2. Highest value: add 100%
3. Second highest: add 50%
4. All remaining: add 33% each
```

```cpp
total = highestValue;
total += secondHighest / 2;
for remaining: total += Resists[i] / 3;
```

### Innate Resistance Value
```
base = 7 + (ChallengeRating * 2) / 3
+ AbilityLevel(CA_BOOST_RESISTS)
```

## Caster Level and Spell DC

### Character Caster Level (Create.cpp line 3629)

```cpp
int16 ab = AbilityLevel(CA_SPELLCASTING);
if (HasStati(BONUS_SLOTS)) ab = max(ab, 1);  // hack for 1st level bards
return ab;
```

### Casting Attribute Bonuses

CalcValues applies modifiers to A_ARC (arcane), A_DIV (divine), A_PRI (primal), A_BAR (bardic), A_SOR (sorcery) through the A_MAG virtual alias. Major penalties:

- Metallic weapons/shields/armour: -16 per piece to A_PRI (stacked)
- Non-light armour: penalty*2 to bardic casting
- Shield: penalty*2 to arcane casting
- Armour: penalty*2 to arcane casting
- Confusion: -15 MAG
- Stunned/Nausea: -10 MAG
- Defensive stance: -4 MAG
- Tumbling: -5 MAG
- Hunger effects: -3 to -6 MAG

### Bonus Spell Slots

```cpp
intScaled = min(max(IAttr(A_INT) - 9, 0), 21)  // 0-21 range
BonusSlots[0] = BonusSpells[intScaled][0]  // all bonus 1st-level slots
for (i = 1; i < 9; i++)
    BonusSlots[i] = min(BonusSpells[intScaled][i],
                        max(SpellSlots[i], CasterLev() - SAL(i+1)))
```

SAL (Spell Access Level) table: `{0, 1, 3, 5, 7, 9, 12, 14, 16, 18}`

## Mana Calculation

### Character Mana (Character::CalcValues, lines 1662-1678)

```
mMana = sum of manaRolls[class][level] for all classes
mMana *= ManaMultiplier[TotalLevel()]
mMana += 10
mMana += Mod(a_mana) * TotalLevel()
mMana += AbilityLevel(CA_MAGICAL_NATURE)
```

Where `a_mana` is A_WIS normally, or A_CON if ONE_BODY_ONE_SOUL and CON mod > WIS mod.

**ManaMultiplier table** (by total level):
```
Lv:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
     1  1  2  2  3  3  3  4  4  4  4  5  5  5  5  5  6  6  6  6  6  6  7  7  7  7  7  7  7  8  8  8
```

### Monster Mana (Creature::CalcHP)

```
mMana = TMON(mID)->Mana + AbilityLevel(CA_MAGICAL_NATURE) + GetAttr(A_MAN)*5
manaDie = HasAttk(A_CAST) || HasAbility(CA_SPELLCASTING) ? 12 : 4
effectiveManaLevel = max(ChallengeRating(), AbilityLevel(CA_SPELLCASTING))

for (i = 0; i < effectiveManaLevel; i++)
    mMana += ManaMultiplier[i] * Roll(1, manaDie)
```

## Skill Point Calculation (Character::CalcSP)

```cpp
for (i = 0; i != 3; i++) {
    if (tc->SkillPoints >= 8)
        TotalSP[i] = max(1, SkillPoints + ((IAttr(A_INT)-10)/2)*2);
    else
        TotalSP[i] = max(1, SkillPoints + ((IAttr(A_INT)-10)/2));
    TotalSP[i] *= Level[i];
    TotalSP[i] += BonusSP[i];
}
```

High-skill classes (8+ base) get double INT modifier. Minimum 1 SP per level.

## IAttr (Inherent/Intrinsic Attribute)

For characters (Create.cpp line 3622):
```cpp
return BAttr[a] + (RaceID ? TRACE(RaceID)->AttrAdj[a] : 0) +
    HasFeat(FT_IMPROVED_STRENGTH+a) +
    SumStatiMag(ADJUST_INH, a);
```

This is base + racial + improvement feat + inherent bonuses. Used for HP/mana calculations where only permanent bonuses should count.

## Modifier Functions

### Mod(a) -- Standard Modifier
```cpp
res = Attr[a] ? (Attr[a] - 10) / 2 : 0;  // 0 if attr is 0
if (a == A_DEX && wearing armour)
    res = min(res, armour_MaxDexBonus);
```

### Mod2(a) -- Conservative Modifier
```cpp
res = Attr[a] ? (Attr[a] - 11) / 2 : 0;  // slightly lower than Mod
// Same DEX/armour cap
```

Mod2 rounds less favorably: Attr 12 gives Mod=+1 but Mod2=+0.

### KMod/KMod2 (Character only)
Same formulas but use `KAttr[a]` (known values) instead of `Attr[a]`.

### XMod/XMod2 (CalcValues-local)
```cpp
#define XMod(a)  (KnownOnly ? KMod(a) : Mod(a))
#define XMod2(a) (KnownOnly ? KMod2(a) : Mod2(a))
```

## KnownOnly Parameter

When `KnownOnly = true`:

1. **Character::CalcValues** always calls both modes. The requested mode is called **last** so AttrAdj retains those values for the BonusBreakdown display.
2. **Equipment bonuses gated by KN_PLUS:** Enhancement bonuses from unidentified items are skipped via the `KNOWN` macro:
   ```cpp
   #define KNOWN \
       if (KnownOnly && S->h && oThing(S->h)->isItem() && !oItem(S->h)->isKnown(KN_PLUS)) continue
   ```
3. **Attribute storage:** KnownOnly writes to `KAttr[]` instead of `Attr[]`
4. **XMod/XMod2 switching:** Attribute-dependent bonuses use KMod (known modifier) instead of Mod

## Item-Specific CalcValues

Weapon and armour stats are **not** computed in CalcValues directly. Instead, CalcValues reads pre-computed values from items:

- `TITEM(iID)->u.w.Acc` -- weapon accuracy
- `TITEM(iID)->u.w.Spd` -- weapon speed
- `TITEM(iID)->u.w.SDmg` / `LDmg` -- small/large damage dice
- `it->GetPlus()` -- enhancement bonus
- `it->CovVal(this, KnownOnly)` -- armour/shield coverage
- `it->DefVal(this, KnownOnly)` -- shield defense value
- `it->ArmVal(DType, KnownOnly)` -- armour resistance value
- `((Armour*)it)->PenaltyVal(this, true)` -- armour/shield check penalty
- `((Armour*)it)->MaxDexBonus(this)` -- max DEX bonus from armour
- `it->ParryVal(this)` -- parry value for expertise
- `it->HasQuality(...)` -- quality flags (WQ_SPEED, WQ_DEFENDING, IQ_MITHRIL, etc.)

## GetBAB Functions

### Creature::GetBAB(mode)
```cpp
BAB = TMON(tmID)->Hit;
// Adjusted by all templates
```

### Character::GetBAB(mode)
```cpp
BAB = 0;
warriorLevels = 0;
for each class:
    BAB += (TCLASS->AttkVal[mode] * Level[i]) / 100;
    if (AttkVal[mode] >= 100) warriorLevels += Level[i];
// Study bonus (capped at TotalLevel)
sBAB = min(TotalLevel(), BAB + min(warriorLevels, IntStudy[STUDY_BAB]));
return max(BAB, sBAB);
```

## FaceRadius (Size -> Map Radius)

```
SZ_MINISCULE(1) -> 0
SZ_TINY(2)      -> 0
SZ_SMALL(3)     -> 0
SZ_MEDIUM(4)    -> 0
SZ_LARGE(5)     -> 0
SZ_HUGE(6)      -> 1
SZ_GARGANTUAN(7)-> 2
SZ_COLLOSAL(8)  -> 3
```

## InherentCreatureReach

```cpp
if (HasMFlag(M_REACH)) return true;
if (Attr[A_SIZ] >= SZ_LARGE && HasMFlag(M_HUMANOID)) return true;
if (Attr[A_SIZ] >= SZ_HUGE) return true;
return false;
```

## Known Bugs and Design Notes

1. **Penalty stacking from same source:** Penalties from two instances of the same effect stack unintentionally because eID is not stored in AttrAdj. This caused issues with multiple slow traps making PCs unable to move.

2. **WESMAX ordering dependency:** The order spells are cast can affect final values when mixing positive and negative bonuses of the same type. Example: Spell1 (+3 STR, -3 DEX) and Spell2 (-3 STR, +3 DEX) give different results depending on cast order.

3. **Static AttrAdj:** The AttrAdj array is static (shared), meaning only one creature can calculate at a time. The `inCalcVal` guard prevents recursion but also means any function called during CalcValues that tries to calc another creature will fail silently.

4. **Fatigue restart loop:** The fatigue-dependent restart can iterate up to 10 times. If it doesn't converge, fatigue is clamped to the previous value.

5. **A_SPD_BRAWL speed calculation:** Uses `AttrAdj[A_HIT_ARCHERY][BONUS_BASE+i]` for all modes (appears to be a bug -- should likely use each mode's own BAB, but consistently uses archery BAB for speed calculation).

## Porting Considerations

1. **CalcValues is critical** -- Must be ported accurately for game balance
2. **Bonus stacking** -- 39 types with specific stacking rules; core correctness requirement
3. **Attribute derivation** -- All 41 attributes must be computed correctly
4. **Performance** -- Called frequently; in Jai, the static AttrAdj array should be a thread-local or context parameter
5. **KnownOnly mode** -- Two computation paths (full vs. player-known); Character version calls both
6. **Percent attributes** -- Multiplicative composition formula must be exact
7. **MR diminishing returns** -- Special stacking different from all other attributes
8. **Static weapon pointers** -- Must be handled carefully in Jai (probably context struct members)
9. **Fatigue restart loop** -- Preserve the goto-based restart mechanism (or refactor to while loop)
10. **Phase ordering** -- The order of bonus application matters due to early attribute pre-calculation at Phase 10
