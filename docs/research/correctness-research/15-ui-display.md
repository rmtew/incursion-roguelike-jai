# UI & Display System

**Source**: `Term.cpp`, `TextTerm.cpp`, `Wcurses.cpp`, `Wlibtcod.cpp`, `Managers.cpp`, `Sheet.cpp`, `Message.cpp`, `Display.cpp`, `Player.cpp`, `inc/Term.h`
**Status**: Fully researched

---

## Table of Contents

1. [Terminal System](#terminal-system)
2. [Glyph Architecture](#glyph-architecture)
3. [Message System (Message.cpp)](#message-system)
4. [XPrint Format Tags](#xprint-format-tags)
5. [Article and Determiner Handling](#article-and-determiner-handling)
6. [Name Flags](#name-flags)
7. [Message Dispatch Functions](#message-dispatch-functions)
8. [IPrint / IDPrint](#iprint--idprint)
9. [Message Queue System](#message-queue-system)
10. [Creature Name System](#creature-name-system)
11. [Item Name Pipeline](#item-name-pipeline)
12. [Display Rendering (Display.cpp)](#display-rendering)
13. [Thing Placement](#thing-placement)
14. [PlaceNear Algorithm](#placenear-algorithm)
15. [Thing Move](#thing-move)
16. [Map Update Rendering Pipeline](#map-update-rendering-pipeline)
17. [Overlay System](#overlay-system)
18. [GUI Managers](#gui-managers)
19. [Character Sheet](#character-sheet)
20. [Player Input Loop](#player-input-loop)
21. [Rest System](#rest-system)
22. [SpendHours](#spendhours)
23. [DaysPassed Dungeon Regeneration](#dayspassed-dungeon-regeneration)
24. [Game Options](#game-options)
25. [Porting Considerations](#porting-considerations)

---

## Terminal System

### Backend Hierarchy
```
Term (abstract base)
├── TextTerm (80x50 character terminal)
├── cursesTerm (curses/ncurses)
└── libtcodTerm (libtcod library)
```

### Window System (WIN_*, 26 types)
```
WIN_SCREEN(0), WIN_MAP(1), WIN_MSG(2), WIN_STATUS(3),
WIN_MENU(4), WIN_CUSTOM(5), WIN_INPUT(6), ...
up to WIN_LAST(26)
```

Screen divided into regions: map display, message area, status bar, menus, etc.

### TextTerm (Term.cpp, TextTerm.cpp)
Character-based 80x50 terminal:
- Window handling and layout
- Message I/O and scrollback
- Text rendering with color support
- Menu display and input

### cursesTerm (Wcurses.cpp)
Curses/ncurses wrapper:
- Screen management
- Color pair management
- File dialog support

### libtcodTerm (Wlibtcod.cpp)
libtcod library wrapper:
- Graphical tile display
- CP437 font rendering
- File management
- Color support beyond 16 ANSI

---

## Glyph Architecture

A `Glyph` is a 32-bit value packed as:
```
Bits 0-11:  GLYPH_ID (12 bits, 0-4095, maps to character/tile)
Bits 12-16: GLYPH_FORE (foreground colour, 5 bits)
Bits 17-21: GLYPH_BACK (background colour, 5 bits)
```

Key macros:
```cpp
GLYPH_VALUE(id, attr)    // Combine ID + foreground colour
GLYPH_ID_VALUE(glyph)    // Extract character/tile ID
GLYPH_FORE_VALUE(glyph)  // Extract foreground colour
GLYPH_BACK_VALUE(glyph)  // Extract background colour
GLYPH_BACK(value)        // Shift a colour value into background position
GLYPH_FORE(value)        // Shift a colour value into foreground position
```

---

## Message System (Message.cpp)

### Buffer Management

The system uses static buffers for recursive XPrint calls, supporting up to 5 levels of nesting:

```cpp
char XPrintBuff1[130000];  // Level 1 (deepest)
char XPrintBuff2[130000];  // Level 2
char XPrintBuff3[4096];    // Level 3
char XPrintBuff4[4096];    // Level 4
char XPrintBuff5[4096];    // Level 5
static int16 xprint_lev = 0;  // Recursion depth counter
```

First two levels get 130,000 bytes; levels 3-5 get only 4,096. Boundary check: `p >= Out + (xprint_lev < 3 ? 129000 : 4000)`. Beyond 5 levels: `Error("XPrint recursion is too deep!")`.

Global `int16 Silence` flag suppresses all message output when nonzero.

### Core XPrint Function

```cpp
const char* __XPrint(Player *POV, const char *msg, va_list args)
```

`POV` (point of view) is the player who receives the message. If POV cannot perceive (`XPerceives`) an object, it is replaced with "something" / "it" / "its".

Parameters consumed from `va_list` into a union array:
```cpp
union { int32 i; const char *s; Thing *o; } Params[10];
```

Parameters consumed **lazily** -- only pulled from `va_arg` when the tag index exceeds the count of parameters consumed so far. Tags can specify explicit indices (e.g., `<str2>`) or auto-increment.

---

## XPrint Format Tags

All tags enclosed in `<...>`. Tags can have colon separator for dual-part tags: `<Tag1:Tag2>`. Tag names lowercased during parsing. Maximum tag name length: 23 characters.

### Parameter Tags

| Tag Pattern | Type | Description |
|---|---|---|
| `<num>` / `<num2>` | `int` param | Integer via `Format("%d", ...)` |
| `<str>` / `<str2>` | `const char*` param | String insertion. NULL becomes `"[null string]"` |
| `<char:XXX>` | literal glyph | Encodes glyph code as `LITERAL_CHAR` + two bytes. XXX is numeric or from `GLYPH_CONSTNAMES` |
| `<ht>` / `<ht2>` | `hText` param | Text handle -- resolves via VM string table or module text |
| `<rid>` / `<res>` / `<rid2>` | `rID` param | Resource ID -- becomes `NAME(rID)` |
| `<obj>` / `<obj2>` | `Thing*` param | Object name via `Subject->Name(Flags)`. Falls back to "something" if not perceived |
| `<hobj>` / `<hitm>` | `hObj` param | Object handle -- resolved to `Thing*` via `oThing()` |
| `<mon>` / `<itm>` | `Thing*` param | Same as `<obj>` (all treated identically) |

### Event-Bound Tags (no param consumption, bound to `EventInfo* ev`)

| Tag | Resolves To |
|---|---|
| `<ea>` / `<eactor>` | `ev->EActor` |
| `<ev>` / `<et>` / `<etarget>` | `ev->ETarget` |
| `<ei>` / `<eitem>` | `ev->EItem` |
| `<ei2>` / `<eitem2>` | `ev->EItem2` |

### Pronoun and Gender Tags (dual-tag form `<pronoun:subject>`)

| Tag1 | Output |
|---|---|
| `his` | `His()` / `his()` / `"Its"` / `"its"` (not perceived) |
| `him` | `Him()` / `him()` / `"It"` / `"it"` |
| `he` / `she` | `He()` / `he()` / `"It"` / `"it"` |
| `s` | `"s"` if singular, `""` if plural (not perceived: skip entirely) |
| `god` | Random god name based on creature alignment, or `getGod()` for characters |

### Special Block Tags

| Tag | Description |
|---|---|
| `<list tattoos>` | Enumerate all tattoo effects, sorted alphabetically |
| `<list macros>` | Enumerate all macro effects, sorted |
| `<list options>` | Dump all game options by category with descriptions |
| `<weapon table>` | Call `HelpWeaponTable()` |

### Numeric Color Codes

A tag like `<5>` is a **color code**. Stored as a negative byte: `*p++ = -atoi(Tag1)`. When rendering encounters a negative character value, it interprets it as a color change. The `LITERAL_CHAR` (`-20`) glyph encoding uses the same mechanism -- byte `-20` signals a literal glyph follows.

Color constants used as negatives: `-SKYBLUE`, `-RED`, `-GREY`, `-YELLOW`, `-WHITE`, `-GREEN`, `-CYAN`, `-MAGENTA`, `-PINK`, `-AZURE`, `-EMERALD`.

---

## Article and Determiner Handling

Before the `PutName` label, the engine performs **look-behind** on the output buffer to detect articles preceding a `<tag>`:

- `"a "` or `"A "` before tag: sets `NA_A` flag, rewinds output pointer by 2
- `"an "` or `"An "` before tag: sets `NA_A` flag, rewinds output pointer by 3
- `"the "` or `"The "` before tag: sets `NA_THE` flag, rewinds output pointer by 4

Writing `"the <obj>"` in a format string causes the engine to strip "the " and pass `NA_THE` to `Name()`, which then chooses the appropriate article based on whether the name is proper. After a period-space (`. `), `NA_CAPS` is auto-set for capitalization.

Possessives are detected after the closing `>`: if `'s` follows, `NA_POSS` is set.

---

## Name Flags

```cpp
#define NA_LONG    0x0001  // Full details: "uncursed long... injured kobold"
#define NA_MECH    0x0002  // Mechanical info: "long sword +1"
#define NA_CAPS    0x0004  // Capitalize first letter
#define NA_POSS    0x0008  // Possessive: "kobold's"
#define NA_A       0x0010  // Indefinite article: "a kobold"
#define NA_THE     0x0020  // Definite article: "the kobold"
#define NA_INSC    0x0040  // Show inscription: "sword {blinky}"
#define NA_SINGLE  0x0080  // Singular even if plural quantity
#define NA_SHADOW  0x0100  // Shadow perception: "unclearly seen monstrous form"
#define NA_STATI   0x0200  // Status prefixes: "terrified paralyzed male kobold"
#define NA_XCAPS   0x0400  // Title case: "The Long Sword [2d4/4d5]"
#define NA_MONO    0x0800  // No color highlighting for blessed/cursed
#define NA_IDENT   0x1000  // Pretend fully identified
#define NA_NO_TERSE 0x2000 // Spell out "blessed"/"cursed" instead of "b"/"c"
#define NA_FLAVOR  0x4000  // Show flavor text
```

---

## Message Dispatch Functions

| Function | Semantics |
|---|---|
| `XPrint(msg, ...)` | Format with no POV (NULL player). No event context. |
| `PPrint(player, msg, ...)` | Format with specific POV player. No event context. |
| `DPrint(e, msg1, msg2, ...)` | **Dual-perspective**: `msg1` to `e.EActor` (1st person), `msg2` to all other players who perceive EActor (3rd person) |
| `APrint(e, msg, ...)` | **All perceivers**: `msg` to every player who perceives EActor, EItem, or EVictim |
| `VPrint(e, msg1, msg2, ...)` | **Victim-perspective**: `msg1` to `e.EVictim`, `msg2` to others who perceive EVictim |
| `TPrint(e, msg1, msg2, msg3, ...)` | **Three-way**: `msg1` to EActor, `msg2` to EVictim, `msg3` to everyone else who perceives both |
| `Hear(e, range, msg, ...)` | Range-based: msg to players within `range` who do NOT perceive EActor and are NOT deaf |
| `SinglePrintXY(e, msg, ...)` | Location-based with deduplication. Uses static `Recent[12]` array to suppress duplicate messages. Pass NULL msg to reset. |

---

## IPrint / IDPrint

### Player::__IPrint
```cpp
void Player::__IPrint(const char*msg, va_list ap)
```
- Checks `Silence` flag first
- Calls `__XPrint(this, msg, ap)` -- the player IS the POV
- Force-capitalizes first character
- If a message queue is active (`m->QueueNum()`), appends to `MessageQueue[queue]` with trailing space
- Otherwise, sends directly to `MyTerm->Message(fm)`

### Player::IDPrint
```cpp
void Player::IDPrint(msg1, msg2, ...)
```
- `msg1` goes to `this` (1st person)
- `msg2` goes to all other players on the same map who perceive `this` (3rd person)

### Thing::IDPrint
```cpp
void Thing::IDPrint(msg1, msg2, ...)
```
- Non-player version. `msg1` is ignored (Things cannot receive messages).
- `msg2` goes to all players who perceive the Thing.
- Special case: if the Thing is an Item with no map but has an Owner, uses the Owner's map.

---

## Message Queue System

Maps have a stack-based queue system:
```cpp
Map::SetQueue(Queue)    // Push queue number onto QueueStack[++QueueSP]
Map::UnsetQueue(Queue)  // Pop (with validation)
Map::PrintQueue(Queue)  // Dump to all players on map
Map::EmptyQueue(Queue)  // Discard all queued messages
```

When a queue is active (`QueueNum() != 0`), `__IPrint` accumulates messages into `MessageQueue[queue]` rather than displaying immediately. `DumpQueue` sends accumulated text via `MyTerm->Message()`.

```cpp
String MessageQueue[8];  // 8 message buffer slots
```

---

## Creature Name System

The `NA_STATI` flag triggers a comprehensive status prefix system. Applied in this order (each prepended):

1. **Gender**: `"male "` / `"female "` (unless `M_NEUTER`)
2. **HP status** (ratio of current/max HP * 10):
   - 10: `"uninjured"`
   - 8-9: `"mildly injured"`
   - 6-7: `"moderately hurt"`
   - 4-5: `"severely hurt"`
   - 2-3: `"badly wounded"`
   - 1: `"critically wounded"`
   - 0: `"almost dead"`
3. **Condition stati** in order: AFRAID, PARALYSIS, CONFUSED, ELEVATED, STUNNED, HIDING, PRONE, CHARGING, SLEEPING, BLIND, STUCK, PHASED, SUMMONED
4. **Hostility**: `"peaceful"` / `"formerly peaceful"` / `"allied"` / `"neutral"` / `"hostile"`
5. **Awareness** (if player is hiding and has high enough Appraise): `"aware"` / `"unaware"` prefix

---

## Item Name Pipeline

Item names are assembled in parts stored in an `EventInfo` struct used as workspace:

| Field | Content |
|---|---|
| `nArticle` | "the", "a", "an", quantity prefix |
| `nAdjective` | damage state, poisoned, partly eaten, etc. |
| `nCursed` | blessed/cursed/uncursed (colored unless `NA_MONO`) |
| `nPrequal` | pre-qualifier qualities (e.g., "flaming", "masterwork") |
| `nFlavour` | unidentified flavor text |
| `nBase` | base item name from resource |
| `nPlus` | enhancement bonus ("+1", colored yellow if boosted) |
| `nOf` | assembled "of X and Y" from post-qualifier names |
| `nPostqual` | post-qualifier text |
| `nNamed` | named items short-circuit the whole pipeline |
| `nInscrip` | inscription in `{braces}` |
| `nMech` | mechanical details in `[brackets]` |
| `nAppend` | charges, uses, light turns |

**Assembly order**: `nArticle + nAdjective + nCursed + nPrequal + [nFlavour] + nBase + nPlus + nOf + nPostqual + [nNamed] + nInscrip + nMech + nAppend`

**Color rules**: Blessed items use SKYBLUE, cursed use RED. Unknown curse status shows `"?"` in WHITE. Terse mode (`OPT_TERSE_BLESSED`) replaces "blessed"/"cursed" with "b"/"c".

---

## Display Rendering (Display.cpp)

### Thing::PlaceAt

```cpp
void Thing::PlaceAt(Map*_m, int16 _x, int16 _y, bool share_square)
```

Key flow:
1. **Size check**: Huge+ creatures (`GetAttr(A_SIZ) >= SZ_HUGE`) flagged as `isBig`
2. **Mount handling**: Mounts' mobile fields move with the rider
3. **Generic item bug patch**: Potions/scrolls/rings/wands without `eID` are deleted
4. **Same-map optimization**: If already on same map, calls `Move()` instead
5. **Event system**: Fires `EV_PLACE`; aborts if event returns ABORT
6. **Mobile field preservation**: Before removing from old map, saves all mobile fields (`FI_MOBILE`) into `MyFields[12]` and removes them, then re-creates at new position
7. **Contents list insertion**: Creatures always inserted AFTER the first creature in contents list (maintains creature-first ordering)
8. **Player map setup**: For players, calls `RegisterPlayer()`, `SetMap()`, `AdjustMap()`, sets `UpdateMap = true`
9. **Overflow**: If target square is occupied and `share_square` is false, coordinates set to (1,1) and `PlaceNear` finds an actual open square

---

## Thing Placement

### Contents List Ordering

The linked list at each map cell (`At(x,y).Contents`) maintains specific ordering:
- **Creatures first**: When inserting, if the first thing in Contents is a creature, the new thing is inserted after it (via `Next` chain)
- Otherwise, the new thing is inserted at the head

This ensures creatures always take visual priority when iterating.

---

## PlaceNear Algorithm

```cpp
void Thing::PlaceNear(int16 x, int16 y)
```

Expanding-ring search:
1. Search rings from `r=0` to `r=6` (or `r=40` for players)
2. For each ring, collect candidate squares `cx[]/cy[]` (up to 120)
3. Filters: in-bounds, not solid, not fall-trap (unless aerial), no warned terrain, no existing creature
4. **Big creature extra**: For `SZ_HUGE+`, checks the entire `FaceRadius[size]` area for walls and other huge creatures
5. Picks a random candidate from the valid set
6. **Retry mode**: If no position found on first pass, retries allowing displacement of small/medium creatures
7. **Player fallback**: If a player still can't be placed, deletes all obstacles at their position
8. **Non-player fallback**: If a non-player can't be placed, it is deleted (`Remove(true)`)

---

## Thing Move

```cpp
void Thing::Move(int16 newx, int16 newy, bool is_walk)
```

1. **Engulfed check**: Engulfed creatures cannot move
2. **Mount bypass**: Mounted creatures skip to AddToList
3. **Field interaction**: When moving across fields:
   - Mobile fields owned by this creature (or mount) move via `MoveField`
   - `EV_FIELDOFF` fired for fields left behind
   - `EV_FIELDON` fired for fields entered
4. **Contents list update**: Removes from old position's Contents linked list, adds to new position's Contents list (creature-first ordering preserved)
5. **Mount sync**: Mount's x, y, m synced to rider
6. **Map update**: Calls `Map::Update(ox,oy)` and `Map::Update(x,y)` to refresh display
7. **Engulfed carry**: All creatures engulfed by this one move with it

---

## Map Update Rendering Pipeline

Located in `Term.cpp`. Core rendering decision for a single map cell:

1. **Get base glyph**: `g = mg = GlyphAt(x,y)` (terrain glyph from `LocationInfo.Glyph`)
2. **FI_SIZE field check**: If a size field exists and no solid terrain, check if player perceives the field creator
3. **Contents iteration**: Walk Contents linked list at (x,y):
   - Call `p->Perceives(t)` for each thing
   - Unscrutinized monsters get `ScrutinizeMon()` call
   - Count `items` and `creatures`
   - **Priority system**: `Priority(t->Type)` determines which thing's Image is shown
     - Higher priority thing's `Image` replaces the glyph
     - `F_HILIGHT` flag: Sets background to EMERALD (clearing foreground if also EMERALD to avoid invisibility)
     - Otherwise: composites thing's foreground with terrain's background
4. **Shadow perception**: `PER_SHADOW` replaces glyph with `GLYPH_UNKNOWN` in SHADOW colour
5. **Same-colour fix**: If foreground == background, flips the foreground to make it visible
6. **Visibility check**: If cell not `VI_VISIBLE` and no perceivable thing:
   - Shows `At(x,y).Memory` (remembered glyph from previous sight)
   - Falls back to `GLYPH_UNSEEN` if no memory
7. **Multi-display**:
   - `creatures > 1` and priority == 3: Shows `GLYPH_MULTI` (multi-creature indicator) in WHITE
   - `items > 1` and priority < 3: Shows `GLYPH_PILE` in GREY, unless there's a Container (shows container glyph)
8. **Overlay**: After all content rendering, overlays composited: any active overlay glyph at (x,y) replaces display, preserving terrain background

### Engulfed Rendering (TextTerm::ShowMap)

When player is engulfed:
- Map is cleared
- Player glyph drawn at center
- Engulfer drawn as ASCII border: `-`, `|`, `/`, `\` in the engulfer's colour

### Map::ResetImages

Called when a player enters a map. Iterates all creatures and calls `SetImage()` on each, then `Update()` for the cell.

---

## Overlay System

```cpp
class Overlay {
    int16 GlyphX[MAX_OVERLAY_GLYPHS], GlyphY[MAX_OVERLAY_GLYPHS];
    Glyph GlyphImage[MAX_OVERLAY_GLYPHS];
    int16 GlyphCount;
    bool Active;
};
```

- One overlay per Map (`Map::ov`)
- `Activate()`: Resets all glyph positions to -1, sets Active
- `DeActivate()`: Clears count, updates all previous glyph positions on map
- `AddGlyph(x, y, g)`: Adds glyph at position (capped at `MAX_OVERLAY_GLYPHS`)
- `RemoveGlyph(x, y)`: Sets position to -1 (does not compact array)
- `ShowGlyphs()`: Calls `Map::Update` for each active glyph, then `T1->Update()`

Used for spell effects, projectile animations, and temporary visual effects.

---

## GUI Managers (Managers.cpp)

### Manager Types
- **Spell Manager** - Spell selection and casting UI
- **Inventory Manager** - Item browsing and management
- **Skill Manager** - Skill usage interface
- **Barter Manager** - Trading with NPCs
- **Option Manager** - Game settings

---

## Character Sheet (Sheet.cpp)

### Display
- Full character statistics
- Equipment and inventory summary
- Skill breakdown with modifiers
- Spell list
- Character dump to file

### Breakdown Methods
```cpp
String& SkillBreakdown(sk, maxlen)    // Detailed skill bonus sources
String& SpellBreakdown(sp, maxlen)    // Spell bonus breakdown
String& ResistBreakdown(dt, maxlen)   // Resistance source breakdown
```

---

## Player Input Loop

### Player Initialization

```cpp
Player::Player(Term *t, int16 _Type) : Character(FIND("human;temp"), _Type)
```
- Initializes 5 `RecentVerbs` to -1
- Sets `FFCount = 20` (flat-footed counter)
- Default macros: `Macros[2]="Autorest"`, `[4]="Autobuff"`, `[7]="AutoLoot"`, `[8]="AutoDrop"`
- State flags: `MS_KNOWN | MS_POLY_KNOWN | MS_SEEN_CLOSE | MS_SCRUTINIZED`

### ChooseAction -- Main Input Loop

```cpp
do {
    ch = MyTerm->GetCharCmd();
    switch (ch) { ... }
} while (!Timeout);
```

**Pre-action checks**:
- Low HP warning: If `cHP * 10 <= (mHP + THP) * OPT_LOWHP_WARN`, shows warning box
- Empty hand warning: If no weapon and `OPT_WARN_EMPTY_HAND` set
- Compulsion: `CH_COMPEL` stati forces compelled action
- Paralysis: Special paralyzed menu (pray, magic, or wait 10/20/30 turns)
- In-air: Forces inventory mode
- AutoHide: If `OPT_AUTOHIDE` and conditions met, automatically attempts to hide

**Arrow key movement** (bottom of switch):
- If engulfed, attacks the engulfer
- If shift held: either fires ranged (`OPT_SHIFTARROW=0`) or runs (`OPT_SHIFTARROW=1`)
- Charging logic: Checks charge direction compatibility, auto-charge mode
- Creature collision: If hostile creature ahead and perceived, triggers attack
  - Friendly creatures get confirmation prompt
  - Attack mode selection: S_BRAWL, S_DUAL, S_MELEE, S_THROWN, S_ARCHERY

**Auto-save**: Every 200 actions (`ActionsSinceLastAutoSave >= 200`)

---

## Rest System

### Rest Command
- `KY_CMD_REST`: Adds 15 to Timeout (short rest / wait)
- `KY_CMD_SLEEP`: Calls `ThrowVal(EV_REST, REST_DUNGEON [| REST_SAFE | REST_INSTANT], this)`

### REST Flags
```cpp
#define REST_SAFE     0x0001  // No encounters
#define REST_FULL     0x0002  // Full heal
#define REST_NOMANA   0x0004  // Don't restore mana
#define REST_PLOT     0x0008  // Skip abort checks
#define REST_INSTANT  0x0010  // No time passage
#define REST_NOMSG    0x0020  // Suppress "well rested" message
#define REST_NOHEAL   0x0040  // Don't heal HP
#define REST_RESTLESS 0x0080  // Don't restore fatigue for allies
#define REST_DUNGEON  0x0100  // In-dungeon rest (requires confirm, encounter check)
#define REST_NOIDENT  0x0200  // Skip item intuition
#define REST_FOOD     0x0400  // Set hunger to SATIATED for all
```

### Rest Flow (Player::Rest)

**1. Pre-checks** (unless REST_PLOT):
- Dwarven Focus active: Can't rest
- Solid terrain: "Nice try. No."
- Poisoned/Stoning: Can't rest
- Starving: Can't rest

**2. Encounter calculation** (`RestEncounterChance`):
- Flood-fills map from player position
- For each hostile creature within `maxDist + 15 + depth*2`:
  - Must be flood-connected (reachable)
  - Skip immobile creatures (MOV <= -15)
  - Skip creatures in vaults
  - In-sight hostiles prevent rest entirely
- Encounter chance = sum of `(250 + CR*10 + INT_mod*20) / distance` for each hostile
- Monsters grouped by PartyID; the strongest party is selected for encounter

**3. Watch system**:
- Allies within 6 squares ordered to take watches reduce encounter chance by `sumSpot`
- Mindless undead, temporary summons excluded
- If `sumSpot > depth * 3`, player gets forewarning on encounter

**4. Time passage** (unless REST_INSTANT):
- Advances `HOUR_TURNS * 8 * Percent / 100` turns
- Increments day counter
- Calls `DaysPassed()` for dungeon repopulation

**5. Recovery for ALL creatures on ALL dungeon levels**:
- Hunger: Reduced to 65% (normal), 75% (Reverie), 85% (Slow Metabolism), 100% (allies/REST_FOOD=SATIATED)
- HP: `(CR + 3) * CON * Percent / 800` healing, plus Heal skill bonus
- Ability damage: 1-2 points restored per stat per rest
- Mana: Proportional to rest completion percent
- Fatigue: Full restore if Percent=100, partial otherwise. Cursed armour caps at -1.
- Per-day items: Charges reset (3/day, 7/day, 1/day items)
- Monster PreBuff: Monsters re-apply their buff spells
- Corpse decay: Fully decayed corpses removed
- Traps: Reset disarmed state with probability based on depth

**6. Encounter resolution** (if Roll < Chance):
- "An encounter!" message
- Player dismounts, drops non-cursed armour on ground
- Hostile party placed near player
- Uncanny Dodge 3+ or Light Sleeper feat: Forewarning (not sleeping)
- Otherwise: Put to sleep for 20 turns, 60-turn timeout

**7. Successful rest**:
- CalcValues(), LastRest updated
- "You awaken feeling well rested and recovered."
- Armour put back on, remount messages

---

## SpendHours

Used for crafting/scribing/etc:
```cpp
EvReturn Player::SpendHours(int16 minHours, int16 maxHours, int16 &hoursSpent, bool isHeal)
```

- Cannot work while poisoned, stoning, starving, being strangled
- Cannot work if hostiles in sight
- Awake time limit: `(12 + CON_mod) * HOUR_TURNS`
- If remaining awake time < minHours, must rest first
- Hours spent = min(maxHours, remaining awake time in hours)

---

## DaysPassed Dungeon Regeneration

When the player enters a map whose `Day` counter is behind `theGame->Day`:

1. Strip all timed stati (Duration > 0 or == -2) from every Thing
2. Clear searched flags from doors
3. Restore disarmed traps with `random(10) < Depth` probability
4. Remove dungeon fields and temporary terrain changes
5. Repopulate monsters to `MONSTER_EQUILIBRIUM` (base + depth * increment)
   - Place new encounters at random open non-vault squares 25+ distance from players
   - New monsters' magic items above depth/2 are stripped (anti-scumming)
6. Generate 2-5 staple items at random positions
7. Difficulty-based monster cap: Remove monsters above `Depth + 1` (or `+3` with OOD option)

---

## Game Options (OPT_*, ~100 types)

Options stored as `int8 Options[OPT_LAST]` (OPT_LAST = 900).

### Categories
| Range | Category | Description |
|---|---|---|
| 100-199 | `OPC_CHARGEN` | Character generation |
| 200-299 | `OPC_INPUT` | Input preferences |
| 300-399 | `OPC_LIMITS` | Limits and warnings |
| 400-499 | `OPC_DISPLAY` | Output/rendering |
| 500-599 | `OPC_TACTICAL` | Tactics and combat |
| 600-699 | (unused) | Free mode options |
| 800-899 | `OPC_WIZARD` | Wizard mode cheats |

### File I/O
Options saved as raw byte array to `Options.Dat`. `LoadOptions()` reads the file; `UpdateOptions()` selectively merges categories. On new game, wizard/tactical options reset to defaults.

### Key Options
- `OPT_TERSE_BLESSED` (401): "b"/"c" instead of "blessed"/"cursed"
- `OPT_SORT_PILE`: 0=name, 1=type, 2=quality
- `OPT_SHIFTARROW` (203): 0=shift-arrow fires, 1=shift-arrow runs
- `OPT_LOWHP_WARN` (307): Low HP warning threshold (gradient of 10%)
- `OPT_LOWHP_AGG` (308): Aggressive low HP warning (requires ENTER)
- `OPT_AUTOMORE` (201): Auto-more for messages
- `OPT_CLEAR_EVERY_TURN` (225): Clear messages each turn
- `OPT_SAFEREST` (805): Wizard mode safe rest

---

## Rendering Pipeline

### Existing Spec
See `docs/research/specs/rendering-pipeline.md` for the rendering priority system.

### Priority Order
1. Overlay glyphs (spell effects, targeting)
2. Creatures (highest)
3. Items
4. Fields
5. Terrain (lowest)

### Color System
16 ANSI colors (0-15), mapped to RGB for graphical backends.
Already implemented in `src/dungeon/render.jai`.

---

## Porting Considerations

1. **Terminal abstraction** - Port needs its own display backend (SDL2, terminal, etc.)
2. **Message grammar engine** - Complex XPrint system with look-behind article detection, recursive buffering, and POV-dependent naming. Core infrastructure for all game messages.
3. **Glyph packing** - 32-bit glyph with 12-bit ID + 5-bit fore + 5-bit back. Already partially implemented.
4. **Name pipeline** - Both Creature::Name (status prefix system) and Item::Name (14-field assembly) are complex and perception-dependent.
5. **Rendering pipeline** - Contents list ordering (creature-first), priority system, shadow perception fallback, multi-creature/pile indicators, overlay compositing.
6. **PlaceAt/PlaceNear** - Placement with field preservation, expanding-ring search, big creature handling, retry with displacement.
7. **Message dispatch** - Six dispatch modes (DPrint, APrint, VPrint, TPrint, Hear, SinglePrintXY) plus message queue system.
8. **Rest system** - Complex encounter calculation with flood-fill pathfinding, watch system, global creature recovery, dungeon regeneration.
9. **Window system** - Layout manager for dividing screen
10. **Managers** - UI state machines; port after core systems
11. **Options** - ~100 options stored as byte array; start with subset
12. **Character sheet** - Template-based display; port after character system
