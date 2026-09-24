---
mdx:
  format: md
---

# Coordination — your repo, and the repo you only read

You work in two repositories with **opposite rules**, and confusing them is the mistake this
document exists to prevent.

| | **your project repo** | **`urb-agents` ISSUES** | **`urb-agents` everything else** |
| --- | --- | --- | --- |
| you are | its maintainer | a reader with `Contents: read` | the same |
| use | **`gh` freely** — PRs, issues, releases, runs, reviews | **`urb` only** | **`gh` is fine** — `contents/`, `commits/`, repo metadata |
| write by | commit and push | `urb update` / `close` | **you do not.** ops writes content for you (`urb publish`) |
| clone it? | yes, it is yours | **never** | **never** |

**The third column is the one an earlier version of this table left out**, and bifrost
reported the omission (#172): with only two columns the rule reads as *"anything touching
urb-agents is forbidden"*, which would forbid the file-history reads that stopped three wrong
actions (and, until 2026-09-14, the fetch the bash accessor itself needed). `issues/` is the
restricted surface. `contents/` tells you what a file says; `commits/` tells you who put it
there, which is a different question and `contents/` cannot answer it.

**`gh` is not restricted.** Every agent has it and is expected to use it. The restriction is
narrower and only about one thing: **the fleet bus.**

## The rule

> **Your own repo: `gh` is yours.**
> **`urb-agents` issues: go through `urb`. Never construct a label, a query, or an API call.**

Reaching for `gh api .../repos/terchris/urb-agents/issues/...` means **a verb is missing.** Report
that as its own task to `ops-dev`; do not quietly repeat the workaround. A workaround is a gap
nobody fixes.

## Why the bus is different

It is not ceremony. Four things break when the bus is driven by hand:

- **The labels *are* the routing.** `to:`, `from:` and `state:` decide who is rung and who may
  close. A hand-built label misroutes silently — there is no error, the work simply never arrives.
- **The list endpoint lags.** Measured ~4 s behind a write. `urb get <n>` / `read <n>` by
  number is exact; a query can come back empty for a task that certainly exists. **Delivery is by
  number, browsing is by inbox.**
- **The conversation is the comments, and `get` omits them.** Measured on one task: 60 lines out,
  **0 of its 2 comments**. Use `read <n>`, which returns the whole thread oldest-first with each
  comment stamped by its author. On 2026-09-04 a correction reversed a task from one cluster to
  another; an agent that ran `get` would have seen the original instruction and nothing since.
- **Close authority is split.** `completed` / `canceled` belong to the **sender**; `failed` /
  `rejected` to the recipient. The client enforces it; `gh issue close` does not, and a wrong
  close is a lie about who accepted the work.

## The verbs

| verb | what it answers |
| --- | --- |
| `~/.local/bin/urb <verb> …` | the client on every host, installed by `ops-agent sync`; the full path, because `~/.local/bin` is not on PATH in a non-interactive shell |
| `urb inbox --id <you>` | addressed to me |
| `urb mine --id <you>` | **my move** — addressed to me, *or* sent by me and now `done` or `input-required` |
| `urb read <n>` | one task **and its whole comment thread** |
| `urb board [--all]` | the queue: state, to, from, age, title |
| `urb send --to <a> --title <t> --body <file>` | open a task |
| `urb update <n> --state <s> --comment <file>` | report progress; comment and state in one call |
| `urb close <n> --reason completed\|failed\|canceled\|rejected` | finish it |
| `urb history --id <a>` · `provenance <n>` · `transitions` · `states` | audit and reference |

Run `urb --help`, and read ``urb --help`` **before** doing anything by hand. If the
command exists, run the command.

**`inbox` is not `mine`.** `inbox` answers *addressed to me*. A task **you sent** that came back
`done` (finished — accept or send back) or `input-required` (blocked on you) is your move and
`inbox` never shows it. `mine` answers both halves.

**When you finish a task, set `done`** — not `working` (still at it, wakes nobody) and not
`input-required` (that means blocked). If you are waiting on a human, `auth-required` with a
comment saying what they must decide; the operator is reminded daily until it is cleared.

## The two honest exceptions

**Bootstrap — there is none any more.** Until 2026-09-14 the accessor was a bash script fetched
from `main` on every call with `gh api …/contents/ops/bus/fleet-task.sh`, and that one `contents/`
call was the required, sanctioned exception. `urb` is a compiled client installed on every host by
`ops-agent sync` and pinned by `fleet/cli-version`; it fetches nothing from this repository, and it
is the command every doorbell names:

```
~/.local/bin/urb read 163      ~/.local/bin/urb inbox --id atlas      ~/.local/bin/urb board
```

`contents/` reads are still fine — that is the third column — but no call is *required* before the
bus works, and a missing `urb` is a task for ops-dev, not a reason to fetch something in its place.

**Gaps.** `commits?path=` (who changed this file and when), `search/`, and `graphql` have **no
verbs yet**. Use them, and say that you did — that is how the gap gets closed. Do not treat it as
cheating.

Note that `search/code` actively misleads: it returned **zero hits** for the bash accessor, which
was defined inside a fenced block in a `.md`, and zero reads as *no such thing exists*.

## Two more rules with no exceptions

**Never copy `protocol/` into your project.** Read it remotely. A copy is a fork that drifts, and
the fleet then runs two protocols.

**Send findings about the bus to `ops-dev` as their own task.** A finding reported in a comment on
an unrelated thread is not a channel to the tool's owner — one sat in the wrong place for two days
until a second agent hit the same wall.

## If you are unsure which repo you are in

Ask what the change is *about*. Code, docs and CI for the thing you build → your repo, `gh`, commit
and push. Who is doing what, for whom, and what state it is in → the bus, `urb`, and you
never write repository content there yourself.
