# Summary of Actions

This is the README's requested "brief README or notes document explaining your key decisions" — but about the *process*, not the technical detail. The technical detail already exists, in full, in five other documents this process produced. This one is the map: how this submission actually got built, using Claude Code, and why it was built that way.

## The result, in numbers

- **3 objectives, all addressed**: price tracking as a structurally independent table; an alert system ordered by `event_time` with one alert per streak; measured performance work on both the import path and every read path.
- **~44 seconds** end-to-end for the real 1,000,000-row import, including alert generation — down from an extrapolated ~30 minutes for the original row-by-row approach.
- **31,447 alerts**, exact, against the real imported data.
- **230x faster** on the busiest store's page: 6 queries / 21ms, down from a measured 20,341 queries / 5,946.9ms.
- **34 tests, 0 failures**, weighted toward the logic the review process identified as actually risky.
- A documented limitation left honestly unfixed where fixing it wasn't yet justified (a grouped count that's already 84% of one page's load time at today's scale, correctly scoped as a 100x-scale problem, not a today problem) — because explaining a tradeoff is part of the assignment, not a gap in it.

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

## Why eighteen rounds, not one

The point of the repeated review wasn't indecision — it was that nothing got accepted just because an AI (either Claude instance, or CodeRabbit) suggested it. A few concrete examples of that discipline actually paying off, not just claimed:

- A blank cell in a CSV turned out to crash the *entire* import, not just that row — because Ruby's CSV library returns `nil`, not `""`, for an empty field, which raises a different exception class than the one the code was checking for. That's not something you'd guess; it had to be verified against the actual language behavior.
- A fix for one bug (pagination hiding "Next" on a short last page) quietly introduced a different one — doubling the number of queries on every paginated page in the app, because `Relation#first(n)` on an unloaded relation runs its own fresh query rather than reusing the one already in flight. Caught by review, confirmed with live query logging against the running app, fixed, and re-verified the same way.
- A fix for *that* review finding (stop sending two alert emails for one failure) initially relied on checking whether a database transaction was still open — which worked correctly in production, but gave the wrong answer inside the test suite, because Rails' own test framework wraps every test in its own transaction. The fix was redone as an explicit flag instead of inferring intent from ambient state that the test framework itself was quietly changing.
- Suggestions were also specifically rejected, not just accepted by default — a critique that two column names should be considered "dates" was corrected to type-neutral wording once checked against the actual schema (`event_time` is `datetime`, by design, documented specifically so it wouldn't get narrowed to `date` later); a suggestion to treat a negative price as a row to silently skip was instead kept as a hard failure of the whole import, on the reasoning that a negative price means the file itself is untrustworthy, not that one row is bad.

## Where everything actually lives

| Document | What's in it |
|---|---|
| `INITIAL_PROPOSAL.md` | The first draft. Frozen — several of its ideas were superseded, kept as a record of where this started. |
| `REVIEWED_PROPOSAL.md` | The full 18-round review log. The *why* behind every decision below, including the ones that didn't survive. |
| `FINAL_PROPOSAL.md` | The design that was actually approved and built. States only the destination, with measured numbers. |
| `CLAUDE.md` | Orientation for anyone — human or AI — picking this repository back up. The traps already found, so they don't get rediscovered. |
| `IMPLEMENTATION_REPORT.md` | What happened when the approved design was actually built and run: what held up exactly as predicted, the bugs found only by running the app, and the full CodeRabbit-driven review of the real code. |
| `DESIGN_PROPOSAL.md` | A bonus: three concrete visual-redesign options for the app's UI, proposed on a separate branch, not built pending a decision. |
