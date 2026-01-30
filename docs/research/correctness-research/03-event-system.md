# Event System

**Source**: `Event.cpp`, `inc/Events.h`, `inc/Defines.h`, `Annot.cpp`, `Fight.cpp`, `Creature.cpp`, `Item.cpp`, `Player.cpp`, `Display.cpp`, `MakeLev.cpp`
**Status**: Fully researched

## Overview

The event system is the central dispatch mechanism for ALL game actions. Every action (attack, move, cast, pick up, etc.) is represented as an `EventInfo` struct and dispatched through the event system. Resource scripts handle events to implement custom behavior.

## EventInfo Structure

The EventInfo struct is massive (~200 fields) and serves as the universal parameter block for all game operations.

### Core Fields
```cpp
uint16 Event;            // Event type (EV_* constant)
EvParam p[5];            // 5 parameter slots (union of pointers)
Field *EField;           // Associated field
Map *EMap;               // Associated map
```

### Parameter Accessors (Macros)
```cpp
#define EActor    p[0].c    // Acting creature
#define EPActor   p[0].pl   // Acting player
#define ETarget   p[1].t    // Target thing
#define EVictim   p[1].c    // Victim creature
#define EItem     p[2].i    // Primary item
#define EWeapon   p[2].wp   // Weapon used
#define EItem2    p[3].i    // Secondary item
#define EFeat     p[1].f    // Feature
```

### EvParam Union
```cpp
union EvParam {
    Thing *t; Item *i; Creature *c; Player *pl;
    Attack *at; Feature *f; Map *m; Object *o; Weapon *wp;
};
```

### Combat Fields
```cpp
int8 vRoll, vtRoll;      // d20 roll, total roll
int8 AType, DType;       // Attack type, damage type
int8 vHit, vDef;         // Hit modifier, defense modifier
int8 vThreat, vCrit;     // Threat range, crit multiplier
int8 vArm, vPen;         // Armor, penetration
int8 saveDC;             // Save DC
int8 vCasterLev;         // Caster level
int16 vDmg, bDmg, aDmg, xDmg; // Damage values
int16 vMult, vDuration;  // Multiplier, duration
Dice Dmg;                // Damage dice
```

### Boolean Flags (~60 flags)
Combat state: `isHit`, `isCrit`, `isFumble`, `Died`, `ADied`, `Blocked`, `Saved`, `Immune`, `MagicRes`, `Resist`, `Absorb`

Perception: `actUnseen`, `vicUnseen`, `actIncor`, `vicIncor`

Combat modifiers: `Ranged`, `isAoO`, `isCleave`, `isSurprise`, `isGreatBlow`, `isSneakAttack`, `isFlanking`, `isFlatFoot`, `isOffhand`, `isGhostTouch`

Magic: `isSpell`, `isBlessed`, `isCursed`, `effDisbelieved`, `actIllusion`, `vicIllusion`, `effIllusion`

Output control: `Silence` (suppress ALL output), `Terse` (suppress non-essential)

### Positional/Directional Fields
```cpp
int16 x, y, z;          // Position and direction
int16 sp;                // Spell number
int16 EvFlags;           // Event-specific flags
int32 EParam, EParam2;   // Generic integer parameters
```

### Additional Combat Fields
```cpp
int8 vRange;             // Range
int8 vRadius;            // Area radius
int8 vOpp1, vOpp2;       // Opposed check values
int8 vRideCheck;         // Ride check result
int8 vChainCount, vChainMax; // Chain attack tracking
int8 vPenetrateBonus;    // Spell resistance penetration
Item *remainingAmmo;     // Ammunition tracking
uint32 MM;               // Metamagic flags
```

### String Fields (24 strings)
**Message strings:** `GraveText`, `strDmg`, `strXDmg`, `strHit`, `strDef`, `strOpp1`, `strOpp2`, `strBlastDmg`

**Naming system (for EV_PRINT_NAME):** `nPrefix`, `nCursed`, `nPrequal`, `nPostqual`, `nNamed`, `nBase`, `nAppend`, `nOf`, `nAdjective`, `nFlavour`, `nInscrip`, `nMech`, `nArticle`, `nPlus`, `Text`, `enDump`

### Encounter Generation Fields (~40 fields)
**Encounter-level:** `enTerrain`, `enCR`, `enDepth`, `enXCR`, `enID`, `enRegID`, `enAlign`, `enPurpose`, `enFlags`, `enFreaky`, `enSleep`, `enType`, `enPartyID`, `enDriftGE`, `enDriftLC`, `enConstraint`

**Per-part:** `epMinAmt`, `epMaxAmt`, `epAmt`, `epFreaky`, `epWeight`, `epMType`, `ep_monCR`, `ep_mountCR`, `ep_mID`, `ep_tID`, `ep_tID2`, `ep_tID3`, `ep_hmID`, `ep_htID`, `ep_htID2`, `ep_pID`, `ep_iID`, `epXCR`, `eimXCR`

### Dungeon Generation Fields
```cpp
Rect cPanel, cMap, cRoom; // Current panel/map/room during generation
int16 vDepth, vLevel;     // Generation depth/level
int16 terraKey, terrainListIndex; // Terrain mutation keys
```

### Resource Selection Fields
```cpp
uint32 chType;            // Resource type to choose
uint16 chList;            // Resource list
bool chMaximize;          // Maximize selection
bool chBestOfTwo;         // Best-of-two selection
rID chResult;             // Chosen resource ID
rID chSource;             // Source constraint
bool (*chCriteria)(EventInfo&, rID); // Custom filter callback
```

### Illusion Fields
```cpp
uint16 illFlags;          // Illusion flags
char illType;             // Illusion type
rID ill_eID;              // Illusion effect resource ID
```

## Event Types (EV_* Constants)

190+ event types organized by category:

### Movement & Navigation (1-10)
EV_MOVE(1), EV_BREAK(2), EV_PUSH(3), EV_PULL(4), EV_MIX(5), EV_POUR(6), EV_ZAP(7)

### Attack Sequence (11-28)
EV_ATTK(11), EV_NATTACK(17), EV_WATTACK(18), EV_STRIKE(19), EV_HIT(20), EV_MISS(21), EV_CRIT(22), EV_FUMBLE(23), EV_BLOCK(24), EV_PARRY(25), EV_DODGE(26), EV_ATTACKMSG(27), EV_MAGIC_HIT(28)

### Object Interaction (29-52)
EV_OPEN(29), EV_CLOSE(30), EV_DRINK(35), EV_INVOKE(36), EV_CAST(37), EV_READ(38), EV_DAMAGE(41), EV_DEATH(42), EV_FIELDON(43), EV_FIELDOFF(44), EV_REST(45), EV_WALKON(47), EV_EFFECT(52)

### Social (55-67)
EV_TALK(55), EV_BARTER(56), EV_COW(57), EV_GREET(62), EV_ORDER(63), EV_TAUNT(67)

### Combat Special (71-83)
EV_OATTACK(71), EV_HIDE(73), EV_TURNING(80), EV_JUMP(81), EV_MAGIC_STRIKE(83)

### Religion (134-149)
EV_PRAY(134), EV_SACRIFICE(135), EV_BLESSING(147), EV_GOD_RAISE(148)

### Character Creation (150-177)
EV_BIRTH(150), EV_PREREQ(151), EV_ADVANCE(153), EV_ISTARGET(155)

### Dungeon Generation (180-192)
EV_GEN_DUNGEON(180), EV_GEN_LEVEL(181), EV_GEN_PANEL(182), EV_GEN_ROOM(183), EV_ENGEN(184)

## Event Dispatch Macros

### PEVENT - Post Event
```cpp
#define PEVENT(ev, actor, xID, set_val, r) {
    EventInfo e; e.Clear();
    e.Event = ev; e.EActor = actor; e.EVictim = actor;
    e.EMap = e.EActor ? e.EActor->m : NULL;
    set_val;  // Custom setup
    r = TEFF(xID)->Event(e, xID, 0);
}
```

### DAMAGE - Damage Event
```cpp
#define DAMAGE(act, vic, dtype, amt, str, set_val) {
    EventInfo xe; xe.Clear();
    xe.Event = EV_DAMAGE; xe.EActor = act; xe.EVictim = vic;
    xe.DType = dtype; xe.vDmg = amt; xe.GraveText = str;
    set_val;
    ReThrow(EV_DAMAGE, xe);
}
```

### THROW / XTHROW / RXTHROW
```cpp
THROW(ev, set_val)            // Create and dispatch new event
XTHROW(ev, e, set_val)        // Copy event, modify, and rethrow
RXTHROW(ev, e, r, set_val)    // Like XTHROW but capture return
```

## Event Dispatch Flow

1. EventInfo populated with parameters
2. `ReThrow(ev, e)` called
3. ReThrow searches resource database for handlers
4. Calls `TEFF(xID)->Event(e, xID, 0)` for each matching handler
5. Return value (EvReturn) determines continuation:
   - ERROR(-1): Failed
   - NOTHING(0): Continue
   - DONE(1): Complete
   - ABORT(2): Cancel operation
   - NOMSG(3): Success but suppress messages

---

## Implementation-Level Event Dispatch Mechanics

Source: `Event.cpp`, `Annot.cpp`, `Creature.cpp`, `Item.cpp`, `Player.cpp`, `Display.cpp`, `MakeLev.cpp`, `Fight.cpp`

### Event Stack Architecture

The event system uses a fixed-size stack for recursive event dispatch:

```cpp
EventInfo EventStack[EVENT_STACK_SIZE];  // EVENT_STACK_SIZE = 128
int16     EventSP = -1;                 // Stack pointer, -1 = empty
```

Every event dispatch function (`Throw`, `ReThrow`, `ThrowDir`, etc.) pushes onto this stack. The stack prevents re-entrancy issues -- events can trigger other events recursively (e.g., an attack triggering damage, damage triggering death, death triggering effects). The original code had a stack size of 32, which was found to overflow during normal gameplay; it was raised to 128.

```cpp
#define CHECK_OVERFLOW  if (EventSP > EVENT_STACK_SIZE-1) Fatal("Event Stack Overflow!");
```

### Event Code Arithmetic: The Modifier System

Event codes are small integers (1-192 for base events). The system uses arithmetic offsets to create modified event variants:

```cpp
#define PRE(a)       (a + 500)      // Pre-event: fires before main handler
#define POST(a)      (a + 1000)     // Post-event: fires after main handler
#define EVICTIM(a)   (a + 2000)     // Victim variant of event
#define ETARGET(a)   (a + 2000)     // Synonym for EVICTIM
#define EITEM(a)     (a + 4000)     // Item context variant
#define META(a)      (a + 10000)    // Meta-event for TRAP_EVENT stati
#define GODWATCH(a)  (a + 20000)    // God evaluation variant
```

These offsets create a flat numeric namespace:
- Base event `EV_STRIKE = 19` becomes `PRE(EV_STRIKE) = 519`, `POST(EV_STRIKE) = 1019`
- `EVICTIM(EV_STRIKE) = 2019` means "this creature is the victim of a strike"
- `GODWATCH(EV_STRIKE) = 20019` means "gods evaluate the actor's strike conduct"
- `GODWATCH(EVICTIM(EV_STRIKE)) = 22019` means "gods evaluate the victim's involvement in a strike"
- `META(EV_STRIKE) = 10019` and `META(EVICTIM(EV_STRIKE)) = 12019` are used for TRAP_EVENT stati interception

### Return Values and Propagation Control

```cpp
#define ERROR    -1   // Fatal error in handler
#define NOTHING   0   // Handler did not handle; continue dispatch
#define DONE      1   // Event fully handled; stop dispatching
#define ABORT     2   // Event cancelled; stop and unwind
#define NOMSG     3   // Handled but suppress messages (sets e.Terse = true, continues dispatch)
```

Critical propagation rules:
- **DONE** or **ABORT**: Immediately stop dispatching to remaining handlers and return.
- **ERROR**: Log error, convert to ABORT, and return.
- **NOMSG**: Sets `e.Terse = true` on the EventInfo, then **continues** dispatching to remaining handlers. This allows handlers to suppress messages without preventing other handlers from processing the event.
- **NOTHING**: Event was not handled by this handler; continue to next handler in chain.

Special case: If RealThrow completes all three phases (PRE, main, POST) and the main phase returned NOTHING, it is a **fatal error** for base events (< 500). PRE/POST events returning NOTHING is allowed:
```cpp
if (r == NOTHING) {
    if (e.Event >= 500)
        return r;  // PRE/POST not needing handling is OK
    Fatal("Error: Unhandled Event:%s (%d)!", ...);
}
```

### The Three-Phase Dispatch: RealThrow

`RealThrow` is the core dispatch orchestrator. Every event goes through three phases:

```cpp
EvReturn RealThrow(EventInfo &e) {
    // 1. Check if this event is triggered by a divine action
    if (EventSP > 0) {
        int16 ev = EventStack[EventSP-1].Event % 500;
        if (ev == EV_RETRIBUTION || ev == EV_GIVE_AID ||
            ev == EV_GODPULSE || ev == EV_ANGER_PULSE ||
            ev == EV_SACRIFICE)
            e.isActOfGod = true;
    }

    // 2. Auto-set EMagic for magic events (kludge for scripts that cannot set it)
    if (e.Event == EV_MAGIC_HIT || e.Event == EV_MAGIC_STRIKE)
        if (e.eID && !e.EMagic)
            e.EMagic = &TEFF(e.eID)->ef;

    // 3. Three-phase dispatch
    Ev = e.Event;
    e.Event = PRE(Ev);       // Phase 1: PRE_*
    r = ThrowEvent(e);

    if (r != ABORT && r != DONE) {
        e.Event = Ev;         // Phase 2: Main event
        r = ThrowEvent(e);
    }

    if (r != ABORT) {
        e.Event = POST(Ev);  // Phase 3: POST_*
        ThrowEvent(e);        // POST return value is ignored for propagation
    }

    // Fatal if base event was unhandled
    if (r == NOTHING && e.Event < 500)
        Fatal("Error: Unhandled Event:%s (%d)!", ...);

    return r;
}
```

Key behaviors:
- PRE phase can ABORT or DONE to prevent main event from firing.
- Main event result controls whether POST fires: ABORT prevents POST, but DONE allows POST.
- POST phase always fires unless PRE or main ABORTed. POST return value does not affect the final return.
- The `isActOfGod` flag is set when the parent event on the stack is a divine event (EV_RETRIBUTION, EV_GIVE_AID, etc.).

### ThrowEvent: The Handler Priority Chain

`ThrowEvent` is the handler routing function. It determines which handlers see the event in what order. The priority chain is:

```
1. Region at subject's location
2. Terrain at subject's location (if TF_SPECIAL flag set)
3. Illusionary terrain at subject's location (if FI_ITERRAIN field exists)
4. Map/dungeon resource
5. Field or effect resource (e.EField->eID or e.eID)
6. All gods evaluate actor's conduct (if actor is Character)
7. All gods evaluate victim's conduct (if victim is Character)
8. Map object (ThrowTo)
9. TRAP_EVENT stati on each parameter object (p[3] down to p[0])
10. Each parameter object via ThrowTo (p[3] down to p[0])
```

#### Detailed ThrowEvent Flow

```cpp
EvReturn ThrowEvent(EventInfo &e) {
    // Determine subject: victim for DAMAGE/DEATH, actor otherwise
    sub = (e.Event == EV_DAMAGE || e.Event == EV_DEATH) ? e.EVictim : e.EActor;

    // Resolve EMap from available objects
    if (e.EActor && e.EActor->m)       e.EMap = e.EActor->m;
    else if (e.EVictim && e.EVictim->m) e.EMap = e.EVictim->m;
    else if (e.EActor && e.EActor->isItem() && ((Item*)e.EActor)->Owner())
        e.EMap = ((Item*)e.EActor)->Owner()->m;
    else if (e.EItem && e.EItem->isItem() && e.EItem->Owner())
        e.EMap = e.EItem->Owner()->m;

    // --- Priority 1: Region ---
    if (sub && e.EMap && sub->x != -1) {
        xID = e.EMap->RegionAt(sub->x, sub->y);
        res = TREG(xID)->Event(e, xID);
        // DONE/ABORT -> return; NOMSG -> e.Terse = true; ERROR -> log + ABORT
    }

    // --- Priority 2: Terrain (if TF_SPECIAL) ---
    // Uses e.isLoc ? (EXVal,EYVal) : (sub->x,sub->y) for position
    if (TTER(terrain)->HasFlag(TF_SPECIAL)) {
        res = TTER(xID)->Event(e, xID);
        // same return handling
    }

    // --- Priority 3: Illusionary terrain ---
    if (e.EMap->FieldAt(tx,ty,FI_ITERRAIN) && e.EActor) {
        xID = e.EMap->PTerrainAt(tx, ty, e.EActor->isCreature() ? e.EActor : NULL);
        res = TTER(xID)->Event(e, xID);
    }

    // --- Priority 4: Dungeon resource ---
    if (e.EMap && e.EMap->dID) {
        res = RES(e.EMap->dID)->Event(e, e.EMap->dID);
    }

    // --- Priority 5: Field/effect resource ---
    if (e.EField && e.EField->eID)
        res = RES(e.EField->eID)->Event(e, e.EField->eID);
    else if (e.eID && e.Event && e.Event != EV_EFFECT)
        res = RES(e.eID)->Event(e, e.eID);

    // --- Priority 6: God evaluation of actor conduct ---
    if (e.EActor && e.EActor->isCharacter()) {
        for (i = 0; i != nGods; i++) {
            oEv = e.Event;
            e.Event = GODWATCH(e.Event);  // ev + 20000
            res = GodList[i]->Event(e, GodIDList[i]);
            e.Event = oEv;  // restore
        }
    }

    // --- Priority 7: God evaluation of victim conduct ---
    if (e.EVictim && e.EVictim->isCharacter()) {
        for (i = 0; i != nGods; i++) {
            oEv = e.Event;
            e.Event = GODWATCH(EVICTIM(e.Event));  // ev + 22000
            res = GodList[i]->Event(e, GodIDList[i]);
            e.Event = oEv;
        }
    }

    // --- Priority 8: Map object ---
    ThrowTo(e, e.EMap);

    // --- Priority 9-10: Parameter objects (p[3] down to p[0]) ---
    for (i = 3; i != -1; i--) {
        if (e.p[i].o) {
            // 9a: Check TRAP_EVENT stati
            StatiIterNature(t, TRAP_EVENT) {
                oEv = e.Event;
                e.Event = (i == 1) ? META(EVICTIM(e.Event)) : META(e.Event);
                if (META(S->Mag) == e.Event)
                    res = RES(S->eID)->Event(e, S->eID);
                e.Event = oEv;
            }

            // 9b: ThrowTo the parameter object
            ThrowTo(e, e.p[i].o);
        }
    }
    return NOTHING;
}
```

#### Subject Resolution

The "subject" determines position for region/terrain lookups:
- For `EV_DAMAGE` and `EV_DEATH`: subject = `EVictim`
- For all other events: subject = `EActor`

If `e.isLoc` is true, the position is taken from `(e.EXVal, e.EYVal)` instead of the subject's coordinates.

### ThrowTo: The Type Hierarchy Dispatch

`ThrowTo` dispatches an event to a specific object, walking the C++ type hierarchy using a macro-generated switch:

```cpp
EvReturn ThrowTo(EventInfo &e, Object *t) {
    i = t->Type;
Again:
    if (!i) return r;
    switch(i) {
        // HIER macro: call Event, if DONE/ABORT/ERROR return; if NOMSG set Terse; then goto base type
        HIER(Map,         T_MAP,       0)
        HIER(Thing,       T_THING,     0)
        HIER(Creature,    T_CREATURE,  T_THING)
        HIER(Character,   T_CHARACTER, T_CREATURE)
        HIER(Player,      T_PLAYER,    T_CHARACTER)
        HIER(Monster,     T_MONSTER,   T_CREATURE)
        // ... item types all route to T_ITEM -> T_THING
        HIER(Item,        T_ITEM,      T_THING)
        HIER(Weapon,      T_WEAPON,    T_ITEM)
        HIER(Armour,      T_ARMOUR,    T_ITEM)
        HIER(Feature,     T_FEATURE,   T_THING)
        HIER(Door,        T_DOOR,      T_FEATURE)
        // etc.
    }
}
```

The HIER macro pattern:
```cpp
#define HIER(Type, T_TYPE, T_BASE)          \
    case T_TYPE:                            \
        r = ((Type*)t)->Event(e);           \
        if (r==DONE || r==ABORT || r==ERROR)\
            return r;                       \
        if (r==NOMSG) e.Terse = true;       \
        i = T_BASE;                         \
        goto Again;
```

This means for a Player object, the dispatch chain is:
`Player::Event -> Character::Event -> Creature::Event -> Thing::Event`

Each level can handle the event and stop propagation, or return NOTHING to let the next level try. Many item types (T_POTION, T_WAND, T_SCROLL, T_RING, etc.) all fall through to `Item::Event` before reaching `Thing::Event`.

### Resource Script Event Interception

Resource scripts (compiled from `.irh` files) intercept events through the annotation system.

#### Annotation Storage

Each resource has a linked list of annotations. Event annotations have type `AN_EVENT`:
```cpp
struct Annotation {
    int32 Next;       // linked list pointer
    uint8 AnType;     // AN_EVENT for event handlers
    union {
        struct {
            uint32 MsgOrCode;  // VM bytecode offset (if Event > 0) or text offset (if Event < 0)
            int16  Event;      // Positive = code handler, Negative = message handler
        } ev[5];               // Up to 5 event handlers per annotation node
    } u;
};
```

An event handler can be either:
- **Code handler** (`Event > 0`): `MsgOrCode` points to VM bytecode. The scripting VM executes it.
- **Message handler** (`Event < 0`, i.e., negated event code): `MsgOrCode` points to a text string in the module's text segment. The message is printed according to message count rules.

#### EventMask Optimization

Each resource has a 16-bit `EventMask` bitmask for fast rejection:
```cpp
uint16 EventMask;
// Check: if (!(EventMask & BIT((e.Event % 16) + 1))) return NOTHING;
```

This is a hashing optimization. The event code modulo 16 maps to a bit. If the bit is not set, the resource has no handlers for any event in that hash bucket. This allows skipping the annotation scan for the majority of resources.

#### Resource::Event Implementation

```cpp
EvReturn Resource::Event(EventInfo &e, rID xID, int16 Event) {
    // Fast reject via EventMask
    if (!(EventMask & BIT((e.Event % 16) + 1)))
        return NOTHING;

    // Scan annotations for matching event handlers
    for (a = FAnnot(); a; a = NAnnot())
        if (a->AnType == AN_EVENT)
            for (i = 0; i != 5; i++)
                if (a->u.ev[i].Event == e.Event) {
                    // Code handler: execute VM bytecode
                    res = theGame->VM.Execute(&e, xID, a->u.ev[i].MsgOrCode);
                    return (EvReturn) res;
                }
                else if (a->u.ev[i].Event == -e.Event)
                    // Message handler: collect message string
                    EvMsg[MsgNum++] = module->QTextSeg + a->u.ev[i].MsgOrCode;

    // Print collected messages based on count
    switch(MsgNum) {
        case 1: APrint(e, EvMsg[0]); e.Terse = true; break;      // Actor-perspective
        case 2: DPrint(e, EvMsg[0], EvMsg[1]); e.Terse = true; break;  // Dual-perspective
        case 3: TPrint(e, EvMsg[0], EvMsg[1], EvMsg[2]); e.Terse = true; break; // Triple
    }
    // For DAMAGE/DEATH/MAGIC_HIT/MAGIC_STRIKE: uses VPrint (victim-perspective) instead of DPrint
    return e.Terse ? NOMSG : NOTHING;
}
```

Key details:
- Code handlers return immediately. Only the first matching code handler executes.
- Message handlers are accumulated (up to 64). Multiple message strings can exist for the same event.
- Messages use different print functions based on count: APrint (1 msg), DPrint/VPrint (2 msgs), TPrint (3 msgs).
- Special kludge: `EV_MAGIC_HIT` messages are only printed once per target via `e.MHMessageDone` flag.

### Object-Level Event Handlers

Each game object type has its own `Event` method that dispatches events to specific handler methods.

#### Creature::Event Pattern

Creature::Event has two distinct phases before the switch:

```cpp
EvReturn Creature::Event(EventInfo &e) {
    // Phase 1: If this creature is the VICTIM, dispatch to monster type + templates
    if (e.EVictim == this) {
        e.Event = EVICTIM(e.Event);         // ev + 2000
        res = TMON(mID)->Event(e, mID);     // Monster resource script
        // Also iterate all TEMPLATE stati and dispatch to each template
        StatiIterNature(this, TEMPLATE) {
            res = TTEM(S->eID)->Event(e, S->eID);
        }
        e.Event -= EVICTIM(0);              // Restore event code
    }

    // Phase 2: If this creature is the ACTOR, dispatch to monster type + templates
    if (e.EActor == this) {
        res = TMON(mID)->Event(e, mID);
        StatiIterNature(this, TEMPLATE) {
            res = TTEM(S->eID)->Event(e, S->eID);
        }
    }

    // Phase 3: Switch on event code to call specific handler methods
    switch(e.Event) {
        case EV_MOVE:      if (e.EActor == this) return Walk(e);
        case EV_STRIKE:    if (e.EActor == this) return Strike(e);
        case EV_HIT:       if (e.EActor == this) return Hit(e);
        case EV_DAMAGE:    if (e.EVictim == this) return Damage(e);
        case EV_DEATH:     if (e.EVictim == this) return Death(e);
        case EV_CAST:      if (e.EActor == this) return Cast(e);
        case EV_EFFECT:    return MagicEvent(e);  // No actor check
        case PRE(EV_STRIKE): if (e.EActor == this) return PreStrike(e);
        case POST(EV_STRIKE): // Skirmish behavior, Feed Upon Pain
        // ... 50+ more cases
    }
    // Fallback: if isVerb flag set and actor is this, try HandleVerb
    if (e.isVerb && e.EActor == this)
        return HandleVerb(e);
    return NOTHING;
}
```

Important pattern: Each case checks `e.EActor == this` or `e.EVictim == this` before dispatching. This is because ThrowTo calls Event on every parameter object, not just the relevant one. The self-check prevents a weapon from handling an attack meant for a creature.

#### Item::Event Pattern

Item has a unique pre-dispatch that sends events to the item's magical effect:

```cpp
EvReturn Item::Event(EventInfo &e) {
    // Phase 1: If item has an effect (eID), dispatch as EITEM variant
    if (eID && eID != e.eID) {
        e.Event = EITEM(e.Event);            // ev + 4000
        res = TEFF(eID)->Event(e, eID);      // Effect resource script
        e.Event -= EITEM(0);                 // Restore
    }

    // Phase 2: Dispatch to item type resource
    res = TITEM(iID)->Event(e, iID);

    // Phase 3: Switch on specific events
    switch(e.Event) {
        case EV_DAMAGE:   if (e.ETarget == this) return Damage(e);
        case EV_EFFECT:   return MagicEvent(e);
        case EV_MAGIC_HIT: return MagicHit(e);
        case EV_ZAP:      return ZapWand(e);  // etc.
    }
}
```

The `EITEM` modifier allows effect scripts to distinguish between being the spell being cast vs. being an item enchantment reacting to an event.

#### Character::Event Pattern

Character handles religion-related events exclusively:
```cpp
EvReturn Character::Event(EventInfo &e) {
    if (e.EActor != this) return NOTHING;
    switch (e.Event) {
        case PRE(EV_PRAY):     return PrePray(e);
        case EV_PRAY:          return Pray(e);
        case EV_SACRIFICE:     return Sacrifice(e);
        case EV_RETRIBUTION:   return Retribution(e);
        case EV_GIVE_AID:      return GiveAid(e);
        // ... more religion events
    }
    return NOTHING;
}
```

#### Player::Event Pattern

Player handles player-specific events that don't apply to monsters:
```cpp
EvReturn Player::Event(EventInfo &e) {
    switch (e.Event) {
        case EV_DEATH:     if (e.EVictim == this) return Death(e);
        case POST(EV_MOVE): UpdateMap = true; break;
        case EV_VICTORY:   VictoryFlag = true; /* ... */ break;
        case EV_REST:      return Rest(e);
        case EV_GOD_RAISE: return GodRaise(e);
    }
    return NOTHING;
}
```

#### Thing::Event (Base Class)

Handles basic events that apply to all things:
```cpp
EvReturn Thing::Event(EventInfo &e) {
    switch(e.Event) {
        case EV_TURN:  return DONE;
        case EV_PLACE: return DONE;
        case PRE(EV_FIELDON):
        case PRE(EV_FIELDOFF):
            // Check if thing is affected by field's effect; ABORT if not
        case EV_FIELDON:  if (e.EActor == this) return FieldOn(e);
        case EV_FIELDOFF: if (e.EActor == this) return FieldOff(e);
    }
    return NOTHING;
}
```

#### Map::Event

Map handles encounter generation events:
```cpp
EvReturn Map::Event(EventInfo &e) {
    // First dispatch to encounter and template resources
    SEND_TO(enID)       // Encounter resource
    SEND_TO(ep_mID)     // Monster template
    SEND_TO(ep_tID)     // etc.

    switch (e.Event) {
        case EV_ENGEN:           return enGenerate(e);
        case EV_ENGEN_PART:      return enGenPart(e);
        case EV_ENBUILD_MON:     return enBuildMon(e);
        case EV_ENCHOOSE_MID:    return enChooseMID(e);
        // ... more encounter generation events
    }
    return NOTHING;
}
```

### Dispatch Entry Points (Throw Variants)

All entry points follow the same pattern: push onto EventStack, call RealThrow, pop stack.

| Function | Extra Setup | Purpose |
|----------|------------|---------|
| `Throw(Ev, p1, p2, p3, p4)` | None | Basic event with up to 4 parameter objects |
| `ReThrow(ev, e)` | Copies existing EventInfo, sets new event code | Re-dispatch with modified event type |
| `ThrowDir(Ev, d, p1..p4)` | Sets `EDir = d`, `isDir = true` | Directional events |
| `ThrowXY(Ev, x, y, p1..p4)` | Sets `EXVal`, `EYVal`, `isLoc = true` | Location-targeted events |
| `ThrowVal(Ev, n, p1..p4)` | Sets `EParam = n` | Events with integer parameter |
| `ThrowEff(Ev, eID, p1..p4)` | Sets `eID` (effect resource ID) | Events associated with an effect |
| `ThrowEffDir(Ev, eID, d, p1..p4)` | Sets `eID`, `EDir`, `isDir` | Directional effect events |
| `ThrowEffXY(Ev, eID, x, y, p1..p4)` | Sets `eID`, `EXVal`, `EYVal`, `isLoc` | Location-targeted effect events |
| `ThrowLoc(Ev, x, y, p1..p4)` | Sets `EXVal`, `EYVal`, `isLoc` | Synonym for ThrowXY |
| `ThrowField(Ev, f, p1..p4)` | Sets `EField = f` | Events associated with a map field |
| `ThrowDmg(Ev, DType, DmgVal, s, p1..p4)` | Sets `DType`, `vDmg`, `GraveText` | Damage events |
| `ThrowTerraDmg(Ev, DType, DmgVal, s, victim, trID)` | Sets up actor from terrain creator, handles illusionary terrain | Terrain-originated damage |
| `ThrowDmgEff(Ev, DType, DmgVal, s, eID, p1..p4)` | Sets `DType`, `vDmg`, `GraveText`, `eID` | Damage from a specific effect |
| `RedirectEff(e, eID, Ev)` | Copies event, sets new eID, does NOT propagate changes back | One-way effect redirection |

#### ReThrow: Bidirectional State Propagation

`ReThrow` is special because it propagates changes **back** to the caller's EventInfo:

```cpp
EvReturn ReThrow(int16 ev, EventInfo &e) {
    EventSP++;
    CHECK_OVERFLOW;
    EventStack[EventSP] = e;              // Copy caller's state to stack
    EventStack[EventSP].Event = ev;        // Set new event code
    EventStack[EventSP].Terse = false;     // Reset terse flag
    EventStack[EventSP].isVerb = false;
    r = RealThrow(EventStack[EventSP]);    // Dispatch
    EventStack[EventSP].Event = e.Event;   // Restore original event code
    ter = e.Terse;                         // Preserve caller's Terse
    e = EventStack[EventSP];              // Copy ALL changes back to caller
    e.Terse = ter;                        // Restore Terse (don't let sub-event override)
    EventSP--;
    return r;
}
```

This means handlers can modify `e.isHit`, `e.vDmg`, etc. and those changes propagate back to the caller. The `Terse` flag is explicitly preserved from the caller.

#### RedirectEff: One-Way Propagation

`RedirectEff` is the opposite -- it copies the outer event's data to a new stack entry but does NOT copy results back:

```cpp
EvReturn RedirectEff(EventInfo &e, rID eID, int16 Ev) {
    EventSP++;
    EventStack[EventSP] = e;
    EventStack[EventSP].eID = eID;
    EventStack[EventSP].Event = Ev;
    EventStack[EventSP].isActivation = false;
    // ... optional effect prompt ...
    r = RealThrow(EventStack[EventSP]);
    EventSP--;
    return r;  // Changes to EventStack NOT copied back to e
}
```

Used for triggering a secondary effect within an effect (e.g., an item activation calling a spell) without corrupting the outer effect's `efNum`, `EMagic`, etc.

### Convenience Macros for Event Dispatch

```cpp
// PEVENT: Post event to a specific effect resource (bypasses normal dispatch)
#define PEVENT(ev, actor, xID, set_val, r)
    // Creates local EventInfo, sets actor=victim=actor, calls TEFF(xID)->Event directly

// DAMAGE: Shorthand for throwing a damage event
#define DAMAGE(act, vic, dtype, amt, str, set_val)
    // Creates local EventInfo, sets up damage fields, calls ReThrow(EV_DAMAGE, ...)

// XTHROW: Copy event, modify, rethrow (result not captured)
#define XTHROW(ev, e, set_val)
    // Creates copy xe = e, applies set_val, ReThrow(ev, xe), copies xe.chResult back

// RXTHROW: Like XTHROW but captures return value
#define RXTHROW(ev, e, r, set_val)
    // Same as XTHROW but r = ReThrow(ev, xe)

// THROW: Create fresh event and rethrow (minimal setup)
#define THROW(ev, set_val)
    // Creates fresh EventInfo, applies set_val, ReThrow(ev, xe)
```

Note a bug in PEVENT and DAMAGE macros: `e.EXVal = actor->y` should be `e.EYVal = actor->y`.

### EVerify: Parameter Type Checking

The `EVerify` macro validates that event parameters match expected types:
```cpp
#define EVerify(p1, p2, p3, p4)
    // For each non-zero expected type, checks that e.p[N] is non-null and matches type
    // Fatal error on mismatch: "Incorrect Parameter type" or "Unexpected NULL Event Parameter!"
```

Used in handler switch cases:
```cpp
case EV_PICKUP:
    EVerify(T_CREATURE, 0, T_ITEM, 0)  // p[0]=creature, p[2]=item
    if (e.EActor == this) return PickUp(e);
```

### God Evaluation System

Gods evaluate character conduct via a pre-cached array:

```cpp
TGod*  GodList[MAX_GODS];     // Cached god resource pointers
rID    GodIDList[MAX_GODS];   // Cached god resource IDs
int16  nGods;                 // Count of gods

void InitGodArrays() {
    for (i = 0; i != theGame->LastGod(); i++) {
        GodIDList[i] = theGame->GodID(i);
        GodList[i] = TGOD(GodIDList[i]);
    }
    nGods = i;
}
```

When a Character is the actor, every god evaluates the event with `GODWATCH(e.Event)`. When a Character is the victim, every god evaluates with `GODWATCH(EVICTIM(e.Event))`. The event code is temporarily modified and restored after each god evaluation.

### TRAP_EVENT: Stati-Based Event Interception

Objects can have `TRAP_EVENT` stati that intercept events passing through them:

```cpp
StatiIterNature(t, TRAP_EVENT) {
    oEv = e.Event;
    // For p[1] (victim), use META(EVICTIM(ev)); for others, use META(ev)
    e.Event = (i == 1) ? META(EVICTIM(e.Event)) : META(e.Event);
    if (META(S->Mag) == e.Event)   // S->Mag holds the base event code to trap
        res = RES(S->eID)->Event(e, S->eID);  // Dispatch to the stati's effect resource
    e.Event = oEv;
}
```

This allows effects to set up "event traps" -- for example, a Contingency spell could set a TRAP_EVENT stati that fires when the creature takes damage.

### Complete Attack Event Flow Example

An attack from initiation to resolution follows this event chain:

```
1. Player action triggers EV_ATTK
   -> Creature decides attack mode (melee/ranged/natural)

2. EV_WATTACK (weapon attack sequence)
   -> Creature::WAttack validates attack (sanity checks, state checks)
   -> Iterates attack routine: for each attack in the sequence:
      -> ReThrow(EV_STRIKE, e)

3. PRE(EV_STRIKE) = 519
   -> ThrowEvent dispatches to all handlers in priority order
   -> Region/terrain can abort
   -> Resource scripts can modify hit/damage
   -> Creature::PreStrike calculates hit modifiers, defense values

4. EV_STRIKE = 19
   -> Creature::Strike is the core attack resolution:
      -> Roll d20 (e.vRoll)
      -> Check miss chance (concealment, blur, displacement, cover)
      -> Reveal attacker/target
      -> Check incorporeality
      -> Calculate hit: (vHit + vRoll >= max(vDef, vRideCheck)) || vRoll == 20
      -> Calculate crit: vRoll >= vThreat && (vHit + vtRoll) >= vDef
      -> Check crit immunity, fortification
      -> If hit:
         -> ReThrow(EV_HIT, e)
         -> For natural attacks with A_ALSO/A_CRIT riders: additional ReThrow(EV_HIT, ...)
      -> If miss:
         -> ReThrow(EV_MISS, e)
      -> ReThrow(EV_ATTACKMSG, e)  -- display attack message
      -> Clean up temporary stati
      -> Check for response attacks (A_DEQU, etc.)

5. EV_HIT = 20
   -> Creature::Hit calculates damage:
      -> Roll damage dice
      -> Apply modifiers (strength, magic, etc.)
      -> ReThrow(EV_DAMAGE, e)  -- deliver damage to victim

6. EV_DAMAGE = 41
   -> Creature::Damage applies damage:
      -> Check resistances, immunities
      -> Apply damage to HP
      -> If HP <= 0: ReThrow(EV_DEATH, e)

7. POST(EV_STRIKE) = 1019
   -> Skirmish behavior (M_SKIRMISH monsters flee after landing a hit)
   -> Feed Upon Pain healing
```

Each step goes through the full ThrowEvent handler chain, allowing resource scripts, terrain, regions, gods, items, templates, and effects to intercept and modify the event at any point.

### EventInfo Initialization and Cleanup

#### Clear Method

```cpp
void EventInfo::Clear() {
    // First: NULL out all 24 String fields (prevents dangling pointers)
    GraveText = NULL; strDmg = NULL; /* ... all 24 strings ... */
    // Then: memset entire struct to zero
    memset(this, 0, sizeof(EventInfo));
}
```

The two-step clear (null strings then memset) is necessary because String objects may hold pointers to strdup'd buffers. Setting them to NULL first ensures proper cleanup before the memset zeros everything.

#### Copy Semantics

```cpp
void EventInfo::UserDefinedCopy(EventInfo &e) {
    // 1. Raw memory copy of entire struct
    memcpy(this, &e, sizeof(EventInfo));
    // 2. Zero out string region (to clear copied pointers)
    memset(&GraveText, 0, sizeof(String) * 24);
    // 3. Properly copy each String using String::operator=
    GraveText = e.GraveText;
    strDmg = e.strDmg;
    // ... all 24 strings
}
```

This is a deliberate optimization: `memcpy` the whole struct (fast for the ~200 non-string fields), then properly copy just the strings. The comment warns this relies on assumptions: no virtual members in String, struct layout matches declaration order, and zero-initialized String equals empty string.

### SetEvent: Basic Initialization

```cpp
void SetEvent(EventInfo &e, int16 Ev, Object *p1, Object *p2, Object *p3, Object *p4) {
    e.Clear();
    e.Event = Ev;
    e.p[0].o = p1;
    e.p[1].o = p2;
    e.p[2].o = p3;
    e.p[3].o = p4;
}
```

Note: SetEvent does NOT push onto the event stack or dispatch. It only initializes. Previously returned a static EventInfo, which was changed because static storage caused re-entrancy issues in event loops.

### Special Dispatch: ThrowTerraDmg

Terrain damage has special handling because the "attacker" must be resolved from the terrain creator:

```cpp
EvReturn ThrowTerraDmg(int16 Ev, int16 DType, int16 DmgVal, const char *s,
                       Object *victim, rID trID) {
    // Actor = terrain creator (via Map::GetTerraCreator)
    // If no creator found, actor = victim (self-damage)
    e.p[0].o = m->GetTerraCreator(victim->x, victim->y);
    if (!e.p[0].o) e.p[0].o = victim;

    // If actual terrain differs from trID, it's illusionary:
    if (trID != m->TerrainAt(victim->x, victim->y)) {
        e.effIllusion = true;
        // Find the illusionary terrain field's creator instead
        for (i = 0; m->Fields[i]; i++)
            if (m->Fields[i]->FType & FI_ITERRAIN)
                if (m->Fields[i]->inArea(victim->x, victim->y))
                    e.p[0].o = oThing(m->Fields[i]->Creator);
    }
}
```

### Event System Constants Summary

| Constant | Value | Purpose |
|----------|-------|---------|
| `EVENT_STACK_SIZE` | 128 | Maximum recursive event depth |
| `MAX_GODS` | (from Defines.h) | Maximum gods in god evaluation array |
| `ERROR` | -1 | Handler error return |
| `NOTHING` | 0 | Handler did not handle |
| `DONE` | 1 | Handler completed event |
| `ABORT` | 2 | Handler cancelled event |
| `NOMSG` | 3 | Handler says suppress messages |
| `AN_EVENT` | (from Defines.h) | Annotation type for event handlers |
| `TRAP_EVENT` | 79 | Stati nature for event trapping |

### Event Code Ranges

| Range | Meaning |
|-------|---------|
| 1-499 | Base events (EV_MOVE through EV_ENGEN_ALIGN) |
| 500-999 | PRE events (ev + 500) |
| 1000-1499 | POST events (ev + 1000) |
| 2000-2499 | EVICTIM events (ev + 2000) |
| 4000-4499 | EITEM events (ev + 4000) |
| 10000-14999 | META events for TRAP_EVENT (ev + 10000) |
| 20000-24999 | GODWATCH events (ev + 20000) |

### Message Printing Functions

Events use several perspective-based printing functions:

| Function | Parameters | Semantics |
|----------|-----------|-----------|
| `APrint` | 1 message | Actor-perspective only |
| `DPrint` | 2 messages | msg1 = actor sees, msg2 = others see |
| `VPrint` | 2 messages | msg1 = victim sees, msg2 = others see |
| `TPrint` | 3 messages | msg1 = actor, msg2 = victim, msg3 = others |
| `IPrint` | 1 message | Internal print to specific creature |
| `IDPrint` | 2 messages | Internal dual print |

Resource event messages use these based on count: 1 msg = APrint, 2 msgs = DPrint/VPrint (VPrint for damage/death/magic events), 3 msgs = TPrint.

---

## Porting Considerations

1. **EventInfo size** - This is a massive struct. In Jai, could use a similar flat struct or break into sub-structs by category (combat, encounter, chargen)
2. **EvParam union** - Jai has tagged unions; could use `#type_info` or explicit tag
3. **Dispatch macros** - Replace with inline procedures in Jai
4. **Event handler lookup** - Currently via virtual methods and resource scripts; in Jai, use procedure tables or tagged dispatch
5. **String fields** - Many temporary strings in EventInfo; Jai's string handling differs
6. **The ~60 boolean flags** - Could use a bitfield in Jai
7. **Event code arithmetic** - The PRE/POST/EVICTIM/META/GODWATCH offset system maps cleanly to enums or integer arithmetic in Jai
8. **ThrowTo type hierarchy** - The HIER macro simulates virtual dispatch with a type switch; in Jai, use a procedure pointer table indexed by object type
9. **EventStack** - Fixed-size array with stack pointer is straightforward in Jai
10. **ReThrow bidirectional copy** - The copy-dispatch-copyback pattern needs careful attention to preserve Terse flag behavior
11. **Resource EventMask** - The 16-bit hash-based fast rejection is important for performance and should be preserved
12. **God evaluation cache** - The GodList/GodIDList arrays should be initialized at game start
