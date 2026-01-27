// Incursion Port - Dice System
// Reconstructed from RECONSTRUCTION-CORE.md
// Note: Random module imported via main.jai

Dice :: struct {
    number: s8;
    sides:  s8;
    bonus:  s8;
}

make_dice :: (num: s8, sides: s8, bonus: s8 = 0) -> Dice {
    d: Dice;
    d.number = num;
    d.sides = sides;
    d.bonus = bonus;
    return d;
}

roll :: (d: Dice) -> s32 {
    total: s32 = d.bonus;
    for i: 0..d.number-1 {
        total += 1 + cast(s32) (random_get() % cast(u64) d.sides);
    }
    return total;
}

average :: (d: Dice) -> s32 {
    return cast(s32) d.number * (cast(s32) d.sides + 1) / 2 + cast(s32) d.bonus;
}

minimum :: (d: Dice) -> s32 {
    return cast(s32) d.number + cast(s32) d.bonus;
}

maximum :: (d: Dice) -> s32 {
    return cast(s32) d.number * cast(s32) d.sides + cast(s32) d.bonus;
}

dice_to_string :: (d: Dice, buffer: [] u8) -> string {
    // Format as "NdS+B" or "NdS-B" or "NdS"
    pos := 0;

    // Number
    if d.number >= 10 {
        buffer[pos] = #char "0" + cast(u8) (d.number / 10);
        pos += 1;
    }
    buffer[pos] = #char "0" + cast(u8) (d.number % 10);
    pos += 1;

    // 'd'
    buffer[pos] = #char "d";
    pos += 1;

    // Sides
    if d.sides >= 100 {
        buffer[pos] = #char "0" + cast(u8) (d.sides / 100);
        pos += 1;
    }
    if d.sides >= 10 {
        buffer[pos] = #char "0" + cast(u8) ((d.sides / 10) % 10);
        pos += 1;
    }
    buffer[pos] = #char "0" + cast(u8) (d.sides % 10);
    pos += 1;

    // Bonus
    if d.bonus > 0 {
        buffer[pos] = #char "+";
        pos += 1;
        if d.bonus >= 10 {
            buffer[pos] = #char "0" + cast(u8) (d.bonus / 10);
            pos += 1;
        }
        buffer[pos] = #char "0" + cast(u8) (d.bonus % 10);
        pos += 1;
    } else if d.bonus < 0 {
        buffer[pos] = #char "-";
        pos += 1;
        b := -d.bonus;
        if b >= 10 {
            buffer[pos] = #char "0" + cast(u8) (b / 10);
            pos += 1;
        }
        buffer[pos] = #char "0" + cast(u8) (b % 10);
        pos += 1;
    }

    result: string;
    result.data = buffer.data;
    result.count = pos;
    return result;
}

parse_dice :: (s: string) -> Dice, bool {
    d: Dice;
    d.number = 1;
    d.sides = 0;
    d.bonus = 0;

    pos := 0;

    // Parse number of dice (optional, defaults to 1)
    num := 0;
    while pos < s.count && s[pos] >= #char "0" && s[pos] <= #char "9" {
        num = num * 10 + cast(s32) (s[pos] - #char "0");
        pos += 1;
    }

    if num > 0 {
        d.number = cast(s8) num;
    }

    // Skip 'd' or 'D'
    if pos >= s.count || (s[pos] != #char "d" && s[pos] != #char "D") {
        return d, false;
    }
    pos += 1;

    // Parse sides
    sides := 0;
    while pos < s.count && s[pos] >= #char "0" && s[pos] <= #char "9" {
        sides = sides * 10 + cast(s32) (s[pos] - #char "0");
        pos += 1;
    }

    if sides == 0 return d, false;
    d.sides = cast(s8) sides;

    // Parse optional bonus
    if pos < s.count {
        negative := false;
        if s[pos] == #char "+" {
            pos += 1;
        } else if s[pos] == #char "-" {
            negative = true;
            pos += 1;
        }

        bonus := 0;
        while pos < s.count && s[pos] >= #char "0" && s[pos] <= #char "9" {
            bonus = bonus * 10 + cast(s32) (s[pos] - #char "0");
            pos += 1;
        }

        if negative {
            d.bonus = cast(s8) (-bonus);
        } else {
            d.bonus = cast(s8) bonus;
        }
    }

    return d, true;
}
