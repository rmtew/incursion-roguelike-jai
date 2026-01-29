# Master Research Index - Incursion Port

## Overview

This document indexes ALL subsystems in the original Incursion codebase that require research for a faithful port. Each area links to detailed research notes (when they exist) and tracks research status.

**Original Source**: `C:\Data\R\roguelike - incursion\repo-work\`
**Source Files**: 47 .cpp files, 23 .h headers
**Constant Categories**: 45 (in Defines.h, ~4700 lines)
**Class Hierarchy**: Object > Thing > {Creature, Feature, Item}; 21 Resource types

---

## Research Status Legend

- **DONE** - Comprehensive research exists, ready for porting
- **PARTIAL** - Some research exists, gaps remain
- **STUB** - Area identified, minimal notes
- **TODO** - Not yet researched

---

## Class Hierarchy

```
Object (Base.h)
├── Thing (Map.h) - Physical dungeon objects
│   ├── Creature (Creature.h) - Living beings [also inherits Magic]
│   │   ├── Character - Player-like (class/race system, inventory slots)
│   │   │   └── Player - The actual player (UI, journal, options)
│   │   └── Monster - AI-controlled (behavior, targeting)
│   ├── Feature (Feature.h) - Non-movable features
│   │   ├── Door - Lockable/breakable
│   │   ├── Trap - Triggered hazards
│   │   └── Portal - Stairs and transport
│   └── Item (Item.h) - Carryable objects [also inherits Magic]
│       ├── QItem - Items with magical qualities
│       │   ├── Food
│       │   │   └── Corpse
│       │   ├── Container
│       │   ├── Weapon
│       │   └── Armour
│       └── Coin
├── Game
├── Map (Map.h) - Dungeon map with LocationInfo grid
├── Registry - Object handles and serialization
└── Module (Res.h) - Resource database
    └── Resource - Base for all templates
        ├── TMonster, TItem, TFeature, TEffect
        ├── TClass, TRace, TDomain, TGod
        ├── TArtifact, TTemplate, TFlavor
        ├── TDungeon, TRegion, TTerrain
        ├── TQuest, TRoutine, TNPC
        ├── TText, TVariable, TBehaviour
        └── TEncounter
```

---

## 1. Core Architecture

### 1.1 Object & Registry System
- **Status**: DONE (01-object-registry.md)
- **Source**: `Base.cpp`, `Registry.cpp`, `VMachine.cpp`, `inc/Base.h`, `inc/Res.h`
- **Key Types**: Object, hObj (handle), Registry (65536-entry hash), String (tmpstr pool, color codes), Dice, Array/NArray/OArray, MVal, VMachine (63 opcodes, 64 registers, 8192 stack)
- **Scope**: Handle-based object system (handles start at 128), serialization (ARCHIVE_CLASS), RegNode collision chaining, String temp pool (64000 entries), IncursionScript VM (VCode instruction format, system objects 1-10), Array growth strategy
- **Notes**: Registry::Get() is second-most-called function (profiled). VMachine bridges scripts to C++ via auto-generated Dispatch.h. String uses negative chars for color codes. MVal has two-phase Adjust() algorithm (VType then BType).

### 1.2 Resource System
- **Status**: DONE (02-resource-system.md)
- **Research**: `docs/research/parser-research/`, `docs/research/correctness-research/`
- **Source**: `Res.cpp`, `inc/Res.h`
- **Key Types**: Resource (base), Module, rID, hText, hCode, 21 derived resource types
- **Scope**: Resource ID encoding (module slot << 24 | offset), text/code segments, annotation system, random resource selection, resource iteration (FirstRes/NextRes), player memory management
- **Notes**: rID is uint32 with high byte = module slot + 1, remaining bits = offset. Module stores typed arrays (QMon, QItm, etc.) with cumulative offset indexing. Annotation system provides flexible metadata (effects, abilities, tiles, equipment grants).

### 1.3 Event System
- **Status**: DONE (03-event-system.md)
- **Source**: `Event.cpp`, `inc/Events.h`
- **Key Types**: EventInfo (~200 fields), EvParam (union), EvReturn (int8)
- **Scope**: 190+ event types (EV_MOVE through EV_TERMS), event dispatch via ReThrow(), macros (PEVENT, DAMAGE, THROW, XTHROW, RXTHROW), parameter verification (EVerify)
- **Notes**: EventInfo is the central data structure for ALL game actions. Contains combat fields (vRoll, vHit, vDef, vDmg, etc.), encounter generation fields, character creation fields, 60+ boolean flags, 8+ string fields for naming, and resource IDs. Events are dispatched to resource handlers via TEFF(xID)->Event().

### 1.4 Values & Calculation System
- **Status**: DONE (17-values-calcvalues.md)
- **Source**: `Values.cpp`
- **Key Concepts**: Creature attribute calculation, resistance levels, hit point calculation, hostility determination, CalcValues() method chain
- **Notes**: Values.cpp handles the complex d20-system calculations: attribute modifiers, saving throws, attack bonuses, AC calculation, skill modifiers, resistance stacking rules. CalcValues() is called frequently and caches results in Attr[] array.

---

## 2. Creature Systems

### 2.1 Creature Core
- **Status**: DONE (04-creature-system.md)
- **Source**: `Creature.cpp`, `inc/Creature.h`
- **Key Types**: Creature (base class)
- **Scope**: Stati (status effects) management, field management, perception precalculations, attribute/trait queries, mana management, death handling
- **Key Fields**: mID/tmID, cHP/mHP, Attr[ATTR_LAST], StateFlags, perception ranges (TremorRange, SightRange, etc.)
- **Notes**: Creature inherits from both Thing and Magic. Contains ~200 methods spanning combat, magic, perception, movement, inventory, social interaction. Pure virtual ChooseAction() splits into Player (input) and Monster (AI).

### 2.2 Monster AI
- **Status**: DONE (04-creature-system.md, Monster section)
- **Source**: `Monster.cpp`, `inc/Creature.h` (Monster class, lines 1124-1196)
- **Key Types**: Monster, ActionInfo, EffectInfo
- **Scope**: AI decision making (ChooseAction), action priority queue (Acts[64]), target evaluation (RateAsTarget), pathfinding (SmartDirTo), prebuffing, spell selection, inventory management, retargeting
- **Key Fields**: Inv (single linked list), BuffCount, Recent[6] (action history), static condition flags (isAfraid, isBlind, etc.)
- **Notes**: Monster uses static arrays for action planning (Acts[64], Effs[1024]). AI evaluates threats, manages spell usage, handles group tactics. Target system tracks hostility levels.

### 2.3 Player System
- **Status**: DONE (04-creature-system.md, Player section)
- **Source**: `Player.cpp`, `inc/Creature.h` (Player class, lines 960-1121)
- **Key Types**: Player, QuickKey, JournalInfoType, GameTimeInfoType, ReincarnationInfo
- **Scope**: Player input handling, resting mechanics, dungeon time tracking, vision calculation, journal system, options, macros, auto-pickup, character gallery
- **Key Fields**: Options[OPT_LAST], MaxDepths[MAX_DUNGEONS], Journal, MessageQueue[8], AutoBuffs[64]
- **Notes**: Player overrides ChooseAction() with input-driven selection. Has extensive UI methods (menus, prompts, stat display). CalcVision() is player-specific FOV.

### 2.4 Character System
- **Status**: DONE (04-creature-system.md, Character section)
- **Source**: `Character.cpp`, `inc/Creature.h` (Character class, lines 586-810)
- **Key Types**: Character
- **Scope**: Equipment slots (Inv[NUM_SLOTS]), class/race system (ClassID[6], RaceID), skill ranks (SkillRanks[SK_LASTSKILL]), feat bitfield (Feats[]), class abilities (Abilities[CA_LAST]), alignment (alignGE, alignLC), experience/leveling, spellcasting slots, deity favor system
- **Notes**: Character supports up to 6 multiclass levels. HP/mana rolls tracked per-level per-class. Deity favor system tracks sacrifice values, anger, and favor per god. Personality flags affect NPC interactions.

### 2.5 Character Creation
- **Status**: DONE (13-skills-feats.md, Character Creation section)
- **Source**: `Create.cpp`
- **Scope**: Attribute rolling, class/race selection, starting equipment, feat/ability grants, leveling, XP awards, reincarnation
- **Notes**: Complex character creation with multiple attribute generation methods, prerequisite checking, and class-specific initialization.

---

## 3. Combat Systems

### 3.1 Melee & Ranged Combat
- **Status**: DONE (05-combat-system.md)
- **Source**: `Fight.cpp`
- **Scope**: Attack sequences (NAttack, WAttack, RAttack, SAttack, OAttack), strike resolution, hit/miss/crit/fumble, damage calculation, death handling, bull rush, grapple, maneuvers, attacks of opportunity, cleave, whirlwind
- **Event Flow**: EV_NATTACK → EV_STRIKE → EV_HIT/EV_MISS → EV_DAMAGE → EV_DEATH
- **Notes**: Combat uses EventInfo extensively. Attack types defined in A_* constants (114 types). Damage types, critical multipliers, threat ranges all from item/creature data.

### 3.2 Movement System
- **Status**: DONE (05-combat-system.md, Movement section)
- **Source**: `Move.cpp`
- **Scope**: Walking, jumping, pushing, terrain effects, movement costs, passability checks, flying/swimming/phasing, attacks of opportunity from movement
- **Notes**: Movement interacts with terrain, fields, traps, and other creatures. MoveTimeout calculates speed based on attributes and encumbrance.

---

## 4. Magic & Effects

### 4.1 Magic System
- **Status**: DONE (07-magic-system.md)
- **Source**: `Magic.cpp`, `inc/Magic.h`
- **Scope**: Spell casting, wand usage, scroll reading, mana costs, spell DCs, caster levels, metamagic, counterspelling, spell resistance
- **Notes**: Magic is a mixin class inherited by Creature and Item. Spells are TEffect resources with Schools, Sources, Purpose, and EffectValues. Metamagic modifiers (MM_*) are bitmask flags (27 types).

### 4.2 Effects System
- **Status**: DONE (07-magic-system.md, Effect Archetypes section)
- **Source**: `Effects.cpp`
- **Scope**: Specific effect archetypes: Vision, Blast, Drain, Grant, Inflict, Polymorph, Dispel, Reveal, Summon, Terraform, Illusion, Creation, Detect, Travel
- **EA_* Constants**: 46 effect action types (EA_BLAST, EA_GRANT, EA_HEALING, etc.)
- **Notes**: Each archetype handles targeting, area of effect, saving throws, and result application differently. EffectValues struct has 12 fields for parameterization.

### 4.3 Prayer & Divine System
- **Status**: DONE (07-magic-system.md, Prayer section)
- **Source**: `Prayer.cpp`
- **Scope**: Prayer mechanics, divine intervention, divine blessings, crowning, god favor/anger, sacrifice system, alignment-sensitive actions, paladin fall/atonement
- **Notes**: Complex deity system with per-god favor tracking, sacrifice values by category, anger thresholds, and divine action triggers (EV_PRAY, EV_SACRIFICE, EV_BLESSING, etc.).

---

## 5. Item & Equipment

### 5.1 Item System
- **Status**: DONE (06-item-system.md)
- **Source**: `Item.cpp`, `inc/Item.h`
- **Key Types**: Item, QItem, Food, Corpse, Container, Weapon, Armour, Coin
- **Scope**: Item creation, stacking, knowledge flags (KN_MAGIC, KN_QUALITY), damage/armor calculations, weapon/armor properties, quality system (WQ_* weapon qualities, AQ_* armor qualities), material, weight, hardness
- **Notes**: QItem supports up to 8 magical qualities per item. Weapon has SDmg/LDmg (small/large damage dice), threat range, crit multiplier. Armour has ArmVal/CovVal/DefVal. Items track Known flags for player discovery.

### 5.2 Inventory Management
- **Status**: DONE (06-item-system.md, Inventory section)
- **Source**: `Inv.cpp`
- **Scope**: Character/monster inventory manipulation, container handling, item wielding/wearing, equipment slot system (SL_* constants, 24 slots), stacking rules
- **Notes**: Player uses fixed slots (Inv[NUM_SLOTS]), Monster uses linked list (single hObj head). Container class manages nested items.

---

## 6. World & Map

### 6.1 Map System
- **Status**: DONE (09-map-system.md)
- **Research**: `docs/research/specs/dungeon-generation/`
- **Source**: `Map.h`, `Display.cpp`
- **Key Types**: Map, LocationInfo, Field, MTerrain, TerraRecord, Overlay, EncMember
- **Scope**: LocationInfo per-cell (Glyph, Region, Terrain, 16 bit flags, Visibility, Memory, Contents), field effects (area spells), magical terrain, overlay system, LOS/LOF calculations, object placement, encounter placement
- **Key LocationInfo Fields**: Opaque, Obscure, Lit, Bright, Solid, Shade, hasField, Dark, mLight, mTerrain, cOpaque, Special, isWall, isVault, isSkylight, mObscure, Visibility (16-bit), Memory (uint32)
- **Notes**: Map uses bit-packed LocationInfo for memory efficiency. Visibility uses VI_VISIBLE|VI_DEFINED|VI_EXTERIOR|VI_TORCHED flags. Field system manages area effects with center, radius, duration. TorchList tracks light sources.

### 6.2 Dungeon Generation
- **Status**: DONE
- **Research**: `docs/research/specs/dungeon-generation/` (10 files)
- **Source**: `MakeLev.cpp`
- **Scope**: Room placement, corridor generation, terrain assignment, feature placement, population, region system, vault system
- **Notes**: Comprehensive specs exist covering all 8 generation phases. Room types (RM_*, 32 types), tunnel types (TU_*, 6 types), room population (RC_*, 13 types).

### 6.3 Feature System
- **Status**: DONE (10-feature-system.md)
- **Source**: `Feature.cpp`, `inc/Feature.h`
- **Key Types**: Feature, Door, Trap, Portal
- **Scope**: Door mechanics (open/close/lock/break/secret), trap mechanics (trigger, detection, disarm), portal/stairs (level transitions, depth management), feature HP
- **Notes**: Door has DoorFlags (DF_BROKEN, DF_LOCKED), Trap has TrapFlags and tID, Portal handles inter-level movement.

### 6.4 Vision & Perception
- **Status**: DONE (11-vision-perception.md)
- **Research**: `docs/research/specs/visibility-system.md`, `docs/research/specs/lighting-system.md`
- **Source**: `Vision.cpp`
- **Scope**: FOV calculation, line-of-sight, line-of-fire, perception types (PER_VISUAL, PER_TREMOR, PER_BLIND, PER_INFRA, PER_SCENT, PER_TELEPATHY, PER_SHADOW, PER_SHARED), creature perception ranges, field perception
- **Notes**: Original uses multiple perception modes as bitmask (PER_*, 10 types). Vision.cpp handles both monster and player vision. CalcVision() is player-specific. Perceives() returns bitfield of perception types used.

### 6.5 Pathfinding
- **Status**: DONE (11-vision-perception.md, Pathfinding section)
- **Source**: `Djikstra.cpp`
- **Scope**: Dijkstra shortest path algorithm, monster pathfinding (SmartDirTo), RunTo/RunDir for player, path consideration of terrain costs and obstacles
- **Notes**: Used by monster AI for intelligent movement and by player for auto-run.

### 6.6 Overland
- **Status**: STUB (lower priority, not needed for initial dungeon port)
- **Source**: `OverGen.cpp`, `Overland.cpp`
- **Scope**: Overland map generation, overland movement mechanics, wilderness terrain (TT_* terrain types as bitmask)
- **Notes**: Separate from dungeon generation. May be lower priority for initial port.

---

## 7. Status & Effects

### 7.1 Status Effects (Stati)
- **Status**: DONE (08-status-effects.md)
- **Source**: `Status.cpp`, `inc/Creature.h` (StatiCollection)
- **Key Types**: Status, StatiCollection
- **Scope**: Status effect application/removal, permanent vs temporary stati, duration tracking, stacking rules, StatiOn/StatiOff callbacks, stati from templates/bodies
- **StatiCollection Fields**: S (array), Added, Idx (index), Last, Allocated, Removed, Nested
- **Notes**: StatiCollection uses indexed array with nesting support for recursive effect application. Status has Nature, Val, Mag, Duration, Source, CLev, Dis, Once, eID, h fields.

---

## 8. Social & Skills

### 8.1 Skills System
- **Status**: DONE (13-skills-feats.md)
- **Source**: `Skills.cpp`
- **Key Constants**: SK_* (49 skills), CA_* (143 class abilities), FT_* (200+ feats)
- **Scope**: Active skill effects, special abilities, skill checks, feat prerequisites (boolean logic with 3 OR clauses x 5 AND conditions)
- **Notes**: Skills use d20 system. Feat prerequisites can check feats, abilities, BAB, skills, CR, attributes, caster level, weapon skills, proficiencies.

### 8.2 Social & NPC Interaction
- **Status**: DONE (14-social-quest.md)
- **Source**: `Social.cpp`
- **Scope**: NPC conversation, barter/trade, companion recruitment, party dynamics, personality system
- **Events**: EV_TALK, EV_BARTER, EV_COW, EV_DISMISS, EV_ENLIST, EV_FAST_TALK, EV_GREET, EV_ORDER, EV_QUELL, EV_REQUEST, EV_SURRENDER, EV_TAUNT

### 8.3 Quest System
- **Status**: DONE (14-social-quest.md)
- **Source**: `Quest.cpp`
- **Key Types**: TQuest
- **Scope**: Quest creation, tracking, completion
- **Notes**: TQuest is minimal (just Flags[2]). Quest logic likely in event scripts.

---

## 9. Encounter & Population

### 9.1 Encounter Generation
- **Status**: DONE (12-encounter-generation.md)
- **Research**: `docs/research/specs/dungeon-generation/population.md`
- **Source**: `Encounter.cpp`
- **Key Types**: EncMember, TEncounter
- **Scope**: Monster/item generation within CR constraints, summoning effects, dungeon population, encounter balancing, template application, formation generation
- **EventInfo Fields**: en* (encounter fields), ep* (encounter part fields) - ~40 dedicated fields
- **Notes**: Encounter generation uses extensive EventInfo fields. TEncounter has Terrain, Weight, minCR/maxCR, Parts[MAX_PARTS]. Supports multi-part encounters with template stacking.

---

## 10. UI & Display

### 10.1 Terminal System
- **Status**: DONE (15-ui-display.md)
- **Source**: `Term.cpp`, `TextTerm.cpp`, `Wcurses.cpp`, `Wlibtcod.cpp`, `inc/Term.h`
- **Scope**: TextTerm class (80x50 text mode), window management (WIN_* constants, 26 window types), curses and libtcod backends, input handling
- **Notes**: Multiple backend implementations. Window system divides screen into regions (map, messages, stats, etc.). Key rendering integration point.

### 10.2 GUI Managers
- **Status**: DONE (15-ui-display.md)
- **Source**: `Managers.cpp`
- **Scope**: Spell manager, inventory manager, skill manager, barter manager, option manager
- **Notes**: Manager pattern for complex UI interactions (spell selection, inventory manipulation, etc.).

### 10.3 Message System
- **Status**: DONE (15-ui-display.md)
- **Source**: `Message.cpp`
- **Scope**: Message formatting, grammar handling (pronoun, plural, article generation), message queue, IPrint/IDPrint dispatch, conditional messages (seen/unseen actors)
- **Notes**: Complex grammar engine handles "You hit the goblin" vs "The orc hits the goblin" vs "Something hits you" based on perception.

### 10.4 Character Sheet
- **Status**: DONE (15-ui-display.md)
- **Source**: `Sheet.cpp`
- **Scope**: Character sheet display, stat block composition, character dump to file
- **Notes**: Formats all character data for display.

### 10.5 Help System
- **Status**: DONE (15-ui-display.md)
- **Source**: `Help.cpp`
- **Scope**: Online help, object descriptions, monster memory (remembered abilities/attacks)
- **Notes**: Help system provides context-sensitive information about game elements.

---

## 11. Data & Configuration

### 11.1 Tables, Globals & Static Data
- **Status**: DONE (16-data-tables.md)
- **Source**: `Tables.cpp`, `inc/Globals.h`
- **Scope**: Saving throw tables, static data arrays, 75 TextVal lookup arrays (enum-to-string mappings), 30+ calculation breakdown variables (spell power/DC/skill), 13 event dispatch Throw variants, game state globals, message/print system functions
- **Notes**: Globals.h declares core singletons (theGame, theRegistry, T1), event dispatch functions, print system (XPrint/DPrint/TPrint), and all static data tables. Tables.cpp provides pure data definitions.

### 11.2 Annotations
- **Status**: DONE (16-data-tables.md)
- **Source**: `Annot.cpp`
- **Scope**: Resource annotations (dungeon constants, race/monster equipment, map tile types, class abilities)
- **Notes**: Annotations extend Resources with typed metadata. Used for equipment grants, tile definitions, ability specifications.

### 11.3 Targeting System
- **Status**: DONE (04-creature-system.md Target System section, 16-data-tables.md)
- **Source**: `Target.cpp`, `inc/Target.h`
- **Scope**: Target selection, three-tier hostility evaluation (Specific → LowPriorityStati → Racial), 32-target fixed array, HostilityWhyType (23 reason codes), TargetType enum (creatures, areas, items, orders, memory flags), damage thresholds for turning hostile
- **Notes**: TargetSystem is embedded in every Creature. Evaluates hostility through three tiers with proof chains explaining *why* each relationship exists. Supports racial feuds, alignment conflicts, leader relationships, status effects, and personal grudges. Full detail in doc 04.

### 11.4 Debug & Dump
- **Status**: DONE (16-data-tables.md)
- **Source**: `Debug.cpp`
- **Scope**: Wizard mode functions, dump functions for all object types (lines 1856-1978 for resource dumps)
- **Notes**: Dump functions are essential references for verifying port correctness. Show expected field values and formats.

---

## 12. Scripting & Compilation

### 12.1 Scripting System (VMachine)
- **Status**: PARTIAL (see docs/research/scripting/)
- **Research**: `docs/research/scripting/` (6 files)
- **Source**: `VMachine.cpp`, `RComp.cpp`
- **Scope**: IncursionScript bytecode execution, script-to-C++ interface, compiled event handlers
- **Notes**: VMachine executes bytecode for resource event handlers. RComp is debug-only compiler. Research covers syntax mapping and approach options.

### 12.2 Parser & Lexer
- **Status**: PARTIAL (see docs/research/parser-research/)
- **Research**: `docs/research/parser-research/` (2 files)
- **Source**: `Tokens.cpp` (flex-generated), `yygram.cpp` (grammar-generated)
- **Scope**: IncursionScript lexer and parser, resource file (.irh) compilation
- **Notes**: Parser research covers token types and grammar structure. Runtime semantics less documented.

---

## Constant Categories (Defines.h)

45 categories totaling ~4700 lines:

| Category | Count | Purpose |
|----------|-------|---------|
| LEVEL_* | ~57 | Level-dependent scaling formulas |
| MVAL_* | 4 | Modifier value types |
| T_* | 92 | Object/resource type IDs |
| SL_* | 24 | Equipment slot positions |
| IT_* | 49 | Item type flags |
| AI_* | 60 | Item acquisition categories |
| AF_* | 32 | Artifact flags |
| TF_* | 28 | Terrain flags |
| RF_* | 28 | Room flags |
| CF_* | 17 | Class/race flags |
| DOF_* | 1 | Domain flags |
| GF_* | 21 | God flags |
| FF_* | 1 | Feature flags |
| MF_* | 1 | Map flags |
| BF_* | 32 | Monster behavior flags |
| NF_* | 31 | Encounter formation flags |
| RM_* | 32 | Room generation types |
| RC_* | 13 | Room population types |
| TU_* | 6 | Tunnel generation types |
| A_* | 114 | Attack/action types |
| M_* | 114 | Monster flags |
| TT_* | 16 | Surface terrain types (bitmask) |
| TMF_* | 6 | Template modifier flags |
| SZ_* | 8 | Size categories |
| PER_* | 10 | Perception types (bitmask) |
| MA_* | 130 | Monster archetypes/races |
| ATTR_* | 41 | Character attributes |
| SK_* | 49 | Skills |
| CA_* | 143 | Class abilities |
| PHD_* | 6 | Party/pet handling |
| WQ_* | 64 | Weapon qualities |
| AQ_* | 42 | Armor qualities |
| FT_* | 200+ | Feats |
| MM_* | 27 | Metamagic modifiers (bitmask) |
| STUDY_* | 10 | Study/expertise focuses |
| EP_* | 6 | Effect properties |
| ACT_* | 43 | In-game actions |
| BONUS_* | 39 | Bonus types |
| ADJUST_* | 18 | Status adjustments |
| EF_* | 105 | Effect flags |
| EA_* | 46 | Effect action types |
| WIN_* | 26 | Window types |
| OPT_* | ~100 | Game options |
| GLYPH_* | ~120 | Display glyphs |
| PRIO_* | ~10 | Rendering priorities |

---

## Priority Order for Research

### High Priority (core mechanics needed for any gameplay)
1. Values & Calculation System (3.5e rules engine)
2. Creature Core (base entity behavior)
3. Combat System (primary gameplay loop)
4. Item System (equipment and loot)
5. Status Effects (pervasive game mechanic)
6. Event System (connects everything)

### Medium Priority (needed for full gameplay)
7. Monster AI (enemy behavior)
8. Magic & Effects (spellcasting)
9. Skills & Feats (character progression)
10. Character Creation (game entry point)
11. Inventory Management
12. Feature System (doors, traps, stairs)
13. Encounter Generation (dungeon population)

### Lower Priority (polish and completion)
14. Prayer/Divine System
15. Social/NPC Interaction
16. Quest System
17. Message System (grammar engine)
18. Pathfinding
19. Terminal/UI
20. Help System
21. Overland
22. Tables & Static Data
23. Annotations
24. Targeting
25. Character Sheet
26. Debug/Dump (verification reference)
