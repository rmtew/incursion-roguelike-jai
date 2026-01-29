# Skills, Feats & Abilities

**Source**: `Skills.cpp`, `Create.cpp`, `inc/Creature.h`, `inc/Defines.h`
**Status**: Architecture researched from headers

## Skills (SK_*, 49 types)

### Skill Categories
Skills follow d20/OGL rules. Each skill has an associated attribute:
- STR-based: Climb, Jump, Swim
- DEX-based: Balance, Escape Artist, Hide, Move Silently, Open Lock, Ride, Tumble, Use Rope
- CON-based: Concentration
- INT-based: Alchemy, Appraise, Craft, Decipher Script, Disable Device, Forgery, Knowledge (multiple), Search, Spellcraft
- WIS-based: Handle Animal, Heal, Intuition, Listen, Profession, Sense Motive, Spot, Survival, Wilderness Lore
- CHA-based: Bluff, Diplomacy, Disguise, Gather Information, Intimidate, Perform, Use Magic Device

### Skill Check Formula
```
d20 + skill ranks + attribute modifier + misc bonuses vs DC
```

### Skill Ranks
```cpp
int8 SkillRanks[SK_LASTSKILL];  // Character's invested ranks
uint16 SpentSP[6], BonusSP[6], TotalSP[6]; // Skill points per class
```

- Max ranks = character level + 3 (for class skills)
- Max ranks = (character level + 3) / 2 (for cross-class skills)
- `MaxRanks(sk)` - Calculate maximum ranks for skill
- `SkillLevel(n)` - Total skill level (ranks + modifiers)
- `SkillAttr(sk)` - Get associated attribute

## Class Abilities (CA_*, 143 types)

### Storage
```cpp
uint8 Abilities[CA_LAST];  // Level or boolean per ability
```

### Examples
CA_ANCESTRAL_MEMORY, CA_SNEAK_ATTACK, CA_TURN_UNDEAD, CA_WILD_SHAPE, CA_RAGE, CA_SMITE, CA_LAY_HANDS, CA_DIVINE_GRACE, CA_EVASION, CA_UNCANNY_DODGE, etc.

### Key Methods
- `HasAbility(n, inh)` - Check if creature has ability
- `AbilityLevel(n)` - Get ability level/count
- `GainAbility(ab, pa, sourceID, statiSource)` - Grant ability

## Feats (FT_*, 200+ types)

### Storage
```cpp
uint16 Feats[(FT_LAST/8)+1];  // Bitfield (1 bit per feat)
```

### Feat Categories (organized alphabetically in Defines.h)
FT_AB through FT_TUVWXYZ covering:
- Combat feats: Power Attack, Cleave, Great Cleave, Improved Initiative, Combat Reflexes
- Weapon feats: Weapon Focus, Weapon Specialization, Weapon Finesse
- Metamagic feats: Empower, Extend, Maximize, Quicken, Silent, Still
- Save feats: Great Fortitude, Iron Will, Lightning Reflexes
- Skill feats: Skill Focus, Alertness
- Special: Toughness, Dodge, Mobility, Spring Attack

### Feat Prerequisites
Complex prerequisite system using boolean logic:
```
Up to 3 OR clauses, each with up to 5 AND conditions.
Conditions check: feats, abilities, BAB, skills, CR, attributes,
caster level, weapon skills, proficiencies, attack bonuses, monster types.
```
- `FeatPrereq(n, fail_if_feat_requires_feat)` - Check prerequisites
- `HasFeat(n, inh, list)` - Check feat possession
- `GainFeat(list, param)` - Grant feat to character

## Character Creation (Create.cpp)

### Attribute Generation
- Multiple methods available (selected by statMethod)
- `RollAttributes()` - Generate base attributes
- BAttr[7] stores base values (STR, DEX, CON, INT, WIS, CHA, MOV)

### Level Advancement
- `AdvanceLevel()` - Level up process
- HP roll tracked: `hpRolls[3][MAX_CHAR_LEVEL]`
- Mana roll tracked: `manaRolls[3][MAX_CHAR_LEVEL]`
- Skill point allocation
- Feat selection (every 3rd level + class bonus feats)
- Class ability grants

### Multiclassing
- Up to 6 classes: `ClassID[6]`
- Levels per class: `Level[3]` (3 primary classes)
- XP penalty for imbalanced multiclassing

### Experience
- `XP`, `XP_Drained` - Current and drained XP
- `GainXP(xp)`, `LoseXP(xp)` - XP management
- `KillXP(kill, percent)` - XP from kills
- `NextLevXP()` - XP needed for next level
- `XPPenalty()` - Multiclass penalty

### Reincarnation
- `Reincarnate()` - Create reincarnated character
- `ReincarnationInfo` tracks previous lives

## Study System (STUDY_*, 10 types)

```
STUDY_CASTING(1) through STUDY_LAST(10)
```
Character study focuses for gaining expertise in areas.

## Porting Considerations

1. **Skill ranks** - Fixed-size array, straightforward
2. **Feat bitfield** - 200+ feats in packed uint16 array; use Jai bit operations
3. **Ability array** - Simple uint8 per ability
4. **Prerequisites** - Complex boolean logic needs careful port
5. **Multiclass** - Up to 6 classes with separate level tracking
6. **XP system** - Standard d20 progression
