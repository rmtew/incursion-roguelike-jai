// Incursion Port - Test Framework and Tests
// Reconstructed from RECONSTRUCTION.md
// Note: Basic module imported via main.jai

// Test state
test_count: s32;
test_passed: s32;
test_failed: s32;
current_section: string;

test_section :: (name: string) {
    current_section = name;
    print("\n=== % ===\n", name);
}

test_assert :: (condition: bool, name: string) {
    test_count += 1;
    if condition {
        test_passed += 1;
    } else {
        test_failed += 1;
        print("  FAIL: % (in %)\n", name, current_section);
    }
}

test_assert_eq :: (actual: $T, expected: T, name: string) {
    test_count += 1;
    if actual == expected {
        test_passed += 1;
    } else {
        test_failed += 1;
        print("  FAIL: % (in %)\n", name, current_section);
        print("    Expected: %\n", expected);
        print("    Actual:   %\n", actual);
    }
}

// Note: Use == for string comparison (Jai compares content)

test_summary :: () {
    print("\n========================================\n");
    print("Tests: %  Passed: %  Failed: %\n", test_count, test_passed, test_failed);
    if test_failed == 0 {
        print("ALL TESTS PASSED!\n");
    } else {
        print("SOME TESTS FAILED\n");
    }
    print("========================================\n");
}

// Run all tests
run_all_tests :: () {
    test_count = 0;
    test_passed = 0;
    test_failed = 0;

    test_dice();
    test_glyph();
    test_direction();
    test_registry();
    test_object();
    test_map();
    test_creature();
    test_item();
    test_feature();
    test_vision();
    test_event();
    test_constants();
    test_lexer();
    test_parser();
    test_real_irh_files();

    test_summary();
}

// Dice tests
test_dice :: () {
    test_section("Dice Tests");

    // make_dice
    {
        d := make_dice(2, 6, 3);
        test_assert_eq(d.number, 2, "make_dice number");
        test_assert_eq(d.sides, 6, "make_dice sides");
        test_assert_eq(d.bonus, 3, "make_dice bonus");
    }

    // minimum
    {
        d := make_dice(2, 6, 3);
        test_assert_eq(minimum(d), 5, "minimum 2d6+3");
    }

    // maximum
    {
        d := make_dice(2, 6, 3);
        test_assert_eq(maximum(d), 15, "maximum 2d6+3");
    }

    // average
    {
        d := make_dice(2, 6, 0);
        test_assert_eq(average(d), 7, "average 2d6");
    }

    // parse_dice
    {
        d, ok := parse_dice("2d6+3");
        test_assert(ok, "parse_dice 2d6+3 ok");
        test_assert_eq(d.number, 2, "parse_dice number");
        test_assert_eq(d.sides, 6, "parse_dice sides");
        test_assert_eq(d.bonus, 3, "parse_dice bonus");
    }

    // parse_dice negative bonus
    {
        d, ok := parse_dice("1d8-2");
        test_assert(ok, "parse_dice 1d8-2 ok");
        test_assert_eq(d.number, 1, "parse_dice neg number");
        test_assert_eq(d.sides, 8, "parse_dice neg sides");
        test_assert_eq(d.bonus, -2, "parse_dice neg bonus");
    }

    // dice_to_string
    {
        d := make_dice(2, 6, 3);
        buffer: [32] u8;
        s := dice_to_string(d, buffer);
        test_assert(s == "2d6+3", "dice_to_string 2d6+3");
    }
}

// Glyph tests
test_glyph :: () {
    test_section("Glyph Tests");

    // make_glyph - use literal values to test the function
    {
        g := make_glyph(#char "@", 15, 0);  // WHITE=15, BLACK=0
        test_assert_eq(glyph_char(g), #char "@", "glyph char");
        test_assert_eq(glyph_fg(g), 15, "glyph fg");
        test_assert_eq(glyph_bg(g), 0, "glyph bg");
    }

    // make_glyph with default bg
    {
        g := make_glyph(#char "g", 2);  // GREEN=2
        test_assert_eq(glyph_char(g), #char "g", "glyph char default bg");
        test_assert_eq(glyph_fg(g), 2, "glyph fg default bg");
        test_assert_eq(glyph_bg(g), 0, "glyph bg default");
    }
}

// Direction tests
test_direction :: () {
    test_section("Direction Tests");

    test_assert_eq(DirX(.NORTH), 0, "DirX NORTH");
    test_assert_eq(DirY(.NORTH), -1, "DirY NORTH");
    test_assert_eq(DirX(.EAST), 1, "DirX EAST");
    test_assert_eq(DirY(.EAST), 0, "DirY EAST");
    test_assert_eq(DirX(.SOUTHWEST), -1, "DirX SOUTHWEST");
    test_assert_eq(DirY(.SOUTHWEST), 1, "DirY SOUTHWEST");
}

// Registry tests
test_registry :: () {
    test_section("Registry Tests");

    registry_init();

    // Register and retrieve
    {
        t: Thing;
        thing_init(*t);
        h := registry_register(*t);
        test_assert(h != NULL_OBJ, "registry_register returns valid handle");

        got := registry_get(h);
        test_assert(got == *t, "registry_get returns same object");
    }

    // NULL handle
    {
        got := registry_get(NULL_OBJ);
        test_assert(got == null, "registry_get NULL_OBJ returns null");
    }

    registry_clear();
}

// Object tests
test_object :: () {
    test_section("Object Tests");

    // Thing init
    {
        t: Thing;
        thing_init(*t);
        test_assert_eq(t.myHandle, NULL_OBJ, "thing_init handle");
        test_assert(t.stati == null, "thing_init stati null");
    }

    // Stati add/has/get
    {
        t: Thing;
        thing_init(*t);

        test_assert(!thing_has_stati(*t, 1), "no stati initially");

        thing_add_stati(*t, 1, 10, 5);
        test_assert(thing_has_stati(*t, 1), "has stati after add");

        s := thing_get_stati(*t, 1);
        test_assert(s != null, "get stati not null");
        test_assert_eq(s.val, 10, "stati val");
        test_assert_eq(s.mag, 5, "stati mag");

        thing_remove_stati(*t, 1);
        test_assert(!thing_has_stati(*t, 1), "no stati after remove");

        thing_free_stati(*t);
    }
}

// Map tests
test_map :: () {
    test_section("Map Tests");

    m: Map;
    map_init(*m, 10, 10);

    test_assert_eq(m.width, 10, "map width");
    test_assert_eq(m.height, 10, "map height");

    // in_bounds
    test_assert(map_in_bounds(*m, 0, 0), "in_bounds 0,0");
    test_assert(map_in_bounds(*m, 9, 9), "in_bounds 9,9");
    test_assert(!map_in_bounds(*m, -1, 0), "out of bounds -1,0");
    test_assert(!map_in_bounds(*m, 10, 5), "out of bounds 10,5");

    // map_at
    loc := map_at(*m, 5, 5);
    test_assert(loc != null, "map_at returns location");
    test_assert_eq(loc.terrain, NULL_ID, "initial terrain");

    // set_terrain
    map_set_terrain(*m, 5, 5, 42);
    loc2 := map_at(*m, 5, 5);
    test_assert_eq(loc2.terrain, 42, "terrain after set");

    map_free(*m);
}

// Creature tests
test_creature :: () {
    test_section("Creature Tests");

    c: Creature;
    creature_init(*c);

    test_assert_eq(c.hp, 10, "initial hp");
    test_assert_eq(c.max_hp, 10, "initial max_hp");
    test_assert(creature_is_alive(*c), "initially alive");

    creature_take_damage(*c, 5);
    test_assert_eq(c.hp, 5, "hp after damage");

    creature_heal(*c, 3);
    test_assert_eq(c.hp, 8, "hp after heal");

    creature_heal(*c, 100);
    test_assert_eq(c.hp, 10, "hp capped at max");
}

// Item tests
test_item :: () {
    test_section("Item Tests");

    i: Item;
    item_init(*i);

    test_assert_eq(i.plus, 0, "initial plus");
    test_assert(!item_is_masterwork(*i), "not masterwork initially");
    test_assert(!item_is_magic(*i), "not magic initially");

    i.plus = 1;
    test_assert(item_is_masterwork(*i), "masterwork at +1");
    test_assert(!item_is_magic(*i), "not magic at +1");

    i.plus = 2;
    test_assert(item_is_masterwork(*i), "masterwork at +2");
    test_assert(item_is_magic(*i), "magic at +2");

    // Qualities
    test_assert(!item_has_quality(*i, 3), "no quality initially");
    item_add_quality(*i, 3);
    test_assert(item_has_quality(*i, 3), "has quality after add");
    item_remove_quality(*i, 3);
    test_assert(!item_has_quality(*i, 3), "no quality after remove");
}

// Feature tests
test_feature :: () {
    test_section("Feature Tests");

    // Door
    {
        d: Door;
        door_init(*d);
        test_assert(feature_is_solid(*d.feature), "door initially solid");
        test_assert(feature_is_opaque(*d.feature), "door initially opaque");
        test_assert(!door_is_open(*d), "door initially closed");

        door_open(*d);
        test_assert(door_is_open(*d), "door open after open");
        test_assert(!feature_is_solid(*d.feature), "door not solid when open");

        door_close(*d);
        test_assert(!door_is_open(*d), "door closed after close");
        test_assert(feature_is_solid(*d.feature), "door solid when closed");

        door_lock(*d);
        test_assert(door_is_locked(*d), "door locked");
        door_unlock(*d);
        test_assert(!door_is_locked(*d), "door unlocked");
    }

    // Trap
    {
        t: Trap;
        trap_init(*t);
        test_assert(trap_is_hidden(*t), "trap initially hidden");
        test_assert(!trap_is_disarmed(*t), "trap not disarmed");

        trap_reveal(*t);
        test_assert(!trap_is_hidden(*t), "trap revealed");

        triggered := trap_trigger(*t);
        test_assert(triggered, "trap triggers");

        trap_disarm(*t);
        test_assert(trap_is_disarmed(*t), "trap disarmed");
        triggered2 := trap_trigger(*t);
        test_assert(!triggered2, "disarmed trap doesn't trigger");
    }

    // Portal
    {
        p: Portal;
        portal_init(*p);
        test_assert(!portal_is_stairs(*p), "portal not stairs initially");

        p.portal_type = POR_DOWN_STAIR;
        test_assert(portal_is_stairs(*p), "down stair is stairs");
        test_assert(portal_is_down(*p), "down stair is down");
        test_assert(!portal_is_up(*p), "down stair is not up");
    }
}

// Vision tests
test_vision :: () {
    test_section("Vision Tests");

    // Distance functions
    test_assert_eq(chebyshev_distance(0, 0, 3, 4), 4, "chebyshev 0,0 to 3,4");
    test_assert_eq(chebyshev_distance(0, 0, 5, 0), 5, "chebyshev horizontal");
    test_assert_eq(manhattan_distance(0, 0, 3, 4), 7, "manhattan 0,0 to 3,4");
    test_assert_eq(euclidean_dist_squared(0, 0, 3, 4), 25, "euclidean squared 3,4");

    // Direction
    test_assert_eq(direction_to(0, 0, 1, 0), Dir.EAST, "direction east");
    test_assert_eq(direction_to(0, 0, 0, -1), Dir.NORTH, "direction north");
    test_assert_eq(direction_to(0, 0, 1, 1), Dir.SOUTHEAST, "direction southeast");

    // Opposite
    test_assert_eq(opposite_dir(.NORTH), Dir.SOUTH, "opposite north");
    test_assert_eq(opposite_dir(.EAST), Dir.WEST, "opposite east");
}

// Event tests
test_event :: () {
    test_section("Event Tests");

    e: Event;
    event_init(*e);
    test_assert_eq(e.etype, EventType.EV_NONE, "initial event type");
    test_assert_eq(e.actor, NULL_OBJ, "initial actor");

    e2 := make_attack_event(1, 2);
    test_assert_eq(e2.etype, EventType.EV_ATTACK, "attack event type");
    test_assert_eq(e2.actor, 1, "attack actor");
    test_assert_eq(e2.target, 2, "attack target");
}

// Constants tests
test_constants :: () {
    test_section("Constants Tests");

    // Basic lookup
    {
        val, found := lookup_resource_constant("NORTH");
        test_assert(found, "NORTH found");
        test_assert_eq(val, 0, "NORTH value");
    }

    {
        val, found := lookup_resource_constant("SOUTH");
        test_assert(found, "SOUTH found");
        test_assert_eq(val, 1, "SOUTH value");
    }

    // Not found
    {
        _, found := lookup_resource_constant("NOT_A_CONSTANT");
        test_assert(!found, "NOT_A_CONSTANT not found");
    }

    // Some type constants
    {
        val, found := lookup_resource_constant("T_WEAPON");
        test_assert(found, "T_WEAPON found");
    }
}

// Lexer tests
test_lexer :: () {
    test_section("Lexer Tests");

    // Simple tokens
    {
        source := "Monster";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.KW_MONSTER, "Monster keyword");
    }

    // Number
    {
        source := "42";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.NUMBER, "number type");
        test_assert_eq(tok.int_value, 42, "number value");
    }

    // Hex number
    {
        source := "0xFF";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.NUMBER, "hex type");
        test_assert_eq(tok.int_value, 255, "hex value");
    }

    // String
    {
        source := "\"hello\"";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.STRING, "string type");
    }

    // Dice notation
    {
        source := "2d6";
        lex := lexer_init(source);
        tok1 := lexer_next_token(*lex);
        test_assert_eq(tok1.type, TokenType.NUMBER, "dice number");
        tok2 := lexer_next_token(*lex);
        test_assert_eq(tok2.type, TokenType.DICE_D, "dice d");
        tok3 := lexer_next_token(*lex);
        test_assert_eq(tok3.type, TokenType.NUMBER, "dice sides");
    }

    // Resource reference
    {
        source := "$\"goblin\"";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.RES_REF, "res ref type");
    }

    // Critical multiplier
    {
        source := "x3";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.CRIT_MULT, "crit mult type");
        test_assert_eq(tok.int_value, 3, "crit mult value");
    }

    // Percent
    {
        source := "100%";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.PERCENT, "percent type");
        test_assert_eq(tok.int_value, 100, "percent value");
    }

    // Operators
    {
        source := "| + - { }";
        lex := lexer_init(source);
        tok1 := lexer_next_token(*lex);
        test_assert_eq(tok1.type, TokenType.PIPE, "pipe");
        tok2 := lexer_next_token(*lex);
        test_assert_eq(tok2.type, TokenType.PLUS, "plus");
        tok3 := lexer_next_token(*lex);
        test_assert_eq(tok3.type, TokenType.MINUS, "minus");
        tok4 := lexer_next_token(*lex);
        test_assert_eq(tok4.type, TokenType.LBRACE, "lbrace");
        tok5 := lexer_next_token(*lex);
        test_assert_eq(tok5.type, TokenType.RBRACE, "rbrace");
    }

    // Color keywords
    {
        source := "bright blue";
        lex := lexer_init(source);
        tok1 := lexer_next_token(*lex);
        test_assert_eq(tok1.type, TokenType.KW_BRIGHT, "bright");
        tok2 := lexer_next_token(*lex);
        test_assert_eq(tok2.type, TokenType.KW_BLUE, "blue");
    }

    // Comments
    {
        source := "// comment\n42";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.NUMBER, "after line comment");
    }

    // Block comments
    {
        source := "/* comment */ 42";
        lex := lexer_init(source);
        tok := lexer_next_token(*lex);
        test_assert_eq(tok.type, TokenType.NUMBER, "after block comment");
    }
}

// Parser tests - simplified to avoid memory issues
test_parser :: () {
    test_section("Parser Tests");

    // Simple terrain (minimal test)
    {
        source := #string END
Terrain "floor" {
    Image: grey '.';
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse terrain ok");
        test_assert_eq(p.terrains.count, 1, "one terrain parsed");
    }

    // Class with hitdice
    {
        source := #string END
Class "fighter" {
    HitDice: 10;
    Def: 1/1;
    Mana: 0;
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse class ok");
        test_assert_eq(p.classes.count, 1, "one class parsed");
    }

    // Template
    {
        source := #string END
Template "hatchling" : TM_AGECAT for MA_DRAGON {
    Desc: "Young dragons.";
    CR: +0;
    Size: -4;
    Power: +1;
    Flags: TMF_OBVIOUS, TMF_NOGEN;
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse template ok");
        test_assert_eq(p.templates.count, 1, "one template parsed");
        test_assert(p.templates[0].has_for, "template has for clause");
        test_assert(p.templates[0].has_cr, "template has cr");
        test_assert_eq(p.templates[0].cr, 0, "template cr is 0");
    }

    // Region
    {
        source := #string END
Region "Underground River" : RF_RIVER {
    Floor: $"shallow water";
    Depth: 3;
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse region ok");
        test_assert_eq(p.regions.count, 1, "one region parsed");
        test_assert(p.regions[0].has_floor, "region has floor");
        test_assert(p.regions[0].has_depth, "region has depth");
    }

    // Encounter
    {
        source := #string END
Encounter "goblin warband" {
    Weight: 40;
    CR: 1-10;
    Flags: NF_UNIFORM;
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse encounter ok");
        test_assert_eq(p.encounters.count, 1, "one encounter parsed");
        test_assert(p.encounters[0].has_weight, "encounter has weight");
        test_assert_eq(p.encounters[0].weight, 40, "encounter weight is 40");
        test_assert(p.encounters[0].has_cr, "encounter has cr");
        test_assert_eq(p.encounters[0].cr_min, 1, "encounter cr min is 1");
        test_assert_eq(p.encounters[0].cr_max, 10, "encounter cr max is 10");
    }

    // Domain
    {
        source := #string END
Domain "Fire" : 0 {
    Desc: "The domain of fire.";
    Spells: $"burning hands", $"fireball";
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse domain ok");
        test_assert_eq(p.domains.count, 1, "one domain parsed");
        test_assert(p.domains[0].has_desc, "domain has desc");
        test_assert_eq(p.domains[0].spells.count, 2, "domain has 2 spells");
    }

    // God
    {
        source := #string END
God "Aiswin" {
    Domains: $"Fate", $"Knowledge", $"Night";
    Desc: "God of Secrets.";
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse god ok");
        test_assert_eq(p.gods.count, 1, "one god parsed");
        test_assert_eq(p.gods[0].domains.count, 3, "god has 3 domains");
        test_assert(p.gods[0].has_desc, "god has desc");
    }

    // Text
    {
        source := #string END
Text "help::intro" {
    "Welcome to Incursion!";
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse text ok");
        test_assert_eq(p.texts.count, 1, "one text parsed");
    }

    // Dungeon
    {
        source := #string END
Dungeon "The Goblin Caves" {
    Desc: "The goblin caves.";
    Constants:
        * DUN_DEPTH 10;
    Specials:
        * $"entry chamber" at level 1,
        * $"ancient library" at level 2;
}
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);
        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse dungeon ok");
        test_assert_eq(p.dungeons.count, 1, "one dungeon parsed");
        test_assert(p.dungeons[0].has_desc, "dungeon has desc");
        test_assert_eq(p.dungeons[0].specials.count, 2, "dungeon has 2 specials");
    }

    // Multiple domains with various grant types (from domains.irh)
    {
        source := #string END
Domain "Domination" : 0
  {
    Desc: "Test domain";
    Grants:
      Ability[CA_COMMAND_AUTHORITY,+1] at every 4th level starting at 4th,
      Feat[FT_SCHOOL_FOCUS,SC_ENC] at 1st level;
  }
Domain "Earth" : 0
  {
    Desc: "Test domain";
    Grants:
      Ability[CA_COMMAND,MA_EARTH] at 1st level,
      Stati[SAVE_BONUS,SN_PETRI,+1] at every level starting at 1st,
      Stati[IMMUNITY,AD_STON] at 7th level;
  }
END;
        lex := lexer_init(source);
        tokens := lexer_tokenize_all(*lex);

        p := parser_init(tokens);
        ok := parser_parse(*p);
        test_assert(ok, "parse domains with multiple grants ok");
    }
}

// Test parsing real .irh files from the original Incursion source
// NOTE: These tests require access to the original Incursion source code.
// They will be skipped if the files are not found at the expected path.
// To run these tests, set IRH_PATH to your local Incursion source lib/ directory.
test_real_irh_files :: () {
    test_section("Real IRH File Tests");

    // Local path to original Incursion source - adjust for your system
    IRH_PATH :: "C:/Data/R/roguelike - incursion/repo-work/lib/";

    // Test flavors.irh - simple Flavour resources
    test_irh_file(IRH_PATH, "flavors.irh", "flavors");

    // Test mundane.irh - basic items
    test_irh_file(IRH_PATH, "mundane.irh", "mundane");

    // Test domains.irh - god domains
    test_irh_file(IRH_PATH, "domains.irh", "domains");

    // Test weapons.irh - weapon items
    test_irh_file(IRH_PATH, "weapons.irh", "weapons");

    // Test enclist.irh - encounter lists
    test_irh_file(IRH_PATH, "enclist.irh", "enclist");

    // Test dungeon.irh - dungeons, regions, terrains, features
    // This tests the new weighted selection parsing (Lists, RoomTypes, Walls, Door, Flags)
    test_irh_file(IRH_PATH, "dungeon.irh", "dungeon");
}

test_irh_file :: (path: string, filename: string, label: string) {
    full_path := tprint("%1%2", path, filename);
    content, success := read_entire_file(full_path);

    if !success {
        print("  SKIP: Could not read % (file not found)\n", filename);
        return;
    }

    lex := lexer_init(content);
    tokens := lexer_tokenize_all(*lex);

    p := parser_init(tokens);
    ok := parser_parse(*p);

    if ok && p.errors.count == 0 {
        test_assert(true, tprint("% parsed successfully", label));
        // Print stats
        total := p.flavors.count + p.items.count + p.monsters.count +
                 p.effects.count + p.features.count + p.terrains.count +
                 p.races.count + p.classes.count + p.templates.count +
                 p.regions.count + p.encounters.count + p.domains.count +
                 p.gods.count + p.texts.count + p.dungeons.count + p.artifacts.count;
        print("    Parsed % resources from %\n", total, filename);
        if p.flavors.count > 0    print("      Flavors: %\n", p.flavors.count);
        if p.items.count > 0      print("      Items: %\n", p.items.count);
        if p.monsters.count > 0   print("      Monsters: %\n", p.monsters.count);
        if p.effects.count > 0    print("      Effects: %\n", p.effects.count);
        if p.features.count > 0   print("      Features: %\n", p.features.count);
        if p.terrains.count > 0   print("      Terrains: %\n", p.terrains.count);
        if p.races.count > 0      print("      Races: %\n", p.races.count);
        if p.classes.count > 0    print("      Classes: %\n", p.classes.count);
        if p.templates.count > 0  print("      Templates: %\n", p.templates.count);
        if p.regions.count > 0    print("      Regions: %\n", p.regions.count);
        if p.encounters.count > 0 print("      Encounters: %\n", p.encounters.count);
        if p.domains.count > 0    print("      Domains: %\n", p.domains.count);
        if p.gods.count > 0       print("      Gods: %\n", p.gods.count);
        if p.texts.count > 0      print("      Texts: %\n", p.texts.count);
        if p.dungeons.count > 0   print("      Dungeons: %\n", p.dungeons.count);
        if p.artifacts.count > 0  print("      Artifacts: %\n", p.artifacts.count);
    } else {
        test_assert(false, tprint("% parsed with errors", label));
        // Print stats even on failure to see what was parsed
        total := p.flavors.count + p.items.count + p.monsters.count +
                 p.effects.count + p.features.count + p.terrains.count +
                 p.races.count + p.classes.count + p.templates.count +
                 p.regions.count + p.encounters.count + p.domains.count +
                 p.gods.count + p.texts.count + p.dungeons.count + p.artifacts.count;
        if total > 0 {
            print("    (Partially parsed % resources)\n", total);
            if p.dungeons.count > 0   print("      Dungeons: %\n", p.dungeons.count);
            if p.regions.count > 0    print("      Regions: %\n", p.regions.count);
            if p.terrains.count > 0   print("      Terrains: %\n", p.terrains.count);
            if p.features.count > 0   print("      Features: %\n", p.features.count);
        }
        // Print first few errors
        max_errors := min(p.errors.count, 10);
        for i: 0..max_errors-1 {
            err := p.errors[i];
            print("    Error at line %, col %: %\n", err.line, err.column, err.message);
        }
        if p.errors.count > 10 {
            print("    ... and % more errors\n", p.errors.count - 10);
        }
    }
}
