# Retail Inventory Tracking — Joey Bennett

The original assignment is in [ASSIGNMENT.md](ASSIGNMENT.md).

**This branch (`proposed-changes-new-design`) is an optional bonus** - a visual redesign plus additional features (alerts filtering, sorting, live search, CSV export) built on top of the submission. Every assignment requirement was already satisfied on `proposed-changes-joey`; none of this branch's content was needed to meet the spec. See `DESIGN_PROPOSAL_FINAL.md`, `DESIGN_REVIEWED_PROPOSAL.md`, and `DESIGN_IMPLEMENTATION_REPORT.md` for what this branch adds and why.

## Running it

Requires Ruby 3.2.2 and PostgreSQL 13+.

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails tracking_events:import          # ~44s, includes alert generation
bin/rails price_checks:generate_sample    # needs the import above first
bin/rails price_checks:import
bin/rails test                            # 84 tests on this branch (34 on proposed-changes-joey)
bin/rails test:system                     # 6 more - real Chrome via Capybara + Selenium
```

## Key decisions

- **Price checks get their own table.** The assignment says the two checks are independent, so `price_checks` has no foreign key to `tracking_events` at all — not a column bolted onto it.
- **Alerts are computed with a SQL window function**, ordered by `(event_time, id)`, one alert per streak rather than per pair. Ordering by arrival order instead would get roughly **79% of alerts wrong** — the CSV isn't sorted by `event_time`.
- **Re-imports are blocked per file (a checksum), not per row.** 57,551 same-day duplicate checks are real data, not an import bug; a unique index on the row would silently drop some of them.
- **Batched `insert_all`** instead of row-by-row `create!`: the import went from an extrapolated ~30 minutes to a measured ~44 seconds.
- **Grouped counts plus paginated show pages** instead of N+1 queries: the busiest store's page went from a measured 20,341 queries / 5.9s to 6 queries / 21ms.

## Assumptions

- Same-day ties are ordered by import order (`id`) as the explicit tiebreak.
- No real price data was provided, so a sample `price_checks.csv` is generated from the existing product/store pairs.
- A bad CSV row is skipped and logged, not fatal to the whole file — except a negative price, which fails the whole import on purpose (it signals the file itself is untrustworthy, not that one row is bad).

## Known limits

- Grouped counts scan the full table on every request (125ms of a 149ms `/products` load today); a `counter_cache` would fix this at 100x the data, not needed yet.
- No auth: alerts aren't scoped to the brand viewing them.

## More detail

The decisions above are the summary. The full reasoning behind each — including a from-scratch proposal, an 18-round adversarial review of it before any code was written, and a second review of the actual implementation once built — is in:

`FINAL_PROPOSAL.md` (design) · `IMPLEMENTATION_REPORT.md` (build and results) · `REVIEWED_PROPOSAL.md` (review log) · `CLAUDE.md` (orientation for anyone, human or AI, picking this back up) · `SUMMARY_OF_ACTIONS.md` (how this process actually went, using Claude Code)
