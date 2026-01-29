# Defines.h Comprehensive Constants Reference

**Source**: `inc/Defines.h` (4704 lines)
**Status**: Fully analyzed

## Overview

Defines.h is the central definition hub, shared between C++ and IncursionScript via `#ifdef ICOMP` guards. Contains all game constants, type definitions, and forward declarations.

## Type Definitions (C++ only)

| Type | Underlying | Purpose |
|------|-----------|---------|
| `int8` | `signed char` | 8-bit signed |
| `int16` | `signed short` | 16-bit signed |
| `uint8` | `unsigned char` | 8-bit unsigned |
| `uint16` | `unsigned short` | 16-bit unsigned |
| `uint32` | `unsigned long` | 32-bit unsigned |
| `int32` | `signed long` | 32-bit signed |
| `rID` | `unsigned long` | Resource ID handle |
| `Dir` | `signed char` | Direction value |
| `Glyph` | `uint32` | Packed glyph (12-bit ID + 4-bit fg + 4-bit bg) |
| `EvReturn` | `int8` | Event return value |
| `hText` | `signed long` | Text handle |
| `hCode` | `signed long` | Code handle |
| `hObj` | `signed long` | Object handle |

## Status Effects (237 types)

### Maladies (1-21)
SICKNESS, POISONED, BLINDNESS, HALLU, STUNNED, CONFUSED, SLEEPING, PARALYSIS, AFRAID, STUCK, BLEEDING, PRONE, STONING, DISEASED, NAUSEA

### Character Abilities (30-48)
WEP_SKILL, FAV_ENEMY, EXTRA_SKILL, TURN_ABILITY, SPECIALTY_SCHOOL, EXTRA_FEAT, INNATE_SPELL

### Special (60-97)
SPRINTING, GRABBED/GRAPPLED/GRAPPLING, HIDING, RAGING, SUMMONED, MAGIC_RES, TEMPLATE, ILLUSION, CHARGING, TUMBLING, SINGING, HUNGER, MOUNTED

Sub-values:
- BLIND: BLIND_UNWANTED, BLIND_EYES_CLOSED
- GRAB: GR_GRABBED, GR_GRAPPLED, GR_SWALLOWED
- HIDE: HI_SHADOWS, HI_CEILING, HI_UNDER, HI_WATER
- CHARM: CH_CHARM, CH_CALMED, CH_ALLY, CH_DOMINATE, CH_COMMAND

### Dispellable Magic (100-179)
INVIS, SEE_INVIS, PHASED, POLYMORPH, RESIST, ADJUST (18 sub-types for bonus sources), REGEN, LEVITATION, WARNING, FORTIFICATION, CHARMED, TIMESTOP, IMMUNITY

### Item/Misc (180-236)
COCKED, DAMAGED, WIZLOCK, MY_GOD, ALIGNMENT, ENCOUNTER

### Classification Macros
- `IsMagicStati()` - Dispellable magical effects
- `IsMaladyStati()` - Negative conditions
- `IsAdjustStati()` - Attribute adjustments
- `IsAbilityStati()` - Character abilities

## Damage Types (AD_*, ~75 types)

### Elemental
AD_FIRE, AD_COLD, AD_ACID, AD_ELEC, AD_SONI

### Special
AD_NECR (necrotic), AD_PSYC (psychic), AD_MAGC (magic), AD_FORCE

### Status-Inflicting
AD_SLEE (sleep), AD_STUN, AD_PLYS (paralysis), AD_STON (petrification), AD_POLY (polymorph), AD_CONF (confusion), AD_FEAR

### Drain Effects
AD_DREX (drain XP), AD_DRST through AD_DRLU (drain attributes: STR through LUC)

### Ability Damage
AD_DAST through AD_DALU (damage to attributes without drain)

### Combat Special
AD_GRAB, AD_TRIP, AD_DISA (disarm), AD_VAMP (vampiric)

### Damage Immunity Flags (DF_*, bitmask)
DF_FIRE(0x01), DF_COLD(0x02), DF_ACID(0x04), DF_ELEC(0x08), through DF_SUBD(0x10000000)

## Material Types (MAT_*, 35 types)

MAT_LIQUID(1), MAT_WAX(2), MAT_VEGITE(3), MAT_FLESH(4), MAT_LEATHER(5), MAT_WOOD(6), MAT_BONE(7), MAT_COPPER(8), MAT_IRON(9), MAT_SILVER(10), MAT_GOLD(11), MAT_PLATINUM(12), MAT_MITHRIL(13), MAT_ADAMANT(14), MAT_DRAGONHIDE(15), MAT_FORCE(16), MAT_MAGMA(17), MAT_CLOUD(18), ..., MAT_IRONWOOD(35)

## Saving Throw System

### Save Types
FORT(0), REF(1), WILL(2), NOSAVE(3)

### Save Subtypes (SA_*, 22 bitmask flags)
SA_MAGIC, SA_EVIL, SA_NECRO, SA_PARA, SA_DEATH, SA_ENCH, SA_PETRI, SA_POISON, SA_TRAPS, SA_GRAB, SA_FEAR, etc.

### Sequential Indices (SN_*, 1-22)
For array indexing of save subtypes.

## Weapon Groups (WG_*, bitmask, 18 types)

WG_SIMPLE, WG_EXOTIC, WG_SBLADES (short blades), WG_LBLADES (long blades), WG_AXES, WG_ARCHERY, WG_STAVES, WG_IMPACT, WG_POLEARMS, WG_LARMOUR (light), WG_MARMOUR (medium), WG_HARMOUR (heavy), WG_SHIELDS

## Area of Effect Types (AR_*, ~12 types)

AR_BOLT, AR_BEAM, AR_BALL, AR_RAY, AR_BURST, AR_TOUCH, AR_FIELD, AR_BARRIER, AR_BREATH, AR_CONE, AR_CHAIN

## Hunger System

| Constant | Value | Meaning |
|----------|-------|---------|
| BLOATED | 3000 | Overfull |
| SATIATED | 2500 | Well-fed |
| CONTENT | 2000 | Normal |
| PECKISH | 1500 | Slightly hungry |
| HUNGRY | 1000 | Need food |
| STARVING | 480 | Critical |
| WEAK | 240 | Very weak |
| FAINTING | 120 | About to collapse |
| STARVED | 0 | Dead from hunger |

## Religion System

### God Message Types (MSG_*, 80 types)
Various deity communication messages for different situations.

### Aid Types (AID_*, 17 types)
Types of divine aid a god can provide.

### Sacrifice Codes (SAC_*)
Types of offerings to deities.

### God Status Flags (GS_*, 7 types)
Player relationship state with each god.

### Trouble Types (TROUBLE_*, 17 types)
Types of divine punishment for transgressions.

## Personality Archetypes (PA_*, 16 types)

NPC personality types affecting dialogue and behavior.

## Field Flags (FI_*, 17 bitmask flags)

FI_MOBILE, FI_MODIFIER, FI_CONTINUAL, FI_ANTIMAG, FI_BLOCKER, FI_LIGHT, FI_FOG, FI_SHADOW, FI_SILENCE, FI_DARKNESS

## Naming Flags (NA_*, 15 bitmask flags)

Control how object names are formatted (articles, plurals, colors, etc.)

## Event Modifier Macros

Events can be intercepted at multiple phases:
```cpp
PRE(a)      = a + 500     // Before event
POST(a)     = a + 1000    // After event
EVICTIM(a)  = a + 2000    // Route to victim
EITEM(a)    = a + 4000    // Route to item
META(a)     = a + 10000   // Meta-event
GODWATCH(a) = a + 20000   // God observing
```

This allows resource scripts to hook into any event at any phase.

## VM Opcodes (63 instructions)

For IncursionScript bytecode VM:

### Arithmetic/Logic
ADD, SUB, MULT, DIV, MOD, NOT, BAND, BOR, MIN, MAX

### Control Flow
JUMP, HALT, JTRU, JFAL, CMXX (comparisons)

### Memory
MOV, LOAD, PUSH, POP, GVAR, SVAR

### Functions
RUN, RET, CALL, SYS

### Loops
REPI (repeat integer), REPD (repeat down), REPN (repeat N), REPE (repeat end)

### Strings
ASTR (append), MSTR (match), CSTR (compare), WSTR (write), ESTR (evaluate)

### Special
ROLL (dice roll)

## Dungeon Generation Constants (~80)

Key values:
- LEVEL_SIZEX/Y - Map dimensions
- PANEL_SIZEX/Y - Panel dimensions
- ROOM_MINX/MAXX/MINY/MAXY - Room size bounds
- DUN_DEPTH - Dungeon depth settings
- INITIAL_CR - Starting challenge rating
- TORCH_DENSITY - Light source frequency

## Door Flags (DF_*, 8 types)

Packed in int8: DF_OPEN, DF_STUCK, DF_LOCKED, DF_SECRET, DF_JAMMED, DF_BROKEN, DF_MAGIC_LOCK, DF_SEARCHED

## Object Flags (F_*, 18 bitmask flags)

F_SOLID, F_OPAQUE, F_HIDING, F_DELETE, F_UPDATE, etc.

## Knowledge Flags (KN_*, 8 flags)

KN_MAGIC, KN_PLUS, KN_QUALITY, KN_CURSE, KN_NATURE, etc.

## Item State Flags (IF_*, 11 flags)

IF_BLESSED, IF_CURSED, IF_WORN, IF_MASTERWORK, IF_BROKEN, etc.

## Glyph Encoding

32-bit packed format:
```
Bits 0-11:  Glyph ID (~4000 unique glyphs)
Bits 12-15: Foreground color (16 ANSI)
Bits 16-19: Background color (16 ANSI)
```

Macros: GLYPH_ID_MASK, GLYPH_FORE_MASK, GLYPH_BACK_MASK

## Architectural Patterns

1. **Dual-language header** - C++ and IncursionScript share constants via `#ifdef ICOMP`
2. **Numbered flags vs bitflags** - Two patterns: sequential IDs in flag arrays (M_*, IT_*) and direct bitmask (DF_*, SA_*, WG_*)
3. **Event phase routing** - PRE/POST/EVICTIM/EITEM/META/GODWATCH modifiers
4. **Level-scaling formulas** - LEVEL_* negative constants encode scaling curves
5. **OBJ_TABLE_SIZE = 65536** - Hash table for object registry (was 4096, increased after profiling)
