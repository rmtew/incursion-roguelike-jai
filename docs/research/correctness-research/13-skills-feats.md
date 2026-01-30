# Skills, Feats & Abilities

**Source**: `Skills.cpp`, `Create.cpp`, `inc/Creature.h`, `inc/Defines.h`
**Status**: Fully researched

## Table of Contents
- [Skill Check System](#skill-check-system)
- [Skill Level Calculation](#skill-level-calculation)
- [Skill Kit System](#skill-kit-system)
- [Individual Skill Implementations](#individual-skill-implementations)
- [Class Ability Implementations](#class-ability-implementations)
- [Crafting System](#crafting-system)
- [Legend Lore / Identification](#legend-lore--identification)
- [Devour System](#devour-system)
- [Turning Undead](#turning-undead)
- [Feat System](#feat-system)
- [Character Creation](#character-creation)
- [Level Advancement](#level-advancement)
- [Experience System](#experience-system)
- [Studies System](#studies-system)
- [Porting Considerations](#porting-considerations)

---

## Skill Check System

**Source**: `Skills.cpp` lines 1520-1722 (`Creature::SkillCheck()`)

### Core Formula
```
result = SkillLevel(sk) + best_roll + mod1 + mod2 + armPen
success = (result >= DC) OR (natural 20 auto-success for specific skills)
```

The global `LastSkillCheckResult` stores the exact numeric result for callers that need it.

### Multi-Roll System (Non-OGL Extension)

Certain skills roll multiple d20s and take the best, to improve reliability in a roguelike context:

```
rollA = 1d20                          (always)
rollB = 1d20 if SK_USE_MAGIC, SK_ANIMAL_EMP, or SK_DECIPHER
rollC = 1d20 if Skill Focus (SKILL_BONUS with SS_PERM source)
roll  = max(rollA, rollB, rollC)
```

Design rationale (from source comments): "In a roguelike game it is important that rogues be able to read scrolls and fire wands, and rangers and druids tame animals, with some degree of reliability. Abilities which work 50% of the time in combat are practically useless in a RL."

### Skill Mastery

If the creature has `CA_SKILL_MASTERY` and the skill is a rogue class skill:
```
roll = max(roll, min(15, 7 + Mod(A_INT)))
```
This gives a guaranteed minimum roll for class skills.

### Most Skilled Ally

For certain skills, a nearby friendly creature with a higher skill level can substitute:
```
Eligible skills: SK_LOCKPICKING, SK_HEALING, SK_HANDLE_DEV, SK_SEARCHING,
                 SK_INTUITION, SK_ANIMAL_EMP, SK_DIPLOMACY, SK_BLUFF,
                 SK_INTIMIDATE, SK_DECIPHER
```
The `MostSkilledAlly()` function finds the best nearby ally; their `SkillLevel(sk)` is used instead of the actor's if higher.

### Natural 20 Auto-Success

A natural 20 only auto-succeeds when:
1. The creature is NOT threatened (not in melee combat)
2. The skill is one of: `SK_ESCAPE_ART`, `SK_CLIMB`, `SK_HANDLE_DEV`, `SK_SEARCH`, `SK_BALANCE`

### Suggestion Clause

Hardcoded special case for social skills (`SK_DIPLOMACY`, `SK_BLUFF`, `SK_INTIMIDATE`): if the actor has an enchantment-school `SKILL_BONUS` on the skill, the victim's mind resistance reduces the bonus:
```
if victim.ResistLevel(AD_MIND) == -1:
    bonus reduced by HighStatiMag(SKILL_BONUS, sk)
else:
    bonus reduced by min(bonus, victim.ResistLevel(AD_MIND) + victim.HighStatiMag(SAVE_BONUS, SN_ENCH))
```

### Exercise System

When a check barely succeeds (passed by exactly 1 point: `sr + roll + mods >= DC` but `sr + 1 + mods < DC`), the associated attributes are exercised:
```
die = DC - 10 (base exercise amount)
Exercise(SkillInfo[sk].attr1, 1d(die), exercise_column, cap)
Exercise(SkillInfo[sk].attr2, 1d(die), exercise_column, cap) if attr2 != attr1
```

Skill-specific exercise modifiers:
| Skill | Column | Cap | Die Modifier |
|-------|--------|-----|--------------|
| SK_LOCKPICKING | EXXX_PSKILL | 60 | die/2 |
| SK_JUMP | EDEX_JUMP | 20 | die/2, testThreat |
| SK_METAMAGIC | EXXX_SKILL | 50 | none, testThreat |
| SK_BALANCE | varies | 75 if fall | die*2 if fall, testThreat |
| SK_BLUFF/INTIMIDATE/DIPLOMACY | EXXX_PSKILL | 75 | die*2 |
| SK_DECIPHER | EXXX_PSKILL | 60 | die/2 |
| SK_ESCAPE_ART/RIDE/SWIM | EXXX_SKILL | 30 | none, testThreat |

When `testThreat` is true, exercise only occurs if `isThreatened()`.

Additionally, barely-succeeded checks award god favour for deities with the skill as a favoured skill:
```
favour = max(0, 10 * (total_result - 15))
```

---

## Skill Level Calculation

**Source**: `Create.cpp` lines 3638-3854 (`Creature::SkillLevel()`)

### Complete Formula (Characters)
```
SkillLevel = SkillRanks[sk]
           + s_racial     (racial bonuses from body/template/race)
           + s_feat       (feat bonuses, class skill bonuses)
           + s_enhance    (enhancement bonuses from spells/effects)
           + s_domain     (domain bonuses)
           + s_item       (item bonuses)
           + s_ins        (insight bonuses, e.g. Ancestral Memory)
           + s_syn        (synergy bonuses from related skills)
           + s_comp       (competence bonuses)
           + s_circ       (circumstance bonuses/penalties)
           + s_inh        (inherent bonuses from abilities)
           + s_size       (size modifier, Hide only)
           + s_armour     (armour check penalty)
           + s_train      (training bonus)
           + s_kit        (skill kit bonus)
           + s_focus      (skill focus bonus)
           + Mod2(SkillAttr(sk))   (attribute modifier)
```

### Bonus Sources (Non-stacking by type)

Each bonus type takes the maximum from its source. From SKILL_BONUS stati:
| Source | Maps To |
|--------|---------|
| SS_CLAS | s_feat (max) |
| SS_BODY, SS_TMPL, SS_RACE | s_racial (max) |
| SS_DOMA | s_domain (max) |
| SS_ITEM | s_item (max) |
| SS_PERM | s_focus (max) |
| Other | s_enhance (max) |

### Feat Skill Bonuses

Each feat grants `FEAT_SKILL_BONUS = 3` to paired skills:
| Feat | Skills |
|------|--------|
| FT_ALERTNESS | SK_LISTEN, SK_SPOT |
| FT_ACROBATIC | SK_JUMP, SK_TUMBLE |
| FT_ATHLETIC | SK_ATHLETICS, SK_CLIMB, SK_SWIM |
| FT_ARTIFICER | SK_CRAFT, SK_HANDLE_DEV |
| FT_EDUCATED | SK_KNOW_FIRST through SK_KNOW_LAST |
| FT_INSIGHTFUL | SK_APPRAISE, SK_INTUITION (deprecated) |
| FT_LARCENOUS | SK_LOCKPICKING, SK_PICK_POCKET |
| FT_CAPTIVATING | SK_DIPLOMACY, SK_PERFORM |
| FT_SNEAKY | SK_HIDE, SK_MOVE_SILENTLY |
| FT_WOODSMAN | SK_WILD_LORE, SK_ANIMAL_EMP |
| FT_GRACEFUL | SK_BALANCE, SK_ESCAPE_ART, SK_SWIM |
| FT_DETECTIVE | SK_APPRAISE, SK_SEARCH, SK_GATHER_INF |
| FT_TALENTED | SK_DECIPHER, SK_USE_MAGIC |
| FT_GUILDMAGE | SK_METAMAGIC, SK_SPELLCRAFT |
| FT_PHYSICIAN | SK_HEAL, SK_ALCHEMY |
| FT_MURDEROUS | SK_FIND_WEAKNESS, SK_POISON_USE |
| FT_CLEAR_MINDED | SK_CONCENT, SK_INTUITION |
| FT_LANDED_NOBLE | SK_RIDE, SK_SENESCHAL |
| FT_DECIEVER | SK_BLUFF, SK_DISGUISE, SK_ILLUSION |

### Inherent Bonuses from Abilities
- `CA_FATESENSE`: +4 to SK_INTUITION (as domain bonus)
- `CA_SHARP_SENSES`: AbilityLevel added to SK_SPOT, SK_LISTEN
- `CA_STONEWORK_SENSE`: AbilityLevel added to SK_SEARCH
- `CA_LEGEND_LORE`: AbilityLevel/2 added to all knowledge skills

### Circumstance Modifiers
- SK_HIDE while CHARGING: -20
- SK_HIDE while ELEVATED in tree/ceiling: +2 + SkillLevel(SK_CLIMB)/3
- While SINGING (any skill except SK_PERFORM): -2

### Size Modifier (SK_HIDE only)
```
s_size = (SZ_MEDIUM - Attr[A_SIZ]) * 4
```

### Training Bonus
```
s_train = 0
if race has skill: s_train += 1
for each class with skill: s_train += 1
if s_train == 0 and has EXTRA_SKILL: s_train = 1
if s_train > 0: s_train += 2   (minimum +3 for any class skill)
```

### Synergy Bonuses
```
For each synergy pair (target_skill, source_skill, divisor):
    s_syn += SkillRanks[source_skill] / divisor
```
Uses a `Synergies[][]` table (defined elsewhere).

### Armour Check Penalty
Applies when `SkillInfo[sk].armour_penalty` is set. Checks slots `SL_ARMOUR`, `SL_READY`, `SL_WEAPON`:
```
s_armour += armour_penalty_flag * PenaltyVal(this, true)
```
Special: SK_SWIM ignores penalty for items with `IQ_FEATHERLIGHT`.

### Monster Skill Levels
For non-character creatures:
- Class skills: `sr = max(1, ChallengeRating()) + 3`
- SK_SPOT, SK_LISTEN (non-class): `sr = ChallengeRating() / 2`
- Skill Focus: `sr += 2`

### Ancestral Memory
When `ANC_MEM` stati is present for a skill:
```
mr = MaxRanks(sk)
s_ins = max(s_ins, 4 - abs(mr - sr))
sr = mr   (ranks elevated to maximum)
```

---

## Max Ranks (Progressive Table)

**Source**: `Create.cpp` lines 3528-3581 (`Character::MaxRanks()`)

The max ranks grow more slowly than level, allowing characters to broaden over time:

```cpp
int8 ClassLevelRanks[] = {
    0,  2,  4,  6,  7,  8,  9,  10,  10,  11, 12, 12,
    13, 14, 14, 15, 16, 16, 17, 18,  18,  19,
    20, 20, 20, 20, 20, 20, 20, 20,  20,  20  // paranoia
};
```

- **Racial skill**: `ClassLevelRanks[TotalLevel()]`
- **Class skill**: `ClassLevelRanks[sum of levels in classes that have the skill]`
- **Familiar skill**: `max(mr, min(TotalLevel(), 5))`
- **Intensive Study (Sneak)**: Hide/Move Silently ranks +2 per study level, capped at `ClassLevelRanks[TotalLevel()]`
- **Domain skill**: `mr += ClassLevelRanks[AbilityLevel(CA_DOMAINS)]`
- **Other EXTRA_SKILL**: `ClassLevelRanks[TotalLevel()]`

---

## Skill Kit System

**Source**: `Skills.cpp` lines 750-812

### SkillKitMod()
Returns total kit bonus for a skill from three sources:
1. **Primary kit**: Best bonus from items with `SKILL_KIT_FOR` matching the skill
   - `mod = SKILL_KIT_MOD constant + item plus`
2. **Secondary kits**: Cumulative bonuses from unique items with `SECONDARY_KIT_FOR`
3. **Rope modifier**: For SK_CLIMB, items with `IT_ROPE` contribute `ROPE_MOD`
4. **Innate kit**: `INNATE_KIT` stati checked

### Performance Optimization
These skills short-circuit (return 0 immediately) because they have no applicable kits:
`SK_MOVE_SIL, SK_HIDE, SK_SPELLCRAFT, SK_SPOT, SK_LISTEN, SK_INTIMIDATE`

### HasSkillKit()
Required for: `SK_HEAL, SK_DISGUISE, SK_ALCHEMY, SK_MINING, SK_CRAFT, SK_LOCKPICKING`

Special: `SK_KNOW_THEO` gets +4 bonus from a holy symbol of your god equipped in an active slot.

---

## Individual Skill Implementations

**Source**: `Skills.cpp` lines 814-1113 (`Character::UseSkill()`)

### SK_LISTEN (Active Listen)
- Cannot use in combat (isThreatened)
- Costs 40 timeout
- Iterates all creatures on the map
- Excludes clearly perceived creatures
- DC for hearing: `target.SkillLevel(SK_MOVE_SIL) + distance`
- Score: `SkillLevel(SK_LISTEN) * 2 - DC`
  - Score > 15: Identify specific creature type (by name)
  - Score > 5: Hear general sound by creature type, with direction
  - Score > 0: Hear general sound by creature type, no direction
- Reports distance using qualitative terms (40+ = "exceedingly faintly", 5- = "very close by")
- Reports direction (N/S/E/W/NE/NW/SE/SW)
- After listening, can assess rest safety (DC 15 Listen check):
  - Chance <= 0: "safe to rest"
  - Chance < 100: "may be an encounter"
  - Chance >= 100: "not safe to rest"
- Failed rest-safety check gives `TRIED` stati preventing retry for 3 ticks

### SK_HIDE
Dispatches to `EV_HIDE` event with `HI_SHADOWS`.

### SK_SEARCH
```
SK_SEARCH: calls Creature::Search()
```
(Separate function, handles trap/secret door detection.)

### SK_HANDLE_DEV
- Costs 50 timeout
- Finds adjacent perceived traps and attempts `DisarmTrap()`
- With `TELEKINETIC` stati, can target traps at range
- Trap Disarm DC: `15 + TrapLevel()`

### SK_ANIMAL_EMP
- Targets a creature
- `e.EParam = SkillLevel(SK_ANIMAL_EMP)`
- Species affinity can override with higher value
- Valid targets: MA_ANIMAL (with skill), MA_BEAST (with FT_BEASTIAL_EMPATHY)

### SK_HEAL
- Requires healing kit
- Heals `2d6 + max(1, SkillLevel(SK_HEAL)/3)` HP
- Cannot heal undead

### SK_DISGUISE
- Requires disguise kit
- Only humanoids can use effectively
- See [Disguise DC Calculation](#disguise-dc-calculation) below

### SK_BALANCE
- Creates a tightrope bridge effect

### SK_TUMBLE
- Costs 1 fatigue
- Grants TUMBLING stati for `1d4 + SkillLevel(SK_TUMBLE)` duration
- Exercises DEX

### SK_JUMP
- Prompts for target location, dispatches EV_JUMP

### SK_KNOW_MAGIC
- Dispatches to EV_RESEARCH (library research)

---

## Disguise DC Calculation

**Source**: `Skills.cpp` lines 2313-2395

Base DC depends on racial similarity:
```
Default DC: 16
Similar races: 13   (from Similarities table)
Same race: 10       (from Races table)
```

**Similarities table**:
```
Human-Elf, Human-Dwarf, Human-Halfling, Human-Gnome, Human-Planetouched,
Orc-Goblin, Elf-Faerie, Elf-Drow, Halfling-Gnome, Reptile/Humanoid-Kobold
```

**Size modifier**:
- Size difference > 1: impossible (return -1)
- Size difference = 1: DC += 7

**Gender modifier**:
- Disguising as all-female race while male: DC += 4
- Disguising as all-male race while female: DC += 4

Undead targets skip size modifier.

---

## Pick Pocket

**Source**: `Skills.cpp` lines 2640-2778

DC is based on target's awareness:
```
Base: opposed SK_PICK_POCKET vs target's SK_SPOT
Modifiers for item weight, visibility of item, etc.
```

---

## Class Ability Implementations

**Source**: `Skills.cpp` lines 1749-2292 (`Character::UseAbility()`)

### CA_BERSERK_RAGE
- Fatigue cost based on armour:
  - No armour: 1
  - Light: 2
  - Medium: 3
  - Heavy: 4
  - Level 4+: cost reduced by 1
  - Cost 0: CON check (DC 20) or still costs 1
- Cannot rage while afraid
- Strength bonus by level:
  - Level 16+: +8
  - Level 10+: +6
  - Level 3+ (or single-class): +4
  - Otherwise: +2
- Duration: `10 + AbilityLevel(CA_BERSERK_RAGE) * 3`

### CA_LAY_ON_HANDS
- Costs 2 fatigue, +30 timeout
- Targets nearby creature
- Against undead: `2d6 + max(1, 2 + Mod(A_CHA)) * AbilityLevel(CA_LAY_ON_HANDS)` holy damage
- Against living: heals same amount

### CA_SOOTHING_WORD
- Costs 3 fatigue
- DC: `10 + AbilityLevel/2 + Mod(A_CHA)`
- Affects hostile, living, non-sapient creatures within 6 tiles
- WILL save vs DC, enchantment + magic
- Failed save: creature pacified

### CA_TRACKING
- Max targets: `max(1, Mod(A_WIS) + 1 + AbilityLevel/5)`
- Tracking range: `min(125, 40 + AbilityLevel * 5)`

### CA_MANIFESTATION
- Costs 3 fatigue
- Duration: `1d4 + TotalLevel()/3`

### CA_PROTECTIVE_WARD
- Costs 2 fatigue
- Grants saving throw bonus equal to AbilityLevel
- Duration: `20 + AbilityLevel * 3`

### CA_FEAT_OF_STRENGTH
- Costs 4 fatigue
- Grants STR bonus equal to AbilityLevel
- Duration: 1 tick

### CA_UNBIND
- Costs 2 fatigue
- Range: `max(1, AbilityLevel + Mod(A_CHA))`
- Frees summoned creatures in radius

---

## Crafting System

**Source**: `Skills.cpp` lines 3130-3758

### XP Cost Table
```cpp
int16 XPCostTable[] = {
    0, 80, 160, 320, 540, 720, 1280, 1670,
    2000, 2880, 3920, 5120, 6480, 8165,
    12050, 15400, 17200, 19400, 21300,
    23750, 25000
};
```
Indexed by item level (0-20).

### Crafting Modes
| Ability Source | Item Type | Skill Used | Max Level |
|----------------|-----------|------------|-----------|
| SK_ALCHEMY + SKILL_VAL | T_POTION (AI_ALCHEMY) | SK_ALCHEMY | SkillLevel(SK_ALCHEMY) |
| SK_POISON_USE + SKILL_VAL | T_POTION (AI_POISON) | min(SK_POISON_USE, SK_ALCHEMY) | min of both |
| FT_SCRIBE_SCROLL + FEAT_VAL | T_SCROLL | none | SkillLevel(SK_KNOW_MAGIC) |
| FT_BREW_POTION + FEAT_VAL | T_POTION (AI_POTION) | SK_ALCHEMY | SkillLevel(SK_ALCHEMY) |
| SK_CRAFT + SKILL_VAL | varies | SK_CRAFT | SkillLevel(SK_CRAFT) |
| CA_WEAPONCRAFT + ABIL_VAL | weapons/armour | SK_CRAFT | SkillLevel(SK_CRAFT), requires forge |
| CA_STORYCRAFT + ABIL_VAL | any (improve only) | none | AbilityLevel + Mod(A_CHA) + 1 |

### Tempering (Masterwork)
- Requires forge, metallic bladed weapon
- 6 hours work time
- DC: `15 + ItemLevel()`
- Success: Grants MASTERWORK stati with quality `(SkillLevel(SK_CRAFT) - 7) / 5`
- Failure below `10 + ItemLevel()`: damages weapon (1d8 damage, may destroy)
- Exercises STR (1d12, ESTR_FORGE, cap 30) and INT (1d12, EINT_CREATION, cap 40)

---

## Legend Lore / Identification

**Source**: `Skills.cpp` lines 4775-4915

### Progressive Knowledge Thresholds
Formula: `i = (10 + AbilityLevel(CA_LEGEND_LORE) + Mod(A_INT)) - ItemLevel()`

| Threshold (i >) | Knowledge Gained |
|-----------------|-----------------|
| 0 | KN_NATURE (item type/nature) |
| 5 | KN_CURSE (cursed status) |
| 8 | KN_BLESS (blessed status) |
| 10 | KN_MAGIC (magical properties) |
| 15 | KN_PLUS (enhancement bonus) |
| 20 | KN_PLUS2 (secondary plus) |
| 30 | KN_ARTI (artifact status) |

### Decipher Skill (Runic Items)
- Items with `IF_RUNIC` flag or flavour names containing runic words
- Runic words: "rune", "runic", "runed", "inscribed", "written", "symbol", "glyph", "engraved", "ancient", "script", "iconic"
- DC: `10 + ItemLevel() * 2`
- Success reveals: KN_MAGIC, KN_CURSE, KN_PLUS
- Exercises INT

### Nature Sense (CA_NATURE_SENSE)
- Automatically identifies mushrooms and herbs (full knowledge)

### Fatesense (CA_FATESENSE)
- Automatically reveals KN_CURSE
- "You feel a faint shiver" for cursed items

### Easy Intuit Options
- 0: No auto-intuit
- 1: Intuit all items on sight
- 2: Intuit weapons/armour/missiles/bows/shields only

---

## Scrutinize Monster (Knowledge Skills)

**Source**: `Skills.cpp` lines 4921-5055

Automatically called when an unscrutinized monster's glyph is first drawn. Uses the most relevant knowledge skill:
| Monster Type | Knowledge Skill |
|-------------|----------------|
| MA_UNDEAD | SK_KNOW_UNDEAD |
| MA_AQUATIC | SK_KNOW_OCEANS |
| MA_PLANT/FUNGI/NATURAL/ANIMAL/SYLVAN/BEAST | SK_KNOW_NATURE |
| MA_MYTHIC/FAERIE/NAGA/LYCANTHROPE/DRAGON | SK_KNOW_MYTH |
| MA_EYE/VORTEX/MAGC | SK_KNOW_MAGIC |

Uses the highest applicable skill level among all matching skills.

---

## Devour System

**Source**: `Skills.cpp` lines 2911-3080

### Theological Consequences
Devouring sapient creatures:
- Transgress Mara: severity 7 (unless both orc)
- Transgress Erich: severity 4
- Transgress Immotian: severity 6
- Transgress Xavias: severity 3
- Transgress Hesani: severity 3
- Gain favour with Khasrach: `10 * ChallengeRating`
- AlignedAct(AL_NONLAWFUL, 3) unless orc or reptile

All devouring gains favour with Zurvash: `5 * ChallengeRating`.

Devouring reptilian flesh removes STONING stati.

### Devouring Mechanics (requires CA_DEVOURING)
Undead flesh yields nothing.

**Resistance gains**: For each damage type (fire, cold, acid, electric, toxic, necrotic, psychic, magic, sunlight, sonic, disease):
- If monster has immunity: effective level = `max(CR, 0) + 3`
- If monster has resistance: effective level = `max(CR, 0) + 1`
- If devoured monster's resistance exceeds your current racial resistance: gain +1 resistance

**Attribute gains**: For specific monster types mapped to attributes (using AttrMTypes table):
- If monster's attribute exceeds your base + inherent bonus, and you have room (max `5 + AbilityLevel(CA_INHERANT_POTENTIAL)`):
  gain +1 inherent bonus

**Dragon mana**: Devouring dragons grants mana bonus (10 * dragon power level), incrementally.

**XP from devouring**:
```
base = CR * 50
halve for each level player CR exceeds monster CR
GainXP(result)
```

---

## Turning Undead

**Source**: `Skills.cpp` lines 4375-4614

### Requirements
- Need holy symbol (in READY/WEAPON/AMULET/ARMOUR slot) matching your god, OR armour/shield with `AQ_GRAVEN`
- Must have a god with favour
- Fatigue cost: 2 (regular turning), 4 (greater turning)
- Timeout: 30

### Turn Check Formula
```
base = e.vDmg (turn check value from event)
if FT_IMPROVED_TURNING: +4
if SkillLevel(SK_KNOW_THEO) > 5: +2
+Mod(A_CHA)

max_dist = 10 + total_check

For each valid target in range:
    roll = 1d20
    resist = max(CR + AbilityLevel(CA_TURN_RESISTANCE), 1)
    mag = ((check + roll) * 750) / (resist * 100)
```

### Effect Tiers (by mag value)
| mag | Effect |
|-----|--------|
| > 60 (or > 10 with Greater Turning) | Instant death (EV_DEATH) |
| > 30 | Holy damage: `(check + roll)d4` |
| > 20 | Stunned for `(check + roll) + 5` ticks |
| > 10 | Afraid (FEAR_PANIC) for `(check + roll)*3 + 10` ticks |
| > 5 | Morale penalty -2 for `(check + roll)*6 + 20` ticks |
| <= 5 | Target resists |

### Command Variant (CA_COMMAND)
| mag | Effect |
|-----|--------|
| > 40 | Permanent charm (CH_COMMAND) |
| > 20 | Paralyzed 1d4 ticks + Afraid 1d4 ticks |
| > 10 | Afraid 1d4 ticks (FEAR_PANIC) |

### Divine Feat Integration
If the turner has any divine feat (FT_DIVINE_ARMOUR, CLEANSING, MIGHT, RESISTANCE, VENGEANCE, VIGOR, AEGIS), grants `CHANNELING` stati for `GetAttr(A_CHA) * 2` duration.

---

## Feat System

### Feat Storage
```cpp
uint16 Feats[(FT_LAST/8)+1];  // Bitfield, 1 bit per feat
```
Access: `Feats[ft/8] & (1 << (ft%8))`

### HasFeat() Implementation

**Source**: `Create.cpp` lines 3466-3526

Checks multiple sources in order:
1. Armour proficiency feats map to `Proficiencies` bitfield
2. `EXTRA_FEAT` stati with matching value
3. `EXTRA_SKILL` stati with matching value
4. `TEMPLATE` stati - templates can grant feats
5. `CONDITIONAL_FEAT` stati - evaluated via `EV_ISTARGET` event
   - Class/race conditional feats count for prerequisites
   - Item/spell conditional feats do NOT count for prerequisites
6. Feat bitfield: `Feats[ft/8] & (1 << (ft%8))`

### FeatPrereq() Implementation

**Source**: `Create.cpp` lines 3253-3358

Prerequisites are stored in Disjunctive Normal Form (DNF):
```
Up to FP_MAX_DISJUNCTS OR clauses
Each with up to FP_MAX_CONJUNCTS AND conditions
```

Special pre-checks:
- FT_INTENSIVE_STUDY requires `getEligableStudies() != 0`
- Armour proficiency feats (LIGHT/MEDIUM/HEAVY) fail if already proficient
- Feats with FF_UNIMP or FF_MONSTER flags: always fail
- Already-held feats: fail unless FF_MULTIPLE
- FF_META feats require `CasterLev() > 0`
- FP_ALWAYS: always pass

Condition types evaluated:
| FP_ Type | Check |
|----------|-------|
| FP_FEAT | `IHasFeat(arg)` |
| FP_ABILITY | `IHasAbility(arg) && AbilityLevel(arg) >= val` |
| FP_BAB | `GetBAB(arg) >= val` |
| FP_NOT_PROF | `!(Proficiencies & arg)` |
| FP_PROF | `Proficiencies & arg` |
| FP_CR | `ChallengeRating() >= arg` |
| FP_ATTR | `IAttr(arg) >= val` (uses inherent attributes, not item-boosted) |
| FP_SKILL | `ISkillLevel(arg) >= val` |
| FP_CASTER_LEVEL | `CasterLev() >= arg` |
| FP_WEP_SKILL | `HasStati(WEP_SKILL, arg)` |
| FP_ATTACK | `TMON(tmID)->HasAttk(arg)` |
| FP_MTYPE | `TMON(tmID)->isMType(tmID, arg)` |

Important: `IAttr()` returns inherent attributes (base + racial + feat + inherent bonuses), NOT item-enhanced attributes. This prevents "put on a Headband of Intellect to learn a feat" abuse.

### IAttr Formula
```
IAttr(a) = BAttr[a] + TRACE(RaceID)->AttrAdj[a] + HasFeat(FT_IMPROVED_STRENGTH+a) + SumStatiMag(ADJUST_INH, a)
```

---

## Character Creation

**Source**: `Create.cpp` lines 95-740 (`Player::Create()`)

### Creation Flow (Sequential Steps)
1. Initialize: clear feats, spells, skill ranks, set Level[0]=1
2. Options: optionally alter chargen options, check explore mode
3. Clear abilities
4. Set up reincarnation info or fresh creation
5. If OPT_ATTR_FIRST: roll attributes first
6. Gender selection (male/female/random)
7. Race selection (from loaded modules, excludes subraces)
8. Subrace selection (if any subraces exist for chosen race)
9. Gain racial stati, set monster ID
10. Generate name (from race name lists)
11. Handle SK_ANY racial skills
12. Class selection (excludes prestige and pseudo classes)
13. God selection (if class is religious)
14. If not OPT_ATTR_FIRST: roll attributes now
15. Grant perks (if used)
16. Alignment selection (filtered by class and god requirements)
17. AdvanceLevel() (first level)
18. Skill point allocation (SkillManager)
19. Calculate HP/Mana
20. Set hunger to SATIATED-10
21. Fire PRE(EV_BIRTH) events on race, class, god
22. Grant starting gear from race, class, "Universal Gear"
23. Optionally grant "Beginner's Kit"
24. Grant weapon for weapon focus feats
25. Handle excess items
26. Fire EV_BIRTH events
27. Learn spells (if applicable)
28. Choose domains (if applicable)
29. Final CalcValues()

### Explore Mode Detection
```cpp
bool isExploreMode(Player *p) {
    return p->Opt(OPT_BEGINKIT) ||
           p->Opt(OPT_MAX_MANA) ||
           p->Opt(OPT_MAX_HP) ||
           (p->Opt(OPT_EASY_INTUIT) == 1) ||
           (p->Opt(OPT_POWER_STATS) >= 2) ||
           (p->Opt(OPT_DIFFICULTY) < 2) ||
           (p->Opt(OPT_ELUDE_DEATH) == 4);
}
```

---

## Attribute Generation

**Source**: `Create.cpp` lines 912-1685

### AttrDice() Function
```
Roll N d6, take best 3:
    roll[0..N-1] = random(6) + 1 each
    find indices of 3 highest values
    return sum of those 3
```

### Method 0: 4d6 In Order
- Generate 5 sets of 7 attributes (STR, DEX, CON, INT, WIS, CHA, LUC)
- Each attribute: `AttrDice(4)` (best 3 of 4d6)
- Total filtered to range: `95 <= total <= 100` (minimum 100 rolls attempted)
- Player picks one of 5 sets
- Visual rolling animation for 500ms per set
- Rerolling puts game in Explore Mode

### Method 1: 4d6 + Perks
Same as Method 0, but each set includes random perks (2 for most races, 3 for humans, 1 for subraces).

### Method 2: Point Buy
Base: all attributes start at 8.

**Point budget by power setting**:
| OPT_POWER_STATS | Points |
|-----------------|--------|
| 0 (low) | 30 |
| 1 (standard) | 42 |
| 2 (high) | 54 |
| 3 (heroic) | 75 |

**Point costs per attribute value**:
```cpp
int8 PointCosts[] = { 0, 0, 0, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 8, 10, 13, 16 };
//                    0  1  2   3   4   5   6   7  8  9 10 11 12 13 14 15  16  17  18
```
Attributes range 3-18. Values below 8 give points back.

### Stat Total Range (Rolling Methods)
The `wanted` variable controls the target range:
| OPT_POWER_STATS | Target |
|-----------------|--------|
| 0 | 75 |
| 1 | 100 |
| 2 | 115 |
| 3 | 125 |

But the actual filter always uses `95-100` regardless (the `wanted` variable is set but the while loop hardcodes `tot < 95 || tot > 100`). This appears to be a bug or leftover from an earlier design.

---

## Perk System

**Source**: `Create.cpp` lines 995-1336

### Perk Type Weights
```cpp
static int16 PerkWeights[][2] = {
    { PERK_ABILITY,  10 },
    { PERK_SPELL,    5  },
    { PERK_TALENT,   15 },
    { PERK_RESIST,   10 },
    { PERK_FEAT,     25 },
    { PERK_ITEM,     30 },
    { PERK_IMMUNE,   5  },
};
```
Total weight: 100. Weighted random selection.

### Perks Per Race
- Humans: 3 perks per set
- Standard races: 2 perks per set
- Subraces (BaseRace set): 1 perk per set
- No race selected: 3 perks per set

### Perk Rerolling
- Rerolling with perks enabled triggers Explore Mode
- Warning message displayed on first reroll attempt
- Second press of 'x' proceeds with reroll

---

## Level Advancement

**Source**: `Create.cpp` lines 2205-2441 (`Player::AdvanceLevel()`)

### Advancement Flow
1. Check max level (MAX_CHAR_LEVEL)
2. Choose class to advance in (if multiclassed)
3. Validate:
   - Class level cap not exceeded
   - Not a fallen paladin advancing in paladin
   - Religious class requires a god
   - Alignment requirements met (class and god)
   - God requirements met (if class has ALLOWED_GODS list)
4. Increment `Level[c]`
5. Grant proficiencies from class
6. Attribute bonus every 4th level (OPT_ATTR_ON_LEVEL):
   - Max bonus: `5 + AbilityLevel(CA_INHERANT_POTENTIAL)`
7. Fire PRE(EV_ADVANCE) events on race, class, god, domains
8. `AddAbilities(ClassID[c], Level[c])` - class abilities for this level
9. `AddAbilities(RaceID, TotalLevel())` - racial abilities for total level
10. Fire EV_ADVANCE events
11. Grant feats:
    - Every 3rd total level OR level 1: `GainFeat(FT_FULL_LIST)`
    - Level 1 gets a SECOND feat (bonus starting feat)
12. Grant class skills (level 1 in class) and racial skills (level 1 total)
13. Roll HP:
    ```
    HD = tc->HitDie
    if Thaumaturge specialty: HD = 8
    OPT_MAX_HP:
        0 (random): max(random(HD)+1, HD/2)    // min half
        1 (half):   HD/2
        2 (full):   HD
    ```
14. Roll Mana (same structure with ManaDie)
15. God favour level bleedoff
16. Fire POST(EV_ADVANCE) events
17. Update tattoos
18. Disable reincarnation at level 5+

### Alignment Flags Checked
Class flags: `CF_LAWFUL, CF_CHAOTIC, CF_EVIL, CF_GOOD, CF_NONLAWFUL, CF_NONCHAOTIC, CF_NONEVIL, CF_NONGOOD`

---

## Experience System

**Source**: `Create.cpp` lines 1835-2043

### GainXP()
```
actual_xp = XP - (XP * XPPenalty()) / 100
```
Also handles:
- Prayer timeout decrement
- Polymorph tick tracking (removed after 20 ticks)
- Mana bleed (10% chance per tick if hMana >= 80)
- Listen retry cooldown
- Level-up notification

### LoseXP()
```
XP = max(0, XP - amount)
```

### KillXP() - Kill Experience

**Base XP by Challenge Rating**:
| CR | Base XP |
|----|---------|
| -6 | 10 |
| -5 | 15 |
| -4 | 20 |
| -3 | 25 |
| -2 | 35 |
| -1 | 50 |
| 0 | 75 |
| 1+ | 100 * CR |
| < -6 | 5 |

**Difficulty multiplier**:
- DIFF_EXPLORE: XP * 2
- DIFF_TRAINING: XP * 3/2

**Scaling by CR difference**:
```cpp
int16 Scale[] = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
                  125, 150, 175, 200, 250, 300, 400, 500, 600, 800 };
```
Index: `(kill_CR - player_ECL) + 9`, clamped to [0, 19].
- Same CR = 100% (index 9)
- Kill 1 CR higher = 125%
- Kill 9+ CR higher = 800%
- Kill 9 CR lower = 10%

**Slow advancement** (low-level characters):
```cpp
int16 SlowAdvance[] = { 100, 100, 100, 125, 150, 200, 300 };
nXP = (nXP * 100) / SlowAdvance[min(ChallengeRating(), 6)]
```

**Additional modifiers**:
- Was-friendly creatures: XP / 3
- Generated/summoned creatures: XP / (1 + generation_count)
- Summoned creatures: 0 XP
- Polymorph: ECL includes original monster CR

**Leader/companion sharing**: If creature has a leader, leader gets full XP. Diplomacy-tagged companions get 75% XP.

### XPPenalty() - Multiclass Penalty
```
Default penalty: 25%

No penalty if:
  - Has CA_VERSATILITY (human trait)
  - OPT_FAVOURED_CLASS == 1
  - Single-classed (no Level[1] or Level[2])
  - Highest-level class is a favoured class of the race
    (checked against TRACE(RaceID)->FavouredClass[0..2] and CF_FAVOURED flag)

Additional penalties:
  - SumStatiMag(XP_PENALTY) added
  - Alignment deviation: if (-alignLC) > 40 and TotalLevel >= 3: adds (alignLC + 40)
```

### NextLevXP()
```
ExperienceChart[Level[0] + Level[1] + Level[2] + 1]
```

---

## Studies System (Intensive Study)

**Source**: `Create.cpp` lines 42-52, 3360-3394

### Studies Table
```cpp
int16 Studies[9][4] = {
//  Study Index,      Class Ability,          Increase, Rate
    { STUDY_TURNING,  CA_TURNING,             2,        1 },
    { STUDY_SMITE,    CA_SMITE,               4,        1 },
    { STUDY_UNARMED,  CA_UNARMED_STRIKE,      2,        1 },
    { STUDY_SNEAK,    CA_SNEAK_ATTACK,         1,        2 },
    { STUDY_CASTING,  CA_SPELLCASTING,         1,        1 },
    { STUDY_BARDIC,   CA_LEGEND_LORE,          2,        1 },
    { STUDY_SHAPES,   CA_WILD_SHAPE,           2,        1 },
    { STUDY_MOUNT,    CA_SACRED_MOUNT,         3,        1 },
};
```

### Eligibility Formula
```
clev = TotalLevel()
mlev = (clev*4 + 4) / 5

For each study:
    if Abilities[class_ability] > 0
    AND rate * (Abilities[class_ability] + IntStudy[index] * increase) < mlev
    AND Abilities[class_ability] > IntStudy[index] * increase
    THEN eligible

STUDY_BAB special case:
    For each BAB type, sum levels in classes with AttkVal >= 100
    If warrior_levels > IntStudy[STUDY_BAB] AND GetBAB(type) < TotalLevel()
    THEN eligible
```

### Effect
Each Intensive Study feat trades a feat slot for one increment of the studied class ability, allowing a multiclass character to advance a specific class ability beyond their class level.

---

## Paladin Fall

**Source**: `Create.cpp` lines 2444-2473

When a paladin falls:
1. Set `isFallenPaladin = true`
2. Lose abilities: `CA_SACRED_MOUNT, CA_DIVINE_GRACE, CA_LAY_ON_HANDS, CA_AURA_OF_VALOUR`
3. Lose innate spells: Mount, Cure Disease, Magic Circle vs. Evil, Protection from Evil, Detect Evil
4. Lose turning levels: `CA_TURNING -= (paladin_level - 2)` if level >= 3
5. Remove all stati from paladin source

Paladin atonement (`PaladinAtone()`) is declared but not implemented.

---

## HasSkill() - Skill Possession

**Source**: `Create.cpp` lines 3583-3612

For Characters:
```
Check allies (if check_allies flag):
    Nearby friendly creatures within 6 tiles with LOS
Return true if:
    Race has skill OR
    Any class (with levels) has skill OR
    Has EXTRA_SKILL stati for skill
```

For Creatures (non-character):
```
Return true if:
    Has EXTRA_SKILL stati OR
    HasFeat(sk)   (skills stored in feat array for monsters)
```

---

## Weapon Skill System

**Source**: `Create.cpp` lines 3396-3463

### Character Weapon Skill
Checks in order:
1. Strength requirement (WT_STR1/2/3 flags): min STR = 5 + 8/4/2 per flag
2. WEP_SKILL stati for specific weapon
3. Armour proficiency feats (Light/Medium/Heavy/Shield)
4. Exotic weapons require explicit proficiency
5. General proficiency: `Proficiencies & weapon_group`

### Monster Weapon Skill
Returns highest applicable:
- FT_WEAPON_MASTERY: WS_MASTERY
- FT_WEAPON_SPECIALIST: WS_SPECIALIST
- FT_WEAPON_FOCUS: WS_FOCUSED
- Default: WS_PROFICIENT
- Exotic without feat: WS_NOT_PROF

---

## Porting Considerations

1. **SkillCheck multi-roll system** - Non-standard d20 extension. Some skills roll 2-3d20 and take best. Must implement the conditional rolling logic.
2. **Skill level calculation** - 16+ separate bonus categories that don't stack within category. Need careful tracking of bonus sources.
3. **MaxRanks progressive table** - Not linear OGL rules. Uses custom table allowing skill broadening at higher levels.
4. **Training bonus** - Incursion-specific. +1 per source (race/class), then +2 if any match (minimum +3 for class skills).
5. **Feat prerequisites DNF** - Complex boolean evaluation. Up to 3 OR clauses, each with up to 5 AND conditions.
6. **Exercise system** - Barely-succeeded checks train attributes. Skill-specific exercise columns and caps.
7. **Turn check formula** - Significantly different from SRD. Uses `(check * 750) / (resist * 100)` ratio with tiered effects.
8. **XP scaling** - 20-element scale table plus slow advancement table. Complex CR-difference calculation.
9. **Perk system** - Weighted random generation during character creation. 7 perk types with specific weights.
10. **Stat generation** - Rolling enforces 95-100 total range regardless of power setting. Point buy uses non-linear cost table.
11. **Devour system** - Complex resistance/attribute gain from eating monsters. Theology-aware.
12. **Legend Lore** - Progressive item identification with 7 knowledge tiers based on ability+INT-itemlevel formula.
