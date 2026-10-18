# CLAUDE.md

A Rails app tracking retail inventory and price checks across stores, with an alert system for repeated stockouts, and a performance-focused import/query path.

## Where decisions actually live

- **`FINAL_PROPOSAL.md`** — the source of truth. Final schema, final code, measured numbers. Read this first.
- **`REVIEWED_PROPOSAL.md`** — the *why*, as a review log. Only open this for the reasoning behind a specific decision below — it's long.
- **`INITIAL_PROPOSAL.md`** — the original first draft. Several of its ideas were superseded (see below). Don't build from this one.

## Setup

```bash
rbenv install 3.2.2 && rbenv local 3.2.2   # Ruby 3.2.2, not system Ruby
bundle install                              # Rails 7.1.6
bin/rails db:create db:migrate db:seed
bin/rails tracking_events:import            # ~41s, measured - 1,000,000 rows, import + alert generation together
bin/rails price_checks:generate_sample      # writes a sample price_checks.csv
bin/rails price_checks:import
bin/rails test
```

## The most important rule

**Never add a unique index on `(product_id, store_id, event_time)`.** Same-day duplicate checks are real data, not an import bug — 57,551 rows, 18,062 of them with a genuine `True`/`False` conflict. A unique constraint on that triple silently drops real rows. This was the first and biggest finding of the whole review, and it's exactly the thing an AI reaches for first when asked to prevent duplicate imports. Idempotency belongs at the file level (a `csv_imports` checksum table), never the row level.

## Conventions to follow on every change

- Order alerts and streaks by `(event_time, id)`, never insertion order — the CSV isn't sorted, and insertion order silently gives a different, wrong answer.
- `insert_all` skips callbacks and validations. Data integrity for anything bulk-inserted has to come from database constraints, not Rails-level validations alone.
- Never use `includes` just to count rows — use a grouped count.
- Every list page gets pagination from the start, not added later.
- Measure before claiming a speedup — same schema, same indexes/FKs, same environment on both sides of the comparison.
- Run `bin/rails test` before committing. Any change to alert logic needs a test covering it. Test priority is the alert window logic (out-of-order arrival, same-day ties, a price check mid-streak, re-import idempotency) over model validations — that's where the risk actually is.
- `config.eager_load` is only `true` under CI (`config/environments/test.rb`), so a plain local `bin/rails test` run never loads files outside the code paths your tests exercise — a broken helper can sit green indefinitely. `test/integration/routes_smoke_test.rb` calls `Rails.application.eager_load!` directly and hits every route; keep it passing rather than relying on CI to be the first to notice a boot failure.

## Traps already found

- **Alert generation runs once per import, never once per batch.** Per-batch regeneration measured at ~87 minutes — worse than the import this project exists to speed up.
- **No `product_store_statuses` / running counter table.** Alerts are computed directly from `tracking_events` with a window function. A bulk `insert_all` skips `after_create`, so an incrementally-maintained counter can't be kept in sync during import.
- **`tracking_events` keeps its name.** Price checks live in their own `price_checks` table; renaming the existing 1,000,000-row table would buy nothing.
- **One alert per streak, not per pair.** A 3-in-a-row streak is one alert, not two — use the `prev2` check in the generator query.
- **`Product#name` is globally unique, not scoped to `brand_id`.** `tracking_events.csv` has no brand column, so the importer can only resolve a product by name alone — a brand-scoped uniqueness validation doesn't match what the importer can actually check.
- **The per-pair `AlertGenerator` needs bind parameters, not string interpolation** — `exec_query(sql, name, [product_id, store_id])`, plain values.
- **The import transaction needs `pg_advisory_xact_lock`.** Without it, two concurrent imports of the same file both do the full batched insert before colliding at commit — wasted work, not data corruption, but it raises uncaught.
- **`event_time` stays `datetime`, not `date`**, even though the current data is day-only — keeps room for real time-of-day data later.
- **Run `ANALYZE` on the target table inside the import transaction, right after the batched inserts and before `after_import`.** Immediately after a `TRUNCATE`, Postgres' planner statistics say the table has 0 rows — `TRUNCATE` resets `pg_class.reltuples` right away, and autovacuum can't see rows this transaction hasn't committed yet. A query planned later in the same transaction (the alert generator's window-function query) can get planned for an empty table and pick a bad plan for 1,000,000 rows. `ANALYZE`, unlike `VACUUM`, is allowed inside a transaction block and sees the transaction's own uncommitted writes — confirmed by repeating a fresh `TRUNCATE` + full re-import 4 times after adding it with no hang, versus 2 hangs in 4 attempts beforehand.

## Explicitly out of scope (see `FINAL_PROPOSAL.md`'s "Out of scope" section)

Scalability, fault tolerance, reads-vs-writes, and security already got a specific pass there — not a generic one. If something new comes up that touches any of these, extend that section's reasoning rather than re-deriving it from first principles.

One scaling note from that section worth repeating here: offset pagination (`limit`/`offset`) is fine at 1,000,000 rows but not at 100x — grouped counts and deep-page `OFFSET` both scale with table size, not page size. Keyset pagination and a `counter_cache` are the fixes if that scale is ever actually reached.

No auth/authorization (alerts aren't actually scoped to a brand yet — `current_brand.alerts.find(id)` + Pundit is the stated plan, not built), no background jobs or Redis (nothing needs them at this scale), no CSV upload hardening (the importer reads a fixed path, not user input).
