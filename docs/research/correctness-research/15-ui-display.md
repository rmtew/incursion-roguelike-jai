# UI & Display System

**Source**: `Term.cpp`, `TextTerm.cpp`, `Wcurses.cpp`, `Wlibtcod.cpp`, `Managers.cpp`, `Sheet.cpp`, `Message.cpp`, `inc/Term.h`
**Status**: Architecture identified from headers

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

## GUI Managers (Managers.cpp)

### Manager Types
- **Spell Manager** - Spell selection and casting UI
- **Inventory Manager** - Item browsing and management
- **Skill Manager** - Skill usage interface
- **Barter Manager** - Trading with NPCs
- **Option Manager** - Game settings

## Message System (Message.cpp)

### Grammar Engine
Complex message formatting handles:
- Pronoun selection (you/he/she/it/they)
- Plural forms
- Article selection (the/a/an)
- First vs third person ("You hit" vs "The orc hits")
- Perception-dependent messages ("Something hits you" when actor unseen)

### Message Methods
```cpp
void IPrint(const char*, ...)           // Print to player
void __IPrint(const char*, va_list)     // Varargs version
void IDPrint(const char*, const char*, ...) // Dual message (actor/observer)
```

### Message Queue
```cpp
String MessageQueue[8];  // Recent message buffer
```

### Conditional Display
Messages change based on:
- Whether actor is perceived by viewer
- Whether victim is perceived by viewer
- Whether actor is the player
- Whether action is in line of sight

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

## Game Options (OPT_*, ~100 types)

Organized by category:
```
OPC_CHARGEN(100)   - Character generation options
OPC_INPUT(200)     - Input handling
OPC_LIMITS(300)    - Game limits
OPC_DISPLAY(400)   - Display settings
OPC_TACTICAL(500)  - Tactical/combat options
OPC_STAB(600)      - Stability options
OPC_WIZARD(700)    - Debug/wizard options
```

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

## Porting Considerations

1. **Terminal abstraction** - Port needs its own display backend (SDL2, terminal, etc.)
2. **Message grammar** - Complex system; may want simplified version initially
3. **Window system** - Layout manager for dividing screen
4. **Managers** - UI state machines; port after core systems
5. **Options** - ~100 options; start with subset
6. **Character sheet** - Template-based display; port after character system
