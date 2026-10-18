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

Three things worth architecting alongside the restyle, in order of how much a real user of this app would actually want them.

### Filtering and search

**Alerts are the highest-value target, not product/store/brand name search.** With 31,447 alerts, "show me open alerts for Brand X" is a real operational need; with 226 products, a name-search box mostly just saves a page-flip. Concretely:

- An alert status filter (`?status=open` / `?status=resolved`) is a `where(resolved_at: nil)` / `where.not(resolved_at: nil)` scope - no new index needed, since nothing is ordered or filtered by `resolved_at` at volume today.
- A brand/product/store name search box (`WHERE name ILIKE ?`) is fine unindexed at 226/101/45 rows. The one real risk is SQL injection through the wildcard itself, not the query shape - `%`/`_` in user input need `sanitize_sql_like` before they reach `ILIKE`, the same category of care this project already gave the alert generator's bind parameters.
- If this ever ran at 100x scale with free-text search expected to stay fast, that's a `pg_trgm` trigram index, not a bigger box - named here so it doesn't get rediscovered from scratch later, the same way the counter-cache and keyset-pagination scaling notes already are in `FINAL_PROPOSAL.md`.

### Infinite scroll, and why it isn't just a visual choice

Infinite scroll and the pagination style already flagged as a 100x-scale concern in `FINAL_PROPOSAL.md` are the same decision, not two separate ones.

`LIMIT 50 OFFSET N` gets slower the deeper a page is, because Postgres has to scan and discard every skipped row first. Classic numbered pagination hides that cost today (nobody manually clicks to page 400), but infinite scroll removes the one thing that was keeping it hidden - continuous scrolling make deep offsets the *common* case, not the rare one. Switching to keyset pagination (`WHERE (event_time, id) < (last_seen_event_time, last_seen_id) ORDER BY ... LIMIT 50`, using the composite indexes already in place) fixes that, and it's a better technical fit for infinite scroll specifically: keyset pagination's real weakness is that it can't do "jump to page 7" without a page-number index to anchor from - a limitation infinite scroll never needed in the first place, since it only ever asks for "the next batch from here."

The implementation path doesn't need a new dependency either: Rails 7 ships Hotwire/Turbo already (it's in this app's importmap right now, unused). A `turbo_frame_tag` at the bottom of a list, lazy-loaded via its own `src`, is the standard Rails-native way to build a "load more" or auto-scroll-triggered frame - no custom JS, no Stimulus controller required for the simplest version.

**Net: if infinite scroll gets built, build it on keyset pagination from the start** rather than bolting it onto `LIMIT`/`OFFSET` and inheriting a performance problem that was already named and deferred once.

### Smaller things worth naming

- **Sortable columns** (click "Tracking Events" on the products index to sort by it) - cheap, a `params[:sort]` whitelist against a small set of columns.
- **A date range on time-series pages** (price history, a store or product's tracking events) - the data is already time-ordered; this is a `WHERE event_time BETWEEN ?` away.
- **CSV export of the current alert or price-history view** - fitting, given the whole app exists to *import* CSVs; exporting one back out is the same shape in reverse.

None of these are part of the visual-redesign bonus by default - naming them here so they're a deliberate "not now" rather than something that just never came up.

## Next step

Pick one, or name specific pieces to combine (e.g. Option A's layout with Option C's alert-row treatment). Once decided, implementation happens the same way everything else on this branch has: file by file, tested, committed with real content.
