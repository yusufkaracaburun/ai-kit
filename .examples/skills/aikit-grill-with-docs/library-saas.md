# `aikit-grill-with-docs` — library SaaS

**Source:** synthetic (fictional "Booklane" library-SaaS, modelled after typical multi-tenant Laravel patterns).
**Goal:** flesh out `CONTEXT.md` + first two ADRs for a brownfield codebase nobody has documented.

## Prompt

> We have a Booklane backend (Laravel 11) that manages library memberships, loans, and overdue fines. Nobody has documented the domain model. Models include `Branch`, `Member`, `Loan`, `Fine`, `Subscription`, `LibraryUser`, and `Profile`. Some of these names are confusing — a `LibraryUser` and a `Member` look like the same thing on the surface. Grill me with the docs so we end up with a `CONTEXT.md` and at least one ADR.

## Output — `CONTEXT.md` (excerpt)

```markdown
# Booklane context

Domain language for the Booklane backend — the system librarians use to issue
loans and bill fines at one or more library Branches.

Terms only land here once challenged against the code. Absence ≠ doesn't exist
— it means not yet grilled.

## Language

### Branch cluster

**Branch**:
A physical library location. Has a `code` (immutable, used in member-numbers
like "AMS-00421"), `name`, address fields, opening hours, and a default
`currency_id`. A Branch is also the tenant boundary: every Loan, Fine, and
Subscription belongs to exactly one Branch via `branch_id`.
_Avoid_: Location, site, tenant, library (call it "Branch").

**BranchClosure**:
A scheduled closing of a Branch — holidays, renovations. Has a date range and
a reason. Loans cannot be due during a closure (the Loan service shifts
due-dates forward). 1:many from Branch.
_Avoid_: Holiday, vacation, downtime.

### Member cluster

**Member**:
A library card-holder at a specific Branch. Carries the card number,
membership tier, expiry date, and the foreign key to LibraryUser. A person
may have separate Memberships at multiple Branches (each is its own Member
row). See [ADR-0001](./docs/adr/0001-member-vs-libraryuser.md).
_Avoid_: User, Patron, Customer, LibraryUser (different model — see below).

**LibraryUser**:
The auth credential — email, password, JWT subject, roles. **Carries nothing
human**. Names, addresses, preferred contact channel live on Profile. A
LibraryUser without a Profile is broken state ([ADR-0001]).
_Avoid_: Member, Person, Account.

**Profile**:
The person attached to a LibraryUser (1:1 via `library_user_id`). First name,
last name, phone, language, accessibility prefs, GDPR consent flags. Holds
nothing Branch-specific.
_Avoid_: Person record, identity.

### Lending cluster

**Loan**:
One book-out-the-door event. Belongs to a Member (not a LibraryUser — Loans
are per-Branch-membership). Carries due-date, return-date (nullable),
renewal_count, and item_isbn. Fines belong to a Loan, not a Member.
_Avoid_: Borrowing, Reservation (those are pre-loan state — separate model).

**Fine**:
A monetary charge raised against a Loan when overdue. 1:many from Loan
(multiple overdue periods can produce multiple Fines on one Loan). The
billing amount comes from `branches.daily_fine_amount × days_overdue` —
computed once on raise, never recomputed. See [ADR-0002].

## Flagged ambiguities

- **`LibraryUser` vs `Member` is the #1 trap.** Same person can have one
  LibraryUser and three Members. Always disambiguate: "the LibraryUser owns
  the auth; the Member owns the Branch relationship." Code that says
  `Loan -> User` is wrong — Loan belongs to Member.
- **Fine amount is frozen at issue time.** Don't recompute on display; show
  `fines.amount`, not `branches.daily_fine_amount × days_overdue` (the
  branch rate may have changed).
```

## Output — `docs/adr/0001-member-vs-libraryuser.md`

```markdown
# ADR-0001: LibraryUser is auth-only; Member is the Branch relationship

## Status
Accepted (retroactive — codifies the 2022 schema split).

## Context
The schema has both `library_users` and `members`. A naive reading suggests
duplication. It is not — the split mirrors the User/Profile split common in
Laravel apps, plus a multi-tenant twist: one person can be a Member of
multiple Branches simultaneously, each tracking its own card number, tier,
and expiry independently.

A future engineer scanning the models will see two near-identical "person"
shapes and may try to consolidate them.

## Decision
Keep two models with distinct, non-overlapping roles:
- **LibraryUser** answers: "Is this credential valid? Who is the JWT subject?
  What roles?"
- **Member** answers: "What is this person's relationship with *this* Branch?
  Their card number, membership tier, expiry?"

A LibraryUser has 0..N Members. A Member belongs to exactly one LibraryUser
and one Branch. Loans and Fines hang off Member (Branch-scoped), not
LibraryUser.

## Consequences
- **Lookups via Member, not LibraryUser.** Querying "all loans for user X" is
  ambiguous unless you pick a Branch. The API should reject that query
  shape; clients pass `branch_id`.
- **Soft-deleting a LibraryUser cascades to all Members.** Make the cascade
  explicit in the deletion flow; surprised admins are a UX bug.
- **Membership renewal is a Member-level concern, not LibraryUser-level.**
  Different Branches may renew on different dates.
```

## Output — `docs/adr/0002-fine-amount-frozen-at-issue.md`

```markdown
# ADR-0002: Fine amounts are frozen at issue time

## Status
Accepted.

## Context
Branches can change their `daily_fine_amount` at any time. Naive computation
of "amount = days_overdue × current_daily_fine_amount" would mean a Branch
quietly increasing fines retroactively raises all open Fines — a billing
correctness bug that's both unfair and probably illegal in some
jurisdictions.

## Decision
On the Loan service's `raise_fine` action: compute the amount once using the
Branch's `daily_fine_amount` at the moment of raising, persist it in
`fines.amount`, and never recompute.

Display and billing read `fines.amount`. They never re-multiply
`days_overdue × branches.daily_fine_amount`.

## Consequences
- **A Branch rate-change today does NOT change yesterday's Fines.** Members
  see the rate they were warned about, not the new one.
- **Auditing is straightforward.** `fines.amount` is the source of truth;
  the (branch_rate × days) breakdown is only for the issue-time UI.
- **Tests must cover the rate-change scenario** — easy to regress by adding
  a "recompute" helper.
```

## What about this output sets the bar

- **Glossary uses the project's words**, not generic DDD jargon. "Branch", "Member", "LibraryUser" — not "Tenant", "User", "Account".
- **Each definition includes an `_Avoid_` line** — the trap-list is as valuable as the definition.
- **Ambiguities are flagged, not hidden.** The "LibraryUser vs Member" trap is the first thing a new engineer would burn 4 hours on.
- **Every ADR codifies an existing decision** with a *why now* and explicit consequences — including the kind of mistake a future engineer might make.
- **No re-derivation across sessions.** Once written, this CONTEXT.md is the cached truth — future skills (`/aikit-review`, `/aikit-improve-codebase-architecture`) read this *before* touching code.

This is the bar. Other `aikit-grill-with-docs` showcases — and `aikit-to-prd`, `aikit-review`, `aikit-improve-codebase-architecture`, etc. — should produce equally concrete, equally domain-specific output.
