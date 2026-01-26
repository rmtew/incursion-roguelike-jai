// Incursion Port - Resource Template Structures
// Reconstructed from RECONSTRUCTION-CORE.md

// Monster template
TMonster :: struct {
    name:   string;
    image:  Glyph;
    size:   u8;
    cr:     s8;
    hd:     s8;
    mov:    s8;
    spd:    s8;
    hit:    s8;
    def:    s8;
    arm:    s8;
    str_val:  s8;
    dex_val:  s8;
    con_val:  s8;
    int_val:  s8;
    wis_val:  s8;
    cha_val:  s8;
    flags:  u64;
    desc:   string;
}

// Item template
TItem :: struct {
    name:    string;
    image:   Glyph;
    itype:   u8;
    level:   s8;
    material: u8;
    weight:  s16;
    cost:    s32;
    damage:  Dice;
    threat:  s8;
    crit:    s8;
    ac:      s8;
    penalty: s8;
    flags:   u64;
    desc:    string;
}

// Effect/Spell template
TEffect :: struct {
    name:    string;
    etype:   s16;
    level:   s8;
    schools: s16;
    flags:   u64;
    desc:    string;
}

// Feature template
TFeature :: struct {
    name:    string;
    image:   Glyph;
    ftype:   u8;
    flags:   u64;
    desc:    string;
}

// Terrain template
TTerrain :: struct {
    name:    string;
    image:   Glyph;
    material: u8;
    flags:   u64;
    desc:    string;
}

// Race template
TRace :: struct {
    name:    string;
    str_mod: s8;
    dex_mod: s8;
    con_mod: s8;
    int_mod: s8;
    wis_mod: s8;
    cha_mod: s8;
    luc_mod: s8;
    size:    u8;
    flags:   u64;
    desc:    string;
}

// Class template
TClass :: struct {
    name:     string;
    hitdice:  s8;
    mana:     s8;
    bab:      s8;  // Base attack bonus progression
    flags:    u64;
    desc:     string;
}

// God template
TGod :: struct {
    name:    string;
    domains: [8] rID;
    flags:   u64;
    desc:    string;
}

// Domain template
TDomain :: struct {
    name:    string;
    flags:   u64;
    desc:    string;
}
