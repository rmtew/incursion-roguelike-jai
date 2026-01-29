# Resource System

**Source**: `Res.cpp`, `inc/Res.h`
**Status**: Fully researched

## Overview

Resources are template definitions loaded from `.irh` script files. They define the properties of monsters, items, effects, terrain, etc. The resource system is the static data backbone of the game.

## Resource ID (rID)

```cpp
typedef unsigned long rID;
```

**Encoding**: 32-bit integer
- High byte (bits 24-31): Module slot + 1 (1-based; 0 means "no resource")
- Lower bits (0-23): Offset within module resource array

**Encoding formula**: `rID = 0x01000000 * (Slot + 1) + offset`

**Decoding**:
- Module index: `(xID >> 24) - 1`
- Offset: `xID & 0x00FFFFFF`

**Layout in Module**: Resources stored in cumulative order:
1. Monsters (offset 0)
2. Items (offset szMon)
3. Features (offset szMon + szItm)
4. Effects (offset szMon + szItm + szFea)
5. Artifacts, Quests, Dungeons, Routines, NPCs
6. Classes, Races, Domains, Gods, Regions, Terrains
7. Texts, Variables, Templates, Flavors, Behaviours, Encounters

Access macros for casting:
```cpp
RES(l)   → Resource*       TMON(l)  → TMonster*    TITEM(l) → TItem*
TEFF(l)  → TEffect*        TFEAT(l) → TFeature*    TRACE(l) → TRace*
TCLASS(l)→ TClass*         TART(l)  → TArtifact*   TDUN(l)  → TDungeon*
TTER(l)  → TTerrain*       TREG(l)  → TRegion*     TDOM(l)  → TDomain*
TGOD(l)  → TGod*           TTEM(l)  → TTemplate*   TFLA(l)  → TFlavor*
TTEX(l)  → TText*          TBEV(l)  → TBehaviour*  TENC(l)  → TEncounter*
NAME(l)  → display name    DESC(l)  → description  FIND(str)→ find by name
```

## Resource Base Class

```cpp
class Resource {
    int16 Type;           // Resource type (T_TMONSTER, etc.)
    int8 ModNum;          // Module number
    uint16 EventMask;     // Bitmask of events this resource handles
    hText Name, Desc;     // Text segment offsets
    int32 AnHead;         // Annotation chain head

    static Annotation *cAnnot, *cAnnot2;  // Two iteration cursors
    static String EvMsg[64];              // Event message strings
};
```

### Construction & Type
```cpp
Resource(int16 _Type);
bool isType(int16 rt);
String & GetName(uint16 fl);
```

### Annotation Management
```cpp
void AddResID(int8 at, rID sID);
void AddAbility(int8 at, int16 ab, uint32 p, int8 l1, int8 l2);
void AddElement(rID eID, int8 x, int8 y, uint16 fl);
void AddEvent(int16 ev, uint32 moc);
void AddChatter(uint8, const char* m1..m5);
void AddEquip(uint8 Chance, Dice amt, rID iID, rID eID, int8 spec, uint8 qual[4], uint8 fl, hCode cond);
void AddTile(char ch, Glyph img, uint8 fl, rID tID, rID xID, rID xID2);
Tile* GetTile(char ch);
void AddParam(int8 p, int16 v);
void AddArray(int8 p, int16 *list);
void AddConstant(int8 con, int32 val);
void AddList(int8 ln, uint32 *lv);
void AddSpecial(rID xID, int16 Chance, int16 lev);
void AddSpecial(rID xID, int16 Chance, Dice& lev);
void AddPower(int8 apt, int8 pw, uint32 x, int16 pa, Dice*charge);
```

### Annotation Queries
```cpp
uint32 GetConst(int16 cn);
bool GetList(int16 ln, rID *lv, int16 max);
bool HasList(int16 ln);
bool ListHasItem(int16 ln, int32 look_for);
rID  GetRes(int16 at, bool first);
rID  FirstRes(int16 at);
rID  NextRes(int16 at);
bool HasRes(rID xID, int16 at);
```

### Annotation Iteration
```cpp
Annotation* Annot(int32 i);
Annotation* FAnnot();      // First (cursor 1)
Annotation* NAnnot();      // Next (cursor 1)
Annotation* FAnnot2();     // First (cursor 2)
Annotation* NAnnot2();     // Next (cursor 2)
Annotation* NewAnnot(int8 at, int32*num, int32 *num2=NULL);
```

### Gameplay
```cpp
void GrantGear(Creature *c, rID xID, bool doRanged=true);
bool HandlesEvent(uint8 ev);
EvReturn Event(EventInfo &e, rID xID, int16 Event=0);
EvReturn PEvent(int16 ev, Thing *t, rID xID, int16 context=0);
EvReturn PEvent(int16 ev, Thing *actor, Thing *item, rID xID, int16 context=0);
String*  GetMessages(int16 ev);
String & RandMessage(int16 ev);
void Dump();
```

## Supporting Structures

### TAttack
```cpp
struct TAttack {
    int8 AType;     // Attack type (A_SLASH, A_BITE, etc.)
    int8 DType;     // Damage type (AD_SLASH, AD_FIRE, etc.)
    union {
        struct { Dice Dmg; int8 DC; } a;
        rID xID;    // Effect resource (special attacks)
    } u;
};
```

### EffectValues
```cpp
struct EffectValues {
    int8  eval;   // Effect value (basic archetype)
    int8  dval;   // Distance value (range)
    int8  aval;   // Area value (area of effect)
    int8  tval;   // Target value (what is affected)
    int8  qval;   // Query value (prompt flags)
    int8  sval;   // Save value (saving throw type)
    int8  lval;   // Level value (max HD, radius, etc.)
    int8  cval;   // Color of blast effect
    rID   rval;   // Resource value (or extra flags)
    uint8 xval;   // Misc (stati #, DType, etc.)
    int16 yval;   // Second misc (stati Val, etc.)
    Dice  pval;   // Power value (damage/healing dice)
};
```

### Status (Bitfield-packed)
```cpp
struct Status {
    unsigned Nature  :8;    // Status type enum
    signed   Val     :16;   // Value parameter
    signed   Mag     :16;   // Magnitude
    signed   Duration:16;   // Duration (-1 = permanent)
    unsigned Source  :8;    // Source type (SS_BODY, etc.)
    unsigned CLev   :6;    // Caster level
    unsigned Dis    :1;    // Disabled flag
    unsigned Once   :1;    // Once-only flag
    signed   eID    :32;   // Effect resource ID
    signed   h      :32;   // Object handle (source)
};
```

### Annotation (Union-based)
Flexible metadata attached to resources. WARNING comment in source: "DO NOT UNDER ANY CIRCUMSTANCES CHANGE THE SIZE OF THE ARRAYS."
- `int32 Next` - Linked list pointer
- `uint8 AnType` - Annotation type
- Union variants: `sp[8]` (spells), `ef` (EffectValues), `eq` (equipment), `ep[2]/ev[5]` (events/chatter), `me[4]` (map elements), `ti[2]` (tiles), `ab[4]` (abilities), `dc[6]` (constants), `dl` (lists), `ds[4]` (specials), `ap[3]` (powers)

### Tile
```cpp
struct Tile {
    rID tID, xID, xID2;  // Terrain, extra resources
    Glyph Image;          // Display glyph
    uint8 fl;             // Flags
    char ch;              // Character key
};
```

### EncPart (Encounter component)
```cpp
struct EncPart {
    uint32 Flags;     // Part flags
    uint8 Weight;     // Selection weight
    uint8 Chance;     // Chance to appear
    uint8 minCR;      // Minimum CR
    Dice  Amt;        // Number of creatures
    hCode Condition;  // Conditional code
    rID xID, xID2;   // Monster/template IDs
};
```

### DebugInfo
```cpp
struct DebugInfo {
    rID xID; int16 Event; int16 VarType; int16 RType;
    int32 Address; btype BType; int16 DataType; char Ident[32];
};
```

## 21 Resource Types

### TMonster (T_TMONSTER)
```cpp
Glyph Image;                    // Display glyph + color
uint32 Terrains;                // Valid terrain bitmask
int8 CR, Depth;                 // Challenge Rating, dungeon depth
int32 MType[3];                 // Monster type flags (3 words bitmask)
int8 Hit, Def, Arm;             // Base hit/defense/armor bonuses
int8 Mov, Spd;                  // Movement rate, speed
int8 Attr[7];                   // STR,DEX,CON,INT,WIS,CHA,LUC
int16 HitDice, Mana;
Status Stati[12];               // Built-in status effects (NUM_TMON_STATI=12)
TAttack Attk[32];               // Attack array (NUM_TMON_ATTK=32)
int8 Weight, Nutrition, Size;
uint16 Feats[16];               // Built-in feats
uint8 Flags[(M_LAST/8)+1];     // M_* flags bit array
uint32 Imm;                     // Immunities
uint16 Res;                     // Resistances
int8 Advancement;
uint8 MTypeCache[];             // Precomputed monster type lookups
```
Methods: `HasAttk()`, `HasDType()`, `GetAttk()`, `HasFeat()`, `SetFlag/UnsetFlag/HasFlag`, `HasSlot()`, `GainStati()`, `isMType()`, `InitializeMTypeCache()`, `Dump()`

### TItem (T_TITEM)
```cpp
uint32 Image;                   // Glyph
int16 IType;                    // Item type enum
int8 Level, Depth, Material, Nutrition;
int16 Weight;
uint16 hp;                      // Durability
int8 Size;
uint32 Cost, Group;             // Gold value, weapon/armor group bitmask
union {
    struct { Dice SDmg, LDmg; int8 Crit, Threat, RangeInc, Acc, Spd, ParryMod; } w;  // Weapon
    struct { int8 Arm[3]; int8 Cov, Def, Penalty; } a;                                 // Armor
    struct { int8 Capacity, MaxSize, WeightMod, CType, Timeout; int16 WeightLim; } c;  // Container
    struct { int8 LightRange; int16 Lifespan; rID Fuel; } l;                           // Light
} u;
uint8 Flags[(IT_LAST/8)+1];
```
Constructor defaults: Crit=2, Threat=1 (20/x2 critical)

### TEffect (T_TEFFECT)
```cpp
uint32 Schools;                 // School bitmask
int8 Sources[4];                // Spell sources (arcane, divine, etc.)
uint32 Purpose;                 // Purpose flags
uint8 ManaCost, BaseChance, SaveType;
int8 Level;
uint8 EFlags[(EF_LAST/8)+1];
EffectValues ef;                // Effect parameters
```
Methods: `Power()`, `Describe()`, `Vals(num)`, `HasSource()`, `SetFlag/UnsetFlag/HasFlag`

### TFeature (T_TFEATURE)
```cpp
uint32 Flags; int16 Image; uint8 FType, Level;
int8 MoveMod; uint16 hp; rID xID; int16 xval;
Dice Factor; int8 Material;
```

### TClass (T_TCLASS)
```cpp
uint8 HitDie, ManaDie, DefMod;
uint8 Skills[40];               // Class skill list
uint8 Saves[3];                 // Save progression (Fort/Ref/Will)
uint8 AttkVal[4];               // Attack bonus progression
uint8 SkillPoints;              // Per level
uint32 Proficiencies;           // Weapon/armor proficiency bitmask
uint8 Flags[(CF_LAST/8)+1];
```
Methods: `HasSkill()`, `SetFlag/UnsetFlag/HasFlag`

### TRace (T_TRACE)
```cpp
rID mID;                        // Associated monster template
rID BaseRace;                   // Parent race (subraces)
rID FavouredClass[3];
int8 AttrAdj[8];               // Attribute adjustments
int8 Skills[12];                // Racial skill bonuses
hText MNames, FNames, SNames;  // Name lists
uint8 Flags[(CF_LAST/8)+1];
```
Methods: `HasSkill()`, `SetFlag/UnsetFlag/HasFlag`

### TArtifact (T_TARTIFACT)
```cpp
rID iID;                        // Base item template
int8 Bonus, pval;
int8 AttrAdjLow[7], AttrAdjHigh[7];
uint32 Qualities, Resists;
uint8 Sustains;
uint8 Flags[(AF_LAST/8)+1];
```

### TDomain (T_TDOMAIN)
```cpp
int8 DType;
rID Spells[9];                  // Domain spells (levels 1-9)
uint8 Flags[(DOF_LAST/8)+1];
```
Methods: `Describe()`, `SetFlag/UnsetFlag/HasFlag`

### TGod (T_TGOD)
```cpp
hText Ranks[8];                 // Rank title text handles
rID Domains[12];                // Granted domains
rID ChosenWeapon;               // Favored weapon
rID Artifacts[6];               // Associated artifacts
uint8 Flags[(GF_LAST/8)+1];
```
Methods: `Describe()`, `SetFlag/UnsetFlag/HasFlag`

### TRegion (T_TREGION)
```cpp
int8 Depth, Size;
rID Walls, Floor, Door;         // Terrain types
int8 MTypes[4];                 // Monster types present
rID Furnishings[6];             // Feature resources
uint32 RoomTypes;               // Room type flags bitmask
uint8 sx, sy;                   // Grid size (fixed-layout)
hText Grid;                     // Grid layout text
uint8 Flags[(RF_LAST/8)+1];
```

### TTerrain (T_TTERRAIN)
```cpp
Glyph Image;
int8 MoveMod, Penalty, Material;
rID eID;                        // Associated effect
int8 SpecChance;
uint8 Flags[(TF_LAST/8)+1];
```

### TTemplate (T_TTEMPLATE)
```cpp
Glyph NewImage;
uint16 TType;
int8 DmgMod;
MVal HitDice, Hit, Def, CR, Mov, Spd, Weight, Size, Power, CasterLev, Arm;
MVal Attr[7];
Status Stati[12];               // NUM_TMON_STATI
int32 ForMType, AddMType;      // Type constraints
uint16 NewFeats[16];
TAttack NewAttk[16];
uint8 AddFlags[(M_LAST/8)+1];  // Flags to add
uint8 SubFlags[(M_LAST/8)+1];  // Flags to remove
uint8 Flags[TMF_LAST];         // Template's own flags
uint32 AddImm, SubImm;
uint16 AddRes, SubRes;
```
Methods: `HasFeat()`, `HasAttk()`, `GetNewAttk()`, `GainStati()`, `AddsFlag/SubsFlag()`, `Dump()`

### TDungeon (T_TDUNGEON)
No fields beyond Resource base. All data in annotations.

### TQuest (T_TQUEST)
```cpp
uint8 Flags[2];
```

### TRoutine (T_TROUTINE)
```cpp
hCode Location;                 // Code entry point
int8 ParamTypes[10];            // Up to 10 parameter types
int8 ParamCount, ReturnType;
```

### TNPC (T_TNPC)
```cpp
int8 BaseAttrs[7];
int8 StartingLevel;
rID ClassPath[36];              // Class per level (up to 36)
int8 AttrBonuses[30];
int8 FeatPriorities[50];
rID SpellPriorities[120];
int8 SkillPriorities[30];
```

### TText (T_TTEXT)
```cpp
int8 dsfdsfs;                   // Placeholder/vestigial field
```
All content accessed via text segment handles.

### TVariable (T_TVARIABLE)
```cpp
hData Location;                 // Handle to data segment location
```

### TFlavor (T_TFLAVOR)
```cpp
int8 IType, Weight, Material, Color;
```

### TBehaviour (T_TBEHAVIOUR)
```cpp
rID spID;                       // Spell-specific behaviour reference
uint32 Conditions;
uint8 Flags[(BF_LAST/8)+1];
```

### TEncounter (T_TENCOUNTER)
```cpp
uint32 Terrain;                 // Terrain type bitmask
int16 Weight, minCR, maxCR, Freak, Depth, Align;
EncPart Parts[MAX_PARTS];      // Monster groups
uint8 Flags[(NF_LAST/8)+1];
```

## Module Class

Container for all resources of a single module.

### Resource Arrays (21 typed)
```cpp
TMonster *QMon;   int16 szMon;     TItem *QItm;      int16 szItm;
TFeature *QFea;   int16 szFea;     TEffect *QEff;    int16 szEff;
TArtifact *QArt;  int16 szArt;     TQuest *QQue;     int16 szQue;
TDungeon *QDgn;   int16 szDgn;     TRoutine *QRou;   int16 szRou;
TNPC *QNPC;      int16 szNPC;     TClass *QCla;     int16 szCla;
TRace *QRac;      int16 szRac;     TDomain *QDom;    int16 szDom;
TGod *QGod;       int16 szGod;     TRegion *QReg;    int16 szReg;
TTerrain *QTer;   int16 szTer;     TText *QTxt;      int16 szTxt;
TVariable *QVar;  int16 szVar;     TTemplate *QTem;  int16 szTem;
TFlavor *QFla;    int16 szFla;     TBehaviour *QBev; int16 szBev;
TEncounter *QEnc; int16 szEnc;
```

### Segment Data
```cpp
const char *QTextSeg;   // Text segment (XOR-obfuscated on disk)
VCode *QCodeSeg;        // Code segment (bytecode)
int32 szTextSeg, szDataSeg, szCodeSeg;
```

### Cache
```cpp
Resource* GetResourceCache[4096];    // Fast lookup cache
rID GetResourceIndex[4096];          // Cache index
```

### Metadata
```cpp
OArray<Annotation,...> Annotations;  // All annotations
OArray<DebugInfo,...> Symbols;       // Debug symbol table
hText Name, FName;                   // Module name, filename
int16 Slot;                          // Module slot number
int32 TurnLastUsed;                  // For LRU management
```

### Key Methods
```cpp
// Resource Lookup
Resource* __GetResource(rID r);           // Internal uncached
Resource* GetResource(rID r);             // Cached lookup
Resource* GetResource(const char* name);  // By name
rID FindResource(const char*);            // Find rID by name
const char* GetText(hText ht);            // Resolve text handle

// Resource ID Generation (21 methods, one per type)
rID MonsterID(uint16 num);    // 0x01000000 * (Slot+1) + 0 + num
rID ItemID(uint16 num);       // 0x01000000 * (Slot+1) + szMon + num
// ... through EncounterID(num)

// Counts
int32 NumResources();
int16 SpellNum(TEffect*), GodNum(TGod*), TemplateNum(TTemplate*);

// Random Selection
rID RandomResource(uint8 RType, int8 Level, int8 Range);

// Memory
void* GetMemoryPtr(rID xID, int8 pn);

// Serialization: XOR-obfuscates text segment on save, un-XOR on load
```

## Game Class

Central singleton managing entire game state.

### Key Fields
```cpp
int16 Day; uint32 Turn; String SaveFile;
bool PlayMode, doSave, doLoad, doAutoSave, doQuit;
int8 Difficulty;

// Modules
static Module *Modules[MAX_MODULES];    // MAX_MODULES = 126
char *MDataSeg[MAX_MODULES];            // Per-module data segments
uint32 MDataSegSize[MAX_MODULES];

// Active objects
hObj m[4], p[4];                        // Maps and players (up to 4)
hObj Timestopper;                       // Time-stopping creature

// Dungeons
rID DungeonID[MAX_DUNGEONS];            // MAX_DUNGEONS = 32
int16 DungeonSize[MAX_DUNGEONS];
hObj *DungeonLevels[MAX_DUNGEONS];      // Dynamic map handle arrays

// Support
OArray<LimboEntry,...> Limbo;           // Entities waiting to enter a level
OArray<ModuleRecord,...> ModFiles;
__FindCache FindCache[128];             // Resource name lookup cache
VMachine VM;                            // Script virtual machine
int16 ItemGenNum, BarrierCount;

// Destroy queue (deferred deletion)
static Thing *DestroyQueue[20480];
static uint16 DestroyCount;
static Thing *cDestroyQueue[20480];     // Concurrent queue
static uint16 cDestroyCount;

// Performance counters (debug)
int32 ccHasEffStati, ccHasValStati, ccHasNatStati, ...;
```

### Key Methods
```cpp
// Game flow
TitleScreen(), StartMenu(), Play(), MultiPlay(), Cleanup();
NewGame(rID mID, bool reincarnate), LoadGame(bool), SaveGame(Player&);

// Resource access
Resource* Get(rID r), rID Find(const char*);
const char* GetName(rID), GetDesc(rID), GetText(rID, hText);

// Resource selection
rID RandomResource(...), GetItemID(...), GetMonID(...);
rID GetEffectID(...), GetEncounterID(...), GetTempID(...);

// Dungeon management
Map* GetDungeonMap(rID dID, int16 Depth, Player*, Map*);
void EnterLimbo(...), LimboCheck(Map*);

// Numbering
rID SpellID(uint16), GodID(uint16), TemplateID(uint16);
int16 SpellNum(rID), GodNum(rID), TemplateNum(rID);
uint16 LastSpell(), LastGod(), LastTemplate();
```

### Supporting Structures
```cpp
struct LimboEntry { hObj h, Target; uint8 x, y; rID mID;
    int8 Depth, OldDepth; uint32 Arrival; String Message; };
struct ModuleRecord { uint8 Slot; hObj hMod; char FName[1024]; };
struct __FindCache { rID xID; char str[32]; };
```

## Porting Status

### Already Ported
- Resource parser (lexer + parser in `src/resource/`)
- Resource runtime lookup (`src/resource/runtime.jai`)
- Glyph constants (`src/glyph_cp437.jai`)
- Basic resource types for dungeon generation

### Needs Porting
- Full TMonster, TItem, TEffect field sets
- TTemplate modifier application
- Annotation system (union-based linked list)
- Module text/code segments
- RandomResource selection algorithm
- Resource event dispatch
- Game class singleton and module management
