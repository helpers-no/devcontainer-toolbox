---
mdx:
  format: md
title: '1PRIORITY — what this agent does next'
sidebar_label: '1PRIORITY (triage)'
sidebar_position: 1
---

# 1PRIORITY — what this agent does next

**Last updated: 2026-09-24** · agent `devcontainer-toolbox` · state **idle**

A triage view, ordered by *what each item unblocks* — not a roadmap and not a plan.
[`index.md`](index.md) says what every backlog item **is**; this file says what to **do next**
and what is stuck behind whom. Kept current on a change, not on a schedule.

Fleet work is on the bus in `terchris/urb-agents` —
`~/.local/bin/urb inbox --id devcontainer-toolbox`; there is no mailbox directory.

---

## Do next — mine, unblocked

| # | What | Why this one |
|---|---|---|
| **1** | [PLAN-p1-dct-shim](../active/PLAN-p1-dct-shim.md) phase 3: end-to-end test of the `uis` shim with `python-basic-webserver-database` | The shim is shipped but has never been confirmed end to end. First check the prerequisite: the template README no longer mentions `docker exec`, but it also has no `uis connect` / `uis status` sections for tasks 3.2–3.3 to test. |
| **2** | Close out [PLAN-dct-exec-host-helper](../active/PLAN-dct-exec-host-helper.md): run the unverified checks, then move it to `completed/` | Shipped in 1.8.0; only its bookkeeping is open. |

## Waiting on someone — ordered by what it unblocks

| What | Who | Since | Unblocks | Raised |
|---|---|---|---|---|
| Whether to open follow-up issue 5.3 in `helpers-no/sovdev-logger` | Terje | 2026-09-24 | Closing PLAN-dct-exec-host-helper | This session |

## If Terje wants work started, these rank highest

1. [INVESTIGATE-outdated-software-versions](INVESTIGATE-outdated-software-versions.md) — every user gets the base image
2. [PLAN-windows-testing](PLAN-windows-testing.md) — DCT claims Windows support that has never been tested
3. [INVESTIGATE-image-retention](INVESTIGATE-image-retention.md) — every release adds image tags to ghcr.io

This ranking is the agent's proposal, not an agreed order. When this file's one-liner changes,
refresh `fleet/status/devcontainer-toolbox.md` with `urb publish-status` (do not write that file
by hand).
