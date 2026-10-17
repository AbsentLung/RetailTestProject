# First Launch

`FINAL_PROPOSAL.md` describes the design. This document is what happened the first time it was actually built, migrated, run, and tested — what held up exactly as predicted, what turned out to need a closer look even though the design was right, and the one real bug that only showed up by actually running the app rather than reading the code.

## What got built

Migrations (constraints, `csv_imports`, `price_checks`, `alerts`), a shared `Importers::BaseCsvImporter` with the advisory lock and two thin subclasses, `AlertGenerator` (bulk and per-pair), `AlertsController` plus pagination and grouped counts across every list page, price display on the product and store show pages, and 21 tests. Five commits, in the order `CLAUDE.md` laid out: migrations → importer → alert generator with tests → controllers/views → timing numbers.

## The design held up, numbers included

Every specific, checkable claim from the 18-round review matched once actually built:

- **Idempotency.** Re-running `tracking_events:import` on the same file: 1.03s, no new rows. Re-running `price_checks:import`: same.
- **One alert per streak, not per pair.** 31,447 alerts after the real 1,000,000-row import — the exact number from the design phase, not an approximation.
- **`resolved_at`, the late-event rule, and per-pair scoping** — all covered by `AlertGeneratorTest` and passing, including the specific case (a late `true` landing between two previously-adjacent `false`s removing the now-invalid alert on regeneration) that took the most design iterations to get right.
- **The N+1 fix, measured against the real app, not a scratch table.** `/stores/95` (10,167 events, the busiest store) now loads in **6 queries, 21ms** — down from an estimated 20,341 queries. The real number is better than the pre-build benchmark, since the live page also renders price history now and still only needs 6 queries total.
- **End-to-end timing.** `bin/rails tracking_events:import`, for real: **41.56 seconds** — import and alert generation together, against the real schema with real indexes and foreign keys. Better than the ~54s estimated by adding two separate scratch-table benchmarks.
- **`seeds.rb` is actually re-runnable now** — ran it twice in a row in the test environment with no foreign key violation.

## A documented limitation, now with a real number attached

The "Out of Scope" section already named this as a 100x-scale concern and deferred it. Running the real app surfaced that it's not purely theoretical even today:

**`/products`'s grouped count took 125.6ms** — `TrackingEvent.group(:product_id).count` over the real 1,000,000-row table — out of a 149ms page load. That's **84% of the page's total time**, from one query, at today's actual scale, not a projected 100x. `/stores` shows the same pattern (73.6ms of an 84ms page load, grouping the same table by `store_id`). `/brands`'s grouped count is sub-millisecond, because it groups `products` (226 rows), not `tracking_events` — a genuinely different, smaller operation, not a discrepancy.

Still deferring the `counter_cache` fix for this exercise — 125ms is tolerable for a demo app at this scale, and the fix was correctly scoped as a 100x concern, not a today concern. But "already the dominant cost on the page, even now" is a more honest way to describe it than leaving the number purely hypothetical.

## The one real bug — found only by testing every route, not by reading the code

`ApplicationHelper#pagination_links` had an `if` modifier used inside an array literal:

```ruby
safe_join([
  (link_to "...") if page > 1,
  link_to("...")
].compact, " | ")
```

This is a `SyntaxError`, not a logic bug — and because helpers load eagerly, it broke the *entire app's boot*, not just the pages using pagination. `curl`-testing every route (not just the ones that changed) caught it immediately; a narrower test pass that only checked the new pages might have missed that the root path was down too. Fixed by building the list conditionally instead of embedding the conditional in the literal. This is exactly the gap between "the design review found real bugs" and "actually running the code finds a different category of bug" — eighteen rounds of review never touched this file, because it didn't exist until implementation.

## A flaky slowdown, investigated and not a code defect

Two of four attempts at `bin/rails tracking_events:import` hung for several minutes, both immediately following a fresh `TRUNCATE`. Investigated live rather than assumed:

- No advisory lock contention and no zombie process — checked `pg_locks` and `pg_stat_activity` directly during a hang.
- No bad query plan from stale statistics — `EXPLAIN (ANALYZE, BUFFERS)` of the exact same alert-generation query, run on a freshly-truncated table with the insert still uncommitted in the same transaction, consistently completed in 1–2.5 seconds regardless of how the table had just been emptied.
- The identical code, run again with no changes, completed cleanly in 41.56s — twice.

The common factor across both hangs was `autovacuum: VACUUM public.tracking_events` actively running (confirmed via `pg_stat_activity`) immediately after the truncate. Most likely explanation: I/O contention between autovacuum cleanup and a large insert transaction right after a structural change to the table, not a defect in the application code. Operational note for anyone re-running this: if a fresh truncate-then-reload hangs, that's worth retrying before assuming the code is broken; running `VACUUM ANALYZE tracking_events` right after a truncate would likely prevent it if this exact reload pattern is ever used outside a one-off local test.

## Test suite

21 tests, 0 failures, 0 errors. Weighted toward the alert window logic per the stated priority: out-of-order arrival, same-day ties, a price check not interfering (it structurally can't — separate table), streak-vs-pair counting, `resolved_at` correctness (including skipping over a longer streak's middle), bulk and per-pair idempotency, and the late-event removal case. Model tests cover the presence/uniqueness validations, including `Product`'s global uniqueness specifically. The four empty `{}` fixture files were deleted — they would have violated the `null: false` constraints added this round and broken every test run via `fixtures :all`.

## Final state

| | |
|---|---|
| `tracking_events` | 1,000,000 |
| `alerts` | 31,447 |
| `price_checks` | 45,672 |
| `products` | 226 |
| `stores` | 101 |
| `brands` | 45 |
| `csv_imports` | 2 |
