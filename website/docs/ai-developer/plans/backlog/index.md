---
mdx:
  format: md
title: Backlog — index
sidebar_label: Backlog (index)
sidebar_position: 0
---

# Backlog — index

What each open backlog item **is**, in one line. [`1PRIORITY.md`](1PRIORITY.md) says what to
**do next**. INVESTIGATEs stay here until every child PLAN ships; PLANs live in `active/` while
in progress.

| Item | What it does | Priority |
|---|---|---|
| [PLAN-fix-windows-quickstart](PLAN-fix-windows-quickstart.md) | Make the Windows Quick Start work: cross-shell `initializeCommand`, safe `install.ps1`, split docs block | High |
| [PLAN-host-installer-handover](PLAN-host-installer-handover.md) | DCT's side of the host-installer split: host requirements page, admin-free callable `install.ps1`/`install.sh`, plain-language handover | High |
| [PLAN-finish-move-to-helpers-no](PLAN-finish-move-to-helpers-no.md) | Leftovers of the terchris → helpers-no move: fork network reversed, old image deleted (phases 1–2 done) | — |
| [INVESTIGATE-outdated-software-versions](INVESTIGATE-outdated-software-versions.md) | Decide how the base image pins or tracks Node and other bundled software versions | — |
| [INVESTIGATE-image-retention](INVESTIGATE-image-retention.md) | Retention policy for the image tags every release pushes to ghcr.io | — |
| [PLAN-windows-testing](PLAN-windows-testing.md) | Validate DCT on Windows; it has only been tested on macOS | — |
| [INVESTIGATE-kubeconfig-in-devcontainer](INVESTIGATE-kubeconfig-in-devcontainer.md) | Make `kubectl` inside the container reach the host's clusters | — |
| [INVESTIGATE-git-identity-auto-detect](INVESTIGATE-git-identity-auto-detect.md) | Pick up the host's git identity on first container start | — |
| [INVESTIGATE-host-identity-and-template-defaults](INVESTIGATE-host-identity-and-template-defaults.md) | Capture host identity once and use it as template defaults | — |
| [INVESTIGATE-otel-auto-identity](INVESTIGATE-otel-auto-identity.md) | Auto-detect the developer identity fields OTel telemetry needs | — |
| [INVESTIGATE-simplify-initial-dct-experience](INVESTIGATE-simplify-initial-dct-experience.md) | Reduce what a new user has to take in on first open | — |
| [INVESTIGATE-dev-setup-direct-command](INVESTIGATE-dev-setup-direct-command.md) | Let `dev-setup` run a named script directly instead of only via the menu | — |
| [INVESTIGATE-template-quickstart-block](INVESTIGATE-template-quickstart-block.md) | A `quickstart` block in `template-info.yaml` for the post-install message | — |
| [INVESTIGATE-php-install-scripts](INVESTIGATE-php-install-scripts.md) | Split plain PHP from the Laravel install script and fix its instructions | — |
| [INVESTIGATE-advanced-templates](INVESTIGATE-advanced-templates.md) | Templates with backend dependencies (for example a CMS plus PostgreSQL) | — |
| [INVESTIGATE-analytics-setup](INVESTIGATE-analytics-setup.md) | Umami analytics for the documentation site; definition incomplete | — |

Priority is unset except where marked: no ranking of the rest of the backlog has been agreed yet.
