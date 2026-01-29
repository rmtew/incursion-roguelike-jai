# Lighting System Specification

How Incursion handles light sources, darkness, and their effect on visibility.

## Data Structures

### LocationInfo Lighting Fields (from `inc/Map.h` lines 29-39)

```c
struct LocationInfo {
    // ...
    unsigned int Lit         :1;   // Cell is lit (terrain or torch)
    unsigned int Bright      :1;   // Brightly lit (near torch center)
    unsigned int Shade       :1;   // Can have shading applied (floor colors)
    unsigned int Dark        :1;   // Magical darkness
    unsigned int mLight      :1;   // Magical light (from spells)
    // ...
};
```

### Creature Vision Ranges (from `inc/Creature.h` lines 187-190)

```c
// Precalculated vision ranges (set in CalcValues)
uint8 TremorRange;    // Tremorsense distance
uint8 SightRange;     // Maximum visual distance
uint8 LightRange;     // Personal light radius (torch, lantern)
uint8 BlindRange;     // Blindsight (echolocation)
uint8 InfraRange;     // Infravision/darkvision
uint8 PercepRange;    // Magical perception
uint8 TelepRange;     // Telepathy range
uint8 ScentRange;     // Scent tracking
uint8 ShadowRange;    // Dim shape perception
uint8 NatureSight;    // Nature sense (druids)
```

## Vision Range Calculation

**Source:** `src/Values.cpp` lines 1392-1448

### SightRange (Maximum Vision)

```c
SightRange = max(12, 15 + Mod(A_WIS) * 3) + AbilityLevel(CA_SHARP_SENSES) * 2;

// FT_ACUTE_SENSES feat: 50% bonus
if (HasFeat(FT_ACUTE_SENSES))
    SightRange = (SightRange * 3) / 2;

// Blindness negates all sight-based ranges
if (isBlind())
    SightRange = ShadowRange = InfraRange = 0;
```

**Typical values:** 12-21 (base 15, modified by WIS and feats)

### LightRange (Personal Light)

```c
// From equipped light source
LightRange = EInSlot(SL_LIGHT) ? EInSlot(SL_LIGHT)->GetLightRange() : 0;

// Glowing weapons add to light range
if (InSlot(SL_WEAPON) && InSlot(SL_WEAPON)->HasQuality(WQ_GLOWING))
    LightRange = max(LightRange, InSlot(SL_WEAPON)->GetPlus() * 3);

// Low-light vision extends light range
if (LightRange)
    LightRange += AbilityLevel(CA_LOWLIGHT);
```

**Item light ranges:** Defined in item definitions (typically 3-6 for torches/lanterns)

### ShadowRange (Dim Perception)

```c
// Shadow range is always 2x light range
ShadowRange = LightRange * 2;
```

### InfraRange (Darkvision)

```c
InfraRange = AbilityLevel(CA_INFRAVISION);

// Monsters without any vision get baseline infravision
if (!isPlayer() && InfraRange + LightRange + ... == 0)
    InfraRange = max(6, InfraRange);
```

### BlindRange (Blindsight)

```c
BlindRange = AbilityLevel(CA_BLINDSIGHT) + HasFeat(FT_BLINDSIGHT);

// Penalties from equipment
if (m->FieldAt(x, y, FI_SILENCE))
    BlindRange = 0;  // Silence negates echolocation
if (InSlot(SL_HELM) && EInSlot(SL_HELM)->isMetallic())
    BlindRange /= 2;  // Metal helm reduces sensitivity
// Large weapons reduce blindsight range
```

## Light Sources in Dungeon

### Terrain-Based Light

**Source:** `src/MakeLev.cpp` lines 132-160

```c
// TF_LOCAL_LIGHT terrain is always lit
At(x, y).Lit = TTER(TerrainAt(x, y))->HasFlag(TF_LOCAL_LIGHT);
```

### Torch Placement

**Source:** `src/MakeLev.cpp` lines 186-207

Room lighting chance:
```c
// Base 50% chance, decreases 4% per depth
if (random(100) + 1 > (ROOM_LIT_CHANCE - LIT_CHANCE_DEPTH_MOD * depth))
    return;  // Room stays dark

// RF_ALWAYS_LIT regions ignore the roll
if (tr->HasFlag(RF_ALWAYS_LIT))
    // Always place torches
```

Torch density:
```c
// Place torches on walls (TF_TORCH terrain)
// Density: 1 in TORCH_DENSITY tiles (default 10)
for each wall tile:
    if (!random(Den))
        WriteAt(x, y, TERRAIN_TORCH);
        TorchList.Add(x + y * 256);
```

### Torch Light Calculation

**Source:** `src/MakeLev.cpp` lines 163-175

```c
int16 Map::isTorched(uint8 x, uint8 y, int16 t) {
    tx = TorchList[t] % 256;
    ty = TorchList[t] / 256;

    if (abs(x - tx) < 8 && abs(y - ty) < 8) {
        d = dist(x, y, tx, ty);
        if (d < 8 && LineOfVisualSight(x, y, tx, ty, NULL)) {
            // Return light level based on distance
            if (d < 3) return 3;  // Bright (yellow)
            if (d < 5) return 2;  // Medium (brown)
            return 1;             // Dim
        }
    }
    return 0;  // Not lit by this torch
}
```

### Light Level Effects on Glyph Color

**Source:** `src/MakeLev.cpp` lines 147-159

```c
if (At(x, y).Shade && GLYPH_ID_VALUE(At(x, y).Glyph) == GLYPH_FLOOR) {
    switch (light_level) {
    case 3:  // Bright
        At(x, y).Glyph = GLYPH_VALUE(GLYPH_FLOOR, YELLOW);
        At(x, y).Bright = true;
        break;
    case 2:  // Medium
        At(x, y).Glyph = GLYPH_VALUE(GLYPH_FLOOR, BROWN);
        break;
    // case 1: dim - no color change
    }
}
```

## Visibility Decision Logic

**Source:** `src/Vision.cpp` lines 35-55 (`MarkAsSeen`)

```c
inline bool Map::MarkAsSeen(int8 pn, int16 lx, int16 ly, int16 dist,
    int16 SightRange, int16 LightRange, int16 ShadowOrBlindRange)
{
    LocationInfo & Here = At(lx, ly);

    if (SightRange) {
        // Normal vision checks
        if (dist > SightRange)
            return true;  // Beyond maximum range

        if (dist > ShadowOrBlindRange && !Here.Lit && !Here.mLight)
            return true;  // Too far in darkness

        if (dist > LightRange && !Here.Lit && !Here.mLight)
            Mask = VI_DEFINED;  // Shadow only
        else
            Mask = VI_VISIBLE | VI_DEFINED;  // Full visibility
    } else {
        // Blindsight (no visual sight)
        if (dist > ShadowOrBlindRange)
            return true;
        Mask = VI_DEFINED;  // Always shadow for blindsight
    }

    Here.Visibility |= Mask << (pn * 4);
    Here.Memory = Here.Glyph;
    return false;  // Continue ray
}
```

### Visibility States Summary

| Condition | Result | Display |
|-----------|--------|---------|
| `dist > SightRange` | Can't see | Memory or GLYPH_UNSEEN |
| `dist > ShadowRange && !Lit` | Can't see | Memory or GLYPH_UNSEEN |
| `dist > LightRange && !Lit` | VI_DEFINED only | See shape, no details |
| `dist <= LightRange OR Lit` | VI_VISIBLE + VI_DEFINED | Full visibility |
| Blindsight only | VI_DEFINED | Always shadowy |

## Shadow Rendering

**Source:** `src/Term.cpp` lines 829-831

When a creature is perceived only via shadow (PER_SHADOW):

```c
if (Vis == PER_SHADOW) {
    // Replace glyph with unknown symbol in shadow color
    g = (g & GLYPH_BACK_MASK) | GLYPH_VALUE(GLYPH_UNKNOWN, SHADOW);
}
```

`GLYPH_UNKNOWN` is typically `?` - shows something is there but unclear what.

## Terrain Flags

| Flag | Value | Effect |
|------|-------|--------|
| `TF_TORCH` | 10 | Terrain is a light source |
| `TF_LOCAL_LIGHT` | 25 | Terrain is self-lit (no radius) |
| `TF_SHADE` | - | Floor can have light-level coloring |

## Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `ROOM_LIT_CHANCE` | 50 | % chance room is lit |
| `LIT_CHANCE_DEPTH_MOD` | 4 | % reduction per depth |
| `TORCH_DENSITY` | 10 | 1-in-N wall tiles gets torch |

## Implementation Plan for Jai Port

### Phase 1: Cell Lighting Data

Add to `LocationInfo` or `TileDisplay`:
```jai
LightingInfo :: struct {
    lit: bool;        // Cell is illuminated
    bright: bool;     // Brightly lit (near torch)
    shade: bool;      // Can have floor shading
    dark: bool;       // Magical darkness
    mlight: bool;     // Magical light
}
```

### Phase 2: Torch Tracking

```jai
// Track torch positions for lighting calculation
torch_positions: [..] struct { x: s32; y: s32; };

place_torch :: (m: *GenMap, x: s32, y: s32) {
    // Place torch terrain
    // Add to torch_positions
}

calculate_torch_lighting :: (m: *GenMap) {
    // For each cell, check if lit by any torch
    // Set Lit flag and adjust glyph color
}
```

### Phase 3: Vision Range Calculation

For MVP with single player:
```jai
PlayerVision :: struct {
    sight_range: u8;    // Base ~15
    light_range: u8;    // From equipped light
    shadow_range: u8;   // light_range * 2
    infra_range: u8;    // Darkvision
    blind_range: u8;    // Blindsight
}

calc_player_vision :: (p: *Player) -> PlayerVision {
    // Calculate based on stats, equipment, abilities
}
```

### Phase 4: Integration with FOV

Update visibility calculation to use light ranges:
```jai
mark_cell_seen :: (m: *GenMap, x: s32, y: s32, dist: s32, vision: PlayerVision) {
    cell := *m.cells[y * m.width + x];

    if dist > vision.sight_range {
        return;  // Beyond max vision
    }

    is_lit := cell.lit || cell.mlight;

    if dist > vision.shadow_range && !is_lit {
        return;  // Too far in darkness
    }

    if dist > vision.light_range && !is_lit {
        // Shadow only
        cell.visibility |= VI_DEFINED;
    } else {
        // Full visibility
        cell.visibility |= VI_VISIBLE | VI_DEFINED;
    }

    cell.memory = cell.glyph;
}
```

## Verification Checklist

- [ ] Rooms have random chance of being lit based on depth
- [ ] Torch terrain placed on walls at correct density
- [ ] Cells near torches marked as Lit
- [ ] Floor colors affected by torch proximity (yellow/brown)
- [ ] Vision blocked beyond SightRange
- [ ] Dark cells only visible within LightRange or InfraRange
- [ ] Shadow rendering shows GLYPH_UNKNOWN for distant unlit creatures
- [ ] Magical light (mLight) overrides darkness
- [ ] Magical darkness (Dark) blocks vision

## Key Source Files

| File | Lines | Content |
|------|-------|---------|
| `inc/Map.h` | 29-39 | LocationInfo lighting flags |
| `inc/Creature.h` | 187-190 | Vision range fields |
| `src/Values.cpp` | 1392-1448 | Vision range calculation |
| `src/MakeLev.cpp` | 132-207 | Torch placement, calcLight |
| `src/Vision.cpp` | 35-55 | MarkAsSeen visibility logic |
| `src/Term.cpp` | 829-831 | Shadow rendering |
