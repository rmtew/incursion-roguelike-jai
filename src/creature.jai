// Incursion Port - Creature System
// Reconstructed from RECONSTRUCTION-CORE.md

Creature :: struct {
    using thing: Thing;
    hp, max_hp:     s16;
    mana, max_mana: s16;
    attrs:          [7] s8;  // STR, DEX, CON, INT, WIS, CHA, LUC
    speed:          s16;
    ac:             s16;
}

creature_init :: (c: *Creature) {
    thing_init(*c.thing);
    c.hp = 10;
    c.max_hp = 10;
    c.mana = 0;
    c.max_mana = 0;
    c.speed = 100;
    c.ac = 10;
    for i: 0..6 {
        c.attrs[i] = 10;
    }
}

creature_get_attr :: (c: *Creature, attr: s32) -> s8 {
    if attr < 0 || attr > 6 return 10;
    return c.attrs[attr];
}

creature_set_attr :: (c: *Creature, attr: s32, val: s8) {
    if attr >= 0 && attr <= 6 {
        c.attrs[attr] = val;
    }
}

creature_attr_mod :: (c: *Creature, attr: s32) -> s8 {
    val := creature_get_attr(c, attr);
    return cast(s8) ((val - 10) / 2);
}

creature_is_alive :: (c: *Creature) -> bool {
    return c.hp > 0;
}

creature_take_damage :: (c: *Creature, amount: s16) {
    c.hp -= amount;
    if c.hp < 0 c.hp = 0;
}

creature_heal :: (c: *Creature, amount: s16) {
    c.hp += amount;
    if c.hp > c.max_hp c.hp = c.max_hp;
}

// Character - player or NPC with levels
Character :: struct {
    using creature: Creature;
    level:   s16;
    xp:      s32;
    gender:  u8;  // 0=male, 1=female
    race:    rID;
    cclass:  rID;  // class is reserved keyword
}

character_init :: (c: *Character) {
    creature_init(*c.creature);
    c.level = 1;
    c.xp = 0;
    c.gender = 0;
    c.race = NULL_ID;
    c.cclass = NULL_ID;
}

get_pronoun :: (c: *Character) -> string {
    if c.gender == 1 return "she";
    return "he";
}

get_possessive :: (c: *Character) -> string {
    if c.gender == 1 return "her";
    return "his";
}

// Player
Player :: struct {
    using character: Character;
    known_spells: [..] rID;
}

player_init :: (p: *Player) {
    character_init(*p.character);
}

// Monster
Monster :: struct {
    using creature: Creature;
    template: rID;
    ai_state: u8;
    target:   hObj;
}

monster_init :: (m: *Monster) {
    creature_init(*m.creature);
    m.template = NULL_ID;
    m.ai_state = 0;
    m.target = NULL_OBJ;
}
