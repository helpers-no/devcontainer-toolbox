---
mdx:
  format: md
---

# Implementation Plans

How we plan, track, and implement features and fixes.

**Related:** [WORKFLOW.md](WORKFLOW.md) — End-to-end flow from idea to implementation

---

## Folder Structure

```
plans/
├── backlog/      # Approved plans waiting for implementation
│   └── 1PRIORITY.md  # Priority view across INVESTIGATE files (see "Keeping 1PRIORITY.md current" below)
├── active/       # Currently being worked on (max 1-2 at a time)
└── completed/    # Done - kept for reference
```

### Flow

PLAN files and INVESTIGATE files have **different** lifecycles:

```
PLAN-*.md:        backlog/ → active/ → completed/

INVESTIGATE-*.md: backlog/ ─────────────────────► completed/
                     │
                     └─ spawns 1+ child PLAN-*.md files (each on its own backlog → active → completed loop)
```

An INVESTIGATE stays in `backlog/` for its **whole life** — including while its child PLANs are being executed. It only moves to `completed/` once **every** child PLAN it spawned has shipped. INVESTIGATEs never live in `active/` — the live thing is the PLAN executing the recommendation, not the INVESTIGATE itself. Keeping the INVESTIGATE in `backlog/` avoids creating two parallel "where is current state?" trackers.

If an INVESTIGATE's recommendation has been accepted but no child PLAN has been drafted yet, it still stays in `backlog/` — note the acceptance in its `## Status` line.

---

## File Types

### INVESTIGATE-*.md

For work that **needs research first**. The problem exists but the solution is unclear.

**This is the most important part of the workflow.** The developer should spend most of their time here. A thorough investigation leads to a good plan, which leads to clean implementation. A rushed investigation leads to rework.

**When to create:**
- Complex work where options need evaluation
- Bug with unknown root cause
- Feature requiring design decisions or architectural choices
- New tool or library selection

**Naming:** `INVESTIGATE-<topic>.md`

Examples:
- `INVESTIGATE-authentication-options.md`
- `INVESTIGATE-performance-issues.md`

**Cluster naming:** `INVESTIGATE-<id><nn>-<topic>.md` — when several investigations belong to one programme, they share a short cluster id plus a two-digit number: `INVESTIGATE-api01-redcross-api-plan.md`, `INVESTIGATE-api02-taxonomy.md`, … The id groups the family in every file listing and gives each member a short stable handle ("api07") for cross-references and discussion. Numbers are allocated in creation order, are **identity not sequence** (execution order lives in the umbrella's plan), and are **never reused or renumbered**. The first cluster is `api` — the Red Cross API programme, with `api01` as its umbrella.

**What makes a good investigation:**

- **Research best practices** — use web search to find how others have solved similar problems, what patterns exist, what pitfalls to avoid
- **Find tools and libraries** — and critically, verify they are actively maintained, recently updated, and have healthy community adoption. AI knowledge has a cutoff date and can recommend abandoned projects.
- **Analyse options** — document pros and cons of each approach with clear reasoning
- **Check for gaps** — after drafting, ask "are there gaps?" or "what could go wrong?" This catches missing steps, overlooked dependencies, and edge cases.
- **Verify findings** — AI can hallucinate tools, libraries, or best practices that don't exist. Ask it to verify its recommendations against current sources.
- **Iterate** — investigations improve through multiple rounds of questions and analysis. The first draft is rarely complete.

The investigation file is a **living document** — it captures decisions, rejected options, and the reasoning behind choices. When someone asks "why did we do it this way?" months later, the investigation has the answer.

Like PLAN files, an investigation must open with a **one-line abstract** as its first prose line (after the H1, before the IMPLEMENTATION RULES blockquote) — describe the question it explores. See the [Header](#1-header-required) convention; the `plans/*` index cards are auto-generated from this line.

**After investigation:** Create one or more PLAN files with the chosen approach.

### PLAN-*.md

For work that is **ready to implement**. The scope is clear, the approach is known.

**When to create:**
- Bug fix with known solution
- Feature request with clear requirements
- Work scoped by a completed investigation

**Naming Conventions:**

| Format | Use Case | Example |
|--------|----------|---------|
| `PLAN-<short-name>.md` | Standalone plan, no specific order | `PLAN-fix-mobile-nav.md` |
| `PLAN-<nnn>-<short-name>.md` | Ordered sequence, indicates execution order | `PLAN-001-data-migration.md` |

#### Ordered Plans (PLAN-nnn-*)

When an investigation produces multiple related plans that should be executed in a specific order, use **three-digit numbering** to indicate the sequence:

```
PLAN-001-data-migration.md        # Must be done first (foundation)
PLAN-002-schema-update.md         # Depends on 001
PLAN-003-ui-components.md         # Depends on 002
PLAN-004-integration-tests.md     # Depends on 003
```

**When to use ordered numbering:**
- Investigation produces 3+ related plans
- Plans have sequential dependencies
- Work is part of a larger initiative

**When NOT to use ordered numbering:**
- Standalone bug fix or small feature
- Plans can be executed in any order
- Single plan from an investigation

### Splitting Investigations into Multiple Plans

When an investigation covers a large initiative, split it into separate ordered plans rather than one monolithic plan. Each plan should be independently completable and deliverable.

**How to split:**

1. **Group by dependency and risk** — phases that need different prerequisites should be separate plans
2. **Group by completeness** — each plan should deliver something useful on its own
3. **Keep optional/deferred work separate** — don't mix required work with nice-to-haves

Each plan references the investigation and the previous plan in its header:

```markdown
**Investigation**: `INVESTIGATE-xyz.md`
**Prerequisites**: PLAN-001 must be complete first
```

---

## Plan Structure

Every plan has these sections:

### 1. Header (Required)

```markdown
# Plan Title

One-line purpose abstract: what this plan delivers (not its status). Plain prose, no links.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - `WORKFLOW.md` - The implementation process
> - `PLANS.md` - Plan structure and best practices

## Status: Backlog | Active | Blocked | Completed

**Goal**: One sentence describing what this achieves.

**Last Updated**: YYYY-MM-DD
```

The **IMPLEMENTATION RULES** blockquote ensures the AI reads the workflow and plan guidelines before starting work.

**The one-line abstract is required** and must be the first prose line, immediately after the H1 and before the IMPLEMENTATION RULES blockquote. The `plans/*` index pages are Docusaurus `generated-index` pages whose cards auto-derive their blurb from this first line — so without it, the card shows the boilerplate "IMPLEMENTATION RULES" text instead of a useful summary. Describe the plan's **purpose** (it should add information beyond the title); keep status/date in the `## Status` line. The same rule applies to `INVESTIGATE-*.md` (describe the question it explores) and the `talk/*` channels (describe the channel).

### 2. Dependencies (If applicable)

```markdown
**Prerequisites**: PLAN-001 must be complete first
**Blocks**: PLAN-003 cannot start until this is done
**Priority**: High | Medium | Low
```

For ordered plans, dependencies are often implicit in the number order. Only add explicit dependency notes when the relationship is non-obvious.

### 3. Problem Summary (Required)

What's wrong or what's needed. Be specific.

### 4. Phases with Tasks (Required)

Break work into phases. Each phase has:
- Numbered tasks
- A validation step at the end

```markdown
## Phase 1: Setup

### Tasks

- [ ] 1.1 Create the config file
- [ ] 1.2 Add validation rules
- [ ] 1.3 Test with sample data

### Validation

User confirms phase is complete.

---

## Phase 2: Implementation

### Tasks

- [ ] 2.1 Update the main component
- [ ] 2.2 Add error handling
- [ ] 2.3 Write tests

### Validation

User confirms implementation works correctly.
```

### 5. Acceptance Criteria (Required)

```markdown
## Acceptance Criteria

- [ ] Feature works correctly
- [ ] No regressions
- [ ] Documentation updated
```

### 6. Implementation Notes (Optional)

Technical details, gotchas, code patterns to follow.

### 7. Files to Modify (Optional but helpful)

```markdown
## Files to Modify

- `path/to/file.ext`
- `path/to/other.ext`
```

---

## Status Values

| Status | Meaning | Location |
|--------|---------|----------|
| `Backlog` | Approved, waiting to start | `plans/backlog/` |
| `Active` | Currently being worked on | `plans/active/` |
| `Blocked` | Waiting on something else | `plans/backlog/` or `plans/active/` |
| `Completed` | Done | `plans/completed/` |

---

## Updating Plans During Implementation

**Critical:** Plans are living documents. Update them as you work. **Mark each task `[x]` immediately after completing it, and mark each phase heading as DONE.** This is not optional — the plan file is the source of truth for progress. If the AI session is interrupted or context is lost, the plan shows exactly where work left off.

### When starting a phase:

```markdown
## Phase 2: Implementation — IN PROGRESS
```

### When completing a task:

```markdown
- [x] 2.1 Update the main component ✓
- [ ] 2.2 Add error handling
```

### When a phase is done:

```markdown
## Phase 2: Implementation — DONE
```

### When blocked:

```markdown
## Status: Blocked

**Blocked by**: Waiting for decision on approach
```

### When complete:

1. Update status: `## Status: Completed`
2. Add completion date: `**Completed**: YYYY-MM-DD`
3. Move file to `plans/completed/`

---

## Validation

Every phase ends with validation. The simplest form is asking the user to confirm.

### Default: User Confirmation

The AI asks: "Phase 1 complete. Does this look good to continue?"

In the plan, this can be written as:

```markdown
### Validation

User confirms phase is complete.
```

### Optional: Automated Check

When a command can verify the work, include it:

```markdown
### Validation

\`\`\`bash
# Command that verifies the work
some-check-command
\`\`\`

User confirms output is correct.
```

### Key Point

Don't force automated validation when it's impractical. User confirmation is valid and often the best approach.

---

## Plan Templates

### Simple Bug Fix

```markdown
# Fix: [Bug Description]

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - `WORKFLOW.md` - The implementation process
> - `PLANS.md` - Plan structure and best practices

## Status: Backlog

**Goal**: [One sentence]

**Last Updated**: YYYY-MM-DD

---

## Problem

[What's broken]

## Solution

[How to fix it]

---

## Phase 1: Fix

### Tasks

- [ ] 1.1 [Specific change]
- [ ] 1.2 [Another change]

### Validation

User confirms fix is correct.

---

## Acceptance Criteria

- [ ] Bug is fixed
- [ ] No regressions
```

### Feature Implementation

```markdown
# Feature: [Feature Name]

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - `WORKFLOW.md` - The implementation process
> - `PLANS.md` - Plan structure and best practices

## Status: Backlog

**Goal**: [One sentence]

**Last Updated**: YYYY-MM-DD

---

## Overview

[What this feature does and why]

---

## Phase 1: [Setup/Preparation]

### Tasks

- [ ] 1.1 [Task]
- [ ] 1.2 [Task]

### Validation

User confirms phase is complete.

---

## Phase 2: [Core Implementation]

### Tasks

- [ ] 2.1 [Task]
- [ ] 2.2 [Task]

### Validation

User confirms phase is complete.

---

## Acceptance Criteria

- [ ] [Criterion]
- [ ] [Criterion]
- [ ] Documentation updated

---

## Files to Modify

- `path/to/file.ext`
```

### Investigation

```markdown
# Investigate: [Topic]

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - `WORKFLOW.md` - The implementation process
> - `PLANS.md` - Plan structure and best practices

## Status: Backlog

**Goal**: Determine the best approach for [topic]

**Last Updated**: YYYY-MM-DD

---

## Questions to Answer

1. [Question 1]
2. [Question 2]

---

## Current State

[What exists now]

---

## Options

### Option A: [Name]

**Pros:**
-

**Cons:**
-

### Option B: [Name]

**Pros:**
-

**Cons:**
-

---

## Recommendation

[After investigation, what do we do?]

---

## Next Steps

- [ ] Create PLAN-xyz.md with chosen approach
  - For multiple related plans, use ordered naming: PLAN-001-*, PLAN-002-*, etc.
```

---

## Decision-point IDs (`[Q<N>]`)

Investigation files accumulate many enumerated lists — Questions to Answer, Options within sections, Open Questions, Decisions resolved during planning, phased PLAN proposals, etc. Without a stable reference scheme, "I agree with 1" is ambiguous because "1" exists in many places. The convention below makes every decision-point in a document referable by a short, unique ID.

### The rule

Every **decision-point** in an investigation or plan file gets a stable ID of the form `[Q<N>]`.

A decision-point is anything the reader might say "yes/no" to or pick between options for. Specifically:

- Topics in **"Questions to Answer"** at the top of an investigation
- **Options** discussed within a section's body (Section B's "Option 1, 2, 3" treatment of alternatives)
- **Rejected alternatives** (so they can be revisited later)
- Items in **"Open Questions"**
- Items in **"Decisions resolved during planning"**
- The **PLANs** in a "Recommendation — phased plan" section (PLAN-A, PLAN-B, …)

Pure narrative, SQL examples, and tables that aren't decision-options don't need IDs.

### Format

- `**[Q3]**` at the **start** of each decision-point item — markdown-bold + brackets so it stands out from prose.
- **Sequential, document-wide-unique** numbering. Allocate in document order.
- **Never reused.** When a question is resolved, its `[Q<N>]` keeps its number and travels with it (often moving from "Open Questions" to "Decisions resolved").
- **Sub-options** use letter suffixes: `Q11a` vs `Q11b` for "pick A or B" within Q11.

### Example

In a section body:

```markdown
The right answer is both:

1. **[Q11]** Org level (`dim_ngo`) — store the NGO's ICNPO codes from Brreg.
2. **[Q12]** Service level (`ref_atlas_service_category`) — Atlas-curated 22-row vocabulary.
3. **[Q13]** Activity catalogue (`dim_activity`) — replaces the crosswalk table.

Rejected alternatives:
- **[Q14]** ICNPO-only — too coarse for the UI Kari needs.
- **[Q15]** Tag-based, no fixed taxonomy — Kari can't filter.
```

In Open Questions:

```markdown
1. **[Q70]** Does the Red Cross API require a key for live polls?
2. ~~**[Q71]**~~ Should the service-category vocabulary be ~22 or ~40 rows? **Resolved** → 22, see Appendix A.
3. **[Q72]** Where do `dim_ngo` rows come from initially?
```

### How to give feedback

The reader can write things like:

- *"Q11 yes, Q14 also worth keeping in the rejected list, Q70 = no key needed for v1, Q72 = hand-curated seed"*
- *"Q11a not Q11b"* (picking a sub-option)
- *"Q33 looks wrong because…"*

Zero ambiguity, even in long files with many parallel numberings.

### Allocating IDs

For a brand-new investigation: number sequentially in document order as you write.

For an existing investigation getting retro-tagged: walk through in document order, assign Q1, Q2, … to each decision-point.

If you insert a new decision-point mid-document later, allocate the next free number and append it — don't renumber to keep IDs in document order. Stability of references matters more than visual ordering.

This convention applies to both INVESTIGATE-*.md and PLAN-*.md files. PLANs typically have fewer decision-points (most decisions are resolved by the time a PLAN is drafted) but Acceptance Criteria, open implementation choices, and validation gates can still benefit from `[Q<N>]` IDs when feedback is wanted.

---

## Best Practices

1. **Investigate first** — spend time understanding the problem before planning the solution
2. **One active plan at a time** — finish before starting another
3. **Small phases** — easier to validate and recover from errors
4. **Specific tasks** — "Update the config in file.ext" not "Fix the thing"
5. **Update as you go** — the plan is the source of truth
6. **Keep completed plans** — they're documentation of what was done and why
7. **Ask for gap analysis** — "Are there gaps in this plan?" catches issues early

## Keeping contributor docs in sync (PLAN-003 phase 5, 2026-04-28)

When a plan changes behaviour that's documented on a `website/docs/contributors/*.md` page (or in `website/docs/ai-developer/`), **the docs update is a sub-step of the relevant phase, not a follow-up plan**. Examples:

- A plan changes how dbt-osmosis is configured → updating `contributors/dbt-osmosis.md` is part of the same phase, not a "we'll do it later" item.
- A plan adds a new step to the source-add workflow → `contributors/adding-a-source.md` gets the new step in the same PR.
- A plan modifies the `check-osmosis.sh` gate → `contributors/check-osmosis.md` reflects the new behaviour.

This convention is rule #8 in [`docs/stack/naming-conventions.md`](https://github.com/terchris/atlas/tree/main/docs/stack/naming-conventions.md). Reviewer responsibility to flag PRs that ship behaviour changes without the matching docs update. No tooling enforces this in v1; if drift becomes a real problem, revisit and add a `check-docs.sh` similar to [`check-osmosis.sh`](https://github.com/terchris/atlas/tree/main/atlas-data/dbt/check-osmosis.sh).

When drafting a plan that changes documented behaviour, include the docs update in the **Files to Modify** list and as an explicit task line in the relevant phase. Don't list it under "What's next" — that's where the convention slips.

## Keeping `backlog/1PRIORITY.md` current

`plans/backlog/1PRIORITY.md` is required. It is the priority view across all open INVESTIGATE files — it tiers them by what to investigate next, what to defer pending prereqs, and what's still an idea (not a real investigation yet). It's a triage tool, not a roadmap. The skeleton is in this template.

Update it when any of the following happens:

- A new `INVESTIGATE-*.md` is added to `backlog/` → place it in the right tier.
- An INVESTIGATE moves to `completed/` → strike its row, promote its Tier-3 dependents up if their prereq just landed.
- A child PLAN of an INVESTIGATE ships → re-rank the parent INVESTIGATE if the partial-completion changes its priority.
- An idea (Tier 4) becomes concrete enough to investigate → promote it to a real tier with a brief rationale.

The doc itself explains how to use it (see its "How to use this doc" section). Re-rank quarterly or after every 3 INVESTIGATEs ship — whichever comes first.
