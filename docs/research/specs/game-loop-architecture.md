# Game Loop Architecture

**Status:** Design phase — not yet implemented

## Goals

Build a minimal interactive game loop that serves three audiences simultaneously:

1. **AI-driven development** — Claude writes test harnesses that call game functions directly, enabling rapid iteration on gameplay systems without manual testing
2. **Human play** — A GUI window where a player uses keyboard input to explore the dungeon
3. **Shared observation** — Either side can produce artifacts (logs, replays, state dumps) the other side can consume

## Core Principle: Library-First Architecture

The game engine is a **library**, not an executable. All game logic lives in importable modules with no dependency on input source or rendering target. Frontends are thin wrappers that feed commands in and consume state out.

```
┌─────────────────────────────────────────────────┐
│                  Game Library                    │
│                                                  │
│  init_game(seed) → GameState                     │
│  do_action(*GameState, Action) → ActionResult    │
│  get_state(*GameState) → StateSnapshot           │
│  hash_state(*GameState) → u64                    │
│                                                  │
└──────────┬──────────┬──────────┬────────────────┘
           │          │          │
     ┌─────┴───┐ ┌────┴────┐ ┌──┴──────────┐
     │   GUI   │ │Headless │ │   Replay    │
     │Frontend │ │ Test    │ │   Frontend  │
     │(human)  │ │(Claude) │ │(both)       │
     └─────────┘ └─────────┘ └─────────────┘
```

## Deterministic Command Log

The central artifact that enables all use cases. A text file that, combined with a seed, fully reproduces a game session.

### Format

```
SEED 928374
VERSION 1
---
TURN 1 MOVE N
TURN 2 MOVE E
TURN 3 WAIT
TURN 4 ATTACK E
TURN 5 USE potion_healing
```

Optional interleaved checkpoints (ignored during replay, validated during determinism testing):

```
TURN 4 ATTACK E
CHECK hp=45 mp=12 pos=6,3 monsters_visible=2 hash=a83f2c01
```

### Requirements for Determinism

- **Single seeded RNG**: All randomness flows through one PCG instance seeded at game start
- **No environment dependence**: No wall-clock time, pointer addresses, hash map iteration order, or uninitialized memory in game logic
- **Complete command capture**: Every player decision is a logged Action — no implicit state from outside the log
- **Deterministic iteration**: All collection types used in game logic must have deterministic iteration order

## Frontends

### 1. GUI Frontend (Human Player)

- Reads keyboard input, translates to Actions
- Renders GameState to the Simp window each frame
- Writes command log to disk as the player acts
- Existing `dungeon_test.jai` evolves into this

**Controls:**
- Arrow keys / WASD: movement
- Additional keys mapped as systems come online (attack, inventory, etc.)
- Pause/inspect mode for examining game state

### 2. Headless Test Frontend (AI Development)

- Claude writes a `.jai` file that imports the game library
- Calls game functions directly: `init_game()`, `do_action()`, `get_state()`
- Compiles and runs as a standalone executable
- Prints structured output (text or state dumps) that Claude reads

**Example test harness:**
```jai
main :: () {
    gs := init_game(seed=42);

    // Spawn test scenario
    p := spawn_player(*gs, 5, 5);
    g := spawn_monster(*gs, 6, 5, "goblin");

    // Execute action
    result := do_action(*gs, .{type=.ATTACK, dir=.EAST});

    // Verify
    print("hit: %\n", result.hit);
    print("damage: %\n", result.damage);
    print("goblin_hp: %\n", g.hp);
    print("state_hash: %\n", hash_state(*gs));
}
```

**Why this mode is powerful for Claude:**
- No IPC, no pipes, no timeouts — just compile and run
- Full access to internal game state, not limited to a query protocol
- Can write focused tests for specific mechanics
- Can set up arbitrary scenarios that would be hard to reach via normal play
- Matches existing `dungeon_test.jai` workflow

### 3. Replay Frontend

- Reads a command log file
- Feeds each command to the game library in sequence
- Can operate in two modes:
  - **Headless**: validates checkpoints, reports divergence, outputs final state hash
  - **Visual**: renders each step to a window (with speed control, pause, step-through)

**Use cases:**
- **Determinism testing**: Replay a log, compare final state hash against recorded value
- **Bug reproduction**: User submits a log file, Claude replays it to inspect the failure point
- **Replay video**: Render a visual replay for sharing or review; could add overlays (damage numbers, threat indicators, FOV highlights)
- **Regression testing**: Library of saved logs that must replay identically after code changes

## Use Cases in Detail

### A. AI Development and Testing

**Scenario testing:**
- Write harnesses that exercise specific systems (combat, magic, movement)
- Set up precise initial conditions impossible to reach through normal play
- Assert expected outcomes with exact values

**Fuzz testing:**
- Generate random valid action sequences for N turns
- Run thousands of games with different seeds
- Flag crashes, assertion failures, or determinism violations

**Regression testing:**
- Maintain a library of command logs with expected final state hashes
- After code changes, replay all logs and verify hashes match
- Binary search divergent logs to find the exact turn where behavior changed

**Formula verification:**
- Set up scenarios matching original Incursion conditions
- Compare our output against values documented in correctness research
- Example: "goblin at CR1, player with +3 attack, verify hit/damage distributions over 10000 trials"

### B. Human Play with AI Observation

**Live play:**
- User plays in GUI, game writes command log in real-time
- After session, Claude reads the log and game output
- Can analyze decisions, flag potential bugs, compute statistics

**Assisted debugging:**
- User encounters a bug during play
- Command log up to that point is the complete bug report
- Claude replays headless, inspects state at the failure turn
- No need for save files, screenshots, or verbal descriptions

**Replay review:**
- User provides a command log
- Claude replays it, annotates interesting moments
- Could generate an enhanced replay with overlays

### C. Determinism Verification

**Hash-based verification:**
- `hash_state()` produces a deterministic u64 from full game state
- Command logs include periodic `CHECK hash=...` lines
- Replay verifies hash at each checkpoint
- Any mismatch identifies the exact turn where determinism broke

**Bisection debugging:**
- Given a log that replays differently, binary search for first divergent turn
- Narrow down which system introduced non-determinism
- Critical for catching: uninitialized memory, iteration order bugs, floating point platform differences

### D. Replay as Save Format

**Conceptually:** seed + command log = complete game history. A traditional save file is just an optimization to avoid replaying from turn zero.

**Both can coexist:**
- Save files for fast resume (serialize current GameState)
- Command logs for debugging, sharing, verification
- Save file could embed the command log for full traceability

## Implementation Order

1. **GameState structure** — Central state object holding map, entities, RNG, turn counter
2. **Action enum** — All possible player commands (move, wait, attack, use, etc.)
3. **do_action()** — Execute an action, advance game state, return result
4. **Command log writer** — Append each action to a log file
5. **Command log reader** — Parse log file into action sequence
6. **hash_state()** — Deterministic hash of full game state
7. **Headless test frontend** — Evolve from current test infrastructure
8. **GUI frontend** — Evolve dungeon_test.jai to accept keyboard input and run game loop
9. **Replay frontend** — Feed log into game library, verify or render
10. **Checkpoint system** — Periodic state hashes in logs for verification

## Files

| File | Purpose |
|------|---------|
| `src/game/state.jai` | GameState, Action, ActionResult types |
| `src/game/loop.jai` | do_action(), turn processing |
| `src/game/log.jai` | Command log read/write |
| `src/game/hash.jai` | State hashing for determinism checks |
| `src/dungeon/` | Existing map/render/visibility (unchanged) |
| `tools/dungeon_test.jai` | Evolves into GUI frontend |
| `tools/replay.jai` | Replay frontend |
| Tests written ad-hoc | Headless test harnesses |

## Relationship to Existing Systems

The current codebase has:
- **Dungeon generation** (`src/dungeon/`) — produces a GenMap
- **Rendering** (`src/dungeon/render.jai`) — converts map state to glyphs
- **Visibility** (`src/dungeon/visibility.jai`) — FOV and lighting
- **Resource database** — baked monster/item/terrain tables
- **Terminal renderer** (`src/terminal/`) — Simp-based glyph display

GameState wraps these: it owns a GenMap, a player entity, a turn counter, and the RNG. The existing rendering and visibility code is called by the GUI frontend but not by headless tests (which query state directly).

## Design Decisions

- **Action granularity**: One action = one player decision = one keypress. Everything between keypresses (monster turns, triggered effects, door auto-opens, traps fire, FOV recalculates) is deterministic resolution of that single action. The log records `MOVE N`, not `OPEN_DOOR then MOVE N`. This matches the original Incursion model where the player acts, then the world resolves.
- **Monster turns**: Not logged. They are deterministic output of seed + player action sequence. Logging them would be redundant since replay reproduces them identically. (Debug output during replay can print them for inspection.)

## Design Decisions (continued)

- **State snapshot format**: Text with labeled key=value pairs. Best for both Claude (reads file output directly, no decoder needed) and humans (scannable without tooling). Two levels of detail:
  - **Checkpoint lines** (in command log): compact single-line `CHECK hp=45 mp=12 pos=6,3 hash=a83f2c01`
  - **Full state dumps** (for debugging): multi-line with sections, printed to stdout or file
  - Binary serialization deferred to save files if needed for performance; not used for inspection or logging

## Design Decisions (continued)

- **Log compression**: No compression. A 50,000-turn game at ~20 bytes/line is ~1MB — trivially small. Plain text is human-readable, grep-able, and git-friendly. If bulk storage of regression logs ever matters, gzip after the session. Run-length encoding of repeated actions (e.g., `TURN 1-14 MOVE N`) is a possible future optimization but not worth the parser complexity now.
