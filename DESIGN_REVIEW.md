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

## Round 5 — Four small fixes, then approved

A review pass on `DESIGN_PROPOSAL_FINAL.md` as it stood after round 3, confirming everything from that round was addressed and raising four more small items. All four confirmed and fixed; none were blockers.

**Elasticsearch wasn't named as a declined choice.** It had been discussed and declined in round 2 above, but never added to `DESIGN_PROPOSAL_FINAL.md`'s own "Pattern choices considered and declined" section alongside React and Sass - the other two declined choices for the same bonus round. Added as a third entry there, condensed from round 2's reasoning rather than repeating it in full.

**Option C's mockup zero-padded tracking-event counts (`0892`, `0441`).** The same problem as round 3's F7 (`snake_case` product names), a smaller version - a theme choice changing the actual data on screen. Fixed the same way: real numbers shown as-is, and the existing "Correction from the mockup" note extended to cover both.

**"Four things worth architecting" actually listed five** (search, sorting, date range filtering, infinite scroll, CSV export). A miscount from when CSV export was added after the heading was written. Fixed to "Five things."

**The concurrent-writes comparison named the wrong bug.** The row comparing offset vs. keyset pagination's behavior under concurrent writes went on to compare it to "the exact-multiple-page edge case already found and fixed this session" - but that bug was about whether a "Next" link displays correctly at an exact page-count boundary, not about rows shifting during concurrent writes. Different bug, different cause; the comparison didn't hold up. Also flagged as narration ("this session") that doesn't belong in a document meant to be read later. Deleted the sentence - the table row already states the real claim on its own.

**Approved.** Build order: Option A (responsive, optional dark theme), then alerts filters, then keyset infinite scroll, then CSV export - the suggested scope from round 3, taken as-is. Staying on `proposed-changes-new-design`; `proposed-changes-joey` doesn't change.

## Round 6 — "Keyset infinite scroll" was really keyset pagination, after Option A/filters/scroll/export were built

**What was raised.** After Option A, the alerts filters, keyset pagination, and CSV export were all built and committed, a question surfaced about where the actual infinite-scroll behavior was - the UI only offered a "Previous"/"Next" link pair. It didn't auto-load as the page was scrolled.

**The gap was real.** What round 3's suggested scope called "keyset infinite scroll" had been built as keyset *pagination* - the hard, valuable part (query cost that doesn't grow with depth, no skipped/duplicated rows under concurrent writes) - but exposed through ordinary link clicks, not through scrolling. That's a real difference from what `DESIGN_PROPOSAL_FINAL.md`'s infinite-scroll section actually described (auto-loading on scroll, with a "Load more" button as the named fallback, not the only way in).

**Built properly**, auto-loading as the page scrolls, via actual GET requests the same way round 1 above measured: a small Stimulus controller watches the existing "Next" link with an `IntersectionObserver`, and fetches that link's own URL when it scrolls into view, appending the rows the response contains. The link stays in the DOM throughout - it's the fallback round 1's usability notes already called for, not a separate thing that needed building. Round 1's finding (GET-per-scroll isn't slow at this app's scale) was a measurement against hypothetical traffic at the time; it now describes what every scroll step on `/alerts` and the tracking-event lists actually does, and the keyset queries underneath are cheaper than what round 1 measured, not just as cheap.

**One correction already named in round 1 was wrong in the other direction.** The original `turbo_frame_tag` plan in `DESIGN_PROPOSAL_FINAL.md`'s infinite-scroll section doesn't actually work: a `<turbo-frame>` placed inside a `<tbody>` gets foster-parented out of the table by the browser's HTML parser, since custom elements aren't valid table content there. Fixed in `DESIGN_PROPOSAL_FINAL.md` to describe what was actually buildable and built - Stimulus plus `fetch`, not a frame.

**Also fixed:** the "Usability, not just the query" list now says which of its three pitfalls got solved by this build (the Load more fallback, by construction; the unreachable footer, since loading stops once there's no more "Next" to watch) and which didn't (the Back button still resets scroll position - the URL never changes as rows append, so that limitation stands as described, not silently dropped).

## Round 7 — Sorting and keyset infinite scroll, combined after all

**What was raised:** add sortable column headers to every table, including alerts - "all of these headers should order onclick."

**This revises F4 (round 3) rather than just extending it.** F4 recommended keeping sorting and keyset scrolling on separate tables specifically because combining them multiplies complexity - every sortable column needs its own cursor, and in the worst case its own index. That reasoning wasn't wrong, it was a scope call, not a correctness argument: the engineering is real, but doable.

- `KeysetPage` grew a `direction:`, `id_column:`, and `value:` parameter - generalized from "sort by one datetime column, descending" to "sort by any SQL expression, either direction, with a value extractor for columns that aren't the row's own attribute."
- Sorting alerts by brand, product, or store needed a real join (`eager_load`, not `includes`) so the `ORDER BY`/`WHERE` could reference those tables in the same query as the keyset comparison.
- Sorting by "status" needed a computed boolean (`resolved_at IS NOT NULL`), not `resolved_at` itself - `resolved_at` is NULL for every open alert, and NULL never satisfies a keyset `<`/`>` comparison. A boolean expression is never NULL, which sidesteps needing a three-column cursor just for this one case.
- `KeysetCursor` needed to encode more than timestamps - a brand name is a string, "is resolved" is a boolean. Typed the token (`["time"|"bool"|"int"|"str", value, id]`) instead of assuming every sort column is a date.

Each of the five sortable alert columns got its own cursor column and value extractor, verified directly against real data (`bin/rails runner`, not just reading the code) before trusting it in the UI - including walking the "status" cursor across 30 pages to confirm it crosses the open/resolved boundary in order, not just within one bucket of 50.

Products, stores, and brands got the simpler version: no keyset there (still plain offset pagination), so sorting is just `.order()`, plus - for the two count columns (tracking events per product/store, products per brand) - the join+group+order combined query already named as Option 1 in "Sorting by a computed count" above, built now rather than just described.

## Round 8 — Four decisions made together: infinite scroll reverted, tracking events gained filters, and the stack pivoted to TypeScript and React

**1. Auto-loading on scroll was reverted.** Round 6 built real scroll-triggered auto-loading. Used in practice, it didn't read as an improvement - continuous loading with no visible page boundary reads as "the page never ends," not "efficient." Reverted to plain, click-through "Previous"/"Next" links at 50 rows per page. The keyset pagination underneath - the actually hard-won part, flat query cost and no skipped/duplicated rows under concurrent writes - is unchanged; only the auto-load trigger is gone. `app/javascript/controllers/infinite_scroll_controller.js` and its system test are removed.

This also closes the usability section's one open item cleanly: plain pagination links are real page navigations, so the Back button already works exactly as expected - nothing left to solve. The "Load more fallback" and "footer unreachable" pitfalls don't apply either, for the same reason: there's no auto-load left to need a fallback for.

**2. Tracking events are now filterable and sortable too.** The product and store show pages' tracking-event lists get the same treatment alerts already had: filter by Inventory Present (yes/no), by the one dimension each page doesn't already fix (Store, on a product's page; Product, on a store's page), and by the date range already named - not built - in "Beyond the visual layer" above. Sortable by Event Time, Inventory Present, and that same per-page dimension, using the generalized `KeysetPage` from round 7. Database changes: none beyond what's already there - the date range filter uses the same composite indexes that already cover `event_time` as a trailing column.

A real bug here, caught by a controller test rather than by review: the "filter to one store" and "filter to one product" dropdowns had their options backwards. `pluck("stores.id", "stores.address")` plucks `[id, address]`, but `options_for_select` expects `[label, value]` pairs - every option showed the row's *id* as its visible label and the *address* as the value actually submitted. Fixed by plucking `address, id` (and `name, id` on the store page) instead. Caught because a test asserted on the dropdown's actual rendered options, not just that the page returned 200.

**3. TypeScript, for the interactive controllers.** Raised directly: "it catches mistakes better when using AI." The real cost is a build step - `importmap-rails` serves JavaScript straight from `app/javascript/` with no compilation, which was the actual basis for calling this app's frontend dependency-free. TypeScript needs stripping (and, for JSX, transforming) before a browser can run it. Adopted anyway, as a deliberate reversal of that stance: `tsc --noEmit` type-checks `app/javascript/controllers_src/*.{ts,tsx}`; `esbuild`, used for transformation only (`bundle: false`), compiles them to plain ES modules under `app/javascript/controllers/`, which `importmap-rails` serves exactly as before. Bare imports (`react`, `@hotwired/stimulus`) pass through untouched and resolve in the browser via the importmap, same as every other pinned package - esbuild here strips types and transforms JSX, it doesn't bundle.

**4. React, for the alerts filter UI specifically.** Also raised directly, reasoning that the project is expected to grow more complex client-side logic over time, and a framework pays off more as that happens. The TypeScript decision above already removed the "no build step" objection that was the main argument against React in "Pattern choices" - what's left of that section's reasoning (consistency with an otherwise fully server-rendered app) still holds for everything that doesn't need a framework, which is still most of this app. React was scoped to exactly the one place that already had meaningfully complex client state to keep in sync without a reload (status/brand filters, sort, and a pagination cursor) - not a rewrite of the server-rendered pages. `app/javascript/controllers_src/alerts_filter_controller.tsx` is a Stimulus controller whose only job is mounting a React component into its own element; the component fetches a new `format.json` response from the same `AlertsController#index` action the HTML page already uses, and renders its own filter form, table, and pagination. The server-rendered version - a real `<form>`, real links, a working submit button - stays in the DOM as the no-JS fallback; React replaces it only once it's actually mounted.

**A real bug here too, and a telling one.** The first working version failed silently in the browser - no visible error, the page just never updated. `react-dom/client` and `scheduler` both failed to dynamically import, masked by the browser's generic "Failed to fetch dynamically imported module" message, which doesn't say why. Tracing it required importing each dependency individually in the browser console, via a throwaway diagnostic system test rather than guesswork, until `scheduler` turned up the real cause: `bin/importmap pin react react-dom/client` vendored `scheduler.js`, but not the relative import *inside* `scheduler.js` (`./cjs/scheduler.production.js`) that it depends on - a gap in the vendoring step, not in anything written here. Fixed by fetching that one file manually to the matching relative path. Worth naming plainly: adding a framework adds exactly this kind of integration surface - a dependency of a dependency silently missing - that a fully server-rendered page never has to think about.

---

**A note on naming, after round 3.** `DESIGN_PROPOSAL.md` is now two files, matching how `INITIAL_PROPOSAL.md` / `REVIEWED_PROPOSAL.md` / `FINAL_PROPOSAL.md` work for the main feature: `DESIGN_PROPOSAL_INITIAL.md` is frozen at exactly the state before round 3's edits (rounds 1 and 2 were always clarified here, never edited into the document itself, so nothing changes there); `DESIGN_PROPOSAL_FINAL.md` carries round 3's corrections and the suggested scope, and is the one that keeps getting updated as review continues. The references to `DESIGN_PROPOSAL.md` by its old name in rounds 1-3 above are left as they were written, since that was its real name at the time.
