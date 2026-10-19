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

## What stays the same regardless of which one you pick

The same 4 sample products and 2 sample alerts (one ongoing, one resolved) appear in all three mockups, so the comparison is the design, not the data. Nothing in `app/` changes until one is picked - this file and the artifact are the proposal, not the implementation.

## Beyond the visual layer

Four things worth architecting alongside the restyle, each with the actual database changes required, not just the feature description.

### Search

**Alerts are the highest-value target, not product/store/brand name search.** With 31,447 alerts, "show me open alerts for Brand X" is a real operational need; with 226 products, a name-search box mostly just saves a page-flip.

- **Alert status filter** (`?status=open` / `?status=resolved`): `where(resolved_at: nil)` / `where.not(resolved_at: nil)`. **Database changes: none** at today's scale - nothing filters or orders by `resolved_at` yet. If this needed to stay fast at higher volume, the fix is a partial index: `CREATE INDEX ON alerts (triggered_at) WHERE resolved_at IS NULL` - covers "open alerts, newest first" directly, and stays small regardless of how large the resolved-alert history grows, since it only indexes the open ones.
- **Name search** (`WHERE name ILIKE '%term%'`): fine unindexed at 226/101/45 rows - a leading wildcard can't use a plain btree index anyway (Postgres can only range-scan a `LIKE 'term%'` prefix, not `%term%`), so a normal index wouldn't help here regardless of scale. The real risk is SQL injection through the wildcard characters themselves, not the query shape: `%`/`_` in user input need `sanitize_sql_like` before reaching `ILIKE`.
- **Database changes, at 100x scale**: a `pg_trgm` trigram index - `CREATE EXTENSION pg_trgm; CREATE INDEX ... USING gin (name gin_trgm_ops)`. A genuinely different *kind* of index from anything else in this app today (everything existing is a plain btree) - named now so it isn't rediscovered from scratch later, the same way the counter-cache and keyset-pagination notes already are in `FINAL_PROPOSAL.md`.

### Sorting

Clicking a column header (e.g. "Tracking Events" on the products index) to sort by it.

- **Sorting by a stored column** (name, address, `triggered_at`): a plain `ORDER BY`. `products.name` and `stores.address` are already uniquely indexed; `alerts.triggered_at` isn't indexed today - the only index on `alerts` besides its foreign keys is the unique one on `second_event_id`. **Database changes: one new index, `(triggered_at)` on `alerts`, if alerts get sorted at volume** - the others need nothing new.
- **Sorting by a computed count** (products by tracking-event count, brands by product count) is the harder case, worth naming the real tension rather than assuming a quick fix:
  - **Option 1 - live `JOIN` + `GROUP BY` + `ORDER BY`.** Reuses the exact aggregate query already run for display (`TrackingEvent.group(:product_id).count`), just reordered - no new expensive operation, since the cost is already being paid today. **Database changes: none.**
  - **Option 2 - a `counter_cache` column** (`products.tracking_events_count`). The textbook fix for "sort/filter by a count cheaply" - but not free here specifically, because of a tension already named in `CLAUDE.md`: Rails' `counter_cache` maintains itself via `after_create`/`after_destroy`, and this app's entire import performance story is built on `insert_all`, which skips callbacks entirely. A counter_cache column here needs a manual reconciliation step bolted onto the importer (a batch `UPDATE products SET tracking_events_count = (SELECT COUNT(*) ...)` after each import), not Rails keeping it in sync automatically. **Database changes: a new `integer, null: false, default: 0` column, plus an importer change to reconcile it - not just a migration.**
  - **Recommendation: Option 1 for now.** The aggregate is already being computed for display; sorting by it costs nothing new. Revisit Option 2 only if the aggregate itself becomes the bottleneck independent of sorting - it already partially is (the documented 125ms / 84% `/products` cost in `IMPLEMENTATION_REPORT.md`).

### Date range filtering

A `from`/`to` filter on time-series pages: price history, a product or store's tracking events.

- Implementation: `WHERE event_time BETWEEN ? AND ?`, scoped to the product or store already being viewed.
- **Database changes: none.** The existing composite indexes (`[:product_id, :event_time]`, `[:store_id, :event_time]`) already have `event_time` as the trailing column - a range condition on it, within a fixed product or store, is an index range scan on an index that already exists. One case where the indexing already in place happens to support the new feature for free.

### Infinite scroll, and why it isn't just a visual choice

Infinite scroll and the pagination style already flagged as a 100x-scale concern in `FINAL_PROPOSAL.md` are the same decision, not two separate ones.

`LIMIT 50 OFFSET N` gets slower the deeper a page is, because Postgres has to scan and discard every skipped row first. Classic numbered pagination hides that cost today (nobody manually clicks to page 400), but infinite scroll removes the one thing that was keeping it hidden - continuous scrolling makes deep offsets the *common* case, not the rare one.

**Database changes**, if this moves to keyset pagination (`WHERE (sort_column, id) < (last_seen_value, last_seen_id) ORDER BY sort_column DESC, id DESC LIMIT 50` instead of `OFFSET`):
- Products/stores/brands (ordered by name/address): **no new index** - already uniquely indexed, which is exactly what a keyset cursor needs to anchor on.
- Alerts (ordered by `triggered_at`): **one new index**, `(triggered_at, id)` - doesn't exist today.
- Tracking events / price history (ordered by `event_time`, scoped to a product or store): **no new index** - the existing composite indexes already cover this ordering.

The implementation path doesn't need a new dependency: Rails 7 ships Hotwire/Turbo already (it's in this app's importmap right now, unused). A `turbo_frame_tag` at the bottom of a list, lazy-loaded via its own `src`, is the standard Rails-native way to build a "load more" or auto-scroll-triggered frame - no custom JS required for the simplest version.

#### Pagination vs. keyset (cursor): the actual tradeoff

| | Offset pagination (today) | Keyset / cursor pagination |
|---|---|---|
| Query cost at page N | Grows with N - scans and discards every skipped row | Constant, regardless of scroll depth |
| "Jump to page 12" | Yes | No - only next/previous from a cursor |
| Total page count ("page 3 of 40") | Cheap-ish (one extra `COUNT`) | Not naturally available at all |
| New indexes needed | None | One, for `alerts` - others reuse existing unique/composite indexes |
| Correctness under concurrent writes | Can skip or repeat rows if the underlying set changes between page loads | Stable - a cursor anchored to a specific row is unaffected by rows inserted elsewhere |
| Implementation complexity | Already built | Needs a cursor encode/decode step, and validating a client-supplied token instead of a trusted integer page number |

That "correctness under concurrent writes" row isn't just a performance difference. Offset pagination can skip or duplicate rows under concurrent inserts - the same *category* of bug as the exact-multiple-page edge case already found and fixed this session (`IMPLEMENTATION_REPORT.md`), just a different trigger (a changing row count mid-session instead of a coincidental one).

**Recommendation: build infinite scroll on keyset pagination from the start**, not on `LIMIT`/`OFFSET`. The extra cost is small (one new index, a cursor helper) against inheriting a scaling problem that was already named and deferred once, and then having to redo the work later anyway.

### CSV export

Exporting the current alert or price-history view back out as a CSV - fitting, given the whole app exists to *import* CSVs. **Database changes: none** - this reads the same data already being queried for display.

None of the four are part of the visual-redesign bonus by default - naming them here so they're a deliberate "not now" rather than something that just never came up.

## Pattern choices considered and declined

Two suggestions came up for the interactive pieces above. Both are real, reasonable choices elsewhere - here's the actual reasoning for not using them in this project.

### Turbo Frames (Hotwire) vs. React

Infinite scroll, live search, and sortable columns without a full page reload all need *some* client-side interactivity. The two real candidates:

| | Turbo Frames / Hotwire | React |
|---|---|---|
| New dependency | None - already in this app's importmap, unused | A full JS framework, plus a build pipeline this app doesn't have |
| Rendering model | Same as the rest of the app - server-rendered ERB, swapped in fragments | A second, parallel rendering model alongside the existing ERB views |
| Fits keyset-paginated infinite scroll | Directly - a `turbo_frame_tag` lazy-loaded via its own `src` is the standard pattern | Works, but needs a JSON API underneath either way, since React doesn't render ERB |
| Consistency with the rest of the codebase | High - the whole app is server-rendered today | Low - one feature would work on a fundamentally different architecture from every other page |

**Declined for this project.** React is a reasonable choice for a product where rich client-side interaction is a first-class requirement. That's not what this is: a Rails take-home where every other page is server-rendered ERB, and the one framework capable of the same interactive result with zero new dependencies is already sitting unused in the importmap. Adopting React here would mean one feature working on a completely different architecture from the rest of the app, for no capability this app actually needs.

**React Native specifically** (raised as "an easy path to a mobile app later") doesn't actually shorten that path the way it might seem to. React Native doesn't render React *web* views - there's no `<div>`/`<table>` in React Native, only native components (`<View>`, `<FlatList>`, etc.) - so a future native app's UI gets built from scratch regardless of what today's website uses. What *does* make a future native app easier is a clean JSON API underneath, which is a backend concern, independent of the website's rendering choice. See the forward-looking note below.

### Plain CSS (current) vs. Sass

| | Plain CSS (current) | Sass |
|---|---|---|
| New dependency | None - the existing Sprockets pipeline | `dartsass-rails`, or a Node build step |
| Theming mechanism | CSS custom properties - one token set, swapped per theme or per design option, already how all three options above and the house artifact style work | Variables + mixins - a different mechanism for the same job |
| What it would add here | - | Nesting, mixins - neither used by any of the three proposed designs |

**Declined for this project.** Sass earns its place when a stylesheet is complex enough that nesting and mixins meaningfully reduce duplication. None of the three design options need that - each is a single token set (palette plus two or three type roles) applied through CSS custom properties, which is already doing the real work (theme-swapping) in this app's existing artifacts. Adding a build-step dependency for authoring conveniences nothing here needs doesn't pay for itself.

## A forward-looking note, not built now

If a native iOS/Android app is a real possibility later, the highest-leverage thing to do *now* isn't a frontend framework choice for the website - it's keeping controllers thin enough that adding a JSON API later is additive, not a rewrite. Concretely: `respond_to :html, :json` on the existing actions, or a dedicated `Api::V1::` namespace reusing the same models and query logic already built. A native app (React Native or otherwise) would consume that API; it wouldn't consume today's ERB views either way, so nothing about the website's rendering choice helps or hurts that future path. Not built now - named here so it's a deliberate "not yet" rather than something that has to get re-derived from scratch if it ever becomes real.

## Next step

Pick one of the three visual directions, or name specific pieces to combine (e.g. Option A's layout with Option C's alert-row treatment). Decide separately which of search, sorting, date-range filtering, and infinite scroll are actually in scope for this bonus round, if any. Once decided, implementation happens the same way everything else on this branch has: file by file, tested, committed with real content.
