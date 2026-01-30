# Magic, Effects, and Prayer System Specification

Extracted from `Magic.cpp`, `Effects.cpp`, and `Prayer.cpp` in the original Incursion source.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Spellcasting Flow (Creature::Cast)](#spellcasting-flow)
3. [Spell Rating / Success Chance](#spell-rating)
4. [Spell Save DC](#spell-save-dc)
5. [Mana Cost and Recovery](#mana-cost)
6. [Metamagic System](#metamagic)
7. [Spell Resistance](#spell-resistance)
8. [Counterspelling](#counterspelling)
9. [Effect Calculation (CalcEffect)](#effect-calculation)
10. [Duration Calculation](#duration-calculation)
11. [Area-of-Effect Archetypes](#area-of-effect-archetypes)
12. [Effect Archetypes (EA_*)](#effect-archetypes)
13. [Item-Based Magic](#item-based-magic)
14. [Divine Magic / Prayer System](#divine-magic)
15. [Favour and Sacrifice](#favour-and-sacrifice)
16. [Transgression System](#transgression-system)
17. [Divine Intervention](#divine-intervention)
18. [Constants and Formulas Summary](#constants-summary)

---

## Architecture Overview

The magic system uses an event-driven architecture with three layers:

1. **Magic.cpp** - Core spell execution: casting, targeting, area-of-effect projection, spell rating, mana costs, counterspelling, and item-based magic (potions, scrolls, wands).
2. **Effects.cpp** - Specific effect archetype implementations: Blast, Grant, Inflict, Healing, Summon, Polymorph, Terraform, Travel, Dispel, Reveal, Illusion, Creation.
3. **Prayer.cpp** - Divine system: prayer mechanics, sacrifice, favour calculation, transgression/anger, divine intervention (aid, deflect, resurrect), altar conversion, god messaging.

### Event Flow

```
Creature::Cast (or Invoke, DrinkPotion, ReadScroll, ZapWand)
  -> EV_EFFECT
    -> Magic::MagicEvent (iterates over effect segments)
      -> Magic::CalcEffect (compute caster level, save DC, damage, duration)
      -> Area dispatch: ABallBeamBolt, AField, AGlobe, ABarrier, ATouch, or AR_NONE
        -> EV_MAGIC_STRIKE (per target)
          -> Magic::MagicStrike (spell resistance, saving throws, illusion disbelief)
            -> EV_MAGIC_HIT
              -> Magic::MagicHit (dispatches to specific archetype)
                -> Blast, Grant, Inflict, Healing, Summon, etc.
```

### EffectValues Structure

Each TEffect has one or more EffectValues segments (accessed via `TEffect::Vals(n)`):
- `eval` - Effect archetype (EA_BLAST, EA_GRANT, EA_INFLICT, etc.)
- `aval` - Area archetype (AR_BOLT, AR_BEAM, AR_BALL, AR_BURST, AR_FIELD, etc.)
- `xval` - Primary parameter (damage type for blasts, stati type for grant/inflict)
- `yval` - Secondary parameter
- `sval` - Save type (REF, FORT, WILL, NOSAVE)
- `pval` - Dice for damage/magnitude (supports level adjustment)
- `lval` - Range/radius dice
- `cval` - Colour value for visual effects
- `tval` - Target limiter (monster type, item type, level)
- `rval` - Resource ID (for summons, terraform terrain, etc.)
- `qval` - Targeting qualifiers (Q_LOC, Q_TAR, Q_EQU, etc.)

---

## Spellcasting Flow

### Creature::Cast(EventInfo &e)

**Pre-checks (abort conditions):**
- Elf casting necromancy (SC_NEC without SC_ABJ): blocked
- Paralyzed without both MM_STILL and MM_VOCALIZE: blocked
- Polymorphed with M_NOHANDS without MM_STILL: blocked
- Already-active persistent/permanent effect on target: blocked
- Raging, sprinting, tumbling, charging, enraged: blocked (staff spells exempt)
- In field of silence without MM_VOCALIZE: blocked

**Component requirements:**
- SP_PRIMAL, SP_BARDIC, SP_STAFF, SP_SORCERY: no component needed
- SP_DIVINE/SP_DOMAIN: requires holy symbol in ready/weapon/amulet/armour slot (or graven armour)
- SP_ARCANE: requires spellbook containing the spell in inventory
  - Damaged spellbook: Decipher check DC = 10 + (bookHP%/10), failure causes dmgFail
  - LUCUBRATION stati: bypasses spellbook requirement if spell level <= lucubration level
- SP_INNATE/SP_STAFF: returns 100 (auto-success), delegates to Invoke for innate

**Two-weapon casting penalty:**
- Wielding weapon + ready item (different items): need hand free for somatic components
- Without Quick Draw feat and without MM_STILL: extra timeout = 3000 / (100 + 10*Mod(DEX))

**Casting timeout formula:**
```
castingTimeout = 3000 / max(25, 100 + 10*(1 + Mod(A_INT) - TEFF(eID)->Level))
```
- MM_QUICKEN: halves timeout
- Combat Casting feat: halves timeout on spell failure
- Polymorphed without MM_STILL: +15
- Elevated on ceiling: +15
- Mounted without MM_STILL (balance < 20): +15

**Staff spell fatigue:**
- Staff spells not also known as regular spells cost fatigue via `GetStaffFatigueCost()`

**Metamagic fatigue:**
- If metamagic active and SK_METAMAGIC skill exists:
  - Base fatigue cost = MMFeatLevels(MM)
  - Skill check DC 10 on SK_METAMAGIC, then: `fc -= 1 + (sc / 5)` (min 0)
  - Remaining fatigue cost charged

**Bard Spellbreak interaction:**
- Bard singing BARD_SPELLBREAK within range (SkillLevel(SK_PERFORM) + 2):
  - Caster makes SK_CONCENT check vs bard's SK_PERFORM check
  - If caster loses, WILL save DC 10 + bardic_music_level/2 + Mod(CHA)
  - Failure: spell fails; critical failure: CONFUSED for 2d4 rounds

**Mana check:**
- If cMana < mCost: "You don't have enough mana."
  - If cMana >= mCost/2: player can attempt anyway, success if random(25)+80 <= SpellRating
  - On forced cast failure: goto SpellFails

**Spell success/failure:**
- Roll = random(100) + 1
- If oHP > cHP (took damage during casting, from AoO etc.):
  - `dmg_pen = ((oHP-cHP)*300) / (mHP+GetAttr(A_THP))`
  - Reduced by concentration buffer: `dmg_pen = max(0, dmg_pen - (ConcentBuffer()-concentUsed-p_conc)*5)`
  - Rating reduced by dmg_pen
- If roll > rating: spell fails
  - 1/20 chance of incomplete spell draining 1 fatigue
  - If failure was due to damage specifically (roll <= rating+dmg_pen): "spell disrupted"

**Provoke AoO:**
- Unless MM_DEFENSIVE or EF_DEFENSIVE flag, casting provokes Attack of Opportunity

**Invisibility break:**
- Casting offensive/curse/summon spells or spells not targeting friendly creatures breaks INVIS (unless INV_IMPROVED)

---

## Spell Rating

### Creature::SpellRating (monsters)

```
Chance = BaseChance + Mod(A_INT)*5 + CasterLev()*3
       - MMFeatLevels(mm)*10
       + max(A_ARC, A_DIV)*5   (if theurgy/druidic source)
       + A_ARC*5               (otherwise)

if Chance > 90: Chance = 90 + (Chance-90)/10
if Chance > 50 and MM_SURE: return 100
return clamp(2, 98, Chance)
```

### Character::SpellRating (player/NPCs)

```
Chance = p_base + p_int + p_lev + p_meta + p_spec + p_calc + p_circ + p_conc

where:
  p_base = te->BaseChance              (from effect definition)
  p_int  = Mod2(A_INT) * 5
  p_lev  = (CasterLev() - SAL(te->Level)) * 2
  p_meta = -MMFeatLevels(mm) * 5
  p_spec = specialist school modifier (from SpecialistTable[school][spell_school])
           (max of all spell schools; non-arcane sources clamp negative to 0)
  p_calc = best of: A_DIV*5 (divine), A_BAR*5 (bardic), A_PRI*5 (primal),
                     A_SOR*5 (sorcery), A_ARC*5 (arcane)
  p_circ = circumstance penalties (unless MM_STILL):
           -60 grappled/stuck
           -20 prone
           -40 deep liquid terrain
           -40 sticky terrain
           -max(0, 40 - SkillLevel(SK_RIDE)*2) mounted + threatened
  p_conc = min(abs(p_circ), ConcentBuffer()*5)  -- concentration buffer offsets

if Chance > max(90, p_base): Chance = max(90,p_base) + (Chance-max(90,p_base))/5
if Chance > 50 and MM_SURE: return 100
return clamp(2, 100, Chance)
```

Special cases:
- SP_INNATE or SP_STAFF: returns 100 (auto-success)
- Elf + necromancy: returns -1 (cannot cast)
- No BaseChance (Turn Undead etc.): returns 99

---

## Spell Save DC

### Creature::getSpellDC

```
DC = dc_base + dc_lev + dc_attr + dc_focus + dc_will + dc_beguile + dc_trick + dc_hard + dc_height + dc_affinity

where:
  dc_base  = 10
  dc_lev   = TEFF(spID)->Level
  dc_attr  = best of:
             Mod(A_INT) for SP_ARCANE
             Mod(A_WIS) for SP_DIVINE/SP_PRIMAL/SP_DOMAIN
             Mod(A_CHA) for SP_SORCERY/SP_BARDIC/SP_INNATE
  dc_focus = 2 if caster has SCHOOL_FOCUS matching spell schools
             +4 if SP_DOMAIN and FT_DOMAIN_MASTERY
             +2 if SP_DOMAIN and FT_DOMAIN_FOCUS
  dc_will  = AbilityLevel(CA_ARCANE_WILL)
  dc_beguile = max(0, Mod(A_CHA)) if CA_BEGUILING_MAGIC and EF_MENTAL
  dc_trick = 8 if arcane trickery
  dc_hard  = 2/4/8 from EF_HARDSAVE2/4/8 flags
  dc_height = 4 if MM_HEIGHTEN
  dc_affinity = 2 if lizardfolk+water or dwarf+earth school
```

### Item save DC:
```
DC = 10 + (GetPlus() * 2) + caster Mod(A_WIS) + hard save bonuses
```

### Trap/no-actor save DC:
```
DC = 10 + te->Level
```

### Special ability save DC:
```
DC = 10 + ChallengeRating() + Mod(A_CHA)
```

---

## Mana Cost

### Creature::getSpellMana

```
base mCost = TEFF(spID)->ManaCost

With metamagic:
  mult = 2 + MMFeatLevels(MM)
  mCost = (mCost * mult + 1) / 2
  mCost = max(mCost, ManaCost + 3*(mult-2))

Specialist school modifier:
  If spell is in opposition school (specMod < 0):
    mCost += (mCost * abs(specMod)) / 10
  If spell is in specialty school (specMod > 0):
    mCost = max(1, mCost - (mCost * abs(specMod)) / 50)
  Divine/bardic/primal/sorcery: negative specMod clamped to 0

Buff cost reduction:
  CA_PREPATORY_MAGIC: mCost = max((mCost * (100 - level*5)) / 100, 1)
  FT_MYSTIC_PREPARATION: mCost = max(mCost - 2, 1)

Racial affinity:
  Lizardfolk + water school, or Dwarf + earth school: mCost = (mCost+1)/2

Innate spell cost for monsters:
  Full ManaCost (changed from 1/3 for balance)
```

---

## Metamagic

### Available Metamagics (MM_* flags)

| Flag | Feat | Effect |
|------|------|--------|
| MM_AMPLIFY | FT_AMPLIFY_SPELL | Reduces target MR by 25% |
| MM_AUGMENT | FT_AUGMENT_SUMMONING | Summoned creatures get +4 STR/CON, +THP |
| MM_ANCHOR | FT_ANCHOR_SPELL | Duration * 2 (if duration > 1) |
| MM_BIND | FT_BIND_SPELL | Caster excluded from targeting |
| MM_CONSECRATE | FT_CONSECRATE_SPELL | Half damage as AD_HOLY |
| MM_CONTROL | FT_CONTROL_SPELL | Choose from N candidates (3+Mod(INT)) |
| MM_DEFENSIVE | FT_DEFENSIVE_SPELL | No AoO provocation |
| MM_EMPOWER | FT_EMPOWER_SPELL | Damage * 150% |
| MM_ENLARGE | FT_ENLARGE_SPELL | Radius * 2 |
| MM_FOCUS | FT_FOCUS_SPELL | Radius / 2 |
| MM_FORTIFY | FT_FORTIFY_SPELL | Caster level + 5 for dispel/penetration |
| MM_HEIGHTEN | FT_HEIGHTEN_SPELL | Level-limited effects use CL*2; save DC + 4 |
| MM_INHERANT | FT_INHERANT_SPELL | Skip component requirements |
| MM_JUDICIOUS | FT_JUDICIOUS_SPELL | Only targets hostile creatures |
| MM_MAXIMIZE | FT_MAXIMIZE_SPELL | Maximum damage (Number * Sides + Bonus) |
| MM_EXTEND | FT_EXTEND_SPELL | Duration * 2 (if >= 1); Range * 2 |
| MM_PROJECT | FT_PROJECT_SPELL | Converts to beam-like projection |
| MM_QUICKEN | FT_QUICKEN_SPELL | Casting timeout / 2 |
| MM_REPEAT | FT_REPEAT_SPELL | (implementation unclear from source) |
| MM_STILL | FT_STILL_SPELL | No somatic components needed |
| MM_SURE | FT_SURE_SPELL | If base rating > 50, auto-success |
| MM_TRANSMUTE | FT_TRANSMUTE_SPELL | Change elemental damage type |
| MM_UNSEEN | FT_UNSEEN_SPELL | (implementation unclear from source) |
| MM_VILE | FT_VILE_SPELL | (implementation unclear from source) |
| MM_VOCALIZE | FT_VOCALIZE_SPELL | No verbal components needed |
| MM_WARP | FT_WARP_SPELL | Projectiles pass through walls (max(2, 3+Mod(INT)) times) |

---

## Spell Resistance

In `Magic::MagicStrike`:

```
Conditions: target is creature, spell is not psionic, not EF_MUNDANE, target is hostile
victim_mr = GetAttr(A_MR)

if victim_mr > 0:
  victim_mr_final = FT_AMPLIFY_SPELL ? (victim_mr * 75) / 100 : victim_mr
  roll = random(100) + 1
  actor_side = roll + ChallengeRating()*2 + (FT_SPELL_PENETRATION ? 20 : 0)
  victim_side = victim_mr_final + victim_ChallengeRating()*2
  bypass = actor_side > victim_side

  if !bypass: e.MagicRes = true (spell is resisted)
```

---

## Counterspelling

### Creature::Counterspell

**Detection:** Other creatures that perceive the caster and have SK_SPELLCRAFT make a check vs DC 10 + spell level. Success identifies the spell being cast.

**Counter selection priority:**
1. Known spell of same school and >= level of target spell (cheapest mana cost preferred)
2. Dispel Magic as fallback (harder DC: +5)

**Spellcraft DC to counterspell:** Check > 15 + spell_level (+ 5 if using dispel)

**Mana cost reduction by Spellcraft level:**
- >= 25: cost / 3
- >= 20: cost / 2
- >= 15: cost * 2/3

**AI behavior (option OPT_COUNTERSPELL):**
- 0: never counterspell
- 1: always counterspell
- 2: ask player
- 3: smart (counter if remaining mana > half max, and target timeout < 50)

**Counterspell timeout:** max(3, (isDispel ? 20 : 15) - SkillLevel(SK_SPELLCRAFT))

**Reflective Counterspell feat:** If the original target was not the caster and spell is attack/curse, redirects the spell back at the original caster.

---

## Effect Calculation

### Magic::CalcEffect(EventInfo &e)

**Caster Level determination (priority order):**
1. Item (scroll): max(spell_level*2-1, SkillLevel(SK_DECIPHER)-2)
2. Item (general): ItemLevel()
3. No actor: te->Level
4. Trap: te->Level
5. Poison/disease: te->Level
6. SP_INNATE: max(1, ChallengeRating())
7. Otherwise: CasterLev()

**Caster level bonuses:**
- BONUS_SCHOOL_CASTING_LEVEL stati: +Mag if spell school matches
- Lizardfolk + water school: +1
- Dwarf + earth school: +1
- Illusion overcast option: +OPT_OVERCAST

**Range calculation:**
```
if ef.lval and no aval: LevelAdjust(lval, CasterLev, item_plus)
else: 5 + CasterLev/2
MM_EXTEND: range * 2
```

**Radius calculation:**
```
LevelAdjust(lval, CasterLev, item_plus)
MM_ENLARGE: radius * 2
```

**Damage calculation:**
```
Dmg = pval.LevelAdjust(CasterLev, item_plus)
If spell/scroll and EA_BLAST/EA_DRAIN with physical damage:
  Dmg.Bonus += SpellDmgBonus(eID)
If EA_INFLICT on armour:
  Dmg.Bonus += SpellDmgBonus(eID)

MM_MAXIMIZE: vDmg = Number * Sides + Bonus
else: vDmg = Dmg.Roll()
MM_EMPOWER: vDmg = (vDmg * 150) / 100
```

**SpellDmgBonus:**
```
db = Mod(A_WIS) + AbilityLevel(CA_ARCANE_WILL)
If CA_SPELL_FURY + physical blast + arcane/sorcery source:
  db += max(0, Mod(A_WIS))
```

**Chain max targets:** CasterLev / 4

---

## Duration Calculation

```
EF_DSHORT:     1d4 + 1
EF_D1ROUND:    2
EF_DLONG:      100 + CasterLev * 10
EF_DXLONG:     1000 + CasterLev * 100
EF_PERSISTANT: -2 (permanent while maintained)
EF_PERMANANT:  -1 (truly permanent)
default:       10 + CasterLev * 2

Modifiers:
  MM_ANCHOR (duration > 1):              * 2
  EP_BUFF + FT_MYSTIC_PREPARATION:       * 2
  MM_PERSISTANT (duration >= 10):        set to -2
  MM_EXTEND (duration >= 1):             * 2
```

---

## Area-of-Effect Archetypes

### AR_BOLT
Single-target projectile. Stops at first creature hit. Passes through walls if MM_WARP.

### AR_BEAM / AR_BREATH
Line effect that passes through creatures (hits all in path). Multi-target.

### AR_RAY
Line effect, single target (stops at first hit but travels through space).

### AR_CHAIN
Beam that arcs to nearest valid target after each hit. Max targets = CasterLev/4. Ignores friendly creatures (unless EF_NOTBAD). Needs line of fire for each arc.

### AR_BALL
Projectile that travels to target location, then explodes outward. Ball expansion uses BFS-like algorithm with MinGlyphs:
```
MM_ENLARGE: 20 * lval
MM_FOCUS:   lval
default:    3 * lval
```

### AR_BURST
Like ball but centered on caster (no projectile travel phase).

### AR_GLOBE
Circular area around target point. Affects all within radius. Distance check: `dist < vRadius`.

### AR_BARRIER
Wall creation along a cardinal direction. Extends perpendicular to chosen direction until hitting solid walls or reaching limit. Creatures in path are displaced via PlaceNear.

### AR_FIELD / AR_MFIELD
Creates persistent field on the map. AR_MFIELD is mobile (follows creator). Uses NewField() to place. Has glyph options: insects, fog, floor variants.

### AR_TOUCH
Touch-range delivery (handled by ATouch).

### AR_NONE
Direct effect on target (no projectile). Used for self-buffs, etc.

### AR_POISON / AR_DISEASE
Only affects targets without immunity to the relevant damage type.

---

## Effect Archetypes

### EA_BLAST
Deals typed damage. Save for half (if EF_PARTIAL flag). Evasion: if REF save succeeds and light armour, full evasion (0 damage). Improved Evasion (level > 9): partial evasion on failed save. Partial Evasion feat: damage = (dmg+2)/3 instead of (dmg+1)/2.

Lore feats: +20% damage for matching element (FT_LORE_OF_RIME, etc.).

EF_HALF_UNTYPED: splits damage, half typed + half AD_NORM.
MM_CONSECRATE: splits damage, half typed + half AD_HOLY.

Failed save with area effect: 1/3 chance of damaging weapon, 1/3 armour, 1/3 random exposed item (half blast damage).

Incorporeal/planar mismatch: 0 damage unless AD_MAGC, AD_HOLY, AD_NECR, SC_FORCE, or ghost touch.

### EA_GRANT
Gives beneficial stati to target creature. Duration depends on source:
- isWield: permanent (SS_ITEM)
- isEnter: temporary (SS_ENCH) with duration
- Otherwise: temporary, removes existing same-eID effect first
- Source flags: EF_ONCEONLY -> SS_ONCE, EF_CURSE -> SS_CURS, EF_MUNDANE -> SS_MISC, else SS_ENCH
- MM_FORTIFY: caster level + 5

### EA_INFLICT
Applies harmful stati to target. Checks immunity first:
- STUNNED: AD_STUN immunity
- CONFUSED: AD_CONF immunity
- POISONED: AD_POIS immunity
- DISEASED: AD_DISE immunity
- BLIND: AD_BLND immunity
- ASLEEP: AD_SLEE immunity
- PARALYSIS: AD_PLYS immunity (or limited free action)
- AFRAID: AD_FEAR immunity
- PHASED: blocked by ANCHORED/MANIFEST

ASLEEP/CHARMED on hostile: grants kill XP.
Enchantment school + WILL save + Slippery Mind: schedules second save 2 turns later.

### EA_DRAIN
Drains stats/levels. If poison/disease archetype and resisted: damage / 2.

### EA_HEALING
Multi-mode healing. xval flags:
- HEAL_HP: heals hit points. Undead take double damage instead (AD_NORM).
- HEAL_MANA: restores mana
- HEAL_XP: restores drained XP (vDmg * 500)
- HEAL_ATTR / HEAL_SATTR: restores drained attributes (vDmg/5 points)
- HEAL_FATIGUE: restores fatigue
- HEAL_MALADY: removes specific stati
- HEAL_ALL_MALADIES: removes blind, confused, dazed, diseased, stunned, poisoned, hallucination, bleeding, choking, wounded, polymorph
- HEAL_HUNGER: sets hunger to CONTENT

Phoenix Song interaction: healing with AR_NONE spreads to all friendly creatures near bard singing BARD_PHOENIX.

### EA_POLYMORPH
Random form selection: ChallengeRating-based, CR range = [max(0,CR-4)/2, max(1,CR/2)]. Dragons excluded. MM_CONTROL: choose from N candidates (3+Mod(INT)). Specific form if rval set.

Equipment handling: items that don't fit new form either merge (merge flag or poly source) or fall free. Incorporeal form: equipment falls through body. Immunities from new form remove matching stati.

### EA_SUMMON
Encounter generation with EN_SUMMON flag. EF_XSUMMON: only one active summon per effect. MM_CONTROL: choose from N options (5+Mod(INT)). EF_MULTIPLE: allows multiple creatures.

MM_AUGMENT + SC_WEA school: +4 STR, +4 CON, +(10+spell_level*5) THP.

### EA_DISPEL
Dispel check: `if eCasterLev + 11 > vDmg + bon: resisted`.
`bon = AbilityLevel(CA_PURGE_MAGIC)`.

DIS_BANISH: if summoned creature and `vDmg + bon >= 11 + summoned_magnitude`: creature removed.
DIS_DISPEL: iterates all stati with SS_ENCH/SS_ITEM/SS_ONCE/SS_ATTK, comparing caster levels.

Items get DISPELLED stati for vDuration (suppress rather than remove).

### EA_TERRAFORM
Creates terrain. Types: TERRA_EMPTY (must be open), TERRA_ROCK (must be solid stone), TERRA_FLOOR, TERRA_OPEN, TERRA_CLOSED, TERRA_WATER, TERRA_CHASM, TERRA_BRIDGE, TERRA_ALL.

Tracks via TerraList (global per terraform) and TerraXY (per tile). Stores save DC, duration, damage dice, creator. Duration = 0 means permanent. Creatures in newly-solid terrain are displaced.

### EA_TRAVEL
Teleportation. Types:
- TRAVEL_TO_TARG: go to specific location
- TRAVEL_KNOWN: random within vDmg range (must be remembered squares, avoids chasms/solid/vaults)
- TRAVEL_ANYWHERE: random within range (no memory requirement)
- MM_CONTROL: player chooses destination

Blocked by ANCHORED stati. Dismounts if mounted.

### EA_ILLUSION
Three modes:
- 'c' (creature): creates illusory creature via encounter generation
- 'i' (item): creates illusory item on ground with ILLUSION stati
- 'f' (force): redirects to another spell with effIllusion flag

Illusion disbelief: WILL save DC = 10 + Illusionist's SK_ILLUSION/2 + arcane trickery bonus + school focus bonus. Auto-disbelieved by: true sight, mindless creatures, sharp senses/tremorsense/blindsight/scent (unless IL_IMPROVED).

### EA_REVEAL
Augury/divination. Shows greatest adversity (strongest creature) and greatest prosperity (best item) with direction and distance. Prior auguries reduce effectiveness: `PreviousAuguries*4 > tlev` means only vague results. Distance gauged relative to map size.

### EA_VISION
Clairvoyance. Player can move viewpoint freely within range (vRange * 5). Uses arrow keys. Provides full vision from viewpoint.

### EA_CREATION
Creates items or traps from rval resource.

---

## Item-Based Magic

### Potions (Item::DrinkPotion)
- Timeout: +30
- No AoO (intentionally softened for roguelike)
- SK_ALCHEMY check DC 10+ItemLevel for identification
- Consumed after use

### Scrolls (Item::ReadScroll)
- Scroll level = TEFF->Level*2 - 1 (EF_STAPLE: -5)
- Caster level = SkillLevel(SK_DECIPHER)
- If scroll level > caster level: warning, WILL save DC 15 to continue
- SK_DECIPHER check DC 10 + scroll level: failure = wild magic
- If check > 20 + scroll level and 50% chance: scroll preserved
- Counterspellable
- If SpellRating <= 0: scroll strain damage (Level*2 AD_NORM) + 2/3 mana drain
- Timeout: max(10, 50 - casterLevel*2)

### Wands (Item::ZapWand)
- Requires charges and mana (ManaCost)
- Timeout: 2000 / max(25, 100 + Mod(INT)*5)
- Use Magic check: best of 2d20 (3d20 with permanent skill bonus), + SkillLevel(SK_USE_MAGIC) + specialist bonus
- DC = 10 + ItemLevel/2 (EF_STAPLE: level - 5)
- Supercharge levels:
  - Rating+roll >= 30+Lev: supercharge 4
  - Rating+roll >= 25+Lev: supercharge 3
  - Rating+roll >= 20+Lev: supercharge 2
  - Rating+roll >= 15+Lev: supercharge 1
  - Rating+roll >= 10+Lev/2: normal success
  - Below: failure
- Mana cost: Cost + Cost*Supercharge / ((Cost+1)*(Supercharge+1))
- On failure: random mishap (damage, polymorph, confusion, teleport, etc.)

### Activation (Item::Activate)
- Timeout: +30
- EF_1PERDAY/EF_3PERDAY/EF_7PERDAY: charge-limited per day

---

## Divine Magic

### PrePray Flow
1. Check for altar at current position
2. If no god and no altar: abort
3. If god and altar of different god: choose which
4. Options vary by context:
   - On own altar: request aid, bless items, seek insight, sacrifice
   - Not on altar: request aid, seek insight
   - On foreign altar: convert, request aid, sacrifice

### Insight (Seek divine knowledge)
- Requires: not threatened, SK_KNOW_THEO check DC 15, no previous attempt this turn
- Reports: forsaken, anathema, angry (two levels), tolerant
- Lists available aid types with required favour
- Can trigger item identification (AID_IDENTIFY)
- Sets PrayerTimeout and FavPenalty

### Item Blessing (IBlessing)
- Requires calcFavour > 100
- Weapon/shield/armour can receive god-specific quality
- Quality limited by: `ItemLevel <= FavourLev + Mod(WIS) + isChosenWeapon*4`
- If already blessed: skip
- Otherwise: remove curse, add blessed flag
- FavPenalty += quality_mod*3 + quantity/5

---

## Favour and Sacrifice

### calcFavour
```
Favour = sum of SacVals[godNum][0..MAX_SAC_CATS+1]
       * (100 - FavPenalty[godNum]) / 100
       Modified by EV_CALC_FAVOUR event
```

### Sacrifice value calculation
```
sacVal = base_value * sacMult / 10 * (10 + SkillLevel(SK_KNOW_THEO)) / 10

base_value:
  Creature sacrifice: XCR(ChallengeRating)
  Book: 100 + ItemLevel*50
  Item: getShopCost()

sacMult: from SacList (default 10, overridable per category)
```

**Impressive sacrifice:** creature sac impressive if sacVal > previous best; item sac impressive if sacVal > WealthByLevel[TotalLevel/2] / 20.

**Anger reduction:** each sacrifice reduces anger by 3 (max 0).

**Sacrifice categories:** matched via SacList from god definition. Summoned/illusory creatures rejected. Bad categories: SAC_ANGRY (transgression +1), SAC_ABOMINATION (transgression +5).

### Favour advancement
- FavourLev[godNum] tracks current tier (0-9)
- When calcFavour exceeds favourChart[currentLevel]: advance
- Must pass isWorthyOf check
- EV_BLESSING event fired
- AddAbilities granted per tier

---

## Transgression System

### Character::Transgress(gID, mag, doWrath, reason)

**For non-own-god:** random(60) > mag chance of being noticed; capped at 1 magnitude; stops if anger already > 10.

**Anger accumulation:** Anger[godNum] += mag (capped at 50).

**Duplicate check:** AngerThisTurn prevents double-counting within a turn. Only the highest magnitude transgression counts per turn.

**Thresholds:**
- `Anger > TOLERANCE_VAL` with doWrath: triggers EV_RETRIBUTION
- `Anger >= 50`: GS_ANATHEMA (permanent rejection)
- `Anger > 35` (own god): Forsake

**Forsake mechanics:**
- GF_FORGIVING god with anger <= 30: penance instead (GS_PENANCE)
- Otherwise: GS_FORSAKEN, GodID = 0
- All sacrifice values zeroed
- All blessing stati removed (SS_BLES)

### isWorthyOf
Checks alignment compatibility, not anathema/forsaken/penance.

---

## Divine Intervention

### Prayer (Creature::Pray)

**Prerequisites:**
- SK_KNOW_THEO check DC = PRAYER_DC (god constant), with retry penalty
- Praying to non-own-god triggers EV_JEALOUSY
- Anger > TOLERANCE_VAL: retribution instead of aid
- PrayerTimeout > 0: transgression +1, timeout extended

**Aid matching:** iterates player's trouble list against god's AID_CHART. Each aid requires minimum favour and priority threshold. AidPairs maps troubles to aid types.

**Post-prayer:**
```
PrayerTimeout = PRAYER_TIMEOUT + TotalLevel + random(5)
FavPenalty += INTERVENTION_COST
```

### Trouble Priority System
Troubles sorted by priority (P_CRITICAL=highest to P_LOW=lowest):
- INJURY: 70%+ critical, 50%+ urgent, 20%+ moderate, any = low
- LOWMANA: 92%+ critical, 80%+ extreme, etc.
- HUNGER: weak/fainting = critical, starving = urgent, hungry = moderate
- Various stati: STONING critical, POISON extreme, BLIND extreme, etc.
- ENEMIES: based on XCR ratio (enemy vs player+allies)

### Divine Deflect (GodDeflect)
Triggers when incoming damage would bring HP below mHP/5 or weapon is vorpal:
- Requires GS_INVOLVED, not anathema/forsaken
- Favour >= aid chart threshold for AID_DEFLECT
- FavPenalty + INTERVENTION_COST <= 100
- Anger <= max(3, TOLERANCE_VAL)
- Effect: `vDmg /= vCrit` (removes critical multiplier)

### Resurrection (GodRaise)
- Requires: GS_INVOLVED, own god, TotalLevel >= MIN_RAISE_LEVEL
- BAttr[A_CON] > 3
- Favour >= AID_RESURRECT threshold
- resChance check: if resChance < random(100), soul too weak
- Costs: RESURRECTION_COST to FavPenalty
- Penalties: lose XP (max(0, min(XP-2000, XP*85/100))), permanent -1 CON
- Restoration: full HP, full mana, remove curses/diseases/poisons/bleeding
- Teleported to dungeon level 1, given resurrection gear

---

## Altar Conversion

### ConvertAltar
- Requires: own god, not threatened, SK_KNOW_THEO check DC 15
- Costs: 2 fatigue, 4 hours
- Roll: 1d20 + FavourLev + Mod(WIS) + 4 (if altar god cedes)
  - > 15: altar converts
  - > 12: altar trembles (no conversion)
  - > 7 or ceded: altar shatters
  - Otherwise: altar explodes (2d10 blunt + 2d10 fire damage)
- Always: FavPenalty[altarGod] += 20; transgression to altar god

---

## Constants Summary

### Key God Constants (from TGod)
- `TOLERANCE_VAL` - anger threshold before retribution
- `PRAYER_DC` - skill check DC for prayer
- `PRAYER_TIMEOUT` - base prayer cooldown
- `INTERVENTION_COST` - favour penalty per intervention
- `RESURRECTION_COST` - favour penalty for resurrection
- `MIN_RAISE_LEVEL` - minimum player level for resurrection
- `MIN_CONVERT_FAVOUR` - favour needed to convert to this god
- `PERSONAL_ALIGN` - alignment of the god
- `VOICE_COLOUR` - colour for divine speech
- `HOLY_SYMBOL` - eID of god's holy symbol
- `CHOSEN_WEAPON` - iID of favoured weapon
- `CHOSEN_WEAPON_QUALITY` / `SHIELD` / `ARMOUR` - blessing qualities
- `LAY_MULTIPLIER` - favour divisor for non-own-god aid

### Key Lists (from TGod)
- `AID_CHART` - triplets of (aid_type, min_priority, min_favour)
- `SACRIFICE_LIST` - pairs of (creature_type/item_type, sac_result)
- `FAVOUR_CHART` - favour thresholds per level (9 levels)
- `GOD_RELATIONS` - relationships with other gods
- `GODSPEAK_LIST` - custom messages per event
- `ALLOWED_GODS` - gods valid for specific classes

### Aid Types
```
AID_HEAL, AID_PURIFY, AID_SMITE, AID_UNCURSE, AID_TELEPORT,
AID_FEED, AID_REFRESH, AID_RESTORE, AID_CURE, AID_CLARITY,
AID_RESURRECT, AID_BERSERK, AID_NEWBOOK, AID_MANA, AID_DEFLECT,
AID_IDENTIFY
```

### God State Flags (GS_*)
```
GS_INVOLVED   - player has interacted with this god
GS_FORSAKEN   - god has forsaken player
GS_ANATHEMA   - permanent rejection (anger >= 50)
GS_PENANCE    - forgiving god in probation state
GS_ABANDONED  - player converted away from this god
GS_KNOWN_ANGER - player knows god is angry
```

### Elemental Damage Macro
```c
#define is_elemental_dmg(i) (i == AD_FIRE || i == AD_COLD || i == AD_ELEC || \
                             i == AD_TOXI || i == AD_SONI || i == AD_ACID)
```
