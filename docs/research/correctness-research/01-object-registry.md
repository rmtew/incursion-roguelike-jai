# Object & Registry System

**Source**: `Base.cpp`, `Registry.cpp`, `inc/Base.h`
**Status**: Fully researched

## Core Types

### Primitive Types
```cpp
rID    = unsigned long    // Resource ID (module << 24 | offset)
hObj   = signed long      // Object handle (registry index)
hData  = signed long      // Data handle
hText  = signed long      // Text segment offset
hCode  = signed long      // Code segment offset
Glyph  = unsigned long    // 32-bit glyph (char:12, fg:4, bg:4, ...)
Dir    = signed char      // Direction enum
EvReturn = signed char    // Event return (-1=ERROR, 0=NOTHING, 1=DONE, 2=ABORT, 3=NOMSG)
```

### String Class

Custom string with buffer management and canary guard value.

#### Fields
```cpp
class String {
    int32 Canary;     // 0xABCDEF12 for tmpstr-allocated; 0 otherwise
    char* Buffer;     // Heap-allocated via strdup/malloc/realloc
    int32 Length;     // strlen(Buffer), includes color-code bytes (negative chars)
};
```

#### Temporary String Pool
- `tmpstr(data, newbuff)` - Allocates a `String` on heap, adds pointer to `StrBufDelQueue[]`
- `StrBufDelQueue[STRING_QUEUE_SIZE]` - Circular queue, `STRING_QUEUE_SIZE = 64000`
- `PurgeStrings()` - When `iStrBufDelQueue >= 256`, sweeps queue freeing strings with valid canary
- `~String()` scans `StrBufDelQueue` to null out shared buffer entries, then `free(Buffer)`

#### Color Codes
Negative character values (char < 0) are embedded color codes. Two length methods:
- `GetTrueLength()` - Counts chars where `*ch > 0` (visible length)
- `TrueLength()` - Counts chars where `0 < ch < 127`, returns `int16`

#### All Methods
```cpp
// Constructors / Destructor
String();                              // Buffer=NULL, Length=0, Canary=0
String(const char*str);                // Copies via strdup()
~String();                             // Scans StrBufDelQueue, then Empty()

// Mutators
void Empty();                          // free(Buffer), set NULL, Length=0
void SetAt(int32 loc, char ch);        // Direct character write

// Operators
operator const char*();                // Returns Buffer
String & operator+=(const char*add);   // Append via x_realloc + strcpy
String & operator+=(char ch);          // Append single char
String & operator=(const char*s);      // strdup() new, Empty() old
String & operator=(String &s);         // Delegates to =(const char*)
String & operator+(const char*s);      // Creates tmpstr, appends
bool operator==(const char* s2);       // strcmp == 0 (handles NULL)
bool operator!=(const char* s2);
bool operator>(const char* s2);
bool operator<(const char* s2);

// Queries
const char* GetData();                 // Returns Buffer (inline)
int32 GetLength();                     // Returns Length (includes color codes)
int32 GetTrueLength();                 // Visible character count
int16 TrueLength();                    // Visible chars in [1,126] range
int32 strchr(char ch);                 // Offset of char, or 0 if not found
int8 GetAt(int32 loc);                 // Char at loc, or 0 if out of bounds

// Substrings (all return tmpstr references)
String & Left(int32 sz);              // First sz bytes
String & TrueLeft(int32 sz);          // First sz visible chars
String & TrueRight(int32 sz);         // Last sz visible chars
String & Right(int32 sz);             // Last sz bytes
String & Mid(int32 start, int32 end); // Substring from start to end inclusive
String & Trim();                       // Strip leading/trailing whitespace

// Parsing
String & Upto(const char* chlist);     // Everything before first char in chlist
String & After(const char* chlist);    // Everything after first char in chlist

// Transformation
String & Capitalize(bool all=false);   // Capitalize first (or all) words
String & Replace(const char* find, const char* rep);
String & Upper();
String & Lower();
String & Decolorize();                 // Strip all color codes (negative chars)

// Serialization
void Serialize(Registry &r);           // r.Block((void**)(&Buffer), Length+1)
```

#### Free Functions
```cpp
String * tmpstr(const char*data, bool newbuff=true);
void PurgeStrings();
String & VFormat(const char*fmt, va_list ap);  // vsprintf into static 32000-byte buffer
String & Format(const char*fmt, ...);
String & Pluralize(const char* s, rID iID=0);
String & Replace(const char* str, const char* find, const char* rep);
// Free-function wrappers: Capitalize, Left, Right, Trim, Mid, Upto, After, Upper, Lower, Decolorize
```

### Array Template

```cpp
template<class S, int32 Initial, int32 Delta> class Array
```
- `S* Items` - malloc'd array of elements
- `uint32 Size` - Current allocated capacity
- `uint32 Count` - Number of used elements

#### Growth Strategy
- **Enlarge()**: If `Count + Delta + 10 < Size`, no-op. If Items NULL, malloc `max(Initial, Delta)`. Otherwise `x_realloc` to `Size + Delta`, memset new region to 0.
- **Reduce()**: Completely disabled (commented out).
- **Add()**: If `Count >= Size`, Enlarge(), then `Items[Count++] = item`.
- **Set(idx)**: Repeatedly Enlarge() until `Size > idx+1`, then `Count = max(Count, idx+1)`.

#### Methods
```cpp
Array();                       // malloc(Initial * sizeof(S)), memset to 0
~Array();                      // free(Items)
void Set(S&, uint32 idx);     // Set at index, auto-grow
int32 Add(S&);                // Append, returns new index
int32 Total();                // return Count
void Remove(uint32 i);        // Remove at index, memmove remaining down
S* NewItem();                 // Append uninitialized slot, return pointer
void Serialize(Registry &r);  // r.Block for Items array
void Clear();                 // Count = 0 (does NOT free memory)
```

#### Variants
- **NArray** - Value semantics. `operator[](int32)` returns reference (or reference to ZeroValue if out of bounds). `RemoveItem(S)` removes all matching values.
- **OArray** - Pointer semantics. `operator[](int32)` returns pointer (or NULL if out of bounds). `RemoveItem(S*)` removes all matching pointers.

Note: There is no `SortArray` class in the codebase.

#### Concrete Instantiations
```cpp
Array<Field,10,5>               // Map::Fields
Array<hObj,1000,10>             // Map::Things
Array<hObj,30,30>               // Various
Array<hObj,5,5>                 // Various
Array<Status,0,1>               // Creature::Stati
Array<GroupNode,20,2>           // Registry::Groups
Array<Object*,10,10>            // LoadGroup::LoadedObjects
Array<uint16,20,20>             // Map::TorchList
Array<LimboEntry,20,10>        // Game::Limbo
Array<MTerrain,0,10>            // Map::TerraXY
Array<TerraRecord,0,5>         // Map::TerraList
Array<Annotation,ANNOT_INITIAL_SIZE,20> // Module::Annot
Array<ModuleRecord,5,5>        // Game::ModFiles
Array<uint16,200,200>          // PQueue::Elements
Array<hObj,10,20>              // Thing::backRefs
Array<uint16,5,5>              // yyMapSize (resource compiler)
Array<DebugInfo,1000,1000>     // Module::DI
```

### Dice Struct
```cpp
struct Dice {
    int8 Number;    // Number of dice (can be negative)
    int8 Sides;     // Sides per die
    int8 Bonus;     // Flat modifier
};
```

#### Roll Semantics
- Instance `Roll()`: Rolls `abs(Number)` dice of Sides, sums them.
  - Number > 0: adds Bonus, clamps result to min 0
  - Number < 0: subtracts Bonus, clamps result to max 0
  - Number == 0: returns just the sum (no clamping)
- Static `Roll(n, s, b, e)`: Rolls n dice of s sides, adds b. Result clamped to min 0. Parameter `e` is unused.
- Sides < 0 is a Fatal error.

#### Str() Formatting
- Sides <= 0: returns `"%d"` of Bonus only
- Sides == 1: returns `"%d"` of (Number + Bonus) -- collapses 7d1+2 to "9"
- Bonus != 0: returns `"%dd%d%+d"` (e.g., "2d6+3")
- Bonus == 0: returns `"%dd%d"` (e.g., "2d6")

#### Other Methods
```cpp
int16 Roll();                              // Instance roll
static int16 Roll(int8 n, int8 s, int8 b=0, int8 e=0); // Static roll
Dice& LevelAdjust(int16 level, int16 spec=0);  // Each component through ::LevelAdjust()
void Set(int8 n, int8 s, int8 b);         // Direct setter
bool operator==(Dice &d);                 // All three components match
```

### MVal (Modifier Value)

Bitfield struct for attribute modifiers, 28 bits packed into 32:
```cpp
struct MVal {
    signed int Value:10;     // -512..511
    unsigned int VType:4;    // Value type
    signed int Bound:10;     // -512..511
    unsigned int BType:4;    // Bound type
};
```

#### Adjust(int16 oval) - Two Phase Algorithm

**Phase 1 - Apply VType:**
| VType | Formula |
|-------|---------|
| `MVAL_NONE (0)` | `nval = oval` |
| `MVAL_ADD (1)` | `nval = max(0, oval + Value)` |
| `MVAL_SET (2)` | `nval = Value` |
| `MVAL_PERCENT (3)` | `nval = (oval * Value) / 100` |

**Phase 2 - Apply BType:**
| BType | Formula |
|-------|---------|
| `MBOUND_NONE (0)` | No bounding |
| `MBOUND_MIN (1)` | `nval = max(Bound, nval)` |
| `MBOUND_MAX (2)` | `nval = min(Bound, nval)` |
| `MBOUND_NEAR (3)` | `nval = max(nval, (nval + Bound*2) / 3)` |

Note: MBOUND_NEAR appears to apply the same formula regardless of direction, which may be a copy-paste bug in the original.

### Rect Struct
```cpp
struct Rect { uint8 x1, x2, y1, y2; }
```
- Methods: `Within()`, `PlaceWithin()`, `Overlaps()`, `Volume()`

### Fraction Class
- `int32 m_numerator, m_denominator`
- `Normalize()`, comparison operators

## Object System

### Object (Root Class)
Base class for ALL game objects:
- `int16 Type` - Object type (T_* constant)
- `hObj myHandle` - Registry handle
- Virtual methods: `Name()`, `Describe()`, `Dump()`, `Serialize()`
- Type checks: `isCreature()`, `isFeature()`, `isItem()`, `isPlayer()`, `isMonster()`, `isCharacter()`, `isContainer()`

### Thing (Physical Object Base)
Inherits Object. Base for all dungeon entities:
- `Map* m` - Containing map
- `hObj Next, hm` - Linked list and map handle
- `int16 x, y` - Position
- `Glyph Image` - Display glyph
- `int16 Timeout` - Action timer
- `uint32 Flags` - Behavior flags
- `String Named` - Custom name
- `StatiCollection __Stati` - Status effects
- `NArray<hObj,10,20> backRefs` - Back references

Key virtual methods:
- `SetImage()`, `Initialize()`, `Event()`, `DoTurn()`, `Move()`, `Remove()`
- `StatiOn()`, `StatiOff()` - Status effect callbacks
- `PlaceAt()`, `PlaceNear()`, `PlaceOpen()` - Placement
- `DirTo()`, `DistFrom()` - Spatial queries
- `ProjectTo()`, `ProjectDir()` - Line projection

## Registry System

### Hash Table Design
```cpp
#define OBJ_TABLE_SIZE   65536      // Object hash table size (was 4096, profiled)
#define OBJ_TABLE_MASK   65535      // h & mask instead of h % size
#define DATA_TABLE_SIZE  512        // Data block hash table
#define DATA_TABLE_MASK  511
```

### RegNode Structure
```cpp
struct RegNode {
    Object   *pObj;    // Registered object
    RegNode  *Next;    // Collision chain
};

struct DataNode {
    void     *pData;   // Data block pointer
    int32     Size;    // Block size
    hObj      hOwner;  // Owning object handle
    hData     myHandle;// Data block handle
    DataNode *Next;    // Collision chain
};
```

### Registry Fields
```cpp
class Registry {
    RegNode  ObjTable[OBJ_TABLE_SIZE];   // 65536-entry inline hash table
    DataNode DataTable[DATA_TABLE_SIZE]; // 512-entry data block table
    OArray<GroupNode,20,2> Groups;       // Save/load group tracking
    int32 TimeCounter;
    bool saveMode, loadMode;
    hObj hCurrent;                       // Currently serializing handle
    FILE *fp;
  public:
    hObj LastUsedHandle;                 // Monotonic counter, starts at 128
    hObj hModule;                        // Module handle
};
```

### Handle Allocation
- Handles start at 128 (0-127 reserved for system objects and NULL)
- `LastUsedHandle` increments monotonically
- New objects get `LastUsedHandle++`; loaded objects reuse saved handle
- Hash slot: `h & OBJ_TABLE_MASK` (power-of-2 table)

### Lookup Algorithm (Get)
```cpp
Object* Registry::Get(hObj h) {
    if (h <= 0) return NULL;
    if (h < 128) return theGame->VM.GetSystemObject(h);  // System objects
    RegNode *r = &(ObjTable[h & OBJ_TABLE_MASK]);
    do {
        if (r->pObj && r->pObj->myHandle == h) return r->pObj;
        r = r->Next;
    } while (r);
    Error("invalid object handle");
    return NULL;
}
```

### Insert Algorithm (RegisterObject)
```cpp
hObj Registry::RegisterObject(Object *o, bool loaded) {
    hObj h = loaded ? o->myHandle : LastUsedHandle++;
    hData hm = h & OBJ_TABLE_MASK;
    RegNode *r = &(ObjTable[hm]);
    if (!r->pObj) {
        ObjTable[hm].pObj = o;          // Inline slot (no allocation)
    } else {
        while(r->Next) r = r->Next;
        r->Next = new RegNode;          // Collision: append to chain
        r->Next->pObj = o;
        r->Next->Next = NULL;
    }
    return h;
}
```

### Remove Algorithm
Walks chain at `ObjTable[h & OBJ_TABLE_MASK]`, handles:
1. First node, no chain: NULL the pObj
2. First node with chain: copy next node data into first, delete next
3. Middle/end node: unlink and delete

Also cleans DataTable entries for T_MODULE, T_PLAYER, T_MAP objects.

### Key Methods
```cpp
Registry();                              // memset tables to 0, LastUsedHandle = 128
void Empty();                            // Re-zero tables, LastUsedHandle = 128
bool Saving(), Loading();                // Mode queries
void Block(void **Block, size_t sz);     // Save/load a data block
hData RegisterBlock(void *o, hObj Owner, size_t sz, hData h = 0);
void ClearDataTable();
hObj RegisterObject(Object*o, bool loaded=false);
void RemoveObject(Object*);
Object* Get(hObj h);
bool Exists(hObj h);
void* GetData(hData h);
hObj GetModuleHandle();

// Type-safe accessors (with ASSERTs):
Thing* GetThing(hObj h);
Player* GetPlayer(hObj h);
Creature* GetCreature(hObj h);
Item* GetItem(hObj h);
Annotation* GetAnnot(hObj h);
Map* GetMap(hObj h);

// Serialization
int16 SaveGroup(Term &t, hObj hGroup, bool use_lz, bool newFile=false);
int16 LoadGroup(Term &t, hObj hGroup, bool use_lz);
```

### Handle Access Macros
```cpp
#define oThing(h)     ( theRegistry->GetThing(h) )
#define oCreature(h)  ( theRegistry->GetCreature(h) )
#define oItem(h)      ( theRegistry->GetItem(h) )
#define oMap(h)       ( theRegistry->GetMap(h) )
```

### Global Instances
```cpp
Registry MainRegistry;
Registry ResourceRegistry;
Registry *theRegistry = &MainRegistry;   // Active registry
```

## VMachine (Script Virtual Machine)

**Source**: `inc/Res.h` (lines 61-98), `src/VMachine.cpp`

### Architecture
```cpp
class VMachine {
    static int32 Regs[64];           // 64 integer registers
    static String SRegs[64];         // 64 string registers
    static int32 Stack[8192];        // Operand stack
    static String VStr[256];         // String pool
    static uint32 StrUsed[(256/8)+1];// String usage bitmap
    static Breakpoint Breakpoints[64];
    static int16 nBreakpoints;
    static int32* Memory;            // Data segment pointer (per-module)
    static int32 szMemory;           // Data segment size
    int8 mn;                         // Current module number
    rID xID;                         // Current resource ID
    bool isTracing;                  // Debug trace active
    EventInfo *pe;                   // Current event
    Object *Subject;                 // Subject of execution
};
```

### VCode Instruction Format (32 bits)
```cpp
struct VCode {
    unsigned int Opcode:6;      // 6 bits: opcode (0-63)
    signed int Param1:10;       // 10 bits: first parameter (-512..511)
    unsigned int P1Type:3;      // 3 bits: parameter type flags
    signed int Param2:10;       // 10 bits: second parameter
    unsigned int P2Type:3;      // 3 bits: parameter type flags
};
```

Parameter type flags:
- `RT_REGISTER (1)` - Value is register number
- `RT_MEMORY (2)` - Value is memory address
- `RT_REGISTER + RT_MEMORY (3)` - Indirect: register holds memory address
- `RT_EXTENDED (4)` - Full int32 in next VCode word(s)
- `0` - Literal/immediate value

### System Object Handles (1-10)
```cpp
SOBJ_E        = 1    // EventInfo pointer
SOBJ_ETERM    = 2    // Terminal
SOBJ_EPLAYER  = 3    // Player
SOBJ_EACTOR   = 4    // Event actor (Creature)
SOBJ_ETARGET  = 5    // Event target (Thing)
SOBJ_EVICTIM  = 6    // Event victim (Creature)
SOBJ_EITEM    = 7    // Event item
SOBJ_EITEM2   = 8    // Second event item
SOBJ_EMAP     = 9    // Event map
SOBJ_GAME     = 10   // Game object
```

### All 63 Opcodes

| # | Name | Semantics |
|---|------|-----------|
| 0 | *(sentinel)* | Loop terminator |
| 1 | `JUMP` | `vc += (V1 - 1)` relative jump |
| 2 | `HALT` | Return NOTHING, restore stack pointer |
| 3 | `ADD` | `R0 = V1 + V2` |
| 4 | `SUB` | `R0 = V1 - V2` |
| 5 | `MULT` | `R0 = V1 * V2` |
| 6 | `DIV` | `R0 = V1 / V2` |
| 7 | `MOD` | `R0 = V1 % V2` |
| 8 | `MOV` | `*LV1 = V2` (move/assign) |
| 9 | `BSHL` | `R0 = V1 >> V2` (NOTE: label says "shift left", implements right) |
| 10 | `BSHR` | `R0 = V1 << V2` (NOTE: label says "shift right", implements left) |
| 11 | `JTRU` | If V1 truthy, `vc += (V2 - 1)` |
| 12 | `JFAL` | If V1 falsy, `vc += (V2 - 1)` |
| 13 | `CMEQ` | `R0 = (V1 == V2)` |
| 14 | `CMNE` | `R0 = (V1 != V2)` |
| 15 | `CMGT` | `R0 = (V1 > V2)` |
| 16 | `CMLT` | `R0 = (V1 < V2)` |
| 17 | `CMLE` | `R0 = (V1 <= V2)` |
| 18 | `CMGE` | `R0 = (V1 >= V2)` |
| 19 | `LOAD` | Defined but NOT handled in Execute switch |
| 20 | `NOT` | `R0 = !V1` (logical NOT) |
| 21 | `NEG` | `R0 = ~V1` (bitwise complement, despite name) |
| 22 | `BAND` | `R0 = V1 & V2` |
| 23 | `BOR` | `R0 = V1 \| V2` |
| 24 | `RUN` | No-op (commented out `Execute(vc+Value1)`) |
| 25 | `RET` | Return V1, restore stack pointer |
| 26 | `CALL` | Defined but NOT handled |
| 27 | `PUSH` | `Stack[R63++] = V1` |
| 28 | `POP` | `R63 -= V1` (pop N items) |
| 29 | `SYS` | Defined but NOT handled |
| 38 | `REPI` | Repeat by increment (not handled) |
| 39 | `REPD` | Repeat by decrement (not handled) |
| 40 | `REPN` | Repeat until V1 != V2 (not handled) |
| 41 | `REPE` | Repeat until V1 == V2 (not handled) |
| 42 | `CMEM` | `CallMemberFunc(V2, V1, 0)` - call C++ member function |
| 43 | `GVAR` | `GetMemberVar(V2, V1, 0)` - get C++ member variable |
| 44 | `SVAR` | `SetMemberVar(V2, V1, R0)` - set C++ member variable |
| 45 | `GOBJ` | Defined but NOT handled |
| 46 | `JTAB` | Jump table: V1=value, V2=table_size, followed by {value,offset} pairs |
| 47 | `SBRK` | Set break: push `vc + V1` onto BreakStack |
| 48 | `FBRK` | Free break: pop BreakStack |
| 49 | `JBRK` | Jump to break: `vc = BreakStack[--bsp]` |
| 50 | `ROLL` | `R0 = Dice::Roll(V1, V2)` |
| 51 | `INC` | `*LV1 += V2` |
| 52 | `DEC` | `*LV1 -= V2` |
| 53 | `MIN` | `R0 = min(V1, V2)` |
| 54 | `MAX` | `R0 = max(V1, V2)` |
| 55 | `LAND` | `R0 = V1 && V2` (logical AND) |
| 56 | `LOR` | `R0 = V1 \|\| V2` (logical OR) |
| 57 | `ASTR` | String concat: `SReg[-1] = STR(V1) + STR(V2)` |
| 58 | `MSTR` | Defined but NOT handled |
| 59 | `CSTR` | String compare: `R0 = stricmp(STR(V1), STR(V2))` |
| 60 | `WSTR` | String write: `STR(V1) = STR(V2)` |
| 61 | `ESTR` | String empty: `STR(V1).Empty()` |
| 62 | `CONT` | Defined but NOT handled |
| 63 | `LAST` | Same as HALT |

Opcodes 30-37 are undefined (gap).

### Execution Model
1. **Entry**: `Execute(EventInfo *e, rID xID, hCode CP)` - loads Memory from `theGame->MDataSeg[mn]`
2. **Code pointer**: `VCode *vc = Modules[mn]->QCodeSeg + CP`
3. **Main loop**: `while ((++vc)->Opcode)` - opcode 0 is sentinel
4. **Register convention**: R0 = accumulator, R63 = stack pointer
5. **Stack pointer**: Saved/restored on HALT/RET to prevent corruption
6. **String handling**: Negative hText values index `SRegs[-ht]`; non-negative index module text segment
7. **Script-C++ bridge**: `Dispatch.h` (auto-generated from `Api.h`) provides `CallMemberFunc`, `GetMemberVar`, `SetMemberVar`

### Key Methods
```cpp
int32 Execute(EventInfo *e, rID xID, hCode CP);  // Main entry
int32 Execute(Thing*t, rID xID, hCode CP);        // Thing subject entry
Object* GetSystemObject(hObj h);                   // Map handle 1-10
void SystemFunc(int16 funcid, int32 param);        // Built-in system calls
void CallMemberFunc(int16 funcid, hObj h, int8 n); // Script-to-C++ call
void GetMemberVar(int16 varid, hObj h, int8 n);    // Script-to-C++ read
void SetMemberVar(int16 varid, hObj h, int32 val); // Script-to-C++ write
```

## Serialization

All persistent objects use ARCHIVE_CLASS macro:
```cpp
#define ARCHIVE_CLASS(ClassName, Base, r) \
  friend class Registry; protected: \
  ClassName(Registry*r) : Base(r) {} \
  virtual size_t ObjectSize() { return sizeof(ClassName); } \
  virtual void Serialize(Registry &r, bool isSave) { \
    Base::Serialize(r,isSave);
#define END_ARCHIVE }
```

## Porting Considerations

1. **hObj handles** - Can use integer indices into a flat array, or tagged unions
2. **String** - Jai has built-in string type; need to handle color codes
3. **Array** - Jai has `[..]` dynamic arrays built in
4. **Dice** - Simple struct, already ported
5. **MVal** - Jai supports bitfield-like structs via bit operations
6. **Serialization** - Jai doesn't have virtual dispatch; need explicit type switches or procedure tables
7. **Virtual methods** - Core design challenge: Jai has no inheritance. Options:
   - Tagged union with procedure tables
   - Interface pattern with function pointers
   - Switch-based dispatch on type field
8. **Glyph encoding** - Already partially ported in `glyph_cp437.jai`
9. **Registry** - 65536-entry hash table with chained collisions; straightforward in Jai
10. **VMachine** - May not need full port if IncursionScript is replaced with native Jai code
