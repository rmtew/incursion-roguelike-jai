# Social, Quest & NPC Systems

**Source**: `Social.cpp`, `Quest.cpp`, `Help.cpp`
**Status**: Fully researched (expanded 2026-01-30)

---

## Table of Contents

1. [Social Interaction Flow](#social-interaction-flow)
2. [doSocialSanity() Validation](#dosocialsanity-validation)
3. [Hostility System](#hostility-system)
4. [Social Modifier Calculation](#social-modifier-calculation)
5. [Comparative Strength](#comparative-strength)
6. [Cow (Intimidation)](#cow-intimidation)
7. [Offer Terms](#offer-terms)
8. [Quell (Diplomacy Conflict Resolution)](#quell-diplomacy-conflict-resolution)
9. [Enlist (Recruitment)](#enlist-recruitment)
10. [Companion System (PHD)](#companion-system-phd)
11. [MakeCompanion() Flow](#makecompanion-flow)
12. [Barter System](#barter-system)
13. [Shop Pricing](#shop-pricing)
14. [Fast Talk](#fast-talk)
15. [Distract](#distract)
16. [Taunt](#taunt)
17. [Greet](#greet)
18. [Request](#request)
19. [Order (Companion Commands)](#order-companion-commands)
20. [Surrender](#surrender)
21. [Dismiss](#dismiss)
22. [canTalk() Logic](#cantalk-logic)
23. [Perceived Monster Type (isPMType)](#perceived-monster-type-ispmtype)
24. [Money System](#money-system)
25. [Quest System](#quest-system)
26. [Help / Monster Memory](#help-monster-memory)
27. [Porting Considerations](#porting-considerations)

---

## Social Interaction Flow

### PreTalk Menu

`Creature::PreTalk(EventInfo &e)` presents available social options. The menu is filtered per-option based on the target's state:

| Event | Code | Available When |
|-------|------|----------------|
| EV_GREET (62) | G | Target NOT summoned by actor |
| EV_BARTER (56) | B | Not hostile, not summoned, not M_NOHANDS, and (actor has SK_DIPLOMACY or CHA >= 13 or target has M_SELLER) |
| EV_COW (57) | C | Target hostile, actor has SK_INTIMIDATE, target not AFRAID |
| EV_DISMISS (58) | D | Target friendly to actor |
| EV_DISTRACT (59) | D | Target not friendly, target not DISTRACTED |
| EV_ENLIST (60) | E | Target not hostile AND not friendly (neutral) |
| EV_FAST_TALK (61) | F | Target hostile, actor has SK_BLUFF |
| EV_TERMS (177) | O | Target hostile AND target AFRAID |
| EV_ORDER (63) | O | Target friendly |
| EV_QUELL (64) | Q | Target hostile |
| EV_REQUEST (65) | R | Target not hostile AND not friendly (neutral) |
| EV_SURRENDER (66) | S | Target hostile, target NOT AFRAID |
| EV_TAUNT (67) | T | Target not friendly, target not ENRAGED |

**Non-talkable target shortcut**: If target is a creature but cannot talk, and is friendly to actor, the system auto-selects EV_ORDER (for animal companions that can receive orders but cannot converse).

**Endgame override**: `checkEndgameStuff()` intercepts social events when the target's party includes the unique NPC "Murgash, the Goblin King" -- all social actions redirect to Murgash, except EV_SURRENDER which rethrows.

---

## doSocialSanity() Validation

`bool Creature::doSocialSanity(int16 ev, Creature *cr)` validates that a social interaction can proceed. Returns false to abort. Checks in order:

### 1. Speaker Ability
- If `!canTalk(cr)`: check telepathy. If `AbilityLevel(CA_TELEPATHY) >= DistFrom(cr)`, proceed telepathically. Otherwise abort: "You can't talk in this form."

### 2. Line of Fire
- Checks `m->LineOfFire(x,y,cr->x,cr->y,this)` for same-map actors.
- Telepathy can bypass solid barriers.
- "You cannot talk though solid barriers."

### 3. Target Can Respond
- **Exceptions**: EV_DISTRACT and EV_ORDER skip this check (you can distract/order non-speaking creatures).
- Otherwise, target must be able to `canTalk(this)`, or actor must have telepathy and target must be `MA_SAPIENT`.

### 4. Silence Field
- `m->FieldAt(x,y,FI_SILENCE)` blocks all social actions: "You can't talk in a region of magical silence."

### 5. Hiding
- If actor is HIDING, prompts "Confirm reveal yourself by talking?" -- reveals on yes, aborts on no.

### 6. Sleeping Target
- Prompts to wake. Deep sleep types (SLEEP_PSYCH, SLEEP_DEEP, SLEEP_FATIGUE) cannot be woken: "The <Obj> seems to be in a very deep slumber."
- Normal sleep: `cr->Awaken(-1)`.

### 7. Enraged Target
- ENRAGED status blocks: "<He:Obj>'s too furious to talk right now."

### 8. Paralyzed Target
- If actor has telepathy in range, proceed. Otherwise: "Being paralyzed, the <Obj> really isn't a great conversationalist at the moment."

### 9. Telepathy Notification
- If any telepathy bypass was used: "You speak with the <Obj> telepathically."

### 10. Stunned/Confused (conditional)
- Blocked EXCEPT for EV_COW and EV_DISTRACT.
- Stunned: "The <Obj> staggers but does not respond."
- Confused: "The <Obj> babbles incoherantly in response."

### 11. ENEMY_TO Check (specific events only)
- Only for: EV_TERMS, EV_QUELL, EV_COW, EV_SURRENDER, EV_REQUEST.
- Iterates ENEMY_TO stati. If the target matches (by MType or handle), the interaction is blocked with event-specific messages:
  - EV_TERMS: "frightened, but too repellant"
  - EV_QUELL/EV_REQUEST: "will hear no reason from the likes of you"
  - Default: "growls at you with an instinctive hate"

---

## Hostility System

### Hostility Structure (from Target.h)

```
HostilityQual: Neutral, Enemy, Ally
HostilityQuant: Apathy(0), Minimal(1), Tiny(2), Weak(10), Medium(20), Strong(30)
```

### HostilityWhyType Enumeration
Tracks WHY hostility exists:
- `HostilityDefault` - baseline
- `HostilityFeud` - racial enmity (e.g., MA_ELF vs MA_DROW)
- `HostilityMindless` - M_MINDLESS creatures
- `HostilityPeaceful` - MS_PEACEFUL flag
- `HostilityGood` - good-on-good friendship
- `HostilityOutsider` - aligned outsider conflicts
- `HostilityDragon` - chromatic vs metallic
- `HostilitySmite` - good smites evil
- `HostilityLeader` / `HostilityMount` / `HostilityDefendLeader`
- `HostilityYourLeaderHatesMe` / `HostilityYourLeaderIsOK`
- `HostilityParty` - same PartyID
- `HostilityFlag` - M_HOSTILE monster flag
- `HostilitySolidarity` - racial solidarity
- `HostilityEID` - magic item effects (vermin friendship, aggravate)
- `HostilityTarget` - personal feelings about specific creature
- `HostilityFood` - carnivores eating adventurers
- `HostilityEvil` - evil attacks weaker things
- `HostilityAlienation` - animals in dungeon, elementals on prime
- `HostilityCharmed` / `HostilityCommanded`

### Key Functions

```cpp
// Player delegates to Monster's perspective
bool Creature::isHostileTo(Creature *c) {
    if (isPlayer() && c->isMonster())
        return c->isHostileTo(this);
    return (ts.SpecificHostility(this, c).quality == Enemy);
}

bool Creature::isFriendlyTo(Creature *c) {
    if (c == this) return true;
    if (isPlayer() && c->isMonster())
        return c->isFriendlyTo(this);
    return (ts.SpecificHostility(this, c).quality == Ally);
}
```

**Key insight**: `isHostileTo` and `isFriendlyTo` delegate to the target's perspective when the Player checks a Monster. The target system has two layers:
- `RacialHostility()` - uses only MA_* types and monster templates
- `SpecificHostility()` - adds stati, abilities, charmed, personal feelings, partyID

### DY_* Flags (local to Social.cpp)
```cpp
#define DY_HOSTILE    0x0001
#define DY_CHARMED    0x0002
#define DY_DOMINATED  0x0004
#define DY_ANGERED    0x0008
#define DY_STRUCK     0x0010
```
These appear to be early design flags that are not used in the final Social.cpp code (they are defined but never referenced in the file).

---

## Social Modifier Calculation

`int16 Creature::getSocialMod(Creature *cr, bool inc_str)` computes a modifier applied to social skill checks. Stored in global `modBreakdown` as a human-readable string.

### Racial Solidarities (same race bonus)
| Race | Modifier |
|------|----------|
| MA_LIZARDFOLK | +6 |
| MA_ILLITHID | +4 |
| MA_DWARF | +4 |
| MA_ELF | +2 |
| MA_CELESTIAL | +6 |
| MA_DEVIL | +3 |
| MA_KOBOLD | +2 |
| MA_GNOME | +2 |
| MA_HALFLING | +1 |
| MA_GOBLINOID | +1 |
| MA_DROW | **-2** (distrust among drow) |

### Racial Enmities/Affinities (cross-race modifiers)
| Race A | Race B | Modifier | Reciprocal |
|--------|--------|----------|------------|
| MA_LIZARDFOLK | MA_DRAGON | +3 | Yes |
| MA_DWARF | MA_ELF | -1 | Yes |
| MA_HUMAN | MA_HALFLING | +1 | Yes |
| MA_DROW | MA_ELF | -6 | No |
| MA_DROW | MA_DWARF | -6 | No |
| MA_DROW | MA_DEMIHUMAN | -4 | No |
| MA_KOBOLD | MA_GNOME | -6 | No |
| MA_KOBOLD | MA_DEMIHUMAN | -4 | No |
| MA_ORC | MA_ELF | -4 | No |
| MA_ORC | MA_DWARF | -4 | No |
| MA_DWARF | MA_GIANT | -4 | Yes |
| MA_GOBLIN | MA_HALFLING | -3 | No |
| MA_GOBLINOID | MA_DEMIHUMAN | -2 | Yes |
| MA_GOOD | MA_CELESTIAL | +2 | No |
| MA_EVIL | MA_CELESTIAL | -8 | No |
| MA_LAWFUL | MA_DEVIL | +4 | No |
| MA_CHAOTIC | MA_DEVIL | -4 | No |
| MA_ALL | MA_DEMON | -10 | Yes |
| MA_ABERRATION | MA_DEMIHUMAN | -4 | No |
| MA_ELF | MA_DROW | -4 | No |
| MA_DWARF | MA_EARTH | +2 | Yes |
| MA_LIZARDFOLK | MA_WATER | +2 | Yes |
| MA_ELF | MA_FAERIE | +2 | Yes |
| MA_UNDEAD | MA_NLIVING | -4 | No |
| MA_NLIVING | MA_UNDEAD+MA_EVIL | -4 | No |

**Note**: Only one racial modifier applies (first match wins via goto DoneRaceMod). Uses `isPMType()` which respects Bluff-based disguise.

### Alignment Modifiers (after racial, only one applies)
| Condition | Modifier |
|-----------|----------|
| Actor perceived evil, target not evil | -6 |
| Actor is evil AND perceived evil | -2 |
| Target lawful, actor perceived chaotic | -2 |
| Target good, actor perceived good | +2 |

### Special Modifiers
- **Alluring feat**: +3 if opposite gender AND compatible species group (demihuman-to-demihuman, goblinoid-to-goblinoid, or reptilian-to-reptilian)
- **Charmed**: +4 if target has CHARMED(CH_CHARM) by actor
- **SOCIAL_MOD stati**: Iterates all SOCIAL_MOD stati on actor. Each can be filtered by MType. Non-mundane effects are reduced by target's enchantment save bonus. Mind-immune targets ignore non-mundane social mods.
- **Comparative Strength** (if `inc_str` is true AND target is not MA_GOOD): adds `getComparativeStrengthMod()` result.

---

## Comparative Strength

`int16 Creature::getComparativeStrengthMod(Creature *targ)` computes relative party power.

### Algorithm
1. Iterate all creatures friendly to actor that target can perceive (plus actor themselves even if unseen). Sum their XCR values.
2. Iterate all creatures friendly to target (visible or not). Sum their XCR values.
3. HP scaling: Each creature's XCR is scaled by `(cHP*100/mHP)/100` unless they have the "Adamant Facade" effect (which hides weakness).
4. Convert both XCR sums back to CR via `XCRtoCR()`.
5. Return `yourCR - theirCR`.

**Key insight**: The comparison is asymmetric -- the actor's team is what the TARGET can see, but the target's team counts everything (even hidden allies). This means hidden enemies of the target count against the actor's intimidation.

### XCR/CR Conversion
```cpp
inline int32 XCR(int16 CR) {
    if (CR >= 1) return (CR+3)^3;  // cubic
    // Special cases for CR 0 to -8:
    // 0->55, -1->44, -2->33, -3->26, -4->22, -5->18, -6->15, -7->12, -8->10
    // CR < -8 -> 6
}

inline int16 XCRtoCR(int32 XCR) {
    // Reverse lookup using precomputed cube table
    // Table: {10,12,15,18,22,26,33,44,55, 4^3,5^3,...39^3}
    // Returns index-8 (so index 0 = CR -8)
}
```

---

## Cow (Intimidation)

`EvReturn Creature::Cow(EventInfo &e)` -- Intimidate hostile creatures into fear.

### Preconditions
- `doSocialSanity(EV_COW)` passes
- Not already TRIED (keyed `SK_INTIMIDATE + EV_COW*100`)
- Target NOT immune to fear (`ResistLevel(AD_FEAR) != -1`)

### Alignment Impact
- If target is NOT evil AND actor is NOT an orc or barbarian: `AlignedAct(AL_NONCHAOTIC, 3, "intimidation")`

### DC Calculation
```
Base DC = 10

If group cow (target has allies on map):
    DC += 10
    DC += max(0, BestCR * 3)
    where BestCR = highest (ChallengeRating + SAVE_BONUS[SN_FEAR]) among group

If single target:
    DC += max(0, target.ChallengeRating * 3)
```

### Skill Check
- `SkillCheck(SK_INTIMIDATE, CheckDC, true, smod, modBreakdown)`
- `smod = getSocialMod(target, true)` (includes comparative strength)

### Results by Margin
| Result vs DC | Duration | Effect |
|-------------|----------|--------|
| > DC+10 | Permanent (dur=0) | AFRAID(FEAR_PANIC), target drops ALL non-worn-armor gear at feet, XP=120(good)/100 |
| > DC+5 | Semi-permanent (dur=-2) | AFRAID(FEAR_PANIC), target drops one random good item as tribute, XP=50 |
| <= DC+5 | 3d6 + intimidate level | AFRAID(FEAR_PANIC), DO_NOT_PICKUP, XP proportional |
| Failed | -- | "isn't impressed with your might" |

**All affected creatures** gain DO_NOT_PICKUP stati to prevent reclaiming dropped gear. If duration is permanent (0), `FocusCheck(this)` is called. Time cost: 30 Timeout units.

---

## Offer Terms

`EvReturn Creature::OfferTerms(EventInfo &e)` -- offer surrender terms to already-frightened creatures.

### Preconditions
- Target must have "natural fear" (FEAR_MANA, FEAR_HP, FEAR_PANIC, or FEAR_COWED), NOT FEAR_SKIRMISH or magical fear
- Not already TRIED (keyed `SK_DIPLOMACY + EV_TERMS*100`)

### Alignment Impact
- If target is not evil, has M_IALIGN flag, and was not previously friendly: `AlignedAct(AL_GOOD, 3, "offering terms")`
  - Note: The code has a likely bug -- it checks `!e.EVictim->isMType(MA_EVIL)` then uses `e.EVictim->isMType(MA_EVIL) ? 1 : 3` which always evaluates to 3.

### DC Calculation
```
Base DC = 5

If group:
    DC += 10
    DC += max(0, BestCR)  // note: just CR, not CR*3 like Cow
If single:
    DC += max(0, target.ChallengeRating * 2)
```

### Results
| Result vs DC | Effect |
|-------------|--------|
| > DC+10 | Neutral, drops ALL non-worn-armor gear, XP=120(good)/100 |
| > DC+7 | Neutral, drops one random good tribute item |
| > DC+5 | Neutral (dur=0, permanent), DO_NOT_PICKUP |
| > DC | Neutral (dur=-2), DO_NOT_PICKUP |
| Failed | "refuses your terms" |

Creatures that accept terms: `TurnNeutralTo`, `MS_PEACEFUL` flag set, 50 Timeout.

---

## Quell (Diplomacy Conflict Resolution)

`EvReturn Creature::Quell(EventInfo &e)` -- resolve hostility through diplomacy.

### Preconditions
- Requires SK_DIPLOMACY skill
- Target must be hostile
- Not already TRIED (keyed `SK_DIPLOMACY + EV_QUELL*100`)

### Skill Selection
- Default: SK_DIPLOMACY
- If racial enemy (target has innate hostility toward actor): diplomatic resolution. If actor is NOT evil target: `AlignedAct(AL_GOOD, 3, "resolving conflict")`
- If damage-based hostility (target was hit by actor): this becomes "exploitation" using SK_BLUFF. Requires confirmation. `AlignedAct(AL_EVIL, 1, "exploitation")` and `Transgress(FIND("Essiah"), 5, false, "exploitation")`.

### DC Calculation
```
Base DC = 15 + max(0, target.ChallengeRating) * 3

If target was damaged by actor:
    DC += 5 + ((damage * 10) / target.maxHP)

Tribute discount (-7 DC) if:
    target is (goblinoid OR outsider OR illithid OR dragon) AND evil
    AND actor has a good inventory item worth 100+ target's CR
```

### Tribute Mechanic
On success with DC margin < 10 and tribute discount was active:
1. First try SK_BLUFF vs `11 + target.SkillLevel(SK_APPRAISE)` to avoid paying
2. If bluff fails, target demands a random good item from actor's inventory
3. Player can accept (item transferred, conflict resolved) or refuse (treated as failure)

### Success
- All creatures in target's party: `TurnNeutralTo(actor)`
- XP: 100 (good actor) or 50 (non-good)
- Wisdom exercise: `Exercise(A_WIS, random(4)+1, EWIS_PERSUADE, 25)` on attempt regardless of result

### TRIED Tracking
All creatures in target's PartyID get TRIED stati, preventing re-attempts on the whole group.

---

## Enlist (Recruitment)

`EvReturn Creature::Enlist(EventInfo &e)` -- recruit neutral creatures.

### Preconditions
- Target must be Monster, actor must be Player
- Not already tried (keyed `SK_DIPLOMACY + EV_ENLIST*100`)
- Target not aquatic (unless amphibious)
- Target not CHARMED (must choose freely; use Request for charmed)
- PHD budget check: `MaxGroupCR(PHD_PARTY) - GetGroupCR(PHD_PARTY, target.CR) >= 0`

### Alignment Impacts
- Evil target: `AlignedAct(AL_NONGOOD, 3, "allying with evil")`
- Chaotic target (unless both good): `AlignedAct(AL_NONLAWFUL, 2, "allying with chaos")`
- Lawful non-good target: `AlignedAct(AL_NONCHAOTIC, 2, "allying with law")`

### Rejoin Mechanic
If target was previously dismissed (has TRIED for `SK_DIPLOMACY + EV_DISMISS*100`):
- If dismissal was amicable (Mag=1): auto-rejoin, skip DC check
- If dismissal was bitter (Mag=0): refuses

### Alignment Refusal
Certain creature types refuse based on alignment incompatibility:
- Evil perceived actor + good target: always refuses
- For dragons, outsiders, M_IALIGN creatures, and Murgash:
  - Good perceived actor + evil target: refuses
  - Chaotic perceived actor + lawful target: refuses
  - Lawful perceived actor + chaotic target: refuses

### DC Calculation
```
If target has a CLASS-type template: DC = 15
Else if MA_ADVENTURER: DC = 20
Else: DC = 25

DC += max(0, target.ChallengeRating * 3)
```

### DC Reductions
- **Perform skill**: If `SkillLevel(SK_PERFORM) >= 7`: DC -= (SkillLevel(SK_PERFORM) - 5) / 2
- **Appraise skill**: If `SkillLevel(SK_APPRAISE) >= 7`: DC -= (SkillLevel(SK_APPRAISE) - 5) / 2

### Skill Check
- `SkillCheck(SK_DIPLOMACY, CheckDC, true, smod, modBreakdown)`
- `smod = getSocialMod(target, false)` (no comparative strength for recruitment)

### On Success
- `MakeCompanion(player, PHD_PARTY)`
- Time cost: 50 Timeout

---

## Companion System (PHD)

PHD = "Party Hit Dice" -- the budget system for controlling companions.

### Pool Types
```cpp
#define PHD_PARTY    1  // Generic NPC allies (recruited via Enlist)
#define PHD_MAGIC    2  // Dominated or Summoned monsters
#define PHD_ANIMAL   3  // Ranger/Druid animal companions
#define PHD_COMMAND  4  // Cleric's Commanded Undead
#define PHD_UNDEAD   5  // Necromancer Undead Pool
#define PHD_FREEBIE  6  // Does not count toward any PHD
```

### MaxGroupCR() by Pool Type
```
PHD_PARTY:   TotalLevel + Mod(A_CHA) + diplomacy_bonus + leadership_bonus + BONUS_PHD
             where diplomacy_bonus = max(0, (SkillLevel(SK_DIPLOMACY) - 5) / 5 * 2)
             where leadership_bonus = HasFeat(FT_LEADERSHIP) ? 3 : 0

PHD_MAGIC:   max(0, (CasterLev + TotalLevel) / 2) + CA_COMMAND_AUTHORITY + BONUS_PHD

PHD_ANIMAL:  -10 if no CA_ANIMAL_COMP ability
             Otherwise: max(1, AbilityLevel(CA_ANIMAL_COMP)) + BONUS_PHD

PHD_COMMAND: -10 if no CA_COMMAND ability
             Otherwise: max(1, HighStatiMag(COMMAND_ABILITY)) + CA_COMMAND_AUTHORITY + BONUS_PHD

PHD_UNDEAD:  HighStatiMag(BONUS_PHD, PHD_UNDEAD)  // entirely from stati bonuses
```

### GetGroupXCR() -- Current Group Cost
Iterates all Monsters on the map that are led by the player. For each:
1. Skip illusions and NO_PHD creatures
2. Skip EF_XSUMMON summoned creatures
3. Classify into pool type:
   - CHARMED(CH_DOMINATE) or SUMMONED -> PHD_MAGIC
   - CHARMED(CH_COMMAND) -> PHD_COMMAND
   - MA_ANIMAL -> PHD_ANIMAL
   - MA_UNDEAD -> PHD_UNDEAD
   - Otherwise -> PHD_PARTY
4. Skip if classified pool != requested pool
5. Add `max(10, (CR+2)^3)` to running total

### Pool Overflow
The PHD_PARTY pool absorbs overflow from other pools:
- If PHD_ANIMAL group > MaxGroupCR(PHD_ANIMAL), overflow goes to PHD_PARTY
- Same for PHD_MAGIC and PHD_COMMAND overflow -> PHD_PARTY
- PHD_UNDEAD overflow -> PHD_MAGIC (necromancers can use magic pool for undead)

### GetGroupCR (convenience)
```cpp
int16 GetGroupCR(int16 CompType, int16 AddCR=0) {
    return XCRtoCR(GetGroupXCR(CompType, AddCR));
}
```

### FixSummonCR()
Used when summoning: decrements the requested CR until the creature fits within the PHD budget. Also accounts for overflow into PHD_PARTY pool.

---

## MakeCompanion() Flow

`bool Monster::MakeCompanion(Player *p, int16 CompType)` -- converts a monster to a companion.

### PHD Check
1. If creature has EF_XSUMMON summoned effect: skip PHD check
2. If CompType == PHD_FREEBIE: grant NO_PHD stati, skip check
3. If illusion: skip check
4. Otherwise: compute remaining PHD budget
   - For non-PARTY types, also adds surplus from PHD_PARTY pool

### Overflow Failure Handling (by CompType)
| CompType | On PHD Exceeded |
|----------|----------------|
| PHD_UNDEAD | Silent failure (return false) |
| PHD_ANIMAL | "You don't feel you can control that many animals" |
| PHD_MAGIC | Will save (DC 15+CR) to pacify instead; failure = breaks free |
| PHD_COMMAND | Terrify instead (AFRAID), remove CHARMED |
| Default | Return false |

### Post-PHD Setup
1. Add player as TargetSummoner in target system
2. Retarget the companion
3. If player has OPT_WAIT_FOR_PETS: give OrderWalkNearMe
4. If CompType != PHD_MAGIC: set PartyID = player's PartyID

### Heroic Quality
If creature is MA_ADVENTURER, not HEROIC_QUALITY, not undead, not summoned/illusory, and CompType is PHD_PARTY:
- Gain HEROIC_QUALITY stati
- Gain +20 cHP bonus
- "You sense a certain heroic quality about the <Obj>..."

### Cleanup
1. Remove banned ally spells (`alliesShouldntCast[]`)
2. `CalcValues()`
3. `IdentifyMon()` -- auto-identify the companion's monster type
4. Identify all templates on the companion
5. All existing allied creatures: remove this companion from their target lists and retarget

### InitCompanions()
Called at game start for Player:
- **Paladins** get a mount:
  - Drow/Lizardfolk: "riding lizard"
  - Gnomes: "riding dog"
  - Small races: "pony"
  - Default: "horse"
  - Mount gets PHD_ANIMAL type and a random animal name
- Fires `EV_INIT_COMP` event on the player's class resource

---

## Barter System

`EvReturn Creature::Barter(EventInfo &e)` -- initiate trade.

### Access Control
- If target has M_SELLER flag: always proceed to barter UI
- If actor is perceived evil AND target is not evil: "no desire to trade"
- Check TRIED stati (keyed `EV_BARTER*100 + SK_DIPLOMACY`):
  - Mag=1: proceed (previously passed diplomacy check)
  - Mag=0: refuse (previously failed)
- If social modifier < 0 AND not M_SELLER:
  - Attempt `SkillCheck(SK_DIPLOMACY, 10 - mod*2, true)` to persuade
  - Success: set TRIED=1, proceed
  - Failure: set TRIED=0, "no desire to trade"

### Barter UI
Delegates to `thisp->MyTerm->BarterManager(e.EVictim)` -- the terminal's barter interface.
Time cost: 30 Timeout.

---

## Shop Pricing

`int32 Item::getShopCost(Creature *Buyer, Creature *Seller)` computes item prices.

### Base Cost Calculation
1. Start with `TITEM(iID)->Cost`
2. **Plus-priced items**: If item has ITEM_COST list, use `priceList[GetInherentPlus()] * 100`
3. **Spellbooks**: Sum of `max(200, 150 * spell_level)` per spell
4. **Scrolls/Potions**: `base + (effect_level + 3) * multiplier * 10` where multiplier is 50 for potions, 20 for scrolls
5. **Wands**: `base + 250 * ItemLevel^2`
6. **Magical items**: If has effect or inherent plus:
   - Check ITEM_COST list on effect
   - Otherwise use default cost table by item level (0-20):
     ```
     {500, 1000, 2000, 3000, 4000, 6000, 8000, 12000, 16000, 24000,
      36000, 48000, 56000, 75000, 102000, 128000, 256000, 512000,
      1000000, 1500000, 2000000}
     ```
   - Weapons/Armor/Shields/Bows: multiply by 400 (effect) or 160 (inherent)
   - Other: multiply by 70
7. Multiply by quantity
8. Divide by 100 (convert from copper to gold)
9. **Divide by 3** (sell price is 1/3 of base)

### Price Markup by Diplomacy + Social Mod

The markup percentage is looked up in a table indexed by `Buyer.SkillLevel(SK_DIPLOMACY) + getSocialMod(Seller, false)`, clamped to [-10, +30].

**Shop Prices** (M_SELLER vendors) -- percentage markup:
```
Index -10 to -6:  5000%, 4750%, 4500%, 4250%, 4000%
Index  -5 to -1:  3750%, 3500%, 3250%, 3000%, 2750%
Index   0 to +4:  2500%, 2250%, 2000%, 1500%, 1000%
Index  +5 to +9:   900%,  800%,  700%,  600%,  500%
Index +10 to +14:  450%,  400%,  350%,  300%,  250%
Index +15 to +19:  225%,  200%,  190%,  180%,  170%
Index +20 to +24:  160%,  155%,  150%,  145%,  140%
Index +25 to +30:  135%,  130%,  125%,  123%,  122%, 120%
```

**Barter Prices** (non-seller NPCs) -- percentage markup:
```
Index -10 to -6:  500%, 450%, 400%, 350%, 300%
Index  -5 to -1:  275%, 250%, 225%, 200%, 175%
Index   0 to +4:  150%, 130%, 110%, 100%, 100%
Index  +5 to +9:  100%,  95%,  90%,  85%,  80%
Index +10 to +14:  75%,  70%,  68%,  66%,  64%
Index +15 to +19:  62%,  60%,  58%,  56%,  54%
Index +20 to +24:  52%,  50%,  48%,  46%,  44%
Index +25 to +30:  42%,  40%,  38%,  36%,  34%, 30%
```

**Companion discount**: If seller's leader is the buyer, add +10 to index (for barter prices).

**Note**: Shop prices are always >= 120% (seller always profits). Barter prices can go below 100% at high skill, meaning NPCs might give you items for less than "value".

### InitShopkeeper()
```cpp
Creature * InitShopkeeper(rID mID, int32 gold) {
    // Creates monster, CalcValues, grants gear, gives gold coins
    // Removes cursed items from shop inventory
    // Clears IF_CURSED and IF_BLESSED flags on all items
}
```

---

## Fast Talk

`EvReturn Creature::FastTalk(EventInfo &e)` -- bluff a hostile creature into hesitating.

### Preconditions
- `doSocialSanity(EV_FAST_TALK)` passes
- Not already TRIED (keyed `SK_BLUFF + EV_FAST_TALK*100`, temporary 30-turn duration)
- Actor must have SK_BLUFF

### DC Calculation
```
BluffDC = 10 + target.ChallengeRating + max(target.SK_APPRAISE, target.SK_CONCENT)
```

### Effect
- On success: target loses `LastSkillCheckResult * 2` Timeout (wastes their turns)
- On failure: "isn't fooled"
- Either way: actor gains 10 Timeout

### Flavor
Random text from 4 variants (grab shoulders, wild story, ramble madly, speak rapidly).

---

## Distract

`EvReturn Creature::Distract(EventInfo &e)` -- bluff to distract enemies.

### Preconditions
- Requires SK_BLUFF
- Target not friendly, not already DISTRACTED

### DC Calculation
```
Resistance = max(target.SK_CONCENT, target.A_SAV_WILL) + accumulated retry bonus

If group distract:
    CheckDC = 15 + BestRes (highest resistance among all hostile/allied-to-target)
If single:
    CheckDC = 10 + targetRes
```

### Retry Penalty
Each failed distraction attempt adds +5 to TRIED modifier on target.
Each successful distraction adds +2.

### Effect
- On success: targets gain `DISTRACTED` stati for 2 turns, with magnitude = margin of success
- Must have LineOfSight from actor to each affected creature
- Time cost: 20 Timeout

---

## Taunt

`EvReturn Creature::Taunt(EventInfo &e)` -- provoke enemies into rage.

### Preconditions
- Requires SK_BLUFF
- Not already TRIED (keyed `SK_BLUFF + EV_TAUNT*100`, temporary -2 duration)

### DC Calculation
```
Base DC = 15

If group taunt:
    DC += 5 + BestWill * 2  (best A_SAV_WILL among target's allies)
If single:
    DC += target.A_SAV_WILL * 2
```

### Effect
- On success: targets gain `ENRAGED` stati for `SkillLevel(SK_BLUFF)` turns, with actor as source
- Time cost: 30 Timeout

---

## Greet

`EvReturn Creature::Greet(EventInfo &e)` -- chat with non-hostile creatures.

### Flow
1. Hostile targets just say they want to kill you
2. Non-hostile: "You chat with the <Obj>."
3. **Random bonus** (once per creature, player-only): Roll `random(300) / max(1, SK_DIPLOMACY + socialMod)` and check result:

| Roll Result | Bonus |
|-------------|-------|
| 1 | "tells you about local dungeon layout" -- casts Magic Mapping |
| 2 | Warns about strongest hostile creature on level (by CR) |
| 3 | Gives a hint: identifies a random magic item by name ("I've heard that X are Y") |
| 4 | "heartening war stories" -- restore 2 FP (fatigue points) |
| other | No bonus |

**Note**: Higher diplomacy + social mod makes the divisor larger, making low roll results (1-4) more likely. The bonus is gated by the TRIED stati to prevent farming.

Time cost: 25 Timeout.

---

## Request

`EvReturn Creature::Request(EventInfo &e)` -- ask neutral NPCs for favors.

### Skill Selection
Player can choose between Diplomacy, Intimidate, or Bluff:
- If SK_INTIMIDATE > SK_DIPLOMACY: offer Intimidate (with confirmation showing both modifiers)
- Else if SK_BLUFF > SK_DIPLOMACY: offer Bluff
- Default: SK_DIPLOMACY

### Alignment Impacts
- Using SK_INTIMIDATE on non-evil: `AlignedAct(AL_NONCHAOTIC|AL_LAWFUL, 3, "coercion")`
- Using SK_BLUFF on non-evil: `AlignedAct(AL_NONLAWFUL|AL_CHAOTIC, 3, "treachery")`

### Request Types and Base DCs
| Request | Code | Base DC |
|---------|------|---------|
| Follow After Me | OrderWalkNearMe | 10 |
| Fight Against Enemy | OrderAttackTarget | 15 |
| Go To Location | OrderWalkToPoint | 20 |
| Stop Fighting | OrderBeFriendly | 15 |
| Take Watches With Me | OrderTakeWatches | 10 |
| Give Item to Me | OrderGiveMeItem | 20 |

### DC Modifiers
```
If Intimidate and target is fear-immune: auto-fail

If group persuasion:
    DC += 10
    DC += BestCR * 2  (+ fear save bonus if using Intimidate)
If single:
    DC += max(0, target.CR * 2)  (+ fear save bonus if Intimidate)

DC += RETRY_BONUS (increases +3 per attempt)
```

### Give Item Constraints
- Must be beside target
- M_SELLER targets refuse
- IF_PROPERTY items (personal belongings) cannot be requested

### Failure Consequences
- **Diplomacy failure**: "You fail to persuade" -- no hostility change
- **Bluff/Intimidate failure**: Target (and allies) turn hostile + TRIED(EV_REQUEST, -2 turn duration)

### Success
- Each request type gives appropriate orders via `ts.giveOrder()`
- Follow/GoTo/Attack orders grant DIPLOMACY_TAG stati (-2 turn duration) for XP sharing: "You receive half the experience for his kills"

Time cost: 50 Timeout.

---

## Order (Companion Commands)

`EvReturn Creature::Order(EventInfo &e)` -- give orders to allied creatures.

### Available Orders
| Order | Code | Description |
|-------|------|-------------|
| Retarget | TargetMaster | Forget orders and re-evaluate |
| Stand Still | OrderStandStill | Stop moving |
| Travel In Front | OrderWalkInFront | 30ft (3 squares) ahead |
| Travel In Back | OrderWalkInBack | 10ft (1 square) behind |
| Travel Near Me | OrderWalkNearMe | Stay beside player |
| Travel To Destination | OrderWalkToPoint | Go to selected point |
| Do Not Attack | OrderDoNotAttack | Passive mode |
| Do Not Pick Up Items | OrderNoPickup | Ignore items |
| Attack Neutrals | OrderAttackNeutrals | Attack neutral creatures |
| Attack Specific Target | OrderAttackTarget | Focus on chosen enemy |
| Hide | OrderHide | Stealth when possible |
| Do Not Hide | OrderDoNotHide | Reveal and stop hiding |
| Give Item to Me | OrderGiveMeItem | Transfer found (non-property) item |
| Return to Home Plane | OrderReturnHome | Dismiss summoned creature |

**All Allies mode**: `e.isAllAllies` sends order to all visible led creatures on map. Some orders (Give Item, Return Home) are only available for single targets.

### Special Behaviors
- `Retarget`: calls `ForgetOrders()` + `Retarget(cr, true)`
- `AttackNeutrals`: gives order then retargets
- `DoNotHide`: reveals the creature first
- `GiveMeItem`: IF_PROPERTY items refused ("personal property")
- `ReturnHome`: removes SUMMONED and TRANSFORMED stati (effectively dismissing)

---

## Surrender

`EvReturn Creature::Surrender(EventInfo &e)` -- player surrenders to hostile group.

### DC Calculation
```
Base DC = 10

Comparative strength adjustment:
    mod = -target.getComparativeStrengthMod(actor)
    If mod < 0: DC += mod  (weaker player makes it easier; stronger player ignored)

If target is lawful: DC -= 5
```

### Skill Check
`SkillCheck(SK_DIPLOMACY, CheckDC, true)` -- no social modifier applied.

### Results by Margin
**Conditional surrender (margin > 10)**:
- If enemy has hands:
  - If player has > 750*BestCR gold: "claims <num> gold as a lein"
  - Else: "All your gold is taken"
  - `LoseMoneyTo(750*BestCR, random_hand_creature)`
  - One random good item also taken

**Unconditional surrender (margin <= 10)**:
- All magic items, coins, and gems are taken
- Distributed to random creatures with hands in enemy party

### Chaotic Betrayal
If target's leader is MA_CHAOTIC AND margin < 10:
- 1/3 chance: "laughs gleefully and keeps attacking!" (surrender rejected)

### Success
- All creatures in target's party: `TurnNeutralTo(actor)`
- "accepts your surrender and lets you go on your way"

Time cost: 30 Timeout.

---

## Dismiss

`EvReturn Creature::Dismiss(EventInfo &e)` -- dismiss a companion.

### DC Calculation
```
If already TRIED (keyed SK_DIPLOMACY + EV_DISMISS*100): auto-success with previous result

CheckDC = 7 + max(0, target.ChallengeRating) + m.Depth
```

### Skill Check
`SkillCheck(SK_DIPLOMACY, CheckDC, true)`

### Result Tracking
Stores result (success=1, failure=0) in TRIED stati. This affects future Enlist attempts:
- Amicable dismissal (result=1): creature will rejoin without a check
- Bitter dismissal (result=0): creature refuses to rejoin

### Effect
- `TurnNeutralTo(actor)` regardless of check result
- Message differs: "amicable terms" vs "cheated and embittered"

Time cost: 30 Timeout.

---

## canTalk() Logic

`bool Creature::canTalk(Creature *to)` -- determines if a creature can engage in speech.

### Decision Tree
1. NOT `MA_SAPIENT` -> false (must be sapient)
2. `MA_PLANT` AND listener has `SK_KNOW_NATURE >= 10` -> true (druids talk to plants)
3. `M_TALKABLE` flag -> true (override for specific talkable monsters like myconids)
4. `M_NOTTALKABLE` flag -> false (explicit non-talkable override)
5. `MA_ADVENTURER` -> true (adventurer types are generally talkable)
6. `M_NOHEAD` -> false (headless creatures cannot talk)
7. Check all 3 MType slots against non-talkable type list:
   - Animals, bats, beasts, cats, dogs, constructs, elementals, fungi, jellies, plants, puddings, rodents, snakes, spiders, quadrupeds, worms, quylthulgs, trappers, vortexes, nightshades, mimics
   - If ANY MType matches -> false
8. Default -> true

---

## Perceived Monster Type (isPMType)

`bool Creature::isPMType(int32 mt, Creature *cr)` -- checks if actor appears to be a given type from the perspective of creature `cr`.

### Compound Types
If `mt > 256`: recursively check `mt % 256` AND `mt / 256` (encodes two types).

### Bluff vs Appraise
For alignment types (MA_GOOD, MA_EVIL, MA_LAWFUL, MA_CHAOTIC):
- If actor's SK_BLUFF > cr's SK_APPRAISE: return cr's own alignment instead (bluff conceals true alignment)

### Disguise
If actor has DISGUISED stati:
- Check if disguise is penetrated:
  - Disguise magnitude < `cr.SK_SPOT + cr.SK_APPRAISE` -> ignore disguise
  - `CA_SHARP_SENSES` + disguise value < 8 -> ignore
  - `CA_SCENT` + disguise value < 12 -> ignore
  - Illusion school + `TRUE_SIGHT` -> ignore
- If disguise holds: return the disguised creature's isMType result

### Fallback
If no disguise or disguise penetrated: return `isMType(mt)` (actual type).

---

## Money System

### getTotalMoney()
Iterates all T_COIN items in inventory, sums `Quantity * TITEM(iID)->Cost` (in copper pieces).

### LoseMoneyTo(amt, cr)
Transfers money from creature to another:
1. Convert amt to copper (multiply by 100)
2. Cap at total money available
3. Sort all coin stacks by denomination (largest first: platinum, gold, silver, copper)
4. Greedy algorithm: take full stacks from largest to smallest, then partial stacks
5. If remainder exists: pay with single coin of smallest denomination available (overpayment)
6. Transfer stacks to recipient (or destroy if cr is NULL)

---

## Quest System (Quest.cpp)

### TQuest Resource
```cpp
class TQuest : public Resource {
    uint8 Flags[2];   // Quest flags (minimal)
};
```

Quest logic is primarily script-driven via resource event handlers, not hardcoded in C++.

---

## Help / Monster Memory

### Features
- Online help for game elements
- Object descriptions (detailed)
- Monster memory: player remembers observed monster behaviors
  - Attack types observed
  - Spells cast
  - Abilities used
  - Resistances discovered
- Context-sensitive help

---

## Porting Considerations

1. **Social interactions** are event-driven. Port after the event system is functional.
2. **Companion system** is complex: PHD budgets with cubic CR aggregation, pool overflow between types, multiple companion classifications. The XCR/XCRtoCR conversion functions are critical shared infrastructure.
3. **TRIED stati** pattern: Social.cpp uses TRIED extensively with a compound key of `skill_id + event_id * 100` to track per-creature interaction attempts. This pattern needs a reliable stati/status effect system.
4. **Social modifiers**: The `getSocialMod()` function encodes extensive D&D 3.5e racial relationship data. This is a large lookup table that should be data-driven if possible.
5. **Shop pricing**: Two separate price tables (Shop vs Barter) with 41 entries each. The base item cost calculation has multiple special cases by item type.
6. **Quests** need VMachine scripting system first.
7. **Help/Monster memory** is lower priority UI.
8. **Target system** (Target.h) is a prerequisite -- all hostility/friendliness checks delegate to the target system's SpecificHostility/RacialHostility.
9. **Comparative strength** calculation requires the full party/creature tracking system and XCR math.
10. **Alignment system** is tightly coupled -- many social actions trigger AlignedAct() with specific alignment shifts.
