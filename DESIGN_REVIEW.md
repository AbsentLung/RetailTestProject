# Design Review

A review log for `DESIGN_PROPOSAL.md`, the same way `REVIEWED_PROPOSAL.md` is for `FINAL_PROPOSAL.md`: what was raised, checked against the real app, and revised or pushed back on.

## Round 1 — Doesn't a small GET per scroll mean infinite scroll just isn't slow?

**What was raised:** `DESIGN_PROPOSAL.md`'s infinite-scroll section warned that `LIMIT 50 OFFSET N` gets slower the deeper a page is, and that infinite scroll makes deep offsets the common case. The question: if each request is still just fetching 50 rows, wouldn't a properly-implemented GET-per-scroll be fast regardless of depth?

**Verifying it against the actual data.** Measured real query time at four offsets against the actual 31,447-row `alerts` table, using the exact `ORDER BY triggered_at DESC, id DESC` the real pagination uses, 5 runs each after warming the cache:

| Offset | Avg query time |
|---|---|
| 0 (first page) | ~4.9ms |
| 5,000 | ~6.3ms |
| 15,000 | ~9.7ms |
| 31,350 (last page) | ~7.9ms |

**The correction.** The original framing was right in shape but imprecise about magnitude, and that's worth being honest about rather than leaving as a vague "this will be slow." At today's actual scale, it isn't - single-digit milliseconds across the entire table, roughly 2x slower at the deepest offset than the shallowest, completely imperceptible to someone scrolling. The question's intuition is correct: a well-implemented GET-per-scroll is not inherently slow, and nothing here contradicts that.

What the measurement does confirm is the shape of the underlying claim, just not its urgency: the cost genuinely grows with offset depth (it isn't flat), and infinite scroll genuinely does change which depths get reached in practice - nobody manually clicks "next" 600 times with numbered pagination, but removing that friction makes deep scrolling routine instead of rare. That's a real mechanism, just not one that bites at 31,447 rows. It bites at 100x this app's data, where the same growing curve lands at offsets in the millions rather than the tens of thousands - the point `DESIGN_PROPOSAL.md`'s recommendation (build on keyset pagination from the start) was always actually about, not today's scale.

**Kept as written in `DESIGN_PROPOSAL.md`, clarified here instead of there.** The recommendation itself doesn't change - keyset pagination is still the right call if infinite scroll gets built, because its cost doesn't grow with depth at all, which is a strictly better property regardless of whether today's scale happens to make the alternative's cost small too. What changes is being precise about *why*: not "this will visibly slow the app down now," but "this is a cost that scales with a usage pattern infinite scroll specifically encourages, and the fix is nearly free to build correctly from the start versus retrofitting later."

## Round 2 — Why not Elasticsearch for search?

**What was raised:** `DESIGN_PROPOSAL.md` names `pg_trgm` as the fix for name search at 100x scale. The question: why not Elasticsearch instead?

**The case for it, stated fairly.** Elasticsearch is a genuinely stronger tool for a certain kind of search problem - relevance ranking, typo tolerance, faceted search, full-text matching across long prose, usually at large document counts. None of that is a strawman; it's real capability `pg_trgm` doesn't have.

**Why it doesn't fit this project specifically:**

- **The actual problem is smaller than the tool.** This app's search need is "find a product, store, or brand by part of its name" - short string fields, at most tens of thousands of rows even at 100x today's scale. `pg_trgm` (substring similarity on short fields) matches that problem directly; Elasticsearch is sized for a bigger one.
- **It's infrastructure, not a library.** `pg_trgm` is `CREATE EXTENSION pg_trgm` - no new service to run, monitor, back up, or pay for. Elasticsearch means operating a second system alongside Postgres.
- **It has the same sync problem already named for `counter_cache`, and it's worse.** An Elasticsearch index needs to stay in sync with Postgres, normally via save callbacks. This app's import performance is built on `insert_all`, which skips callbacks entirely - a bulk CSV import wouldn't update an Elasticsearch index automatically, so this would need an explicit reindex step bolted onto the importer, on top of running the second system in the first place. Compounding cost, not a free upgrade.
- **Even Postgres's own full-text search (`tsvector`) is worth ruling out separately, for a different reason.** It's better than trigram for ranked multi-word matching, but worse for the real use case here: typing a partial name ("chocol" -> "Chocolate Frogs") is a substring-similarity problem, which trigram handles and `tsvector` doesn't do as naturally.

**Declined, documented rather than dropped.** Not "Elasticsearch is bad" - "Elasticsearch is proportionate to a search problem bigger than the one this app actually has." Kept out of `DESIGN_PROPOSAL.md` itself; recorded here as a real alternative that was considered and why.
