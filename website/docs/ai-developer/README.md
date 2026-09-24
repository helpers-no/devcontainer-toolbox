---
mdx:
  format: md
---

# AI Developer Guide

Instructions for AI coding assistants working on this project.

---

## Why This System

AI coding assistants are powerful but need structure to be effective. This system has three layers:

1. **The Cage** — When a devcontainer exists, the AI runs inside it. It can only see the project
   directory. Your machine, SSH keys, and other projects are protected. Skip this layer if
   `project-*.md` says there is no devcontainer.
2. **The Plan** — The AI creates a plan before writing code. You review it. This prevents
   hallucinations, scope drift, and wasted work.
3. **The Tests** — Validation catches mistakes. The AI runs checks after each phase and
   self-corrects before you review.

---

## Documents

| Document | Purpose | When to Read |
|----------|---------|-------------|
| [WORKFLOW.md](WORKFLOW.md) | End-to-end flow from idea to implementation | When starting new work |
| [PLANS.md](PLANS.md) | Plan structure, investigation guidance, templates | When creating or implementing a plan |
| [DEVCONTAINER.md](DEVCONTAINER.md) | How to work inside the devcontainer | When `project-*.md` says DCT applies |
| [GIT.md](GIT.md) | Git safety rules and platform operations | When doing git operations |
| [COORDINATION.md](COORDINATION.md) | Your repo vs the coordination repo: where `gh` applies and where `fleet-task` does | Before touching an issue in `urb-agents` |
| [AZURE-DEVOPS.md](AZURE-DEVOPS.md) | Azure DevOps (`az` CLI) | When `origin` is Azure DevOps |
| [SECURITY.md](SECURITY.md) | Secrets and any published-site access rule | Before writing anything sensitive |
| [VERIFICATION.md](VERIFICATION.md) | Whether a round of verification can be trusted | Before believing a green run, and before writing a check |

---

## Start Here

When starting a new session, read files in this order:

1. **Read all `project-*.md` files first** — they are the authoritative source for everything
   project-specific: what this project is, what it builds, where its code lives, which commands
   to run, which framework docs apply and which don't (e.g. whether [DEVCONTAINER.md](DEVCONTAINER.md)
   is relevant), what the architectural contracts are, and where the rest of the documentation
   lives. **Do not assume any project-specific detail from this README** — if the framework doc
   and the project doc disagree, the project doc wins.
2. **Read all `template-*.md` files** (if any) — tech stack from installed templates
3. **Read [WORKFLOW.md](WORKFLOW.md)** when starting new work
4. **Read [PLANS.md](PLANS.md)** when creating or implementing a plan
5. **Reference** [DEVCONTAINER.md](DEVCONTAINER.md), [GIT.md](GIT.md),
   [AZURE-DEVOPS.md](AZURE-DEVOPS.md) as needed — but only if the `project-*.md` files indicate
   they apply
6. **Read [SECURITY.md](SECURITY.md)** before writing anything sensitive
7. **Read [VERIFICATION.md](VERIFICATION.md)** before trusting a check, yours or anyone's

---

## File Naming Convention

| Prefix | Meaning | Portable? | Created by |
|--------|---------|-----------|------------|
| (none) | Universal workflow docs | Yes — copy from `terchris/urb-agents` `ai-developer-template/` | Copied from template |
| `project-*` | Project-specific setup and conventions | No | Project maintainer / this agent |
| `template-*` | Tech stack from installed template | No | `dev-template` command |
| `plans/` | Implementation plans | No | AI + maintainer |

---

## Plans Folder

Implementation plans are stored in `plans/`:

```
plans/
├── backlog/      # Approved plans waiting for implementation
│   └── 1PRIORITY.md  # Triage: what to do next, what is stuck
├── active/       # Currently being worked on (max 1-2 at a time)
└── completed/    # Done - kept for reference
```

### File Types

| Type | When to use |
|------|-------------|
| `PLAN-*.md` | Solution is clear, ready to implement |
| `INVESTIGATE-*.md` | Needs research first, approach unclear |

---

## Quick Reference

### When user says "I want to add X" or "Fix Y":

1. Create `INVESTIGATE-*.md` or `PLAN-*.md` in `plans/backlog/`
2. Ask user to review the plan
3. Wait for approval before implementing

### When user approves a plan:

1. Ask: "Do you want to work on a feature branch? (recommended)"
2. Create branch if yes
3. Move plan to `plans/active/`
4. Implement phase by phase
5. Ask user to confirm after each phase

### When implementation is complete:

1. Move plan to `plans/completed/`
2. Create Pull Request if on feature branch

---

## Project-Specific Instructions

All project-specific information — purpose, architecture, repository layout, key commands,
devcontainer-or-not, tech stack, contracts, where the rest of the docs live, git host, the
path of *this* `ai-developer/` folder, and the urb-agents agent id — lives in `project-*.md`
files in this directory.

This repo's is [project-devcontainer-toolbox.md](project-devcontainer-toolbox.md) (the template ships it as `project.EXAMPLE.md`). Read it before doing anything else.

If the repo root contains a `CLAUDE.md` or `AGENTS.md`, the relevant `project-*.md` will say so
and link to it.

**Fleet work does not live here.** The inbox is a query on `terchris/urb-agents` —
`~/.local/bin/urb inbox --id <agent-id>`, open issues labelled `to:<agent-id>`; there is no mailbox
directory. Do not copy that protocol into this folder.
