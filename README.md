# Retail Inventory Tracking System

## Project Overview

This project simulates a simplified retail inventory-tracking system. You are provided with:

- A set of **Stores**
- A set of **Brands**
- A set of **Products**
- A large CSV file containing **1,000,000 tracking events**
- A basic importer that reads the CSV and creates `TrackingEvent` records

Your goal is to improve the system, modify one of its key features, and then add a new feature.

You are encouraged to:
- Refactor existing code
- Introduce new endpoints or views
- Improve performance, clarity, and maintainability

There is no single "correct" solution — but there are many poor ones. We want to see how **you** design and implement a real-world improvement inside a Rails application.

## Setup

This app is a standard Rails 7.1 / Ruby 3.2 project backed by PostgreSQL.

### Prerequisites

- **Ruby**: `3.2.2`
- **Rails**: `~> 7.1.6`
- **PostgreSQL**: 13+ recommended

You can use **rbenv**, **rvm**, or **asdf** to install the correct Ruby version.

#### Installing Ruby with rbenv
```bash
# Install Ruby 3.2.2
rbenv install 3.2.2

# Set it locally for this project
rbenv local 3.2.2
```

### Installation
```bash
# Install dependencies
bundle install

# Set up the database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

### Importing Tracking Events

To import the million-row CSV file:
```bash
bin/rails tracking_events:import
```

## Objectives

### First Objective: Price Tracking

Currently, the system only tracks if inventory is present via `TrackingEvent`. We want to add a way to track price. An inventory check and price check are separate and can occur without the other happening.

### Second Objective: Alert System

Build an alert system that creates an alert to the brand if a store has two "no inventory" events in a row for the same product based on event_time. There doesn't need to be a big UI for this—just a basic index and show page like the rest of the app.

### Third Objective: Performance Improvements

Improve the app's overall performance. This can be done as you work on the first and second objectives or after completing them.

## Technology Stack

- **Ruby**: 3.2.2
- **Rails**: 7.1.6
- **Database**: PostgreSQL 13+

## Evaluation Criteria

You will be evaluated on:
- Code quality and organization
- Database design decisions
- Performance optimizations
- Ability to explain your thinking and decision making

Feel free to make reasonable assumptions where requirements are ambiguous—just document them in your code or a separate notes file.

## Time Expectation

This project should take approximately [2-3 hours] to complete. Focus on demonstrating your problem-solving approach rather than achieving perfection. AI is allowed on this project. 

## Submission

Please submit:
- A link or invite to your Git repository (GitHub, GitLab, etc.)
- A brief README or notes document explaining your key decisions
- Any instructions needed to run your solution

---

# Notes from the author — Joey Bennett

## Running it

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails tracking_events:import          # ~44s, includes alert generation
bin/rails price_checks:generate_sample    # needs the import above first
bin/rails price_checks:import
bin/rails test                            # 34 tests
```

## Key decisions

- **Price checks get their own table.** The README says the two checks are independent, so `price_checks` has no foreign key to `tracking_events` at all — not a column bolted onto it.
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
