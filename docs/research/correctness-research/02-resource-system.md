# Resource System

**Source**: `Res.cpp`, `inc/Res.h`
**Status**: Researched from headers; parser partially researched

## Overview

Resources are template definitions loaded from `.irh` script files. They define the properties of monsters, items, effects, terrain, etc. The resource system is the static data backbone of the game.

## Resource ID (rID)

```cpp
typedef unsigned long rID;
```

**Encoding**: 32-bit integer
- High byte (bits 24-31): Module slot + 1
- Lower bits (0-23): Offset within module resource array

**Layout in Module**: Resources stored in fixed order:
1. Monsters (offset 0)
2. Items (offset szMon)
3. Features (offset szMon + szItm)
4. Effects (offset szMon + szItm + szFea)
5. ...continued for all 21 types

Access functions: `MonsterID(num)`, `ItemID(num)`, `FeatureID(num)`, etc.

## Resource Base Class

```cpp
class Resource {
    int16 Type;           // Resource type
    int8 ModNum;          // Module number
    uint16 EventMask;     // Events this resource handles
    hText Name, Desc;     // Text segment offsets
    int32 AnHead;         // Annotation chain head
};
```

Key methods:
- `GetName(flags)` - Get resource name
- `HandlesEvent(ev)` - Check if resource handles event type
- `Event(e, xID)` - Execute resource event handler
- `GetConst(cn)` - Get constant value from annotations
- `GetList(ln, lv, max)` - Get list from annotations
- `FirstRes(at)`, `NextRes(at)` - Iterate sub-resources
- `GrantGear(...)` - Grant equipment to creature

## 21 Resource Types

### TMonster (Monster Template)
```cpp
Glyph Image;
uint32 Terrains;             // Allowed terrain bitmask
int8 CR, Depth;              // Challenge rating, depth
int32 MType[3];              // Monster type flags
int8 Hit, Def, Arm;          // Combat modifiers
int8 Mov, Spd;               // Movement, speed
int8 Attr[7];                // STR,DEX,CON,INT,WIS,CHA,MOV
int16 HitDice, Mana;
Status Stati[12];            // Built-in status effects
TAttack Attk[32];            // Attack definitions
int8 Weight, Nutrition, Size;
uint16 Feats[16];
uint8 Flags[(M_LAST/8)+1];  // M_* flags bit array
uint32 Imm;                  // Immunities
uint16 Res;                  // Resistances
int8 Advancement;
```

### TItem (Item Template)
```cpp
uint32 Image;
int16 IType;                 // Item type (T_WEAPON, T_ARMOUR, etc.)
int8 Level, Depth;
int8 Material, Nutrition;
int16 Weight;
uint16 hp;
int32 Cost, Group;
union {
    struct { Dice SDmg, LDmg; int8 Crit, Threat, ... } w;  // Weapon
    struct { int8 Arm[3]; int8 Cov, Def, Penalty; } a;      // Armor
    struct { int8 Capacity, MaxSize; int16 WeightLim; } c;   // Container
    struct { int8 LightRange; int16 Lifespan; rID Fuel; } l; // Light
} u;
uint8 Flags[(IT_LAST/8)+1];
```

### TEffect (Spell/Effect Template)
```cpp
uint32 Schools;              // School bitmask
int8 Sources[4];             // Spell sources (arcane, divine, etc.)
uint32 Purpose;              // Effect purpose flags
uint8 ManaCost, BaseChance, SaveType;
int8 Level;
uint8 EFlags[(EF_LAST/8)+1]; // EF_* flags
EffectValues ef;             // Effect parameters
```

### TTemplate (Monster Modifier)
Modifies base TMonster with additions/subtractions:
```cpp
Glyph NewImage;
uint16 TType;
MVal HitDice, Hit, Def, CR, Mov, Spd, Weight, Size, Power, CasterLev, Arm;
MVal Attr[7];
Status Stati[12];
int32 ForMType, AddMType;   // Type constraints
uint16 NewFeats[16];
TAttack NewAttk[16];
uint8 AddFlags[], SubFlags[]; // Flags to add/remove
uint32 AddImm, SubImm;
uint16 AddRes, SubRes;
```

### Other Resource Types
| Type | Key Fields | Purpose |
|------|-----------|---------|
| TFeature | Flags, Image, FType, Level, hp | Dungeon feature templates |
| TClass | HitDie, ManaDie, Skills[40], Saves[3], AttkVal[4], Proficiencies | Character classes |
| TRace | mID, BaseRace, AttrAdj[8], FavouredClass[3] | Character races |
| TArtifact | iID, Bonus, AttrAdj, Qualities, Resists | Unique items |
| TDomain | DType, Spells[9] | Cleric domains |
| TGod | Ranks[8], Domains[12], ChosenWeapon, Artifacts[6] | Deities |
| TRegion | Depth, Size, Walls/Floor/Door rIDs, MTypes[4], RoomTypes | Dungeon regions |
| TTerrain | Image, MoveMod, Penalty, Material, eID | Terrain types |
| TDungeon | (minimal - base class only) | Dungeon definitions |
| TQuest | Flags[2] | Quest templates |
| TRoutine | Location, ParamTypes[10], ReturnType | Script routines |
| TNPC | BaseAttrs[7], ClassPath[36], Priorities | NPC templates |
| TText | (minimal) | Text blocks |
| TVariable | Location | Script variables |
| TFlavor | IType, Weight, Material, Color | Item flavors |
| TBehaviour | spID, Conditions, Flags | AI behaviors |
| TEncounter | Terrain, Weight, CR range, Parts[] | Encounter templates |

## Module Class

Container for all resources of a single module:
```cpp
class Module : public Object {
    TMonster *QMon; TItem *QItm; TFeature *QFea; TEffect *QEff;
    TArtifact *QArt; TQuest *QQue; TDungeon *QDgn; TRoutine *QRou;
    TNPC *QNPC; TClass *QCla; TRace *QRac; TDomain *QDom;
    TGod *QGod; TRegion *QReg; TTerrain *QTer; TText *QTxt;
    TVariable *QVar; TTemplate *QTem; TFlavor *QFla;
    TBehaviour *QBev; TEncounter *QEnc;
    const char *QTextSeg;  // Text segment
    VCode *QCodeSeg;       // Bytecode segment
};
```

Key methods:
- `GetResource(rID)` - Get resource by ID
- `FindResource(name)` - Find by name
- `GetText(hText)` - Get text from segment
- `RandomResource(type, level, range)` - Random selection

## Annotation System

Flexible metadata attached to resources:
```cpp
struct Annotation {
    // Union containing:
    // - Effect values (EffectValues)
    // - Abilities
    // - Tiles
    // - Equipment grants
    // - Powers
    // - Constants
    // - Resource lists
};
```

Accessed via: `Annot(index)`, `GetConst(cn)`, `GetList(ln, lv, max)`, `FirstRes(at)`, `NextRes(at)`

## Porting Status

### Already Ported
- Resource parser (lexer + parser in `src/resource/`)
- Resource runtime lookup (`src/resource/runtime.jai`)
- Glyph constants (`src/glyph_cp437.jai`)
- Basic resource types for dungeon generation

### Needs Porting
- Full TMonster, TItem, TEffect field sets
- TTemplate modifier application
- Annotation system
- Module text/code segments
- RandomResource selection algorithm
- Resource event dispatch
