# Summary of Actions

The key decisions themselves are in `README.md`. This is the longer version: how this submission actually got built using Claude Code, and the process that produced those decisions — proposed, reviewed 18 times, approved, implemented, then reviewed again against the real code.

## The result, in numbers

- **3 objectives, all addressed**: price tracking as a structurally independent table; an alert system ordered by `event_time` with one alert per streak; measured performance work on both the import path and every read path.
- **Alerts ordered by `event_time`, not CSV arrival order** — ordering by arrival order instead agrees with the correct, chronological result on only 8,340 of 39,114 events (21.3%), getting roughly **79% of alerts wrong**. Not a guess: the CSV's row order has essentially zero correlation with `event_time` (`corr(id, event_time) ≈ -0.0003`), measured directly against the real data.
- **~44 seconds** end-to-end for the real 1,000,000-row import, including alert generation — down from an extrapolated ~30 minutes for the original row-by-row approach; the import step alone, measured against a schema-matched benchmark (indexes and foreign keys included on both sides), is **~51.6x faster**.
- **31,447 alerts**, exact, against the real imported data.
- **~283x faster** on the busiest store's page: 6 queries / 21ms, down from a measured 20,341 queries / 5,946.9ms.
- **34 tests, 0 failures**, weighted toward the logic the review process identified as actually risky.
- One limitation named and left unfixed on purpose: a grouped count that's already 84% of one page's load time at today's scale, scoped as a 100x-scale problem rather than a today problem.

## The process

**1. Orientation, before touching any code.** First ask: list the three objectives plainly, from the README, so there was a shared, explicit target before any proposal existed.

**2. A bug hunt, scoped to the objectives.** Second ask: find bugs in the starter app, with the README's objectives specifically in mind — not a generic lint pass, but "what's actually wrong given what this app is supposed to do."

**3. A separate cleanliness pass.** A distinct third ask, deliberately separated from the bug hunt: general code-cleanliness issues, independent of whether they were functionally broken.

**4. Design options, before committing to one.** Rather than accepting the first design that came back, asked for several system-design alternatives — including diagrams of the current schema and the alternatives — so the choice between them was visible and deliberate, not accepted by default.

**5. A first proposal, then real self-review.** Once a direction was picked, `INITIAL_PROPOSAL.md` was the result. Reading it closely surfaced real flaws in it — not polish issues, substantive ones.

**6. A second, independent opinion.** Rather than resolve those flaws alone, a second Claude agent was brought in specifically as an adversarial second pair of eyes on the same proposal — someone (something) with no investment in the first draft being right.

**7. Eighteen rounds of revision, kept, not cleaned up.** Each round of critique — from the second agent, and from direct inspection — was checked against the real code, the real 1,000,000-row dataset, or a real benchmark before being accepted or specifically rejected. The full back-and-forth, including the rounds where a critique was pushed back on and held, is in `REVIEWED_PROPOSAL.md`. It was never sanitized down to just the final answer, on purpose — the reasoning is the part worth keeping.

**8. Approval.** `FINAL_PROPOSAL.md` is what got approved: the design that addressed all three objectives as cleanly as the review process could make it — price tracking as a genuinely separate table (not a column bolted onto `TrackingEvent`), an alert system ordered by `event_time` rather than insertion order with one alert per streak rather than per pair, and performance work on both the write path (batched imports) and the read path (N+1 elimination, pagination, matched indexes) with real before/after numbers, not estimates.

**9. Implementation.** Only after that approval did any application code get written — migrations, importers, the alert generator, controllers and views, tests, in that order.

**10. A real review of the real build.** The implementation was reviewed the same way the proposal was: adversarially, not just read over. CodeRabbit's automated review ran against the actual diff; the resulting back-and-forth — findings confirmed, findings disputed, findings that turned out to be more serious than they first looked, and at least one fix that needed a second fix of its own — is recorded in full in `IMPLEMENTATION_REPORT.md`.

## What the review process actually caught

Designed in a written proposal, reviewed against real data, then built and tested. A few concrete examples of what that produced:

- An early review comment flagged the running-streak-counter design as flawed because the CSV isn't sorted by `event_time` — real, but the first attempt to quantify it undersold its own finding: comparing total counts (38,901 arrival-order pairs vs. 39,114 chronological) made the two methods look nearly equivalent, a 213-pair difference. A later pass checked *which specific events* each method flags, not just how many — and found only 8,340 of the 39,114 correctly-identified events agree between the two orderings. Arrival order isn't "213 off," it's wrong on roughly 79% of alerts; the close total counts were a coincidence of the data being shuffled randomly.
- A blank cell in a CSV turned out to crash the *entire* import, not just that row — because Ruby's CSV library returns `nil`, not `""`, for an empty field, which raises a different exception class than the one the code was checking for. That's not something you'd guess; it had to be verified against the actual language behavior.
- A fix for one bug (pagination hiding "Next" on a short last page) quietly introduced a different one — doubling the number of queries on every paginated page in the app, because `Relation#first(n)` on an unloaded relation runs its own fresh query rather than reusing the one already in flight. Caught by review, confirmed with live query logging against the running app, fixed, and re-verified the same way.
- A separate fix (stop sending two alert emails for one failure) initially relied on checking whether a database transaction was still open — which worked correctly in production, but gave the wrong answer inside the test suite, because Rails' own test framework wraps every test in its own transaction. The fix was redone as an explicit flag instead of inferring intent from ambient state that the test framework itself was quietly changing.
- Suggestions were also specifically rejected, not just accepted by default — a critique that two column names should be considered "dates" was corrected to type-neutral wording once checked against the actual schema (`event_time` is `datetime`, by design, documented specifically so it wouldn't get narrowed to `date` later); a suggestion to treat a negative price as a row to silently skip was instead kept as a hard failure of the whole import, on the reasoning that a negative price means the file itself is untrustworthy, not that one row is bad.

## Where everything actually lives

| Document | What's in it |
|---|---|
| `INITIAL_PROPOSAL.md` | The first draft. Frozen — several of its ideas were superseded, kept as a record of where this started. |
| `REVIEWED_PROPOSAL.md` | The full 18-round review log. The *why* behind every decision below, including the ones that didn't survive. |
| `FINAL_PROPOSAL.md` | The design that was actually approved and built. States only the destination, with measured numbers. |
| `CLAUDE.md` | Orientation for anyone — human or AI — picking this repository back up. The traps already found, so they don't get rediscovered. |
| `IMPLEMENTATION_REPORT.md` | What happened when the approved design was actually built and run: what held up exactly as predicted, the bugs found only by running the app, and the full CodeRabbit-driven review of the real code. |

As a bonus beyond the three objectives, the app's UI design was also explored further on a separate branch, not merged into this one.
