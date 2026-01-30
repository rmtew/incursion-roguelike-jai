// Mersenne Twister MT19937 - Exact match to original Incursion RNG
//
// This implementation matches the MT19937 code in Incursion's Base.cpp
// to ensure identical random sequences given the same seed.

// Period parameters
MT_N :: 624;
MT_M :: 397;
MT_MATRIX_A   : u32 : 0x9908b0df;  // constant vector a
MT_UPPER_MASK : u32 : 0x80000000;  // most significant w-r bits
MT_LOWER_MASK : u32 : 0x7fffffff;  // least significant r bits

// Mersenne Twister state
MT19937 :: struct {
    mt: [MT_N] u32;  // state vector
    mti: s32;        // index into state vector (mti==N+1 means uninitialized)
}

// Initialize MT with a seed (matches init_genrand)
mt_seed :: (state: *MT19937, seed: u32) {
    state.mt[0] = seed & 0xffffffff;
    for mti: 1..MT_N-1 {
        state.mt[mti] = (1812433253 * (state.mt[mti-1] ^ (state.mt[mti-1] >> 30)) + cast(u32)mti);
        state.mt[mti] &= 0xffffffff;
    }
    state.mti = MT_N;
}

// Generate a random u32 on [0, 0xffffffff] (matches genrand_int32)
mt_genrand_u32 :: (state: *MT19937) -> u32 {
    mag01: [2] u32 = .[0, MT_MATRIX_A];

    if state.mti >= MT_N {
        // Generate N words at one time
        if state.mti == MT_N + 1 {
            // Not seeded, use default seed
            mt_seed(state, 5489);
        }

        for kk: 0..MT_N-MT_M-1 {
            y := (state.mt[kk] & MT_UPPER_MASK) | (state.mt[kk+1] & MT_LOWER_MASK);
            state.mt[kk] = state.mt[kk + MT_M] ^ (y >> 1) ^ mag01[y & 1];
        }
        for kk: MT_N-MT_M..MT_N-2 {
            y := (state.mt[kk] & MT_UPPER_MASK) | (state.mt[kk+1] & MT_LOWER_MASK);
            state.mt[kk] = state.mt[kk + (MT_M - MT_N)] ^ (y >> 1) ^ mag01[y & 1];
        }
        y := (state.mt[MT_N-1] & MT_UPPER_MASK) | (state.mt[0] & MT_LOWER_MASK);
        state.mt[MT_N-1] = state.mt[MT_M-1] ^ (y >> 1) ^ mag01[y & 1];

        state.mti = 0;
    }

    y := state.mt[state.mti];
    state.mti += 1;

    // Tempering
    y ^= (y >> 11);
    y ^= (y << 7) & 0x9d2c5680;
    y ^= (y << 15) & 0xefc60000;
    y ^= (y >> 18);

    return y;
}

// Incursion's random(max) function - returns [0, max-1]
mt_random :: (state: *MT19937, max: s32) -> s32 {
    if max <= 0 return 0;
    return cast(s32)(mt_genrand_u32(state) % cast(u32)max);
}

// Global RNG state for original-compatible mode
global_mt: MT19937;
global_mt_initialized := false;

// Debug: count total calls to random() for crash reproduction
global_rng_call_count: s64 = 0;

// Initialize global MT with seed
random_init :: (seed: u32) {
    mt_seed(*global_mt, seed);
    global_mt_initialized = true;
    global_rng_call_count = 0;
}

// Global random function matching Incursion's random()
random :: (max: s32) -> s32 {
    if !global_mt_initialized {
        mt_seed(*global_mt, 5489);  // Default seed
        global_mt_initialized = true;
    }
    global_rng_call_count += 1;
    return mt_random(*global_mt, max);
}

// Generator mode (only ORIGINAL is supported - kept for API compatibility)
GeneratorMode :: enum {
    ORIGINAL;   // Exact Incursion replication (MT19937, MakeLev algorithm)
}
