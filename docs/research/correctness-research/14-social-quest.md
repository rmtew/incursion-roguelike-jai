# Social, Quest & NPC Systems

**Source**: `Social.cpp`, `Quest.cpp`, `Help.cpp`
**Status**: Architecture identified from headers

## Social System (Social.cpp)

### NPC Interaction Events
| Event | Code | Purpose |
|-------|------|---------|
| EV_TALK | 55 | Initiate conversation |
| EV_BARTER | 56 | Trade items |
| EV_COW | 57 | Intimidate |
| EV_DISMISS | 58 | Dismiss companion |
| EV_DISTRACT | 59 | Distract creature |
| EV_ENLIST | 60 | Recruit companion |
| EV_FAST_TALK | 61 | Persuade/bluff |
| EV_GREET | 62 | Greeting |
| EV_ORDER | 63 | Give order to ally |
| EV_QUELL | 64 | Calm unrest |
| EV_REQUEST | 65 | Request aid |
| EV_SURRENDER | 66 | Surrender |
| EV_TAUNT | 67 | Taunt enemy |

### Creature Methods
```cpp
virtual bool canTalk(Creature *to)   // Can speak?
virtual EvReturn PreTalk(EventInfo &e)  // Pre-conversation setup
virtual EvReturn Barter(EventInfo &e)   // Trade
virtual EvReturn Cow(EventInfo &e)      // Intimidate
virtual EvReturn Taunt(EventInfo &e)    // Taunt
virtual EvReturn Greet(EventInfo &e)    // Greet
bool doSocialSanity(ev, cr)             // Validate social interaction
```

### Companion System
- `MakeCompanion(Player* p, int16 CompType)` - Become companion
- `PHD_PARTY(1)` through `PHD_FREEBIE(6)` - Companion pool types
- `InitCompanions()` - Set up companion system
- `SummonAnimalCompanion(mount)` - Druid/ranger companion
- Max CR tracked: `GetGroupCR()`, `MaxGroupCR()`

### Personality
```cpp
uint32 Personality;  // Personality/background flags
```
Affects NPC reactions and dialogue options.

## Quest System (Quest.cpp)

### TQuest Resource
```cpp
class TQuest : public Resource {
    uint8 Flags[2];   // Quest flags (minimal)
};
```

Quest logic appears to be primarily script-driven rather than hardcoded.
Most quest behavior defined in resource event handlers.

## Help System (Help.cpp)

### Features
- Online help for game elements
- Object descriptions (detailed)
- Monster memory (remembered abilities/attacks from encounters)
- Context-sensitive help

### Monster Memory
Player remembers what they've seen monsters do:
- Attack types observed
- Spells cast
- Abilities used
- Resistances discovered

## Porting Considerations

1. **Social interactions** - Mostly event-driven, port after event system
2. **Companion system** - Complex: CR tracking, party dynamics, AI control
3. **Quests** - Script-driven, needs VMachine first
4. **Help system** - Lower priority, primarily UI
5. **Monster memory** - Player knowledge tracking per monster type
