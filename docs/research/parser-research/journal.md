# Parser Research Journal

## 2026-01-28: Initial Research

### What was done
- Searched for Jon Blow's parsing recommendations
- Found and downloaded transcript from YouTube video: "Discussion with Casey Muratori about how easy precedence is..." (https://www.youtube.com/watch?v=fIPO4G42wYE)
- Created `notes.md` with key takeaways

### Key findings

1. **Handwritten recursive descent > Parser generators**
   - Jon strongly recommends against Yacc/Bison/ANTLR
   - "Just write code the way you normally would"
   - Better error messages, easier to maintain

2. **For operator precedence, use Pratt/TDOP parsing**
   - Jon used tree-rewriting for 9 years before switching
   - TDOP is simpler and cleaner
   - Core idea: pass `min_precedence` parameter, stop recursing when you hit a lower-precedence operator

3. **The algorithm is simple**
   - Jon converted Jai's full parser in ~6-7 hours
   - The complexity is overstated in traditional CS education

### Transcript file
- `blow-muratori-parsing.en.srt` - Full auto-generated transcript (~18K lines in SRT format)

### Next steps
- [x] Review transcript for specific code examples Jon showed
- [x] Compare with our current `parser.jai` implementation
- [x] Consider if TDOP would simplify our expression parsing

---

## 2026-01-28: Reconciliation with Current Code

### Analysis performed

Read and analyzed:
- `src/resource/lexer.jai` (~1550 lines)
- `src/resource/parser.jai` (~4000+ lines, read expression parsing section)

### Current approach

**Lexer:**
- Handwritten token-by-token scanning
- Context-sensitive keyword handling via `brace_level`
- Linear if-chain for keyword lookup (~280 keywords)
- Special tokens: `DICE_D`, `CRIT_MULT`, `RES_REF`, `MAPAREA`

**Parser:**
- Handwritten recursive descent
- Expression precedence via stacked functions:
  - `parse_cexpr` (lowest: `|`)
  - `parse_cexpr2` (`&`, `+`, `-`)
  - `parse_cexpr3` (highest: unary, atoms)

### Verdict: Current approach is correct

**We already follow Jon Blow's core recommendations:**
1. Handwritten code - no parser generators
2. Recursive descent - "just write code"
3. Good error messages with line/column

**TDOP is not needed because:**
- Only 3 precedence levels (vs 15+ in Jai)
- Simple operators: `|`, `&`, `+`, `-`
- Stable grammar (resource files don't evolve like a language)

**Jon's approach for 9 years** was exactly what we have - precedence via separate functions. He only switched to TDOP when the language grew complex and changes became "annoying."

### Potential future simplifications

1. Hash table for keyword lookup (currently O(n) linear scan)
2. Consolidate color keywords to single token type with value
3. Add error recovery with sync points (low priority)

### Conclusion

No changes needed. The current implementation is well-aligned with Jon Blow's philosophy. Keep it simple.
