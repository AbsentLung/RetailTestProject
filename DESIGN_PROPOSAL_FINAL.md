# Design Proposal

A bonus visual pass over the app, proposed before any app files change. Three concrete directions, same sample content in each so the only variable is the design itself. The rendered comparison is in the artifact; this file is the written record of what each one actually is.

No new dependencies in any of the three - hand-rolled CSS through the existing Sprockets pipeline (`app/assets/stylesheets/application.css`), consistent with this project's stance against adding a gem for something plain CSS already does.

## Option A — Quiet Ledger

A clean admin console: minimal, professional, reads like a well-made internal tool rather than a product.

- **Palette.** Cool slate-white paper (`#F6F7F9`), near-navy ink (`#1C2430`), one confident accent - a deep teal (`#146C5F`) that reads as "in stock" without reaching for literal green. Status: a muted brick red for open alerts, a muted green for resolved.
- **Type.** IBM Plex Sans for headings, Source Sans 3 for body text, IBM Plex Mono for counts and prices.
- **Layout.** A sticky top nav (Products / Stores / Brands / Alerts), content in bordered cards with soft shadows, tables sitting flush inside their card. Status shown as a small pill badge.
- **Where it fits.** Lowest risk, least opinionated of the three - the safe, correct-looking choice for a take-home submission.

## Option B — Stockroom Dashboard

More branded and warmer, like something a small retail chain's internal ops team would actually use day to day.

- **Palette.** Warm paper (`#FBF7F1`, closer to receipt stock than clinical white), warm ink-brown (`#2B2117`), a rust/amber accent (`#B5531C`) that reads as a warehouse stamp rather than a corporate blue.
- **Type.** Libre Franklin (bold, slightly condensed - a signage feel) for headings, Work Sans for body.
- **Layout.** Products/stores/brands render as a card grid instead of bare table rows - each one its own small tile. Status shown as a solid stamped chip with a dot, not a soft pill.
- **Where it fits.** More visual personality than Option A; closer to the "retail ops dashboard" category from the earlier round, now actually shown rather than named.

## Option C — Night Shift Console

Dark-mode-first, built for scanning a lot of rows fast - fitting, given the real data behind this app is 1,000,000 tracking events.

- **Palette.** Near-black charcoal-navy (`#0B0E12`), not pure black. A phosphor-green accent (`#39D98A`) for the general UI, a warm red (`#FF6B5E`) reserved for open alerts.
- **Type.** IBM Plex Mono for everything, headings included - a deliberate terminal/console feel rather than a typical CRUD-app look.
- **Layout.** Dense tables, minimal row padding. Alert status isn't a badge at all - it's a colored left-border bar on the row itself, like a log line.
- **Where it fits.** The most opinionated option. Best if the alert system (the app's actual headline feature) should visually dominate, at the cost of looking less like a conventional admin panel.
- **Correction from the mockup:** the artifact's first pass rewrote real product names into `snake_case` (`chocolate_frogs`) for the terminal aesthetic, and zero-padded tracking-event counts (`0892`) for the same reason. Both change the actual data on screen, not just its styling - a real product named "Chocolate Frogs" shouldn't display as something else, and a count of 892 isn't 0892, because of a theme choice. Both dropped from the mockup regardless of which option gets picked.

## What stays the same regardless of which one you pick

The same 4 sample products and 2 sample alerts (one ongoing, one resolved) appear in all three mockups, so the comparison is the design, not the data. Nothing in `app/` changes until one is picked - this file and the artifact are the proposal, not the implementation.

**Responsive layout is a requirement for whichever direction gets picked, not an extra.** "Viewable on mobile" was already settled earlier as a responsive-CSS question, independent of any framework choice - it belongs here as part of the actual scope, not left implicit.

## Beyond the visual layer

Five things worth architecting alongside the restyle, each with the actual database changes required, not just the feature description.

### Search

**Alerts are the highest-value target, not product/store/brand name search.** With 31,447 alerts, "show me open alerts for Brand X" is a real operational need; with 226 products, a name-search box mostly just saves a page-flip.

- **Alert status filter** (`?status=open` / `?status=resolved`): `where(resolved_at: nil)` / `where.not(resolved_at: nil)`. **Database changes: none** at today's scale - nothing filters or orders by `resolved_at` yet. If this needed to stay fast at higher volume, the fix is a partial index: `CREATE INDEX ON alerts (triggered_at) WHERE resolved_at IS NULL` - covers "open alerts, newest first" directly, and stays small regardless of how large the resolved-alert history grows, since it only indexes the open ones.
- **Name search** (`WHERE name ILIKE ?`, value bound - not interpolated, so this isn't a SQL injection question at all): fine unindexed at 226/101/45 rows - a leading wildcard can't use a plain btree index anyway (Postgres can only range-scan a `LIKE 'term%'` prefix, not `%term%`), so a normal index wouldn't help here regardless of scale. The real issue is correctness, not security: a user searching for literal `50%` would have that `%` interpreted as a wildcard inside the pattern, matching anything starting with `50` rather than the literal string. `sanitize_sql_like` is still the right fix - it escapes `%`/`_` in the *user's* term before it's wrapped in the pattern - just for that reason, not injection.
- **Database changes, at 100x scale**: a `pg_trgm` trigram index - `CREATE EXTENSION pg_trgm; CREATE INDEX ... USING gin (name gin_trgm_ops)`. A genuinely different *kind* of index from anything else in this app today (everything existing is a plain btree) - named now so it isn't rediscovered from scratch later, the same way the counter-cache and keyset-pagination notes already are in `FINAL_PROPOSAL.md`.

### Sorting

Clicking a column header (e.g. "Tracking Events" on the products index) to sort by it. Originally scoped to the index pages only - see "Sorting and infinite scroll, revisited" below for why that scope didn't hold.

- **Sorting by a stored column** (name, address, `triggered_at`): a plain `ORDER BY`. `products.name` and `stores.address` are already uniquely indexed; `alerts.triggered_at` isn't indexed today - the only index on `alerts` besides its foreign keys is the unique one on `second_event_id`. **Database changes: one new index, `(triggered_at)` on `alerts`, if alerts get sorted at volume** - the others need nothing new.
- **Sorting by a computed count** (products by tracking-event count, brands by product count) is the harder case, worth naming the real tension rather than assuming a quick fix:
  - **Option 1 - live `JOIN` + `GROUP BY` + `ORDER BY`.** The real controller today runs two separate queries - the paginated `Product` list, and a *separate* `TrackingEvent.group(:product_id).count` into a Ruby hash the view looks up by id. Sorting by that count means combining these into one query (a join, grouped, with the count as an orderable column) - a genuinely different query shape, not the existing one just reordered. The cost is comparable to what's already being paid today (same aggregate, same table scan), but it is new code, not a free reorder. **Database changes: none.**
  - **Option 2 - a `counter_cache` column** (`products.tracking_events_count`). The textbook fix for "sort/filter by a count cheaply" - but not free here specifically, because of a tension already named in `CLAUDE.md`: Rails' `counter_cache` maintains itself via `after_create`/`after_destroy`, and this app's entire import performance story is built on `insert_all`, which skips callbacks entirely. A counter_cache column here needs a manual reconciliation step bolted onto the importer (a batch `UPDATE products SET tracking_events_count = (SELECT COUNT(*) ...)` after each import), not Rails keeping it in sync automatically. **Database changes: a new `integer, null: false, default: 0` column, plus an importer change to reconcile it - not just a migration.**
  - **Recommendation: Option 1 for now.** The join+group+order query is new code, but no new storage or reconciliation step, and the cost is already being paid today in a different shape. Revisit Option 2 only if the aggregate itself becomes the bottleneck independent of sorting - it already partially is (the documented 125ms / 84% `/products` cost in `IMPLEMENTATION_REPORT.md`).

#### Sorting and infinite scroll, revisited

The original call here was to keep sorting off alerts and the event lists entirely, since every sortable column needs its own keyset cursor and, in the worst case, its own supporting index - sorting by name needs a cursor anchored on name, a count needs one anchored on count, and so on. That reasoning about the cost was correct; the scope decision built from it didn't hold; sorting was added to alerts and the tracking-event lists anyway (`DESIGN_REVIEW.md` round 7).

What actually made that tractable: `KeysetPage` took the "own cursor per column" cost as a parameter, not a blocker - generalized once (direction, a qualified id column, a value extractor for joined/computed columns), then reused for five sortable alert columns and the tracking-event columns below, rather than hand-building a cursor per column. Index pages (products/stores/brands) stay on plain offset pagination regardless - they were never the ones with a cursor-cost problem to begin with.

### Date range filtering, and tracking-event filters more generally

**Built**, on the product and store show pages' tracking-event lists: a `from`/`to` date range, an Inventory Present filter (yes/no), and - scoped to whichever dimension that page doesn't already fix - a Store filter on a product's page, a Product filter on a store's page. Sortable by Event Time, Inventory Present, and that same per-page dimension, using the same keyset mechanism alerts already uses (`DESIGN_REVIEW.md` round 7's generalized `KeysetPage`).

- Implementation: `WHERE event_time >= ? AND event_time <= ?` for the range, scoped to the product or store already being viewed; plain equality for Inventory Present and the store/product filter.
- **Database changes: none.** The existing composite indexes (`[:product_id, :event_time, :id]`, `[:store_id, :event_time, :id]`) already have `event_time` as a middle column and `id` trailing - a range condition on `event_time`, within a fixed product or store, is still an index range scan on an index that already exists. One case where the indexing already in place happens to support the new feature for free.

### Infinite scroll, and why it isn't just a visual choice

Infinite scroll and the pagination style already flagged as a 100x-scale concern in `FINAL_PROPOSAL.md` are the same decision, not two separate ones.

`LIMIT 50 OFFSET N` gets slower the deeper a page is, because Postgres has to scan and discard every skipped row first. Classic numbered pagination hides that cost today (nobody manually clicks to page 400), but infinite scroll removes the one thing that was keeping it hidden - continuous scrolling makes deep offsets the *common* case, not the rare one.

**Database changes**, if this moves to keyset pagination (`WHERE (sort_column, id) < (last_seen_value, last_seen_id) ORDER BY sort_column DESC, id DESC LIMIT 50` instead of `OFFSET`):
- Products/stores/brands (ordered by name/address): **no new index** - already uniquely indexed, which is exactly what a keyset cursor needs to anchor on.
- Alerts (ordered by `triggered_at`): **one new index**, `(triggered_at, id)` - doesn't exist today.
- Tracking events / price history (ordered by `event_time`, scoped to a product or store): the keyset cursor is `(event_time, id)`, so the exact index is `(store_id, event_time, id)` / `(product_id, event_time, id)` - **one new column added to each existing composite index.** The current `(store_id, event_time)` / `(product_id, event_time)` get the scan most of the way there (narrows to the right store or product, gets into the right time range), but don't cover the `id` tiebreak for rows sharing the same `event_time` - without it, ties need an extra sort step rather than a single fully-ordered index scan.

**Built, then the auto-load reverted - the pagination underneath stayed.** A Stimulus controller that auto-loaded the next batch on scroll was built and worked correctly (see `DESIGN_REVIEW.md` round 6), but reviewing it in actual use, continuous scrolling with no visible page boundary read as "the page never ends," not as an efficiency win. Reverted to plain, click-through "Previous"/"Next" links at 50 rows per page (round 8). What's unchanged is the actual point of this section: alerts and the tracking-event lists are on keyset pagination, not `LIMIT`/`OFFSET`, so query cost stays flat regardless of how many pages someone clicks through, and the correctness property below still holds. Only the auto-load trigger is gone - the mechanism it was triggering is exactly what every "Next" click already uses.

This means the GET-per-scroll question from `DESIGN_REVIEW.md`'s round 1 isn't hypothetical - every "Next" click on `/alerts` and the tracking-event lists is one. Round 1's measurement (single-digit milliseconds at this app's real row counts, regardless of offset) was taken against `LIMIT`/`OFFSET`; the keyset queries built here are cheaper still, since their cost doesn't grow with depth at all.

#### Pagination vs. keyset (cursor): the actual tradeoff

| | Offset pagination (today) | Keyset / cursor pagination |
|---|---|---|
| Query cost at page N | Grows with N - scans and discards every skipped row | Constant, regardless of scroll depth |
| "Jump to page 12" | Yes | No - only next/previous from a cursor |
| Total page count ("page 3 of 40") | Cheap-ish (one extra `COUNT`) | Not naturally available at all |
| New indexes needed | None | One new index for `alerts`; `id` added as a trailing column to the existing tracking-event/price-history composite indexes; products/stores/brands reuse their existing unique indexes as-is |
| Correctness under concurrent writes | Can skip or repeat rows if the underlying set changes between page loads | Stable - a cursor anchored to a specific row is unaffected by rows inserted elsewhere |
| Implementation complexity | Already built | Needs a cursor encode/decode step, and validating a client-supplied token instead of a trusted integer page number |

That "correctness under concurrent writes" row isn't just a performance difference. Offset pagination can skip or duplicate rows under concurrent inserts - a real correctness bug, not just a speed one.

**Recommendation: build infinite scroll on keyset pagination from the start**, not on `LIMIT`/`OFFSET`. The extra cost is small (one new index, a cursor helper) against inheriting a scaling problem that was already named and deferred once, and then having to redo the work later anyway.

#### Usability, not just the query

This section named three real infinite-scroll pitfalls to design around. After round 8's revert to plain pagination links, all three are moot in the way that matters most: a "Next" click is a real page navigation, not a scroll-triggered fetch, so none of these are failure modes of what's actually built.

- **The browser Back button.** A real navigation's Back button already returns to exactly where it was, the same as every other page in this app - nothing special to solve.
- **A "Load more" button fallback.** There's no auto-loading to need a fallback for - the "Next" link already is the only way forward, for everyone, with or without JS.
- **The footer becomes unreachable.** Content only loads on a real click, so the footer is always reachable - there's no tail that keeps growing underneath it.

Kept here as a record of what was actually considered mid-build (`DESIGN_REVIEW.md` round 6), not because any of it still describes a real risk.

### CSV export

Exporting the current alert or price-history view back out as a CSV - fitting, given the whole app exists to *import* CSVs. **Database changes: none** - this reads the same data already being queried for display.

None of the four are part of the visual-redesign bonus by default - naming them here so they're a deliberate "not now" rather than something that just never came up.

## Pattern choices: declined, then one of them reversed

Three suggestions came up for the pieces above. Two stayed declined; the third - React - was revisited after this section was first written and adopted in a scoped way. Rather than rewrite the original reasoning as if it never existed, it's kept below as it was, with the reversal stated plainly next to it - see `DESIGN_REVIEW.md` round 8 for the full account of why.

### Turbo Frames (Hotwire) vs. React

Infinite scroll, live search, and sortable columns without a full page reload all need *some* client-side interactivity. The two real candidates:

| | Turbo Frames / Hotwire | React |
|---|---|---|
| New dependency | None - already in this app's importmap, unused | A full JS framework, plus a build pipeline this app doesn't have |
| Rendering model | Same as the rest of the app - server-rendered ERB, swapped in fragments | A second, parallel rendering model alongside the existing ERB views |
| Fits keyset-paginated infinite scroll | Directly - a `turbo_frame_tag` lazy-loaded via its own `src` is the standard pattern | Works, but needs a JSON API underneath either way, since React doesn't render ERB |
| Consistency with the rest of the codebase | High - the whole app is server-rendered today | Low - one feature would work on a fundamentally different architecture from every other page |

**Declined for this project, as it stood then.** React is a reasonable choice for a product where rich client-side interaction is a first-class requirement. That's not what this was at the time: a Rails take-home where every other page is server-rendered ERB, and the one framework capable of the same interactive result with zero new dependencies was already sitting unused in the importmap. The `turbo_frame_tag` half of this comparison also turned out to be wrong on its own terms once actually built - see the infinite-scroll section above - which doesn't change this verdict, but is worth knowing before weighing it.

**Reversed, scoped to the alerts filter UI specifically.** Once TypeScript was adopted (below) for unrelated reasons, the "no build pipeline" argument against React was already gone - the build step would exist either way. The remaining argument (consistency with a server-rendered app) still holds for everything that doesn't need a framework, which is still true of most of this app. React was adopted for exactly the one place that had real, multi-piece client state to keep in sync (filters, sort, and a pagination cursor, all without a reload) - not as a replacement for server-rendered ERB generally. The table above is still an accurate comparison of the two options; what changed is that one feature's actual requirements grew past where the "Declined" verdict was reasoning from.

**React Native specifically** (raised separately, as "an easy path to a mobile app later") doesn't actually shorten that path the way it might seem to. React Native doesn't render React *web* views - there's no `<div>`/`<table>` in React Native, only native components (`<View>`, `<FlatList>`, etc.) - so a future native app's UI gets built from scratch regardless of what today's website uses. What *does* make a future native app easier is a clean JSON API underneath, which is a backend concern, independent of the website's rendering choice. See the forward-looking note below. This reasoning is unaffected by the React reversal above - adopting React for one web UI island says nothing about React Native for a future mobile app.

### Plain JavaScript (original) vs. TypeScript

Raised directly: TypeScript "catches mistakes better when using AI." The comparison is really about what it costs to get that, not whether type errors are worth catching.

| | Plain JavaScript | TypeScript |
|---|---|---|
| New dependency | None - `importmap-rails` serves `app/javascript/**` straight to the browser | A compiler (`tsc`) plus a transform step (`esbuild`, for JSX) before anything can be served |
| Catches | Nothing before runtime | Type mismatches, typos in prop/field names, wrong argument counts - exactly the mistakes that are easy to introduce and easy to miss reviewing AI-generated diffs |
| What changes for importmap-rails | Nothing - files are served as-written | Still served as plain `.js` - source moves to `app/javascript/controllers_src/*.ts(x)`, compiled output lands where importmap already expects it |

**Adopted**, reversing the "no build pipeline" stance this section opened with. The honest accounting: this app now has a build step it didn't have before, and that step has to actually run (and its output committed, or regenerated) for the two interactive controllers to work at all - a real new way for the app to be broken that didn't exist when everything was server-rendered ERB and unprocessed JS. Worth it specifically because the stated reason (catching mistakes in AI-assisted changes before they reach the browser) is a real, recurring risk this project has already hit elsewhere in less visible ways - and once paid for TypeScript, the same build step is most of what React needed too (below).

### Postgres search (`ILIKE` / `pg_trgm`) vs. Elasticsearch

| | Plain CSS (current) | Sass |
|---|---|---|
| New dependency | None - the existing Sprockets pipeline | `dartsass-rails`, or a Node build step |
| Theming mechanism | CSS custom properties - one token set, swapped per theme or per design option, already how all three options above and the house artifact style work | Variables + mixins - a different mechanism for the same job |
| What it would add here | - | Nesting, mixins - neither used by any of the three proposed designs |

**Declined for this project.** Sass earns its place when a stylesheet is complex enough that nesting and mixins meaningfully reduce duplication. None of the three design options need that - each is a single token set (palette plus two or three type roles) applied through CSS custom properties, which is already doing the real work (theme-swapping) in this app's existing artifacts. Adding a build-step dependency for authoring conveniences nothing here needs doesn't pay for itself.

### Postgres search (`ILIKE` / `pg_trgm`) vs. Elasticsearch

Named in "Search" above as the fix for name search at 100x scale: Postgres `ILIKE`/`pg_trgm`/full-text first, not Elasticsearch.

**Declined for this project.** Elasticsearch is a stronger tool, but for a bigger problem than this app has - relevance ranking, typo tolerance, and full-text search across millions of documents, not "find a product by part of its name" across a few tens of thousands of rows even at 100x scale. It's also a second system to run and keep in sync with Postgres, normally via save callbacks that this app's `insert_all`-based imports skip entirely - the same sync problem already named for `counter_cache`, and worse, since it means operating a whole second service rather than one Rails-maintained column. Worth it at millions of documents, or for fuzzy relevance tuning `pg_trgm` genuinely can't do - not at this app's scale. Full reasoning in `DESIGN_REVIEW.md`, round 2.

## A forward-looking note, not built now

If a native iOS/Android app is a real possibility later, the highest-leverage thing to do *now* isn't a frontend framework choice for the website - it's keeping controllers thin enough that adding a JSON API later is additive, not a rewrite. Concretely: `respond_to :html, :json` on the existing actions, or a dedicated `Api::V1::` namespace reusing the same models and query logic already built. A native app (React Native or otherwise) would consume that API; it wouldn't consume today's ERB views either way, so nothing about the website's rendering choice helps or hurts that future path. Not built now - named here so it's a deliberate "not yet" rather than something that has to get re-derived from scratch if it ever becomes real.

## A suggested scope, pending your pick

Not a decision - a recommendation to approve, adjust, or reject, same as everything else here.

1. **Option A (Quiet Ledger)**, responsive, with an optional dark theme through the same CSS custom properties and `prefers-color-scheme` already used for theming - gets Option C's dark-mode appeal without its risk or its data-rewriting mistake.
2. **Alerts filters**: open/resolved, and by brand.
3. **Keyset infinite scroll** on tracking events and alerts specifically - the two tables actually large enough for it to matter.
4. **CSV export of alerts** - optional, small, and the one feature here that's genuinely cheap regardless of what else gets picked.

**Skipped by default: name search and count sorting.** On tables this small (226/101/45 rows), both add real implementation cost (the join+group+order restructuring, a `sanitize_sql_like` call, a new `alerts` index) for a feature that mostly just saves a page-flip today.

## Next step

Pick one of the three visual directions, or name specific pieces to combine (e.g. Option A's layout with Option C's alert-row treatment). Decide separately which of search, sorting, date-range filtering, and infinite scroll are actually in scope for this bonus round, if any. Once decided, implementation happens the same way everything else on this branch has: file by file, tested, committed with real content.
