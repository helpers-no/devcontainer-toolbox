# Investigate: AI Workflow Installer Tool (`dev-template-ai.sh`)

## Status: Completed

**Completed**: 2026-03-30

**Goal**: Create `dev-template-ai.sh` — a command that installs AI workflow templates into any project, following the same UX pattern as `dev-template.sh` for app templates.

**Priority**: Medium

**Last Updated**: 2026-03-29

**Related**: [INVESTIGATE-ai-developer-template.md](https://github.com/helpers-no/dev-templates/blob/main/website/docs/ai-developer/plans/backlog/INVESTIGATE-ai-developer-template.md) in `helpers-no/dev-templates` — contains the full investigation and design decisions.

---

## Summary

This investigation was started in this repo (DCT) in January 2026 and continued in `helpers-no/dev-templates` in March 2026 where the design was finalized. The work is split across two repos:

- **`helpers-no/dev-templates`** — hosts `ai-templates/` folder with template content (parallel to `templates/`)
- **`helpers-no/devcontainer-toolbox`** (this repo) — hosts `dev-template-ai.sh` script

The dev-templates repo will create the template content. This document covers the DCT side: the script.

---

## Design Decisions (from dev-templates investigation)

### Why a Separate Script (Not Modifying `dev-template.sh`)

`dev-template.sh` is purpose-built for app scaffolding:
- Hard-requires `manifests/deployment.yaml` — AI templates have no Kubernetes manifests
- Copies everything to project root — AI templates need files in `docs/ai-developer/`
- Replaces K8s placeholders in YAML — AI templates don't need this
- Sets up CI/CD workflows — not relevant for workflow docs

The two template types are complementary. A project runs `dev-template.sh` for the app, then `dev-template-ai.sh` for the AI workflow. Or `dev-template-ai.sh` alone for non-Urbalurba projects.

### Naming

`dev-template-ai.sh` — sorts next to `dev-template.sh` in `ls`.

### Target Path

AI templates install to `docs/ai-developer/` as a standard path, baked into each template's directory structure.

### CLAUDE.md Conflict Handling

Each template includes:
- `CLAUDE.md` — starter file for project root
- `CLAUDE-template.md` — reference copy stored inside `docs/ai-developer/`

Script behavior:
1. **No existing CLAUDE.md**: Copy `CLAUDE.md` to project root. Done.
2. **Existing CLAUDE.md**: Do NOT overwrite. Keep `CLAUDE-template.md` in `docs/ai-developer/` and print:

```
⚠️  CLAUDE.md already exists in your project.
   A template CLAUDE.md has been placed at docs/ai-developer/CLAUDE-template.md

   Ask your AI assistant: "Merge CLAUDE-template.md into my CLAUDE.md"
```

### Skeleton project file

Each template includes a `project-TEMPLATE.md` with TODOs. The script renames it to `project-{{REPO_NAME}}.md` during installation.

---

## Architecture

### Source: `helpers-no/dev-templates`

```
dev-templates/
├── templates/              # App templates (used by dev-template.sh)
│   ├── typescript-basic-webserver/
│   └── ...
├── ai-templates/           # AI workflow templates (used by dev-template-ai.sh)
│   ├── plan-based-workflow/
│   │   ├── TEMPLATE_INFO
│   │   └── template/      # Files to install, preserving directory structure
│   │       ├── docs/ai-developer/
│   │       │   ├── README.md
│   │       │   ├── WORKFLOW.md
│   │       │   ├── PLANS.md
│   │       │   ├── DEVCONTAINER.md
│   │       │   ├── GIT.md
│   │       │   ├── TALK.md
│   │       │   ├── CLAUDE-template.md
│   │       │   ├── project-TEMPLATE.md
│   │       │   └── plans/
│   │       │       ├── backlog/.gitkeep
│   │       │       ├── active/.gitkeep
│   │       │       └── completed/.gitkeep
│   │       └── CLAUDE.md
│   └── ...future templates...
```

**TEMPLATE_INFO format** (same as app templates):
```bash
TEMPLATE_NAME="Plan-Based AI Workflow"
TEMPLATE_DESCRIPTION="Structured AI development with plans, phases, and validation"
TEMPLATE_CATEGORY="WORKFLOW"
TEMPLATE_PURPOSE="Provides a complete AI-assisted development workflow with investigation plans, phased implementation, and human-in-the-loop validation. Includes CLAUDE.md, plan templates, and git safety rules."
```

### Script: `dev-template-ai.sh`

Lives at `.devcontainer/manage/dev-template-ai.sh` in this repo.

---

## How `dev-template-ai.sh` Should Work

Follow the same patterns as `dev-template.sh` v1.6.0. Key differences noted below.

### Same as `dev-template.sh`

- Check prerequisites (`dialog`, `unzip`)
- Download `helpers-no/dev-templates` repo as zip
- Read `TEMPLATE_INFO` from each subfolder
- Show interactive `dialog` menu grouped by category
- User selects, sees details, confirms
- Clean up temp dir
- Script metadata block (`SCRIPT_ID`, `SCRIPT_NAME`, etc.)

### Different from `dev-template.sh`

| Aspect | `dev-template.sh` | `dev-template-ai.sh` |
|--------|-------------------|---------------------|
| Source folder in zip | `templates/` | `ai-templates/` |
| Validation | Requires `manifests/deployment.yaml` | No manifests validation — just check `template/` dir exists |
| File copy | Copies template root to `$CALLER_DIR/` | Copies `template/` contents to `$CALLER_DIR/` preserving paths |
| Placeholder replacement | `{{GITHUB_USERNAME}}`, `{{REPO_NAME}}` in YAML files | `{{REPO_NAME}}` in `.md` files |
| CLAUDE.md | Not handled | Special conflict handling (see above) |
| project-TEMPLATE.md | Not applicable | Installed as-is; developer renames manually |
| GitHub workflows | Copies `.github/workflows/` | Not applicable |
| .gitignore merge | Yes | Not needed |
| Git identity | Requires GitHub org + repo | Only needs repo name (for placeholders) |

### Step-by-Step Script Flow

1. Check prerequisites (`dialog`, `unzip`)
2. Detect repo name from `git remote` (via `lib/git-identity.sh`)
3. Display intro banner
4. Download `helpers-no/dev-templates` zip
5. Scan `ai-templates/*/` directories, read `TEMPLATE_INFO`
6. Show `dialog` menu (grouped by `TEMPLATE_CATEGORY`)
7. Show template details, get confirmation
8. Validate: check `template/` subdirectory exists in selected template
9. Copy `template/` contents to `$CALLER_DIR/` preserving directory structure, with these rules:
    - **Always overwrite** the 6 portable docs (README.md, WORKFLOW.md, PLANS.md, DEVCONTAINER.md, GIT.md, TALK.md) and `project-TEMPLATE.md` — these are template-owned
      - **Note (2026-09-24):** `TALK.md` is retired. It described a file-based agent bus that the fleet replaced with GitHub issues, and `helpers-no/dev-templates` no longer ships it. Do not reintroduce it. The rest of this rule is unchanged history.
    - **Never overwrite** user-renamed `project-*.md` files (anything other than `project-TEMPLATE.md`)
    - **Never overwrite** anything in `plans/` (backlog/, active/, completed/) — user's work
    - **Create** `plans/` directories with `.gitkeep` only if they don't exist
10. Handle CLAUDE.md:
    - If `$CALLER_DIR/CLAUDE.md` exists → remove the copied one, keep `docs/ai-developer/CLAUDE-template.md`, print merge instructions
    - If no existing CLAUDE.md → leave the copied one in place, remove `CLAUDE-template.md` (not needed)
11. Replace `{{REPO_NAME}}` in all `.md` files under `$CALLER_DIR/docs/ai-developer/` and `$CALLER_DIR/CLAUDE.md`
12. Clean up temp dir
13. Print completion message with next steps

---

## Tasks for This Repo

- [ ] Create `dev-template-ai.sh` in `.devcontainer/manage/`
- [ ] Follow `dev-template.sh` v1.6.0 patterns (dialog, zip download, TEMPLATE_INFO scanning)
- [ ] Scan `ai-templates/` instead of `templates/`
- [ ] Copy `template/` contents preserving directory structure
- [ ] Handle `{{REPO_NAME}}` replacement in `.md` files
- [ ] Handle CLAUDE.md conflict (see strategy above)
- [ ] Support safe re-runs: overwrite template-owned files, never overwrite user files or plans/
- [ ] Register in `tools.json` / `categories.json` so it appears in `dev-help`
- [ ] Add script metadata block for component scanner

---

## Open Questions

1. **Category names**: App templates use `WEB_SERVER`, `WEB_APP`, `OTHER`. AI templates could start with `WORKFLOW` as the only category, adding more (e.g., `RULES`, `MULTI_TOOL`) when there are enough templates to warrant grouping.
2. **Script metadata**: What `SCRIPT_CATEGORY` should `dev-template-ai.sh` use? Likely `SYSTEM_COMMANDS` (same as `dev-template.sh`).

---

## Dependencies

- **Blocked by**: `helpers-no/dev-templates` must have the `ai-templates/plan-based-workflow/` folder committed and pushed to `main` before this script can be tested.
- **Not blocked by**: The script structure and logic can be developed in parallel.

---

## Next Steps

- [ ] Wait for `helpers-no/dev-templates` to create `ai-templates/plan-based-workflow/`
- [ ] Create PLAN-dev-template-ai.md with implementation tasks
