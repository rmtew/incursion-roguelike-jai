# Jon Blow's Parsing Recommendations

Research notes on Jon Blow and Casey Muratori's discussion about parsing approaches.

## Video Source

**"Discussion with Casey Muratori about how easy precedence is..."**
- URL: https://www.youtube.com/watch?v=fIPO4G42wYE
- Date: January 6, 2024
- Duration: ~3 hours
- Transcript: `blow-muratori-parsing.en.srt`

## Key Recommendations

### 1. Use Recursive Descent Parsing

> "Recursive descent parsing... what it actually means is just write code the way you normally would for any other program."

- Don't use parser generators (Yacc, Bison, ANTLR, etc.)
- Write the parser by hand as normal code
- Much simpler and more maintainable
- Better error messages (error reporting is the "user interface of your programming language")

### 2. Avoid the Dragon Book Approach

Jon and Casey strongly criticize traditional compiler textbook approaches:
- LR parser generators are overcomplicated
- "Syntax directed translation" adds unnecessary complexity
- The Dragon Book creates "misconceptions" about parsing difficulty

Jon spent years making toy languages in college using parser generators before realizing handwritten parsers are better.

### 3. Operator Precedence: Use TDOP/Pratt Parsing

Jon used **tree rewriting** for 9 years in Jai before switching to **TDOP (Top-Down Operator Precedence)**, also known as Pratt parsing.

#### The Problem

Given `a + b * c + d`, a naive recursive parser produces the wrong tree:
```
      +
     / \
    a   +
       / \
      b   *
         / \
        c   d
```

But the correct tree (respecting `*` > `+` precedence) is:
```
        +
       / \
      +   d
     / \
    a   *
       / \
      b   c
```

#### Jon's Previous Approach: Tree Rewriting

After building an incorrect tree, check each node:
- If node is `*` and right child is `+` (lower precedence), rewrite the tree
- Works by induction (only need to check one layer at a time)
- "Fix it in post" - easier to write, but adds complexity

#### The Better Approach: Pratt/TDOP Parsing

**Core Algorithm (simplified pseudocode):**

```
parse_expression(min_precedence):
    left = parse_leaf()

    while true:
        op = peek_operator()
        if op.precedence < min_precedence:
            break
        advance()  // consume operator
        right = parse_expression(op.precedence + 1)  // +1 for left-assoc
        left = make_binary(left, op, right)

    return left
```

**Key Insight:** The `min_precedence` parameter controls when to stop recursing:
- When you see an operator with lower precedence, return the subtree
- The caller (at lower precedence) will attach it correctly
- For right-associative operators, don't add +1 to the recursive call

### 4. Handling Associativity

- **Left-associative** (most operators): Use `op.precedence + 1` in recursive call
- **Right-associative** (e.g., exponentiation `^`): Use `op.precedence` in recursive call

Jon: "In my parser I don't think about this rule at all because we have no right associative operator."

### 5. Parameters for Complex Expressions

For real languages, the function signature becomes:
```
parse_expression(left_tree, min_precedence, control_flags)
```

- `left_tree`: The already-parsed left side
- `min_precedence`: Stop when seeing lower precedence
- `control_flags`: Handle special cases (commas, colons, etc.)

### 6. The Simplicity

Jon: "It's so simple it's unbelievable that it's even been a problem for decades... it's so simple it's crazy and if anybody had ever just sat down and said look here's the thing..."

The conversion from tree-rewriting to TDOP took Jon **~6-7 hours** for a full C++ competitor language with complex grammar.

## Good References Mentioned

- Bob Nystrom's article on Pratt parsing: https://journal.stuffwithstuff.com/2011/03/19/pratt-parsers-expression-parsing-made-easy/
- Go's parser (uses similar approach)
- matklad's "Simple but Powerful Pratt Parsing": https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html

## Summary Meme

Jon and Casey created a meme mocking the Dragon Book:
- Dragon wearing shirt: "Complexity of compiler design"
- Knight with "LR Parser Generator" sword and "Syntax Directed Translation" shield
- Hooded figure says: "That's left" (referencing left-associativity)

The joke: Parsing isn't the complicated part of compilers, the rest is.

## Related Algorithms

| Name | Notes |
|------|-------|
| Pratt Parsing | Original 1973 paper by Vaughan Pratt |
| TDOP | Top-Down Operator Precedence (same as Pratt) |
| Precedence Climbing | Similar algorithm, different formulation |
| Shunting Yard | Dijkstra's algorithm, uses explicit stack |

All produce the same output - it's just different ways to implement the mapping.

## Applicability to This Project

### Current Implementation Analysis

**Lexer (`src/resource/lexer.jai`, ~1550 lines):**
- Already handwritten, no generators - matches Jon's recommendation
- Clean character-by-character scanning
- Context-sensitive `brace_level` for code block keyword handling
- Keyword lookup is a linear if-chain (~280 keywords) - simple and works
- Special handling for: dice notation (`d`), crit multipliers (`x2`), resource refs (`$"name"`)

**Parser (`src/resource/parser.jai`, ~4000+ lines):**
- Handwritten recursive descent - exactly what Jon recommends
- Expression parsing uses "precedence as separate functions" pattern:
  ```
  parse_cexpr   -> parse_cexpr2  (handles: |)
  parse_cexpr2  -> parse_cexpr3  (handles: &, +, -)
  parse_cexpr3  -> atoms         (handles: unary, parens, literals)
  ```
- This is the "second best" approach Jon used in Jai for 9 years

### Should We Adopt TDOP?

**No, the current approach is appropriate.** Here's why:

| Factor | Jai (Jon's case) | Our Resource Parser |
|--------|------------------|---------------------|
| Expression complexity | Full C++ competitor | Simple constant math |
| Operator count | Many (all C ops) | Few: `\|`, `&`, `+`, `-` |
| Precedence levels | 15+ levels | 3 levels |
| Associativity issues | Multiple right-assoc | All left-associative |
| Frequent changes | Yes (evolving lang) | No (stable format) |

Jon's trigger for switching to TDOP:
> "I wanted to change some feature in the thing and I had to go deal with this parser thing and it felt a little bit annoying"

Our resource expressions are simple:
```
M_HUMANOID | M_EVIL           // Flag combination
SZ_SMALL + 1                  // Size arithmetic
(LEVEL_1PER1)d8               // Dice with constant
```

**TDOP would be overkill** - we have only 3 precedence levels and rarely change the expression grammar.

### What We Already Do Right

1. **Handwritten recursive descent** - Jon's core recommendation
2. **No parser generators** - Jon explicitly criticizes Yacc/Bison/ANTLR
3. **Good error messages** - `add_error(p, "Expected expression")` with line/column
4. **Clean separation** - lexer handles tokenization, parser handles structure

### Potential Simplifications (if wanted)

1. **Keyword lookup**: Convert linear if-chain to hash table for O(1) lookup
   - Current: ~280 `if lower_str == "..." return ...` lines
   - Would reduce lexer size but may not improve parse speed noticeably

2. **Token types**: We have ~160 token types; could consolidate some keywords
   - e.g., `KW_RED` through `KW_EMERALD` could be one `COLOR` token with value
   - Already partially done with `ATTRIBUTE`, `DIRECTION`, `WEP_TYPE`, `STYPE`

3. **Error recovery**: Currently stops on first error; could add sync points
   - Low priority for resource files (fix one error at a time is fine)

### Conclusion

**The current implementation follows Jon Blow's core philosophy:**
- Handwritten code, no generators
- Simple, readable, maintainable
- "Just write code the way you normally would"

The multi-function precedence pattern (`cexpr` -> `cexpr2` -> `cexpr3`) is exactly what Jon used for nearly a decade. It works well for our simple expression grammar.

**TDOP would be valuable if:**
- We add many more operators (unlikely for resource files)
- We need to frequently modify expression grammar
- Expression parsing becomes "annoying" to modify (Jon's trigger)

Until then, keep the current approach.
