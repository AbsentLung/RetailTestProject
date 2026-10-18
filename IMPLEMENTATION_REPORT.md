# Implementation Report

`FINAL_PROPOSAL.md` describes the design. This document is what happened when it was actually built, migrated, run, and tested — what held up exactly as predicted, what turned out to need a closer look even though the design was right, the one real bug that only showed up by running the app rather than reading the code, and a slowdown that got root-caused and fixed rather than just explained away.

## What got built

Migrations (constraints, `csv_imports`, `price_checks`, `alerts`), a shared `Importers::BaseCsvImporter` with the advisory lock and two thin subclasses, `AlertGenerator` (bulk and per-pair), `AlertsController` plus pagination and grouped counts across every list page, price display on the product and store show pages, an `ANALYZE` call that fixed a real post-truncate import hang, two integration tests closing a real gap in test coverage, seven fixes from PR review (a pagination tiebreak, three unpaginated index pages, a non-atomic alert regeneration, a blank-cell crash, a silently-miscategorized blank value, an octal-parsing bug, and a missing database constraint), and 27 tests total.

## The design held up, numbers included

Every specific, checkable claim from the 18-round review matched once actually built:

- **Idempotency.** Re-running `tracking_events:import` on the same file: 1.03s, no new rows. Re-running `price_checks:import`: same.
- **One alert per streak, not per pair.** 31,447 alerts after the real 1,000,000-row import — the exact number from the design phase, not an approximation.
- **`resolved_at`, the late-event rule, and per-pair scoping** — all covered by `AlertGeneratorTest` and passing, including the specific case (a late `true` landing between two previously-adjacent `false`s removing the now-invalid alert on regeneration) that took the most design iterations to get right.
- **The N+1 fix, measured against the real app, not a scratch table.** `/stores/95` (10,167 events, the busiest store) now loads in **6 queries, 21ms** — down from a measured 20,341 queries / 5,946.9ms (`FINAL_PROPOSAL.md`'s number was itself measured, not estimated). The real number is better than the pre-build benchmark, since the live page also renders price history now and still only needs 6 queries total.
- **End-to-end timing.** `bin/rails tracking_events:import`, for real: **~44 seconds** (four runs, after the `ANALYZE` fix below: 41.3s, 43.2s, 44.6s, 45.0s — median ~43.9s) — import and alert generation together, against the real schema with real indexes and foreign keys. Better than the ~54s estimated by adding two separate scratch-table benchmarks. The first real run, before `ANALYZE` was added, measured 41.56s; the range above is the current, accurate number for the code as it stands now.
- **`seeds.rb` is actually re-runnable now** — ran it twice in a row in the test environment with no foreign key violation.

## A documented limitation, now with a real number attached

The "Out of Scope" section already named this as a 100x-scale concern and deferred it. Running the real app surfaced that it's not purely theoretical even today:

**`/products`'s grouped count took 125.6ms** — `TrackingEvent.group(:product_id).count` over the real 1,000,000-row table — out of a 149ms page load. That's **84% of the page's total time**, from one query, at today's actual scale, not a projected 100x. `/stores` shows the same pattern (73.6ms of an 84ms page load, grouping the same table by `store_id`). `/brands`'s grouped count is sub-millisecond, because it groups `products` (226 rows), not `tracking_events` — a genuinely different, smaller operation, not a discrepancy.

Still deferring the `counter_cache` fix for this exercise — 125ms is tolerable for a demo app at this scale, and the fix was correctly scoped as a 100x concern, not a today concern. But "already the dominant cost on the page, even now" is a more honest way to describe it than leaving the number purely hypothetical.

## One bug, one test gap

`ApplicationHelper#pagination_links` had an `if` modifier used inside an array literal:

```ruby
safe_join([
  (link_to "...") if page > 1,
  link_to("...")
].compact, " | ")
```

This is a `SyntaxError`, not a logic bug. Rails controllers include all helpers by default (`config.action_controller.include_all_helpers`, true here, never overridden) — the first request to hit *any* controller builds a shared helper module that loads every file in `app/helpers`, not just the one the current page actually calls. That's why every route broke, not just the pages using pagination. `curl`-testing every route (not just the ones that changed) caught it immediately; a narrower test pass that only checked the new pages might have missed that the root path was down too. Fixed by building the list conditionally instead of embedding the conditional in the literal.

None of the existing 21 tests caught it because none of them exercised a controller action — they were all model and service tests. The helper-loading codepath above only runs on an actual request, so a syntax error sitting in a helper file could stay invisible to the suite indefinitely. Fixed by adding `test/integration/routes_smoke_test.rb`, two tests:

- `Rails.application.eager_load!`, called directly — loads every file in the app, not just helpers, before a single request happens, so a load-time error anywhere surfaces immediately.
- One request against every route (`/`, `/products`, `/products/:id`, `/stores`, `/stores/:id`, `/brands`, `/brands/:id`, `/alerts`, `/alerts/:id`), asserting a 200.

Verified both directions, not just added and trusted: reintroduced the exact broken helper from scratch, ran the suite, watched both new tests fail with the real `SyntaxError` and the real `NoMethodError` it caused downstream — then restored the fix and watched both pass again. The suite is now 23 tests, 0 failures, and an app that can't boot can no longer report a clean test run.

## A flaky slowdown, found and fixed, not just worked around

Two of four attempts at `bin/rails tracking_events:import` hung for several minutes, both immediately following a fresh `TRUNCATE`. Checked live during the hangs: no lock contention, no zombie process (`pg_locks`, `pg_stat_activity`). An `EXPLAIN (ANALYZE, BUFFERS)` of the alert query against a freshly-truncated table came back fast, 1–2.5 seconds — but that check ran the query by itself, not inside the same transaction with the batch inserts still uncommitted, which are different conditions from the actual hang.

The real mechanism is a known Postgres gotcha: `TRUNCATE` resets `pg_class.reltuples` to 0 immediately, and autovacuum can't see rows that this transaction hasn't committed yet. A query planned later in the *same* transaction — the alert generator's window-function query, run right after the batch inserts — can get planned against a table the planner still believes is empty, picking a plan that's fine for 0 rows and bad for 1,000,000.

The fix: run `ANALYZE tracking_events` inside the import transaction, after the last batch insert and before alert generation. `ANALYZE` (unlike `VACUUM`, which can't run inside a transaction block at all) is allowed there and sees the transaction's own uncommitted writes. Added to `Importers::BaseCsvImporter#call`, then verified by truncating and rerunning the full import **4 times in a row** with the fix in place — 41.3s, 43.2s, 44.6s, 45.0s, zero hangs, versus 2 hangs in 4 attempts before the fix. Not formal proof the mechanism is exactly right, but a real, repeatable behavior change under the same conditions that produced the original hangs.

## Found in PR review, fixed before merge

CodeRabbit and a manual pass over the diff found seven real issues:

- **Pagination order was missing a tiebreak.** `event_time`/`triggered_at` are dates, and ties are common — Postgres doesn't guarantee stable ordering across separate `LIMIT`/`OFFSET` queries for tied values, so rows could repeat on one page and never appear on another. `Paginatable#paginate` now appends the primary key as a descending secondary sort.
- **The products/stores/brands index pages were never actually paginated.** `Product.includes(:brand)`, `Store.all`, and `Brand.all` loaded every row with no `limit` at all — a direct miss against the project's own stated convention ("every list page gets pagination from the start"). Harmless at today's 226/101/45 rows, but inconsistent with what the rest of the app does. Fixed, with a sensible base order (`:name`/`:address`) under the same tiebreak.
- **`AlertGenerator#call`'s delete-then-regenerate wasn't atomic outside the import.** The tracking-event import runs it inside its own transaction, but a standalone call (e.g. `AlertGenerator.new(product_id:, store_id:).call`) ran `delete_all` and the `INSERT ... SELECT` as two separate statements — a failure in between leaves that scope with zero alerts, and a concurrent reader could briefly see the same. Wrapped in `Alert.transaction do ... end`, which joins the import's existing transaction rather than opening a nested one.
- **A single blank cell crashed the entire import, not just that row.** Verified empirically rather than assumed: Ruby's CSV library returns `nil`, not `""`, for an empty field, and `Date.parse(nil)` / `Integer(nil)` both raise `TypeError`, not `ArgumentError` — the only exception the per-row rescue caught. One blank `Date` or `Price Cents` cell rolled back the whole file. Fixed: `rescue ArgumentError, TypeError`.
- **A blank `Inventory Present` cell was silently recorded as a real "no inventory" reading.** `cast_boolean` mapped `nil`/`""` into the same bucket as `"false"`/`"f"`/`"0"` — backwards from the documented intent of bug #5 ("an unrecognized value now raises instead of defaulting to false, so a data-quality problem can't masquerade as a real no-inventory reading"). A blank cell is exactly the data-quality problem that rule exists for. Removed `nil, ""` from the false branch; they now raise and the row is skipped like any other bad value.
- **Price parsing had a leading-zero bug.** `Integer("0100")` is Ruby reading an octal literal, not a decimal one — it returns `64`, not `100`. Fixed with `Integer(row["Price Cents"], 10)`.
- **Negative prices had no constraint at the database level.** `insert_all` skips Rails validations entirely, and `null: false` doesn't reject a negative integer. Added a `price_cents >= 0` check constraint via migration, applied cleanly against the real 1,000,000-row dataset.
- **Reseeding left stale import checksums behind.** `db:seed` deleted `Alert`/`PriceCheck`/`TrackingEvent` rows but never cleared `CsvImport`, so re-importing the same file afterward would see its checksum already recorded and silently do nothing. Added `CsvImport.delete_all` to the reset block.

Four new tests cover the two importer fixes: a blank date cell, a blank inventory value, a leading-zero price, and a blank price cell — each asserting the bad row is skipped, not that it crashes the import.

## Test suite

27 tests, 0 failures, 0 errors. Weighted toward the alert window logic per the stated priority: out-of-order arrival, same-day ties, a price check not interfering (it structurally can't — separate table), streak-vs-pair counting, `resolved_at` correctness (including skipping over a longer streak's middle), bulk and per-pair idempotency, and the late-event removal case. Model tests cover the presence/uniqueness validations, including `Product`'s global uniqueness specifically. Two are the integration smoke tests from the first build pass; four more cover the importer fixes from PR review above. The four empty `{}` fixture files were deleted — they would have violated the `null: false` constraints added this round and broken every test run via `fixtures :all`.

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
