# Design Implementation Report

`DESIGN_PROPOSAL_FINAL.md` describes the bonus round's design; `DESIGN_REVIEW.md` is the record of what was questioned and corrected before and during the build. This document is what actually happened: what held up exactly as planned, four real bugs that only showed up by running the thing rather than reading the code, a place the build didn't match the proposal (fixed), and a later place the build matched the proposal but the proposal itself turned out to be the wrong call (also fixed, by changing course rather than forcing it).

## What got built

In order: Option A ("Quiet Ledger" - responsive layout, dark theme via `prefers-color-scheme`), alerts filters (status and brand), keyset pagination for alerts and tracking-event lists, CSV export of alerts, sortable columns everywhere including alerts (generalizing the keyset mechanism to support any column, either direction), filtering and sorting on the tracking-event lists too (inventory present, a date range, and a store/product dimension), and a live, no-reload filter UI for alerts built in React. A scroll-triggered auto-load variant was also built, then reverted in favor of plain pagination links - see below. Two migrations add the index columns the keyset queries need. 69 tests total - 65 unit/integration/controller plus 2 real-browser system tests (Capybara + Selenium + actual Chrome, not a stub) covering the parts a request/response test can't - that the live filter genuinely doesn't reload the page, and that clicking a sort header genuinely re-sorts without one either.

## The design held up, mostly

- **The filters are cheap, as predicted.** Status and brand both filter on existing indexed columns (`resolved_at`, `brand_id`) - no migration needed for either, matching `DESIGN_PROPOSAL_FINAL.md`'s claim exactly. Same for the tracking-event filters: the date range reuses the existing composite indexes' trailing `event_time` column, as predicted.
- **Keyset pagination's actual benefit held up under test**, not just in theory: `KeysetPageTest` round-trips a cursor forward and back to the exact same rows, confirms rows sharing an identical sort value still order consistently via the `id` tiebreak, and walks a boolean sort ("status") across 30 pages to confirm it crosses the open/resolved boundary cleanly rather than just working within one bucket.
- **CSV export reads the same filtered, sorted scope as the HTML view**, per the proposal's "no new storage" framing - no separate export-specific query logic.

## One place the first build didn't match the proposal - caught, then fixed

`DESIGN_PROPOSAL_FINAL.md`'s suggested scope called for "keyset infinite scroll." What got built first was keyset *pagination* - the query-level fix, exposed through ordinary link clicks, not scrolling. Caught by a direct question about where the scrolling actually was. Fixed by building real auto-loading (a Stimulus controller watching the "Next" link with an `IntersectionObserver`), verified with a real system test - scrolling the link into view with zero clicks loaded the remaining rows.

## One place the build matched the proposal, and the proposal was the problem

Auto-loading, once actually watchable in a real browser rather than read as a design doc, didn't read as an improvement - continuous loading with no visible page boundary read as "the page never ends," not as efficient. Reverted to plain, click-through pagination at 50 rows per page. The keyset mechanism underneath - the part that actually took engineering effort and carries the real correctness/performance property - is unchanged; only the auto-load trigger is gone. `DESIGN_PROPOSAL_FINAL.md` and `DESIGN_REVIEW.md` (round 8) are both updated to say so plainly, rather than leaving the auto-load description standing as if it were still current.

## Sorting, extended to the tables it was originally scoped away from

`DESIGN_PROPOSAL_FINAL.md` originally kept sorting off alerts and the tracking-event lists specifically, reasoning that combining "sort by any column" with keyset pagination multiplies the complexity of both. That reasoning about the cost was right; the scope call built from it was revisited and reversed (`DESIGN_REVIEW.md` round 7) once asked for directly. What made it tractable: `KeysetPage` took the per-column cursor cost as a parameter (`direction:`, `id_column:`, `value:`) rather than a wall, then got reused across five sortable alert columns (brand, product, store, triggered-at, and a computed boolean for status) and three tracking-event columns, instead of hand-building a cursor per column. Verified directly against real data via `bin/rails runner` before trusting it in the UI, not just read as correct from the code.

## Four bugs, caught by running the app, not reading the code

**The cursor's own encoding was broken from the start.** `KeysetCursor` originally joined a timestamp and a row id with `:` and split on the first `:` to decode - but an ISO8601 timestamp already contains colons, so decoding cut the timestamp itself in half. Every "Next" click silently re-rendered page one forever - wrong, not crashing, the more dangerous kind of bug. Caught by a round-trip test failing with the wrong rows. Fixed by switching to a typed JSON encoding (`[type, value, id]`), which also turned out necessary anyway once sorting needed to encode strings and booleans, not just timestamps.

**`csv` isn't auto-required outside the test environment.** The CSV export passed its controller test on the first try, which made the gap easy to miss - something in the test boot path pulls in Ruby's `csv` stdlib transitively that the dev server doesn't. The real server 500'd with `NameError: uninitialized constant AlertsController::CSV` on the identical code. Caught by curling the export endpoint against a running server instead of trusting the green suite alone. Fixed with an explicit `require "csv"`.

**Two dropdown filters had their options exactly backwards.** The product/store tracking-event filters' "pick one store" and "pick one product" selects plucked `[id, name]` from the database, but `options_for_select` expects `[label, value]` - every option showed the row's *id* as the visible label and the *name* as what actually got submitted. Caught by a controller test that asserted on the dropdown's actual rendered options, not just that the page returned 200. Fixed by swapping the pluck order.

**A missing nested vendor file broke React silently.** The first working version of the React-based alerts filter failed in the browser with no visible error - `bin/importmap pin react react-dom/client` had vendored `scheduler.js`, but not `scheduler.js`'s *own* relative import (`./cjs/scheduler.production.js`), which it depends on. The browser's actual error - "Failed to fetch dynamically imported module" - doesn't say which module or why; tracing it required a throwaway diagnostic system test that imported each dependency individually in the browser until the real cause turned up. Fixed by fetching that one file to the matching relative path by hand. Named plainly in `DESIGN_REVIEW.md` round 8: this is exactly the kind of integration surface a framework adds that a fully server-rendered page never has to think about.

## Verified by running it, not just by the test suite being green

- Followed a real "Next" link's cursor through `curl` and confirmed the alert IDs on the second page were genuinely different from the first, not a repeat.
- Downloaded the actual CSV export via `curl`, confirmed the `content-type`/`content-disposition` headers and that the row count matched the active filter.
- Walked a date-range filter that should return zero rows through `curl`, and confirmed via server logs that the SQL itself carried the right `WHERE` clause before trusting the empty-state message in the rendered page - an earlier version of this exact check gave a false "bug" because a sloppy grep pattern matched a *different* table's dates on the same page, not the one actually being filtered.
- Watched a real Chrome window auto-load alerts on scroll (before that was reverted), and separately watched the React-based filter UI change results and the URL with no page reload, confirmed via `window.name` surviving the operation - a real navigation clears it, a DOM update doesn't.
- Clicked a sort header in that same real browser and confirmed the row order actually changed with no reload, after an initial version of that specific test gave a false failure by reading the DOM before React's async update had finished - fixed the test's wait condition, not the app.

## What's still a known limitation, not silently dropped

The infinite-scroll usability notes in `DESIGN_PROPOSAL_FINAL.md` are now moot rather than solved or unsolved - there's no auto-loading left for any of them to apply to. The one real limitation that survives the revert: the browser Back button on a *React*-rendered alerts page still works correctly (it's `history.pushState`-backed, same as a real navigation), but nothing preserves scroll position within the list itself if someone navigates away and back - not named as a problem in the current design doc because, with plain pagination, it isn't one; worth stating here in case the UI changes again later.
