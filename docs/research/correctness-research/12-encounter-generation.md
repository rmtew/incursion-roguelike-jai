# Encounter Generation System

**Source**: `Encounter.cpp` (3346 lines)
**Spec**: `docs/research/specs/dungeon-generation/population.md`
**Status**: Fully researched

## Overview

Encounter generation creates balanced groups of monsters for dungeon population. It works within CR (Challenge Rating) constraints and supports multi-part encounters with template stacking. The same code path is used for both dungeon population and summoning effects.

## Key Data Structures

### EncMember
```cpp
struct EncMember {
    rID mID, tID, tID2, tID3;   // Monster and template IDs (up to 3 templates)
    rID iID, pID;                // Item and party IDs
    rID hmID, htID, htID2;       // Humanoid mount/template IDs (up to 2 mount templates)
    uint16 Flags, Align;
    hObj hMon;                   // Created monster handle
    int8 Part, xxx;
};
```

### EncPart (resource definition for one part of an encounter)
```cpp
struct EncPart {
    uint32 Flags;       // EP_* flags
    uint8 Weight;       // Weight for XCR budget distribution
    uint8 Chance;       // Percentile chance of this part being included
    uint8 minCR;        // Minimum CR for this part to activate
    Dice  Amt;          // Amount spec: Sides=dice, Number+Bonus=range, Bonus=fixed
    hCode Condition;    // Script condition
    rID xID;            // Monster list/type ID or specific monster
    rID xID2;           // Template list/type ID or specific template
};
```

### TEncounter (Resource)
```cpp
class TEncounter : public Resource {
    uint32 Terrain;              // Terrain type bitmask
    int16 Weight, minCR, maxCR;  // Selection weight, CR range
    int16 Freak, Depth, Align;   // Freak factor, depth restriction, alignment
    EncPart Parts[MAX_PARTS];    // Multi-part encounter
    uint8 Flags[(NF_LAST/8)+1];  // NF_* flags (bitfield)
};
```

### Static State
```cpp
int32 Map::uniformKey[50];      // Keys for uniform selection cache
rID   Map::uniformChoice[50];   // Values for uniform selection cache
int16 Map::cUniform;            // Count of uniform entries
EncMember Map::EncMem[MAX_ENC_MEMBERS];  // Built encounter members
int16 Map::cEncMem;             // Count of members
Creature * CandidateCreatures[2048];     // Placed creature references
```

## XCR Budget System (The Core Math)

### XCR(CR) -- CR to Experience CR conversion
The XCR formula is **cubic**, NOT exponential as the comments suggest:
```cpp
inline int32 XCR(int16 CR) {
    if (CR >= 1)
        return (CR + 3) * (CR + 3) * (CR + 3);   // Cubic: (CR+3)^3
    // Sub-zero CR uses a lookup table:
    switch (CR) {
        case 0:  return 55;
        case -1: return 44;
        case -2: return 33;
        case -3: return 26;
        case -4: return 22;
        case -5: return 18;
        case -6: return 15;
        case -7: return 12;
        case -8: return 10;
        default: return 6;
    }
}
```

**Example XCR values**: CR1=64, CR2=125, CR3=216, CR4=343, CR5=512, CR10=2197

### XCRtoCR(XCR) -- Reverse lookup
Uses a static table of cubes (and the sub-zero table) to find the CR for a given XCR value. The table maps indices 0-42 to CRs -8 through 36.

```cpp
inline int16 XCRtoCR(int32 XCR) {
    static int32 Cubes[] = {
        10, 12, 15, 18, 22, 26, 33, 44, 55,  // CR -8 to 0
        4*4*4, 5*5*5, 6*6*6, ...              // CR 1+: (CR+3)^3
        39*39*39 };                            // CR 36
    for (i = 0; i != 43; i++)
        if (Cubes[i] >= XCR)
            return i - 8;  // offset by 8 for sub-zero CRs
    return 36;
}
```

### Per-Individual XCR Calculation (enCalcCurrPartXCR)
Calculates the XCR cost of one encounter member with all its additions:
```
epCurrXCR = XCR(base_monster_CR after all template CR adjustments)
          + XCR(mount_CR after mount template adjustments)   [if mounted]
          + XCR(party_effect_level - 2)                      [if has pID]
          + XCR(item_effect_level - 2)                       [if has iID]
```

Template CR adjustment is sequential: `CR = template.CR.Adjust(CR)` applied for tID, tID2, tID3 in order.

## Encounter Flags

### NF_* Flags (on TEncounter resource)
| Flag | Value | Meaning |
|------|-------|---------|
| NF_NOGEN | 1 | Not randomly generated |
| NF_SINGLE | 2 | Single-monster encounter |
| NF_MULTIPLE | 3 | Multi-monster encounter |
| NF_HORDE | 4 | Horde encounter (10-50 monsters) |
| NF_FREAKY | 5 | Allow freaky templates |
| NF_AQUATIC | 6 | Aquatic-only encounter |
| NF_STAGGERED | 7 | Staggered generation (random parts for each monster) |
| NF_FORMATION | 8 | Monsters in formation |
| NF_UNIFORM | 9 | All monsters of same type |
| NF_VAULT | 13 | Vault encounter |
| NF_FORM50 | 15 | 50% chance of formation |
| NF_CONTEXT_AQUATIC | 16 | Aquatic if context is water |

### EN_* Flags (on generation request)
| Flag | Value | Meaning |
|------|-------|---------|
| EN_ROOM | 0x00000001 | Place in last created room |
| EN_STREAMER | 0x00000002 | Place in water streamer |
| EN_SINGLE | 0x00000004 | Generate one monster |
| EN_FREAKY | 0x00000008 | Ignore normal template restrictions |
| EN_MAXIMIZE | 0x00000010 | Must be stated CR |
| EN_DUNGEON | 0x00000020 | Create potential uniques |
| EN_NOPLACE | 0x00000100 | Store in Candidates array, don't place on map |
| EN_SUMMON | 0x00000400 | Summoned monsters |
| EN_ANYOPEN | 0x00000800 | Place in OpenX/OpenY slots |
| EN_MULTIPLE | 0x00001000 | Generate 4+random(5) monsters |
| EN_NOBUILD | 0x00002000 | Don't create Monster objects |
| EN_CREATOR | 0x00008000 | Use creator's party |
| EN_ILLUSION | 0x00010000 | Create illusionary creatures |
| EN_HOSTILE | 0x00040000 | Create hostile to summoner |
| EN_DUMP | 0x00080000 | Build text description only |
| EN_NESTED | 0x00100000 | Nested sub-encounter |
| EN_NOSLEEP | 0x00200000 | No sleeping monsters |
| EN_VAULT | 0x00800000 | Vault encounter |
| EN_AQUATIC | 0x01000000 | Aquatic encounter |
| EN_OODMON | 0x02000000 | Out-of-depth monster warning |
| EN_DUNREGEN | 0x04000000 | Dungeon regeneration |

### EP_* Flags (on EncPart)
| Flag | Value | Meaning |
|------|-------|---------|
| EP_ELSE | 0x00000001 | Alternative to previous part |
| EP_OR | 0x00000002 | Choose one from OR group |
| EP_NOXCR | 0x00000004 | Ignore XCR budget |
| EP_UNIFORM | 0x00000008 | Same monster for all in this part |
| EP_SKILLED | 0x00000010 | Add skill template |
| EP_SKILLMAX | 0x00000020 | Add highest-CR skill template |
| EP_SKILLHIGH | 0x00000040 | Add best-of-two skill template |
| EP_CLASSED | 0x00000080 | Must have class template |
| EP_CLASS50 | 0x00000100 | 50% chance of class template |
| EP_CLASS25 | 0x00000200 | 25% chance of class template |
| EP_CLASS10 | 0x00000400 | 10% chance of class template |
| EP_SKEW_FOR_AMT | 0x00000800 | Prefer more, weaker monsters |
| EP_SKEW_FOR_XCR | 0x00001000 | Prefer fewer, stronger monsters |
| EP_MOUNTED | 0x00002000 | Always mounted |
| EP_MOUNTABLE | 0x00004000 | 50% chance mounted |
| EP_LEADER | 0x00008000 | This part is the leader |
| EP_ANYMON | 0x00040000 | Choose from all monsters by type |
| EP_ANYTEMP | 0x00080000 | Choose from all templates by type |
| EP_FREAKY | 0x00100000 | Allow freaky templates for this part |
| EP_SKEW_FOR_MID | 0x00200000 | Best-of-4 weighted selection (prefer higher CR) |
| EP_MAYCLASS | 0x00400000 | May add class template |

### Template Type Flags (TM_*)
| Flag | Value | Meaning |
|------|-------|---------|
| TM_SKILL | 0x0001 | Skill templates (skilled, veteran, etc.) |
| TM_CLASS | 0x0002 | Class templates (barbarian, sorceror, etc.) |
| TM_AGECAT | 0x0004 | Age category (juvenile, great wyrm, etc.) |
| TM_NATURE | 0x0008 | Nature templates (axiomatic, corrupted, dire, etc.) |
| TM_UNDEAD | 0x0010 | Undead templates (skeleton, zombie, mummy) |
| TM_CHIEFTAN | 0x0020 | Leader/chieftain templates |
| TM_SHAMAN | 0x0040 | Shaman/magical support templates |
| TM_ATTR | 0x0080 | Exceptional attribute templates |
| TM_DESCENT | 0x0100 | Half-dragon, half-fiend, etc. |
| TM_PLANAR | 0x0200 | Celestial, anarchic, flame, aqueous |

## Generation Flow: The Full Pipeline

### Entry Points (thEnGen variants)
All entry points construct an `EventInfo` and call `ReThrow(EV_ENGEN, e)`:
- `thEnGen(xID, fl, CR, enAlign)` -- basic
- `thEnGenXY(...)` -- with placement coordinates
- `thEnGenSummXY(...)` -- summoning with coordinates and caster
- `thEnGenMon(...)` -- constrained to specific monster ID
- `thEnGenMonXY(...)` -- specific monster with placement
- `thEnGenMonSummXY(...)` -- specific monster summoning
- `thEnGenMType(...)` -- constrained to monster type
- `thEnGenMTypeXY(...)` -- monster type with placement
- `rtEnGen(...)` -- re-throw (preserves existing EventInfo)

### Main Algorithm: enGenerate (EV_ENGEN handler)

#### Stage 0: Clear and Initialize
If not a nested encounter (`EN_NESTED`), zero out:
- `EncMem[]` array (MAX_ENC_MEMBERS)
- `cEncMem = 0`
- `cUniform = 0` (uniform selection cache)
- `CandidateCreatures[]` (2048 entries)

Calculate `enDesAmt` (desired monster count):
```
If EN_SINGLE:    enDesAmt = 1
If EN_ANYOPEN:   enDesAmt = OpenC / {30 if depth>2, 50 if depth==2, 75 if depth<=1}
If EN_MULTIPLE:  enDesAmt = 4 + random(5)
```

Cap desired amount: `enDesAmt = min(enDesAmt, maxAmtByCR(enCR))`

**maxAmtByCR table**:
```
CR1: 5,  CR2: 7,  CR3: 10,  CR4: 12,  CR5: 15
CR>5: 50,  CR<1: 4
```

#### Stage 1: Choose Encounter ID from Region's ENCOUNTER_LIST
If the encounter has a `enRegID` with an ENCOUNTER_LIST:
- Parse weighted list entries (3 formats: -2/rID/constraint, -3/rID/constraint/minCR/maxCR, plain rID)
- Filter by minCR and alignment conflict
- Choose by weighted random selection
- If selected, jump to PresetEncounter

#### Stage 2: Build Potential Encounter List (global search)
Iterate all TEncounter resources across modules and filter:
- `te->minCR > enCR` or `te->maxCR < enCR` -- skip
- `NF_NOGEN` -- skip
- Aquatic filtering (NF_AQUATIC vs non-aquatic)
- Vault filtering (EN_VAULT must match NF_VAULT)
- Terrain type match
- Monster type match (enType)
- Desired amount compatibility (NF_SINGLE, NF_MULTIPLE, NF_HORDE)
- Amount range check via `okDesAmt()` (rolls Amt 3 times, takes min/max)
- Alignment conflict check
- EV_ISTARGET event check

Weight assignment: uses `WEIGHT_CURVE_BY_CR` list if available, otherwise `te->Weight`.

#### Stage 3: Choose Encounter from Weighted List
Standard weighted random selection from accumulated weights.

#### Stage 4: Eliminate Inapplicable/Percentile Parts (PresetEncounter)
For each part in the selected TEncounter:
- Skip if `part.minCR > enCR`
- Roll `part.Chance` percentile (skip if `random(100)+1 > Chance`)
- Handle `EP_ELSE` (skip if previous part was NOT skipped)
- Handle `EP_OR` groups (choose one randomly from the OR group)

#### Stage 5: Calculate Total Weight and Divide XCR Budget
```cpp
enXCR = XCR(enCR);
enSleep = random(100) + 1;

// Scale up for large rooms
if (enDesAmt >= 4) {
    enXCR += (enDesAmt / 3) * (enXCR / 2);
    // Also increase sleep threshold (more monsters may be asleep)
    if (!(EN_NOSLEEP))
        for (i = 0; i < enDesAmt/3; i++)
            enSleep = max(enSleep, random(100) + 1);
}

// Apply encounter-specific minimums
enXCR = max(enXCR, XCR(enCR) * MIN_XCR_MULT);
enXCR = max(enXCR, MIN_XCR);
```

Calculate total weight from non-skipped parts, used to distribute XCR proportionally.

#### NF_STAGGERED Special Path
For staggered encounters, each monster is individually rolled for which part it belongs to:
```
mCount = enDesAmt or (3 + random(5))
For each monster:
    Choose a part by weighted random from non-skipped parts
    Set epMinAmt = epMaxAmt = 1
    epXCR = enXCR / mCount
    ReThrow(EV_ENGEN_PART)
```

#### Stage 6: Create Parts in Order (normal path)
For each non-skipped part:
```
epXCR = (enXCR * part.Weight) / totalWeight

// Determine amount range:
if part.Amt.Sides:     epMinAmt = epMaxAmt = Amt.Roll()
if Amt.Number+Bonus:   epMinAmt = Number, epMaxAmt = Bonus
if just Amt.Bonus:     epMinAmt = epMaxAmt = Bonus
if NF_SINGLE:          epMinAmt = epMaxAmt = 1
if NF_HORDE:           epMinAmt = 10, epMaxAmt = 50
else:                  epMinAmt = epMaxAmt = 0

ReThrow(EV_ENGEN_PART)
```

On ABORT: retry with relaxed constraints (clear enConstraint, or re-pick encounter).

#### Deviance Testing (between Stage 6 and 7)
After all parts are generated:
```cpp
totXCR = sum of XCR(CR) for each EncMem member
Deviance = abs(enXCR - totXCR) * 100 / enXCR

// Additional penalties:
if (enDesAmt)
    Deviance += max(0, (abs(enDesAmt - cEncMem) * 100 / enDesAmt) - 50)
if (cEncMem > maxAmtByCR(enCR))
    Deviance += (cEncMem - maxAmtByCR(enCR)) * 100 / maxAmtByCR(enCR)

if (Deviance > 50 && enTries < 5)
    restart from DevianceRestart  // retry up to 5 times
```

**Key formula**: Deviance over 50% triggers a retry. Max 5 retries.

#### Stage 7: Build the Encounter (EN_DUMP path for diagnostics, or real build)

**Alignment drift and group alignment**:
```cpp
enDriftGE = enDriftGE * (100 / cEncMem)  // average the drift
if no explicit good/evil constraint:
    if (enDriftGE - 25 + random(50) > 0)
        enAlign |= AL_NONGOOD
    else
        enAlign |= AL_NONEVIL
```

**Formation**: enabled if `NF_FORMATION` or (`NF_FORM50` and 50% chance).

**HACKFIX cap**: `cEncMem = min(cEncMem, 5)` -- hard cap at 5 creatures.

**Building**: For each EncMem, call `ReThrow(EV_ENBUILD_MON, e)`.

**Party composition** (leader selection):
1. Find any member explicitly flagged `EP_LEADER` -- that's the leader
2. If no explicit leader, choose the highest-CR sapient creature
3. All non-leader creatures get `TargetLeader` targeting
4. If formation is enabled, non-leaders get `OrderWalkNearMe`

## Part Generation: enGenPart (EV_ENGEN_PART handler)

### Amount Determination

Rolls 5 random amounts from [epMinAmt, epMaxAmt] range to establish upper/lower bounds.

Three paths based on constraints:

**Path 1: EP_NOXCR** (ignore XCR budget):
```
epAmt = RNDAMT or 1
```

**Path 2: Fixed amount** (epMinAmt == epMaxAmt):
```
eimXCR = min(XCR(enCR), epXCR / epMinAmt)
epAmt = epMinAmt
```

**Path 3: Variable amount** (determine from CR range):
```
minCR = getMinCR(e)  // lowest possible monster CR from this part
maxCR = min(getMaxCR(e), enCR)

if minCR == maxCR:
    eimXCR = XCR(minCR)
    epAmt = max(1, epXCR / eimXCR)  [clamped to min/max]
else:
    if EP_SKEW_FOR_AMT:  eimXCR = (XCR(min)*3 + XCR(max)*1) / 4  // prefer more weaker
    if EP_SKEW_FOR_XCR:  eimXCR = (XCR(min)*1 + XCR(max)*4) / 4  // prefer fewer stronger
    else:                eimXCR = (XCR(min)*2 + XCR(max)*2) / 4  // balanced

    eimXCR = min(XCR(enCR), eimXCR)
    epAmt = max(1, epXCR / eimXCR)  [clamped with randomness from bounds]
```

### Monster Generation Loop
For each monster in the part:
```
1. Reset all ep_mID/tID/hmID fields
2. Roll epFreaky if NF_FREAKY or EP_FREAKY
3. ReThrow(EV_ENCHOOSE_MID) -> sets chResult = mID
4. If mID is a TEncounter: recursive nested generation
5. ReThrow(EV_ENSELECT_TEMPS) -> applies templates
6. If epFailed: retry up to 20 times
7. Handle undead rider + living mount: auto-add graveborn/zombie/skeleton template to mount
8. enAddMon(e) -> store in EncMem
9. UpdateAlignRestrict(e) -> tighten alignment constraints
10. Adaptive filling: if totalXCR >= epXCR, stop early
11. If under budget and under uBound, increase epAmt
```

**Undead mount logic**: If rider is undead but mount is not, randomly apply one of:
- "graveborn;template"
- "zombie"
- "skeleton"

## Monster Selection: enChooseMID (EV_ENCHOOSE_MID handler)

### Max CR Calculation
```
maxCR = XCRtoCR(eimXCR)
if EP_CLASSED: maxCR = max(1, maxCR - 2)  // leave room for class template
if constraint is specific mID: maxCR = max(maxCR, min(enCR, TMON(constraint)->CR))
maxCR = max(1, maxCR)
if epTries > 5: maxCR = max(0, maxCR - (epTries-5)/2)  // progressive relaxation
```

### Selection Paths

**Path A: Specific monster (ep.xID is a resource ID)**:
Return it directly.

**Path B: EP_ANYMON (choose from all monsters of a given type)**:
Scan all TMonster resources, filtering:
- CR <= maxCR (unless getMinCR mode)
- Not M_NOGEN (unless constraint is a specific mID)
- Depth <= enDepth
- Aquatic matching (M_AQUATIC, M_AMPHIB)
- Not M_PLAYER or M_UNKNOWN
- Not M_SOLITARY (unless NF_SINGLE encounter)
- Alignment conflict (M_IALIGN + sapient)
- Monster type match (isMType for part's xID type)
- Constraint satisfaction
- EV_CRITERIA script check
- External criteria function check

All qualifying monsters get equal weight (1 each).

**Path C: Weighted monster list (ep.xID references a list)**:
Parse the encounter's weighted list. Supports:
- Weight change entries (values < 0x01000000)
- `-1` entries with type code = "ANY of type" (expand to all matching monsters)
- Specific monster IDs with CR/depth/alignment/constraint filtering
- Nested TEncounter references in lists

### Final Selection

**getMinCR mode**: Return lowest-CR monster from list.
**getMaxCR mode**: Return highest-CR monster from list.
**EP_SKEW_FOR_MID**: Best-of-4 weighted random (picks 4 random, keeps highest CR).
**Normal**: Standard weighted random selection.

**Uniform cache**: If NF_UNIFORM or EP_UNIFORM, store chosen mID in cache for reuse.

## Template Selection: enSelectTemps (EV_ENSELECT_TEMPS handler)

Templates are applied in a specific priority order, with XCR budget checks between each step:

### Step 1: Explicit Part Template
If `ep->xID2` is set:
- If it's a specific template ID: apply directly (if `enTemplateOk`)
- If `EP_ANYTEMP` + type mask: scan all templates of that type, random pick
- If it's a list reference: call `EV_ENCHOOSE_TEMP` with the list

### Step 2: Universal Template
If encounter has a `UNIVERSAL_TEMPLATE` list entry (pre-selected in Stage 6):
Apply it to all monsters. If it can't be applied, mark `epFailed`.

### Step 3: (skipped if over XCR budget)

### Step 4: Class Template
Chance calculation: cumulative from EP_CLASS10 (10%), EP_CLASS25 (25%), EP_CLASS50 (50%).
```
chance = 0
if EP_CLASS10: chance += 10
if EP_CLASS25: chance += 25
if EP_CLASS50: chance += 50
if (EP_CLASSED or EP_MAYCLASS or chance >= epClassRoll):
    Choose from CLASS_LIST or TM_CLASS templates
    If EP_CLASSED and nothing found: retry with increasing eimXCR
```

### Step 5: Mount Generation
Mount is generated if any of:
- Monster has M_RIDER flag (or template adds it)
- EP_MOUNTED on part
- EP_MOUNTABLE on part and 50% chance
- Monster has SK_RIDE feat and 33% chance

Mount source: check monster/templates for MOUNT_LIST. Default: "warhorse".

### Step 6: Freaky Template (if epFreaky >= 7)
Choose from TM_NATURE | TM_DESCENT types, plus TM_PLANAR if NF_SINGLE.

### Step 7: (placeholder for poison weapons / extra magic items)

### Step 8: Skill Template
If EP_SKILLED, EP_SKILLMAX, or EP_SKILLHIGH:
- EP_SKILLMAX: maximize (highest CR template)
- EP_SKILLHIGH: best-of-two
- EP_SKILLED: random

### Step 9: Dragon Age Category
If monster is MA_DRAGON and no TM_AGECAT template yet:
Choose maximized age category template. Default: "young".

## Template Validation: enTemplateOk

A template passes validation if:
1. Base monster matches template's `ForMType` (skip if `force=true`)
2. New XCR would not exceed per-individual budget (`eimXCR`)
3. No alignment conflict (if template adds M_IALIGN)
4. External criteria pass (callback + EV_CRITERIA script)
5. Monster can actually accept the template (`CanAddTemplate` check -- creates temp Monster object)

## Template Choice: enChooseTemp (EV_ENCHOOSE_TEMP handler)

### From weighted list (if encounter has list `e.chList`):
Parse weighted template list, filtering through `enTemplateOk`.

### From type scan (if no list):
Scan all templates matching `e.chType`, excluding TMF_NOGEN.

### Selection modes:
- **getMinCR**: lowest CR-adjusting template
- **getMaxCR**: highest CR-adjusting template
- **chMaximize**: collect all templates that produce the highest CR, pick randomly among them
- **chBestOfTwo**: pick two random templates, keep the one with higher CR adjustment
- **Normal**: weighted random selection

Results are cached in uniform system for NF_UNIFORM encounters.

## Mount Generation: enGenMount (EV_ENGEN_MOUNT handler)

Only applies to M_HUMANOID without M_NOLIMBS.

Default mount: "warhorse" (if no MOUNT_LIST found).

Parses MOUNT_LIST weighted list:
- Templates preceding a monster entry in the list are applied to that mount
- CR filtering based on remaining XCR budget: `maxCR = XCRtoCR(eimXCR - epCurrXCR)`
- Tracks lowCR/highCR for getMinCR/getMaxCR modes
- Standard weighted random selection

## Monster Building: enBuildMon (EV_ENBUILD_MON handler)

### Construction sequence:
```
1. Create Monster(em->mID)
2. Set PartyID
3. GrantGear from base monster resource
4. For each template (tID, tID2, tID3):
   a. CalcValues()
   b. AddTemplate(tID)
   c. GrantGear from template
   d. PEvent(EV_BIRTH) from template
5. PEvent(EV_BIRTH) from base monster
6. MonsterGear() -- equip torches, random items
7. Sleep check: if EN_DUNGEON and random(100)+1 <= enSleep and not sleep-immune
   -> GainPermStati(SLEEPING)
```

**HACKFIX**: Building stops at member index 5. `if (e.cMember >= 5) return ABORT`

### Summoned/Created/Illusory Monsters
Additional handling for EN_SUMMON, EN_CREATOR, EN_ILLUSION:
- Set party to caster's party (unless EN_HOSTILE)
- Summoned: SUMMONED stati with duration
- Illusory: ILLUSION stati with save DC
- Created: TargetMaster relationship
- If caster is player: MakeCompanion(PHD_MAGIC)
- EN_HOSTILE: TurnHostileTo caster

## Alignment System

### AlignConflict(al1, al2, strict)
Checks for alignment incompatibility:
- Good + (Evil or NonGood) = conflict
- Evil + (Good or NonEvil) = conflict
- Lawful + (Chaotic or NonLawful) = conflict
- Chaotic + (Lawful or NonChaotic) = conflict
- In strict mode: al2 having a specific alignment that al1 lacks = conflict

### UpdateAlignRestrict(e)
After adding a monster with M_IALIGN:
- Good monster: add AL_NONEVIL to encounter alignment
- Evil monster: add AL_NONGOOD
- Chaotic monster: add AL_NONLAWFUL
- Lawful monster: add AL_NONCHAOTIC
- Also adjusts enDriftGE and enDriftLC by +/-2

### enGenAlign (EV_ENGEN_ALIGN handler)
Generates individual alignment for sapient, non-inherent-alignment creatures.

**Good/Evil axis probabilities**:
- If constrained to Evil: always Evil
- If constrained to Good: always Good
- If NonGood + NonEvil: always Neutral
- If NonGood: biased toward Evil (depends on creature flags, ~60-80%)
- Default with M_EVIL flag: 70% Evil, 23% Neutral, 7% Good
- Default with M_GOOD flag: 70% Good, 23% Neutral, 7% Evil
- Default neutral: 70% Neutral, ~10% Good, ~20% Evil

**Lawful/Chaotic axis**: Same probability structure as Good/Evil.

**Special cases**: Dragons 67% keep default alignment; Goblinoids 50% keep default.

## Placement Algorithm: enBuildMon placement section

### EN_ANYOPEN placement (random from open tiles):
```
For formation encounters: reuse previous position after first placement.

Up to 50 tries:
1. Pick random open tile: j = random(OpenC)
2. Terrain checks:
   - Aquatic monsters must go in TF_WATER
   - Non-aquatic/non-amphib must NOT be in TF_WATER
   - Non-spiders can't go in TF_STICKY terrain
   - Non-aerial can't go in TF_FALL terrain
   - TF_WARN terrain: check EV_MON_CONSIDER event
   - Features at location: check EV_MON_CONSIDER
3. PlaceAt(map, OpenX[j], OpenY[j])
4. Initialize(true) unless EN_VAULT
5. Store formation coordinates
```

### Specific position placement:
```
PlaceAt(map, EXVal, EYVal)
Initialize(true) unless EN_VAULT
```

### Post-placement:
- `GainPermStati(ENCOUNTER, ...)` -- marks monster as part of this encounter
- OOD warning: if `ChallengeRating() > max(2, enCR)`, log warning

## Monster Equipment: MonsterGear

```cpp
void Monster::MonsterGear() {
    // Vision equipment
    if (no infravision/tremorsense/blindsight) {
        if (!M_NOHANDS)
            Give 1 torch
        else
            Grant infravision(6) as perm stati  // HACK for animals
    }

    // Random magic item (5% chance)
    if (!random(20) && M_HUMANOID && !M_NOHANDS)
        GenItem(IG_MONEQUIP, 0, CR-1, 10,
            CasterLev() ? MageItems : MonsterItems)
}
```

## Item Generation: GenItem

### Level Calculation
```
maxlev = max(3, Depth)  // floor at 3 for early game variety

// Low luck penalty (80% of items):
if (random(5) && Luck <= 9)
    maxlev += (Luck - 11) / 2  // negative adjustment

// High luck bonus (20% of items):
adjlev = maxlev + random((Luck-9)/2) for Luck > 9
if (!random(5)) maxlev = adjlev

// Min/max level:
if IG_GREAT:  minlev = max(0, maxlev - 2)
if IG_GOOD:   minlev = max(0, maxlev - 4)
else:         minlev = max(maxlev - 4, 0)
```

### Cursed Item Chance
```
CURSED_CHANCE from dungeon constant (default behavior ~25)
Two rolls: first for IF_CURSED, second for truly cursed (EF_CURSED eID)
```

### Item Type Selection
Uses probability tables (ItemGen arrays):
- **DungeonItems**: weapons(50), armour(35), potions, scrolls, wands, etc.
- **MonsterItems**: weapons(25), armour(15), potions(50), scrolls(25), etc.
- **MageItems**: potions(50), scrolls(35), wands, etc.
- **ChestItems**: balanced mix
- **StapleItems**: books, potions, scrolls, etc.

### Coin Generation
```
val = WealthByLevel[Depth] / 4
val *= (50 + random(100)) / Cost  // 50%-150% of base
maxCoins cap: randomly chosen from {25000, 10000, 5000, 2500}
```

**WealthByLevel table** (by dungeon level 0-20):
```
0, 1000, 1700, 3500, 5400, 9000, 13000,
19000, 27000, 36000, 49000, 66000,
88000, 110000, 150000, 200000, 260000,
340000, 440000, 580000, 760000
```

### Magic Weapon/Armour Generation
```
magicLevel = best_of_two(random(1 + maxlev - minlev) + minlev)

If mundane (1 in maxlev+2 chance): skip magic
If specific weapon (Depth>5, 12.5% chance): grant named effect

NumQualities(plusLevel):
    i = random(100)
    if i > 45 + plusLevel*5: 0 qualities
    if plusLevel>2, i < plusLevel*3: 2 qualities
    if plusLevel>4, i < plusLevel*5: 3 qualities
    if plusLevel>6, i < plusLevel*6: 4 qualities
    else: 1 quality

MakeMagicWeaponArmour: distributes plusLevel budget between
    weapon/armour qualities and enhancement bonus (+1 to +5)
```

### Racial Material Qualities (33% chance on any item)
Random selection from: Elven, Dwarven, Orcish(x2 weight), Adamant/Darkwood, Mithril/Darkwood, Ironwood, Silver.

### Blessing (percentage chance = max(maxlev, 5)%)
Removes cursed, adds blessed.

## Uniform Selection Cache

The uniform system ensures consistency within an encounter when NF_UNIFORM or EP_UNIFORM:
- `enUniformAdd(key, choice)` -- store a choice for a key
- `enUniformGet(key)` -- retrieve stored choice
- Keys are composed from list IDs, part indices, and flag masks
- Supports up to 50 cached choices per encounter

## Encounter Retry and Error Handling

### Part retry (RetryPart):
- If `epFailed` and `epTries < 20`: retry the individual monster
- Restores cEncMem and cUniform to pre-attempt values

### Encounter retry (DevianceRestart):
- If deviance > 50% and tries < 5: regenerate entire encounter
- If enConstraint exists with enRegID: retry up to 100 times with different encounters
- If 100 region tries fail: drop region constraint and use global encounter pool

### Error fallback:
- If no monsters found in enChooseMID: fallback to "human" and return ABORT
- If 1000 restarts on item generator: return "food ration"

## Porting Status

### Already Ported
- Basic monster placement during generation
- Room population density selection
- Monster resource lookup from .irh files

### Needs Porting
- Full encounter generation algorithm (enGenerate with all 7 stages)
- CR-balanced monster selection (enChooseMID)
- Template stacking (enSelectTemps with 9 steps)
- Multi-part encounters (enGenPart)
- Deviance testing and retry logic
- Humanoid mounts and riders (enGenMount)
- Encounter alignment constraints (enGenAlign, UpdateAlignRestrict)
- XCR budget system (cubic formula)
- Party composition (leader + followers)
- Formation and staggered encounters
- Uniform selection cache
- Nested encounters (recursive sub-encounter generation)
- Monster gear and item generation (MonsterGear, GenItem)
- Sleep calculation for dungeon encounters
- Summoning/creation/illusion variants
- EN_DUMP diagnostic output
- Adaptive filling (dynamic epAmt adjustment)
