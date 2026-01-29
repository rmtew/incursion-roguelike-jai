# Data, Tables & Global Systems

**Source**: `Tables.cpp`, `Annot.cpp`, `Target.cpp`, `Res.cpp`, `Base.cpp`, `Registry.cpp`, `Debug.cpp`, `inc/Globals.h`
**Status**: Fully researched

## Game State Globals

### Core Singletons
| Variable | Type | Purpose |
|----------|------|---------|
| `theGame` | `Game*` | THE singleton game instance |
| `theRegistry` | `Registry*` | Active object registry pointer |
| `MainRegistry` | `Registry` | Registry for game objects |
| `ResourceRegistry` | `Registry` | Registry for resource objects |
| `T1` | `Term*` | Terminal/display interface |

### Event System State
| Variable | Type | Purpose |
|----------|------|---------|
| `EventStack` | `EventInfo[EVENT_STACK_SIZE]` | Stack of active events |
| `EventSP` | `int16` | Event stack pointer |
| `Silence` | `int16` | Global silence counter (suppresses messages when >0) |

### Game State
| Variable | Type | Purpose |
|----------|------|---------|
| `__spentHours` | `int16` | Hours spent tracking |
| `LastSkillCheckResult` | `int16` | Last skill check result |
| `RInf` | `ReincarnationInfo` | Reincarnation state |
| `QuestMode` | `bool` | Quest mode flag |

### Selection Arrays
| Variable | Type | Purpose |
|----------|------|---------|
| `Candidates` | `rID[2048]` | Temp array for resource selection |
| `nCandidates` | `int16` | Count |
| `GodIDList` | `rID[]` | All god resource IDs |
| `nGods` | `int16` | God count |

## Global Free Functions

### Core Utility
| Function | Purpose |
|----------|---------|
| `Fatal(fmt, ...)` | Fatal error, terminates |
| `Error(fmt, ...)` | Non-fatal error |
| `init_genrand(seed)` | Seed Mersenne Twister |
| `genrand_int32()` | Generate 32-bit random |
| `random(mx)` | Random 0..mx-1 |
| `dist(x1,y1,x2,y2)` | Distance between points |
| `DirTo(sx,sy,tx,ty)` | Direction from source to target |
| `PurgeStrings()` | Free string pool |
| `strcatf(dst,fmt,...)` | Format and concatenate |

### Alignment & Religion
| Function | Purpose |
|----------|---------|
| `ResAlign(xID)` | Get resource alignment |
| `AlignConflict(al1,al2,strict)` | Check alignment conflict |
| `godAllowsAlign(gID,align)` | God permits alignment? |
| `GodPronoun(gID,poss)` | God pronoun |
| `getGodRelation(from,to,doWrath)` | Relationship between gods |

### Gameplay Logic
| Function | Purpose |
|----------|---------|
| `isLegalPersonTo(Actor,Victim)` | Legal target check |
| `getChivalryBreach(e)` | Chivalry code violation |
| `effectGivesStati(eID)` | Effect grants status? |
| `MonHDType(MType)` | Hit die for monster type |
| `MonGoodSaves(MType)` | Good saves for monster type |
| `ResourceLevel(xID)` | Level of resource |
| `ResourceHasFlag(xID,fl)` | Resource flag check |
| `MaxItemPlus(MaxLev,eID)` | Max magic plus at level |
| `FeatName(ft)` | Feat display name |
| `FeatUnimplemented(ft)` | Feat has no implementation? |

### Event Dispatch (13 Throw Variants)
All return `EvReturn`:

| Function | Extra Parameters | Purpose |
|----------|-----------------|---------|
| `Throw` | `Ev, p1..p4` | Basic dispatch |
| `ThrowVal` | `Ev, n, p1..p4` | With numeric value |
| `ThrowXY` | `Ev, x, y, p1..p4` | At coordinates |
| `ThrowDir` | `Ev, d, p1..p4` | With direction |
| `ThrowField` | `Ev, f, p1..p4` | With field |
| `ThrowEff` | `Ev, eID, p1..p4` | With effect |
| `ThrowEffDir` | `Ev, eID, d, p1..p4` | Effect + direction |
| `ThrowEffXY` | `Ev, eID, x, y, p1..p4` | Effect + coordinates |
| `ThrowLoc` | `Ev, x, y, p1..p4` | At location |
| `ThrowDmg` | `Ev, DType, DmgVal, s, p1..p4` | Damage event |
| `ThrowTerraDmg` | `Ev, DType, DmgVal, s, victim, terID` | Terrain damage |
| `ThrowDmgEff` | `Ev, DType, DmgVal, s, eID, p1..p4` | Damage + effect |
| `RedirectEff` | `e, eID, Ev` | Redirect to new effect |
| `ReThrow` | `ev, e` | Re-dispatch existing event |
| `SetEvent` | `e, Ev, p1..p4` | Initialize EventInfo |

### Message/Print System
| Function | Purpose |
|----------|---------|
| `XPrint(msg,...)` | Format message (no POV) |
| `PPrint(POV,msg,...)` | Format for player POV |
| `APrint(e,msg,...)` | To all perceiving players |
| `DPrint(e,msg1,msg2,...)` | Actor gets msg1, perceivers get msg2 |
| `VPrint(e,msg1,msg2,...)` | Victim gets msg1, perceivers get msg2 |
| `TPrint(e,msg1,msg2,msg3,...)` | Three-way: actor/victim/perceivers |
| `Hear(e,range,msg,...)` | Audio message within range |
| `SinglePrintXY(e,msg,...)` | Message if location visible |

### Description Functions
| Function | Purpose |
|----------|---------|
| `DescribeSkill(sk)` | Full skill text description |
| `DescribeFeat(ft)` | Full feat text description |
| `ItemNameFromEffect(eID)` | Item name from effect |

## Calculation Breakdown Variables

Debug/UI variables exposing step-by-step calculation breakdowns:

### Spell Power Breakdown
| Variable | Purpose |
|----------|---------|
| `p_base` | Base power |
| `p_int` | Intelligence modifier |
| `p_spec` | Specialization |
| `p_lev` | Level-based |
| `p_conc` | Concentration |
| `p_meta` | Metamagic |
| `p_calc` | Calculated total |
| `p_circ` | Circumstance modifier |
| `ps_perfect` | String: perfect conditions |
| `ps_calc` | String: calculation description |

### Spell DC Breakdown
| Variable | Purpose |
|----------|---------|
| `dc_base` | Base DC |
| `dc_hard` | Hardness modifier |
| `dc_focus` | Spell Focus feat |
| `dc_trick` | Trick modifier |
| `dc_will` | Will component |
| `dc_beguile` | Beguile modifier |
| `dc_lev` | Level modifier |
| `dc_attr` | Attribute modifier |
| `dc_height` | Heighten spell |
| `dc_affinity` | Affinity modifier |
| `dcs_attr` | String: which attribute drives DC |

### Skill Check Breakdown
| Variable | Purpose |
|----------|---------|
| `s_racial` | Racial bonus |
| `s_enhance` | Enhancement bonus |
| `s_feat` | Feat bonus |
| `s_domain` | Domain bonus |
| `s_item` | Item bonus |
| `s_train` | Training/ranks |
| `s_syn` | Synergy bonus |
| `s_armour` | Armour check penalty |
| `s_comp` | Competence bonus |
| `s_circ` | Circumstance bonus |
| `s_inh` | Inherent bonus |
| `s_size` | Size bonus |
| `s_kit` | Kit bonus |
| `s_focus` | Focus bonus |
| `s_ins` | Insight bonus |

## Static Data Tables

### Direction/Movement
| Variable | Type | Purpose |
|----------|------|---------|
| `DirX[]` | `int8[]` | X-offset per direction |
| `DirY[]` | `int8[]` | Y-offset per direction |

### Combat/Rules Tables
| Variable | Type | Purpose |
|----------|------|---------|
| `GoodSave[]` | `int8[]` | Good save progression |
| `PoorSave[]` | `int8[]` | Poor save progression |
| `ManaMultiplier[]` | `int8[]` | Mana multiplier by class/level |
| `ChargeBonusTable[10][30]` | `int8[][]` | Charge bonuses |
| `ArmourTable[33][16]` | `int8[][]` | AC by type and bonus |
| `AbsorbTable[17][16]` | `int8[][]` | Damage absorption |
| `SpellTable[27][9]` | `int8[][]` | Spells per day by level |
| `BonusSpells[22][9]` | `int8[][]` | Bonus spells by attribute |
| `Studies[9][4]` | `int16[][]` | Study requirements |
| `EncumValues[4]` | `int32[]` | Encumbrance thresholds |
| `EncumbranceTable[]` | `int16[]` | Encumbrance modifiers |
| `MonkDamage[]` | `Dice[]` | Monk unarmed damage by level |
| `ExperienceChart[]` | `int32[]` | XP needed per level |
| `WealthByLevel[]` | `int32[]` | Expected treasure by level |
| `QualityMods[][2]` | `int16[][]` | Weapon quality modifier pairs |
| `AQualityMods[][2]` | `int16[][]` | Armor quality modifier pairs |
| `SpecialistTable[9][9]` | `int8[][]` | Specialist wizard spell slots |
| `FaceRadius[]` | `int8[]` | Facing radius by size |
| `NeededSwings[]` | `int8[]` | Swings needed |

### Monster/Item Glyph Arrays
| Variable | Purpose |
|----------|---------|
| `MonsterGlyphs[]` | Glyph per monster type |
| `ItemGlyphs[]` | Glyph per item type |
| `CreationGlyphs[]` | Glyphs for character creation |
| `WildShapeGlyphs[]` | Glyphs for wild shape forms |

### Character Building Arrays
| Variable | Purpose |
|----------|---------|
| `RogueFeats[]` | Rogue bonus feats |
| `MonkFeats[]` | Monk bonus feats |
| `RangerEnemies[]` | Ranger favored enemy types |
| `FavEnemies[]` | Favored enemy type list |
| `okStartingAbils[]` | Legal starting abilities |
| `badStartingFeats[]` | Feats not allowed at creation |
| `ActiveTraits[]` | Active trait list |

### Info Structures
| Variable | Purpose |
|----------|---------|
| `SkillInfo[]` | Full skill info (name, attribute, etc.) |
| `Synergies[][3]` | Skill synergy definitions |
| `AlignmentInfo[]` | Alignment names and relationships |
| `AbilInfo[]` | Ability score info |
| `FeatInfo[]` | Feat info with prerequisites |
| `OptionList[]` | Game options |
| `YuseCommands[]` | Use-menu commands |

### Display Strings
| Variable | Purpose |
|----------|---------|
| `KeyBindings` | Key bindings help text |
| `GlyphLegend1/2` | Glyph legend help pages |
| `AttrTitle[]` | Attribute full names |
| `RatingWord[]` | Rating descriptors |
| `SlotNames[]` | Equipment slot names |
| `NumberNames[]` | "one", "two", "three"... |
| `RomanNumerals[]` | "I", "II", "III"... |
| `EncumbranceNames[]` | Encumbrance level names |
| `PersonalityNames[]` | AI personality type names |
| `PersonalityDescs[]` | AI personality descriptions |

## TextVal Lookup Arrays (75 total)

### Display Name Arrays (45)
Mapping game enum values to human-readable strings:

| Array | Maps |
|-------|------|
| `DTypeNames[]` | Damage types → "fire", "cold", etc. |
| `ATypeNames[]` | Attack types → "slash", "bite", etc. |
| `AbilityNames[]` | Ability scores |
| `ClassAbilities[]` | Class features |
| `RarityNames[]` | Rarity levels |
| `WeaponGroupNames[]` | Weapon groups |
| `MTypeNames[]` | Monster types |
| `ITypeNames[]` | Item types |
| `SourceNames[]` | Magic sources |
| `AnnotationNames[]` | Annotation types |
| `AttkVerbs1/2[]` | Attack verbs (1st/3rd person) |
| `BreathTypes[]` | Breath weapon types |
| `StatiLineStats/Shorts[]` | Status line display |
| `BoltNames/BeamNames/CloudNames/BallNames/BreathNames[]` | Effect names by shape |
| `SchoolNames[]` | Magic school names |
| `StudyNames[]` | Study types |
| `SizeNames[]` | Creature sizes |
| `ActionVerbs[]` | Action verbs |
| `DataTypeNames[]` | Data types |
| `BonusNames/Nicks[]` | Bonus type names/abbreviations |
| `SaveBonusNames[]` | Save bonus names |
| `PreQualNames/PostQualNames[]` | Weapon quality prefix/suffix names |
| `QualityDescs/MaterialDescs[]` | Quality/material descriptions |
| `GenericPreQualNames[]` | Non-weapon prefix qualities |
| `APreQualNames/APostQualNames[]` | Armor quality prefix/suffix names |
| `GenericQualityDescs/AQualityDescs[]` | Quality descriptions |
| `MMDTypeNames/MMAttkVerbs/MMAttkVerbs2[]` | Monster manual display |
| `SpellPurposeNames[]` | Spell purpose names |
| `PerDescs[]` | Personality descriptions |
| `FileErrors[]` | File error messages |

### CONSTNAMES Arrays (30)
Mapping C++ constants to string names (for scripting/debug):

| Array | Prefix | Maps |
|-------|--------|------|
| `MA_CONSTNAMES[]` | `MA_` | Monster type aggregates |
| `M_CONSTNAMES[]` | `M_` | Monster flags |
| `AD_CONSTNAMES[]` | `AD_` | Attack delivery types |
| `A_CONSTNAMES[]` | `A_` | Attack types |
| `T_CONSTNAMES[]` | `T_` | Object/resource types |
| `SS_CONSTNAMES[]` | `SS_` | Status source types |
| `ATTR_CONSTNAMES[]` | `ATTR_` | Attributes |
| `STATI_CONSTNAMES[]` | `STATI_` | Status effects |
| `EV_CONSTNAMES[]` | `EV_` | Event types |
| `OPCODE_CONSTNAMES[]` | `OPCODE_` | VM opcodes |
| `TA_CONSTNAMES[]` | `TA_` | Target types |
| `DT_CONSTNAMES[]` | `DT_` | Damage types |
| `WQ_CONSTNAMES[]` | `WQ_` | Weapon qualities |
| `AQ_CONSTNAMES[]` | `AQ_` | Armor qualities |
| `IQ_CONSTNAMES[]` | `IQ_` | Item qualities |
| `WS_CONSTNAMES[]` | `WS_` | Weapon styles |
| `SK_CONSTNAMES[]` | `SK_` | Skills |
| `SN_CONSTNAMES[]` | `SN_` | Synergies |
| `HI_CONSTNAMES[]` | `HI_` | Hit locations |
| `IL_CONSTNAMES[]` | `IL_` | Item levels |
| `PHASE_CONSTNAMES[]` | `PHASE_` | Game phases |
| `BARD_CONSTNAMES[]` | `BARD_` | Bard abilities |
| `INV_CONSTNAMES[]` | `INV_` | Inventory slots |
| `CH_CONSTNAMES[]` | `CH_` | Channel constants |
| `CA_CONSTNAMES[]` | `CA_` | Class abilities |
| `SP_CONSTNAMES[]` | `SP_` | Spell purposes |
| `AI_CONSTNAMES[]` | `AI_` | AI behaviors |
| `MS_CONSTNAMES[]` | `MS_` | Monster subtypes |
| `IF_CONSTNAMES[]` | `IF_` | Item flags |
| `GLYPH_CONSTNAMES[]` | `GLYPH_` | Glyphs |

## Annotations (Annot.cpp)

### Overview
Annotations extend Resource objects with typed metadata. Primary mechanism for attaching complex data to resources.

### Access Pattern
```cpp
// Get constant from resource
uint32 value = RES(rID)->GetConst(CONST_NAME);

// Iterate sub-resources
rID sub = RES(rID)->FirstRes(AT_TYPE);
while (sub) {
    // process sub
    sub = RES(rID)->NextRes(AT_TYPE);
}

// Grant equipment
RES(rID)->GrantGear(creature, ...);
```

## Bonus Type System (39 types)

D&D 3.5e bonus types for stacking rules:
```
BONUS_BASE(0), BONUS_ARMOR(1), BONUS_SHIELD(2), BONUS_NATURAL(3),
BONUS_DEFLECT(4), BONUS_DODGE(5), BONUS_ENHANCE(6), BONUS_LUCK(7),
BONUS_MORALE(8), BONUS_INSIGHT(9), BONUS_SACRED(10), BONUS_PROFANE(11),
BONUS_RESIST(12), BONUS_COMP(13), BONUS_CIRC(14), BONUS_SIZE(15),
... up to BONUS_LAST(39)
```

### Stacking Rules
- Same-type bonuses DON'T stack (only highest applies)
- Exception: BONUS_DODGE always stacks
- Penalties always stack

## Debug System (Debug.cpp)

### Wizard Mode Commands
- Object inspection
- Monster scrutiny
- Level treasure listing
- Container inspection

### Dump Functions (lines 1856-1978)
Essential for verification:
```cpp
void Thing::Dump()
void Creature::Dump()
void Item::Dump()
void Feature::Dump()
```

## Porting Considerations

1. **Tables** - Static data, direct port to Jai constants
2. **Annotations** - Flexible metadata; design Jai equivalent (tagged union or struct)
3. **Target system** - See 04-creature-system.md for full TargetSystem detail
4. **Registry** - Core design decision: handle system vs direct pointers
5. **Bonus stacking** - Critical for correctness; verify all 39 types
6. **Debug/Dump** - Essential for verification during porting
7. **TextVal arrays** - 75 enum-to-string mappings; convert to Jai lookup tables
8. **Calculation breakdown variables** - 30+ globals for UI display of formula components
9. **Event dispatch** - 13 Throw variants with different parameter signatures; design unified dispatch in Jai
10. **Print system** - Multi-perspective message formatting (actor/victim/perceiver) needs careful port
