// Game State Hashing - FNV-1a (64-bit)
//
// Deterministic hash of game state for replay verification.
// Hashes: seed, turn, depth, player position, all tiles, door states.
// Does NOT hash: visibility (derived), display info (rendering-only),
// RNG state (implied by seed + actions).

// FNV-1a 64-bit constants
FNV_OFFSET_BASIS : u64 : 0xcbf29ce484222325;
FNV_PRIME        : u64 : 0x00000100000001b3;

fnv1a_init :: () -> u64 {
    return FNV_OFFSET_BASIS;
}

fnv1a_byte :: (hash: u64, b: u8) -> u64 {
    h := hash ^ cast(u64)b;
    h *= FNV_PRIME;
    return h;
}

fnv1a_u16 :: (hash: u64, v: u16) -> u64 {
    h := fnv1a_byte(hash, cast(u8)(v & 0xFF));
    h = fnv1a_byte(h, cast(u8)((v >> 8) & 0xFF));
    return h;
}

fnv1a_s32 :: (hash: u64, v: s32) -> u64 {
    uv := cast,no_check(u32) v;
    h := fnv1a_byte(hash, cast(u8)(uv & 0xFF));
    h = fnv1a_byte(h, cast(u8)((uv >> 8) & 0xFF));
    h = fnv1a_byte(h, cast(u8)((uv >> 16) & 0xFF));
    h = fnv1a_byte(h, cast(u8)((uv >> 24) & 0xFF));
    return h;
}

fnv1a_u64 :: (hash: u64, v: u64) -> u64 {
    h := hash;
    for i: 0..7 {
        h = fnv1a_byte(h, cast(u8)((v >> (cast(u64)i * 8)) & 0xFF));
    }
    return h;
}

// Hash the full game state for determinism verification
hash_state :: (gs: *GameState) -> u64 {
    h := fnv1a_init();

    // Core state
    h = fnv1a_u64(h, gs.seed);
    h = fnv1a_s32(h, gs.turn);
    h = fnv1a_s32(h, gs.depth);
    h = fnv1a_s32(h, gs.player_x);
    h = fnv1a_s32(h, gs.player_y);

    // All tiles
    tile_count := gs.dungeon.width * gs.dungeon.height;
    for i: 0..tile_count-1 {
        h = fnv1a_byte(h, cast(u8) gs.dungeon.tiles[i]);
    }

    // Door states
    for door: gs.dungeon.doors {
        h = fnv1a_s32(h, door.x);
        h = fnv1a_s32(h, door.y);
        h = fnv1a_byte(h, door.flags);
    }

    // Monster positions
    for mon: gs.dungeon.monsters {
        h = fnv1a_s32(h, mon.x);
        h = fnv1a_s32(h, mon.y);
    }

    // Item positions
    for item: gs.dungeon.items {
        h = fnv1a_s32(h, item.x);
        h = fnv1a_s32(h, item.y);
    }

    return h;
}
