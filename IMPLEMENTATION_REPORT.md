# Implementation Report

`FINAL_PROPOSAL.md` describes the design. This document is what happened when it was actually built, migrated, run, and tested — what held up exactly as predicted, what turned out to need a closer look even though the design was right, the one real bug that only showed up by running the app rather than reading the code, and a slowdown that got root-caused and fixed rather than just explained away.

## What got built

Migrations (constraints, `csv_imports`, `price_checks`, `alerts`), a shared `Importers::BaseCsvImporter` with the advisory lock and two thin subclasses, `AlertGenerator` (bulk and per-pair), `AlertsController` plus pagination and grouped counts across every list page, price display on the product and store show pages, an `ANALYZE` call that fixed a real post-truncate import hang, two integration tests closing a real gap in test coverage, eight fixes from PR review (a pagination tiebreak, three unpaginated index pages, a non-atomic alert regeneration, a blank-cell crash, a silently-miscategorized blank value, an octal-parsing bug, a missing database constraint, and stale import checksums on reseed), `ErrorReporter` wired into the importer and `AlertGenerator` with a logging/APM/email/SMS channel each, and 34 tests total.

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

CodeRabbit and a manual pass over the diff found eight real issues:

- **Pagination order was missing a tiebreak.** `event_time`/`triggered_at` aren't unique per row, and ties are common — Postgres doesn't guarantee stable ordering across separate `LIMIT`/`OFFSET` queries for tied values, so rows could repeat on one page and never appear on another. `Paginatable#paginate` now appends the primary key as a descending secondary sort.
- **The products/stores/brands index pages were never actually paginated.** `Product.includes(:brand)`, `Store.all`, and `Brand.all` loaded every row with no `limit` at all — a direct miss against the project's own stated convention ("every list page gets pagination from the start"). Harmless at today's 226/101/45 rows, but inconsistent with what the rest of the app does. Fixed, with a sensible base order (`:name`/`:address`) under the same tiebreak.
- **`AlertGenerator#call`'s delete-then-regenerate wasn't atomic outside the import.** The tracking-event import runs it inside its own transaction, but a standalone call (e.g. `AlertGenerator.new(product_id:, store_id:).call`) ran `delete_all` and the `INSERT ... SELECT` as two separate statements — a failure in between leaves that scope with zero alerts, and a concurrent reader could briefly see the same. Wrapped in `Alert.transaction do ... end`, which joins the import's existing transaction rather than opening a nested one.
- **A single blank cell crashed the entire import, not just that row.** Verified empirically rather than assumed: Ruby's CSV library returns `nil`, not `""`, for an empty field, and `Date.parse(nil)` / `Integer(nil)` both raise `TypeError`, not `ArgumentError` — the only exception the per-row rescue caught. One blank `Date` or `Price Cents` cell rolled back the whole file. Fixed: `rescue ArgumentError, TypeError`.
- **A blank `Inventory Present` cell was silently recorded as a real "no inventory" reading.** `cast_boolean` mapped `nil`/`""` into the same bucket as `"false"`/`"f"`/`"0"` — backwards from the documented intent of bug #5 ("an unrecognized value now raises instead of defaulting to false, so a data-quality problem can't masquerade as a real no-inventory reading"). A blank cell is exactly the data-quality problem that rule exists for. Removed `nil, ""` from the false branch; they now raise and the row is skipped like any other bad value.
- **Price parsing had a leading-zero bug.** `Integer("0100")` is Ruby reading an octal literal, not a decimal one — it returns `64`, not `100`. Fixed with `Integer(row["Price Cents"], 10)`.
- **Negative prices had no constraint at the database level.** `insert_all` skips Rails validations entirely, and `null: false` doesn't reject a negative integer. Added a `price_cents >= 0` check constraint via migration, applied cleanly against the real 45,672-row `price_checks` table.
- **Reseeding left stale import checksums behind.** `db:seed` deleted `Alert`/`PriceCheck`/`TrackingEvent` rows but never cleared `CsvImport`, so re-importing the same file afterward would see its checksum already recorded and silently do nothing. Added `CsvImport.delete_all` to the reset block.

Four new tests cover three importer fixes: the `TypeError` rescue (a blank date cell, a blank price cell), the `cast_boolean` blank-value fix (a blank inventory value), and the octal-parsing fix (a leading-zero price) — each asserting the bad row is skipped, not that it crashes the import.

**A second look at the TypeError fix above found one more real issue.** The `rescue` block applying that fix still wrapped the batch's `model_class.insert_all(batch)` call, not just `row_attributes`. Fixed by moving the `begin/rescue` to wrap only `row_attributes`, so `insert_all` failures still surface and roll back the transaction instead of getting silently counted as a skipped row.

## Edge cases and cleanups

A negative price fails the whole import by design, the same as a structurally broken file — the check constraint is the guard. That's different from a blank cell, which is ordinary missing data in one row; a negative price is a sign the file itself shouldn't be trusted, so stopping and surfacing it beats silently dropping one row and moving on.

Fixed:

- **"Next" always showed, even past the last page.** Most visible on the brands index — 45 rows, one page, and "Next" still linked to an empty page 2. `pagination_links` now takes the rendered collection and only shows "Next" when that page came back full (`collection.size == PER_PAGE`).
- **A test used raw string interpolation into SQL** (`test/models/tracking_event_test.rb`) instead of bind parameters, inconsistent with the parameterized-SQL convention used everywhere else. Switched to `exec_query` with bound values.
- **`price_checks:generate_sample` had no fixed seed**, so regenerating the sample file produces different rows each time. Added `srand(42)`.
- **An unused local variable** (`first_run_id`) was left over in `alert_generator_test.rb` from an earlier draft of that test.

## Error reporting - something the original design didn't consider

Nothing in `FINAL_PROPOSAL.md` or the review rounds asked where this app would actually tell a human when something had gone wrong. `AlertGenerator` and the importer could both already fail outright (the negative-price check constraint above is exactly that kind of failure) and the only trace would be whatever the Rails process happened to log on its way down.

Added `ErrorReporter`, called from the two places that matter - the importer's transaction and `AlertGenerator#call` - not from the per-row rescue, which is routine and already just logs a warning. Anything that reaches `ErrorReporter` is, by definition, the whole operation failing, not one bad row.

**This project doesn't have a New Relic account, or a real phone number, or a real email address to send to - and it's written as if it did anyway.** Each channel checks for its own configuration and no-ops cleanly if it isn't there, rather than pretending to call a service that doesn't exist:

- **Logging.** Always happens, `Rails.logger.error`, with the exception and whatever context the call site had (file path, product/store IDs, rows processed so far).
- **APM (New Relic).** `NewRelic::Agent.notice_error(...)` behind `defined?(NewRelic::Agent)`. True today: there's no account, so this never fires. If one existed, `bundle add newrelic_rpm` plus a license key is the only thing that would need to change - not this code.
- **Email, for every urgent failure.** A real `UrgentIssueMailer`, not a stub - `config.action_mailer.delivery_method` is `:test` in development (same as it already was in `test.rb`), so it genuinely sends, it just doesn't leave the process. That would become `:smtp` with real credentials if this went live.
- **Text, for the same failures.** Behind `ENV["TWILIO_ACCOUNT_SID"].present? && defined?(Twilio::REST::Client)` - no `twilio-ruby` gem added, consistent with this project's stance against a dependency that can't be exercised. The call is real Twilio API usage, just unreachable until that gem and those credentials exist.

A broken notification channel can't suppress the original exception or block the others - each channel's own rescue logs and moves on, and the real exception is always re-raised after all three have had a chance to fire, so the transaction still rolls back exactly as it did before this existed. Verified both ways: a forced failure during import rolls back to zero rows, is reported, and still raises; and running `ErrorReporter.notify` directly in the actual development environment (not just the test suite) produces a real captured email with the right subject and context, with no attempted SMTP connection.

Three new tests cover `ErrorReporter` directly; two more confirm the importer and `AlertGenerator` report and re-raise rather than swallow an unexpected failure.

**A second look at that found a real bug: one failure sent two alerts, and the first one fired while still holding the advisory lock.** `AlertGenerator#call` runs inside the importer's own open transaction (via `after_import`); when it fails, its own rescue reported the exception and re-raised, and the importer's rescue then caught that same exception and reported it again - two emails (and, once configured, two texts) for one incident. Worse: `AlertGenerator`'s report happened *before* the transaction had actually rolled back, since a transaction nested inside another one doesn't issue a real `ROLLBACK` until the outermost one unwinds - meaning a slow mail server would hold the advisory lock and the uncommitted rows open for as long as `deliver_now` took to return.

Checked rather than assumed: `Alert.connection.transaction_open?` is `false` at the rescue point for a real standalone call, and `true` when nested inside the importer's transaction - confirmed both ways with a throwaway script, not just reasoned about. That distinction looked like the fix, until it ran inside the actual test suite: Rails' transactional fixtures wrap every test in its own transaction, so `transaction_open?` reads `true` in tests regardless of whether the real nesting the fix cares about is present - the test harness itself confounds the exact signal the fix depended on. Replaced it with an explicit `report_errors:` flag on `AlertGenerator.new` instead of inferring intent from ambient transaction state: `after_import` passes `report_errors: false`, every other caller defaults to `true`. Simpler, and correct in both tests and production rather than only one.

Also added: `ErrorReporter.notify` marks the exception object it just reported, so even a future caller that reports the same exception a second time can't double-send - a cheap safety net behind the real fix above, not a replacement for it. Verified for real, not just mocked: forced `AlertGenerator`'s SQL call to raise during an actual import against the dev database - exactly one email, zero rows left behind, the exception still raised to the caller.

## Small things from the same pass

- `base_csv_importer.rb`'s success log line now includes `duration=`, turning the end-to-end timing number this document already reports into something the app reports about itself, not just something measured by hand.
- `UrgentIssueMailer`'s recipient is `ENV.fetch("URGENT_ALERT_EMAIL", "ops@example.com")` instead of a hardcoded address.
- A test asserted `ENV["TWILIO_ACCOUNT_SID"]` was `nil` as a proxy for "not configured" - true in this environment, but a brittle thing to assert about ambient state. Changed to explicitly clear and restore the variable for the duration of the test instead of assuming it.

## A fourth review pass, and a fix that needed its own fix

**"Next" could still link to an empty page.** The earlier fix (`collection.size == PER_PAGE`) correctly hid "Next" on a short last page, but couldn't tell a full page that's genuinely the last one from a full page with more after it - when the total row count happens to be an exact multiple of `PER_PAGE`, both look identical from inside that one page. Fixed by having `paginate` fetch one extra row (`PER_PAGE + 1`); `pagination_links` now checks for that extra row instead of guessing from a count that can't carry the distinction, and every view renders only `.first(PER_PAGE)`. Verified the way every fix in this document has been: temporarily reverted the comparison, watched the new test fail against a deliberately-constructed exact-multiple of 50 brands, restored it, watched it pass - then confirmed against the real app that a 226-row page still shows exactly 50 rows with `Next`, and the last page (26 rows) shows only `Previous`.

**The `srand(42)` fix from the last round was incomplete.** `price_checks:generate_sample`'s product/store pair query had no `ORDER BY`. Postgres doesn't guarantee row order without one, so the seeded random sequence could still get consumed in a different order between runs even with the seed fixed - reproducibility depends on both a fixed seed *and* a fixed input order. Added `ORDER BY s.address, p.name`.

**The fix immediately above it introduced a real regression: every paginated page now ran two queries instead of one.** `Relation#first(n)` on a relation that hasn't been loaded yet doesn't take the first `n` of whatever the relation already has queued up - it runs its *own* fresh query with its *own* `LIMIT n`, discarding the relation's `LIMIT PER_PAGE + 1` entirely. Then `pagination_links`' `collection.size`, still unloaded, triggered a second query on top of that (a `COUNT` wrapping the original limit/offset). Confirmed with query logging before touching anything: two separate `SELECT`s where there used to be one. Fixed by having `paginate` call `.to_a` itself, once - every later `.first`/`.size` call is then plain `Array#first`/`Array#size`, no further queries. Verified against the real running server's log, not just a script: one `Product Load` query (`LIMIT 51`), nothing else from pagination.

**A second look at the "exactly once" test found it didn't actually test what it claimed.** It stubbed `AlertGenerator.new` to always return a preconfigured instance, which bypasses whatever arguments the real `after_import` call site passes - the test would have kept passing even if `report_errors: false` were accidentally removed from that call site. Worse: when checked by deliberately removing it, the test *still* passed, for two compounding reasons - `ErrorReporter`'s dedup flag silently absorbed the resulting second report (so the email count stayed at exactly 1 either way), and the body-content assertion (`assert_match "CsvImporter"`) matched the exception's backtrace, which contains the test's own class name, `CsvImporterTest` - a false match that had nothing to do with which layer actually reported. Fixed both: redefine `AlertGenerator#run` on the class itself instead of stubbing `.new`, so the real call site's arguments are what's under test; and assert on the actual context key (`importer:` present, `generator:` absent) instead of a substring that backtrace noise could satisfy by accident.

## Test suite

34 tests, 0 failures, 0 errors. Weighted toward the alert window logic per the stated priority: out-of-order arrival, same-day ties, a price check not interfering (it structurally can't — separate table), streak-vs-pair counting, `resolved_at` correctness (including skipping over a longer streak's middle), bulk and per-pair idempotency, and the late-event removal case. Model tests cover the presence/uniqueness validations, including `Product`'s global uniqueness specifically. Two are the integration smoke tests from the first build pass; four more cover the importer fixes from PR review; six more cover error reporting, including the exactly-one-report fix; one more covers the exact-multiple-page pagination edge case. The four empty `{}` fixture files were deleted — they would have violated the `null: false` constraints added this round and broken every test run via `fixtures :all`.

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
