# Population Specification

## Verification Status

| Section | Status | Source |
|---------|--------|--------|
| PopulatePanel function | VERIFIED | MakeLev.cpp:3269-3301 |
| enGenerate function | VERIFIED | Encounter.cpp:514-1125 |
| enBuildMon function | VERIFIED | Encounter.cpp:2372-2620 |
| FindOpenAreas function | VERIFIED | MakeLev.cpp:3303-3383 |
| FurnishArea function | VERIFIED | MakeLev.cpp:2951-3266 |
| PopulateChest function | VERIFIED | MakeLev.cpp:2911-2949 |
| EN_* flags | VERIFIED | Defines.h:1668-1693 |
| IG_* flags | VERIFIED | Defines.h:1656-1665 |
| FU_* constants | VERIFIED | Defines.h:3828-3843 |
| FOA_* flags | VERIFIED | Defines.h:3496-3508 |
| maxAmtByCR function | VERIFIED | Encounter.cpp:500-512 |

## Challenge Rating Calculation

**Source:** `MakeLev.cpp:3270`

```cpp
int16 DepthCR = (int16)(Con[INITIAL_CR] + (Depth*Con[DUN_SPEED]) / 100 - 1);
```

Where constants are indices into `Con[]` array:
- `INITIAL_CR` (45): Base challenge rating at depth 1
- `DUN_SPEED` (46): CR increase per level (percentage)

## Monster Population

### PopulatePanel Function

**Source:** `MakeLev.cpp:3269-3301`

```cpp
void Map::PopulatePanel(Rect &r, uint16 extraFlags) {
    int16 DepthCR = (int16)(Con[INITIAL_CR] + (Depth*Con[DUN_SPEED]) / 100 - 1);
    int16 realCR;
    rID regID = RegionAt(OpenX[0], OpenY[0]);
    if ((random(100) < 22 - mLuck) && DepthCR > 1 && theGame->Opt(OPT_OOD_MONSTERS))
        /* Generate Out-of-Depth Encounter */
        realCR = DepthCR + random(4) + 1;
    else
        realCR = DepthCR;

    THROW(EV_ENGEN,
        xe.enFlags = EN_DUNGEON | EN_ANYOPEN | ((realCR == DepthCR) ? 0 : (EN_OODMON | EN_SINGLE));
    xe.enFlags |= extraFlags;
    xe.enRegID = regID;
    xe.EMap = this;
    xe.enCR = realCR;
    xe.enDepth = DepthCR;
    if (TREG(regID)->HasFlag(RF_CENTER_ENC) && nCenters)
    {
        xe.enFlags &= ~EN_ANYOPEN;
        xe.isLoc = true;
        int16 i = random(nCenters);
        xe.EXVal = Centers[i] % 256;
        xe.EYVal = Centers[i] / 256;
    }
    );
}
```

**Key behavior:**
- Out-of-depth chance: `random(100) < 22 - mLuck` (when DepthCR > 1 and option enabled)
- OOD monsters: CR increased by `random(4) + 1` (1-5)
- OOD monsters flagged with `EN_OODMON | EN_SINGLE`
- Region's `RF_CENTER_ENC` flag forces placement at room center

### Encounter Flags

**Source:** `Defines.h:1668-1693`

```cpp
#define EN_ROOM     0x00000001 /* Place monsters in last created room */
#define EN_STREAMER 0x00000002 /* Place monsters in (water) streamer */
#define EN_SINGLE   0x00000004 /* Generate only one single monster */
#define EN_FREAKY   0x00000008 /* Ignore normal template restrictions */
#define EN_MAXIMIZE 0x00000010 /* *Must* be stated CR or a little above */
#define EN_DUNGEON  0x00000020 /* Create potential uniques, etc. */
#define EN_MTYPE    0x00000040 /* All monsters of given MType */
#define EN_MONID    0x00000080 /* Specific mID */
#define EN_NOPLACE  0x00000100 /* Place stuff in Candidates, not the map */
#define EN_DEPTH    0x00000200 /* Check map depth vs. monster depth */
#define EN_SUMMON   0x00000400 /* Summoned monsters */
#define EN_ANYOPEN  0x00000800 /* Place according to OpenX / OpenY */
#define EN_MULTIPLE 0x00001000 /* Generate at least 12 monsters */
#define EN_NOBUILD  0x00002000 /* Don't even *create* the monsters */
#define EN_CLUSTER  0x00004000 /* Create all mons within 5 squares of each other */
#define EN_CREATOR  0x00008000 /* Use the creator's party */
#define EN_ILLUSION 0x00010000 /* Create illusionary creatures */
#define EN_SPECIFIC 0x00020000 /* Generate specific creature, not by CR */
#define EN_HOSTILE  0x00040000 /* Create creatures hostile to summoner */
#define EN_DUMP     0x00080000 /* Construct Text Description of Encounter */
#define EN_NESTED   0x00100000 /* Nested Encounter (i.e., vampire) */
#define EN_NOSLEEP  0x00200000 /* Generate None Sleeping */
#define EN_NOMAGIC  0x00400000 /* No Powerful Magic Items (anti-scumming) */
#define EN_VAULT    0x00800000 /* Vault Encounter */
#define EN_AQUATIC  0x01000000 /* Aquatic Encounter */
#define EN_OODMON   0x02000000 /* Out-of-Depth Monster */
#define EN_DUNREGEN 0x04000000 /* Dungeon Regeneration */
```

### Encounter Generation Algorithm

**Source:** `Encounter.cpp:514-1125`

#### Stage 0: Initialize Variables (lines 528-537)

```cpp
if (!(e.enFlags & EN_NESTED)) {
    memset(EncMem,0,sizeof(EncMember)*MAX_ENC_MEMBERS);
    cEncMem = 0;
    cUniform = 0;
    memset(uniformKey,0,sizeof(uniformKey));
    memset(uniformChoice,0,sizeof(uniformChoice));
    memset(CandidateCreatures,0,sizeof(Creature*)*2048);
}
```

#### Desired Amount Calculation (lines 539-554)

```cpp
if (e.enDesAmt)
    ;
else if (e.enFlags & EN_SINGLE)
    e.enDesAmt = 1;
else if (e.enFlags & EN_ANYOPEN) {
    if (e.enDepth > 2)
        e.enDesAmt = max(1,OpenC / 30);
    else if (e.enDepth == 2)
        e.enDesAmt = max(1,OpenC / 50);
    else
        e.enDesAmt = max(1,OpenC / 75);
}
else if (e.enFlags & EN_MULTIPLE)
    e.enDesAmt = 4 + random(5);

e.enDesAmt = min(e.enDesAmt, maxAmtByCR(e.enCR));
```

**Monster count by depth:**
- Depth > 2: `OpenC / 30` (1 monster per 30 open tiles)
- Depth 2: `OpenC / 50` (1 monster per 50 open tiles)
- Depth 1: `OpenC / 75` (1 monster per 75 open tiles)

#### Max Amount by CR (lines 500-512)

```cpp
int16 maxAmtByCR(int16 CR) {
    switch (CR) {
        case 1: return 5;
        case 2: return 7;
        case 3: return 10;
        case 4: return 12;
        case 5: return 15;
        default:
            return (CR > 1) ? 50 : 4;
    }
}
```

#### Stage 1: Choose from Region Encounter List (lines 565-629)

If region has `ENCOUNTER_LIST`, select encounter weighted by CR:
- Skip encounters with `minCR > enCR`
- Skip encounters with alignment conflict
- Weight list format supports `-2` (encounter + constraint) and `-3` (encounter + CR range)

#### Stage 2: Build Potential Encounter List (lines 631-695)

Filter all encounters by:
- `minCR <= enCR <= maxCR`
- Not flagged `NF_NOGEN`
- Aquatic constraints (`NF_AQUATIC`, `NF_CONTEXT_AQUATIC`)
- Vault flag match
- Terrain flags
- Single/multiple/horde flags
- Alignment compatibility

#### Stage 3: Weighted Selection (lines 703-710)

```cpp
w = random((int16)enWeight[c]);
for (i=0;i!=c;i++)
    if (enWeight[i+1] > w) {
        e.enID = enList[i];
        break;
    }
```

#### Stage 4: Part Selection (lines 714-753)

For each encounter part:
- Skip if `minCR > enCR`
- Roll percentile chance
- Handle `EP_ELSE` and `EP_OR` flags

#### Stage 5: XCR Distribution (lines 757-776)

```cpp
e.enXCR = XCR(e.enCR);
e.enSleep = random(100)+1;
/* Increase xCR for large rooms, increase sleep chance to compensate */
if (e.enDesAmt >= 4) {
    e.enXCR += (e.enDesAmt / 3) * (e.enXCR/2);
    if (!(e.enFlags & EN_NOSLEEP))
        for (i=0;i!=(e.enDesAmt / 3);i++)
            e.enSleep = max(e.enSleep,random(100)+1);
}
```

#### Stage 6: Create Parts (lines 780-891)

Build encounter members with templates, checking XCR budget.

#### Stage 7: Build Encounter (lines 925-1124)

```cpp
/* Cap # of creatures at CR max */
cEncMem = min(cEncMem,maxAmtByCR(e.enCR));
/* HACKFIX */
cEncMem = min(cEncMem,5);
```

For each member:
- Create monster with `new Monster(em->mID)`
- Apply templates (`em->tID`, `em->tID2`, `em->tID3`)
- Grant gear from monster and template definitions
- Apply sleep status based on `e.enSleep` threshold
- Handle mounts (`em->hmID`)
- Determine alignment
- Set up leader/formation relationships

### Monster Placement

**Source:** `Encounter.cpp:2537-2620`

```cpp
if (e.enFlags & EN_NOPLACE)
    ;
else if (e.enFlags & EN_ANYOPEN) {
    int16 Tries = 0, j;

    Retry:
    if (Tries >= 50) {
        mn->Remove(true); return ABORT;
    }

    j = random(OpenC);

    /* Aquatic placement */
    if (mn->HasMFlag(M_AMPHIB))
        ;
    else if (mn->isMType(MA_AQUATIC)) {
        if (!TTER(TerrainAt(OpenX[j], OpenY[j]))->HasFlag(TF_WATER))
            { Tries++; goto Retry; }
    }
    else {
        if (TTER(TerrainAt(OpenX[j], OpenY[j]))->HasFlag(TF_WATER))
            { Tries++; goto Retry; }
    }

    /* Special terrain checks */
    if (TTER(TerrainAt(OpenX[j],OpenY[j]))->HasFlag(TF_STICKY))
        if (!mn->isMType(MA_SPIDER))
            { Tries++; goto Retry; }
    if (TTER(TerrainAt(OpenX[j],OpenY[j]))->HasFlag(TF_FALL))
        if (!mn->isAerial())
            { Tries++; goto Retry; }

    mn->PlaceAt(this,OpenX[j],OpenY[j]);
}
```

**Placement rules:**
- Aquatic monsters: must be placed in water (`TF_WATER`)
- Non-aquatic monsters: cannot be placed in water (except `M_AMPHIB`)
- Sticky terrain (`TF_STICKY`): only spiders
- Fall terrain (`TF_FALL`): only aerial creatures
- 50 tries before giving up

## Furnishing System

### FurnishArea Function

**Source:** `MakeLev.cpp:2951-3266`

Called after room generation to add furniture, items, and decorations.

#### Furnishing Types

**Source:** `Defines.h:3828-3843`

```cpp
#define FU_SPLATTER           1   /* Random scatter */
#define FU_TRAIL              2
#define FU_LIFEBLOB           3   /* Cellular automata patches */
#define FU_GRID               4   /* Regular 2x2 grid */
#define FU_COLUMNS            5   /* Alternating rows/columns */
#define FU_CENTER             6   /* Room center points */
#define FU_RANDOM             7   /* Single random placement */
#define FU_TABLE              8
#define FU_BED                9
#define FU_CORNERS            10  /* Corner positions */
#define FU_XCORNERS           11  /* Extended corners */
#define FU_SPACED_COLUMNS     12  /* Widely spaced columns */
#define FU_CENTER_CIRCLE_SMALL   13
#define FU_CENTER_CIRCLE_MEDIUM  14
#define FU_CENTER_CIRCLE_LARGE   15
#define FU_INNER_COLUMNS      16  /* Columns with 2-tile border */
```

#### FU_SPLATTER (lines 3058-3068)

```cpp
if (r.x2)
    j = random(r.Volume()) / 5;
else
    j = random(OpenC) / 8;
for (k = 0; k != j; k++) {
    RANDOM_OPEN;
    if (x != -1) { DRAW_FURNISHING; }
}
```

Density: ~1/5 of room volume or ~1/8 of open tiles.

#### FU_CENTER_CIRCLE_* (lines 3070-3101)

Draws ellipse of furnishings centered on room:
- `LARGE`: Full radius
- `MEDIUM`: Half radius
- `SMALL`: Quarter radius

#### FU_GRID (lines 3107-3113)

```cpp
for (x = r.x1 + 1; x <= r.x2 - 1; x += 2)
    for (y = r.y1 + 1; y <= r.y2 - 1; y += 2)
        DRAW_FURNISHING;
```

Regular 2x2 grid with 1-tile border.

#### FU_COLUMNS (lines 3129-3141)

50% vertical bars, 50% horizontal bars:
```cpp
if (random(2)) {
    for (x = r.x1 + 1; x <= r.x2 - 1; x += 2)
        for (y = r.y1 + 1; y <= r.y2 - 1; y++)
            DRAW_FURNISHING;
} else {
    for (x = r.x1 + 1; x <= r.x2 - 1; x++)
        for (y = r.y1 + 1; y <= r.y2 - 1; y += 2)
            DRAW_FURNISHING;
}
```

### Item Placement in Rooms

**Source:** `MakeLev.cpp:3211-3250`

```cpp
// Chest placement
if (random(100) + 1 < (int16)Con[CHEST_CHANCE] + (1 * (mLuck - 10))) {
    iID = theGame->GetItemID(PUR_DUNGEON, 0, (int8)DepthCR, T_CHEST);
    ch = Item::Create(iID);
    PopulateChest((Container *)ch);
    RANDOM_OPEN_NEAR_SOLID;
    if (x != -1)
        ch->PlaceAt(this, x, y);
}
// Good/Cursed treasure
else if (random(100) + 1 <= (int16)Con[TREASURE_CHANCE])  {
    if (random(100) + 1 <= (int16)Con[CURSED_CHANCE])
        it = Item::GenItem(IG_CURSED, dID, DepthCR, mLuck, DungeonItems);
    else
        it = Item::GenItem(IG_GOOD, dID, DepthCR, mLuck, DungeonItems);
    RANDOM_OPEN_NEAR_SOLID;
}
// Poor item (50% chance if no chest/treasure)
else if (random(100) + 1 < 50) {
    it = Item::GenItem(0, dID, max(0, DepthCR / 2 - 4), 10, DungeonItems);
}

// Staple items
if (random(100) + 1 <= (int16)Con[STAPLE_CHANCE]) {
    it = Item::GenItem(IG_STAPLE, dID, DepthCR, 10, DungeonItems);
}
```

**Item generation constants:**
- `CHEST_CHANCE` (65): Percentage for chest placement
- `TREASURE_CHANCE` (64): Percentage for treasure item
- `CURSED_CHANCE` (68): Percentage of treasure being cursed
- `STAPLE_CHANCE` (69): Percentage for staple items

## Chest Contents

### PopulateChest Function

**Source:** `MakeLev.cpp:2911-2949`

```cpp
void Map::PopulateChest(Container *ch) {
    int16 DepthCR = (int16)(Con[INITIAL_CR] + (Depth*Con[DUN_SPEED]) / 100 - 1);
    int i, j = Con[CHEST_MIN_ITEMS];
    j += random((int16)((Con[CHEST_MAX_ITEMS] - j) + (mLuck - 10) / 2)) + 1;

    for (i = 0; i != j; i++) {
        if (random(100) + 1 <= (int16)Con[TREASURE_CHANCE])
            it = Item::GenItem(IG_CHEST | IG_GOOD, dID, DepthCR + 3, mLuck, ChestItems);
        else
            it = Item::GenItem(IG_CHEST, dID, DepthCR, mLuck, ChestItems);
        if (it)
            ch->XInsert(it);
    }

    // Lock chance increases with depth
    if (random(Depth) && random(Depth))
        ch->GainPermStati(LOCKED, ch, SS_MISC);

    // 1d2-1 staple items
    j = random(2);
    for (i = 0; i != j; i++) {
        it = Item::GenItem(IG_STAPLE, dID, DepthCR, mLuck, StapleItems);
        if (it)
            ch->XInsert(it);
    }

    // 50% chance of 1d5 identify scrolls
    if (!random(2)) {
        it = Item::Create(FIND("scroll"));
        it->MakeMagical(FIND("identify;scroll"));
        it->Quantity = Dice::Roll(1, 5);
        ch->XInsert(it);
    }
}
```

**Chest contents:**
- Item count: `CHEST_MIN_ITEMS` to `CHEST_MAX_ITEMS` + luck modifier
- Treasure items: `TREASURE_CHANCE`% at CR+3 with `IG_GOOD`
- Normal items: At base CR
- Lock chance: `random(Depth) && random(Depth)` (increases quadratically with depth)
- Staple items: 0-1 (50% chance of 1)
- Identify scrolls: 50% chance of 1d5

### Item Generation Flags

**Source:** `Defines.h:1656-1665`

```cpp
#define IG_STAPLE   0x0001  /* Essential consumables */
#define IG_GOOD     0x0002  /* Higher quality */
#define IG_GREAT    0x0004  /* Exceptional quality */
#define IG_WARRIOR  0x0008  /* Warrior-appropriate */
#define IG_WIZARD   0x0010  /* Wizard-appropriate */
#define IG_ROGUE    0x0020  /* Rogue-appropriate */
#define IG_CURSED   0x0040  /* Cursed item */
#define IG_CHEST    0x0080  /* From chest */
#define IG_MONEQUIP 0x0100  /* Monster equipment */
#define IG_KNOWN    0x0200  /* Already identified */
```

## FindOpenAreas Function

**Source:** `MakeLev.cpp:3303-3383`

Populates `OpenX[]`/`OpenY[]` arrays with valid placement locations.

### Open Area Flags

**Source:** `Defines.h:3496-3508`

```cpp
#define FOA_ALLOW_WATER   0x0001  /* Include water tiles */
#define FOA_WATER_ONLY    0x0002  /* Only water tiles */
#define FOA_ALLOW_SPEC    0x0004  /* Include special terrain */
#define FOA_SPEC_ONLY     0x0008  /* Only special terrain */
#define FOA_SOLID_ONLY    0x0010  /* Only solid tiles */
#define FOA_DEEP_ONLY     0x0020  /* Only deep liquid */
#define FOA_NO_TREES      0x0040  /* Exclude trees */
#define FOA_TREES_ONLY    0x0080  /* Only trees */
#define FOA_FLOOR_ONLY    0x0100  /* Only region's floor terrain */
#define FOA_ALLOW_FALL    0x0200  /* Include fall terrain */
#define FOA_FALL_ONLY     0x0400  /* Only fall terrain */
#define FOA_ALLOW_WARN    0x0800  /* Include warning terrain */
#define FOA_WARN_ONLY     0x1000  /* Only warning terrain */
```

### Filter Logic (lines 3312-3378)

For each tile in rectangle:
1. Skip if solid status doesn't match `FOA_SOLID_ONLY`
2. Skip if feature exists
3. Skip if creature exists
4. Check region match
5. Check terrain flags (`TF_SPECIAL`, `TF_WARN`, `TF_WATER`, `TF_FALL`)
6. Check tree status
7. Check floor-only constraint

Maximum 2048 open positions tracked.

## Population Call Order

**Source:** `MakeLev.cpp:2864-2888`

```cpp
// For Castle/Building rooms
if ((RType == RM_CASTLE || RType == RM_BUILDING)) {
    for (i = 0; i != cRectPop; i++) {
        if (TREG(regID)->HasList(ENCOUNTER_LIST))
            if (random(3))
                continue;  // 2/3 chance to skip if region has encounter list
        FindOpenAreas(PopulateQueue[i], regID,
            FOA_ALLOW_WATER | FOA_ALLOW_WARN | FOA_ALLOW_FALL | FOA_ALLOW_SPEC);
        PopulatePanel(PopulateQueue[i], EN_SINGLE);
    }
}
// For normal rooms
else {
    bool anything = false;
    FindOpenAreas(cPanel, regID, 0);
    if (r.x1 < r.x2) { anything = true; FurnishArea(r); }
    if (r2.x1 < r2.x2) { anything = true; FurnishArea(r2); }
    if (r3.x1 < r3.x2) { anything = true; FurnishArea(r3); }
    if (r4.x1 < r4.x2) { anything = true; FurnishArea(r4); }

    if (!anything)
        FurnishArea(NULL_RECT);
    FindOpenAreas(cPanel, regID,
        FOA_ALLOW_WATER | FOA_ALLOW_WARN | FOA_ALLOW_FALL | FOA_ALLOW_SPEC);
    PopulatePanel(cPanel);
}
```

**Population sequence:**
1. Find open areas (strict for furniture)
2. Apply furnishings to sub-rectangles
3. Find open areas (permissive for monsters)
4. Populate with encounters

## Party Assignment

**Source:** `MakeLev.cpp:2900-2908`

```cpp
int16 PartyID = MAX_PLAYERS + 10 + random(200);
for (x = cPanel.x1; x <= cPanel.x2; x++)
    for (y = cPanel.y1; y <= cPanel.y2; y++)
        if (InBounds(x, y))
            for (Creature *cr = FCreatureAt(x, y); cr; cr = NCreatureAt(x, y))
                cr->PartyID = PartyID;
```

All creatures in the same panel share a party ID (prevents in-fighting).
