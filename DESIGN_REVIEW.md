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

## Round 3 — A structured review, answered item by item

A second review pass on `DESIGN_PROPOSAL.md` as it stood after round 2, with specific corrections. Unlike rounds 1-2, these changed `DESIGN_PROPOSAL.md` itself rather than just being clarified here, since several were real inaccuracies in the document, not just imprecision worth a footnote.

**F1. "SQL injection" was the wrong description of the `%`/`_` wildcard risk.** Confirmed and fixed. The search example already bound the value (`WHERE name ILIKE ?`), so unescaped `%`/`_` in a user's search term was never an injection risk - a bound parameter can't break out of the query structure regardless of its contents. What it actually causes is a correctness bug: a literal `50%` in the search box gets its own `%` read as a wildcard inside the pattern, matching anything starting with `50`. `sanitize_sql_like` is still the right fix, now described for the right reason.

**F2. Sorting by a computed count doesn't "reuse" the existing display query - it replaces two queries with one.** Confirmed and fixed. Checked the real `ProductsController#index`: it runs the paginated product query and `TrackingEvent.group(:product_id).count` as two separate statements, the second producing a Ruby hash the view looks up by id, not an orderable column on any row. Sorting by that count means writing a genuinely different query (a join, grouped, with the count selected and orderable) - new code, even though it needs no new storage and the aggregate cost is comparable to what's already being paid today in a different shape. The original wording ("reuses the exact aggregate query... just reordered") overstated how free this is.

**F3. The tracking-event/price-history keyset index claim was imprecise.** Confirmed and fixed. Checked the real schema: `tracking_events` has `(store_id, event_time)` and `(product_id, event_time)`, neither including `id`. A keyset cursor on `(event_time, id)` needs `id` as a third column to be a single fully-ordered index scan - without it, rows sharing the exact same `event_time` need an extra sort step for the tiebreak. The existing 2-column indexes get the scan most of the way there (they're not useless), but "no new index needed" was too strong; the precise fix is `id` added as a trailing column to each.

**F4. Sorting and keyset infinite scroll shouldn't be combined.** Agreed, and added as new guidance rather than a correction to an existing claim. Every sortable column needs its own cursor, and in the worst case its own index; a cursor anchored on a count that changes after every import is a particularly awkward case on top of everything else. Rather than attempt both together, index pages (small enough that plain pagination is fine either way) get sortable columns, and event lists/alerts (the tables actually large enough for infinite scroll to matter) get keyset scrolling in one fixed order, not sortable.

**F5. Responsive layout was a settled decision that never made it into the document.** Added as a stated requirement for whichever visual direction gets picked, rather than left implicit.

**F6. Infinite scroll's usability problems, not just its query cost.** Added: the browser Back button typically resets a scroll-loaded list and discards position; auto-load-only excludes keyboard/JS-disabled navigation, so a visible "Load more" fallback covers both; and a list that keeps loading as the user nears the bottom makes the footer unreachable without a deliberate stopping point.

**F7. Option C's mockup rewrote real product names into `snake_case` for the terminal aesthetic.** Confirmed and fixed, in both the artifact and this review - that changes the actual data on screen for a styling reason, which isn't a legitimate design choice regardless of which option gets picked. The mockup now shows the real names as-is, same as options A and B.

**Added: a suggested scope**, not adopted automatically - Option A (responsive, optional dark theme via the same CSS custom properties already in use), alerts filters (open/resolved, by brand), keyset infinite scroll on tracking events and alerts specifically, and CSV export of alerts as a small optional add. Name search and count sorting skipped by default: real implementation cost, on tables small enough today that the payoff is mostly saving a page-flip.
